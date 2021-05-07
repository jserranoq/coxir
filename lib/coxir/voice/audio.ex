defmodule Coxir.Voice.Audio do
  @moduledoc """
  Work in progress.
  """
  import Coxir.Limiter.Helper, only: [time_now: 0]

  alias Coxir.Voice.Payload.Speaking
  alias Coxir.Voice.Session
  alias __MODULE__

  @type t :: %Audio{}

  defstruct [
    :session,
    :udp_socket,
    :ip,
    :port,
    :ssrc,
    :secret_key,
    :rtp_sequence,
    :rtp_timestamp,
    :last_timestamp
  ]

  @encryption_mode "xsalsa20_poly1305"
  @silence List.duplicate(<<0xF8, 0xFF, 0xFE>>, 5)
  @frame_samples 960
  @frame_duration 20000
  @burst_frames 10
  @burst_wait @burst_frames * @frame_duration

  def encryption_mode do
    @encryption_mode
  end

  def get_udp_socket do
    options = [
      :binary,
      {:active, false},
      {:reuseaddr, true}
    ]

    {:ok, socket} = :gen_udp.open(0, options)

    socket
  end

  def discover_local(udp_socket, remote_ip, remote_port, ssrc) do
    remote_address = ip_to_address(remote_ip)

    padded_remote_ip = String.pad_trailing(remote_ip, 64, <<0>>)

    request = <<1::16, 70::16, ssrc::32>> <> padded_remote_ip <> <<remote_port::16>>

    :ok = :gen_udp.send(udp_socket, remote_address, remote_port, request)

    {:ok, received} = :gen_udp.recv(udp_socket, 74)

    {^remote_address, ^remote_port, response} = received

    <<2::16, 70::16, ^ssrc::32, local_ip::bitstring-size(512), local_port::16>> = response

    local_ip = String.trim(local_ip, <<0>>)

    {local_ip, local_port}
  end

  @spec set_speaking(t, non_neg_integer) :: t
  def set_speaking(%Audio{session: session, ssrc: ssrc} = audio, bit) do
    speaking = %Speaking{speaking: bit, ssrc: ssrc}
    Session.set_speaking(session, speaking)

    if bit == 0 do
      send_frames(audio, @silence)
    else
      audio
    end
  end

  @spec process_burst(t, Enum.t()) :: {t, boolean, timeout}
  def process_burst(%Audio{last_timestamp: last_timestamp} = audio, source) do
    frames = Enum.take(source, @burst_frames)
    ended? = length(frames) < @burst_frames

    now_timestamp = time_now()

    audio = %{audio | last_timestamp: now_timestamp}
    audio = send_frames(audio, frames)

    wait = @burst_wait - (now_timestamp - last_timestamp)

    sleep =
      wait
      |> trunc()
      |> max(0)

    {audio, ended?, sleep}
  end

  defp ip_to_address(ip) do
    {:ok, address} =
      ip
      |> String.to_charlist()
      |> :inet_parse.address()

    address
  end

  defp send_frames(%Audio{} = audio, frames) do
    Enum.reduce(
      frames,
      audio,
      fn frame, audio ->
        send_frame(frame, audio)
      end
    )
  end

  defp send_frame(
         %Audio{
           udp_socket: udp_socket,
           ip: ip,
           port: port,
           rtp_sequence: rtp_sequence,
           rtp_timestamp: rtp_timestamp
         } = audio,
         frame
       ) do
    encrypted = encrypt_packet(audio, frame)
    :gen_udp.send(udp_socket, ip, port, encrypted)

    %{audio | rtp_sequence: rtp_sequence + 1, rtp_timestamp: rtp_timestamp + @frame_samples}
  end

  defp rtp_header(%Audio{ssrc: ssrc, rtp_sequence: rtp_sequence, rtp_timestamp: rtp_timestamp}) do
    <<
      0x80::8,
      0x78::8,
      rtp_sequence::16,
      rtp_timestamp::16,
      ssrc::32
    >>
  end

  defp encrypt_packet(%Audio{secret_key: secret_key} = audio, packet) do
    header = rtp_header(audio)
    nonce = header <> <<0::96>>
    header <> Kcl.secretbox(packet, nonce, secret_key)
  end
end

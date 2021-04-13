defmodule Coxir.API.Limiter do
  @moduledoc """
  Responsible for handling ratelimits.
  """
  alias Coxir.Limiter

  @behaviour Tesla.Middleware

  @major_params ["guilds", "channels", "webhooks"]
  @regex ~r|/?([\w-]+)/(?:\d+)|i

  @header_global "x-ratelimit-global"
  @header_remaining "x-ratelimit-remaining"
  @header_reset "x-ratelimit-reset"

  def call(env, next, _options) do
    bucket = bucket_name(env)

    with {:error, timeout} <- Limiter.hit(:global) do
      Process.sleep(timeout)
    end

    with {:error, timeout} <- Limiter.hit(bucket) do
      Process.sleep(timeout)
    end

    with {:ok, response} <- Tesla.run(env, next) do
      global = Tesla.get_header(response, @header_global)
      remaining = Tesla.get_header(response, @header_remaining)
      reset = Tesla.get_header(response, @header_reset)

      if remaining && reset do
        remaining = String.to_integer(remaining)
        reset = String.to_integer(reset) * 1000
        bucket = if global, do: :global, else: bucket
        Limiter.put(bucket, remaining, reset)
      end

      {:ok, response}
    end
  end

  defp bucket_name(%{method: method, url: url}) do
    case Regex.run(@regex, url) do
      [route, param] when param in @major_params ->
        if method == :delete and String.contains?(url, "messages") do
          "delete:" <> route
        else
          route
        end

      _other ->
        url
    end
  end
end

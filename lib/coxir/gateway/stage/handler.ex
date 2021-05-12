defmodule Coxir.Gateway.Handler do
  @moduledoc """
  Work in progress.
  """
  alias Coxir.Gateway.Dispatcher

  @type t :: module

  @callback handle_event(Dispatcher.event()) :: any

  def child_spec(handler) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_handler, [handler]},
      restart: :temporary
    }
  end

  def start_handler(handler, event) do
    Task.start_link(fn ->
      handler.handle_event(event)
    end)
  end
end

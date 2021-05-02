defmodule Coxir.API.Helper do
  @moduledoc """
  Common helper functions for `Coxir.API` middlewares.
  """
  alias Tesla.Env
  alias Coxir.{Token, Gateway}

  @spec get_token(Env.t()) :: Token.t()
  def get_token(%Env{opts: options}) do
    options
    |> Map.new()
    |> obtain_token()
  end

  defp obtain_token(%{as: gateway}) do
    Gateway.get_token(gateway)
  end

  defp obtain_token(options) do
    config = Application.get_env(:coxir, :token)
    Map.get(options, :token, config)
  end
end

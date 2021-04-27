defmodule Coxir.User do
  @moduledoc """
  Work in progress.
  """
  use Coxir.Model

  embedded_schema do
    field(:username, :string)
    field(:discriminator, :string)
    field(:avatar, :string)
    field(:bot, :boolean)
    field(:system, :boolean)
    field(:mfa_enabled, :boolean)
    field(:locale, :string)
    field(:verified, :boolean)
    field(:email, :string)
    field(:flags, :integer)
    field(:premium_type, :integer)
    field(:public_flags, :integer)
  end

  def fetch(id, options) do
    API.get("users/#{id}", options)
  end

  @doc false
  def create(params, options)

  @spec create_dm(t, Loader.options()) :: Loader.result()
  def create_dm(%User{id: id}, options \\ []) do
    params = %{recipient_id: id}
    Channel.create(params, options)
  end
end

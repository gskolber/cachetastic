defmodule Cachetastic.Serializer do
  @moduledoc """
  Behaviour for Cachetastic serializers.

  Serializers encode Elixir terms to binary for storage in backends like Redis,
  and decode them back on retrieval.

  ## Built-in serializers

    * `Cachetastic.Serializers.JSON` — JSON via Jason (default)
    * `Cachetastic.Serializers.ErlangTerm` — Erlang external term format

  ## Configuration

      config :cachetastic, serializer: Cachetastic.Serializers.JSON

  ## Custom serializer

      defmodule MyApp.MsgpackSerializer do
        @behaviour Cachetastic.Serializer

        @impl true
        def encode(term), do: Msgpax.pack(term)

        @impl true
        def decode(binary), do: Msgpax.unpack(binary)
      end
  """

  @callback encode(term()) :: {:ok, binary()} | {:error, term()}
  @callback decode(binary()) :: {:ok, term()} | {:error, term()}

  @doc """
  Returns the configured serializer module.
  """
  def configured do
    Application.get_env(:cachetastic, :serializer, Cachetastic.Serializers.JSON)
  end

  @doc """
  Encodes a term using the configured serializer.
  """
  def encode(term) do
    configured().encode(term)
  end

  @doc """
  Decodes a binary using the configured serializer.
  """
  def decode(binary) do
    configured().decode(binary)
  end
end

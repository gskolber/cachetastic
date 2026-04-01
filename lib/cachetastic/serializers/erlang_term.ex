defmodule Cachetastic.Serializers.ErlangTerm do
  @moduledoc """
  Erlang external term format serializer.

  Uses `:erlang.term_to_binary/1` and `:erlang.binary_to_term/2` with the
  `:safe` option to prevent atom creation from untrusted data.
  """
  @behaviour Cachetastic.Serializer

  @impl true
  def encode(term) do
    {:ok, :erlang.term_to_binary(term)}
  rescue
    e -> {:error, e}
  end

  @impl true
  def decode(binary) do
    {:ok, :erlang.binary_to_term(binary, [:safe])}
  rescue
    e -> {:error, e}
  end
end

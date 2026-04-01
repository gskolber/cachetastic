defmodule Cachetastic.Serializers.JSON do
  @moduledoc """
  JSON serializer using Jason.
  """
  @behaviour Cachetastic.Serializer

  @impl true
  def encode(term) do
    Jason.encode(term)
  end

  @impl true
  def decode(binary) do
    Jason.decode(binary)
  end
end

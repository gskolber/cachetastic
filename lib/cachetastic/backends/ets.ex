defmodule Cachetastic.Backend.ETS do
  @behaviour Cachetastic.Behaviour

  def start_link(_opts) do
    :ets.new(:cachetastic, [:named_table, :public, :set])
    {:ok, self()}
  end

  def put(_pid, key, value, _ttl \\ nil) do
    :ets.insert(:cachetastic, {key, value})
    :ok
  end

  def get(_pid, key) do
    case :ets.lookup(:cachetastic, key) do
      [{^key, value}] -> {:ok, value}
      _ -> :error
    end
  end

  def delete(_pid, key) do
    :ets.delete(:cachetastic, key)
    :ok
  end

  def clear(_pid) do
    :ets.delete_all_objects(:cachetastic)
    :ok
  end
end

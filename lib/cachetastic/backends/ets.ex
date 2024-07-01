defmodule Cachetastic.Backend.ETS do
  @behaviour Cachetastic.Behaviour

  def start_link(opts) do
    table_name = Keyword.get(opts, :table_name, :cachetastic)
    ttl = Keyword.get(opts, :ttl, 600)

    if :ets.info(table_name) == :undefined do
      :ets.new(table_name, [:named_table, :public, :set])
    end

    {:ok,
     %{
       table_name: table_name,
       ttl: ttl
     }}
  end

  def put(state, key, value, _ttl \\ nil) do
    :ets.insert(state.table_name, {key, value})
    :ok
  end

  def get(state, key) do
    case :ets.lookup(state.table_name, key) do
      [{^key, value}] -> {:ok, value}
      _ -> :error
    end
  end

  def delete(state, key) do
    :ets.delete(state.table_name, key)
    :ok
  end

  def clear(state) do
    :ets.delete_all_objects(state.table_name)
    :ok
  end
end

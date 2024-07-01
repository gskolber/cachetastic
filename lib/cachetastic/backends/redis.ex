defmodule Cachetastic.Backend.Redis do
  @behaviour Cachetastic.Behaviour

  def start_link(opts) do
    Redix.start_link(opts)
  end

  def put(conn, key, value, ttl \\ nil) do
    Redix.command(conn, ["SET", key, value])
    if ttl, do: Redix.command(conn, ["EXPIRE", key, ttl])
    :ok
  end

  def get(conn, key) do
    case Redix.command(conn, ["GET", key]) do
      {:ok, nil} -> :error
      {:ok, value} -> {:ok, value}
      _ -> :error
    end
  end

  def delete(conn, key) do
    Redix.command(conn, ["DEL", key])
    :ok
  end

  def clear(conn) do
    Redix.command(conn, ["FLUSHDB"])
    :ok
  end
end

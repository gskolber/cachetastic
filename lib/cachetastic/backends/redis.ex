defmodule Cachetastic.Backend.Redis do
  @behaviour Cachetastic.Behaviour

  def start_link(opts) do
    {:ok, conn} = Redix.start_link(host: opts[:host], port: opts[:port])
    {:ok, conn}
  end

  def put(conn, key, value, ttl \\ nil) do
    case Redix.command(conn, ["SET", key, value]) do
      {:ok, "OK"} ->
        if ttl, do: Redix.command(conn, ["EXPIRE", key, ttl])
        :ok

      error ->
        error
    end
  end

  def get(conn, key) do
    case Redix.command(conn, ["GET", key]) do
      {:ok, nil} -> :error
      {:ok, value} -> {:ok, value}
      error -> error
    end
  end

  def delete(conn, key) do
    case Redix.command(conn, ["DEL", key]) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def clear(conn) do
    case Redix.command(conn, ["FLUSHDB"]) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end

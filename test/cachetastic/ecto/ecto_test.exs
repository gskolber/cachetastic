defmodule Cachetastic.EctoTest do
  use ExUnit.Case

  alias Cachetastic.TestRepo, as: Repo
  alias Cachetastic.TestSchema
  import Ecto.Query

  setup do
    Repo.start_link()
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    :ok
  end

  test "get_with_cache stores and retrieves data correctly" do
    %TestSchema{name: "test_name", age: 20} |> Repo.insert()

    query = from(t in TestSchema, where: t.age > 10)

    # First call, should fetch from DB and cache it
    {:ok, records} = Repo.get_with_cache(query)
    assert length(records) > 0

    # Second call, should fetch from cache
    {:ok, cached_records} = Repo.get_with_cache(query)
    assert cached_records == records
  end

  test "invalidate_cache removes the cache entry" do
    %TestSchema{name: "test_name", age: 20} |> Repo.insert()
    query = from(t in TestSchema, where: t.age > 10)

    # Cache the result
    {:ok, _records} = Repo.get_with_cache(query)

    # Invalidate the cache
    Repo.invalidate_cache(query)

    # Fetch again, should not be from cache
    {:ok, records} = Repo.get_with_cache(query)
    assert length(records) > 0
  end
end

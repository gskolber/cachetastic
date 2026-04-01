defmodule Cachetastic.NamedCachesTest do
  use ExUnit.Case

  setup do
    Application.put_env(:cachetastic, :backends,
      primary: :ets,
      ets: [],
      fault_tolerance: [primary: :ets]
    )

    :ok
  end

  test "different named caches are isolated" do
    Cachetastic.put(:cache_a, "key", "value_a", nil)
    Cachetastic.put(:cache_b, "key", "value_b", nil)

    assert {:ok, "value_a"} = Cachetastic.get(:cache_a, "key")
    assert {:ok, "value_b"} = Cachetastic.get(:cache_b, "key")
  end

  test "default cache is separate from named caches" do
    Cachetastic.put("shared_key", "default_value")
    Cachetastic.put(:custom, "shared_key", "custom_value", nil)

    assert {:ok, "default_value"} = Cachetastic.get("shared_key")
    assert {:ok, "custom_value"} = Cachetastic.get(:custom, "shared_key")
  end

  test "clear only affects the specified cache" do
    Cachetastic.put(:cache_x, "key", "x_value", nil)
    Cachetastic.put(:cache_y, "key", "y_value", nil)

    Cachetastic.clear(:cache_x)

    assert {:error, :not_found} = Cachetastic.get(:cache_x, "key")
    assert {:ok, "y_value"} = Cachetastic.get(:cache_y, "key")
  end

  test "delete only affects the specified cache" do
    Cachetastic.put(:cache_m, "key", "m_value", nil)
    Cachetastic.put(:cache_n, "key", "n_value", nil)

    Cachetastic.delete(:cache_m, "key")

    assert {:error, :not_found} = Cachetastic.get(:cache_m, "key")
    assert {:ok, "n_value"} = Cachetastic.get(:cache_n, "key")
  end
end

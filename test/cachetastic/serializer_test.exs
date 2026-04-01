defmodule Cachetastic.SerializerTest do
  use ExUnit.Case

  alias Cachetastic.Serializers.ErlangTerm
  alias Cachetastic.Serializers.JSON

  describe "JSON serializer" do
    test "encode and decode a map" do
      data = %{"name" => "test", "value" => 42}
      assert {:ok, encoded} = JSON.encode(data)
      assert {:ok, ^data} = JSON.decode(encoded)
    end

    test "encode and decode a list" do
      data = [1, 2, 3]
      assert {:ok, encoded} = JSON.encode(data)
      assert {:ok, ^data} = JSON.decode(encoded)
    end

    test "returns error for non-encodable data" do
      assert {:error, _} = JSON.encode({:tuple, "not json"})
    end
  end

  describe "ErlangTerm serializer" do
    test "encode and decode a map" do
      data = %{name: "test", value: 42}
      assert {:ok, encoded} = ErlangTerm.encode(data)
      assert {:ok, ^data} = ErlangTerm.decode(encoded)
    end

    test "encode and decode a tuple" do
      data = {:ok, "value", 123}
      assert {:ok, encoded} = ErlangTerm.encode(data)
      assert {:ok, ^data} = ErlangTerm.decode(encoded)
    end

    test "preserves atoms" do
      data = %{key: :some_atom}
      assert {:ok, encoded} = ErlangTerm.encode(data)
      assert {:ok, ^data} = ErlangTerm.decode(encoded)
    end
  end

  describe "configured/0" do
    test "defaults to JSON" do
      Application.delete_env(:cachetastic, :serializer)
      assert Cachetastic.Serializer.configured() == JSON
    end

    test "respects configuration" do
      Application.put_env(:cachetastic, :serializer, ErlangTerm)
      assert Cachetastic.Serializer.configured() == ErlangTerm
      Application.delete_env(:cachetastic, :serializer)
    end
  end
end

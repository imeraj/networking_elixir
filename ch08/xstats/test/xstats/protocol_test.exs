defmodule XStats.ProtocolTest do
  use ExUnit.Case, async: true

  import XStats.Protocol

  describe "parse_metrics/1" do
    test "can parse :gauge metrics" do
      assert {metrics, errors} =
               parse_metrics("""
               set:20|g
               foobar
               float:20.04|g
               set:0|g\
               """)

      assert metrics == [
               {:gauge, "set", 20},
               {:gauge, "float", 20.04},
               {:gauge, "set", 0}
             ]

      assert errors == ["invalid line format: \"foobar\""]
    end

    test "can parse :counter metrics" do
      assert {[{:counter, "reqs", 3}], _errors} =
               parse_metrics("""
               reqs:3|c
               foo
               bar
               """)
    end

    test "returns error if the type of the metric is invalid" do
      assert {[], _errors} = parse_metrics("duration:3s\nfoo\nbar")
    end
  end

  describe "encode_metric/1" do
    test "with :counter" do
      assert encode({:counter, "reqs", 10}) == "reqs:10|c\n"
      assert encode({:counter, "reqs", 0}) == "reqs:0|c\n"
      assert encode({:counter, "reqs", 10.3}) == "reqs:10.3|c\n"
    end

    test "with :gauge" do
      assert encode({:gauge, "val", 1004}) == "val:1004|g\n"
      assert encode({:gauge, "val", 0}) == "val:0|g\n"
      assert encode({:gauge, "val", 10.3}) == "val:10.3|g\n"
    end
  end

  defp encode(metric) do
    metric |> encode_metric() |> IO.iodata_to_binary()
  end
end

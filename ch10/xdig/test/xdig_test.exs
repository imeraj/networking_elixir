defmodule XdigTest do
  use ExUnit.Case
  doctest Xdig

  test "greets the world" do
    assert Xdig.hello() == :world
  end
end

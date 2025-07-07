defmodule SillyGameTest do
  use ExUnit.Case
  doctest SillyGame

  test "greets the world" do
    assert SillyGame.hello() == :world
  end
end

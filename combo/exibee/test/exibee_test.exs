defmodule ExibeeTest do
  use ExUnit.Case
  doctest Exibee

  test "greets the world" do
    assert Exibee.hello() == :world
  end
end

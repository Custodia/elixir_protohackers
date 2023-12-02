defmodule PriceServerTest do
  use ExUnit.Case
  doctest PriceServer

  test "greets the world" do
    assert PriceServer.hello() == :world
  end
end

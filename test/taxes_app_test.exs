defmodule TaxesAppTest do
  use ExUnit.Case
  doctest TaxesApp

  test "greets the world" do
    assert TaxesApp.hello() == :world
  end
end

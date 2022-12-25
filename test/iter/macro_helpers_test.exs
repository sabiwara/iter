defmodule Iter.MacroHelpersTest do
  use ExUnit.Case, async: true
  doctest Iter.MacroHelpers, import: true

  alias Iter.MacroHelpers

  describe "apply_fun/2" do
    test "variable" do
      assert applied_code(quote do: fun) == "fun.(var)"
    end

    test "fn identity" do
      assert applied_code(quote do: fn x -> x end) == "var"
    end

    test "capture identity" do
      assert applied_code(quote do: & &1) == "var"
    end

    test "capture with arity" do
      assert applied_code(quote do: &abs/1) == "abs(var)"
      assert applied_code(quote do: &String.upcase/1) == "String.upcase(var)"
    end

    test "fn inlining" do
      expected = "var * var"
      assert applied_code(quote do: fn x -> x * x end) == expected
    end

    test "capture inlining" do
      expected = "var * var"
      assert applied_code(quote do: &(&1 * &1)) == expected
    end

    test "fn is not inlined when non-variable arg" do
      input = quote do: some_call()
      expected = "(fn x -> x * x end).(some_call())"
      assert applied_code(quote(do: fn x -> x * x end), input) == expected
    end

    test "capture is not inlined when non-variable arg" do
      input = quote do: some_call()
      expected = "(&(&1 * &1)).(some_call())"
      assert applied_code(quote(do: &(&1 * &1)), input) == expected
    end

    test "fn with guards" do
      expected = "(fn x when x > 1 -> x end).(var)"
      assert applied_code(quote do: fn x when x > 1 -> x end) == expected
    end

    test "fn with match" do
      expected = "(fn [x] -> x end).(var)"
      assert applied_code(quote do: fn [x] -> x end) == expected
    end

    test "fn with incorrect arity" do
      expected = "(fn x, y -> x + y end).(var)"
      assert applied_code(quote do: fn x, y -> x + y end) == expected
    end

    test "capture with incorrect arity" do
      expected = "(&(&1 + &2)).(var)"
      assert applied_code(quote do: &(&1 + &2)) == expected
    end

    defp applied_code(fun, ast \\ Macro.var(:var, nil)) do
      fun
      |> MacroHelpers.apply_fun(ast)
      |> Macro.to_string()
    end
  end
end

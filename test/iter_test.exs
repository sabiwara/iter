defmodule IterTest do
  use ExUnit.Case, async: true
  require Iter
  doctest Iter

  defmacrop to_ast(ast) do
    ast |> Macro.expand(__CALLER__) |> Macro.to_string() |> then(&(&1 <> "\n"))
  end

  defp seed(_) do
    :rand.seed(:exsss, {1, 2, 3})
    :ok
  end

  describe "to_list/2" do
    test "simple call" do
      assert Iter.to_list([10, 100]) == [10, 100]
      assert Iter.to_list(1..3) == [1, 2, 3]
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 ** 2)) |> Iter.to_list() == [1, 4, 9]
      assert 1..3 |> Iter.map(&(&1 ** 2)) |> Iter.to_list() == [1, 4, 9]
    end

    test "ast (not breaking the pipe)" do
      expected = """
      acc = []

      acc =
        Enum.reduce([1, 2, 3], acc, fn elem, acc ->
          elem = elem ** 2
          [elem | acc]
        end)

      :lists.reverse(acc)
      """

      assert [1, 2, 3] |> Iter.map(&(&1 ** 2)) |> Iter.to_list() |> to_ast() ==
               expected
    end

    test "ast (collecting and breaking the pipe)" do
      expected = """
      Enum.map(Enum.to_list([1, 2, 3]), &(&1 ** 2))
      """

      assert [1, 2, 3] |> Iter.to_list() |> Iter.map(&(&1 ** 2)) |> to_ast() ==
               expected
    end
  end

  describe "map/2" do
    test "simple call" do
      assert Iter.map([10, 100], &(&1 ** 2)) == [100, 10000]
      assert Iter.map(1..3, &(&1 ** 2)) == [1, 4, 9]
    end

    test "pipeline" do
      assert Iter.map([1, 2, 3], &(&1 ** 2)) |> Iter.map(&to_string/1) == ["1", "4", "9"]
      assert Iter.map(1..3, &(&1 ** 2)) |> Iter.map(&to_string/1) == ["1", "4", "9"]
    end

    test "ast" do
      assert Iter.map([1, 2, 3], &(&1 ** 2)) |> Iter.map(&to_string/1) |> to_ast() == """
             acc = []

             acc =
               Enum.reduce([1, 2, 3], acc, fn elem, acc ->
                 elem = elem ** 2
                 elem = to_string(elem)
                 [elem | acc]
               end)

             :lists.reverse(acc)
             """
    end
  end

  describe "with_index/1" do
    test "simple call" do
      assert Iter.with_index([:a, :b, :c]) == [a: 0, b: 1, c: 2]
      assert Iter.with_index(1..3) == [{1, 0}, {2, 1}, {3, 2}]
    end

    test "pipeline" do
      assert [:a, :b, :c] |> Iter.map(& &1) |> Iter.with_index() == [a: 0, b: 1, c: 2]
      assert 1..3 |> Iter.map(& &1) |> Iter.with_index() == [{1, 0}, {2, 1}, {3, 2}]
    end
  end

  describe "with_index/2" do
    test "simple call - offset" do
      assert Iter.with_index([:a, :b, :c], 100) == [a: 100, b: 101, c: 102]
      assert Iter.with_index(1..3, 100) == [{1, 100}, {2, 101}, {3, 102}]
    end

    test "pipeline - offset" do
      assert [:a, :b, :c] |> Iter.map(& &1) |> Iter.with_index(100) == [a: 100, b: 101, c: 102]
      assert 1..3 |> Iter.map(& &1) |> Iter.with_index(100) == [{1, 100}, {2, 101}, {3, 102}]
    end

    test "simple call - function" do
      assert Iter.with_index([:a, :b, :c], &{&2, &1}) == [{0, :a}, {1, :b}, {2, :c}]
      assert Iter.with_index(1..3, &{&2, &1}) == [{0, 1}, {1, 2}, {2, 3}]

      assert Iter.with_index(1..3, fn x, i when x > 0 -> {i, x} end) == [{0, 1}, {1, 2}, {2, 3}]
    end

    test "pipeline - function" do
      assert [:a, :b, :c] |> Iter.map(& &1) |> Iter.with_index(&{&2, &1}) ==
               [{0, :a}, {1, :b}, {2, :c}]

      assert 1..3 |> Iter.map(& &1) |> Iter.with_index(&{&2, &1}) == [{0, 1}, {1, 2}, {2, 3}]
    end
  end

  describe "match/2" do
    test "simple call" do
      assert [%{a: 1}, nil, %{a: 3}, %{}] |> Iter.match(%{a: a}, a * 2) == [2, 6]
      assert 1..4 |> Iter.match(x when rem(x, 2) == 1, x) == [1, 3]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.match(x when rem(x, 2) == 1, x) == [1, 3]
      assert 1..4 |> Iter.map(& &1) |> Iter.match(x when rem(x, 2) == 1, x) == [1, 3]
    end
  end

  describe "filter/2" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.filter(&(rem(&1, 2) == 1)) == [1, 3]
      assert 1..4 |> Iter.filter(&(rem(&1, 2) == 1)) == [1, 3]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.filter(&(rem(&1, 2) == 1)) == [1, 3]
      assert 1..4 |> Iter.map(& &1) |> Iter.filter(&(rem(&1, 2) == 1)) == [1, 3]
    end
  end

  describe "reject/2" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.reject(&(rem(&1, 2) == 1)) == [2, 4]
      assert 1..4 |> Iter.reject(&(rem(&1, 2) == 1)) == [2, 4]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.reject(&(rem(&1, 2) == 1)) == [2, 4]
      assert 1..4 |> Iter.map(& &1) |> Iter.reject(&(rem(&1, 2) == 1)) == [2, 4]
    end
  end

  describe "split_with/2" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.split_with(&(rem(&1, 2) == 1)) == {[1, 3], [2, 4]}
      assert 1..4 |> Iter.split_with(&(rem(&1, 2) == 1)) == {[1, 3], [2, 4]}
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.split_with(&(rem(&1, 2) == 1)) ==
               {[1, 3], [2, 4]}

      assert 1..4 |> Iter.map(& &1) |> Iter.split_with(&(rem(&1, 2) == 1)) == {[1, 3], [2, 4]}
    end
  end

  describe "take/2" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.take(3) == [1, 2, 3]
      assert 1..100_000 |> Iter.take(3) == [1, 2, 3]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.take(3) == [1, 2, 3]
      assert 1..100_000 |> Iter.map(& &1) |> Iter.take(3) == [1, 2, 3]
    end

    test "infinite streams" do
      assert ~c"defde" = Stream.cycle(~c"abc") |> Iter.map(&(&1 + 3)) |> Iter.take(5)
    end

    test "negative indexes raise" do
      assert_raise FunctionClauseError, fn ->
        1..100 |> Iter.map(&(&1 + 3)) |> Iter.take(-2)
      end
    end

    test "stacktrace line" do
      stacktrace =
        try do
          Code.eval_file("test/fixtures/take_error.exs")
        rescue
          FunctionClauseError -> __STACKTRACE__
        end

      assert [
               {Iter.Runtime, :validate_positive_integer, [-1], _},
               {:elixir_eval, :__FILE__, 1, [file: file, line: 4]}
               | _
             ] = stacktrace

      assert to_string(file) |> String.ends_with?("fixtures/take_error.exs")
    end
  end

  describe "drop/2" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.drop(2) == [3, 4]
      assert 1..4 |> Iter.drop(2) == [3, 4]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.drop(2) == [3, 4]
      assert 1..4 |> Iter.map(& &1) |> Iter.drop(2) == [3, 4]
    end
  end

  describe "split/2" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.split(2) == {[1, 2], [3, 4]}
      assert 1..4 |> Iter.split(2) == {[1, 2], [3, 4]}
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.split(2) == {[1, 2], [3, 4]}
      assert 1..4 |> Iter.map(& &1) |> Iter.split(2) == {[1, 2], [3, 4]}
    end
  end

  describe "slice/2" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.slice(1..2) == [2, 3]
      assert 1..4 |> Iter.slice(1..2) == [2, 3]

      assert 0..99 |> Iter.slice(5..15//5) == [5, 10, 15]
      assert 0..99 |> Iter.slice(25..15//5) == []
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(&(&1 * 2)) |> Iter.slice(1..2) == [4, 6]
      assert 1..4 |> Iter.map(&(&1 * 2)) |> Iter.slice(1..2) == [4, 6]

      assert 0..99 |> Iter.map(&(&1 * 2)) |> Iter.slice(5..15//5) == [10, 20, 30]
      assert 0..99 |> Iter.map(&(&1 * 2)) |> Iter.slice(25..15//5) == []
    end
  end

  describe "slice/3" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.slice(1, 2) == [2, 3]
      assert 1..4 |> Iter.slice(1, 2) == [2, 3]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(&(&1 * 2)) |> Iter.slice(1, 2) == [4, 6]
      assert 1..4 |> Iter.map(&(&1 * 2)) |> Iter.slice(1, 2) == [4, 6]
    end
  end

  describe "take_every/2" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.take_every(2) == [1, 3]
      assert 1..4 |> Iter.take_every(2) == [1, 3]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(&(&1 * 2)) |> Iter.take_every(2) == [2, 6]
      assert 1..4 |> Iter.map(&(&1 * 2)) |> Iter.take_every(2) == [2, 6]
    end
  end

  describe "drop_every/2" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.drop_every(2) == [2, 4]
      assert 1..4 |> Iter.drop_every(2) == [2, 4]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(&(&1 * 2)) |> Iter.drop_every(2) == [4, 8]
      assert 1..4 |> Iter.map(&(&1 * 2)) |> Iter.drop_every(2) == [4, 8]
    end
  end

  describe "take_while/2" do
    test "simple call" do
      assert [1, 2, 3, 4, 0] |> Iter.take_while(&(&1 < 3)) == [1, 2]
      assert 1..100_000 |> Iter.take_while(&(&1 < 3)) == [1, 2]
    end

    test "pipeline" do
      assert [1, 2, 3, 4, 0] |> Iter.flat_map(&[&1]) |> Iter.take_while(&(&1 < 3)) == [1, 2]
      assert 1..100_000 |> Iter.flat_map(&[&1]) |> Iter.take_while(&(&1 < 3)) == [1, 2]
    end
  end

  describe "drop_while/2" do
    test "simple call" do
      assert [1, 2, 3, 4, 0] |> Iter.drop_while(&(&1 < 3)) == [3, 4, 0]
      assert 1..4 |> Iter.drop_while(&(&1 < 3)) == [3, 4]
    end

    test "pipeline" do
      assert [1, 2, 3, 4, 0] |> Iter.flat_map(&[&1]) |> Iter.drop_while(&(&1 < 3)) == [3, 4, 0]
      assert 1..4 |> Iter.flat_map(&[&1]) |> Iter.drop_while(&(&1 < 3)) == [3, 4]
    end
  end

  describe "split_while/2" do
    test "simple call" do
      assert [1, 2, 3, 4, 0] |> Iter.split_while(&(&1 < 3)) == {[1, 2], [3, 4, 0]}
      assert 1..4 |> Iter.split_while(&(&1 < 3)) == {[1, 2], [3, 4]}
    end

    test "pipeline" do
      assert [1, 2, 3, 4, 0] |> Iter.flat_map(&[&1]) |> Iter.split_while(&(&1 < 3)) ==
               {[1, 2], [3, 4, 0]}

      assert 1..4 |> Iter.flat_map(&[&1]) |> Iter.split_while(&(&1 < 3)) == {[1, 2], [3, 4]}
    end
  end

  describe "uniq/1" do
    test "simple call" do
      assert [1, 2, 1, 2] |> Iter.uniq() == [1, 2]
      assert 1..4 |> Iter.uniq() == [1, 2, 3, 4]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(&div(&1, 2)) |> Iter.uniq() == [0, 1, 2]
      assert 1..4 |> Iter.map(&div(&1, 2)) |> Iter.uniq() == [0, 1, 2]
    end
  end

  describe "uniq_by/2" do
    test "simple call" do
      assert [1, 2, 4, 3] |> Iter.uniq_by(&div(&1, 2)) == [1, 2, 4]
      assert 1..4 |> Iter.uniq_by(&div(&1, 2)) == [1, 2, 4]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.uniq_by(&div(&1, 2)) == [1, 2, 4]
      assert 1..4 |> Iter.map(& &1) |> Iter.uniq_by(&div(&1, 2)) == [1, 2, 4]
    end
  end

  describe "dedup/1" do
    test "simple call" do
      assert [1, 2, 2, 2, 1] |> Iter.dedup() == [1, 2, 1]
      assert 1..4 |> Iter.dedup() == [1, 2, 3, 4]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(&div(&1, 2)) |> Iter.dedup() == [0, 1, 2]
      assert 1..4 |> Iter.map(&div(&1, 2)) |> Iter.dedup() == [0, 1, 2]
    end
  end

  describe "dedup_by/2" do
    test "simple call" do
      assert [1, 2, 3, 4, 1] |> Iter.dedup_by(&div(&1, 2)) == [1, 2, 4, 1]
      assert 1..4 |> Iter.dedup_by(&div(&1, 2)) == [1, 2, 4]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.dedup_by(&div(&1, 2)) == [1, 2, 4]
      assert 1..4 |> Iter.map(& &1) |> Iter.dedup_by(&div(&1, 2)) == [1, 2, 4]
    end
  end

  describe "reduce/2" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.reduce(&{&2, &1}) == {{1, 2}, 3}
      assert 1..3 |> Iter.reduce(&{&2, &1}) == {{1, 2}, 3}

      assert_raise Enum.EmptyError, fn -> 1..0//1 |> Iter.reduce(&{&2, &1}) end
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(& &1) |> Iter.reduce(&{&2, &1}) == {{1, 2}, 3}
      assert 1..3 |> Iter.map(& &1) |> Iter.reduce(&{&2, &1}) == {{1, 2}, 3}

      assert_raise Enum.EmptyError, fn -> 1..0//1 |> Iter.map(& &1) |> Iter.reduce(&{&2, &1}) end
    end
  end

  describe "reduce/3" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.reduce(0, &{&2, &1}) == {{{0, 1}, 2}, 3}
      assert 1..3 |> Iter.reduce(0, &{&2, &1}) == {{{0, 1}, 2}, 3}
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(& &1) |> Iter.reduce(0, &{&2, &1}) == {{{0, 1}, 2}, 3}
      assert 1..3 |> Iter.map(& &1) |> Iter.reduce(0, &{&2, &1}) == {{{0, 1}, 2}, 3}
    end
  end

  describe "map_reduce/3" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.map_reduce(0, &{&2, &2 + &1}) == {[0, 1, 3, 6], 10}
      assert 1..4 |> Iter.map_reduce(0, &{&2, &2 + &1}) == {[0, 1, 3, 6], 10}
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.map_reduce(0, &{&2, &2 + &1}) ==
               {[0, 1, 3, 6], 10}

      assert 1..4 |> Iter.map(& &1) |> Iter.map_reduce(0, &{&2, &2 + &1}) == {[0, 1, 3, 6], 10}
    end
  end

  describe "scan/3" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.scan(1, &*/2) == [1, 2, 6, 24]
      assert 1..4 |> Iter.scan(1, &*/2) == [1, 2, 6, 24]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.scan(1, &*/2) == [1, 2, 6, 24]
      assert 1..4 |> Iter.map(& &1) |> Iter.scan(1, &*/2) == [1, 2, 6, 24]
    end
  end

  describe "into/2" do
    test "simple call" do
      assert [1, 2, 3, 2] |> Iter.into(MapSet.new()) == MapSet.new([1, 2, 3])
      assert 1..3 |> Iter.into(MapSet.new()) == MapSet.new([1, 2, 3])
    end

    test "pipeline (empty map)" do
      assert [1, 2, 3, 4] |> Iter.map(&{rem(&1, 2), &1}) |> Iter.into(%{}) == %{0 => 4, 1 => 3}
      assert 1..4 |> Iter.map(&{rem(&1, 2), &1}) |> Iter.into(%{}) == %{0 => 4, 1 => 3}

      assert [1, 2, 3, 4] |> Iter.map(&{rem(&1, 2), &1}) |> Iter.into(%{1 => :foo, 2 => :bar}) ==
               %{0 => 4, 1 => 3, 2 => :bar}
    end

    test "pipeline (map set)" do
      assert [1, 2, 3, 2] |> Iter.map(&(&1 * 2)) |> Iter.into(MapSet.new()) ==
               MapSet.new([2, 4, 6])

      assert 1..3 |> Iter.map(&(&1 * 2)) |> Iter.into(MapSet.new()) == MapSet.new([2, 4, 6])
    end

    test "pipeline (empty list)" do
      assert [1, 2, 3, 4] |> Enum.into([]) == [1, 2, 3, 4]
      assert [1, 2, 3, 4] |> Iter.map(&(&1 * 2)) |> Iter.into([]) == [2, 4, 6, 8]
      assert 1..4 |> Iter.map(&(&1 * 2)) |> Iter.into([]) == [2, 4, 6, 8]
    end

    test "ast (empty map)" do
      expected = """
      Map.new([1, 2, 3] |> Iter.map(&{&1 * 2, &1}))
      """

      assert [1, 2, 3] |> Iter.map(&{&1 * 2, &1}) |> Iter.into(%{}) |> to_ast() == expected
    end

    test "ast (non-empty map)" do
      expected = """
      acc = %{0 => 0}

      acc =
        Enum.reduce([1, 2, 3], acc, fn elem, acc ->
          elem = {elem * 2, elem}

          (
            {key, value} = elem
            Map.put(acc, key, value)
          )
        end)

      acc
      """

      assert [1, 2, 3] |> Iter.map(&{&1 * 2, &1}) |> Iter.into(%{0 => 0}) |> to_ast() ==
               expected
    end

    test "ast (empty list)" do
      expected = """
      acc = []

      acc =
        Enum.reduce([1, 2, 3], acc, fn elem, acc ->
          elem = elem * 2
          [elem | acc]
        end)

      :lists.reverse(acc)
      """

      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.into([]) |> to_ast() == expected
    end

    test "ast (other)" do
      expected = """
      {initial_acc, into_fun} = Collectable.into(acc)
      acc = initial_acc

      acc =
        try do
          Enum.reduce([1, 2, 3], acc, fn elem, acc ->
            elem = elem * 2
            into_fun.(acc, {:cont, elem})
          end)
        catch
          kind, reason ->
            into_fun.(initial_acc, :halt)
            :erlang.raise(kind, reason, __STACKTRACE__)
        else
          acc -> into_fun.(acc, :done)
        end

      acc
      """

      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.into(acc) |> to_ast() ==
               expected
    end
  end

  describe "into/3" do
    test "simple call" do
      assert [1, 2, 3, 2] |> Iter.into(MapSet.new(), &(&1 * 2)) == MapSet.new([2, 4, 6])
      assert 1..3 |> Iter.into(MapSet.new(), &(&1 * 2)) == MapSet.new([2, 4, 6])
    end

    test "pipeline (empty map)" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.into(%{}, &{rem(&1, 2), &1}) ==
               %{0 => 4, 1 => 3}

      assert 1..4 |> Iter.map(& &1) |> Iter.into(%{}, &{rem(&1, 2), &1}) == %{0 => 4, 1 => 3}
    end

    test "pipeline (map set)" do
      assert [1, 2, 3, 2] |> Iter.map(&(&1 * 2)) |> Iter.into(MapSet.new()) ==
               MapSet.new([2, 4, 6])

      assert 1..3 |> Iter.map(&(&1 * 2)) |> Iter.into(MapSet.new()) == MapSet.new([2, 4, 6])
    end
  end

  describe "each/3" do
    test "simple call" do
      assert [1, 2] |> Iter.each(&send(self(), &1)) == :ok
      # note: unlike `assert_received 1`, this checks the order
      assert 1 = assert_received(_)
      assert 2 = assert_received(_)

      assert 1..2 |> Iter.each(&send(self(), &1)) == :ok
      assert 1 = assert_received(_)
      assert 2 = assert_received(_)
    end

    test "pipeline" do
      assert [1, 2] |> Iter.map(&(&1 * 2)) |> Iter.each(&send(self(), &1)) == :ok
      assert 2 = assert_received(_)
      assert 4 = assert_received(_)

      assert 1..2 |> Iter.map(&(&1 * 2)) |> Iter.each(&send(self(), &1)) == :ok
      assert 2 = assert_received(_)
      assert 4 = assert_received(_)
    end
  end

  describe "count/1" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.count() == 4
      assert 1..4 |> Iter.count() == 4
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.count() == 4
      assert 1..4 |> Iter.map(& &1) |> Iter.count() == 4
    end
  end

  describe "count/2" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.count(&(rem(&1, 2) == 1)) == 2
      assert 1..4 |> Iter.count(&(rem(&1, 2) == 1)) == 2
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.count(&(rem(&1, 2) == 1)) == 2
      assert 1..4 |> Iter.map(& &1) |> Iter.count(&(rem(&1, 2) == 1)) == 2
    end
  end

  describe "sum/1" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.sum() == 10
      assert 1..4 |> Iter.sum() == 10
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.sum() == 10
      assert 1..4 |> Iter.map(& &1) |> Iter.sum() == 10
    end
  end

  describe "product/1" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.product() == 24
      assert 1..4 |> Iter.product() == 24
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.product() == 24
      assert 1..4 |> Iter.map(& &1) |> Iter.product() == 24
    end
  end

  describe "mean/1" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.mean() == 2.5
      assert 1..4 |> Iter.mean() == 2.5

      assert_raise Enum.EmptyError, fn -> [] |> Iter.mean() end
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(&(&1 * 2)) |> Iter.mean() === 5.0
      assert 1..4 |> Iter.map(&(&1 * 2)) |> Iter.mean() === 5.0

      assert_raise Enum.EmptyError, fn -> [] |> Iter.map(&(&1 * 2)) |> Iter.mean() end
    end
  end

  describe "max/1" do
    test "simple call" do
      assert [2, 4, 1, 3] |> Iter.max() == 4
      assert 1..4 |> Iter.max() == 4
    end

    test "pipeline" do
      assert [2, 4, 1, 3] |> Iter.map(& &1) |> Iter.max() == 4
      assert 1..4 |> Iter.map(& &1) |> Iter.max() == 4
    end
  end

  describe "min/1" do
    test "simple call" do
      assert [2, 4, 1, 3] |> Iter.min() == 1
      assert 1..4 |> Iter.min() == 1
    end

    test "pipeline" do
      assert [2, 4, 1, 3] |> Iter.map(& &1) |> Iter.min() == 1
      assert 1..4 |> Iter.map(& &1) |> Iter.min() == 1
    end
  end

  describe "frequencies/1" do
    test "simple call" do
      assert [:a, :b, :c, :b, :a] |> Iter.frequencies() == %{a: 2, b: 2, c: 1}
      assert 1..2 |> Iter.frequencies() == %{1 => 1, 2 => 1}
    end

    test "pipeline" do
      assert [2, 4, 1, 3] |> Iter.map(&div(&1, 2)) |> Iter.frequencies() ==
               %{0 => 1, 1 => 2, 2 => 1}

      assert 1..4 |> Iter.map(&div(&1, 2)) |> Iter.frequencies() == %{0 => 1, 1 => 2, 2 => 1}
    end
  end

  describe "frequencies_by/2" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.frequencies_by(&div(&1, 2)) == %{0 => 1, 1 => 2, 2 => 1}
      assert 1..4 |> Iter.frequencies_by(&div(&1, 2)) == %{0 => 1, 1 => 2, 2 => 1}
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.frequencies_by(&div(&1, 2)) ==
               %{0 => 1, 1 => 2, 2 => 1}

      assert 1..4 |> Iter.map(& &1) |> Iter.frequencies_by(&div(&1, 2)) ==
               %{0 => 1, 1 => 2, 2 => 1}
    end
  end

  describe "group_by/2" do
    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.group_by(&div(&1, 2)) == %{0 => [1], 1 => [2, 3], 2 => [4]}
      assert 1..4 |> Iter.group_by(&div(&1, 2)) == %{0 => [1], 1 => [2, 3], 2 => [4]}
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(& &1) |> Iter.group_by(&div(&1, 2)) ==
               %{0 => [1], 1 => [2, 3], 2 => [4]}

      assert 1..4 |> Iter.map(& &1) |> Iter.group_by(&div(&1, 2)) ==
               %{0 => [1], 1 => [2, 3], 2 => [4]}
    end
  end

  describe "group_by/3" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.group_by(&div(&1, 2), &(&1 ** 2)) == %{0 => [1], 1 => [4, 9]}

      assert 1..3 |> Iter.group_by(&div(&1, 2), &(&1 ** 2)) == %{0 => [1], 1 => [4, 9]}
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(& &1) |> Iter.group_by(&div(&1, 2), &(&1 ** 2)) ==
               %{0 => [1], 1 => [4, 9]}

      assert 1..3 |> Iter.map(& &1) |> Iter.group_by(&div(&1, 2), &(&1 ** 2)) ==
               %{0 => [1], 1 => [4, 9]}
    end
  end

  describe "join/1" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.join() == "123"
      assert 1..3 |> Iter.join() == "123"

      assert [] |> Iter.join() == ""
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 ** 2)) |> Iter.join() == "149"
      assert 1..3 |> Iter.map(&(&1 ** 2)) |> Iter.join() == "149"

      assert [] |> Iter.map(&(&1 ** 2)) |> Iter.join() == ""
    end
  end

  describe "join/2" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.join("-") == "1-2-3"
      assert 1..3 |> Iter.join("-") == "1-2-3"

      assert [] |> Iter.join("-") == ""
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 ** 2)) |> Iter.join("-") == "1-4-9"
      assert 1..3 |> Iter.map(&(&1 ** 2)) |> Iter.join("-") == "1-4-9"

      assert [] |> Iter.map(&(&1 ** 2)) |> Iter.join("-") == ""
    end
  end

  describe "map_join/2" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.map_join(&(&1 ** 2)) == "149"
      assert 1..3 |> Iter.map_join(&(&1 ** 2)) == "149"

      assert [] |> Iter.map_join(&(&1 ** 2)) == ""
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 - 1)) |> Iter.map_join(&(&1 ** 2)) == "014"
      assert 1..3 |> Iter.map(&(&1 - 1)) |> Iter.map_join(&(&1 ** 2)) == "014"

      assert [] |> Iter.map(&(&1 - 1)) |> Iter.map_join(&(&1 ** 2)) == ""
    end
  end

  describe "map_join/3" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.map_join("-", &(&1 ** 2)) == "1-4-9"
      assert 1..3 |> Iter.map_join("-", &(&1 ** 2)) == "1-4-9"

      assert [] |> Iter.map_join("-", &(&1 ** 2)) == ""
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 - 1)) |> Iter.map_join("-", &(&1 ** 2)) == "0-1-4"
      assert 1..3 |> Iter.map(&(&1 - 1)) |> Iter.map_join("-", &(&1 ** 2)) == "0-1-4"

      assert [] |> Iter.map(&(&1 - 1)) |> Iter.map_join("-", &(&1 ** 2)) == ""
    end
  end

  describe "empty?/1" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.empty?() == false
      assert 1..3 |> Iter.empty?() == false

      assert [] |> Iter.empty?() == true
      assert 1..0//1 |> Iter.empty?() == true
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.filter(&(&1 > 2)) |> Iter.empty?() == false
      assert 1..3 |> Iter.filter(&(&1 > 2)) |> Iter.empty?() == false

      assert [1, 2, 3] |> Iter.filter(&(&1 > 3)) |> Iter.empty?() == true
      assert 1..3 |> Iter.filter(&(&1 > 3)) |> Iter.empty?() == true
    end
  end

  describe "any?/1" do
    test "simple call" do
      assert [false, true] |> Iter.any?() == true
      assert 1..3 |> Iter.any?() == true

      assert [false] |> Iter.any?() == false
      assert 1..0//1 |> Iter.any?() == false
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 > 2)) |> Iter.any?() == true
      assert 1..3 |> Iter.map(&(&1 > 2)) |> Iter.any?() == true

      assert [1, 2, 3] |> Iter.map(&(&1 > 3)) |> Iter.any?() == false
      assert 1..3 |> Iter.map(&(&1 > 3)) |> Iter.any?() == false
    end
  end

  describe "any?/2" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.any?(&(&1 > 2)) == true
      assert 1..3 |> Iter.any?(&(&1 > 2)) == true

      assert [1, 2, 3] |> Iter.any?(&(&1 > 3)) == false
      assert 1..3 |> Iter.any?(&(&1 > 3)) == false
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(& &1) |> Iter.any?(&(&1 > 2)) == true
      assert 1..3 |> Iter.map(& &1) |> Iter.any?(&(&1 > 2)) == true

      assert [1, 2, 3] |> Iter.map(& &1) |> Iter.any?(&(&1 > 3)) == false
      assert 1..3 |> Iter.map(& &1) |> Iter.any?(&(&1 > 3)) == false
    end
  end

  describe "all?/1" do
    test "simple call" do
      assert [false, true] |> Iter.all?() == false

      assert [true] |> Iter.all?() == true
      assert 1..3 |> Iter.all?() == true

      assert [] |> Iter.all?() == true
      assert 1..0//1 |> Iter.all?() == true
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 < 4)) |> Iter.all?() == true
      assert 1..3 |> Iter.map(&(&1 < 4)) |> Iter.all?() == true

      assert [1, 2, 3] |> Iter.map(&(&1 < 3)) |> Iter.all?() == false
      assert 1..3 |> Iter.map(&(&1 < 3)) |> Iter.all?() == false
    end
  end

  describe "all?/2" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.all?(&(&1 < 4)) == true
      assert 1..3 |> Iter.all?(&(&1 < 4)) == true

      assert [1, 2, 3] |> Iter.all?(&(&1 < 3)) == false
      assert 1..3 |> Iter.all?(&(&1 < 3)) == false
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(& &1) |> Iter.all?(&(&1 < 4)) == true
      assert 1..3 |> Iter.map(& &1) |> Iter.all?(&(&1 < 4)) == true

      assert [1, 2, 3] |> Iter.map(& &1) |> Iter.all?(&(&1 < 3)) == false
      assert 1..3 |> Iter.map(& &1) |> Iter.all?(&(&1 < 3)) == false
    end
  end

  describe "member?/2" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.member?(2) == true
      assert 1..3 |> Iter.member?(2) == true

      assert [1, 2, 3] |> Iter.member?(4) == false
      assert 1..3 |> Iter.member?(4) == false
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.member?(4) == true
      assert 1..3 |> Iter.map(&(&1 * 2)) |> Iter.member?(4) == true

      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.member?(3) == false
      assert 1..3 |> Iter.map(&(&1 * 2)) |> Iter.member?(3) == false

      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.member?(4.0) == false
    end
  end

  describe "find/2,3" do
    test "simple call" do
      assert [2, 3, 4] |> Iter.find(&(rem(&1, 2) == 1)) == 3
      assert 2..4 |> Iter.find(&(rem(&1, 2) == 1)) == 3

      assert [2, 4, 6] |> Iter.find(&(rem(&1, 2) == 1)) == nil
      assert 2..6//2 |> Iter.find(&(rem(&1, 2) == 1)) == nil
    end

    test "pipeline" do
      assert [2, 3, 4] |> Iter.map(& &1) |> Iter.find(&(rem(&1, 2) == 1)) == 3
      assert 2..4 |> Iter.map(& &1) |> Iter.find(&(rem(&1, 2) == 1)) == 3

      assert [2, 4, 6] |> Iter.map(& &1) |> Iter.find(&(rem(&1, 2) == 1)) == nil
      assert 2..6//2 |> Iter.map(& &1) |> Iter.find(&(rem(&1, 2) == 1)) == nil

      assert [2, 4, 6] |> Iter.map(& &1) |> Iter.find(:none, &(rem(&1, 2) == 1)) == :none
    end
  end

  describe "find_value/2,3" do
    defp square_odd(x) do
      if rem(x, 2) == 1, do: x ** 2
    end

    test "simple call" do
      assert [2, 3, 4] |> Iter.find_value(&square_odd/1) == 9
      assert 2..4 |> Iter.find_value(&square_odd/1) == 9

      assert [2, 4, 6] |> Iter.find_value(&square_odd/1) == nil
      assert 2..6//2 |> Iter.find_value(&square_odd/1) == nil
    end

    test "pipeline" do
      assert [2, 3, 4] |> Iter.map(& &1) |> Iter.find_value(&square_odd/1) == 9
      assert 2..4 |> Iter.map(& &1) |> Iter.find_value(&square_odd/1) == 9

      assert [2, 4, 6] |> Iter.map(& &1) |> Iter.find_value(&square_odd/1) == nil
      assert 2..6//2 |> Iter.map(& &1) |> Iter.find_value(&square_odd/1) == nil

      assert 2..6//2 |> Iter.map(& &1) |> Iter.find_value(:none, &square_odd/1) == :none
    end
  end

  describe "find_index/2" do
    test "simple call" do
      assert [2, 3, 4] |> Iter.find_index(&(rem(&1, 2) == 1)) == 1
      assert 2..4 |> Iter.find_index(&(rem(&1, 2) == 1)) == 1

      assert [2, 4, 6] |> Iter.find_index(&(rem(&1, 2) == 1)) == nil
      assert 2..6//2 |> Iter.find_index(&(rem(&1, 2) == 1)) == nil
    end

    test "pipeline" do
      assert [2, 3, 4] |> Iter.map(& &1) |> Iter.find_index(&(rem(&1, 2) == 1)) == 1
      assert 2..4 |> Iter.map(& &1) |> Iter.find_index(&(rem(&1, 2) == 1)) == 1

      assert [2, 4, 6] |> Iter.map(& &1) |> Iter.find_index(&(rem(&1, 2) == 1)) == nil
      assert 2..6//2 |> Iter.map(& &1) |> Iter.find_index(&(rem(&1, 2) == 1)) == nil
    end
  end

  describe "at/2,3" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.at(1) == 2
      assert 1..3 |> Iter.at(1) == 2

      assert [1, 2, 3] |> Iter.at(3) == nil
      assert 1..3 |> Iter.at(3) == nil

      assert [1, 2, 3] |> Iter.at(3, :none) == :none
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.at(1) == 4
      assert 1..3 |> Iter.map(&(&1 * 2)) |> Iter.at(1) == 4

      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.at(3) == nil
      assert 1..3 |> Iter.map(&(&1 * 2)) |> Iter.at(3) == nil

      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.at(3, :none) == :none
    end
  end

  describe "fetch/2" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.fetch(1) == {:ok, 2}
      assert 1..3 |> Iter.fetch(1) == {:ok, 2}

      assert [1, 2, 3] |> Iter.fetch(3) == :error
      assert 1..3 |> Iter.fetch(3) == :error
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.fetch(1) == {:ok, 4}
      assert 1..3 |> Iter.map(&(&1 * 2)) |> Iter.fetch(1) == {:ok, 4}

      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.fetch(3) == :error
      assert 1..3 |> Iter.map(&(&1 * 2)) |> Iter.fetch(3) == :error
    end
  end

  describe "fetch!/2" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.fetch!(1) == 2
      assert 1..3 |> Iter.fetch!(1) == 2

      assert_raise Enum.OutOfBoundsError, fn -> [1, 2, 3] |> Iter.fetch!(3) end
      assert_raise Enum.OutOfBoundsError, fn -> 1..3 |> Iter.fetch!(3) end
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.fetch!(1) == 4
      assert 1..3 |> Iter.map(&(&1 * 2)) |> Iter.fetch!(1) == 4

      assert_raise Enum.OutOfBoundsError, fn ->
        [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.fetch!(3)
      end

      assert_raise Enum.OutOfBoundsError, fn ->
        1..3 |> Iter.map(&(&1 * 2)) |> Iter.fetch!(3)
      end
    end
  end

  describe "first/1,2" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.first() == 1
      assert 1..3 |> Iter.first() == 1

      assert [] |> Iter.first() == nil
      assert 1..0//1 |> Iter.first() == nil

      assert [] |> Iter.first(:none) == :none
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.first() == 2
      assert 1..3 |> Iter.map(&(&1 * 2)) |> Iter.first() == 2

      assert [] |> Iter.map(&(&1 * 2)) |> Iter.first() == nil
      assert 1..0//1 |> Iter.map(&(&1 * 2)) |> Iter.first() == nil

      assert [] |> Iter.map(&(&1 * 2)) |> Iter.first(:none) == :none
    end
  end

  describe "last/1,2" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.last() == 3
      assert 1..3 |> Iter.last() == 3

      assert [] |> Iter.last() == nil
      assert 1..0//1 |> Iter.last() == nil

      assert [] |> Iter.last(:none) == :none
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.last() == 6
      assert 1..3 |> Iter.map(&(&1 * 2)) |> Iter.last() == 6

      assert [] |> Iter.map(&(&1 * 2)) |> Iter.last() == nil
      assert 1..0//1 |> Iter.map(&(&1 * 2)) |> Iter.last() == nil

      assert [] |> Iter.map(&(&1 * 2)) |> Iter.last(:none) == :none
    end
  end

  describe "reverse/1,2" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.reverse() == [3, 2, 1]
      assert 1..3 |> Iter.reverse() == [3, 2, 1]

      assert [1, 2, 3] |> Iter.reverse([4, 5]) == [3, 2, 1, 4, 5]
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.reverse() == [6, 4, 2]
      assert 1..3 |> Iter.map(&(&1 * 2)) |> Iter.reverse() == [6, 4, 2]

      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.reverse([4, 5]) == [6, 4, 2, 4, 5]
    end
  end

  describe "sort/1" do
    test "simple call" do
      assert [2, 4, 1, 3] |> Iter.sort() == [1, 2, 3, 4]
      assert 4..1 |> Iter.sort() == [1, 2, 3, 4]
    end

    test "pipeline" do
      assert [2, 4, 1, 3] |> Iter.map(&(&1 * 2)) |> Iter.sort() == [2, 4, 6, 8]
      assert 4..1 |> Iter.map(&(&1 * 2)) |> Iter.sort() == [2, 4, 6, 8]
    end
  end

  describe "sort/2" do
    test "simple call" do
      assert [2, 4, 1, 3] |> Iter.sort(:desc) == [4, 3, 2, 1]
      assert 1..4 |> Iter.sort(:desc) == [4, 3, 2, 1]
    end

    test "pipeline" do
      assert [2, 4, 1, 3] |> Iter.map(&(&1 * 2)) |> Iter.sort(:desc) == [8, 6, 4, 2]
      assert 1..4 |> Iter.map(&(&1 * 2)) |> Iter.sort(:desc) == [8, 6, 4, 2]

      assert [2, 4, 1, 3] |> Iter.map(&(&1 * 2)) |> Iter.sort(&>=/2) == [8, 6, 4, 2]
    end
  end

  describe "random/1" do
    setup :seed

    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.random() == 3
      assert 1..4 |> Iter.random() == 1
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(&(&1 * 2)) |> Iter.random() == 6
      assert 1..4 |> Iter.map(&(&1 * 2)) |> Iter.random() == 2
    end
  end

  describe "take_random/2" do
    setup :seed

    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.take_random(2) == [3, 1]
      assert 1..4 |> Iter.take_random(2) == [2, 4]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(&(&1 * 2)) |> Iter.take_random(2) == [6, 2]
      assert 1..4 |> Iter.map(&(&1 * 2)) |> Iter.take_random(2) == [4, 8]
    end
  end

  describe "shuffle/1" do
    setup :seed

    test "simple call" do
      assert [1, 2, 3, 4] |> Iter.shuffle() == [3, 2, 1, 4]
      assert 1..4 |> Iter.shuffle() == [1, 3, 2, 4]
    end

    test "pipeline" do
      assert [1, 2, 3, 4] |> Iter.map(&(&1 * 2)) |> Iter.shuffle() == [6, 4, 2, 8]
      assert 1..4 |> Iter.map(&(&1 * 2)) |> Iter.shuffle() == [2, 6, 4, 8]
    end
  end

  describe "unzip/1" do
    test "simple call" do
      assert [a: 1, b: 2, c: 3] |> Iter.unzip() == {[:a, :b, :c], [1, 2, 3]}
    end

    test "pipeline" do
      assert [a: 1, b: 2, c: 3] |> Iter.map(& &1) |> Iter.unzip() == {[:a, :b, :c], [1, 2, 3]}
    end
  end

  describe "concat/1" do
    test "simple call" do
      assert [0..2, [:a], %{b: 3}] |> Iter.concat() == [0, 1, 2, :a, {:b, 3}]
    end

    test "pipeline" do
      assert [0..2, [:a], %{b: 3}] |> Iter.map(& &1) |> Iter.concat() == [0, 1, 2, :a, {:b, 3}]
    end
  end

  describe "concat/2" do
    test "simple call" do
      assert [1, 2, 3] |> Iter.concat([:a, :b]) == [1, 2, 3, :a, :b]
      assert 1..3 |> Iter.concat([:a, :b]) == [1, 2, 3, :a, :b]
    end

    test "pipeline" do
      assert [1, 2, 3] |> Iter.map(&(&1 * 2)) |> Iter.concat([:a, :b]) == [2, 4, 6, :a, :b]
      assert 1..3 |> Iter.map(&(&1 * 2)) |> Iter.concat([:a, :b]) == [2, 4, 6, :a, :b]
    end
  end

  describe "flat_map/2" do
    test "simple call" do
      assert Iter.flat_map([1, 2, 3], &(1..&1)) == [1, 1, 2, 1, 2, 3]
      assert Iter.flat_map(1..3, &(1..&1)) == [1, 1, 2, 1, 2, 3]
    end

    test "pipeline" do
      assert Iter.flat_map([1, 2, 3], &(1..&1)) |> Iter.map(&to_string/1) ==
               ["1", "1", "2", "1", "2", "3"]

      assert Iter.flat_map(1..3, &(1..&1)) |> Iter.map(&to_string/1) ==
               ["1", "1", "2", "1", "2", "3"]
    end

    test "pipeline with early return" do
      assert Iter.flat_map([1, 3], &(1..&1)) |> Iter.find_index(&(&1 == 2)) == 2
    end

    test "ast" do
      assert Iter.flat_map([1, 2, 3], &(1..&1)) |> Iter.map(&to_string/1) |> to_ast() ==
               """
               acc = []

               acc =
                 Enum.reduce([1, 2, 3], acc, fn elem, acc ->
                   elem = 1..elem

                   Enum.reduce(elem, acc, fn elem, acc ->
                     elem = to_string(elem)
                     [elem | acc]
                   end)
                 end)

               :lists.reverse(acc)
               """
    end
  end
end

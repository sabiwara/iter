defmodule Iter.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  require Iter

  @moduletag timeout: :infinity
  @moduletag :property

  def log_rescale(generator) do
    scale(generator, &trunc(:math.log(&1)))
  end

  def number(), do: one_of([integer(), float()])

  def reduce_callback do
    one_of([:+, :-, :|])
  end

  def mapper do
    one_of([
      :inc,
      :dec,
      :minus,
      :abs,
      :half,
      :round,
      :double
    ])
  end

  def key_mapper do
    one_of([
      :abs,
      :hash
    ])
  end

  def filter do
    one_of([
      :hash_div,
      :positive,
      :negative,
      :truthy_check
    ])
  end

  def reducer do
    one_of([
      :sum,
      :product,
      :max,
      :min,
      :join,
      {:join, string(:printable) |> log_rescale()},
      {:map_join, mapper()},
      {:map_join, string(:printable) |> log_rescale(), mapper()},
      {:join, string(:printable) |> log_rescale()},
      {:all?, filter()},
      {:any?, filter()},
      {:find, filter()},
      {:find_index, filter()},
      {:find_value, filter()},
      {:split_while, filter()},
      {:frequencies_by, key_mapper()},
      :frequencies,
      :random,
      {:group_by, key_mapper()},
      {:zip, list_of(integer())},
      {:into, one_of([Map]), key_mapper()},
      {:reduce_2, reduce_callback()},
      {:reduce_3, reduce_callback()}
    ])
  end

  def operation do
    one_of([
      {:map, mapper()},
      {:with_index, one_of([:+, :-])},
      {:filter, filter()},
      {:reject, filter()},
      {:take, integer(0..100)},
      {:take_random, integer(0..100)},
      {:drop, integer(0..10)},
      {:take_every, integer(0..10)},
      {:drop_every, integer(0..10)},
      {:take_while, filter()},
      {:drop_while, filter()},
      {:slice_2, integer(0..100), integer(0..100), integer(1..10)},
      {:slice_3, integer(0..100), integer(0..100)},
      :flat_map,
      :to_list,
      :reverse,
      :sort,
      :shuffle,
      :uniq,
      :dedup,
      {:intersperse, number()},
      {:map_intersperse, number(), mapper()},
      {:concat, list_of(integer(), max_length: 10)},
      {:into, one_of([MapSet, List]), key_mapper()}
    ])
  end

  def pipeline do
    {list_of(operation()), one_of([nil, reducer()])}
  end

  defp assert_same(enumerable, pipeline) do
    try do
      assert apply_pipeline(enumerable, pipeline, Enum) ==
               apply_pipeline(enumerable, pipeline, Iter)
    rescue
      err in ExUnit.AssertionError ->
        Process.get(:last_code) |> IO.puts()
        reraise err, __STACKTRACE__
    end
  end

  describe "Iter consistency with Enum" do
    property "chain of operations (lists)" do
      check all(list <- list_of(integer()), pipeline <- pipeline()) do
        assert_same(list, pipeline)
      end
    end

    property "chain of operations (streams)" do
      check all(list <- list_of(integer()), pipeline <- pipeline()) do
        stream = Stream.map(list, &(&1 + 1))

        assert_same(stream, pipeline)
      end
    end

    property "chain of operations (ranges)" do
      check all(
              start <- integer(),
              stop <- integer(),
              step <- integer(),
              step != 0,
              pipeline <- pipeline()
            ) do
        assert_same(start..stop//step, pipeline)
      end
    end

    defp apply_pipeline(list, {operations, reducer}, module) do
      ast = build_pipeline(operations, module) |> do_build_pipeline(reducer, module)

      if module == Iter do
        ast |> Macro.to_string() |> then(&Process.put(:last_code, &1))
      end

      :rand.seed(:exsss, {1, 2, 3})
      {result, _binding} = Code.eval_quoted(ast, [list: list], __ENV__)
      result
    end

    defp build_pipeline([], _module), do: quote(do: var!(list))

    defp build_pipeline([head | tail], module) do
      build_pipeline(tail, module) |> do_build_pipeline(head, module)
    end

    defp do_build_pipeline(ast, :flat_map, module) do
      quote do
        unquote(ast)
        |> unquote(module).flat_map(fn x -> [x, x + 1] end)
      end
    end

    defp do_build_pipeline(ast, {fun, arg}, module)
         when fun in [
                :map,
                :filter,
                :reject,
                :with_index,
                :take_while,
                :drop_while,
                :split_while,
                :all?,
                :any?,
                :find,
                :find_index,
                :find_value,
                :frequencies_by,
                :group_by,
                :map_join
              ] do
      quote do
        unquote(ast) |> unquote(module).unquote(fun)(unquote(fun_ast(arg)))
      end
    end

    defp do_build_pipeline(ast, {fun, raw_arg}, module)
         when (fun in [
                 :take,
                 :drop,
                 :take_every,
                 :drop_every,
                 :take_random,
                 :concat,
                 :join,
                 :zip,
                 :intersperse
               ] and
                 is_number(raw_arg)) or
                is_list(raw_arg) or is_binary(raw_arg) do
      quote do
        unquote(ast) |> unquote(module).unquote(fun)(unquote(raw_arg))
      end
    end

    defp do_build_pipeline(ast, fun, module)
         when fun in [
                :to_list,
                :reverse,
                :sort,
                :shuffle,
                :uniq,
                :dedup,
                :sum,
                :join,
                :frequencies
              ] do
      quote do
        unquote(ast) |> unquote(module).unquote(fun)()
      end
    end

    defp do_build_pipeline(ast, {:slice_2, start, stop, step}, module)
         when is_integer(start) and is_integer(stop) and is_integer(step) do
      quote do
        unquote(ast) |> unquote(module).slice(unquote(start)..unquote(stop)//unquote(step))
      end
    end

    defp do_build_pipeline(ast, {:slice_3, start, amount}, module)
         when is_integer(start) and is_integer(amount) do
      quote do
        unquote(ast) |> unquote(module).slice(unquote(start), unquote(amount))
      end
    end

    defp do_build_pipeline(ast, fun, module)
         when fun in [:min, :max, :product, :random] do
      quote do
        try do
          unquote(ast) |> unquote(module).unquote(fun)()
        rescue
          err -> err.__struct__
        end
      end
    end

    defp do_build_pipeline(ast, {name, raw_arg, fun}, module)
         when (name in [:map_join, :map_intersperse] and
                 is_number(raw_arg)) or
                is_list(raw_arg) or is_binary(raw_arg) do
      quote do
        unquote(ast) |> unquote(module).unquote(name)(unquote(raw_arg), unquote(fun_ast(fun)))
      end
    end

    defp do_build_pipeline(ast, {:reduce_2, fun}, module) do
      quote do
        try do
          unquote(ast) |> unquote(module).reduce(unquote(fun_ast(fun)))
        rescue
          err -> err.__struct__
        end
      end
    end

    defp do_build_pipeline(ast, {:reduce_3, fun}, module) do
      acc = if fun == :|, do: [], else: 0

      quote do
        unquote(ast) |> unquote(module).reduce(unquote(acc), unquote(fun_ast(fun)))
      end
    end

    defp do_build_pipeline(ast, {:into, Map, fun}, module) do
      quote do
        unquote(ast)
        |> unquote(module).into(%{}, fn x ->
          {:erlang.phash2(x, 20), unquote(fun_ast(fun)).(x)}
        end)
      end
    end

    defp do_build_pipeline(ast, {:into, MapSet, fun}, module) do
      quote do
        unquote(ast) |> unquote(module).into(MapSet.new(), unquote(fun_ast(fun)))
      end
    end

    defp do_build_pipeline(ast, {:into, List, fun}, module) do
      quote do
        unquote(ast) |> unquote(module).into([], unquote(fun_ast(fun)))
      end
    end

    defp do_build_pipeline(ast, nil, _module), do: ast

    defp fun_ast(type) do
      case type do
        :inc -> quote do: &(&1 + 1)
        :dec -> quote do: &(&1 - 1)
        :minus -> quote do: &(-&1)
        :abs -> quote do: &abs/1
        :half -> quote do: &(&1 / 2)
        :double -> quote do: &(&1 * 2)
        :round -> quote do: &round/1
        :hash -> quote do: fn x -> :erlang.phash2(x, 100) end
        :+ -> quote do: &+/2
        :- -> quote do: &-/2
        :| -> quote do: &[&1 | &2]
        :positive -> quote do: &(&1 >= 0)
        :negative -> quote do: &(&1 <= 0)
        :hash_div -> quote do: fn x -> :erlang.phash2(x, 5) != 0 end
        # not just bools, also truthiness
        :truthy_check -> quote do: fn x -> :erlang.phash2(x, 5) != 0 && x end
      end
    end
  end
end

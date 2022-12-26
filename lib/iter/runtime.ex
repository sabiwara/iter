defmodule Iter.Runtime do
  @moduledoc false

  # Guards are added as functions to get better errors

  @spec validate_positive_integer(integer()) :: integer()
  def validate_positive_integer(int) when is_integer(int) and int >= 0, do: int

  @spec validate_binary(binary()) :: binary()
  def validate_binary(binary) when is_binary(binary), do: binary

  @spec wrap_random(list()) :: term()
  def wrap_random([]), do: raise(Enum.EmptyError)

  def wrap_random(list) do
    size = length(list)
    # we avoid a reverse step, so we need to compute the index
    # from the end to be consistent with `Enum`
    index = size - :rand.uniform(size) + 1
    :lists.nth(index, list)
  end

  def wrap_shuffle(randomized) do
    :lists.keysort(1, randomized) |> do_wrap_shuffle([])
  end

  defp do_wrap_shuffle([], acc), do: acc

  defp do_wrap_shuffle([{_, value} | tail], acc) do
    do_wrap_shuffle(tail, [value | acc])
  end

  def do_take_random(sample, _idx, _amount = 0, _elem), do: sample

  def do_take_random(sample, idx, amount, elem) when is_map(sample) do
    jdx =
      case idx do
        0 -> 0
        _ -> :rand.uniform(idx + 1) - 1
      end

    cond do
      idx < amount ->
        value = Map.get(sample, jdx)
        Map.put(sample, idx, value) |> Map.put(jdx, elem)

      jdx < amount ->
        Map.put(sample, jdx, elem)

      true ->
        sample
    end
  end

  def do_take_random(sample, idx, amount, elem) when is_tuple(sample) do
    jdx =
      case idx do
        0 -> 0
        _ -> :rand.uniform(idx + 1) - 1
      end

    cond do
      idx < amount ->
        value = elem(sample, jdx)
        put_elem(sample, idx, value) |> put_elem(jdx, elem)

      jdx < amount ->
        put_elem(sample, jdx, elem)

      true ->
        sample
    end
  end

  def wrap_take_random(tuple, amount) when is_tuple(tuple) do
    Tuple.to_list(tuple) |> Enum.take(amount)
  end

  def wrap_take_random(map, amount) when is_map(map) do
    do_wrap_take_random(map, amount, [])
  end

  defp do_wrap_take_random(_sample, 0, acc), do: acc

  defp do_wrap_take_random(sample, position, acc) do
    position = position - 1
    %{^position => elem} = sample
    do_wrap_take_random(sample, position, [elem | acc])
  end

  @compile {:inline, reduce_while_list: 3, reduce_while_range: 5}

  # reduce_while is more optimized than `Enum` to avoid building `:cont` tuples
  def reduce_while(enumerable, acc, fun) when is_function(fun, 2) do
    case enumerable do
      list when is_list(list) ->
        reduce_while_list(list, acc, fun)

      start..stop//step ->
        reduce_while_range(start, stop, step, acc, fun)

      map when is_map(map) and not is_struct(map) ->
        Map.to_list(map) |> reduce_while_list(acc, fun)

      map_set when is_struct(map_set, MapSet) ->
        Enum.to_list(map_set) |> reduce_while_list(acc, fun)

      other ->
        reduce_while_other(other, acc, fun)
    end
  end

  defp reduce_while_list([], acc, _fun), do: acc

  defp reduce_while_list([h | t], acc, fun) do
    case fun.(h, acc) do
      {:__ITER_HALT__, acc} -> {:__ITER_HALT__, acc}
      acc -> reduce_while_list(t, acc, fun)
    end
  end

  defp reduce_while_range(start, stop, step, acc, _fun)
       when (step > 0 and start > stop) or (step < 0 and start < stop),
       do: acc

  defp reduce_while_range(start, stop, step, acc, fun) do
    case fun.(start, acc) do
      {:__ITER_HALT__, acc} -> {:__ITER_HALT__, acc}
      acc -> reduce_while_range(start + step, stop, step, acc, fun)
    end
  end

  defp reduce_while_other(other, acc, fun) do
    Enum.reduce_while(other, acc, fn elem, acc ->
      case fun.(elem, acc) do
        {:__ITER_HALT__, acc} -> {:halt, {:__ITER_HALT__, acc}}
        acc -> {:cont, acc}
      end
    end)
  end

  def wrap_reduce_while({:__ITER_HALT__, acc}), do: acc
  def wrap_reduce_while(acc), do: acc

  @spec wrap_intersperse(list(), term()) :: list()
  def wrap_intersperse(list, separator), do: do_wrap_intersperse(list, separator, [])

  defp do_wrap_intersperse([], _separator, acc) do
    case acc do
      [] -> []
      [_ | rest] -> rest
    end
  end

  defp do_wrap_intersperse([head | tail], separator, acc) do
    do_wrap_intersperse(tail, separator, [separator, head | acc])
  end

  @spec preprocess_slice_range(Range.t()) :: {integer(), integer(), integer()}
  def preprocess_slice_range(start..stop//step)
      when is_integer(start) and start >= 0 and is_integer(stop) and stop >= 0 and
             is_integer(step) and step > 0 do
    case stop - start do
      negative when negative < 0 -> {0, -1, 1}
      amount when step == 1 -> {-start, amount, step}
      amount -> {-start, amount - rem(amount, step), step}
    end
  end
end

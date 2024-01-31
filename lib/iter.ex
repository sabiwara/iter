defmodule Iter do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.drop_every(2)
             |> Enum.join("\n")

  import Iter.Core
  import Iter.MacroHelpers

  @collect_pipeline_disclaimer """
  **Note:** This step collects the pipeline and cannot be merged with following steps.
  Read the [*Collecting the pipeline*](#module-collecting-the-pipeline) section for more information.
  """

  @negative_indexes_disclaimer """
  **Note:** Negative indexes are **NOT** supported when used in a pipeline, since this
  would imply to materialize the whole list and therefore cannot be done lazily.
  If you need to use negative indexes, you can either use materialize the pipeline first
  using `Iter.to_list/1` or use the equivalent `Enum` function.
  Read the [*Collecting the pipeline*](#module-collecting-the-pipeline) section for more information.
  """

  @doc """
  Converts `enumerable` to a list. Equivalent to `Enum.to_list/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.to_list(1..3)
      [1, 2, 3]

  """
  def_iter to_list(enumerable)

  @doc """
  Applies `fun` on each element of `enumerable`. Equivalent to `Enum.map/2`.

  ## Examples

      iex> Iter.map(1..3, & &1 ** 2)
      [1, 4, 9]

  """
  def_iter map(enumerable, fun)

  @doc """
  Returns the `enumerable` with each element wrapped in a tuple
  alongside its index. Equivalent to `Enum.with_index/1`.

  ## Examples

      iex> Iter.with_index(["a", "b", "c"])
      [{"a", 0}, {"b", 1}, {"c", 2}]

  """
  def_iter with_index(enumerable)

  @doc """
  Returns the `enumerable` with each element wrapped in a tuple
  alongside its index. Equivalent to `Enum.with_index/2`.

  Like `Enum.with_index/2`, accepts either an anonymous function or an integer offset,
  but it has to infer the type at compile time. If the expression can't be inferred to
  be either an `fn` or a capture, it will assume it is an integer
  (example: `Iter.with_index(list, var)` will only work if `var` is an integer).

  If an offset is given, it will index from the given offset instead of from zero.

  If a function is given, it will index by invoking the function for each element
  and index (zero-based) of the `enumerable`.

  ## Examples

      iex> Iter.with_index(["a", "b", "c"], 100)
      [{"a", 100}, {"b", 101}, {"c", 102}]

      iex> Iter.with_index(["a", "b", "c"], fn elem, index -> String.duplicate(elem, index) end)
      ["", "b", "cc"]

      iex> Iter.with_index(["a", "b", "c"], &String.duplicate(&1, &2))
      ["", "b", "cc"]


  """
  def_iter with_index(enumerable, fun_or_offset)

  ##############
  ## Filtering
  ##############

  @doc """
  Pattern-matches on each element of the `enumerable`, filters out elements that
  do not match the `pattern`, and returns the `expr`.

  This works a bit like a combination of `map/2` and `filter/2` and works very
  similarly as `for/1` comprehensions.

  There is no equivalent `Enum` function.

  ## Examples

      iex> Iter.match([{:ok, 1}, :error, {:ok, 3}], {:ok, x}, x + 1)
      [2, 4]

  The pattern also supports guards:

      iex> Iter.match([1, nil, 3], x when is_integer(x), x * 2)
      [2, 6]

  """
  def_iter match(enumerable, pattern, expr)

  @doc """
  Filters the `enumerable`, keeping only elements for which `fun` returns a truthy value.
  Equivalent to `Enum.filter/2`.

  ## Examples

      iex> Iter.filter(1..4, &rem(&1, 2) == 1)
      [1, 3]

  """
  def_iter filter(enumerable, fun)

  @doc """
  Filters the `enumerable`, rejecting elements for which `fun` returns a truthy value.
  Equivalent to `Enum.reject/2`.

  ## Examples

      iex> Iter.reject(1..4, &rem(&1, 2) == 1)
      [2, 4]

  """
  def_iter reject(enumerable, fun)

  @doc """
  Splits the `enumerable` in two lists based on the truthiness of applying `fun` on
  each element. Equivalent to `Enum.split_with/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.split_with(1..4, &rem(&1, 2) == 1)
      {[1, 3], [2, 4]}

  """
  def_iter split_with(enumerable, fun)

  @doc """
  Takes an `amount` of elements from the beginning of the `enumerable`.
  Equivalent to `Enum.take/2`.

  #{@negative_indexes_disclaimer}

  ## Examples

      iex> Iter.take(1..1000, 5)
      [1, 2, 3, 4, 5]

  """
  def_iter take(enumerable, amount)

  @doc """
  Drops an `amount` of elements from the beginning of the `enumerable`.
  Equivalent to `Enum.drop/2`.

  #{@negative_indexes_disclaimer}

  ## Examples

      iex> Iter.drop(1..10, 5)
      [6, 7, 8, 9, 10]

  """
  def_iter drop(enumerable, amount)

  @doc """
  Splits the `enumerable` into two lists, leaving `amount` elements in the first one.
  Equivalent to `Enum.split/2`.

  #{@negative_indexes_disclaimer}

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.split(1..10, 5)
      {[1, 2, 3, 4, 5], [6, 7, 8, 9, 10]}

  """
  def_iter split(enumerable, amount)

  @doc """
  Returns a subset list of the given `enumerable` by `index_range`.
  Equivalent to `Enum.slice/2`.

  #{@negative_indexes_disclaimer}

  ## Examples

      iex> Iter.slice(1..100, 5..15)
      [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]

      iex> Iter.slice(1..100, 5..15//5)
      [6, 11, 16]

  """
  def_iter slice(enumerable, index_range)

  @doc """
  Returns a subset list of the given enumerable, from `start_index` with `amount`
  number of elements if available.
  Equivalent to `Enum.slice/3`.

  #{@negative_indexes_disclaimer}

  ## Examples

      iex> Iter.slice(1..100, 5, 10)
      [6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

  """
  def_iter slice(enumerable, start_index, amount)

  @doc """
  Returns a list of every `nth` element in the `enumerable`, starting
  with the first element.
  Equivalent to `Enum.take_every/2`.

  ## Examples

      iex> Iter.take_every(1..10, 3)
      [1, 4, 7, 10]

  """
  def_iter take_every(enumerable, nth)

  @doc """
  Returns a list of every `nth` element in the `enumerable` dropped,
  starting with the first element.
  Equivalent to `Enum.drop_every/2`.

  ## Examples

      iex> Iter.drop_every(1..10, 3)
      [2, 3, 5, 6, 8, 9]

  """
  def_iter drop_every(enumerable, nth)

  @doc """
  Takes the elements from the beginning of the `enumerable`, while `fun` returns
  a truthy value. Equivalent to `Enum.take_while/2`.

  ## Examples

      iex> Iter.take_while(1..1000, & &1 < 6)
      [1, 2, 3, 4, 5]

  """
  def_iter take_while(enumerable, fun)

  @doc """
  Drops elements at the beginning of the `enumerable`, while `fun` returns
  a truthy value. Equivalent to `Enum.drop_while/2`.

  ## Examples

      iex> Iter.drop_while(1..10, & &1 < 6)
      [6, 7, 8, 9, 10]

  """
  def_iter drop_while(enumerable, fun)

  @doc """
  Splits the `enumerable` in two at the position of the element for which `fun`
  returns a falsy value for the first time. Equivalent to `Enum.split_while/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.split_while(1..10, & &1 < 6)
      {[1, 2, 3, 4, 5], [6, 7, 8, 9, 10]}

  """
  def_iter split_while(enumerable, fun)

  @doc """
  Enumerates the `enumerable`, removing the duplicate elements.
  Equivalent to `Enum.uniq/1`.

  ## Examples

      iex> Iter.uniq([1, 2, 1, 3, 2, 4])
      [1, 2, 3, 4]

  """
  def_iter uniq(enumerable)

  @doc """
  Enumerates the `enumerable`, removing elements for which `fun` return duplicate values.
  Equivalent to `Enum.uniq_by/2`.

  ## Examples

      iex> Iter.uniq_by([{1, :x}, {2, :y}, {1, :z}], fn {x, _} -> x end)
      [{1, :x}, {2, :y}]

  """
  def_iter uniq_by(enumerable, fun)

  @doc """
  Enumerates the `enumerable`, removing successive duplicate elements.
  Equivalent to `Enum.dedup/1`.

  ## Examples

      iex> Iter.dedup([1, 2, 2, 3, 3, 1, 3])
      [1, 2, 3, 1, 3]

  """
  def_iter dedup(enumerable)

  @doc """
  Enumerates the `enumerable`, removing successive elements for which `fun` return duplicate values.
  Equivalent to `Enum.dedup_by/2`.

  ## Examples

      iex> Iter.dedup_by([{1, :a}, {2, :b}, {2, :c}, {1, :a}], fn {x, _} -> x end)
      [{1, :a}, {2, :b}, {1, :a}]

  """
  def_iter dedup_by(enumerable, fun)

  ##############
  ## Reducers
  ##############

  @doc """
  Invokes `fun` for each element in the `enumerable` with the accumulator.
  Equivalent to `Enum.reduce/2`.

  Raises `Enum.EmptyError` if `enumerable` is empty.
  The first element of the `enumerable` is used as the initial value of the accumulator.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.reduce(1..5, &*/2)
      120

      iex> Iter.reduce([], &*/2)
      ** (Enum.EmptyError) empty error

  """
  def_iter reduce(enumerable, fun)

  @doc """
  Invokes `fun` for each element in the `enumerable` with the accumulator.
  Equivalent to `Enum.reduce/3`.

  The value of `acc` is used as the initial value of the accumulator.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.reduce(1..5, 1, &*/2)
      120

  """
  def_iter reduce(enumerable, acc, fun)

  @doc """
  Invokes the given function to each element in the `enumerable` to reduce it to
  a single element, while keeping an accumulator.
  Equivalent to `Enum.map_reduce/3`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.map_reduce([1, 2, 3], 0, fn x, acc -> {x * 2, x + acc} end)
      {[2, 4, 6], 6}

  """
  def_iter map_reduce(enumerable, acc, fun)

  @doc """
  Applies the given function to each element in the `enumerable`, storing the
  result in a list and passing it as the accumulator for the next computation.
  Equivalent to `Enum.scan/3`.

  ## Examples

      iex> Iter.scan(1..5, 1, &*/2)
      [1, 2, 6, 24, 120]

  """
  def_iter scan(enumerable, acc, fun)

  @doc """
  Inserts the given `enumerable` into a `collectable`.
  Equivalent to `Enum.into/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.into([a: 1, b: 2, a: 3], %{})
      %{a: 3, b: 2}

      iex> Iter.into([1, 2, 1, 2.0], MapSet.new())
      MapSet.new([1, 2, 2.0])

  """
  defmacro into(enumerable, _collectable = {:%{}, _, []}) do
    # this is a trade-off since actually uses less-memory even if
    # slightly slower.
    quote do: Map.new(unquote(enumerable))
  end

  def_iter into(enumerable, collectable)

  @doc """
  Inserts the given `enumerable` into a `collectable` and maps the `fun`
  function on each item.
  Equivalent to `Enum.into/3`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.into([a: 1, b: 2, a: 3], %{}, fn {k, v} -> {k, v * 2} end)
      %{a: 6, b: 4}

      iex> Iter.into([1, 2, 1, 2.0], MapSet.new(), & &1 * 2)
      MapSet.new([2, 4, 4.0])

  """
  defmacro into(enumerable, _collectable = {:%{}, _, []}, fun) do
    quote do: Map.new(Iter.map(unquote(enumerable), unquote(fun)))
  end

  def_iter into(enumerable, collectable, fun)

  @doc """
  Invokes the given `fun` for each element in the `enumerable`.
  Equivalent to `Enum.each/2`.

  Returns `:ok`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> {:ok, pid} = Agent.start(fn -> [] end)
      iex> Iter.each(1..5, fn i -> Agent.update(pid, &[i | &1]) end)
      :ok
      iex> Agent.get(pid, & &1)
      [5, 4, 3, 2, 1]

  """
  def_iter each(enumerable, fun)

  @doc """
  Returns the `size` of the enumerable. Equivalent to `Enum.count/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.count([1, 2, 3])
      3

  """
  def_iter count(enumerable)

  @doc """
  Returns the count of elements in the `enumerable` for which `fun` returns a truthy value.
  Equivalent to `Enum.count/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.count(1..5, fn x -> rem(x, 2) == 0 end)
      2

  """
  def_iter count(enumerable, fun)

  @doc """
  Returns the sum of all elements in `enumerable`. Equivalent to `Enum.sum/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.sum(1..3)
      6

  """
  def_iter sum(enumerable)

  @doc """
  Returns the product of all elements in `enumerable`.
  Equivalent to `Enum.product/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.product(1..3)
      6

  """
  def_iter product(enumerable)

  @doc """
  Returns the mean value of all elements in `enumerable`.

  Raises `Enum.EmptyError` if `enumerable` is empty.

  There is no equivalent `Enum` function.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.mean(1..10)
      5.5

      iex> Iter.mean([])
      ** (Enum.EmptyError) empty error

  """
  def_iter mean(enumerable)

  @doc """
  Returns the maximal element in the `enumerable` according to Erlang's term ordering.
  Equivalent to `Enum.max/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.max([2, 4, 1, 3])
      4

      iex> Iter.max([])
      ** (Enum.EmptyError) empty error

  """
  def_iter max(enumerable)

  @doc """
  Returns the minimal element in the `enumerable` according to Erlang's term ordering.
  Equivalent to `Enum.min/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.min([2, 4, 1, 3])
      1

      iex> Iter.min([])
      ** (Enum.EmptyError) empty error

  """
  def_iter min(enumerable)

  @doc """
  Returns a map with keys as unique elements of `enumerable` and values
  as the count of every element.
  Equivalent to `Enum.frequencies/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.frequencies([1, 1, 2, 1, 2, 3])
      %{1 => 3, 2 => 2, 3 => 1}

  """
  def_iter frequencies(enumerable)

  @doc """
  Returns a map with keys as unique elements given by `key_fun` and values
  as the count of every element.
  Equivalent to `Enum.frequencies_by/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.frequencies_by(~w{aa aA bb cc}, &String.downcase/1)
      %{"aa" => 2, "bb" => 1, "cc" => 1}

  """
  def_iter frequencies_by(enumerable, key_fun)

  @doc """
  Splits the enumerable into groups based on `key_fun`. Equivalent to `Enum.group_by/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.group_by(~w{ant buffalo cat dingo}, &String.length/1)
      %{3 => ["ant", "cat"], 5 => ["dingo"], 7 => ["buffalo"]}

  """
  def_iter group_by(enumerable, key_fun)

  @doc """
  Splits the enumerable into groups based on `key_fun`.
  Equivalent to `Enum.group_by/3`.

  The result is a map where each key is given by `key_fun` and each
  value is a list of elements given by `value_fun`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.group_by(~w{ant buffalo cat dingo}, &String.length/1, &String.first/1)
      %{3 => ["a", "c"], 5 => ["d"], 7 => ["b"]}

  """
  def_iter group_by(enumerable, key_fun, value_fun)

  @doc """
  Joins the given `enumerable` into a string without any separator.
  Equivalent to `Enum.join/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.join(1..3)
      "123"

  """
  def_iter join(enumerable)

  @doc """
  Joins the given `enumerable` into a string with `joiner` as a separator.
  Equivalent to `Enum.join/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.join(1..3, "-")
      "1-2-3"

  """
  def_iter join(enumerable, joiner)

  @doc """
  Applies `mapper` and joins the given `enumerable` into a string without any separator.
  Equivalent to `Enum.map_join/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.map_join(1..3, & &1 ** 2)
      "149"

  """
  def_iter map_join(enumerable, mapper)

  @doc """
  Applies `mapper` and joins the given `enumerable` into a string with `joiner` as a separator.
  Equivalent to `Enum.map_join/3`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.map_join(1..3, "-", & &1 ** 2)
      "1-4-9"

  """
  def_iter map_join(enumerable, joiner, mapper)

  @doc """
  Intersperses `separator` between each element of the `enumerable`.
  Equivalent to `Enum.intersperse/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.intersperse(1..3, :foo)
      [1, :foo, 2, :foo, 3]

  """
  def_iter intersperse(enumerable, separator)

  @doc """
  Maps and intersperses the given `enumerable` with `separator`.
  Equivalent to `Enum.map_intersperse/3`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.map_intersperse(1..3, :foo, & &1 ** 2)
      [1, :foo, 4, :foo, 9]

  """
  def_iter map_intersperse(enumerable, separator, fun)

  ##############
  ## Find/exist
  ##############

  @doc """
  Returns `true` if `enumerable` is empty, otherwise `false`.
  Equivalent to `Enum.empty?/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.empty?([])
      true

      iex> Iter.empty?([:foo])
      false

  """
  def_iter empty?(enumerable)

  @doc """
  Returns `true` if at least one element in `enumerable` is truthy.
  Equivalent to `Enum.any?/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.any?([false, true])
      true

      iex> Iter.any?([false, nil])
      false

      iex> Iter.any?([])
      false

  """
  def_iter any?(enumerable)

  @doc """
  Returns `true` if `fun` returns a truthy value for at least one element in `enumerable`.
  Equivalent to `Enum.any?/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples
      iex> Enum.any?([2, 4, 6], fn x -> rem(x, 2) == 1 end)
      false

      iex> Enum.any?([2, 3, 4], fn x -> rem(x, 2) == 1 end)
      true

      iex> Iter.any?([], fn x -> rem(x, 2) == 1 end)
      false

  """
  def_iter any?(enumerable, fun)

  @doc """
  Returns `true` if all elements in `enumerable` are truthy.
  Equivalent to `Enum.all?/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.all?(["yes", true])
      true

      iex> Iter.all?([false, true])
      false

      iex> Iter.all?([])
      true

  """
  def_iter all?(enumerable)

  @doc """
  Returns `true` if `fun` returns a truthy value for all elements in `enumerable`.
  Equivalent to `Enum.all?/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Enum.all?([2, 4, 6], fn x -> rem(x, 2) == 0 end)
      true

      iex> Enum.all?([2, 3, 4], fn x -> rem(x, 2) == 0 end)
      false

      iex> Iter.all?([], fn x -> rem(x, 2) == 0 end)
      true

  """
  def_iter all?(enumerable, fun)

  @doc """
  Checks if `element` exists within the `enumerable`.
  Equivalent to `Enum.member?/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples
      iex> Enum.member?([:ant, :bat, :cat], :bat)
      true

      iex> Enum.member?([:ant, :bat, :cat], :dog)
      false

      iex> Iter.member?([1, 2, 3], 2.0)
      false

  """
  def_iter member?(enumerable, element)

  @doc """
  Returns the first element for which `fun` returns a truthy value.
  Equivalent to `Enum.find/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.find([2, 3, 4], fn x -> rem(x, 2) == 1 end)
      3

      iex> Iter.find([2, 4, 6], fn x -> rem(x, 2) == 1 end)
      nil

  """
  def_iter find(enumerable, fun)

  @doc """
  Returns the first element for which `fun` returns a truthy value,
  returns `default` if not found.any()
  Equivalent to `Enum.find/3`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.find([2, 3, 4], 0, fn x -> rem(x, 2) == 1 end)
      3

      iex> Iter.find([2, 4, 6], 0, fn x -> rem(x, 2) == 1 end)
      0

  """
  def_iter find(enumerable, default, fun)

  @doc """
  Similar to `find/2`, but returns the value of the function invocation instead
  of the element itself. Equivalent to `Enum.find_value/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.find_value([%{x: nil}, %{x: 5}, %{}], fn map -> map[:x] end)
      5

      iex> Iter.find_value([%{x: nil}, %{}, %{}], fn map -> map[:x] end)
      nil

  """
  def_iter find_value(enumerable, fun)

  @doc """
  Similar to `find/3`, but returns the value of the function invocation instead
  of the element itself. Equivalent to `Enum.find_value/3`.

  Returns `default` if not found.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.find_value([%{x: nil}, %{x: 5}, %{}], 0, fn map -> map[:x] end)
      5

      iex> Iter.find_value([%{x: nil}, %{}, %{}], 0, fn map -> map[:x] end)
      0

  """
  def_iter find_value(enumerable, default, fun)

  @doc """
  Similar to `find/2`, but returns the index (zero-based) of the element
  instead of the element itself.
  Equivalent to `Enum.find_index/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.find_index(["ant", "bat", "cat"], fn x -> x =~ "b" end)
      1

      iex> Iter.find_index(["ant", "bat", "cat"], fn x -> x =~ "z" end)
      nil

  """
  def_iter find_index(enumerable, fun)

  ##############
  ## Position
  ##############

  @doc """
  Finds the element at the given index (zero-based). Equivalent to `Enum.at/2`.

  Returns `nil` if not found.

  #{@collect_pipeline_disclaimer}

  #{@negative_indexes_disclaimer}

  Also, see `Iter.last/1` if you need to access the last element.

  ## Examples

      iex> Iter.at([:foo, :bar, :baz], 2)
      :baz

      iex> Iter.at([:foo, :bar, :baz], 3)
      nil

  """
  def_iter at(enumerable, index)

  @doc """
  Finds the element at the given index (zero-based).
  Equivalent to `Enum.at/3`.

  Returns `default` if not found.

  #{@collect_pipeline_disclaimer}

  #{@negative_indexes_disclaimer}

  ## Examples

      iex> Iter.at(1..1000, 5, :none)
      6
      iex> Iter.at(1..1000, 1000, :none)
      :none

  """
  def_iter at(enumerable, index, default)

  @doc """
  Finds the element at the given index (zero-based).
  Equivalent to `Enum.fetch/2`.

  Returns `{:ok, element}` if found, otherwise `:error`.

  #{@collect_pipeline_disclaimer}

  #{@negative_indexes_disclaimer}

  ## Examples

      iex> Iter.fetch([:foo, :bar, :baz], 2)
      {:ok, :baz}

      iex> Iter.fetch([:foo, :bar, :baz], 3)
      :error

  """
  def_iter fetch(enumerable, index)

  @doc """
  Finds the element at the given index (zero-based).
  Equivalent to `Enum.fetch!/2`.

  Raises `OutOfBoundsError` if the given index is outside the range
  of the `enumerable`.

  #{@collect_pipeline_disclaimer}

  #{@negative_indexes_disclaimer}

  ## Examples

      iex> Iter.fetch!([:foo, :bar, :baz], 2)
      :baz

      iex> Iter.fetch!([:foo, :bar, :baz], 3)
      ** (Enum.OutOfBoundsError) out of bounds error

  """
  def_iter fetch!(enumerable, index)

  @doc """
  Retrieves the first element of the `enumerable`, or `nil` if empty.

  #{@collect_pipeline_disclaimer}

  There is no equivalent `Enum` function.

  ## Examples

      iex> Iter.first(1..1000)
      1
      iex> Iter.first([])
      nil

  """
  def_iter first(enumerable)

  @doc """
  Retrieves the first element of the `enumerable`, or `default` if empty.

  #{@collect_pipeline_disclaimer}

  There is no equivalent `Enum` function.

  ## Examples

      iex> Iter.first(1..10, :none)
      1
      iex> Iter.first([], :none)
      :none

  """
  def_iter first(enumerable, default)

  @doc """
  Retrieves the last element of the `enumerable`, or `nil` if empty.

  #{@collect_pipeline_disclaimer}

  There is no equivalent `Enum` function, but it can compensate
  for the lack of negative index support in `at/2`.

  ## Examples

      iex> Iter.last(1..10)
      10
      iex> Iter.last([])
      nil

  """
  def_iter last(enumerable)

  @doc """
  Retrieves the last element of the `enumerable`, or `default` if empty.

  #{@collect_pipeline_disclaimer}

  There is no equivalent `Enum` function, but it can compensate
  for the lack of negative index support in `at/3`.

  ## Examples

      iex> Iter.last(1..10, :none)
      10
      iex> Iter.last([], :none)
      :none

  """
  def_iter last(enumerable, default)

  ##############
  ## Wrappers
  ##############

  @doc """
  Returns a list of elements in `enumerable` in reverse order.
  Equivalent to `Enum.reverse/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.reverse(1..3)
      [3, 2, 1]

  """
  def_iter reverse(enumerable)

  @doc """
  Reverses the elements in `enumerable`, appends the `tail`, and
  returns the result as a list.
  Equivalent to `Enum.reverse/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.reverse(1..3, 4..6)
      [3, 2, 1, 4, 5, 6]

  """
  def_iter reverse(enumerable, tail)

  @doc """
  Sorts the `enumerable` according to Erlang's term ordering.
  Equivalent to `Enum.sort/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.sort([4, 1, 5, 2, 3])
      [1, 2, 3, 4, 5]

  """
  def_iter sort(enumerable)

  @doc """
  Sorts the `enumerable` by the given `sorter` function or module.
  Equivalent to `Enum.sort/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.sort([4, 1, 5, 2, 3], :desc)
      [5, 4, 3, 2, 1]

  """
  def_iter sort(enumerable, sorter)

  @doc """
  Sorts the mapped results of the `enumerable` according to Erlang's term ordering.
  Equivalent to `Enum.sort_by/2`.

  #{@collect_pipeline_disclaimer}

  This is actually just an alias for `Enum.sort_by/2`, `Iter` isn't able to
  optimize it.

  ## Examples

      iex> Iter.sort_by(["some", "kind", "of", "monster"], &byte_size/1)
      ["of", "some", "kind", "monster"]

  """
  # Technically could be made faster but the memory cost isn't worth it
  defdelegate sort_by(enumerable, fun, sorter \\ :asc), to: Enum

  @doc """
  Returns a random element of the `enumerable`. Equivalent to `Enum.random/1`.

  Raises `Enum.EmptyError` if `enumerable` is empty.

  #{@collect_pipeline_disclaimer}

  ## Examples

      # Although not necessary, let's seed the random algorithm
      iex> :rand.seed(:exsss, {1, 2, 3})
      iex> Iter.random(1..100)
      27

  """
  def_iter random(enumerable)

  @doc """
  Takes an `amount` of random elements from the `enumerable`.
  Equivalent to `Enum.take_random/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      # Although not necessary, let's seed the random algorithm
      iex> :rand.seed(:exsss, {1, 2, 3})
      iex> Iter.take_random(1..100, 3)
      [74, 28, 55]

  """
  def_iter take_random(enumerable, amount)

  @doc """
  Returns a list with `enumerable` elements in a random order.
  Equivalent to `Enum.shuffle/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      # Although not necessary, let's seed the random algorithm
      iex> :rand.seed(:exsss, {1, 2, 3})
      iex> Iter.shuffle(1..6)
      [3, 2, 5, 1, 4, 6]

  """
  def_iter shuffle(enumerable)

  @doc """
  Zips corresponding elements from a finite collection of `enumerables`
  into a list of tuples.

  This is actually just an alias for `Enum.zip/1`, `Iter` isn't able to
  optimize it.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.zip([[1, 2, 3], [:a, :b, :c], ["foo", "bar", "baz"]])
      [{1, :a, "foo"}, {2, :b, "bar"}, {3, :c, "baz"}]

  """
  defdelegate zip(enumerables), to: Enum

  @doc """
  Zips corresponding elements from two enumerables into a list of tuples.

  This is actually just an alias for `Enum.zip/2`, `Iter` isn't able to
  optimize it.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.zip([1, 2, 3, 4, 5], [:a, :b, :c])
      [{1, :a}, {2, :b}, {3, :c}]

  """
  defdelegate zip(left, right), to: Enum

  @doc """
  Extracts two-element tuples from the given `enumerable` and returns them
  as two separate lists.
  Equivalent to `Enum.unzip/1`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.unzip([{:a, 1}, {:b, 2}, {:c, 3}])
      {[:a, :b, :c], [1, 2, 3]}

  """
  def_iter unzip(enumerable)

  ##############
  ## Flattening
  ##############

  @doc """
  Given an `enumerable` of enumerables, concatenates the enumerables into a single one.
  Equivalent to `Enum.concat/1`.

  ## Examples

      iex> Iter.concat([1..3, 4..6])
      [1, 2, 3, 4, 5, 6]

  """
  def_iter concat(enumerable)

  @doc """
  Concatenates the enumerable on the `right` with the enumerable on the `left`.
  Equivalent to `Enum.concat/2`.

  #{@collect_pipeline_disclaimer}

  ## Examples

      iex> Iter.concat(1..3, 4..6)
      [1, 2, 3, 4, 5, 6]

  """
  def_iter concat(left, right)

  @doc """
  Maps the given `fun` over `enumerable` and flattens the result.
  Equivalent to `Enum.flat_map/2`.

  ## Examples

      iex> Iter.flat_map(1..3, fn n -> 1..n end)
      [1, 1, 2, 1, 2, 3]

  """
  def_iter flat_map(enumerable, fun)

  @doc false
  defmacro explain(expr) do
    Macro.expand(expr, __CALLER__) |> inspect_ast()
  end
end

defmodule Iter.Step do
  @moduledoc false

  import Iter.MacroHelpers, only: [to_exprs: 1]

  alias Iter.Runtime
  alias Iter.MacroHelpers

  @type ast :: Macro.t()
  @type vars :: %{
          elem: ast,
          acc: ast,
          composite_acc: ast,
          extra_args: [ast],
          reduce_module: module,
          reduce_fun: atom
        }
  @type t :: %{
          optional(:meta) => keyword,
          optional(:collect) => boolean(),
          optional(:halt) => boolean(),
          optional(:extra_args) => list(ast),
          optional(:initial_acc) => (() -> ast),
          optional(:init) => (() -> ast | nil),
          optional(:next_acc) => (vars, ast -> ast),
          optional(:return_acc) => (vars -> ast),
          optional(:wrap_acc) => (ast -> ast),
          optional(:wrap_reduce) => (ast -> ast)
        }

  @spec initial_acc(t) :: ast
  def initial_acc(step) do
    case step do
      %{initial_acc: fun} -> fun.()
      %{} -> []
    end
    |> set_location(step)
  end

  @spec init(t) :: ast | nil
  def init(step) do
    case step do
      %{init: fun} -> fun.()
      %{} -> nil
    end
    |> set_location(step)
  end

  @spec next_acc(t, vars, ast) :: ast
  def next_acc(step, vars, continue) do
    case step do
      %{next_acc: fun} -> fun.(vars, continue)
      %{} -> continue
    end
    |> set_location(step)
  end

  @spec return_acc(t, vars) :: ast
  def return_acc(step, vars) do
    case step do
      %{return_acc: fun} -> fun.(vars)
      %{} -> quote do: [unquote(vars.elem) | unquote(vars.acc)]
    end
    |> set_location(step)
  end

  @spec wrap_reduce(t, vars, ast) :: ast
  def wrap_reduce(step, vars, ast) do
    ast =
      case vars.reduce_fun do
        :reduce_while -> quote do: unquote(ast) |> Runtime.wrap_reduce_while()
        :reduce -> ast
      end

    case step do
      %{wrap_reduce: fun} -> fun.(ast) |> set_location(step)
      %{} -> ast
    end
  end

  @spec wrap_acc(t, ast) :: ast
  def wrap_acc(step, ast) do
    case step do
      %{wrap_acc: fun} -> fun.(ast)
      %{} -> quote do: :lists.reverse(unquote(ast))
    end
    |> set_location(step)
  end

  defp set_location(ast, step) do
    if line = step.meta[:line] do
      do_set_location(ast, line)
    else
      ast
    end
  end

  defp do_set_location({call, meta, args} = ast, line) do
    if Keyword.has_key?(meta, :line) do
      ast
    else
      call = do_set_location(call, line)
      meta = Keyword.put(meta, :line, line)

      args =
        case args do
          list when is_list(list) -> Enum.map(list, &do_set_location(&1, line))
          atom when is_atom(atom) -> atom
        end

      {call, meta, args}
    end
  end

  defp do_set_location(other, _line), do: other

  @spec map(ast) :: t
  def map(fun) do
    %{
      next_acc: fn vars, continue ->
        quote do
          unquote(vars.elem) = unquote(MacroHelpers.apply_fun(fun, vars.elem))
          unquote_splicing(to_exprs(continue))
        end
      end
    }
  end

  @spec with_index(ast) :: t
  def with_index(fun = {atom, _, _}) when atom in [:fn, :&] do
    index = Macro.unique_var(:index, __MODULE__)

    %{
      extra_args: [index],
      init: fn -> quote do: unquote(index) = 0 end,
      next_acc: fn vars, continue ->
        quote do
          unquote(vars.elem) = unquote(fun).(unquote(vars.elem), unquote(index))
          unquote(index) = unquote(index) + 1
          unquote_splicing(to_exprs(continue))
        end
      end
    }
  end

  def with_index(offset) do
    index = Macro.unique_var(:index, __MODULE__)

    %{
      extra_args: [index],
      init: fn -> quote do: unquote(index) = unquote(offset) end,
      next_acc: fn vars, continue ->
        quote do
          unquote(vars.elem) = {unquote(vars.elem), unquote(index)}
          unquote(index) = unquote(index) + 1
          unquote_splicing(to_exprs(continue))
        end
      end
    }
  end

  @spec match(ast, ast) :: t
  def match(pattern, expr) do
    %{
      next_acc: fn vars, continue ->
        quote do
          case unquote(vars.elem) do
            unquote(pattern) ->
              unquote(vars.elem) = unquote(expr)
              (unquote_splicing(to_exprs(continue)))

            _ ->
              unquote(vars.composite_acc)
          end
        end
      end
    }
  end

  @spec filter(ast) :: t
  def filter(fun) do
    %{
      next_acc: fn vars, continue ->
        quote do
          if unquote(MacroHelpers.apply_fun(fun, vars.elem)) do
            (unquote_splicing(to_exprs(continue)))
          else
            unquote(vars.composite_acc)
          end
        end
      end
    }
  end

  @spec reject(ast) :: t
  def reject(fun) do
    %{
      next_acc: fn vars, continue ->
        quote do
          if unquote(MacroHelpers.apply_fun(fun, vars.elem)) do
            unquote(vars.composite_acc)
          else
            (unquote_splicing(to_exprs(continue)))
          end
        end
      end
    }
  end

  @spec split_with(ast) :: t
  def split_with(fun) do
    rejected = Macro.unique_var(:rejected, __MODULE__)

    %{
      collect: true,
      extra_args: [rejected],
      init: fn -> quote do: unquote(rejected) = [] end,
      next_acc: fn vars, continue ->
        quote do
          if unquote(MacroHelpers.apply_fun(fun, vars.elem)) do
            (unquote_splicing(to_exprs(continue)))
          else
            unquote(rejected) = [unquote(vars.elem) | unquote(rejected)]
            unquote(vars.composite_acc)
          end
        end
      end,
      wrap_acc: fn ast ->
        quote do: {:lists.reverse(unquote(ast)), :lists.reverse(unquote(rejected))}
      end
    }
  end

  @spec take(ast) :: t
  def take(_amount = value) do
    amount = Macro.unique_var(:amount, __MODULE__)

    %{
      halt: true,
      extra_args: [amount],
      init: fn ->
        quote do: unquote(amount) = Runtime.validate_positive_integer(unquote(value))
      end,
      next_acc: fn vars, continue ->
        quote do
          case unquote(amount) do
            amount when amount > 0 ->
              unquote(amount) = amount - 1
              unquote_splicing(to_exprs(continue))

            _ ->
              {:__ITER_HALT__, unquote(vars.composite_acc)}
          end
        end
      end
    }
  end

  @spec drop(ast) :: t
  def drop(_amount = value) do
    amount = Macro.unique_var(:amount, __MODULE__)

    %{
      extra_args: [amount],
      init: fn ->
        quote do: unquote(amount) = Runtime.validate_positive_integer(unquote(value))
      end,
      next_acc: fn vars, continue ->
        quote do
          case unquote(amount) do
            amount when amount > 0 ->
              unquote(amount) = amount - 1
              unquote(vars.composite_acc)

            _ ->
              (unquote_splicing(to_exprs(continue)))
          end
        end
      end
    }
  end

  @spec split(ast) :: t
  def split(_amount = value) do
    amount = Macro.unique_var(:amount, __MODULE__)
    dropped = Macro.unique_var(:dropped, __MODULE__)

    %{
      collect: true,
      extra_args: [amount, dropped],
      init: fn ->
        quote do
          unquote(amount) = Runtime.validate_positive_integer(unquote(value))
          unquote(dropped) = []
        end
      end,
      next_acc: fn vars, continue ->
        quote do
          case unquote(amount) do
            amount when amount > 0 ->
              unquote(amount) = amount - 1
              (unquote_splicing(to_exprs(continue)))

            _ ->
              unquote(dropped) = [unquote(vars.elem) | unquote(dropped)]
              unquote(vars.composite_acc)
          end
        end
      end,
      wrap_acc: fn ast ->
        quote do: {:lists.reverse(unquote(ast)), :lists.reverse(unquote(dropped))}
      end
    }
  end

  @spec slice(ast) :: t
  def slice(range) do
    stop_index = Macro.unique_var(:stop_index, __MODULE__)
    step = Macro.unique_var(:step, __MODULE__)
    index = Macro.unique_var(:index, __MODULE__)

    %{
      halt: true,
      extra_args: [index],
      init: fn ->
        quote do
          {unquote(index), unquote(stop_index), unquote(step)} =
            Runtime.preprocess_slice_range(unquote(range))
        end
      end,
      next_acc: fn vars, continue ->
        quote do
          case unquote(index) do
            index when index > unquote(stop_index) ->
              {:__ITER_HALT__, unquote(vars.composite_acc)}

            index when index < 0 or rem(index, unquote(step)) != 0 ->
              unquote(index) = index + 1
              unquote(vars.composite_acc)

            index ->
              unquote(index) = index + 1
              unquote_splicing(to_exprs(continue))
          end
        end
      end
    }
  end

  @spec slice(ast, ast) :: t
  def slice(index_value, amount_value) do
    start_index = Macro.unique_var(:start_index, __MODULE__)
    stop_index = Macro.unique_var(:stop_index, __MODULE__)
    index = Macro.unique_var(:index, __MODULE__)

    %{
      halt: true,
      extra_args: [index],
      init: fn ->
        quote do
          amount = Runtime.validate_positive_integer(unquote(amount_value))

          unquote(start_index) =
            case amount do
              0 -> 0
              _ -> Runtime.validate_positive_integer(unquote(index_value))
            end

          unquote(stop_index) = amount + unquote(start_index)

          unquote(index) = 0
        end
      end,
      next_acc: fn vars, continue ->
        quote do
          case unquote(index) do
            index when index < unquote(start_index) ->
              unquote(index) = index + 1
              unquote(vars.composite_acc)

            index when index < unquote(stop_index) ->
              unquote(index) = index + 1
              unquote_splicing(to_exprs(continue))

            _ ->
              {:__ITER_HALT__, unquote(vars.composite_acc)}
          end
        end
      end
    }
  end

  @spec take_while(ast) :: t
  def take_while(fun) do
    %{
      halt: true,
      next_acc: fn vars, continue ->
        quote do
          if unquote(MacroHelpers.apply_fun(fun, vars.elem)) do
            (unquote_splicing(to_exprs(continue)))
          else
            {:__ITER_HALT__, unquote(vars.composite_acc)}
          end
        end
      end
    }
  end

  @spec drop_while(ast) :: t
  def drop_while(fun) do
    switch = Macro.unique_var(:switch, __MODULE__)

    %{
      extra_args: [switch],
      init: fn ->
        quote do
          unquote(switch) = false
        end
      end,
      next_acc: fn vars, continue ->
        quote do
          if unquote(switch) or !unquote(MacroHelpers.apply_fun(fun, vars.elem)) do
            unquote(switch) = true
            (unquote_splicing(to_exprs(continue)))
          else
            unquote(vars.composite_acc)
          end
        end
      end
    }
  end

  @spec split_while(ast) :: t
  def split_while(fun) do
    dropped = Macro.unique_var(:dropped, __MODULE__)

    %{
      collect: true,
      extra_args: [dropped],
      init: fn ->
        quote do
          unquote(dropped) = []
        end
      end,
      next_acc: fn vars, continue ->
        quote do
          if unquote(dropped) == [] && unquote(MacroHelpers.apply_fun(fun, vars.elem)) do
            (unquote_splicing(to_exprs(continue)))
          else
            unquote(dropped) = [unquote(vars.elem) | unquote(dropped)]
            unquote(vars.composite_acc)
          end
        end
      end,
      wrap_acc: fn ast ->
        quote do: {:lists.reverse(unquote(ast)), :lists.reverse(unquote(dropped))}
      end
    }
  end

  @spec uniq_by(ast) :: t
  def uniq_by(fun) do
    set = Macro.unique_var(:set, __MODULE__)

    %{
      extra_args: [set],
      init: fn ->
        quote do: unquote(set) = %{}
      end,
      next_acc: fn vars, continue ->
        quote do
          key = unquote(MacroHelpers.apply_fun(fun, vars.elem))

          case unquote(set) do
            %{^key => _} ->
              unquote(vars.composite_acc)

            _ ->
              unquote(set) = Map.put(unquote(set), key, [])
              unquote_splicing(to_exprs(continue))
          end
        end
      end
    }
  end

  @spec dedup_by(ast) :: t
  def dedup_by(fun) do
    previous = Macro.unique_var(:previous, __MODULE__)

    %{
      extra_args: [previous],
      init: fn ->
        quote do: unquote(previous) = :__ITER_RESERVED__
      end,
      next_acc: fn vars, continue ->
        quote do
          case unquote(MacroHelpers.apply_fun(fun, vars.elem)) do
            ^unquote(previous) ->
              unquote(vars.composite_acc)

            current ->
              unquote(previous) = current
              unquote_splicing(to_exprs(continue))
          end
        end
      end
    }
  end

  @spec reduce(ast) :: t
  def reduce(fun) do
    %{
      collect: true,
      initial_acc: fn -> :__ITER_RESERVED__ end,
      return_acc: fn vars ->
        quote do
          case unquote(vars.acc) do
            :__ITER_RESERVED__ -> unquote(vars.elem)
            acc -> unquote(fun).(unquote(vars.elem), acc)
          end
        end
      end,
      wrap_acc: fn ast ->
        quote do
          case unquote(ast) do
            :__ITER_RESERVED__ -> raise Enum.EmptyError
            acc -> acc
          end
        end
      end
    }
  end

  @spec reduce(ast, ast) :: t
  def reduce(initial, fun) do
    %{
      collect: true,
      initial_acc: fn -> initial end,
      return_acc: fn vars ->
        quote do: unquote(fun).(unquote(vars.elem), unquote(vars.acc))
      end,
      wrap_acc: fn ast -> ast end
    }
  end

  @spec map_reduce(ast, ast) :: t
  def map_reduce(initial, fun) do
    last_acc = Macro.unique_var(:initial, __MODULE__)

    %{
      collect: true,
      extra_args: [last_acc],
      init: fn -> quote do: unquote(last_acc) = unquote(initial) end,
      next_acc: fn vars, continue ->
        quote do
          {unquote(vars.elem), unquote(last_acc)} =
            unquote(fun).(unquote(vars.elem), unquote(last_acc))

          unquote_splicing(to_exprs(continue))
        end
      end,
      wrap_acc: fn ast ->
        quote do: {:lists.reverse(unquote(ast)), unquote(last_acc)}
      end
    }
  end

  @spec scan(ast, ast) :: t
  def scan(initial, fun) do
    last_acc = Macro.unique_var(:initial, __MODULE__)

    %{
      init: fn -> quote do: unquote(last_acc) = unquote(initial) end,
      extra_args: [last_acc],
      next_acc: fn vars, continue ->
        quote do
          unquote(last_acc) =
            unquote(vars.elem) = unquote(fun).(unquote(vars.elem), unquote(last_acc))

          unquote_splicing(to_exprs(continue))
        end
      end
    }
  end

  @spec into(ast, ast) :: t
  def into(collectable, fun) do
    case optimize_collectable(collectable) do
      nil ->
        initial_acc = Macro.unique_var(:initial_acc, __MODULE__)
        into_fun = Macro.unique_var(:into_fun, __MODULE__)

        %{
          collect: true,
          init: fn ->
            quote do
              {unquote(initial_acc), unquote(into_fun)} = Collectable.into(unquote(collectable))
            end
          end,
          initial_acc: fn -> initial_acc end,
          next_acc: map(fun).next_acc,
          return_acc: fn vars ->
            quote do: unquote(into_fun).(unquote(vars.acc), {:cont, unquote(vars.elem)})
          end,
          wrap_acc: fn ast -> ast end,
          wrap_reduce: fn ast ->
            quote do
              try do
                unquote(ast)
              catch
                kind, reason ->
                  unquote(into_fun).(unquote(initial_acc), :halt)
                  :erlang.raise(kind, reason, __STACKTRACE__)
              else
                acc -> unquote(into_fun).(acc, :done)
              end
            end
          end
        }

      :map ->
        %{
          collect: true,
          initial_acc: fn -> quote do: unquote(collectable) end,
          return_acc: fn vars ->
            quote do
              {key, value} = unquote(MacroHelpers.apply_fun(fun, vars.elem))
              Map.put(unquote(vars.acc), key, value)
            end
          end,
          wrap_acc: fn ast -> ast end
        }

      wrap_acc ->
        %{
          collect: true,
          next_acc: map(fun).next_acc,
          wrap_acc: wrap_acc
        }
    end
  end

  defp optimize_collectable({:%{}, _, []}) do
    raise "Unexpected case since this should have already been optimized upstream"
  end

  defp optimize_collectable({:%{}, _, list}) when is_list(list) do
    :map
  end

  defp optimize_collectable({{:., _, [{:__aliases__, _, [:MapSet]}, :new]}, _, []}) do
    fn ast -> quote do: MapSet.new(unquote(ast)) end
  end

  defp optimize_collectable([]) do
    fn ast -> quote do: :lists.reverse(unquote(ast)) end
  end

  defp optimize_collectable(_ast), do: nil

  @spec each(ast) :: t
  def each(fun) do
    %{
      collect: true,
      initial_acc: fn -> :ok end,
      next_acc: fn vars, continue ->
        quote do
          unquote(MacroHelpers.apply_fun(fun, vars.elem))
          unquote_splicing(to_exprs(continue))
        end
      end,
      return_acc: fn vars -> vars.acc end,
      wrap_acc: fn ast -> ast end
    }
  end

  @spec count() :: t
  def count() do
    %{
      collect: true,
      initial_acc: fn -> 0 end,
      return_acc: fn vars ->
        quote do: unquote(vars.acc) + 1
      end,
      wrap_acc: fn ast -> ast end
    }
  end

  @spec count(ast) :: t
  def count(fun) do
    %{
      collect: true,
      initial_acc: fn -> 0 end,
      return_acc: fn vars ->
        quote do
          if unquote(MacroHelpers.apply_fun(fun, vars.elem)) do
            unquote(vars.acc) + 1
          else
            unquote(vars.acc)
          end
        end
      end,
      wrap_acc: fn ast -> ast end
    }
  end

  @spec sum() :: t
  def sum() do
    %{
      collect: true,
      initial_acc: fn -> 0 end,
      return_acc: fn vars ->
        quote do: unquote(vars.elem) + unquote(vars.acc)
      end,
      wrap_acc: fn ast -> ast end
    }
  end

  @spec product() :: t
  def product() do
    %{
      collect: true,
      initial_acc: fn -> 1 end,
      return_acc: fn vars ->
        quote do: unquote(vars.elem) * unquote(vars.acc)
      end,
      wrap_acc: fn ast -> ast end
    }
  end

  @spec mean() :: t
  def mean() do
    count = Macro.unique_var(:count, __MODULE__)

    %{
      collect: true,
      extra_args: [count],
      initial_acc: fn -> 0 end,
      init: fn -> quote do: unquote(count) = 0 end,
      next_acc: fn _vars, continue ->
        quote do
          unquote(count) = unquote(count) + 1
          unquote_splicing(to_exprs(continue))
        end
      end,
      return_acc: fn vars ->
        quote do
          unquote(vars.elem) + unquote(vars.acc)
        end
      end,
      wrap_acc: fn ast ->
        quote do
          case unquote(count) do
            0 -> raise Enum.EmptyError
            count -> unquote(ast) / count
          end
        end
      end
    }
  end

  @spec max() :: t
  def max() do
    do_min_max(fn vars ->
      quote do
        acc when acc >= unquote(vars.elem) -> acc
        _ -> unquote(vars.elem)
      end
    end)
  end

  @spec min() :: t
  def min() do
    do_min_max(fn vars ->
      quote do
        acc when acc <= unquote(vars.elem) -> acc
        _ -> unquote(vars.elem)
      end
    end)
  end

  defp do_min_max(clauses_fun) do
    %{
      collect: true,
      initial_acc: fn -> :__ITER_RESERVED__ end,
      return_acc: fn vars ->
        clauses =
          quote do
            :__ITER_RESERVED__ -> unquote(vars.elem)
          end ++ clauses_fun.(vars)

        quote do
          case unquote(vars.acc) do
            unquote(clauses)
          end
        end
      end,
      wrap_acc: fn ast ->
        quote do
          case unquote(ast) do
            :__ITER_RESERVED__ -> raise Enum.EmptyError
            acc -> acc
          end
        end
      end
    }
  end

  @spec frequencies_by(ast) :: t
  def frequencies_by(fun) do
    %{
      collect: true,
      initial_acc: fn -> quote do: %{} end,
      return_acc: fn vars ->
        quote do
          unquote(vars.elem) = unquote(MacroHelpers.apply_fun(fun, vars.elem))

          case unquote(vars.acc) do
            acc = %{^unquote(vars.elem) => count} -> %{acc | unquote(vars.elem) => count + 1}
            acc -> Map.put(acc, unquote(vars.elem), 1)
          end
        end
      end,
      wrap_acc: fn ast -> ast end
    }
  end

  @spec group_by(ast, ast) :: t
  def group_by(key_fun, value_fun) do
    %{
      collect: true,
      wrap_acc: fn ast ->
        elem = Macro.unique_var(:elem, __MODULE__)

        quote do
          :lists.foldl(
            fn unquote(elem), acc ->
              key = unquote(MacroHelpers.apply_fun(key_fun, elem))

              values = [
                unquote(MacroHelpers.apply_fun(value_fun, elem)) | Map.get(acc, key, [])
              ]

              Map.put(acc, key, values)
            end,
            %{},
            unquote(ast)
          )
        end
      end
    }
  end

  @spec map_join(ast, ast) :: t
  def map_join(_joiner = "", mapper) do
    %{
      collect: true,
      return_acc: fn vars ->
        quote do
          string =
            case unquote(MacroHelpers.apply_fun(mapper, vars.elem)) do
              binary when is_binary(binary) -> binary
              other -> String.Chars.to_string(other)
            end

          [string | unquote(vars.acc)]
        end
      end,
      wrap_acc: fn ast ->
        quote do: :lists.reverse(unquote(ast)) |> IO.iodata_to_binary()
      end
    }
  end

  def map_join(_joiner = value, mapper) do
    joiner = Macro.unique_var(:joiner, __MODULE__)

    %{
      collect: true,
      init: fn ->
        quote do: unquote(joiner) = Runtime.validate_binary(unquote(value))
      end,
      return_acc: fn vars ->
        quote do
          string =
            case unquote(MacroHelpers.apply_fun(mapper, vars.elem)) do
              binary when is_binary(binary) -> binary
              other -> String.Chars.to_string(other)
            end

          [unquote(joiner), string | unquote(vars.acc)]
        end
      end,
      wrap_acc: fn ast ->
        quote do
          case unquote(ast) do
            [] -> ""
            [_joiner | tail] -> :lists.reverse(tail) |> IO.iodata_to_binary()
          end
        end
      end
    }
  end

  @spec map_intersperse(ast, ast) :: t
  def map_intersperse(separator, fun) do
    %{
      collect: true,
      next_acc: map(fun).next_acc,
      wrap_acc: fn ast ->
        quote do: Runtime.wrap_intersperse(unquote(ast), unquote(separator))
      end
    }
  end

  @spec empty?() :: t
  def empty?() do
    %{
      collect: true,
      halt: true,
      initial_acc: fn -> true end,
      next_acc: fn vars, _continue ->
        quote do
          unquote(vars.acc) = false
          {:__ITER_HALT__, unquote(vars.composite_acc)}
        end
      end,
      wrap_acc: fn ast -> ast end
    }
  end

  @spec any?(ast) :: t
  def any?(fun) do
    %{
      collect: true,
      halt: true,
      initial_acc: fn -> false end,
      next_acc: fn vars, _continue ->
        quote do
          if unquote(MacroHelpers.apply_fun(fun, vars.elem)) do
            unquote(vars.acc) = true
            {:__ITER_HALT__, unquote(vars.composite_acc)}
          else
            unquote(vars.composite_acc)
          end
        end
      end,
      wrap_acc: fn ast -> ast end
    }
  end

  @spec all?(ast) :: t
  def all?(fun) do
    %{
      collect: true,
      halt: true,
      initial_acc: fn -> true end,
      next_acc: fn vars, _continue ->
        quote do
          if unquote(MacroHelpers.apply_fun(fun, vars.elem)) do
            unquote(vars.composite_acc)
          else
            unquote(vars.acc) = false
            {:__ITER_HALT__, unquote(vars.composite_acc)}
          end
        end
      end,
      wrap_acc: fn ast -> ast end
    }
  end

  @spec member?(ast) :: t
  def member?(value) do
    element = Macro.unique_var(:element, __MODULE__)

    %{
      collect: true,
      extra_args: [element],
      halt: true,
      initial_acc: fn -> false end,
      init: fn ->
        quote do: unquote(element) = unquote(value)
      end,
      next_acc: fn vars, _continue ->
        quote do
          case unquote(vars.elem) do
            ^unquote(element) ->
              unquote(vars.acc) = true
              {:__ITER_HALT__, unquote(vars.composite_acc)}

            _ ->
              unquote(vars.composite_acc)
          end
        end
      end,
      wrap_acc: fn ast -> ast end
    }
  end

  @spec find(ast, ast) :: t
  def find(default, fun) do
    %{
      collect: true,
      halt: true,
      initial_acc: fn -> :__ITER_RESERVED__ end,
      next_acc: fn vars, _continue ->
        quote do
          if unquote(MacroHelpers.apply_fun(fun, vars.elem)) do
            unquote(vars.acc) = unquote(vars.elem)
            {:__ITER_HALT__, unquote(vars.composite_acc)}
          else
            unquote(vars.composite_acc)
          end
        end
      end,
      wrap_acc: fn ast ->
        quote do
          case unquote(ast) do
            :__ITER_RESERVED__ -> unquote(default)
            found -> found
          end
        end
      end
    }
  end

  @spec find_value(ast, ast) :: t
  def find_value(default, fun) do
    %{
      collect: true,
      halt: true,
      initial_acc: fn -> :__ITER_RESERVED__ end,
      next_acc: fn vars, _continue ->
        quote do
          if value = unquote(MacroHelpers.apply_fun(fun, vars.elem)) do
            unquote(vars.acc) = value
            {:__ITER_HALT__, unquote(vars.composite_acc)}
          else
            unquote(vars.composite_acc)
          end
        end
      end,
      wrap_acc: fn ast ->
        quote do
          case unquote(ast) do
            :__ITER_RESERVED__ -> unquote(default)
            found -> found
          end
        end
      end
    }
  end

  @spec find_index(ast) :: t
  def find_index(fun) do
    %{
      collect: true,
      halt: true,
      initial_acc: fn -> 0 end,
      next_acc: fn vars, _continue ->
        quote do
          if unquote(MacroHelpers.apply_fun(fun, vars.elem)) do
            unquote(vars.acc) = {:ok, unquote(vars.acc)}
            {:__ITER_HALT__, unquote(vars.composite_acc)}
          else
            unquote(vars.acc) = unquote(vars.acc) + 1
            unquote(vars.composite_acc)
          end
        end
      end,
      wrap_acc: fn ast ->
        quote do
          case unquote(ast) do
            {:ok, index} -> index
            _ -> nil
          end
        end
      end
    }
  end

  @spec at(ast, ast) :: t
  def at(index, default) do
    do_fetch(index, fn ast ->
      quote do
        case unquote(ast) do
          {:ok, found} -> found
          index when is_integer(index) -> unquote(default)
        end
      end
    end)
  end

  @spec fetch(ast) :: t
  def fetch(index) do
    do_fetch(index, fn ast ->
      quote do
        case unquote(ast) do
          index when is_integer(index) -> :error
          ok_tuple -> ok_tuple
        end
      end
    end)
  end

  @spec fetch!(ast) :: t
  def fetch!(index) do
    do_fetch(index, fn ast ->
      quote do
        case unquote(ast) do
          {:ok, found} -> found
          index when is_integer(index) -> raise Enum.OutOfBoundsError
        end
      end
    end)
  end

  defp do_fetch(_index = value, wrap_app) do
    %{
      collect: true,
      halt: true,
      initial_acc: fn ->
        quote do: Runtime.validate_positive_integer(unquote(value))
      end,
      next_acc: fn vars, continue ->
        quote do
          case unquote(vars.acc) do
            index when index > 0 ->
              unquote(vars.acc) = index - 1
              unquote_splicing(to_exprs(continue))

            _ ->
              unquote(vars.acc) = {:ok, unquote(vars.elem)}
              {:__ITER_HALT__, unquote(vars.composite_acc)}
          end
        end
      end,
      return_acc: fn vars -> vars.acc end,
      wrap_acc: wrap_app
    }
  end

  def first(default) do
    %{
      halt: true,
      collect: true,
      initial_acc: fn -> :__ITER_RESERVED__ end,
      next_acc: fn vars, _continue ->
        quote do
          unquote(vars.acc) = unquote(vars.elem)
          {:__ITER_HALT__, unquote(vars.composite_acc)}
        end
      end,
      wrap_acc: fn ast ->
        quote do
          case unquote(ast) do
            :__ITER_RESERVED__ -> unquote(default)
            found -> found
          end
        end
      end
    }
  end

  def last(default) do
    %{
      collect: true,
      initial_acc: fn -> :__ITER_RESERVED__ end,
      next_acc: fn vars, _continue ->
        quote do
          unquote(vars.acc) = unquote(vars.elem)
          unquote(vars.composite_acc)
        end
      end,
      wrap_acc: fn ast ->
        quote do
          case unquote(ast) do
            :__ITER_RESERVED__ -> unquote(default)
            found -> found
          end
        end
      end
    }
  end

  def reverse(tail) do
    %{
      collect: true,
      initial_acc: fn ->
        if is_list(tail) do
          tail
        else
          quote do: Enum.to_list(unquote(tail))
        end
      end,
      wrap_acc: fn ast -> ast end
    }
  end

  def to_list() do
    %{
      collect: true
    }
  end

  def sort(sorter) do
    %{
      collect: true,
      wrap_acc: fn ast ->
        case sorter do
          :asc -> quote do: :lists.sort(unquote(ast))
          _ -> quote do: Enum.sort(unquote_splicing([ast, sorter]))
        end
      end
    }
  end

  def sort_by(fun, sorter) do
    %{
      collect: true,
      wrap_acc: fn ast ->
        args =
          case sorter do
            :asc -> [ast, fun]
            _ -> [ast, fun, sorter]
          end

        quote do: Enum.sort_by(unquote_splicing(args))
      end
    }
  end

  @spec random() :: t
  def random() do
    # Tried a smarter approach to avoid building the list based on the
    # `Enum.random/1` algorithm, but it turned out to use much more memory
    # and be much slower due to the use of tuples.
    %{
      collect: true,
      wrap_acc: fn ast ->
        quote do: Runtime.wrap_random(unquote(ast))
      end
    }
  end

  @spec take_random(ast) :: t
  def take_random(_amount = value) do
    amount = Macro.unique_var(:amount, __MODULE__)
    idx = Macro.unique_var(:idx, __MODULE__)

    %{
      collect: true,
      extra_args: [idx],
      init: fn ->
        quote do
          unquote(amount) = Runtime.validate_positive_integer(unquote(value))
          unquote(idx) = -1
        end
      end,
      initial_acc: fn ->
        quote do
          if unquote(amount) <= 128 do
            Tuple.duplicate(nil, unquote(amount))
          else
            %{}
          end
        end
      end,
      next_acc: fn _vars, continue ->
        quote do
          unquote(idx) = unquote(idx) + 1
          unquote_splicing(to_exprs(continue))
        end
      end,
      return_acc: fn vars ->
        quote do
          Runtime.do_take_random(unquote_splicing([vars.acc, idx, amount, vars.elem]))
        end
      end,
      wrap_acc: fn ast ->
        quote do
          Runtime.wrap_take_random(
            unquote(ast),
            Kernel.min(unquote(amount), unquote(idx) + 1)
          )
        end
      end
    }
  end

  @spec shuffle() :: t
  def shuffle() do
    %{
      collect: true,
      next_acc: fn vars, continue ->
        quote do
          unquote(vars.elem) = {:rand.uniform(), unquote(vars.elem)}
          unquote_splicing(to_exprs(continue))
        end
      end,
      wrap_acc: fn ast ->
        quote do: Runtime.wrap_shuffle(unquote(ast))
      end
    }
  end

  @spec unzip() :: t
  def unzip() do
    second = Macro.unique_var(:second, __MODULE__)

    %{
      extra_args: [second],
      init: fn -> quote do: unquote(second) = [] end,
      next_acc: fn vars, continue ->
        quote do
          {unquote(vars.elem), right} = unquote(vars.elem)
          unquote(second) = [right | unquote(second)]
          unquote_splicing(to_exprs(continue))
        end
      end,
      wrap_acc: fn ast ->
        quote do: {:lists.reverse(unquote(ast)), :lists.reverse(unquote(second))}
      end
    }
  end

  @spec concat(ast) :: t
  def concat(right) do
    %{
      collect: true,
      wrap_acc: fn ast ->
        quote do
          unquote(right) |> Enum.reverse(unquote(ast)) |> :lists.reverse()
        end
      end
    }
  end

  @spec flat_map(ast) :: t
  def flat_map(fun) do
    %{
      next_acc: fn vars, continue ->
        quote do
          unquote(vars.elem) = unquote(MacroHelpers.apply_fun(fun, vars.elem))

          unquote(vars.reduce_module).unquote(vars.reduce_fun)(
            unquote(vars.elem),
            unquote(vars.composite_acc),
            fn unquote(vars.elem), unquote(vars.composite_acc) ->
              (unquote_splicing(to_exprs(continue)))
            end
          )
        end
      end
    }
  end

  @identity quote(do: & &1)

  @spec from_ast!(ast) :: t
  def from_ast!(ast) do
    case from_ast(ast) do
      nil ->
        {fun_with_arity, line} = MacroHelpers.fun_arity_and_line(ast)
        raise ArgumentError, "#{line}: Invalid function #{fun_with_arity}"

      step ->
        step
    end
  end

  @spec from_ast(ast) :: t | nil
  def from_ast(ast = {_, meta, _}) do
    case do_from_ast(ast) do
      nil -> nil
      step -> Map.put(step, :meta, meta)
    end
  end

  defp do_from_ast({:map, _, [fun]}), do: map(fun)
  defp do_from_ast({:with_index, _, []}), do: with_index(0)
  defp do_from_ast({:with_index, _, [fun]}), do: with_index(fun)
  defp do_from_ast({:match, _, [pattern, expr]}), do: match(pattern, expr)
  defp do_from_ast({:filter, _, [fun]}), do: filter(fun)
  defp do_from_ast({:reject, _, [fun]}), do: reject(fun)
  defp do_from_ast({:split_with, _, [fun]}), do: split_with(fun)
  defp do_from_ast({:take, _, [amount]}), do: take(amount)
  defp do_from_ast({:drop, _, [amount]}), do: drop(amount)
  defp do_from_ast({:split, _, [amount]}), do: split(amount)
  defp do_from_ast({:slice, _, [range]}), do: slice(range)
  defp do_from_ast({:slice, _, [start, amount]}), do: slice(start, amount)
  defp do_from_ast({:take_while, _, [fun]}), do: take_while(fun)
  defp do_from_ast({:drop_while, _, [fun]}), do: drop_while(fun)
  defp do_from_ast({:split_while, _, [fun]}), do: split_while(fun)
  defp do_from_ast({:uniq, _, []}), do: uniq_by(@identity)
  defp do_from_ast({:uniq_by, _, [fun]}), do: uniq_by(fun)
  defp do_from_ast({:dedup, _, []}), do: dedup_by(@identity)
  defp do_from_ast({:dedup_by, _, [fun]}), do: dedup_by(fun)
  defp do_from_ast({:count, _, []}), do: count()
  defp do_from_ast({:count, _, [fun]}), do: count(fun)
  defp do_from_ast({:reduce, _, [fun]}), do: reduce(fun)
  defp do_from_ast({:reduce, _, [acc, fun]}), do: reduce(acc, fun)
  defp do_from_ast({:map_reduce, _, [acc, fun]}), do: map_reduce(acc, fun)
  defp do_from_ast({:scan, _, [acc, fun]}), do: scan(acc, fun)
  defp do_from_ast({:into, _, [collectable]}), do: into(collectable, @identity)
  defp do_from_ast({:into, _, [collectable, fun]}), do: into(collectable, fun)
  defp do_from_ast({:each, _, [fun]}), do: each(fun)
  defp do_from_ast({:sum, _, []}), do: sum()
  defp do_from_ast({:product, _, []}), do: product()
  defp do_from_ast({:mean, _, []}), do: mean()
  defp do_from_ast({:max, _, []}), do: max()
  defp do_from_ast({:min, _, []}), do: min()
  defp do_from_ast({:frequencies, _, []}), do: frequencies_by(@identity)
  defp do_from_ast({:frequencies_by, _, [fun]}), do: frequencies_by(fun)
  defp do_from_ast({:group_by, _, [key_fun]}), do: group_by(key_fun, @identity)
  defp do_from_ast({:group_by, _, [key_fun, value_fun]}), do: group_by(key_fun, value_fun)
  defp do_from_ast({:join, _, []}), do: map_join("", @identity)
  defp do_from_ast({:join, _, [joiner]}), do: map_join(joiner, @identity)
  defp do_from_ast({:map_join, _, [mapper]}), do: map_join("", mapper)
  defp do_from_ast({:map_join, _, [joiner, mapper]}), do: map_join(joiner, mapper)
  defp do_from_ast({:intersperse, _, [elem]}), do: map_intersperse(elem, @identity)
  defp do_from_ast({:map_intersperse, _, [elem, sep]}), do: map_intersperse(elem, sep)
  defp do_from_ast({:empty?, _, []}), do: empty?()
  defp do_from_ast({:any?, _, []}), do: any?(@identity)
  defp do_from_ast({:any?, _, [fun]}), do: any?(fun)
  defp do_from_ast({:all?, _, []}), do: all?(@identity)
  defp do_from_ast({:all?, _, [fun]}), do: all?(fun)
  defp do_from_ast({:member?, _, [elem]}), do: member?(elem)
  defp do_from_ast({:find, _, [fun]}), do: find(nil, fun)
  defp do_from_ast({:find, _, [default, fun]}), do: find(default, fun)
  defp do_from_ast({:find_value, _, [fun]}), do: find_value(nil, fun)
  defp do_from_ast({:find_value, _, [default, fun]}), do: find_value(default, fun)
  defp do_from_ast({:find_index, _, [fun]}), do: find_index(fun)
  defp do_from_ast({:at, _, [index]}), do: at(index, nil)
  defp do_from_ast({:fetch, _, [index]}), do: fetch(index)
  defp do_from_ast({:fetch!, _, [index]}), do: fetch!(index)
  defp do_from_ast({:at, _, [index, default]}), do: at(index, default)
  defp do_from_ast({:first, _, []}), do: first(nil)
  defp do_from_ast({:first, _, [default]}), do: first(default)
  defp do_from_ast({:last, _, []}), do: last(nil)
  defp do_from_ast({:last, _, [default]}), do: last(default)
  defp do_from_ast({:reverse, _, []}), do: reverse([])
  defp do_from_ast({:reverse, _, [tail]}), do: reverse(tail)
  defp do_from_ast({:to_list, _, []}), do: to_list()
  defp do_from_ast({:sort, _, []}), do: sort(:asc)
  defp do_from_ast({:sort, _, [sorter]}), do: sort(sorter)
  defp do_from_ast({:sort_by, _, [fun]}), do: sort_by(fun, :asc)
  defp do_from_ast({:sort_by, _, [fun, sorter]}), do: sort_by(fun, sorter)
  defp do_from_ast({:random, _, []}), do: random()
  defp do_from_ast({:take_random, _, [amount]}), do: take_random(amount)
  defp do_from_ast({:shuffle, _, []}), do: shuffle()
  defp do_from_ast({:unzip, _, []}), do: unzip()
  defp do_from_ast({:concat, _, []}), do: flat_map(@identity)
  defp do_from_ast({:concat, _, [right]}), do: concat(right)
  defp do_from_ast({:flat_map, _, [fun]}), do: flat_map(fun)

  defp do_from_ast(_ast), do: nil
end

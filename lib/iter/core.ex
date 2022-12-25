defmodule Iter.Core do
  @moduledoc false

  alias Iter.MacroHelpers
  alias Iter.Runtime
  alias Iter.Step

  defmacro def_iter({fun, _, [enum | args]}) do
    quote do
      defmacro unquote(fun)(unquote_splicing([enum | args])) do
        meta = Macro.Env.location(__CALLER__)
        pipeline(unquote(enum), __CALLER__, [{unquote(fun), meta, unquote(args)}])
      end
    end
  end

  def pipeline(ast, env, acc) do
    ast
    |> prepare_pipeline(env, acc)
    |> transpile_pipeline()
  end

  def prepare_pipeline(ast, env, acc) do
    acc = Enum.map(acc, &{&1, Step.from_ast!(&1)})
    {first, steps} = extract_pipeline_steps(ast, env, acc)
    {first, Enum.reverse(steps)}
  end

  defp extract_pipeline_steps(ast, env, acc) do
    with {:ok, arg, step_ast} <- split_call(ast, env),
         step when step != nil <- Step.from_ast(step_ast) do
      if step[:collect] && acc != [] do
        {Macro.expand(ast, env), acc}
      else
        extract_pipeline_steps(arg, env, [{ast, step} | acc])
      end
    else
      _ ->
        {ast, acc}
    end
  end

  @not_real_steps [:explain, :zip]

  defp split_call(ast = {_, meta, args}, env) when is_list(args) do
    case MacroHelpers.normalize_call_function(ast, env) do
      {Kernel, :|>, [left, right]} ->
        case MacroHelpers.normalize_call_function(right, env) do
          {Iter, fun, args} when fun not in @not_real_steps ->
            {_, meta, _} = right
            {:ok, left, {fun, meta, args}}

          _ ->
            :error
        end

      {Iter, fun, [arg | args]} when fun not in @not_real_steps ->
        {:ok, arg, {fun, meta, args}}

      _ ->
        :error
    end
  end

  defp split_call(_ast, _env), do: :error

  @non_existing_functions [:match, :first, :last, :mean]

  defp transpile_pipeline({first, [{{fun, _, args}, _step}]})
       when fun not in @non_existing_functions do
    quote do
      Enum.unquote(fun)(unquote_splicing([first | args]))
    end
  end

  defp transpile_pipeline({first, steps}) do
    {_, [last | _] = steps} = Enum.unzip(steps)
    vars = init_vars(steps)

    initial_acc = Step.initial_acc(last)

    return =
      quote do
        unquote(vars.acc) = unquote(Step.return_acc(last, vars))
        unquote(vars.composite_acc)
      end

    body =
      Enum.reduce(steps, return, fn step, continue ->
        Step.next_acc(step, vars, continue)
      end)

    inits =
      for step <- steps, init <- Step.init(step) |> MacroHelpers.to_exprs(), init != nil, do: init

    wrap_reduce = fn reduce -> Step.wrap_reduce(last, vars, reduce) end

    quote do
      unquote_splicing(inits)
      unquote(vars.acc) = unquote(initial_acc)

      unquote(vars.composite_acc) =
        unquote(
          wrap_reduce.(
            quote do
              unquote(vars.reduce_module).unquote(vars.reduce_fun)(
                unquote(first),
                unquote(vars.composite_acc),
                fn unquote(vars.elem), unquote(vars.composite_acc) -> unquote(body) end
              )
            end
          )
        )

      unquote(Step.wrap_acc(last, vars.acc))
    end
    |> MacroHelpers.remove_useless_assigns()
  end

  defp init_vars(steps) do
    extra_args = Enum.flat_map(steps, &Map.get(&1, :extra_args, []))

    {reduce_module, reduce_fun} =
      if Enum.any?(steps, & &1[:halt]) do
        {Runtime, :reduce_while}
      else
        {Enum, :reduce}
      end

    [:elem, :rest, :acc]
    |> Map.new(&{&1, Macro.unique_var(&1, __MODULE__)})
    |> Map.put(:extra_args, extra_args)
    |> Map.put(:reduce_module, reduce_module)
    |> Map.put(:reduce_fun, reduce_fun)
    |> add_composite_acc()
  end

  defp add_composite_acc(vars = %{acc: acc, extra_args: extra}) do
    composite_acc = composite_acc(acc, extra)
    Map.put(vars, :composite_acc, composite_acc)
  end

  defp composite_acc(acc, []), do: acc

  defp composite_acc(acc, extra) do
    quote do: {unquote(acc), unquote_splicing(extra)}
  end
end

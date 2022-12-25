defmodule Iter.MacroHelpers do
  @moduledoc false

  @doc """
  Resolves the module, function name and arity for a function call AST.

  ## Examples

      iex> normalize_call_function(quote(do: inspect(123)), __ENV__)
      {Kernel, :inspect, [123]}

      iex> normalize_call_function(quote(do: String.upcase("foo")), __ENV__)
      {String, :upcase, ["foo"]}

      iex> alias String, as: S
      iex> normalize_call_function(quote(do: S.upcase("foo")), __ENV__)
      {String, :upcase, ["foo"]}

      iex> normalize_call_function(quote(do: foo(123)), __ENV__)
      :error

  """
  def normalize_call_function({call, _, args}, env) do
    do_normalize_call_function(call, args, env)
  end

  defp do_normalize_call_function(name, args, env) when is_atom(name) do
    arity = length(args)

    case Macro.Env.lookup_import(env, {name, arity}) do
      [{fun_or_macro, module}] when fun_or_macro in [:function, :macro] -> {module, name, args}
      _ -> :error
    end
  end

  defp do_normalize_call_function({:., _, [{:__aliases__, _, _} = module, fun]}, args, env) do
    module = Macro.expand(module, env)
    {module, fun, args}
  end

  defp do_normalize_call_function({:., _, [module, fun]}, args, _env) when is_atom(module) do
    {module, fun, args}
  end

  defp do_normalize_call_function(_call, _args, _env), do: :error

  def fun_arity_and_line({fun, meta, args}) do
    arity = length(args) + 1
    {"Iter.#{fun}/#{arity}", meta[:line]}
  end

  def remove_useless_assigns(ast) do
    Macro.postwalk(ast, fn
      {:__block__, meta, nodes} ->
        nodes = Enum.reject(nodes, &assigning_var_to_self?/1)

        case Enum.reverse(nodes) do
          [var, {:=, _, [var, node]}] -> node
          [var, {:=, _, [var, node]} | rest] -> {:__block__, meta, Enum.reverse(rest, [node])}
          _ -> {:__block__, meta, nodes}
        end

      node ->
        node
    end)
  end

  defp assigning_var_to_self?({:=, _, [var1, var2]}), do: same_var?(var1, var2)
  defp assigning_var_to_self?(_), do: false

  defp same_var?({var, meta1, ctx}, {var, meta2, ctx}) when is_atom(var) and is_atom(ctx),
    do: meta1[:counter] == meta2[:counter]

  defp same_var?(_, _), do: false

  def to_exprs({:__block__, _, exprs}), do: exprs
  def to_exprs(expr), do: [expr]

  def apply_fun(fun, arg) do
    with {var, _, ctx} when is_atom(var) and is_atom(ctx) <- arg,
         {call, _, _} when call in [:fn, :&] <- fun,
         new_ast when new_ast != {nil} <- apply_fun_to_var(fun, arg) do
      new_ast
    else
      _ ->
        quote do: unquote(fun).(unquote(arg))
    end
  end

  # Optimizing by inlining the function call when possible.
  # The compiler should be doing this, but it seems to still improve performance.
  defp apply_fun_to_var({:fn, _, [{:->, _, [[arg = {name, _, ctx}], ast]}]}, var)
       when is_atom(name) and is_atom(ctx) do
    substitute_var(ast, var, &same_var?(&1, arg))
  end

  defp apply_fun_to_var({:&, _, [{:/, _, [call, 1]}]}, var) do
    case call do
      {fun, meta, ctx} when is_atom(fun) and is_atom(ctx) ->
        {fun, meta, [var]}

      {{:., _, [mod, fun]}, _, []} ->
        quote do: unquote(mod).unquote(fun)(unquote(var))
    end
  end

  defp apply_fun_to_var({:&, _, [ast]}, var) do
    substitute_var(ast, var, fn
      {:&, _, [1]} -> true
      {:&, _, [_]} -> throw(:abandon)
      _ -> false
    end)
  end

  # use non-valid AST
  defp apply_fun_to_var(_, _), do: {nil}

  defp substitute_var(ast, arg, condition?) do
    try do
      Macro.postwalk(ast, fn
        ast -> if condition?.(ast), do: arg, else: ast
      end)
    catch
      :abandon ->
        {nil}
    end
  end

  def inspect_ast(ast) do
    ast |> Macro.to_string() |> IO.puts()
    ast
  end
end

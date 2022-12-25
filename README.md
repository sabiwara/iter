# Iter

[![Hex Version](https://img.shields.io/hexpm/v/iter.svg)](https://hex.pm/packages/iter)
[![docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/iter/)
[![CI](https://github.com/sabiwara/iter/workflows/CI/badge.svg)](https://github.com/sabiwara/iter/actions?query=workflow%3ACI)

<!-- MDOC !-->

A blazing fast compile-time optimized alternative to the `Enum` and `Stream`
modules.

## Overview

`Iter` allows you to effortlessly write highly-efficient pipelines to process
enumerables, in a familiar and highly readable style.

```elixir
iex> require Iter
iex> 1..10 |> Iter.map(& &1 ** 2) |> Iter.sum()
385
```

`Iter` will merge both the `map` and `sum` steps and perform both in one single
pass. Unlike the same pipeline written with `Enum`, it won't build any
intermediate list, therefore saving memory and CPU cycles.

You can think of `Iter` as compile-time streams, or as comprehensions on
steroids. It should be highly efficient compared to the same pipeline written
with `Stream`, since it does most of the work at compile time without any
runtime overhead. And while it actually works very similarly to `for/1` under
the hood and basically emits the same code, it offers a much more flexible,
composable and extensive API.

The `benchmarks` folder illustrates how `Iter` compares to `Enum` or `Stream`
through some examples.

Because `Iter` is compile-time, these are macros and not functions. This has
several implications:

- you have to `require` the module first before using it
- they won't appear in the stacktrace in case of errors (but `Iter` tries to
  make sure that stacktraces will point to the line of the step responsible)
- if you "break" the pipeline, `Iter` won't be able to optimize it as a single
  pass: it will suffer the same issue as `Enum`

```elixir
1..10
|> Iter.map(& &1 ** 2)
|> IO.inspect() # <= pipeline broken, creates an intermediate list
|> Iter.sum()
```

When there is no possibility of merging steps, `Iter` is simply delegating to
`Enum` which is optimized plenty on individual steps.

<!-- MDOC !-->

## Installation

`Iter` can be installed by adding `iter` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:iter, "~> 0.1.0"}
  ]
end
```

The documentation can be found at
[https://hexdocs.pm/iter](https://hexdocs.pm/iter).

## Motivation

`Iter` aims to provide a production-ready alternative to the `Enum` and `Stream`
modules, that allows to write enumerable pipelines in a familiar way without a
need to be concerned about efficiency.

Premature optimization is the root of all evil. But by consistently providing
better performance out of the box, `Iter` aims to help focusing more on writing
readable code, and to remove the tradeoff between readability and performance.

While `Iter` is close to offer a drop-in replacement for `Enum`/`Stream`, it
doesn't aim to be an exact one. The [Consistency section](#consistency) below
covers the differences with the standard library.

<!-- MDOC !-->

## Consistency

`Iter` is mostly consistent with the standard library, but it is prioritizing
efficiency over absolute consistency with the `Enum` and `Stream` modules, which
implies some slight differences. These differences are always documented in the
concerned macro docs.

### Negative indexes

`Iter` only supports positive indexes when inside a pipeline, so most of
functions like `at/1`, `slice/1` or `take/1` which would also accept negative
indexes cannot be replaced in cases needing it. The reason is simple: working
with negative indexes implies to materialize the whole list once. If you need
it, you should replace the relevant step to use `Enum`, or maybe call
`Iter.reverse/1` before accessing it (see
[_Collecting the pipeline_](#module-collecting-the-pipeline) section).

### API differences

`Iter` should cover most of the `Enum` API, but:

- some operations are still missing
- some operations won't be added because cannot be implemented efficiently
- some extra functions are being provided: `Iter.mean/1`, `Iter.first/1`,
  `Iter.last/1` (to compensate with the lack of negative indexes) and
  `Iter.match/3` (pattern-match to filter and extract at once, like in
  comprehensions)

## Collecting the pipeline

Some operations like `Iter.to_list/1`, `Iter.reverse/2`, `Iter.reduce/3`,
`Iter.group_by/2`... need to materialize an intermediate list or accumulator and
will collect the pipeline.

Operations that are collecting the pipeline are always mentioning it in their
documentation.

Here is a simple example:

```elixir
users
|> Iter.map(&fetch_user/1)
|> Iter.reject(&is_nil/1)
|> Iter.each(&process_user/1)
```

The pipeline above will start processing users as they are retrieved, in one
single pass. But assuming we want to make sure to be able to first retrieving
all users before starting the processing step, `Iter.to_list/1` can be used to
make the intent explicit:

```elixir
users
|> Iter.map(&fetch_user/1)
|> Iter.reject(&is_nil/1)
|> Iter.to_list()  # forcing the pipeline to collect
|> Iter.each(&process_user/1)
```

Forcing a pipeline to collect through `Enum.to_list/1` (or `Enum.reverse/1`,
faster) can also be used to circumvent some of `Iter`'s limitations like the
absence of negative indexes support:

```elixir
foo
|> Iter.map(&bar/1)
|> Iter.to_list()  # forcing the pipeline to collect
|> Iter.take(maybe_negative_index)
```

In the example above, `Iter.take/2` is now the only step of its pipeline and can
support negative indexing. The extra pass required is made explicit.

<!-- MDOC !-->

## Resources

Still learning `Enum` and struggling to find the right function? Make sure to
check our [Ultimate`Enum` cheatsheet](https://hexdocs.pm/iter/enum.html)!

## Copyright and License

Iter is licensed under the [MIT License](LICENSE.md).

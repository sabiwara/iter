inputs = Enum.map([100, 10_000], &{&1, Enum.shuffle(1..&1)})

defmodule Bench do
  require Iter

  def enum(list), do: list |> Enum.map(&(&1 + 1)) |> Enum.take_random(20)
  def stream(list), do: list |> Stream.map(&(&1 + 1)) |> Enum.take_random(20)
  def iter(list), do: list |> Iter.map(&(&1 + 1)) |> Iter.take_random(20)
end

Benchee.run(
  %{
    "Enum" => &Bench.enum/1,
    "Stream" => &Bench.stream/1,
    "Iter" => &Bench.iter/1
  },
  time: 2,
  memory_time: 0.5,
  inputs: inputs
)

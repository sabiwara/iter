list = Enum.shuffle(1..100)

defmodule Bench do
  require Iter

  def enum(list), do: list |> Enum.map(&(&1 + 1)) |> Enum.sort()
  def stream(list), do: list |> Stream.map(&(&1 + 1)) |> Enum.sort()
  def iter(list), do: list |> Iter.map(&(&1 + 1)) |> Iter.sort()
end

Benchee.run(
  %{
    "Enum" => fn -> Bench.enum(list) end,
    "Stream" => fn -> Bench.stream(list) end,
    "Iter" => fn -> Bench.iter(list) end
  },
  time: 2,
  memory_time: 0.5
)

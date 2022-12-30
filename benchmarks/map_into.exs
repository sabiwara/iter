list = Enum.shuffle(1..100)

defmodule Bench do
  require Iter

  def enum(list), do: list |> Enum.map(&{&1, &1}) |> Enum.into(%{})
  def stream(list), do: list |> Stream.map(&{&1, &1}) |> Enum.into(%{})
  def iter(list), do: list |> Iter.map(&{&1, &1}) |> Iter.into(%{})
  def map_new(list), do: Map.new(list, &{&1, &1})

  def comprehension(list) do
    for x <- list, into: %{}, do: {x, x}
  end
end

Benchee.run(
  %{
    "Enum" => fn -> Bench.enum(list) end,
    "Stream" => fn -> Bench.stream(list) end,
    "Iter" => fn -> Bench.iter(list) end,
    "for" => fn -> Bench.comprehension(list) end,
    "Map.new/2" => fn -> Bench.map_new(list) end
  },
  time: 2,
  memory_time: 0.5
)

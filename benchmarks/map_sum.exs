list = Enum.to_list(1..100)

defmodule Bench do
  require Iter

  def enum(list), do: list |> Enum.map(&(&1 + 1)) |> Enum.sum()
  def stream(list), do: list |> Stream.map(&(&1 + 1)) |> Enum.sum()
  def iter(list), do: list |> Iter.map(&(&1 + 1)) |> Iter.sum()

  def reduce(list) do
    Enum.reduce(list, 0, &(&1 + 1 + &2))
  end
end

Benchee.run(
  %{
    "Enum" => fn -> Bench.enum(list) end,
    "Stream" => fn -> Bench.stream(list) end,
    "manual reduce" => fn -> Bench.reduce(list) end,
    "Iter" => fn -> Bench.iter(list) end
  },
  time: 2,
  memory_time: 0.5
)

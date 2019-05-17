add_scenario = fn inputs, size ->
  cell_size = 500

  prefix =
    size
    |> Integer.floor_div(1000)
    |> Integer.to_string(10)
    |> String.pad_leading(4, "0")

  padded_size =
    size
    |> Integer.to_string(10)
    |> String.pad_leading(7, " ")

  [:beginning, :middle, :ending]
  |> Enum.with_index(1)
  |> Enum.reduce(inputs, fn {placement, idx}, inputs ->
    human_placement =
      placement
      |> Atom.to_string()
      |> String.capitalize()

    key = "#{prefix}-#{idx}. #{padded_size} Set // #{cell_size} cell // #{human_placement}"
    Map.put(inputs, key, {size, cell_size, placement})
  end)
end

make_sorted_set_input = fn {size, cell_size, position} ->
  set =
    1..size
    |> Enum.map(&(&1 * 10_000))
    |> Discord.SortedSet.from_proper_enumerable(cell_size)

  item =
    case position do
      :beginning ->
        15000

      :middle ->
        size * 5000 + 5000

      :ending ->
        size * 10000 + 5000
    end

  {set, item, size}
end

make_ets_input = fn {size, _cell_size, position} ->
  set = :ets.new(:set, [:private, :ordered_set])
  :ets.insert(set, Enum.map(1..size, &{&1 * 10_000}))

  item =
    case position do
      :beginning ->
        15000

      :middle ->
        size * 5000 + 5000

      :ending ->
        size * 10000 + 5000
    end

  {set, item, size}
end

verify_sorted_set = fn {set, size} ->
  expected = size + 1000
  actual = Discord.SortedSet.size(set)

  if expected != actual do
    raise "Set size incorrect: expected #{expected} but found #{actual}"
  end
end

verify_ets = fn {set, size} ->
  expected = size + 1000
  actual = :ets.info(set, :size)

  if expected != actual do
    raise "Set size incorrect: expected #{expected} but found #{actual}"
  end
end

Benchee.run(
  %{
    "SortedSet" => {
      fn {set, item, size} ->
        for i <- 1..1000 do
          Discord.SortedSet.add(set, item + i)
        end

        {set, size}
      end,
      before_each: make_sorted_set_input, after_each: verify_sorted_set
    },
    "ETS" => {
      fn {set, item, size} ->
        for i <- 1..1000 do
          :ets.insert(set, {item + i})
        end

        {set, size}
      end,
      before_each: make_ets_input, after_each: verify_ets
    },
    "ETS batch" => {
      fn {set, item, size} ->
        data = for i <- 1..1000, do: {item + i}
        :ets.insert(set, data)

        {set, size}
      end,
      before_each: make_ets_input, after_each: verify_ets
    }
  },
  inputs:
    %{}
    |> add_scenario.(5000)
    |> add_scenario.(50_000)
    |> add_scenario.(250_000)
    |> add_scenario.(500_000)
    |> add_scenario.(750_000)
    |> add_scenario.(1_000_000),
  formatters: [
    &Benchee.Formatters.Console.output/1,
    &Benchee.Formatters.HTML.output/1
  ],
  formatter_options: [
    html: [file: "bench/results/add/html/add.html"]
  ],
  save: %{
    path: "bench/results/add/runs"
  }
  # time: 60
)

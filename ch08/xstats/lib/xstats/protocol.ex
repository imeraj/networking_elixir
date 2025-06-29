defmodule Xstats.Protocol do
  @moduledoc false

  @type metric() :: {:gauge | :counter, name :: String.t(), value :: number()}

  @spec encode_metric(metric()) :: iodata()
  def encode_metric({type, name, value})
      when is_binary(name) and is_number(value) do
    case type do
      :counter -> [name, ?:, to_string(value), "|c\n"]
      :gauge -> [name, ?:, to_string(value), "|g\n"]
    end
  end

  @spec parse_metrics(binary()) :: {metrics :: [metric()], errors :: [binary()]}
  def parse_metrics(packet) when is_binary(packet) do
    lines = String.split(packet, "\n", trim: true)
    initial_acc = {_metrics = [], _errors = []}

    {metrics, errors} =
      Enum.reduce(lines, initial_acc, fn line, {metrics, errors} ->
        case parse_line(line) do
          {:ok, metric} -> {[metric | metrics], errors}
          {:error, error} -> {metrics, [error | errors]}
        end
      end)

    {Enum.reverse(metrics), Enum.reverse(errors)}
  end

  defp parse_line(line) do
    case String.split(line, ["|", ":"]) do
      [name, value, type] ->
        with {:ok, type} <- parse_type(type),
             {:ok, value} <- parse_number(value) do
          {:ok, {type, name, value}}
        end

      _ ->
        {:error, "invalid line format: #{inspect(line)}"}
    end
  end

  defp parse_type("c"), do: {:ok, :counter}
  defp parse_type("g"), do: {:ok, :gauge}
  defp parse_type(other), do: {:erroor, "invalid type: #{inspect({other})}"}

  defp parse_number(value) do
    case Integer.parse(value) do
      {int, ""} ->
        {:ok, int}

      _ ->
        case Float.parse(value) do
          {float, ""} ->
            {:ok, float}

          _ ->
            {:error, "invalid value: #{inspect(value)}"}
        end
    end
  end
end

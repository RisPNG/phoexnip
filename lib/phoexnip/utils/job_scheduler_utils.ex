defmodule Phoexnip.JobUtils do
  @moduledoc """
  Provides utilities for parsing cron expressions and generating
  human-readable descriptions of their schedule components.

  ## Functions

    * `describe_cron/1` — Parses a cron expression string and returns
      a natural-language description of its timing, or an error tuple
      if the expression is invalid.
  """

  alias Crontab.CronExpression.Parser
  alias Crontab.CronExpression

  @doc """
  Parses the given cron `expression` and returns a human-readable
  description of its schedule.

  ## Examples

      iex> Phoexnip.JobUtils.describe_cron("*/15 * * * *")
      "every 15 minutes, every hour, every day, every day of the week, every month"

      iex> Phoexnip.JobUtils.describe_cron("0 0 1 * *")
      "at minute 0, at hour 0, on day 1, every day of the week, every month"

      iex> Phoexnip.JobUtils.describe_cron("invalid")
      {:error, "Invalid cron expression: syntax error before: \"invalid\""}
  """
  @spec describe_cron(String.t()) :: String.t() | {:error, String.t()}
  def describe_cron(expression) do
    case Parser.parse(expression) do
      {:ok, cron} ->
        generate_description(cron)

      {:error, reason} ->
        {:error, "Invalid cron expression: #{reason}"}
    end
  end

  @doc false
  @spec generate_description(CronExpression.t()) :: String.t()
  defp generate_description(%CronExpression{
         minute: minute,
         hour: hour,
         day: day,
         month: month,
         weekday: weekday
       }) do
    [
      describe_minute(minute),
      describe_hour(hour),
      describe_day(day),
      describe_weekday(weekday),
      describe_month(month)
    ]
    |> Enum.filter(& &1)
    |> Enum.join(", ")
  end

  # Private helpers for each cron field
  defp describe_minute([:*]), do: "every minute"
  defp describe_minute([minute]) when is_integer(minute), do: "at minute #{minute}"
  defp describe_minute([{:-, start, finish}]), do: "at minutes from #{start} to #{finish}"
  defp describe_minute([{:/, :*, step}]), do: "every #{step} minutes"

  defp describe_minute(minutes) when is_list(minutes) do
    minutes
    |> Enum.map(&Integer.to_string/1)
    |> Enum.join(" and ")
    |> (&"at minutes #{&1}").()
  end

  defp describe_hour([:*]), do: "every hour"
  defp describe_hour([hour]) when is_integer(hour), do: "at hour #{hour}"
  defp describe_hour([{:-, start, finish}]), do: "at hours from #{start} to #{finish}"
  defp describe_hour([{:/, :*, step}]), do: "every #{step} hours"

  defp describe_hour(hours) when is_list(hours) do
    hours
    |> Enum.map(&Integer.to_string/1)
    |> Enum.join(" and ")
    |> (&"at hours #{&1}").()
  end

  defp describe_day([:*]), do: "every day"
  defp describe_day([day]) when is_integer(day), do: "on day #{day}"
  defp describe_day([{:-, start, finish}]), do: "on days from #{start} to #{finish}"
  defp describe_day([{:/, :*, step}]), do: "every #{step} days"

  defp describe_day(days) when is_list(days) do
    days
    |> Enum.map(&Integer.to_string/1)
    |> Enum.join(" and ")
    |> (&"on days #{&1}").()
  end

  defp describe_weekday([:*]), do: "every day of the week"
  defp describe_weekday([wd]) when is_integer(wd), do: "on #{weekday_name(Integer.to_string(wd))}"
  defp describe_weekday([wd]) when is_atom(wd), do: "on #{weekday_name(Atom.to_string(wd))}"

  defp describe_weekday([{:-, start, finish}]) do
    "on weekdays from #{weekday_name(Integer.to_string(start))} to #{weekday_name(Integer.to_string(finish))}"
  end

  defp describe_weekday([{:/, :*, step}]), do: "every #{step} days of the week"

  defp describe_weekday(wds) when is_list(wds) do
    wds
    |> Enum.map(&weekday_name(Integer.to_string(&1)))
    |> Enum.join(" and ")
    |> (&"on #{&1}").()
  end

  defp describe_month([:*]), do: "every month"
  defp describe_month([m]) when is_integer(m), do: "in month #{month_name(m)}"

  defp describe_month([{:-, start, finish}]),
    do: "in months from #{month_name(start)} to #{month_name(finish)}"

  defp describe_month([{:/, :*, step}]), do: "every #{step} months"

  defp describe_month(ms) when is_list(ms) do
    ms
    |> Enum.map(&month_name/1)
    |> Enum.join(" and ")
    |> (&"in months #{&1}").()
  end

  @doc false
  @spec month_name(integer()) :: String.t()
  defp month_name(month) when is_integer(month) do
    case month do
      1 -> "January"
      2 -> "February"
      3 -> "March"
      4 -> "April"
      5 -> "May"
      6 -> "June"
      7 -> "July"
      8 -> "August"
      9 -> "September"
      10 -> "October"
      11 -> "November"
      12 -> "December"
      _ -> "Invalid month"
    end
  end

  @doc false
  @spec weekday_name(String.t()) :: String.t()
  defp weekday_name("0"), do: "Sunday"
  defp weekday_name("1"), do: "Monday"
  defp weekday_name("2"), do: "Tuesday"
  defp weekday_name("3"), do: "Wednesday"
  defp weekday_name("4"), do: "Thursday"
  defp weekday_name("5"), do: "Friday"
  defp weekday_name("6"), do: "Saturday"
  defp weekday_name(_), do: "an unknown day"
end

defmodule Beeleex.Helpers do
  @moduledoc false

  require Logger

  def env(key, default \\ nil) do
    Application.get_env(:beeleex, key)
    |> case do
      nil -> default
      value -> value
    end
  end

  @spec compute_cycle_days(String.t(), DateTime.t(), DateTime.t() | nil) :: map()
  def compute_cycle_days(cycle_type, next_execution_date, current_date \\ DateTime.utc_now()) do
    remaining_days = DateTime.diff(next_execution_date, current_date, :day)

    total_duration =
      case cycle_type do
        "week" ->
          # A week is always 7 days
          7

        "month" ->
          Date.days_in_month(current_date)

        "quarter" ->
          quarter = Date.quarter_of_year(current_date)

          start_date = Date.new!(current_date.year, quarter * 3 - 2, 1)
          end_date = Date.end_of_month(Date.new!(current_date.year, quarter * 3, 1))

          Date.diff(end_date, start_date) + 1

        "year" ->
          current_date
          |> Date.leap_year?()
          |> (&if(&1, do: 366, else: 365)).()
      end

    %{cycle_total_duration_in_days: total_duration, cycle_remaining_days: remaining_days}
  end
end

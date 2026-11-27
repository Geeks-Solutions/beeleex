defmodule BeeleexWeb.BeeleeComponentsTest do
  use ExUnit.Case, async: true

  import BeeleexWeb.BeeleeComponents, only: [format_amount: 2, format_money: 3]

  test "formats integer and BigInteger string minor units without losing precision" do
    for {amount, scale, expected} <- [
          {123, 0, "123"},
          {"123", 0, "123"},
          {1, 2, "0.01"},
          {"1050", 2, "10.50"},
          {1, 3, "0.001"},
          {"123456", 3, "123.456"},
          {0, 0, "0"},
          {"0", 2, "0.00"},
          {-1, 3, "-0.001"},
          {"-1050", 2, "-10.50"},
          {9_223_372_036_854_775_807, 2, "92233720368547758.07"},
          {"9223372036854775807", 3, "9223372036854775.807"},
          {"-9223372036854775808", 2, "-92233720368547758.08"}
        ] do
      assert format_amount(amount, scale) == expected
    end
  end

  test "unknown or invalid amounts and scales never become fabricated money" do
    for {amount, scale} <- [
          {nil, 2},
          {100, nil},
          {"100", nil},
          {100, -1},
          {"", 2},
          {"1.5", 2},
          {"1e3", 2},
          {1.0, 2}
        ] do
      assert format_amount(amount, scale) == "—"
    end
  end

  test "labels currencies without inferring the scale or defaulting to EUR" do
    assert format_money("1200", 0, "JPY") == "1200 JPY"
    assert format_money("1200", 2, "USD") == "12.00 USD"
    assert format_money("1200", 3, "KWD") == "1.200 KWD"
    assert format_money(-1200, 2, "EUR") == "-12.00 EUR"
    assert format_money(nil, 2, "GBP") == "— GBP"
    assert format_money(0, nil, "USD") == "— USD"
    assert format_money(100, 2, nil) == "1.00 currency unknown"
  end
end

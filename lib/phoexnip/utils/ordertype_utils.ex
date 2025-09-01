defmodule Phoexnip.OrderTypeUtils do
  @moduledoc """
  Helpers for building and interpreting “order type” dropdown options.

  This module provides:

    * `getOrderTypeOneForDropdown/2` – a list of primary order‐type tuples (`{"CM", 0}`, `{"FOB", 1}`),
      with optional empty and “ALL” entries.
    * `getOrderTypeOneBasedOnInteger/1` – find the label for a given primary order‐type code.
    * `getOrderTypeTwoForDropdown/3` – a combined list of sample and bulk order‐type tuples,
      with options to include only sample, only bulk, and an empty entry.
    * `getOrderTypeTwoForDropdownSalesOrder/3` – a sales‐order–focused subset of
      sample and bulk tuples, with similar filtering options.
    * `getOrderTypeTwoBasedOnInteger/1` – lookup the label for a given secondary order‐type code.
    * `getOrderTypeTwoBasedOnIntegerSalesOrder/1` – lookup the label using the sales‐order list.

  ## Options

    * `add_empty`   – when `true`, prepends an empty `{"", -1}` entry.
    * `allow_all`   – primary only: when `true`, inserts `{"ALL", 2}`.
    * `only_sample` – secondary: when `true`, returns only sample items.
    * `only_bulk`   – secondary: when `true`, returns only bulk items.

  These utilities simplify building dropdowns in forms and translating stored integer codes
  back into human‐readable labels.
  """

  @doc """
  Returns a list of order-type options for use in a dropdown menu.

  ## Parameters

    * `add_empty` — when `true`, includes an empty option `{ "", -1 }` at the top.
    * `allow_all` — when `true`, includes an `"ALL"` option `{ "ALL", 2 }` after the empty option.

  ## Returns

    * A list of `{label, value}` tuples (`String.t()` and `integer()`) in the order:
      1. Optional empty entry
      2. Optional “ALL” entry
      3. `"CM"` (value `0`)
      4. `"FOB"` (value `1`)
  """
  @spec getOrderTypeOneForDropdown(add_empty :: boolean(), allow_all :: boolean()) :: [
          {String.t(), integer()}
        ]
  def getOrderTypeOneForDropdown(add_empty \\ false, allow_all \\ true) do
    [
      if(add_empty, do: {"", -1}, else: nil),
      if(allow_all, do: {"ALL", 2}, else: nil),
      {"CM", 0},
      {"FOB", 1}
    ]
    |> Enum.filter(& &1)
  end

  @doc """
  Looks up the label for a given order type integer from the built-in dropdown options.

  ## Parameters

    * `order_type` — an integer representing the order type (e.g. `-1`, `0`, `1`, `2`).

  ## Behavior

    1. Calls `getOrderTypeOneForDropdown/2` with its defaults to get the list of `{label, value}` tuples.
    2. Finds the tuple whose `value` matches `order_type`.
    3. Returns the corresponding `label`, or an empty string if no match is found.

  ## Returns

    * A `String.t()` label matching the given `order_type`, or `""` if not found.
  """
  def getOrderTypeOneBasedOnInteger(order_type) do
    Enum.find(getOrderTypeOneForDropdown(), fn {_, value} -> value == order_type end)
    |> case do
      {key, _} -> key
      # Handle case where number isn't found
      nil -> ""
    end
  end

  @doc """
  Returns a list of “order type two” options for use in a dropdown menu.

  ## Parameters

    * `add_empty` — when `true`, prepends an empty entry `{"", -1}`.
    * `only_sample` — when `true` (and `only_bulk` is `false`), returns only the sample items.
    * `only_bulk` — when `true` (and `only_sample` is `false`), returns only the bulk items.

  If neither `only_sample` nor `only_bulk` is `true`, returns both sample and bulk items.

  ## Returns

    * A list of `{label, value}` tuples (`String.t(), integer()`) in the order:
      1. Optional empty entry
      2. Sample items: `{"Proto", 0}`, `{"GGP", 1}`, `{"SPA", 2}`
      3. Bulk items: `{"Size set", 8}`, `{"Bulk", 16}`, `{"QRS", 32}`, `{"QPP", 64}`, `{"Wash Test", 128}`, `{"CH Wash Test", 256}`, `{"HT Test", 1024}`, `{"GPA Promo", 2048}`, `{"GFA Promo", 4096}`
  """
  @spec getOrderTypeTwoForDropdown(
          add_empty :: boolean(),
          only_sample :: boolean(),
          only_bulk :: boolean()
        ) :: [{String.t(), integer()}]
  def getOrderTypeTwoForDropdown(add_empty \\ false, only_sample \\ false, only_bulk \\ false) do
    sample_items = [
      {"Proto", 0},
      {"GGP", 1},
      {"SPA", 2}
    ]

    bulk_items = [
      {"Size set", 8},
      {"Bulk", 16},
      {"QRS", 32},
      {"QPP", 64},
      {"Wash Test", 128},
      {"CH Wash Test", 256},
      {"HT Test", 1024},
      {"GPA Promo", 2048},
      {"GFA Promo", 4096}
    ]

    items =
      cond do
        only_sample and not only_bulk -> sample_items
        only_bulk and not only_sample -> bulk_items
        true -> sample_items ++ bulk_items
      end

    if add_empty, do: [{"", -1} | items], else: items
  end

  @doc """
  Returns a list of “order type two” options tailored for sales orders, suitable for a dropdown.

  ## Parameters

    * `add_empty` — when `true`, prepends an empty entry `{"", -1}`.
    * `only_sample` — when `true` (and `only_bulk` is `false`), returns only the sample items.
    * `only_bulk` — when `true` (and `only_sample` is `false`), returns only the bulk items.

  If neither `only_sample` nor `only_bulk` is `true`, defaults to the bulk items only.

  ## Returns

    * A list of `{label, value}` tuples (`String.t(), integer()`) in the order:
      1. Optional empty entry
      2. Sample items: `{"Proto", 0}`, `{"GGP", 1}`, `{"SPA", 2}`
      3. Bulk items: `{"Bulk", 16}`, `{"Short Lead Time", 32}`, `{"Promo", 64}`, `{"Samples", 128}`, `{"Overrun", 256}`, `{"B Grade", 512}`, `{"GBI TOP", 1024}`
  """
  @spec getOrderTypeTwoForDropdownSalesOrder(
          add_empty :: boolean(),
          only_sample :: boolean(),
          only_bulk :: boolean()
        ) :: [{String.t(), integer()}]
  def getOrderTypeTwoForDropdownSalesOrder(
        add_empty \\ false,
        only_sample \\ false,
        only_bulk \\ false
      ) do
    sample_items = [
      {"Proto", 0},
      {"GGP", 1},
      {"SPA", 2}
    ]

    bulk_items = [
      {"Bulk", 16},
      {"Short Lead Time", 32},
      {"Promo", 64},
      {"Samples", 128},
      {"Overrun", 256},
      {"B Grade", 512},
      {"GBI TOP", 1024}
    ]

    items =
      cond do
        only_sample and not only_bulk -> sample_items
        only_bulk and not only_sample -> bulk_items
        true -> bulk_items
      end

    if add_empty, do: [{"", -1} | items], else: items
  end

  @doc """
  Finds the label for a given “order type two” integer code using the default dropdown options.

  ## Parameters

    * `order_type` — an integer code corresponding to one of the values returned by
      `getOrderTypeTwoForDropdown/3` with its defaults (`add_empty: false, only_sample: false, only_bulk: false`).

  ## Behavior

    1. Calls `getOrderTypeTwoForDropdown()` to retrieve the combined list of sample and bulk items.
    2. Searches for the tuple `{label, value}` where `value == order_type`.
    3. Returns the matching `label` string, or `""` if no match is found.

  ## Returns

    * A `String.t()` label for the provided `order_type`, or `""` when not found.
  """
  @spec getOrderTypeTwoBasedOnInteger(order_type :: integer()) :: String.t()
  def getOrderTypeTwoBasedOnInteger(order_type) do
    Enum.find(getOrderTypeTwoForDropdown(), fn {_, value} -> value == order_type end)
    |> case do
      {key, _} -> key
      # Handle case where number isn't found
      nil -> ""
    end
  end

  @doc """
  Finds the label for a given “order type two” integer code using the sales-order dropdown options.

  ## Parameters

    * `order_type` — an integer code corresponding to one of the values returned by
      `getOrderTypeTwoForDropdownSalesOrder/3` with its defaults (`add_empty: false, only_sample: false, only_bulk: false`).

  ## Behavior

    1. Calls `getOrderTypeTwoForDropdownSalesOrder()` to retrieve the list of sample and bulk items for sales orders.
    2. Searches for the tuple `{label, value}` where `value == order_type`.
    3. Returns the matching `label`, or `""` if no match is found.

  ## Returns

    * A `String.t()` label matching the given `order_type`, or `""` when not found.
  """
  @spec getOrderTypeTwoBasedOnIntegerSalesOrder(order_type :: integer()) :: String.t()
  def getOrderTypeTwoBasedOnIntegerSalesOrder(order_type) do
    Enum.find(getOrderTypeTwoForDropdownSalesOrder(), fn {_, value} -> value == order_type end)
    |> case do
      {key, _} -> key
      # Handle case where number isn't found
      nil -> ""
    end
  end
end

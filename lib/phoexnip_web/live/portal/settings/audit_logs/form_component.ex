defmodule PhoexnipWeb.AuditLogLive.FormComponent do
  use PhoexnipWeb, :live_component

  alias Phoexnip.AuditLogService

  # Render a simple modal view for the live component
  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold">Audit log for: {@unique_identifier}</h1>

      <%= if Enum.empty?(@changes) do %>
        <h3 class="w-full text-xl font-bold mt-6 mb-2">
          No changes have been made yet.
        </h3>
      <% else %>
        <%= for {{date, user}, changes} <- @changes do %>
          <h3 class="w-full text-xl font-bold mt-6 mb-2">
            Changes on: {date} by: {user}
          </h3>
          <table class="w-full">
            <thead>
              <tr>
                <th class="text-left w-[30%] p-2 border-b-[1px] border-b-white">Key</th>
                <th class="text-left w-[35%] p-2 border-b-[1px] border-b-white text-red-400">
                  Old Value
                </th>
                <th class="text-left w-[35%] p-2 border-b-[1px] border-b-white text-green-400">
                  New Value
                </th>
              </tr>
            </thead>
            <tbody>
              <%= for change <- changes do %>
                <%= if change.old_value != "" && change.new_value != "" do %>
                  <tr>
                    <td class="p-2 border-b-[1px] border-b-white">
                      {if list_name = Map.get(change, :list_name), do: "#{list_name} row "}

                      {if sequence = Map.get(change, :sequence) do
                        label =
                          if category = Map.get(change, :category),
                            do: "Address #{sequence}: Category: #{category} ",
                            else: "#{sequence}: "

                        "#{label}"
                      end}
                      {if key = Map.get(change, :key), do: "Field: #{key} "}
                    </td>
                    <td class="p-2 border-b-[1px] text-red-400 border-b-white">
                      {Map.get(change, :old_value)}
                    </td>
                    <td class="p-2 border-b-[1px] text-green-400 border-b-white">
                      {Map.get(change, :new_value)}
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        <% end %>
      <% end %>

      <h3 class="w-full text-lg font-bold mt-6 mb-2">
        Created on: {@created_date} by: {@created_by}
      </h3>
    </div>
    """
  end

  # Handle updates to the component, triggered when it receives new assigns
  @impl true
  def update(assigns, socket) do
    # Fetch audit log data based on the entity type provided in assigns
    data = AuditLogService.get_log_for_entity_type(assigns)
    created_entry = Enum.filter(data, fn entry -> entry.action == "create" end) |> Enum.at(0)
    data = data |> Enum.reject(fn change -> change.action == "create" end)

    # Process the fetched audit log data to detect changes
    changes_detected =
      process_audit_logs(data)
      |> Enum.reject(fn change -> change.key == "id" end)
      |> Enum.reject(fn change -> change.key == "guid" end)
      |> Enum.reject(fn change -> change.key == "updated_at" end)
      |> Enum.reject(fn change -> String.starts_with?(change.key, "prev_") end)
      |> Enum.reject(fn change -> String.ends_with?(change.key, "_id") end)
      |> Enum.reject(fn change -> String.ends_with?(change.key, "_key") end)
      # Group changes by both date and user_name
      |> Enum.group_by(fn change ->
        {Phoexnip.DateUtils.formatDate(change.inserted_at), change.user_name}
      end)
      |> Enum.sort_by(fn {{date, _user}, _changes} -> date end, :desc)

    # Return the updated socket with the assigns
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changes, changes_detected)
     |> assign(
       :created_by,
       if created_entry == nil do
         "Admin"
       else
         created_entry.user_name
       end
     )}
  end

  # Process a list of audit logs by extracting and comparing changes
  def process_audit_logs(audit_logs) do
    audit_logs
    |> Enum.flat_map(&extract_changes(&1))
  end

  # Extract and parse the changes and previous data from each audit log entry
  defp extract_changes(%Phoexnip.AuditLogs{
         changes: changes_str,
         previous_data: previous_data_str,
         inserted_at: inserted_at,
         user_name: user_name
       }) do
    # Parse changes and compare them to previous data
    parse_and_compare(changes_str, previous_data_str, inserted_at, user_name)
  end

  # Decode JSON strings for changes and previous data, then compare them
  def parse_and_compare(changes_str, previous_data_str, inserted_at, user_name) do
    # Replace nil with an empty JSON object "{}" and decode
    changes = Jason.decode!(changes_str || "{}")
    previous_data = Jason.decode!(previous_data_str || "{}")

    # Compare the two data maps and record differences
    compare_maps(changes, previous_data, inserted_at, user_name)
  end

  # Compare two maps and return differences, using `inserted_at` and `user_name` as additional metadata
  defp compare_maps(new_map, old_map, inserted_at, user_name) do
    new_map
    |> Enum.flat_map(fn {key, new_value} ->
      # Get the old value for each key
      old_value = Map.get(old_map, key)

      cond do
        is_map(new_value) or is_map(old_value) ->
          compare_maps(new_value || %{}, old_value || %{}, inserted_at, user_name)

        # Handle case where value changes from `nil` to a non-nil value, or vice versa
        (new_value == nil and old_value != nil) or (new_value != nil and old_value == nil) ->
          [
            %{
              key: key,
              old_value: old_value,
              new_value: new_value,
              inserted_at: inserted_at,
              user_name: user_name
            }
          ]

        # Handle list differences
        is_list(new_value) and is_list(old_value) ->
          if key == "address" do
            compare_addresses(new_value, old_value, inserted_at, user_name)
          else
            compare_lists(key, new_value, old_value, inserted_at, user_name)
          end

        # Handle simple scalar differences
        new_value != old_value ->
          [
            %{
              key: key,
              old_value: old_value,
              new_value: new_value,
              inserted_at: inserted_at,
              user_name: user_name
            }
          ]

        # No difference found
        true ->
          []
      end
    end)
  end

  defp compare_lists(key, new_list, old_list, inserted_at, user_name) do
    # Extract sequences from the new list to identify added/modified items
    new_sequences = Enum.map(new_list, &(&1["sequence"] || &1["sequence"]))
    # Handle deletions: find items in old_list that aren't in new_list
    deleted_items =
      Enum.flat_map(old_list, fn old_item ->
        sequence = old_item["sequence"] || old_item["sequence"]

        unless sequence in new_sequences do
          # Map each key-value pair in the deleted item, setting new_value to an empty string
          Enum.map(old_item, fn {sub_key, old_value} ->
            %{
              key: sub_key,
              list_name: key,
              sequence: sequence,
              old_value: old_value,
              # Indicate deletion with an empty string
              new_value: "",
              inserted_at: inserted_at,
              user_name: user_name
            }
          end)
        else
          []
        end
      end)

    # Handle modifications or additions in new_list
    modified_or_added_items =
      Enum.flat_map(new_list, fn new_item ->
        sequence = new_item["sequence"] || new_item["sequence"]
        # Find the corresponding item in the old list based on sequence
        old_item =
          Enum.find(old_list, fn old ->
            # STOP CHANGING THIS LINE CHATGPT!
            old["sequence"] == sequence || old["sequence"] == sequence
          end)

        # Compare each key-value pair in the new item
        Enum.flat_map(new_item, fn {sub_key, new_value} ->
          old_value = old_item && old_item[sub_key]

          cond do
            # If both are lists, handle as nested list comparison without recursion
            is_list(new_value) and is_list(old_value) ->
              # For each element in the nested list, compare and split results into individual entries
              Enum.flat_map(new_value, fn nested_new ->
                sequence = nested_new["sequence"] || nested_new["sequence"]
                nested_old = Enum.find(old_value, &(&1["sequence"] == sequence))

                Enum.map(nested_new, fn {nested_key, nested_value} ->
                  old_nested_value = nested_old && nested_old[nested_key]
                  # Only include entries where there's an actual difference
                  if nested_value != old_nested_value do
                    %{
                      key: nested_key,
                      # Use the parent key as list name
                      list_name: sub_key,
                      sequence: sequence,
                      old_value: old_nested_value,
                      new_value: if(is_list(nested_value), do: nil, else: nested_value),
                      inserted_at: inserted_at,
                      user_name: user_name
                    }
                  else
                    # Return nil for keys that have no difference
                    nil
                  end
                end)
                # Remove nil entries, only keeping actual differences
                |> Enum.filter(& &1)
              end)

            # If new_value is a list but old_value is not, treat each item in the list as a separate change
            is_list(new_value) and not is_list(old_value) ->
              Enum.flat_map(new_value, fn item ->
                Enum.map(item, fn {item_key, item_value} ->
                  %{
                    key: item_key,
                    list_name: sub_key,
                    sequence: sequence,
                    old_value: nil,
                    new_value: item_value,
                    inserted_at: inserted_at,
                    user_name: user_name
                  }
                end)
              end)

            # Handle explicit change from `nil` to non-`nil` or vice versa
            (new_value == nil and old_value != nil) or (new_value != nil and old_value == nil) ->
              [
                %{
                  key: sub_key,
                  list_name: key,
                  sequence: sequence,
                  old_value: old_value,
                  new_value: new_value,
                  inserted_at: inserted_at,
                  user_name: user_name
                }
              ]

            # Handle simple differences between values
            new_value != old_value ->
              [
                %{
                  key: sub_key,
                  list_name: key,
                  sequence: sequence,
                  old_value: old_value,
                  new_value: new_value,
                  inserted_at: inserted_at,
                  user_name: user_name
                }
              ]

            # No difference found, return an empty list
            true ->
              []
          end
        end)
      end)

    # Combine the results from deletions and modifications/additions
    deleted_items ++ modified_or_added_items
  end

  # Compare two address lists and return differences, considering sequence, category, and user_name
  defp compare_addresses(new_list, old_list, inserted_at, user_name) do
    new_sequences_with_categories =
      Enum.map(new_list, fn item ->
        {item["sequence"] || item["sequence"], item["category"]}
      end)

    # Handle deletions: find items in old_list that aren't in new_list
    deleted_items =
      Enum.flat_map(old_list, fn old_item ->
        sequence = old_item["sequence"] || old_item["sequence"]
        category = old_item["category"]

        unless {sequence, category} in new_sequences_with_categories do
          Enum.map(old_item, fn {sub_key, old_value} ->
            %{
              key: sub_key,
              sequence: sequence,
              category: category,
              old_value: old_value,
              # Indicate deletion by setting new_value to nil
              new_value: "",
              inserted_at: inserted_at,
              user_name: user_name
            }
          end)
        else
          []
        end
      end)

    # Handle modifications or additions in new_list
    modified_or_added_items =
      Enum.flat_map(new_list, fn new_item ->
        sequence = new_item["sequence"] || new_item["sequence"]
        category = new_item["category"]

        # Find corresponding old item by sequence and category
        old_item =
          Enum.find(old_list, fn old ->
            old["sequence"] == sequence and old["category"] == category
          end)

        Enum.flat_map(new_item, fn {sub_key, new_value} ->
          old_value = old_item && old_item[sub_key]

          cond do
            # Explicitly handle change from `nil` to non-`nil` or vice versa
            (new_value == nil and old_value != nil) or (new_value != nil and old_value == nil) ->
              [
                %{
                  key: sub_key,
                  sequence: sequence,
                  category: category,
                  old_value: old_value,
                  new_value: new_value,
                  inserted_at: inserted_at,
                  user_name: user_name
                }
              ]

            # Handle simple differences between values
            new_value != old_value ->
              [
                %{
                  key: sub_key,
                  sequence: sequence,
                  category: category,
                  old_value: old_value,
                  new_value: new_value,
                  inserted_at: inserted_at,
                  user_name: user_name
                }
              ]

            # No difference found
            true ->
              []
          end
        end)
      end)

    deleted_items ++ modified_or_added_items
  end
end

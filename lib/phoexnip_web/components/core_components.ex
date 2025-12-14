defmodule PhoexnipWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as modals, tables, and
  forms. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  use Gettext, backend: PhoexnipWeb.Gettext

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true
  attr :class, :string, default: nil
  attr :flash, :map, doc: "the map of flash messages"

  def modal(assigns) do
    assigns =
      assigns
      |> Map.put_new(:class, "")
      |> Map.put_new(:flash, %{})

    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 transition-opacity bg-overlay opacity-30"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <.flash_group flash={@flash} />

        <div class="flex h-full w-full items-center justify-center">
          <div class="w-full h-full flex items-center justify-center p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class={[
                "relative hidden rounded-2xl p-14 shadow-lg ring-1 ring-themePrimary transition bg-page",
                @class
              ]}
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 hover:opacity-40"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"} class="h-full w-full">
                <%!-- Invisible input to capture the focus when the modal is opened --%>
                <.input
                  type="text"
                  class="absolute opacity-0 pointer-events-none"
                  name="hidden"
                  value="hidden"
                />
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def audit_modal(assigns) do
    assigns =
      assigns
      |> Map.put_new(:class, "w-full")
      |> Map.put_new(:flash, %{})

    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 transition-opacity bg-overlay opacity-30"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <.flash_group flash={@flash} />

        <div class="flex justify-center w-full mt-14">
          <div class={"max-w-[83%] p-4 sm:p-6 lg:py-8 " <> @class}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="relative hidden rounded-2xl p-14 shadow-lg ring-1 ring-themePrimary transition bg-page"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 hover:opacity-40"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @spec modal_unclosable(map()) :: Phoenix.LiveView.Rendered.t()
  @doc """
  Renders an unclosable modal dialog, closed only via the provided close button.

  ## Examples

      <.modal_unclosable id="unclosable-modal">Content</.modal_unclosable>
  """
  def modal_unclosable(assigns) do
    assigns =
      assigns
      |> assign_new(:bottom_close, fn -> false end)
      |> Map.put_new(:onclose, "close-modal")
      |> Map.put_new(:class, "w-full")
      |> Map.put_new(:flash, %{})

    ~H"""
    <div
      id={@id}
      class={"relative z-50 #{if @show, do: "", else: "hidden"}"}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
    >
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 transition-opacity bg-overlay opacity-30"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <.flash_group flash={@flash} />

        <div class="flex min-h-full items-center justify-center">
          <div class={"max-w-8xl p-4 sm:p-6 lg:py-8 " <> @class}>
            <.focus_wrap
              id={"#{@id}-container"}
              class="relative rounded-2xl p-14 shadow-lg ring-1 ring-themePrimary transition bg-page"
            >
              <!-- Modal close button (X) -->
              <div class="absolute top-6 right-5">
                <button
                  phx-click={@onclose}
                  type="button"
                  class="-m-3 flex-none p-3 hover:opacity-40"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>

              <div id={"#{@id}-content"}>
                {render_slot(@inner_block)}
              </div>

              <%= if @bottom_close do %>
                <div class="mt-6 right-5 flex justify-end">
                  <.link
                    phx-click={@onclose}
                    class="phx-submit-loading:opacity-75 flex align-center rounded-lg py-2 px-3 font-semibold leading-6 border border-border hover:bg-themePrimary focus:bg-themePrimary"
                  >
                    <.icon name="hero-x-mark-solid" class="w-6 h-6 me-1" /> Close
                  </.link>
                </div>
              <% end %>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders dynamic flash notifications with optional icons, titles, and auto-dismiss.

  ## Examples

      <.flash kind={:info} flash={@flash} />
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :kind, :atom, required: true, doc: "used for styling and flash lookup"
  attr :title, :string, default: nil, doc: "the title of the notification"
  attr :icon, :string, default: nil, doc: "the heroicon name to display in the title"
  attr :duration, :integer, default: nil, doc: "milliseconds until the flash auto-dismisses"
  attr :show_spinner, :boolean, default: false, doc: "whether to show a loading spinner"
  attr :rest, :global, doc: "arbitrary HTML attributes"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    flash_content = Phoenix.Flash.get(assigns.flash, assigns.kind)

    assigns =
      assigns
      |> assign(:flash_content, flash_content)
      |> (fn a ->
            if is_map(flash_content) do
              kind = a.kind

              # Default icon based on kind
              default_icon =
                case kind do
                  :info -> "hero-information-circle-mini"
                  :error -> "hero-exclamation-circle-mini"
                  :warning -> "hero-exclamation-triangle-mini"
                  _ -> nil
                end

              assign(a, %{
                title: Map.get(flash_content, :title, a.title),
                # Msg is usually required from the map
                msg: Map.get(flash_content, :msg),
                icon: Map.get(flash_content, :icon, a.icon || default_icon),
                duration: Map.get(flash_content, :duration, a.duration),
                show_spinner: Map.get(flash_content, :show_spinner, a.show_spinner)
              })
            else
              # Legacy flash, e.g., put_flash(:info, "Ok")
              kind = a.kind

              icon =
                case a.icon do
                  nil ->
                    case kind do
                      :info -> "hero-information-circle-mini"
                      :error -> "hero-exclamation-circle-mini"
                      :warning -> "hero-exclamation-triangle-mini"
                      _ -> nil
                    end

                  value ->
                    value
                end

              assign(a, icon: icon)
            end
          end).()
      |> assign_new(:id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={
        msg =
          render_slot(@inner_block) ||
            (is_map(@flash_content) && @flash_content.msg) ||
            @flash_content
      }
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      phx-hook={if @duration, do: "FlashAutoDismiss"}
      data-duration={@duration}
      role="alert"
      class={[
        "flash fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1 shadow-lg",
        @kind == :info && "bg-infoBg text-infoFg ring-infoBorder",
        @kind == :error && "bg-errorBg text-errorFg ring-errorBorder",
        @kind == :warning && "bg-warnBg text-warnFg ring-warnBorder",
        @kind not in [:warning, :error, :info] && "bg-infoBg text-infoFg ring-infoBorder"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 font-semibold leading-6">
        <.icon :if={@icon} name={@icon} class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-2 leading-5" phx-no-format>
        <span class="whitespace-break-spaces break-words">{msg}</span><.icon
          :if={@show_spinner}
          name="hero-arrow-path"
          class="ml-1 h-3 w-3 animate-spin"
        />
      </p>
    </div>
    """
  end

  @doc """
  Renders a group of flash notifications for standard feedback.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  def flash_group(assigns) do
    ~H"""
    <div id="flash-group" phx-no-format>
      <%!-- Legacy Flash Presets --%>
      <.flash kind={:info} flash={@flash} title="Success!" duration={5000} />
      <.flash kind={:error} flash={@flash} title="Error!" duration={8000} />
      <.flash kind={:warning} flash={@flash} title="Warning" duration={8000} />
      <%!-- System Flash Presets --%>
      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        show_spinner
        phx-disconnected={show("#client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >Attempting to reconnect</.flash>
      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        show_spinner
        phx-error={show("#server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >Hang in there while we get back on track</.flash>
    </div>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the data structure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"
  attr :current_user_admin, :any, default: false
  attr :class, :string, default: ""
  attr :image_url, :string, required: false
  attr :user_id, :string, default: ""

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"
  slot :top_actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} autocomplete="off" {@rest}>
      <div class={@class}>
        <div :for={top_actions <- @top_actions} class="mt-2 flex items-center justify-end gap-2">
          {render_slot(top_actions, f)}
        </div>
        {render_slot(@inner_block, f)}
        <div :for={action <- @actions} class="mt-2 flex items-center justify-end gap-2">
          {render_slot(action, f)}
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  A radio button component bound to a form field, with error messages.

  ## Attributes:
    * `:form` - The form object (from `Phoenix.HTML.Form`).
    * `:field` - The specific field to bind to (e.g., `:role`).
    * `:options` - A list of `{label, value}` tuples for the radio buttons.
    * `:disabled` - Whether the group should be disabled.

  ## Example Usage:
      <.form for={@changeset} phx-change="validate">
        <.radio_buttons form={f} field={:role} options={[{"Admin", "admin"}, {"Editor", "editor"}]} />
      </.form>
  """
  attr :form, :map, required: true
  attr :field, :atom, required: true
  attr :options, :list, required: true
  attr :disabled, :boolean, default: false

  def radio_buttons(assigns) do
    # Assign errors dynamically from the form if not explicitly provided
    assigns =
      assigns
      |> assign_new(:errors, fn ->
        case assigns.form.errors[assigns.field] do
          {msg, _opts} -> [msg]
          nil -> []
        end
      end)

    ~H"""
    <fieldset class="radio-group" phx-feedback-for={Phoenix.HTML.Form.input_name(@form, @field)}>
      <%= for {label, value} <- @options do %>
        <div class="radio-button-container">
          <input
            type="radio"
            id={"#{@form.id}_#{@field}_#{value}"}
            name={Phoenix.HTML.Form.input_name(@form, @field)}
            value={value}
            checked={Phoenix.HTML.Form.input_value(@form, @field) == value}
            class="radio-button-input"
            disabled={@disabled}
          />
          <label for={"#{@form.id}_#{@field}_#{value}"}>{label}</label>
        </div>
      <% end %>
    </fieldset>

    <.error :for={msg <- @errors}>{msg}</.error>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 rounded-lg py-2 px-2 min-h-[2.75rem] min-w-[2.75rem] font-semibold leading-6 border border-borderStrong hover:bg-themePrimary focus:bg-themePrimary",
        @class
      ]}
      {@rest}
    >
      <span class="flex items-center justify-center">
        &#8203; {render_slot(@inner_block)}
      </span>
    </button>
    """
  end

  @doc """
  Renders an input field with label and error handling.

  Supports various types: text, select, checkbox, textarea, number, radio, etc.

  ## Examples

      <.input field={@form[:email]} type="email" />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :icon, :string, default: nil
  attr :value, :any
  attr :class, :string, default: ""

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
                range search select tel text textarea time url week radio-wrap radio-inline)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :parent, :string, default: ""
  attr :disabled, :string, default: nil

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                 multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div phx-feedback-for={@name} class={@class}>
      <label class={
        [
          "mt-2 min-h-[2.75rem] w-full rounded-lg border-2 text-foreground flex items-center justify-between px-3",
          "phx-no-feedback:border-muted",
          if(@disabled,
            do: "bg-disabledSurface cursor-not-allowed",
            else: "bg-surface hover:border-themePrimary"
          ),
          @errors != [] && "border-danger",
          @errors == [] && "border-muted"
        ]
      }>
        <input type="hidden" name={@name} value="false" />
        <span class="flex items-center gap-2">
          <.icon :if={@icon} name={@icon} class="h-5 w-5" />
          {@label}
        </span>
        <input
          type="checkbox"
          id={@id}
          name={@name}
          disabled={@disabled}
          value="true"
          checked={@checked}
          class={
            [
              "!appearance-none input-checkbox h-5 w-5 rounded border-2 !bg-surface hover:cursor-pointer focus:ring-0 focus:outline-none",
              # Hover states - only apply when NOT checked
              "hover:!bg-surface focus:!bg-surface",
              "focus:!border-2",
              # Checked states - override hover/focus
              "checked:!bg-success checked:!border-success checked:bg-center checked:bg-no-repeat checked:bg-[url('/images/check.svg')]",
              # Keep checked styles even when hovering/focusing
              "checked:hover:!bg-success checked:focus:!bg-success",
              "checked:hover:!border-success checked:focus:!border-success",
              @errors != [] &&
                "border-danger focus:!border-danger checked:hover:!border-success checked:focus:!border-success",
              @errors == [] &&
                ((@checked && "border-success focus:!border-success") ||
                   "border-muted focus:!border-muted")
            ]
          }
          {@rest}
        />
      </label>

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} class={@class}>
      <.label for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        disabled={@disabled}
        parent={@parent}
        class="mt-2 max-h-[2.75rem] w-full rounded-lg border-2 text-foreground bg-surface focus:border-themePrimary border-muted"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} class={@class}>
      <.label for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        disabled={@disabled}
        phx-hook="AutoResize"
        phx-debounce="blur"
        class={[
          "mt-2 min-h-[2.75rem] block w-full rounded-lg border-2 text-foreground bg-surface focus:ring-0 sm: sm:leading-6",
          "phx-no-feedback:border-muted phx-no-feedback:focus:border-themePrimary",
          @errors == [] && "border-muted focus:border-themePrimary",
          @errors != [] && "border-danger focus:border-danger"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Number
  def input(%{type: "number"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} class={@class}>
      <.label for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        disabled={@disabled}
        phx-debounce="blur"
        autocomplete="off"
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "text-right mt-2 max-h-[2.75rem] block w-full rounded-lg text-foreground bg-surface focus:ring-0 sm: sm:leading-6 border-2 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none",
          "phx-no-feedback:border-muted phx-no-feedback:focus:border-themePrimary ",
          @errors == [] && "border-muted focus:border-themePrimary",
          @errors != [] && "border-danger focus:border-danger"
        ]}
        {@rest}
      />

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "radio-wrap"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} class={@class}>
      <.label for={@id}>{@label}</.label>
      <div class="mt-2 flex flex-col space-y-2">
        <div :for={{option_label, option_value} <- @options} class="flex items-center gap-4">
          <input
            type="radio"
            id={"#{@id}_#{option_value}"}
            name={@name}
            value={option_value}
            checked={@value == option_value}
            disabled={@disabled}
            class="h-4 w-4 rounded-full border-border text-themePrimary accent-themePrimary focus:ring-0 hover:cursor-pointer disabled:text-muted"
            {@rest}
          />
          <label
            for={"#{@id}_#{option_value}"}
            class="block font-normal leading-6 text-foreground hover:cursor-pointer"
          >
            {option_label}
          </label>
        </div>
      </div>

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "radio-inline"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} class={@class}>
      <.label for={@id}>{@label}</.label>
      <div class="min-h-[2.75rem] ps-1 mt-2 flex flex-wrap items-center gap-x-6 gap-y-2">
        <div :for={{option_label, option_value} <- @options} class="flex items-center gap-4">
          <input
            type="radio"
            id={"#{@id}_#{option_value}"}
            name={@name}
            value={option_value}
            checked={@value == option_value}
            disabled={@disabled}
            class="h-4 w-4 rounded-full border-border text-themePrimary disabled:text-muted accent-themePrimary focus:ring-0 hover:cursor-pointer"
            {@rest}
          />
          <label
            for={"#{@id}_#{option_value}"}
            class="block font-normal leading-6 text-foreground hover:cursor-pointer"
          >
            {option_label}
          </label>
        </div>
      </div>

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name} class={@class}>
      <.label for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        disabled={@disabled}
        phx-debounce="blur"
        autocomplete="off"
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-2 min-w-[2.75rem] max-h-[2.75rem] block w-full rounded-lg text-foreground bg-surface focus:ring-0 sm: sm:leading-6 border-2",
          "phx-no-feedback:border-muted phx-no-feedback:focus:border-themePrimary",
          @errors == [] && "border-muted focus:border-themePrimary",
          @errors != [] && "border-danger focus:border-danger"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def live_select(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
      |> assign(:live_select_opts, assigns_to_attributes(assigns, [:errors, :label]))
      |> Map.put_new(:label, "")

    ~H"""
    <div phx-feedback-for={@field.name}>
      <%= if @label != "" do %>
        <.label for={@field.id}>{@label}</.label>
      <% end %>
      <LiveSelect.live_select
        field={@field}
        text_input_class={[
          "block w-full mt-2 rounded-lg py-[7px] px-[11px]",
          "text-foreground focus:outline-none focus:ring-0 sm:leading-6",
          "phx-no-feedback:border-border phx-no-feedback:focus:border-themePrimary",
          "border-border focus:border-themePrimary",
          @errors != [] && "border-danger focus:border-danger focus:ring-danger/10"
        ]}
        {@live_select_opts}
      />

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a label element.

  ## Examples

      <.label for="email">Email</.label>
  """
  attr :for, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class={@class} class="block font-semibold leading-6">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Displays a standard error message below an input.

  ## Examples

      <.error>Email is required</.error>
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 leading-6 text-danger phx-no-feedback:hidden">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header section with title, optional subtitle, and actions.

  ## Examples

      <.header>Dashboard</.header>
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", @class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8 ">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-2 leading-6 ">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a styled data table.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="Username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :table_length, :string,
    default: "w-full",
    doc: "the max length of your table in tailwind class for example min-w-[10rem]"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col do
    attr :label, :string
    attr :class, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-x-auto overflow-y-hidden px-4">
      <table id={@id} class={"w-full table-auto mt-11 " <> @table_length}>
        <thead class="text-left leading-6">
          <tr>
            <th :for={col <- @col} class={["p-0 pb-1 font-normal", Map.get(col, :class, "")]}>
              {Map.get(col, :label, "TELL THE DEVELOPER THEY FORGOT TO GIVE THIS A LABEL!")}
            </th>
            <th :if={@action != []} class="relative p-0 pb-1">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id <> "-tbody"}
          phx-update="replace"
          class="relative divide-y divide-border border-t border-border leading-6"
        >
          <%= for row <- @rows do %>
            <tr id={@row_id && @row_id.(row)} class="group">
              <td
                :for={{col, i} <- Enum.with_index(@col)}
                phx-click={@row_click && @row_click.(row)}
                class={["relative p-0", @row_click && "hover:cursor-pointer"]}
              >
                <div class="block py-1">
                  <span class="absolute -inset-y-px right-0 -left-4 sm:rounded-l-xl" />
                  <span class={["relative", i == 0]}>
                    {render_slot(col, @row_item.(row))}
                  </span>
                </div>
              </td>
              <td :if={@action != []} class="relative w-14 p-0">
                <div class="relative whitespace-nowrap py-4 text-right font-medium">
                  <span class="absolute -inset-y-px -right-4 left-0 sm:rounded-r-xl" />
                  <span :for={action <- @action} class="relative ml-1 leading-6">
                    {render_slot(action, @row_item.(row))}
                  </span>
                </div>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title"><%= @post.title %></:item>
        <:item title="Views"><%= @post.views %></:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="mt-14">
      <dl class="-my-4 divide-y divide-border">
        <div :for={item <- @item} class="flex gap-4 py-4 leading-6 sm:gap-8">
          <dt class="w-1/4 flex-none">{item.title}</dt>
          <dd class="">{render_slot(item)}</dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-16">
      <.link
        navigate={@navigate}
        class=" font-semibold leading-6 hover:underline hover:text-themePrimary focus:text-themePrimary focus:underline"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" />
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates Ecto changeset error messages using Gettext.

  ## Examples

      translate_error({"can't be blank", []})
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(PhoexnipWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(PhoexnipWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates errors from a keyword list for a given field.

  ## Examples

      translate_errors(changeset.errors, :email)
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end

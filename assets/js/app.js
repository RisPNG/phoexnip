// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import live_select from "live_select";
import topbar from "../vendor/topbar";
import "./flatpickr.min.js";
import { Chart } from "chart.js/auto";

let Hooks = {};

/*
Docs:
https://www.chartjs.org/docs/latest/samples/information.html

Usage:
@data will be on the socket or conn object and can be renamed as needed.
@options will be on the socket or conn object and can be renamed as needed.

DO NOT change the "data-data" or "data-options" or "data-type"

  <canvas
    id="<UNIQUE ID>"
    phx-hook="Chart"
    data-data={Jason.encode!(@data)}
    data-options={Jason.encode!(@options)}
    data-type="<YOUR CHART TYPE>"
    class="<CUSTOM CLASS>"
  >
  </canvas>

on the backend you assign it as follows based on your chart:

    chart_data = %{
      labels: ["A", "B", "C", "D", "E"],
      datasets: [
        %{
          label: "My Dataset",
          data: [1, 2, 3, 4, 5],
          backgroundColor: "rgba(75, 192, 192, 0.2)",
          borderColor: "rgba(75, 192, 192, 1)",
          borderWidth: 1
        }
      ]
    }

    chart_options = %{
      responsive: true,
      plugins: %{
        legend: %{
          display: true
        }
      }
    }

socket = socket |> assign(data: chart_data) |> assign(options: chart_options)
*/
Hooks.Chart = {
  data() {
    return JSON.parse(this.el.dataset.data);
  },
  options() {
    return JSON.parse(this.el.dataset.options);
  },
  type() {
    return this.el.dataset.type;
  },
  mounted() {
    this.renderChart();
  },
  updated() {
    if (this.chart) {
      this.chart.destroy(); // Destroy the existing chart
    }
    const noDataElement = this.el.closest("div").querySelector(".no-data");
    if (noDataElement) {
      noDataElement.classList.add("hidden");
      this.el.classList.remove("hidden");
    }
    this.renderChart(); // Recreate the chart
  },
  renderChart() {
    const chart_data = this.data();
    if (chart_data.labels.length <= 0) {
      //this.el is the canvas
      const noDataElement = this.el.closest("div").querySelector(".no-data");
      if (noDataElement) {
        noDataElement.classList.remove("hidden");
        noDataElement.classList.add("flex");
        this.el.classList.add("hidden");
      }
    } else {
      const ctx = this.el;
      const config = {
        type: this.type(),
        data: chart_data,
        options: this.options(),
      };

      // Create the chart
      this.chart = new Chart(ctx, config);
    }
  },
};

Hooks.DatePicker = {
  mounted() {
    const parent = this.el.parentElement; // Get the parent element
    if (
      parent.classList.contains("ban-future") &&
      parent.classList.contains("ban-past")
    ) {
      console.log("you are an idiot. - Cees");
      setupDatePicker(this.el, false, false);
    } else if (
      parent.classList.contains("ban-future") &&
      !parent.classList.contains("ban-past")
    ) {
      setupDatePicker(this.el, false);
    } else if (
      !parent.classList.contains("ban-future") &&
      parent.classList.contains("ban-past")
    ) {
      setupDatePicker(this.el, true, false);
    } else {
      setupDatePicker(this.el);
    }

    if (parent.classList.contains("start-date")) {
      dateBetween(this.el, "start");
    }
    if (parent.classList.contains("end-date")) {
      dateBetween(this.el, "end");
    }
  },
  updated() {
    const parent = this.el.parentElement; // Get the parent element
    if (
      parent.classList.contains("ban-future") &&
      parent.classList.contains("ban-past")
    ) {
      setupDatePicker(this.el, false, false);
    } else if (
      parent.classList.contains("ban-future") &&
      !parent.classList.contains("ban-past")
    ) {
      setupDatePicker(this.el, false);
    } else if (
      !parent.classList.contains("ban-future") &&
      parent.classList.contains("ban-past")
    ) {
      setupDatePicker(this.el, true, false);
    } else {
      setupDatePicker(this.el);
    }

    if (parent.classList.contains("start-date")) {
      dateBetween(this.el, "start");
    }
    if (parent.classList.contains("end-date")) {
      dateBetween(this.el, "end");
    }
  },
};

Hooks.DateTimePicker = {
  mounted() {
    const parent = this.el.parentElement; // Get the parent element
    if (
      parent.classList.contains("ban-future") &&
      parent.classList.contains("ban-past")
    ) {
      console.log("you are an idiot. - Cees");
      setupDatePicker(this.el, false, false, "d/m/Y H:i", "Y-m-d\\TH:i", true);
    } else if (
      parent.classList.contains("ban-future") &&
      !parent.classList.contains("ban-past")
    ) {
      setupDatePicker(this.el, false, true, "d/m/Y H:i", "Y-m-d\\TH:i", true);
    } else if (
      !parent.classList.contains("ban-future") &&
      parent.classList.contains("ban-past")
    ) {
      setupDatePicker(this.el, true, false, "d/m/Y H:i", "Y-m-d\\TH:i", true);
    } else {
      setupDatePicker(this.el, true, true, "d/m/Y H:i", "Y-m-d\\TH:i", true);
    }

    if (parent.classList.contains("start-date")) {
      dateBetween(this.el, "start", false);
    }
    if (parent.classList.contains("end-date")) {
      dateBetween(this.el, "end", false);
    }
  },
  updated() {
    const parent = this.el.parentElement; // Get the parent element
    if (
      parent.classList.contains("ban-future") &&
      parent.classList.contains("ban-past")
    ) {
      console.log("you are an idiot. - Cees");
      setupDatePicker(this.el, false, false, "d/m/Y H:i", "Y-m-d\\TH:i", true);
    } else if (
      parent.classList.contains("ban-future") &&
      !parent.classList.contains("ban-past")
    ) {
      setupDatePicker(this.el, false, true, "d/m/Y H:i", "Y-m-d\\TH:i", true);
    } else if (
      !parent.classList.contains("ban-future") &&
      parent.classList.contains("ban-past")
    ) {
      setupDatePicker(this.el, true, false, "d/m/Y H:i", "Y-m-d\\TH:i", true);
    } else {
      setupDatePicker(this.el, true, true, "d/m/Y H:i", "Y-m-d\\TH:i", true);
    }
    if (parent.classList.contains("start-date")) {
      dateBetween(this.el, "start", false);
    }
    if (parent.classList.contains("end-date")) {
      dateBetween(this.el, "end", false);
    }
  },
};

function setupDatePicker(
  element,
  can_be_in_the_future = true,
  can_be_in_the_past = true,
  altFormat = "d/m/Y",
  dateFormat = "Y-m-d",
  show_time = false
) {
  let minDate = null;
  let maxDate = null;
  if (!can_be_in_the_past) {
    minDate = "today"; // Disallow dates in the past
  }

  if (!can_be_in_the_future) {
    const now = new Date();
    maxDate = flatpickr.formatDate(now, "Y-m-d H:i");
  }

  flatpickr(element, {
    enableTime: show_time,
    altInput: true,
    altFormat: altFormat,
    dateFormat: dateFormat,
    minDate: minDate, // Apply minDate dynamically
    maxDate: maxDate, // Apply maxDate dynamically
    allowInput: true,
    onChange: () => {
      element.dispatchEvent(new Event("input", { bubbles: true }));
    },
    onClose: () => {
      element.dispatchEvent(new Event("blur", { bubbles: true }));
    },
    onReady: function (selectedDates, dateStr, instance) {
      const calendarContainer = instance.calendarContainer;

      if (calendarContainer) {
        const customButtonsContainer = document.createElement("div");
        customButtonsContainer.className = "flatpickr-custom-buttons";

        // Create Today button
        const todayButton = document.createElement("button");
        todayButton.type = "button";
        todayButton.className = "today-button";
        todayButton.textContent = "Today";
        todayButton.addEventListener("click", () => {
            const now = new Date();
            instance.setDate(
              flatpickr.formatDate(now, "Y-m-d H:i"), // format in local time
              true
            );
            instance.close();
        });

        // Create Clear button
        const clearButton = document.createElement("button");
        clearButton.type = "button";
        clearButton.className = "clear-button";
        clearButton.textContent = "Clear";
        clearButton.addEventListener("click", () => {
          instance.clear();
          instance.close();
        });

        customButtonsContainer.appendChild(todayButton);
        customButtonsContainer.appendChild(clearButton);
        calendarContainer.appendChild(customButtonsContainer);
      }
    },
  });

  // **Dispatch 'input' event on mount to trigger validation**
  element.dispatchEvent(new Event("input", { bubbles: true }));
}

function dateBetween(element, date_type, truncate_time = true) {
  let start_date = null;
  let end_date = null;

  if (date_type == "start") {
    start_date = new Date(element.value);
    end_date = new Date(
      element.parentElement.parentElement
        .querySelector(".end-date")
        .querySelector("input").value
    );
  }
  if (date_type == "end") {
    start_date = new Date(
      element.parentElement.parentElement
        .querySelector(".start-date")
        .querySelector("input").value
    );
    end_date = new Date(element.value);
  }
  if (isNaN(start_date)) {
    start_date = new Date(); // default it to today.
  }
  if (isNaN(end_date)) {
    end_date = new Date();
  }

  if (truncate_time) {
    // Normalize both dates to midnight
    start_date.setHours(0, 0, 0, 0);
    end_date.setHours(0, 0, 0, 0);
  }

  const diffInMilliseconds = end_date - start_date;
  const diffInDays = (diffInMilliseconds / (1000 * 60 * 60 * 24)).toFixed(1);

  //find the difference between the 2 dates and put it in ".date-between-result" input.
  element.parentElement.parentElement
    .querySelector(".date-between-result")
    .querySelector("input").value = diffInDays;
}

function simulateClick(element) {
  const event = new MouseEvent("click", {
    view: window,
    bubbles: true,
    cancelable: true,
  });
  element.dispatchEvent(event);
}

Hooks.FlashAutoDismiss = {
  timer: null,

  startTimer() {
    if (this.timer) {
      clearTimeout(this.timer);
    }

    const duration = this.el.dataset.duration;
    if (!duration) return;

    this.timer = setTimeout(() => {
      this.el.classList.add("animate-fade-out");

      this.el.addEventListener('animationend', () => {
        simulateClick(this.el);
      }, { once: true });

    }, duration);
  },

  mounted() {
    this.startTimer();
  },

  updated() {
    this.startTimer();
  },

  destroyed() {
    if (this.timer) {
      clearTimeout(this.timer);
    }
  }
};

Hooks.AutoResize = {
  mounted() {
    // Auto-resize logic if ignore autosize is false or undefined (to support previous logic.)
    if (
      this.el.dataset.resizetextarea == undefined ||
      (this.el.dataset.resizetextarea === "true") == true
    ) {
      this.resizeTextarea();
      this.el.addEventListener("input", () => this.resizeTextarea());
    }
    if (this.el.dataset.maxRows != undefined) {
      // Limit Max Row
      this.limitMaxRows();
    }
  },

  updated() {
    this.resizeTextarea();
  },

  resizeTextarea() {
    this.el.style.overflow = "hidden";
    this.el.style.height = "auto";
    this.el.style.height = `${this.el.scrollHeight}px`;
  },

  limitMaxRows() {
    const maxRows = this.el.dataset.maxRows;

    this.el.addEventListener("input", () => {
      // Get the line height
      const lineHeight = parseFloat(getComputedStyle(this.el).lineHeight);

      // Calculate rendered lines
      const linesUsed = Math.floor(this.el.scrollHeight / lineHeight);
      if (linesUsed > maxRows) {
        // Trim the last character (or revert to previous value) to enforce max rows
        this.el.value = this.el.value.slice(0, -1);
      }
    });
  },
};

Hooks.LiveSelectAbsolute = {
  mounted() {
    // find the nearest sticky ancestor (e.g. your 18% column)
    let found = this.el.closest('.sticky')
    this.wrapper = found || this.el.closest('.relative')

    // figure out CLOSE_Z:
    if (found) {
      this.CLOSE_Z = '10'
    } else {
      // fallback relative or self → use z-index = 1
      this.CLOSE_Z = '1'
    }

    if (found) {
      this.OPEN_Z = '9999'
    } else {
      // fallback relative or self → use z-index = 1
      this.OPEN_Z = '9'
    }


    this.handleScroll = this.handleScroll.bind(this)
    this.handleResize = this.handleResize.bind(this)

    this.liveSelectEl = this.el.querySelector('[phx-hook="LiveSelect"]')
    this.setupObserver()

    window.addEventListener("scroll", this.handleScroll, true)
    window.addEventListener("resize", this.handleResize, true)

    if (this.liveSelectEl) {
      const raise = () => {
        this.wrapper.style.zIndex = this.OPEN_Z
        setTimeout(() => this.repositionDropdown(), 256)
      }
      const lower = () => {
        console.log(this.CLOSE_Z)
        this.wrapper.style.zIndex = this.CLOSE_Z
      }

      this.liveSelectEl.addEventListener("focusin", raise)
      this.liveSelectEl.addEventListener("click",   raise)
      this.liveSelectEl.addEventListener("input",   raise)
      this.liveSelectEl.addEventListener("blur",    lower)
    }
        // Listen for clicks anywhere, to detect “outside” clicks
        this.onDocClick = this.onDocClick.bind(this)
        document.addEventListener("mousedown", this.onDocClick)
  },

  updated() {
    this.repositionDropdown()
  },

  destroyed() {
    document.removeEventListener("mousedown", this.onDocClick)
    window.removeEventListener("scroll", this.handleScroll, true)
    window.removeEventListener("resize", this.handleResize, true)
    if (this.observer) this.observer.disconnect()
  },
  onDocClick(ev) {
    // if the click target isn’t inside our LiveSelect wrapper…
    if (!this.el.contains(ev.target)) {

      let found = this.el.closest('.sticky')
      const wrapper = found || this.el.closest('.relative')

      // figure out CLOSE_Z:
      CLOSE_Z = '1'
      if (found) {
        CLOSE_Z = '10'
      } else {
        // fallback relative or self → use z-index = 1
        CLOSE_Z = '1'
      }

      // manually lower the z-index
      wrapper.style.zIndex = CLOSE_Z
    }
  },
  setupObserver() {
    this.observer = new MutationObserver(ms => {
      for (let m of ms) {
        for (let node of m.addedNodes) {
          if (node.tagName === 'UL' && node.classList.contains('absolute')) {
            this.repositionDropdown()
            return
          }
        }
      }
    })
    if (this.liveSelectEl) {
      this.observer.observe(this.liveSelectEl, { childList: true, subtree: true })
    }
  },

  handleScroll()   { this.repositionDropdown() },
  handleResize()   { this.repositionDropdown() },

  repositionDropdown() {
    const inputEl    = this.el.querySelector("input")
    const dropdownEl = this.getDropdownEl()
    if (!inputEl || !dropdownEl) return
    if (getComputedStyle(dropdownEl).display === 'none') return

    const r = inputEl.getBoundingClientRect()
    Object.assign(dropdownEl.style, {
      position: 'fixed',
      top:      `${r.bottom}px`,
      left:     `${r.left}px`,
      width:    `${r.width}px`
    })
    dropdownEl.classList.add("positioned-dropdown")
  },

  getDropdownEl() {
    if (this.liveSelectEl) {
      const d = this.liveSelectEl.querySelector("ul.absolute")
      if (d) return d
    }
    return document.querySelector(`ul[data-parent="${this.el.id}"]`)
  }
}


const userTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

// Initialize LiveSocket with hooks
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken, user_timezone: userTimeZone },
  hooks: { ...Hooks, ...live_select }, // Register hooks
});

const rootComputedStyle = getComputedStyle(document.documentElement);
const topbarColor =
  rootComputedStyle.getPropertyValue("--color-primary").trim() ||
  rootComputedStyle.getPropertyValue("--color-brand").trim() ||
  getComputedStyle(document.body).getPropertyValue("color");
const topbarShadow =
  rootComputedStyle.getPropertyValue("--color-shadow-strong").trim() ||
  rootComputedStyle.getPropertyValue("--color-overlay").trim();

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: topbarColor }, shadowColor: topbarShadow });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// Connect if there are any LiveViews on the page
liveSocket.connect();

// Expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// if the parent changes changes all the children to the same thing.
document.addEventListener("rootchanged", function (e) {
  ChangeChildren(e, e.target.getAttribute("id"));
});

// if the child changes, makes sure the parent has at least the same permissions.
document.addEventListener("childchanged", function (e) {
  let parentddl = document.getElementById(e.target.getAttribute("parent"));
  if (parentddl) {
    if (parseInt(e.target.value) > parseInt(parentddl.value)) {
      parentddl.value = e.target.value;
      if (parentddl.getAttribute("parent") != "") {
        parentddl.dispatchEvent(new Event("childchanged", { bubbles: true }));
      }
    }
  }
});

// change all the children based on the parent.
function ChangeChildren(e, parent) {
  let newValue = e.target.value;
  const childrenforsales = document.querySelectorAll(
    "[parent='" + parent + "']"
  );
  childrenforsales.forEach(function (el, index) {
    el.value = newValue;
    ChangeChildren(e, el.getAttribute("id"));
  });
}

// Listen for the LiveView event to trigger Excel download
window.addEventListener("phx:download_excel", (event) => {
  const excelData = event.detail.excel_data;
  const filename = event.detail.filename;

  // Decode base64 data and create a Blob
  const byteCharacters = atob(excelData);
  const byteNumbers = new Array(byteCharacters.length);
  for (let i = 0; i < byteCharacters.length; i++) {
    byteNumbers[i] = byteCharacters.charCodeAt(i);
  }
  const byteArray = new Uint8Array(byteNumbers);
  const blob = new Blob([byteArray], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });

  // Create a link and trigger download
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
});

window.addEventListener("phx:download_pdf", (event) => {
  const pdfData = event.detail.pdf_data;
  const filename = event.detail.filename;

  // Decode base64 data and create a Blob
  const byteCharacters = atob(pdfData);
  const byteNumbers = new Array(byteCharacters.length);
  for (let i = 0; i < byteCharacters.length; i++) {
    byteNumbers[i] = byteCharacters.charCodeAt(i);
  }
  const byteArray = new Uint8Array(byteNumbers);
  const blob = new Blob([byteArray], { type: "application/pdf" });

  // Create a link and trigger download
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
});

// Select all form elements whose IDs start with "upload"
window.addEventListener("phx:update", () => {
  document.querySelectorAll('form[id^="upload"]').forEach((form) => {
    window.addEventListener(`phx:${form.getAttribute("phx-change")}`, (event) => {
      form.querySelector('button[id^="submit-btn"]').click();
    });
  });
});

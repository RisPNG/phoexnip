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
// Alternatively, you can `bun install some-package --prefix assets` and import
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

let Hooks = {};

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
    maxDate = new Date();
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
          instance.setDate(new Date(), true);
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
    if (!this.el.id) {
      this.el.id = `lswrapper-${globalThis.crypto?.randomUUID?.() ?? Math.random().toString(36).slice(2)}`;
    }

    this.wrapper = this.el
    this.wrapper.style.position = 'relative'

    this.handleScroll = this.handleScroll.bind(this)
    this.handleResize = this.handleResize.bind(this)
    this.onDocClick = this.onDocClick.bind(this)
    this.maintainZIndex = this.maintainZIndex.bind(this)

    this.liveSelectEl = this.wrapper.querySelector('[phx-hook="LiveSelect"]')

    this.setupObserver()

    window.addEventListener("scroll", this.handleScroll, true)
    window.addEventListener("resize", this.handleResize, true)
    document.addEventListener("mousedown", this.onDocClick)

    this.zIndexInterval = setInterval(this.maintainZIndex, 100)

    if (this.liveSelectEl) {
      const raise = () => {
        this.ensureHighZIndex()
        setTimeout(() => this.repositionDropdown(), 256)
      }

      this.liveSelectEl.addEventListener("focusin", raise)
      this.liveSelectEl.addEventListener("click", raise)
      this.liveSelectEl.addEventListener("input", raise)
    }
  },

  maintainZIndex() {
    const dropdownEl = this.getDropdownEl()
    if (dropdownEl && getComputedStyle(dropdownEl).display !== 'none') {
      this.ensureHighZIndex()
    } else {
      this.ensureLowZIndex()
    }
  },

  ensureHighZIndex() {
    const targetZ = '9999'
    if (this.wrapper.style.zIndex !== targetZ) {
      this.wrapper.style.zIndex = targetZ
      this.wrapper.style.position = 'relative'
    }
  },

  ensureLowZIndex() {
    const targetZ = '1'
    if (this.wrapper.style.zIndex !== targetZ) {
      this.wrapper.style.zIndex = targetZ
    }
  },

  updated() {
    this.repositionDropdown()
    this.maintainZIndex()
  },

  destroyed() {
    if (this.zIndexInterval) {
      clearInterval(this.zIndexInterval)
    }
    document.removeEventListener("mousedown", this.onDocClick)
    window.removeEventListener("scroll", this.handleScroll, true)
    window.removeEventListener("resize", this.handleResize, true)
    if (this.observer) this.observer.disconnect()
  },

  onDocClick(ev) {
    if (!this.wrapper.contains(ev.target)) {
      const dropdownEl = this.getDropdownEl()
      if (dropdownEl && getComputedStyle(dropdownEl).display !== 'none') {
        setTimeout(() => {
          const stillThere = this.getDropdownEl()
          if (!stillThere || getComputedStyle(stillThere).display === 'none') {
            this.ensureLowZIndex()
          }
        }, 150)
      }
    }
  },

  setupObserver() {
    this.observer = new MutationObserver(ms => {
      for (let m of ms) {
        for (let node of m.addedNodes) {
          if (node.tagName === 'UL' && node.classList.contains('absolute')) {
            this.ensureHighZIndex()
            this.repositionDropdown()
            return
          }
        }
        for (let node of m.removedNodes) {
          if (node.tagName === 'UL' && node.classList.contains('absolute')) {
            this.ensureLowZIndex()
            return
          }
        }
      }
    })

    if (this.liveSelectEl) {
      this.observer.observe(this.liveSelectEl, { childList: true, subtree: true })
    }
  },

  handleScroll() { this.repositionDropdown() },
  handleResize() { this.repositionDropdown() },

  repositionDropdown() {
    const inputEl = this.wrapper.querySelector("input")
    const dropdownEl = this.getDropdownEl()

    if (!inputEl || !dropdownEl) return
    if (getComputedStyle(dropdownEl).display === 'none') return

    const r = inputEl.getBoundingClientRect()
    Object.assign(dropdownEl.style, {
      position: 'fixed',
      top: `${r.bottom}px`,
      left: `${r.left}px`,
      width: `${r.width}px`,
      zIndex: '10000'
    })
    dropdownEl.classList.add("positioned-dropdown")
  },

  getDropdownEl() {
    if (this.liveSelectEl) {
      const d = this.liveSelectEl.querySelector("ul.absolute")
      if (d) return d
    }
    if (this.wrapper.id) {
      return document.querySelector(`ul[data-parent="${this.wrapper.id}"]`)
    }
    return null
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

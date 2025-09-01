// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin");
const fs = require("fs");
const path = require("path");

const colors = require("tailwindcss/colors");
module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/phoexnip_web.ex",
    "../lib/phoexnip_web/**/*.*ex",
    "../deps/phoenix_multi_select/lib/*.ex",
    "../deps/live_select/lib/live_select/component.*ex",
    "../../../deps/live_select/lib/live_select/component.*ex"
  ],
  safelist: [
    {
      pattern: /hero-.*/
    }
  ],
  theme: {
    extend: {
      colors: {
        // Keep default palettes available
        primary: colors.blue,
        brand: "#FD4F00",

        // Semantic theme tokens powered by CSS variables
        page: "rgb(var(--color-page) / <alpha-value>)",
        surface: "rgb(var(--color-surface) / <alpha-value>)",
        foreground: "rgb(var(--color-foreground) / <alpha-value>)",
        muted: "rgb(var(--color-muted) / <alpha-value>)",
        border: "rgb(var(--color-border-subtle) / <alpha-value>)",
        borderStrong: "rgb(var(--color-border-strong) / <alpha-value>)",
        overlay: "rgb(var(--color-overlay) / <alpha-value>)",
        themePrimary: "rgb(var(--color-primary) / <alpha-value>)",
        themePrimaryDark: "rgb(var(--color-primary-dark) / <alpha-value>)",
        danger: "rgb(var(--color-danger) / <alpha-value>)",
        dangerDark: "rgb(var(--color-danger-dark) / <alpha-value>)",
        disabledSurface: "rgb(var(--color-disabled-surface) / <alpha-value>)",

        // Extra semantic tokens for statuses/notices
        success: "rgb(var(--color-success) / <alpha-value>)",
        successDark: "rgb(var(--color-success-dark) / <alpha-value>)",
        infoBg: "rgb(var(--color-info-bg) / <alpha-value>)",
        infoFg: "rgb(var(--color-info-fg) / <alpha-value>)",
        infoBorder: "rgb(var(--color-info-border) / <alpha-value>)",
        successBg: "rgb(var(--color-success-bg) / <alpha-value>)",
        successFg: "rgb(var(--color-success-fg) / <alpha-value>)",
        successBorder: "rgb(var(--color-success-border) / <alpha-value>)",
        warningBg: "rgb(var(--color-warning-bg) / <alpha-value>)",
        warningFg: "rgb(var(--color-warning-fg) / <alpha-value>)",
        warningBorder: "rgb(var(--color-warning-border) / <alpha-value>)",
        errorBg: "rgb(var(--color-error-bg) / <alpha-value>)",
        errorFg: "rgb(var(--color-error-fg) / <alpha-value>)",
        errorBorder: "rgb(var(--color-error-border) / <alpha-value>)",
        warnBg: "rgb(var(--color-warn-bg) / <alpha-value>)",
        warnFg: "rgb(var(--color-warn-fg) / <alpha-value>)",
        warnBorder: "rgb(var(--color-warn-border) / <alpha-value>)",
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) =>
      addVariant("phx-click-loading", [
        ".phx-click-loading&",
        ".phx-click-loading &",
      ])
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-submit-loading", [
        ".phx-submit-loading&",
        ".phx-submit-loading &",
      ])
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-change-loading", [
        ".phx-change-loading&",
        ".phx-change-loading &",
      ])
    ),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function ({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, "../deps/heroicons/optimized");
      let values = {};
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"],
      ];
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach((file) => {
          let name = path.basename(file, ".svg") + suffix;
          values[name] = { name, fullPath: path.join(iconsDir, dir, file) };
        });
      });
      matchComponents(
        {
          hero: ({ name, fullPath }) => {
            let content = fs
              .readFileSync(fullPath)
              .toString()
              .replace(/\r?\n|\r/g, "");
            let size = theme("spacing.6");
            if (name.endsWith("-mini")) {
              size = theme("spacing.5");
            } else if (name.endsWith("-micro")) {
              size = theme("spacing.4");
            }
            return {
              [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
              "-webkit-mask": `var(--hero-${name})`,
              mask: `var(--hero-${name})`,
              "mask-repeat": "no-repeat",
              "background-color": "currentColor",
              "vertical-align": "middle",
              display: "inline-block",
              width: size,
              height: size,
            };
          },
        },
        { values }
      );
    }),
  ],
};

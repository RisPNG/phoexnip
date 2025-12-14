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
        brand: "var(--color-brand)",

        // Semantic theme tokens backed by 8-digit hex CSS variables
        page: "var(--color-page)",
        surface: "var(--color-surface)",
        foreground: "var(--color-foreground)",
        muted: "var(--color-muted)",
        border: "var(--color-border-subtle)",
        borderStrong: "var(--color-border-strong)",
        overlay: "var(--color-overlay)",
        themePrimary: "var(--color-primary)",
        themePrimaryDark: "var(--color-primary-dark)",
        danger: "var(--color-danger)",
        dangerDark: "var(--color-danger-dark)",
        disabledSurface: "var(--color-disabled-surface)",

        // Extra semantic tokens for statuses/notices
        success: "var(--color-success)",
        successDark: "var(--color-success-dark)",
        infoBg: "var(--color-info-bg)",
        infoFg: "var(--color-info-fg)",
        infoBorder: "var(--color-info-border)",
        successBg: "var(--color-success-bg)",
        successFg: "var(--color-success-fg)",
        successBorder: "var(--color-success-border)",
        warningBg: "var(--color-warning-bg)",
        warningFg: "var(--color-warning-fg)",
        warningBorder: "var(--color-warning-border)",
        errorBg: "var(--color-error-bg)",
        errorFg: "var(--color-error-fg)",
        errorBorder: "var(--color-error-border)",
        warnBg: "var(--color-warn-bg)",
        warnFg: "var(--color-warn-fg)",
        warnBorder: "var(--color-warn-border)",
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

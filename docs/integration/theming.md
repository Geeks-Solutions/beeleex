# Theming the Beeleex pages

The Beeleex LiveView pages ship plain CSS in
`priv/static/beeleex/beeleex.css`. The LiveView layout renders a `.beeleex`
wrapper for theme tokens, and component class names use the `bx-` prefix.
Themes are applied at runtime with CSS custom properties and require no CSS
framework or build step.

## 1. Include the stylesheet

Load it once. To serve the dependency's static files, add
`plug Plug.Static, at: "/", from: :beeleex, only: ~w(beeleex)` in your endpoint
and include the stylesheet in your layout:

```html
<!-- root layout <head> -->
<link rel="stylesheet" href="/beeleex/beeleex.css" />
```

If your app bundles CSS, you can instead import the stylesheet in the bundle.
Adjust the path to match your project:

```css
@import "../../deps/beeleex/priv/static/beeleex/beeleex.css";
```

## 2. Theme by overriding variables

Set your overrides on the `.beeleex` element itself. The library declares
defaults there, so setting existing `--bx-*` tokens only on `:root` or a parent
does not replace those defaults. You can define host tokens on an ancestor and
map them on the wrapper:

```css
.app .beeleex {
  --bx-primary: var(--app-action, #0f766e);
  --bx-primary-hover: var(--app-action-hover, #115e59);
  --bx-primary-contrast: var(--app-on-action, #ffffff);
  --bx-link: var(--app-link, #075985);
  --bx-focus-color: var(--app-focus, #7c3aed);
  --bx-ring: 0 0 0 3px var(--bx-focus-color);
  --bx-button-radius: var(--app-button-radius, 999px);
}
```

With unlayered styles, a same-specificity `.beeleex` override must come **after**
the library CSS. If Beeleex loads later (for example, from an inner layout),
use a more specific selector such as `.app .beeleex` or `.beeleex.app-billing`.
If your app uses cascade layers, keep the overrides unlayered while Beeleex is
unlayered, or import Beeleex in a lower-priority layer.

### Supported tokens

| Variable | Purpose | Default |
|----------|---------|---------|
| `--bx-text` | Main text; invoice balance rule | `#111827` |
| `--bx-muted` | Secondary text and labels | `#6b7280` |
| `--bx-bg` | Page background | `transparent` |
| `--bx-surface` | Cards, tables, inputs and dialogs | `#ffffff` |
| `--bx-surface-alt` | Table headers and row hover, invoice notices and reporting, neutral badges | `#f9fafb` |
| `--bx-border` | Borders, section separators, invoice summary and gross total rules | `#e5e7eb` |
| `--bx-primary` / `--bx-primary-hover` / `--bx-primary-contrast` | Primary button fill / hover fill / text; primary also colours the spinner's leading edge | `#4f46e5` / `#4338ca` / `#ffffff` |
| `--bx-link` | Links and non-destructive inline actions | `--bx-primary` |
| `--bx-focus-color` | Focused input border and default button/input ring colour | `--bx-primary` |
| `--bx-ring` | Full `box-shadow` for focused buttons and inputs | `0 0 0 3px` with the focus colour at 25% opacity (fixed indigo on browsers without `color-mix()`) |
| `--bx-invoice-accent` | Invoice header separator colour | `--bx-primary` |
| `--bx-danger` / `--bx-danger-hover` / `--bx-danger-contrast` | Destructive button fill / hover fill / text; danger also colours inline danger actions and form errors | `#e11d48` / `#be123c` / `#ffffff` |
| `--bx-danger-bg` | Danger badge and error alert background | `#fef2f2` |
| `--bx-badge-danger-text` | Danger badge text | `--bx-danger` |
| `--bx-alert-error-text` | Error alert text | `--bx-danger-hover` |
| `--bx-success` / `--bx-success-bg` | Success badge text / background | `#047857` / `#ecfdf5` |
| `--bx-warning` / `--bx-warning-bg` | Warning badge text / background | `#b45309` / `#fffbeb` |
| `--bx-info-bg` / `--bx-alert-info-text` | Info alert background / text | `#eef2ff` / `--bx-primary-hover` |
| `--bx-spinner-track` | Inactive part of the loading spinner | `rgba(79, 70, 229, 0.25)` |
| `--bx-font` | Base font family | `inherit` |
| `--bx-radius` / `--bx-radius-sm` | Shared large / small corner radius | `0.625rem` / `0.375rem` |
| `--bx-button-radius` | Button corner radius; inputs retain `--bx-radius-sm` | `--bx-radius-sm` |
| `--bx-button-padding` | Button padding shorthand | `0.6rem 1rem` |
| `--bx-button-font-size` / `--bx-button-font-weight` | Button text size / weight | `inherit` / `550` |
| `--bx-button-letter-spacing` / `--bx-button-text-transform` | Button tracking / casing | `inherit` / `inherit` |
| `--bx-gap` | Base layout spacing | `1rem` |
| `--bx-shadow` | Card shadow | `0 1px 2px rgba(16, 24, 40, 0.06), 0 1px 3px rgba(16, 24, 40, 0.1)` |
| `--bx-modal-overlay` | Dialog backdrop colour | `rgba(17, 24, 39, 0.5)` |
| `--bx-modal-shadow` | Dialog shadow | `0 10px 30px rgba(16, 24, 40, 0.2)` |

A default shown as another token follows that token until you supply a
separate value. Existing `--bx-ring` overrides still take precedence over the
derived focus shadow. Set `--bx-focus-color` on the wrapper to update both
the default shadow and the focused input border.

## 3. Light, dark and custom themes

Beeleex defaults to a light palette. If your host uses a different palette,
set the wrapper's `color-scheme` for native form widgets and override the
Beeleex colours. For example, if your app sets a `data-theme` attribute:

```css
.app[data-theme="dark"] .beeleex {
  color-scheme: dark;
  --bx-text: #f1f5f9;
  --bx-muted: #cbd5e1;
  --bx-bg: #101827;
  --bx-surface: #172235;
  --bx-surface-alt: #243248;
  --bx-border: #64748b;
  --bx-primary: #a5b4fc;
  --bx-primary-hover: #c7d2fe;
  --bx-primary-contrast: #17133d;
  --bx-link: #93ddfc;
  --bx-focus-color: #fbbf24;
  --bx-ring: 0 0 0 3px var(--bx-focus-color);
  --bx-invoice-accent: #67e8f9;
  --bx-danger: #fda4af;
  --bx-danger-hover: #fecdd3;
  --bx-danger-contrast: #450a19;
  --bx-danger-bg: #4c1826;
  --bx-success: #86efac;
  --bx-success-bg: #123223;
  --bx-warning: #fde68a;
  --bx-warning-bg: #392b13;
  --bx-info-bg: #28305c;
  --bx-alert-info-text: #dbeafe;
  --bx-spinner-track: #6574a2;
  --bx-modal-overlay: rgba(0, 0, 0, 0.7);
  --bx-modal-shadow: 0 10px 30px rgba(0, 0, 0, 0.6);
}
```

For a system theme, have the host resolve `prefers-color-scheme` into its
theme attribute, or map host tokens that change inside a
`@media (prefers-color-scheme: dark)` rule. When using media queries, limit the
system palette to the host's automatic mode so an explicit light or dark
selection wins. `color-scheme` alone does not change Beeleex tokens.

Choose text and background colours together. Check both button states and
status pairs, muted text against both surfaces, and keyboard focus against the
surrounding surface. Use an opaque `--bx-ring` if the default translucent
ring is too faint on your theme.

## 4. Component-level adjustments

For layout and styling beyond the supported tokens, target the relevant
`bx-` class from your wrapper. This scopes your override to the billing UI:

```css
.beeleex .bx-table thead th { text-transform: none; }
```

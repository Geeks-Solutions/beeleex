# Theming the Beeleex pages

The Beeleex LiveView pages ship a single stylesheet
(`priv/static/beeleex/beeleex.css`) that is:

- **scoped** — every rule lives under the `.beeleex` root wrapper (rendered by
  the Beeleex live layout), so it never leaks into your application's styles;
- **dependency-free** — plain CSS, no Tailwind/SASS/build step required;
- **themeable at runtime** — the entire look is driven by CSS custom properties,
  so you restyle it by overriding a handful of variables.

## 1. Include the stylesheet

Add it once to your app. Either reference the file shipped in the dependency or
copy it into your own asset pipeline.

```html
<!-- root layout <head> -->
<link rel="stylesheet" href="/beeleex/beeleex.css" />
```

If you serve the dependency's `priv/static` (Phoenix does this for your own app,
not for deps), the simplest path is to copy/import the file in your bundler, e.g.
with esbuild/npm:

```js
// assets/css/app.css
@import "../../deps/beeleex/priv/static/beeleex/beeleex.css";
```

## 2. Theme by overriding variables

Override any variable **after** the stylesheet loads. Scope your overrides to
`.beeleex` (or a custom class alongside it):

```css
.beeleex {
  --bx-primary: #ff6a00;
  --bx-primary-hover: #e35f00;
  --bx-radius: 4px;
  --bx-font: "Inter", system-ui, sans-serif;
}
```

That single block restyles every button, link, focus ring, badge, etc.

### Available variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `--bx-text` | Body text colour | `#111827` |
| `--bx-muted` | Secondary text | `#6b7280` |
| `--bx-bg` | Page background | `transparent` |
| `--bx-surface` | Cards / tables / inputs background | `#ffffff` |
| `--bx-surface-alt` | Subtle backgrounds (table head, hover) | `#f9fafb` |
| `--bx-border` | Borders / dividers | `#e5e7eb` |
| `--bx-primary` / `--bx-primary-hover` / `--bx-primary-contrast` | Primary action colour | indigo |
| `--bx-danger` / `--bx-danger-hover` / `--bx-danger-contrast` | Destructive actions | rose |
| `--bx-success` / `--bx-success-bg` | "Solvent", "paid", "default" states | emerald |
| `--bx-warning` / `--bx-warning-bg` | "At risk", "pending" states | amber |
| `--bx-info-bg` | Info alert background | light indigo |
| `--bx-font` | Font family (defaults to `inherit`) | `inherit` |
| `--bx-radius` / `--bx-radius-sm` | Corner radius | `0.625rem` / `0.375rem` |
| `--bx-gap` | Base spacing unit | `1rem` |
| `--bx-shadow` | Card shadow | subtle |
| `--bx-ring` | Focus ring | primary @ 25% |

`--bx-font` defaults to `inherit`, so by default the pages already pick up your
site's font.

## 3. Going further

Every element also carries a stable semantic class (`bx-btn`, `bx-table`,
`bx-card`, `bx-badge`, `bx-modal`, `bx-input`, …) so, if variables aren't enough,
you can target those classes directly in your own CSS for finer control:

```css
.beeleex .bx-table thead th { text-transform: none; }
.beeleex .bx-btn--primary { box-shadow: 0 2px 6px rgba(0,0,0,.15); }
```

Because everything is namespaced under `.beeleex` and `bx-`, these overrides
won't collide with the rest of your application.

## Why not Tailwind?

Tailwind theme tokens resolve at **build time**, so a pre-compiled component
library can't be re-themed by a host without rebuilding it. CSS custom
properties resolve at **runtime**, which is what lets you drop these pages into
any site and restyle them with a few lines. (The components keep semantic class
names rather than utility classes for the same reason.)

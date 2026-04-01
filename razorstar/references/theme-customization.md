# Theme Customization

## How to Paste a tweakcn Theme into `theme.css`

1. Open [tweakcn.com/editor/theme](https://tweakcn.com/editor/theme), design your theme, then click **Code**.
2. In `theme.css`, replace the `:root { ... }` block with the tweakcn light-mode output, and the `.dark { ... }` block with the dark-mode output.
3. **Rename** `--sidebar-background` to `--sidebar` in both blocks (tweakcn uses a different name; Basecoat expects `--sidebar`).
4. **Do NOT** paste the `@theme inline` color mappings from tweakcn — `basecoat.css` already registers those. The `@theme inline` block at the bottom of `theme.css` only covers fonts, shadows, and tracking that Basecoat does not handle.
5. Both `oklch()` and hex colour values work fine — no conversion needed.

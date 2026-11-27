# Theme customization

## Paste a tweakcn theme into `theme.css`

1. Open [tweakcn.com/editor/theme](https://tweakcn.com/editor/theme), design, click Code.
2. In `assets/css/theme.css` (or the project's `public/css/theme.css`), replace the `:root { ... }` block with the light output and `.dark { ... }` with the dark output.
3. Rename `--sidebar-background` to `--sidebar` in both blocks. tweakcn and Basecoat disagree on the name.
4. Do not paste tweakcn's `@theme inline` color mappings. `basecoat.css` already registers those. The `@theme inline` at the bottom of `theme.css` only covers fonts, shadows, and tracking.
5. `oklch()` and hex both work.

Do this in the skill's `assets/` before scaffolding if the user wants a custom look from the first run. Otherwise leave the defaults and tweak later.

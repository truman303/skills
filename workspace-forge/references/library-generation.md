# Library generation

Once the workspace is up, libraries are created differently per stack
because the runtime boundary is also the tooling boundary.

## Web (Angular / TypeScript) libs

### Folder taxonomy

```
libs/web/<product>/<module>/<type>/<name>/
```

| Segment   | Pick from                                         | Example         |
| --------- | ------------------------------------------------- | --------------- |
| `<product>` | a domain or app cluster; `shared` for cross-cutting | `katydid`, `shared` |
| `<module>`  | bounded context inside the product                  | `auth`, `shell`, `ui` |
| `<type>`    | `data-access` \| `feature` \| `ui` \| `util`        | `feature`         |
| `<name>`    | the lib's own name (kebab-case)                     | `login-page`      |

This is the standard Nrwl "scope/module/type" layout. Why it's worth the
extra nesting:

- **`<product>`** doubles as the ESLint `scope:` tag, which means
  cross-product imports can be enforced once and forever via
  `@nx/enforce-module-boundaries`.
- **`<module>`** keeps file paths short (no flat 200-folder `libs/`) and
  surfaces bounded contexts to anyone reading the tree.
- **`<type>`** lets you write the standard "feature can import everything,
  ui/util cannot import data-access" rule one time at the workspace root.

### The generator

```sh
npx nx g @nx/angular:library libs/web/<product>/<module>/<type>/<name> \
  --name=<name> \
  --tags=scope:<product>,type:<type> \
  --prefix=ui \
  --no-interactive
```

Two non-obvious things about this generator:

1. **The directory is the positional argument**, the project name is `--name`.
   Mixing them up generates the lib in the wrong place under a path-shaped
   project name, which is annoying to undo.
2. **It does not support `--dry-run`.** Use `git status` after running to
   see what changed; revert with `git checkout -- .` if you don't like the
   result.

### What you get

- `libs/web/.../{<name>}/project.json`, sample standalone component,
  `lint` and `test` targets (vitest-analog by default per `nx.json#generators`).
- A path alias added to `tsconfig.base.json`:
  `"@<scope>/<name>": ["libs/web/<product>/<module>/<type>/<name>/src/index.ts"]`
- No further wiring. Apps and other libs can `import { ... } from '@<scope>/<name>'`
  immediately and Nx infers the dependency from the import.

### Buildable vs non-buildable

Default is **non-buildable** (consumer's bundler compiles the source).
That's the right default for monorepo libs that are only consumed by other
projects in the workspace.

- Pass `--buildable` for an own `ng-packagr` build target. Use this if you
  want incremental builds or to publish to a private registry without going
  full publishable.
- Pass `--publishable --import-path=@your-org/<name>` for npm-publishing.

## .NET libs

### Folder taxonomy

```
libs/dotnet/<Pascal.Cased.Name>/
```

Flat under `libs/dotnet/`, no `<product>/<module>/<type>` nesting. Why:

- C# project names are typically `Product.Module.Layer` (`Demo.Domain`,
  `Katydid.Auth.Domain`) — the dots already encode the hierarchy.
- The runtime boundary isn't ambiguous on the .NET side (everything compiles
  to one set of CLR assemblies), so you don't need `scope:` to keep things
  readable.

### Creating a class lib

```sh
dotnet new classlib -o libs/dotnet/<Name> -f net10.0
```

Then wire references with full `.csproj` paths:

```sh
dotnet add apps/<api>/<api>.csproj reference \
  libs/dotnet/<Name>/<Name>.csproj
```

`@nx/dotnet` auto-detects on the next `nx` invocation. No `project.json`
needed unless you want to override an inferred target (e.g. mark
`build:release` as cacheable, or add tags for module boundaries — see
`module-boundaries.md`).

### Test project

```sh
dotnet new xunit -o libs/dotnet/<Name>.Tests -f net10.0
dotnet add libs/dotnet/<Name>.Tests/<Name>.Tests.csproj reference \
  libs/dotnet/<Name>/<Name>.csproj
```

The xunit/NUnit/MSTest templates are auto-recognized as test projects and
get a `test` target.

## When to add a library at all

Default to apps until they hurt. Symptoms that hurt:

- The same TS file imported from two apps. Move it to `libs/web/shared/`.
- A C# record/type used in both API and tests. Move it to a class lib.
- App build times pushing past a minute on `nx build`. Splitting into a
  buildable lib lets `affected` skip rebuilds when the lib didn't change.

Don't pre-emptively split for "good architecture" — the layout above
absorbs that as soon as the second consumer arrives.

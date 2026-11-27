# README pattern

> Placeholders: `MyApp` (display). See SKILL.md.

Every app gets a `README.md` in its root. It is for someone who has just cloned the project and wants it running, and for the same person three months later who has forgotten how the stylesheet gets built. It covers three things: what the app is, the commands to start it, and the commands to rebuild the styles.

## When to write it

| Track | When | Where |
|-------|------|-------|
| Greenfield | The last step of Phase 2, once `./gradlew build` passes. Bring it up to date in Phase 5. | `README.md` in the project root |
| Attach | Once the first screen works | A short section in the host's own README. See [the attach section](#attached-to-an-existing-app). |

## The template

Text in `<angle brackets>` is for you to replace. The rules for each part follow the template.

````markdown
# MyApp

Java 21 web app for <what it manages>. Login, a dashboard, and a notification bell. Postgres runs in Docker.

## Requirements

Java 21 and Docker.

The `java` command on this machine is Java <n>. Point the shell at Java 21 before Gradle:

```bash
export JAVA_HOME=<path of the Java 21 install on this machine>
export PATH="$JAVA_HOME/bin:$PATH"
```

## Start

Docker has to be running. From the project directory:

```bash
./scripts/start-dev-environment.sh
./gradlew run
```

The script starts Postgres and waits until it is healthy. The app reads `.env` on startup. Open the URL the script prints.

Sign in with `DEV_ADMIN_USERNAME` and `DEV_ADMIN_PASSWORD` from `.env`. The first start creates that user when the users table is empty, and puts one welcome notification behind the bell.

`.env` is gitignored. It holds the database name, both passwords, `DATABASE_URL`, and `UI_PORT`.

## Styles

Pages load `/css/tailwind-output.css`. `theme.css` and the class names in the `.jte` templates are inputs to that file, and `./gradlew build` only copies the CSS that is already compiled. After you edit `src/main/resources/public/css/theme.css`, or use a Tailwind class that no template used before, rebuild the stylesheet and start the app again:

```bash
./tailwindcss -i src/main/resources/public/css/site.css -o src/main/resources/public/css/tailwind-output.css
./gradlew run
```

To rebuild on every save while you work on templates, run the first command with `--watch` in a second terminal. The app still picks up the new stylesheet only when it starts.

The `tailwindcss` command is the Tailwind standalone CLI, a binary in the project root. It is gitignored. After a fresh clone, download the one for your platform from the [Tailwind releases](https://github.com/tailwindlabs/tailwindcss/releases/latest), save it in the project root as `tailwindcss`, and run `chmod +x tailwindcss`. The compiled stylesheet is committed, so the app starts without the binary.

## If a port is taken

Change `UI_PORT` in `.env`. The app uses the new value on the next start. If port 5432 is taken, change the host side of the port mapping in `docker-compose.yml` and the port in `DATABASE_URL` together.

## Stop

Ctrl-C stops the app. The database container keeps running. `docker compose down` stops it.
````

## Filling it in

### The first paragraph

One sentence on what the app is for, in the words the user gave in discovery. Then what it has. In Phase 2 that is login, a dashboard and the bell. In Phase 5 add the first feature: "Products with search, create, edit and delete."

### Requirements

Run `java -version`. If it reports 21, delete the paragraph about the `java` command and the two `export` lines. If it reports something else, find a Java 21 install on the machine, put its real path in, and keep the sentence that says the path belongs to this machine.

### Start

Run both commands from a fresh terminal before you write them down. If `./gradlew run` cannot find the database settings, the app is missing the `.env` loader that [project-scaffolding.md](project-scaffolding.md) asks for. Fix the app. Do not work around it with an extra step in the README. If you cannot run Docker, the user runs the commands at the Phase 3 checkpoint, and you correct the README from what they report.

### The port

If `UI_PORT` is not 8080, say what it is and why: "`UI_PORT` in `.env` is `8088`, because something else was already listening on 8080."

### Styles

The restart is not optional. `./gradlew run` copies `src/main/resources` into `build/` and the app serves the copy, so a rebuilt stylesheet reaches the browser only after the next start. Templates differ: in dev the app reads them from `src/main/jte` on each request, which is why a new class can show up in the HTML and still have no style.

### The last two sections

Keep them if they apply. Add another only for something a person tripped over in this project.

## Rules

1. Every command in the README has been run in this project, by you or by the user.
2. Name the `.env` keys. Never copy a password or any other secret out of `.env`.
3. Describe this app, not the stack. Leave out the package layout, the list of routes, how Javalin or Datastar work, badges, a licence section and a contributing section. The user can ask for any of them.
4. Keep it to about one screen. When a section stops being true, change it in the same piece of work that made it untrue.

## Attached to an existing app

The host has its own README. Do not replace it or reorder it. Add one section near its run instructions and adjust the paths to the UI module:

````markdown
## Web UI

The UI is the `ui` module. It starts with the app and listens on `UI_PORT`, 8080 by default. Sign in with <how users sign in>.

Pages load `/css/tailwind-output.css`, which is compiled ahead of the build. After you edit `ui/src/main/resources/public/css/theme.css`, or use a Tailwind class that no template used before, rebuild the stylesheet and restart the app:

```bash
./tailwindcss -i ui/src/main/resources/public/css/site.css -o ui/src/main/resources/public/css/tailwind-output.css
```
````

Add the paragraph about where the `tailwindcss` binary comes from if the host does not already use Tailwind. If the host has no README at all, ask the user before creating one.

# Project scaffolding

> Placeholders: `MyApp` (display), `myapp` (docker/db), `pkg` (Java package). See SKILL.md.

Greenfield only. To add a UI to an app that already exists, use [attach-existing-app.md](attach-existing-app.md).

## Create the Gradle app

```bash
mkdir MyApp && cd MyApp
gradle init --type java-application --dsl groovy --java-version 21 \
  --package pkg --project-name myapp --test-framework junit-jupiter --no-split-project
```

If `gradle` is missing, install the wrapper from a nearby Java 21 project and copy `gradlew`, `gradlew.d/`, `gradle/wrapper/`.

Set the main class to `pkg.App`.

## Versions (pin these)

Keep them in `gradle.properties` or `ext {}` on the root project.

```
javalinVer=7.2.3
jteVer=3.2.4
datastarVer=1.0.1
jdbiVer=3.54.0
hikariVer=5.1.0
postgresqlVer=42.7.4
flywayVer=11.7.2
log4j2Ver=2.22.1
bcryptVer=0.10.2
```

The JTE Gradle plugin version must match `jteVer`.

`datastarVer` is the Java SDK. It pairs with the bundled `assets/js/datastar.js`, which is Datastar v1.0.5. Upgrade the two together and rerun the browser checks in [crud-pages.md](crud-pages.md) when you do.

## Root `build.gradle`

```groovy
plugins {
    id 'application'
    id 'gg.jte.gradle' version "${jteVer}"
}

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

repositories { mavenCentral() }

dependencies {
    implementation "io.javalin:javalin:${javalinVer}"
    implementation "io.javalin:javalin-rendering-jte:${javalinVer}"

    implementation "gg.jte:jte:${jteVer}"

    implementation "dev.data-star:datastar-java-sdk-core:${datastarVer}"

    implementation "org.jdbi:jdbi3-core:${jdbiVer}"
    implementation "org.jdbi:jdbi3-postgres:${jdbiVer}"
    implementation "com.zaxxer:HikariCP:${hikariVer}"
    implementation "org.postgresql:postgresql:${postgresqlVer}"
    implementation "org.flywaydb:flyway-core:${flywayVer}"
    implementation "org.flywaydb:flyway-database-postgresql:${flywayVer}"

    implementation "org.apache.logging.log4j:log4j-core:${log4j2Ver}"
    implementation "org.apache.logging.log4j:log4j-api:${log4j2Ver}"
    runtimeOnly    "org.apache.logging.log4j:log4j-slf4j2-impl:${log4j2Ver}"

    implementation "at.favre.lib:bcrypt:${bcryptVer}"

    testImplementation "org.junit.jupiter:junit-jupiter:5.11.4"
}

jte {
    generate()
}

application {
    mainClass = 'pkg.App'
}

test { useJUnitPlatform() }
```

`javalin-rendering-jte` already brings JTE. The explicit `gg.jte:jte` line keeps the plugin and runtime on the same version.

The Datastar SDK brings Jackson, which `Signals` uses. There is no separate JSON dependency.

## Directory layout

```
MyApp/
├── build.gradle
├── gradle.properties
├── scripts/start-dev-environment.sh
├── docker-compose.yml
├── .env                          # gitignored
├── src/main/java/pkg/
│   ├── App.java
│   ├── Result.java
│   ├── ErrorDetail.java
│   ├── web/                      # Sse, Signals, TableState, Message, Templates, SessionAuth, ExceptionMapping
│   └── features/
│       ├── auth/
│       ├── dashboard/
│       └── items/
├── src/main/jte/
│   ├── layout/                   # page.jte, landing.jte
│   ├── fragments/                # messages.jte, toast.jte
│   ├── error.jte
│   ├── auth/
│   ├── dashboard/
│   └── items/
├── src/main/resources/
│   ├── public/css/
│   ├── public/js/
│   ├── public/images/
│   ├── db/migration/
│   └── log4j2.xml
└── src/test/java/
```

## Static assets

Copy from `${SKILL_DIR}/assets/` into `src/main/resources/public/`:

```
public/
├── css/basecoat.css
├── css/theme.css
├── css/site.css
├── css/landing.css
├── css/tailwind-output.css      # generate, see below
└── js/basecoat.all.min.js
    js/datastar.js
    js/site.js
```

Javalin serves this tree at `/` via `config.staticFiles.add("/public", Location.CLASSPATH)`.

Generate Tailwind output (Tailwind v4 standalone CLI):

```bash
./tailwindcss -i src/main/resources/public/css/site.css \
  -o src/main/resources/public/css/tailwind-output.css
```

`site.css` imports Tailwind, Basecoat and the theme, so `tailwind-output.css` is the one stylesheet the layout links. Tailwind scans the `.jte` files for class names, so run it again, or keep `--watch` running, after adding classes to a template. Commit `tailwind-output.css` so the first run works without the watcher.

theme.css references Barlow/Poppins under `/fonts/...`. Either add those files or let the browser fall back. Do not block scaffolding on webfonts.

## Flyway

`src/main/resources/db/migration/V001__users.sql` for the session user table. Feature tables get their own `V00n__*.sql`. `App` runs `Flyway.configure().dataSource(ds).load().migrate()` at boot.

Migrations run when the app starts. The user never types a migration command.

## Env loading

Configuration comes from the environment. Read `DATABASE_URL`, `DB_USER`, `DB_PASSWORD`, `DEV_ADMIN_USERNAME`, `DEV_ADMIN_PASSWORD`, `UI_PORT` from the environment. The startup script exports them from `.env`.

A tiny loader that also reads `.env` if present (skip lines starting with `#`) is fine so `./gradlew run` works after the script has been used once. Never commit `.env`.

## IntelliJ

Tell the user to install the **jte** plugin. Without it, `.jte` files are plain text and the type-safe `@param` errors show up only at compile.

## Name substitution

| Where | Replace |
|-------|---------|
| `application.mainClass` | `pkg.App` |
| all `package` / `import` | `pkg.*` |
| docker-compose, `.env` | `myapp` |
| layout `<title>`, sidebar, footer | `MyApp` |
| Flyway `POSTGRES_DB` | `myapp` |

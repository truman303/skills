# Agent Skills

[Agent Skills](https://agentskills.io) maintained by me for practical development work.

## RazorStar Skill

### Overview

[RazorStar Skill](razorstar/SKILL.md)

Guides the user through the process of building a web application using ASP.NET Razor Pages, EF Core with a PostgreSQL database, Datastar for UI reactivity real-time updates via SSE, and Basecoat UI components for simplified Tailwind CSS. Useful for building server-side rendered web applications, where offline capabilities are not required.

Use when the user asks to create a razorstar app, set up a new web app with the RazorStar stack, or add features to an existing RazorStar app. Even if the user just says they want to "build a web app" or "create a CRUD app" or "scaffold a project", consider whether the RazorStar stack is appropriate and offer it.

### Prerequisites

- [Docker](https://www.docker.com/)
- [.NET](https://dotnet.microsoft.com/en-us/download)
- [Tailwind CLI](https://tailwindcss.com/docs/installation/tailwind-cli)

### Installation

Install with the [skills CLI](https://skills.sh/docs/cli).

```cmd
npx skills add https://github.com/truman303/skills --skill razorstar
```

## JtStar Skill

### Overview

[JtStar Skill](jtstar/SKILL.md)

Guides the user through building a server-rendered Java web application with Javalin 7, JTE templates, Jdbi on a PostgreSQL database, Datastar for UI reactivity and real-time updates via SSE, and Basecoat UI components on Tailwind CSS. The domain code follows a small DDD shape: aggregates as records, typed ids, and domain events when something consumes them.

Use when the user asks to create a jtstar app, a Javalin+JTE+Datastar app, a Java CRUD app without a SPA, Spring or Hibernate, or a web UI for an existing Java application.

### Prerequisites

- [Docker](https://www.docker.com/)
- [Java 21](https://adoptium.net/)
- [Tailwind CLI](https://tailwindcss.com/docs/installation/tailwind-cli)

### Installation

```cmd
npx skills add https://github.com/truman303/skills --skill jtstar
```

## Workspace Forge Skill

[Workspace Forge](workspace-forge/SKILL.md)

Workspace Forge is a skill that helps you build an NX workspace (monorepo) with Angular and .NET [@nx/dotnet](https://www.npmjs.com/package/@nx/dotnet) plugin.

Use this skill whenever the user wants to set up an Nx workspace, scaffold a monorepo with Angular and .NET, mix Angular and .NET in one repo, bootstrap a dev container for an Nx repo, get a working `npm run demo` end-to-end, or stand up CI for an Angular + .NET project. Do NOT use this skill for adding apps/libs to an *existing* workspace — `nx-generate` covers that. This skill is specifically about the **first build** of the repo.

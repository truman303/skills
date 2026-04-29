# Agent Skills

[Agent Skills](https://agentskills.io) maintained by me for practical development work.

## RazorStar Skill

### Overview

[RazorStar Skill](razorstar/SKILL.md)

Build a web application using ASP.NET Razor Pages, EF Core with a PostgreSQL database, Datastar for UI reactivity real-time updates via SSE, and Basecoat UI components for simplified Tailwind CSS. Useful for building server-side rendered web applications, where offline capabilities are not required.

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

## Workspace Forge Skill

[Workspace Forge](workspace-forge/SKILL.md)

Workspace Forge is a skill that helps you build an NX workspace (monorepo) with Angular and .NET [@nx/dotnet](https://www.npmjs.com/package/@nx/dotnet) plugin.

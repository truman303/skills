# Nx + Angular + .NET monorepo (Dockerized)

A containerized Nx workspace that hosts both an Angular app (`web`) and a
.NET 8 Web API (`api`). Everything runs inside Docker, so you don't need
Node.js, npm, or the .NET SDK installed on your host.

## Prerequisites

- Docker Desktop / Docker Engine with the Compose plugin (`docker compose`)

## Quick start

```bash
# 1. Build the dev image
docker compose build dev

# 2. Drop into a shell inside the container
docker compose run --rm --service-ports dev
```

From inside the container shell, follow `PLAN.md` in the outputs folder
(or the section below) to generate the Nx workspace, add the .NET plugin,
and scaffold the `web` and `api` apps.

Once the workspace exists you can `exit` and use:

```bash
docker compose up web   # Angular dev server on http://localhost:4200
docker compose up api   # .NET Web API on http://localhost:5000
```

## Layout (after scaffolding)

```
.
├── Dockerfile
├── docker-compose.yml
├── nx.json
├── package.json
├── apps/
│   ├── web/          # Angular app
│   └── api/          # .NET 8 Web API (csproj lives here)
└── ...
```

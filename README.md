# Dossier release stack

Runs **[Dossier](https://github.com/sanjeevstunner/dossier)** (the app) and **[Noperi](https://github.com/sanjeevstunner/NopeRi-ts)** (a Naukri API it uses for job search and applying) with Docker Compose, plus Postgres and, if you want it, Ollama for a local model.

This README only covers deploying and releasing. For features, configuration and API details, see each app's own repo.

| Service  | Image                         | Port (localhost only) |
| -------- | ----------------------------- | --------------------- |
| `app`    | `sanjeevstunner/dossier`      | `3000` (`DOSSIER_PORT`) |
| `noperi` | `sanjeevstunner/noperi`       | `3001` (`NOPERI_PORT`)  |
| `db`     | `postgres:18-alpine`          | not published         |
| `ollama` | `ollama/ollama` (profile `ai`)| not published         |

---

## Using the service

You need Docker with Compose v2. npm is optional.

1. Put `compose.yml`, `.env.example` and (if you use npm) `package.json` in a folder.
2. Copy `.env.example` to `.env` and fill in the required values:

   | Variable | How to get it |
   | --- | --- |
   | `POSTGRES_PASSWORD` | any strong password |
   | `DOSSIER_PASSWORD` | a **hash** of your sign-in password: `docker run --rm -it sanjeevstunner/dossier hash-password` |
   | `DOSSIER_SECRET` | `openssl rand -base64 32` (changing it later signs you out) |
   | `NOPERI_API_KEY` | `openssl rand -hex 24` (at least 16 characters) |
   | `NAUKRI_USERNAME`, `NAUKRI_PASSWORD` | your Naukri login |

   The optional settings (AI provider, job search source, Google OAuth, backups, time zone) are described in `.env.example`.

3. Start it:

   ```sh
   npm run up          # or: docker compose up -d
   ```

4. Open http://localhost:3000 and sign in.

Other commands: `npm run logs`, `npm run pull` (fetch newer images), `npm run down`.

### Running on a server

- Ports bind to `127.0.0.1` only. Put a reverse proxy with HTTPS (Caddy, nginx, etc.) in front of port 3000.
- If you use Gmail/Calendar, set `DOSSIER_PUBLIC_URL` to the public address. The Google OAuth redirect URI is `<DOSSIER_PUBLIC_URL>/api/google/callback`.
- Naukri blocks most datacenter IPs. If Noperi can't log in, set `NAUKRI_PROXY` to a residential proxy.

### Local AI model

Add `COMPOSE_PROFILES=ai` to `.env` and run `docker compose up -d`. Then pull a model and point Dossier at it:

```sh
docker compose exec ollama ollama pull llama3.1:8b
```

```env
DOSSIER_AI_PROVIDER=local
DOSSIER_AI_URL=http://ollama:11434
DOSSIER_AI_MODEL=llama3.1:8b
```

To use Ollama or LM Studio running on the host instead, use `http://host.docker.internal:11434` (or `:1234`).

### Data and backups

Postgres data is stored in the `pgdata` volume and app data in the `data` volume. Dossier backs up every night at 03:00 in `TZ` and keeps backups for `DOSSIER_BACKUP_RETENTION_DAYS` days (default 14). `docker compose down -v` deletes these volumes, so don't run it unless you mean to.

---

## Building on top

This repo holds no application code. It pins both apps as git submodules and builds images from them:

| Path          | Repo |
| ------------- | ---- |
| `dossier`     | [sanjeevstunner/dossier](https://github.com/sanjeevstunner/dossier) (fork of the upstream Dossier) |
| `noperi-ts`   | [sanjeevstunner/NopeRi-ts](https://github.com/sanjeevstunner/NopeRi-ts) |

Make code changes in those repos. Use this one to choose which commits ship and to publish the images.

```sh
git clone --recurse-submodules <this repo>
npm run sources          # check out the pinned submodule commits
npm run sources:latest   # or move to each submodule's latest remote commit
```

### Releasing

1. Each image is tagged with its own submodule's `package.json` version (`dossier/` and `noperi-ts/`), read by `versions.sh`. Bump the version in that project, not here. `npm run versions` shows what will be used.
2. If you moved the submodules, commit the new submodule pointers.
3. Build and push multi-arch images (`linux/amd64`, `linux/arm64`) tagged with that version and `latest`:

   ```sh
   docker login
   docker buildx create --use   # once, if you don't have a multi-platform builder
   npm run release              # or release:dossier / release:noperi on their own
   ```

   `prerelease` runs `npm run sources` first, so the build uses the commits this repo pins.

`npm run up`, `pull` and `hash-password` use the submodule versions too. A plain `docker compose up` uses `:latest`.

### Changing the stack

- New app setting: add it to `app.environment` in `compose.yml` as `${VAR:-}`, then document it in `.env.example`.
- Dossier talks to Noperi over the compose network at `http://noperi:3000` and authenticates with `NOPERI_API_KEY`. Keep the two consistent if you rename either one.
- `.env` is gitignored. Keep it that way.

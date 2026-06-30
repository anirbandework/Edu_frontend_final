# EduAssist — Deployment Runbook (Railway backend + Vercel frontend)

> Backend (FastAPI) → **Railway** (with Railway Postgres + Redis). Frontend (Flutter web) → **Vercel**.
> All the wiring files referenced below already exist; this is the click-by-click runbook.

## Files this setup added
- `edu_backend/railway.json` — Railway build (Dockerfile) + start command + `/health` healthcheck.
- `edu_backend/railway-start.sh` — runs the production migration (schema + indexes + **super-admin seed**), then gunicorn on `$PORT`.
- `edu_backend/Dockerfile` — CMD now binds `$PORT` (was hardcoded 8000).
- `edu_backend/app/core/config.py` — auto-converts Railway's `postgresql://` → `postgresql+asyncpg://`; `ALLOWED_ORIGINS` accepts JSON array or comma-separated.
- `edu_backend/requirements.txt` — **locked** to the working venv (incl. `psycopg2-binary`, `pydantic-settings 2.12`); old/unused pins (pandas, google-ai…) removed.
- `Edu_assist_dynamic/vercel.json` + `vercel_build.sh` — installs Flutter, builds web with `API_BASE_URL`, SPA rewrites.

---

## A. Backend → Railway

1. **New project** → Deploy from your GitHub repo (the `edu_backend` folder). Railway detects the `Dockerfile` + `railway.json`.
2. **Add plugins:** “New → Database → PostgreSQL”, and “New → Database → Redis”.
3. **Service → Variables**, set:

   | Variable | Value |
   |---|---|
   | `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` (reference — scheme auto-normalised to asyncpg in code) |
   | `REDIS_URL` | `${{Redis.REDIS_URL}}` |
   | `JWT_SECRET_KEY` | a long random string — `openssl rand -hex 32` |
   | `ENVIRONMENT` | `production` |
   | `ALLOWED_ORIGINS` | `["https://<your-app>.vercel.app"]` (add the real Vercel URL after step B) |
   | `SUPER_ADMIN_PHONE` | your real admin phone (the login id) |
   | `SUPER_ADMIN_PASSWORD` | a strong password |
   | `SUPER_ADMIN_EMAIL` | optional |

   `PORT` is injected by Railway automatically — don't set it.
4. **Deploy.** On boot, `railway-start.sh` runs `run_production_migration --yes` (creates tables + indexes + **seeds the super-admin**), then starts gunicorn. The healthcheck hits `/health`.
5. **Note the public URL** (Settings → Networking → Generate Domain), e.g. `https://eduassist-backend.up.railway.app`.

> Alternative: instead of letting the start script migrate, run it once from your laptop — set
> `PRODUCTION_DATABASE_URL` in `.env` to Railway → Postgres → Variables → **DATABASE_PUBLIC_URL**, then
> `python -m database_compare.run_production_migration --yes`. (The start script also does it; either is fine, it's idempotent.)

## B. Frontend → Vercel

1. **New project** → import the repo, set **Root Directory** to the Flutter app folder (`…/Edu_assist_dynamic`).
2. **Settings → Environment Variables:** `API_BASE_URL = https://<your-backend>.up.railway.app` (no trailing slash).
   Vercel uses `vercel.json` → `vercel_build.sh` (installs the Flutter SDK, `flutter build web --dart-define=API_BASE_URL=…`), output `build/web`. SPA rewrites are configured.
3. **Deploy.** (The first build is slow — it clones the Flutter SDK. The release build *refuses* a `localhost`/`.local` API URL, so the env var must be the real backend.)
4. **Wire CORS:** copy the Vercel domain into Railway's `ALLOWED_ORIGINS` (step A.3) and redeploy the backend.

## C. Verify
- `GET https://<backend>/health` → 200.
- Open the Vercel URL → log in as the super-admin (phone + password you set). If login 401s, the migration/seed didn't run — check Railway deploy logs for the `[release]` line.
- DevTools → Network: API calls go to the Railway URL with no CORS errors.

---

## Env-var checklist (backend)
`DATABASE_URL` · `REDIS_URL` · `JWT_SECRET_KEY` · `ENVIRONMENT=production` · `ALLOWED_ORIGINS` ·
`SUPER_ADMIN_PHONE` · `SUPER_ADMIN_PASSWORD` · (`SUPER_ADMIN_EMAIL`). Frontend: `API_BASE_URL`.

## Gotchas (already handled in code, here for awareness)
- **asyncpg URL** — Railway gives `postgresql://`; `config.py` rewrites it to `postgresql+asyncpg://`. ✅
- **$PORT** — Dockerfile + `railway-start.sh` bind `${PORT}`. ✅
- **CORS** — wildcard is rejected when `ENVIRONMENT=production`; set the exact Vercel origin. ✅
- **Migrations need psycopg2** — now in `requirements.txt`. ✅
- **🔒 OTP is `999999` in every env** (`config.py: otp_dev_mode_active`). Before real users, restore the prod gate
  (`return self.otp_dev_mode and not self.is_production`) and wire an SMS provider — otherwise anyone who knows a
  phone can set its password. This is the one **must-do security item** pre-launch.
- **Secrets** — keep them in the Railway/Vercel dashboards, not in committed files. Ensure `.env` is git-ignored;
  rotate any key that was ever committed.

## After a schema change (new table / index)
Append the idempotent SQL to `edu_backend/database_compare/migrations.py`, push, and redeploy — `railway-start.sh`
re-runs `run_production_migration` on the next boot (idempotent). New ORM tables are auto-created by
`create_all`; only ALTERs/indexes need a migrations.py entry.

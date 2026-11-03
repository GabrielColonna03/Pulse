# Budget Pulse Dashboard

Budget Pulse is a full-stack personal finance dashboard with:

- Quick Add transaction entry
- Per-user categories, subcategories, and keyword-based auto-categorization
- First-login setup walkthrough for new dashboard users
- Import preview and commit from Excel
- Export to Excel and backup CSV
- Trip tagging and summaries
- Local SQLite storage

## Product Direction

Pulse is being developed as a personal financial memory and planning system:
**leave the spreadsheet, keep the control.** The [production plan](PRODUCT_PLAN.md)
defines the product positioning, roadmap, release gates, success metrics, privacy
requirements, and prioritized backlog.

## Why "Pulse"

The name reflects Pulse's central promise: stay close to your own financial data
and understand what it means. Rather than handing that meaning to an opaque
automated service, Pulse keeps the categories, context, history, and decisions
in the user's hands.

## Run Locally

1. Install dependencies:
  - `npm install`
2. Copy env template (optional for local):
  - `copy .env.example .env`
  - Set `DATABASE_URL` in `.env` to your Supabase Postgres connection string. Localhost uses whichever database this variable points to.
3. Start server:
  - `npm start`
4. Open:
  - `http://localhost:4100`

## Native iOS App (SwiftUI)

A fully native SwiftUI client lives in [`native-ios/`](native-ios/README.md).

```bash
open native-ios/Pulse/Pulse.xcodeproj
```

Set your signing team, enter the API base URL on first launch, then sign in with
your 4-digit PIN. The app uses Keychain-backed Bearer tokens, Face ID lock,
haptics, swipe actions, and Swift Charts while calling the same Pulse API.

## iOS Capacitor App

The repository also keeps a Capacitor shell under `ios/`. `npm run build:ios`
copies the frontend into `www/` and injects the API host from `PULSE_API_BASE`.
The backend remains external and is never bundled into the native app.

```bash
PULSE_API_BASE=https://your-backend-domain.com npm run build:ios
npx cap sync ios
npx cap open ios
```

For local web development, omit `PULSE_API_BASE` so the frontend continues to
use same-origin requests. For an iOS build, set it to the HTTPS production API
origin without a trailing slash.

The remote backend's `CLIENT_ORIGINS` must include `capacitor://localhost` and
the production web frontend origin. Because the app uses credentialed requests,
the backend must echo the requesting origin in `Access-Control-Allow-Origin`,
send `Access-Control-Allow-Credentials: true`, allow `GET,POST,PUT,DELETE,OPTIONS`,
and allow the `Content-Type` and `Authorization` request headers. Do not use
`Access-Control-Allow-Origin: *` with cookies.

Potential follow-up native plugins:

- `@capacitor/status-bar` for status bar appearance and contrast.
- `@capacitor/splash-screen` for launch-screen behavior.
- `@capacitor/preferences` for durable, native-backed preferences.
- `@capacitor/app` for lifecycle and deep-link handling.
- `@capacitor/browser` for external web authentication flows.

The server uses PostgreSQL through `DATABASE_URL`. If `DATABASE_URL` is missing, the PostgreSQL driver attempts its local default connection instead, which is a different database from Supabase.

## Environment Variables

Use `.env` (or host env settings) for runtime config:

- `PORT`: server port (defaults to `4100`)
- `CLIENT_ORIGINS`: comma-separated allowed frontend origins for CORS
  - Example: `https://pulse-ui.pages.dev,https://www.yourdomain.com`
  - Use `*` only for temporary testing

## Free Deployment Paths

### Option A: Single Service (Easiest)

Deploy the whole app (frontend + backend) as one free Node web service on Render.

1. Push this repo to GitHub.
2. In Render, create a **Web Service** from the repo.
3. Build command: `npm install`
4. Start command: `npm start`
5. Set env vars:
  - `PORT` is managed by Render automatically.
  - `CLIENT_ORIGINS` can stay empty for same-origin deployment.
6. Deploy and open your Render URL.

This keeps all features working with no frontend/backend split.

### Option B: Static Frontend + Separate Backend

If you host `index.html`/`app.js`/`styles.css` on a static host (Cloudflare Pages, GitHub Pages, Netlify), keep backend on a Node host.

1. Deploy backend (Render web service).
2. Set backend `CLIENT_ORIGINS` to your static site URL.
3. In `config.js`, set:
  - `window.__PULSE_API_BASE__ = "https://your-backend-domain.com";`
4. Deploy static frontend files.

Frontend now sends API calls to that backend base URL.

## Render Blueprint File

This repo includes `render.yaml` for Render blueprint-style setup.

## Health Check

Backend health endpoint:

- `GET /api/health` returns `{ "status": "ok" }`

## Data Persistence Note

Current storage is SQLite (`budget.db`). On free cloud runtimes, local disk persistence can be limited depending on provider lifecycle. For durable production persistence, migrate DB to a managed Postgres provider and update server queries accordingly.

## Customize Classification

Each signed-in user starts with the default Pulse category model, then can customize it independently:

On a user's first login, Pulse opens a dedicated setup screen before the dashboard. The user must build a valid personal category model with at least one income parent/subcategory and one expense parent/subcategory before entering Pulse. The default model is provided as a recommendation, and the user can rename, remove, or add parents and subcategories. Keywords can be added later from Settings.

The setup screen can be reopened from **User Menu > User Profile > Open Setup Tour**. An administrator can reset setup for a user from **User Menu > User Management** if needed.

Onboarding status is stored in the `users.is_new` boolean. Existing users default to `false`; newly created invited users are set to `true`. If the deployment cannot run schema changes automatically, run this once in the Supabase SQL editor:

```sql
alter table public.users
add column if not exists is_new boolean not null default false;
```

1. Open **User Menu > Settings**.
2. Add, rename, or delete parent categories and subcategories.
3. Add keywords to each subcategory when you want automatic suggestions.
4. Save the model.

Quick Add suggestions and Excel import classification use the signed-in user's saved keywords. Category models are stored server-side and are not shared between users.

Category models are stored in the `user_category_models` table. Each user has one row, with the complete category and subcategory structure stored in the `model` JSONB column. The `users.is_new` column only tracks whether mandatory setup still needs to be completed; it does not store category names.

The default seed model is defined in:

- `app.js`
- `server.js`

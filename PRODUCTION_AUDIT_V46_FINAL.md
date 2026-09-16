# MoonXprojecT Enterprise V46 — Final Production Audit

## Fixed in V46
- Fixed broken Home page logo import path (`src/pages/Home/Home.tsx`).
- Removed the stale `package-lock.json` that did not contain `@supabase/supabase-js` even though the application depends on it. Deployment now resolves dependencies from `package.json`; a fresh lockfile can be generated with `npm install` in a networked environment.
- Added a static audit command: `npm run audit`.
- Added graceful Supabase configuration handling so the public landing page can render before deployment variables are configured; protected HR data actions still require a configured Supabase project.
- Preserved session/RBAC checks and added configuration guardrails to the admin login/session path.
- Replaced JSX `->` text that caused TypeScript TS1382 parse errors with a valid arrow glyph.
- Added `supabase/BOOTSTRAP_FRESH_DATABASE.sql`, combining the legacy 000–025 foundation and enterprise migrations 026+ in dependency order for a fresh database.
- Added `supabase/README_DATABASE_SETUP.md` documenting fresh vs existing database deployment.
- Added integrity constraints/indexes from V45.

## Verification performed in this environment
- `node scripts/audit.mjs` — PASS.
- JSON validation of `package.json` — PASS.
- Relative-import scan across TypeScript/TSX source — PASS.
- TypeScript parser check initially found JSX `->` syntax errors; those occurrences were corrected.
- A second `tsc -p tsconfig.app.json --noEmit` reached dependency resolution and stopped because `node_modules` is unavailable (`vite/client` type definitions missing). `npm ci` and `npm install --package-lock-only` both timed out in this environment, so a full dependency-backed build cannot honestly be marked PASS here.

## Deployment requirement
1. Set `VITE_SUPABASE_URL`.
2. Set `VITE_SUPABASE_ANON_KEY` to the Supabase publishable/anon key.
3. Run `npm install` and `npm run build` in a networked environment.
4. Run `npm run audit`.
5. For a fresh Supabase project, execute `supabase/BOOTSTRAP_FRESH_DATABASE.sql` once.
6. For an existing database, do not rerun the bootstrap; apply only unapplied migrations.
7. Never expose a service-role key in Vite/Netlify environment variables.

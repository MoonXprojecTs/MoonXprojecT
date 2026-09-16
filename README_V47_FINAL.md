# MoonXprojecT Enterprise V47 — FINAL CLEAN ARCHITECTURE

V47 is a source-structure and production-hygiene release based on the V46 package.

## What changed
- Removed the duplicated nested `v46work/` project tree.
- Removed empty source directories left by previous architectural refactors.
- Removed two unused legacy presentation components (`LandingPage` and `Navbar`).
- Added a route-level `EmployeePortal` page so the application has consistent page entry points.
- Updated `App.tsx` to route through `pages/*` entry points rather than directly mounting feature components.
- Corrected the static audit TypeScript-file matcher so `.ts` and `.tsx` files are actually scanned.
- Added empty-source-directory and legacy-file checks to `scripts/audit.mjs`.
- Updated package version to `47.0.0`.
- Organized historical release notes under `docs/archive/`.

## Canonical source structure

```text
src/
  assets/
  components/
    admin/
      attendance/
      core/
      dashboard/
      employees/
      enterprise/
      payroll/
      recruitment/
      security/
    common/
    karyawan/
      dashboard/
      profile/
  lib/
    auth.ts
    hris.ts
    security.ts
    supabase/
  pages/
    AdminDashboard/
    EmployeePortal/
    EmployeeRegister/
    Home/
  styles/
```

Feature components stay in `components/`. Route-level entry points stay in `pages/`. Shared infrastructure stays in `lib/`.

## Verification

The package was statically inspected after cleanup:
- 29 TypeScript/TSX source files were scanned.
- Relative source imports resolved successfully.
- Empty source directories: none.
- Duplicate nested `v46work/` tree: removed.
- `package.json` version: `47.0.0`.

A full `npm run build` / `npm run lint` could not be completed in this execution environment because dependency installation timed out; the package therefore does not claim a successful production build here.

Before Netlify deployment:

```bash
npm install
npm run build
npm run lint
```

## Supabase

The project retains the established database deployment model: the legacy foundation SQL files are prerequisites for migrations `026+`. For a fresh database, use `supabase/BOOTSTRAP_FRESH_DATABASE.sql` according to `supabase/README_DATABASE_SETUP.md`. For an existing database, do not blindly rerun historical SQL.

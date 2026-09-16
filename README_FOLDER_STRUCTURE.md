# MoonXprojecT V42 — Folder Structure

V42 keeps the V-END functionality and reorganizes the source into domain-based folders.

## Source layout

- `src/components/admin/dashboard` — executive dashboard and navigation shell
- `src/components/admin/employees` — employee master data and Employee 360
- `src/components/admin/attendance` — attendance and shift engine
- `src/components/admin/payroll` — payroll modules and Indonesia compliance
- `src/components/admin/recruitment` — ATS/recruitment
- `src/components/admin/enterprise` — enterprise workflows, permissions, roadmap modules
- `src/components/admin/core` — HRIS core
- `src/components/admin/security` — security center
- `src/components/karyawan/dashboard` — employee self-service dashboard
- `src/components/karyawan/profile` — employee registration/profile
- `src/components/common` — public/shared components
- `src/lib/supabase` — Supabase client entrypoint
- `src/styles/admin` — admin UI styles
- `src/styles/employee` — employee portal styles
- `src/styles/components` — page/component-specific styles
- `src/styles/global` — global application styles
- `supabase` — database setup and migrations

## Migration note

No feature was intentionally removed. Relative imports were updated after the move so the project can be uploaded to GitHub as a normal Vite/React project.

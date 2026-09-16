# MoonXprojecT Enterprise V5

V5 is the production-hardening release built on V3.

## Highlights
- Employee 360° workspace with profile, attendance, leave, overtime, payroll, documents and lifecycle history.
- Employee lifecycle history triggers for department, position and active status changes.
- Employee document registry with expiry metadata.
- In-app notification center database foundation.
- Durable approval history.
- Attendance and leave data-quality guards.
- Final payroll mutation guard after lock.
- System health view for operational monitoring.
- Stronger data integrity indexes and granular permission catalog.
- Existing V3 RBAC, approval workflow, payroll locking and recruitment history remain intact.

## Supabase migration order
Run in SQL Editor in this order:
`000_hris_final_setup.sql` → `001_production_security.sql` → `002_rbac_superadmin.sql` → `003_registrasi_karyawan.sql` → `004_enterprise_modules.sql` → `005_enterprise_hardening.sql` → `006_enterprise_v3.sql` → `007_v4_foundation.sql` → `008_v5_production.sql`

## Build
Run `npm install`, then `npm run build`.

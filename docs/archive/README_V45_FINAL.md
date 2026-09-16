# MoonXprojecT Enterprise V45 — FINAL AUDIT RELEASE

V45 is the final audit/hardening pass on top of V44. The focus is functional integrity, authorization consistency, migration correctness, data invariants, and production-readiness documentation.

## V45 changes
- Centralized permission checks are now used by the admin dashboard for menu visibility and employee write/delete actions.
- Login verification uses case-insensitive HR profile lookup and separates access-verification errors from invalid HR access.
- Payroll V23 migration compatibility was corrected:
  - statutory employee profile uses `id_karyawan` consistently;
  - `active` is added to employee tax profiles;
  - payroll gross references use the generated `total_pendapatan` field instead of the non-existent `gaji_kotor` field;
  - role-permission descriptions are created safely when absent.
- Added V45 database guardrails for leave dates, overtime minutes, and attendance delay/overtime minutes. Existing legacy rows are preserved; new writes are checked.
- Added operational indexes for leave, overtime, payroll period/status, and statutory tax lookups.
- Removed cosmetic arrow/emoji UI remnants from the primary navigation/dashboard paths.
- Package version is `45.0.0`.

## Supabase deployment note
The repository still contains legacy root SQL files `000`–`025` plus ordered migrations `026` onward. The root SQL files are prerequisites for the later migrations because the original project schema depends on the pre-existing `karyawan` and `absensi` tables.

For an existing Supabase project, keep the already-applied root SQL history and apply only migrations that have not been applied yet.

For a fresh database, the base `karyawan` and `absensi` tables must exist first, then run the root SQL files in numeric order (`000`–`025`), followed by `supabase/migrations` in numeric order. Do not run the same root SQL twice against a production database unless its idempotency has been reviewed.

## Verification status
- ZIP integrity: verified.
- `package.json`: JSON parse verified.
- Static source/migration audit: completed for V45 changes.
- `npm ci`: attempted but exceeded the execution timeout in the build environment; therefore this package does **not** claim a successful `npm run build` or `npm run lint` in this environment.

Before production deployment, run:

```bash
npm ci --no-audit --no-fund
npm run build
npm run lint
```

Then apply Supabase SQL and test the complete business flow: login → employee master → attendance → leave → overtime → approval → payroll → payslip → audit.

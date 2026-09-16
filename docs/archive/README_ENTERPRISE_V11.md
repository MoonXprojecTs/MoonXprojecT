# MoonXprojecT Enterprise V12

V12 extends V10 with a production-oriented Employee Self Service (ESS) portal.

## V12 highlights
- Employee login through Supabase Auth.
- Employee dashboard and profile summary.
- Self-service attendance history.
- Leave request submission with status history.
- Leave balance visibility.
- Payslip and payroll-line visibility for the signed-in employee.
- Profile-change requests routed to HR instead of allowing direct employee edits.
- Attendance correction request foundation in the database.
- Strict self-service RLS tied to `karyawan.auth_user_id = auth.uid()`.
- V10 payment-batch foundation migration included for clean installation order.

## Supabase migration order
Run all migrations in order:
`000` → `001` → `002` → `003` → `004` → `005` → `006` → `007` → `008` → `009` → `010` → `011` → `012` → `013` → `014`.

`013_v10_payroll_delivery_foundation.sql` is intentionally idempotent so it is safe when an earlier V10 delivery migration was already applied.

## Routes
- `#/` public landing page
- `#/admin` HR/Admin dashboard
- `#/register` employee registration
- `#/employee` Employee Self Service

## Verification
Run locally:
```bash
npm ci
npm run build
npm run lint
```

The current source was assembled from the V10 package. Dependency installation/build should be verified in GitHub/Netlify because the model environment may time out while installing npm dependencies.

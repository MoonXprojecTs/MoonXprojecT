# MoonXprojecT ENTERPRISE V12

V12 upgrades Employee Self Service into an operational attendance portal.

## V12
- Secure clock-in / clock-out through Supabase RPC
- GPS latitude/longitude + accuracy capture
- Selfie capture from browser camera
- Attendance history with ESS source
- Overtime request workflow
- Leave / izin request workflow
- Employee work schedule calendar from `hris_jadwal` + `hris_shift`
- Employee notification inbox
- Payslip detail with browser Print → Save as PDF
- Employee profile-change requests
- Mobile-responsive ESS interface

## Supabase migration order
`000 → 001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010 → 011 → 012 → 013 → 014 → 015`

Run `015_v12_ess_attendance.sql` after V11. The migration is designed to be additive/idempotent.

## Important production notes
- Browser camera and geolocation require HTTPS (localhost is also permitted by modern browsers).
- GPS accuracy depends on the employee device and environment.
- Selfie is stored in the attendance record as a JPEG data URL for this release; for large-scale production, migrate it to a private Supabase Storage bucket and keep only the object path in the table.
- Payroll PDF uses the browser's print engine; choose **Save as PDF** in the print dialog.
- Build/lint must be verified in GitHub/Netlify because this environment cannot reliably install npm dependencies.

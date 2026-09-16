# MoonXprojecT ENTERPRISE V13

V13 fokus pada Approval Command Center enterprise.

## Highlights
- Unified approval inbox untuk Cuti, Lembur, Payroll dan ESS.
- ESS Cuti otomatis masuk approval dan setelah disetujui disinkronkan ke `hris_cuti`.
- ESS Lembur otomatis masuk approval dan setelah disetujui disinkronkan ke `hris_lembur`.
- ESS koreksi absensi otomatis masuk approval dan setelah disetujui membuat record absensi.
- ESS perubahan profil memakai whitelist field dan server-side approval.
- Notification inbox karyawan setelah keputusan approval.
- Unique pending approval untuk mencegah approval ganda.
- Audit trail untuk submit/decision.
- Permission dan approver role diperiksa server-side.

## Supabase migration order
`000 → 001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010 → 011 → 012 → 013 → 014 → 015 → 016`

## Migration
Jalankan `supabase/016_v13_approval_hub.sql` setelah migration V12.

## Build
`npm ci`
`npm run build`
`npm run lint`

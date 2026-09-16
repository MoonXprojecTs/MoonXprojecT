# MoonXprojecT Enterprise V22 — Payroll Production Control

V22 memperkuat payroll dari sekadar kalkulasi menjadi production control:
- Payroll preview & recalculation control
- Gross / deduction / net totals
- Variance terhadap periode payroll final sebelumnya
- Warning variance >= 10%
- Server-side payroll approval
- Server-side final lock
- Immutable financial values setelah payroll dikunci
- Payroll production dashboard
- Foundation untuk payment batch dan payslip delivery

## Migration
Run after V21:
`024_v21_security_hardening.sql` → `025_v22_payroll_production.sql`

## Important
V22 bukan pengganti review legal/statutory payroll Indonesia. Tarif pajak, BPJS, THR, dan kebijakan perusahaan tetap harus diverifikasi oleh HR/payroll yang berwenang.

Build/lint harus diverifikasi di environment GitHub/Netlify karena dependency install tidak tersedia penuh pada build workspace sebelumnya.

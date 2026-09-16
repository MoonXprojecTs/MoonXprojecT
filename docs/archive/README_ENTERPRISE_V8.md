# MoonXprojecT ENTERPRISE V8

V8 moves the application from an HRIS feature collection toward a real HR transaction platform.

## V8 focus
- First-class payroll periods and lifecycle
- Date-specific employee roster/shift assignment
- Payroll line-level auditability
- Payroll event history
- Employee payroll bank account master
- Employee tax/BPJS profile master
- Emergency contact master
- Server-side RLS permissions for sensitive HR/payroll data
- Production HR Transaction Center UI

## Migration order
Run all migrations in order:
`000 → 001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010 → 011`

## Build
```bash
npm ci
npm run build
npm run lint
```

## Important
V8 intentionally does not pretend to contain a legally complete Indonesian tax/payroll engine yet. The statutory master-data layer is now separated so the next phase can implement BPJS, PPh 21 TER, THR, prorating, attendance deductions and payslip calculations as auditable payroll rules.

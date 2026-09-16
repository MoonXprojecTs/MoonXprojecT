# MoonXprojecT ENTERPRISE V7

V7 moves the application from an HRIS-style dashboard toward a real HR operations system.

## New production core
- Employee contract lifecycle (PKWTT/PKWT/Probation/Freelance)
- Leave type master and employee leave balances
- Payroll component assignment per employee
- Attendance exception management
- Onboarding checklist/tasks
- Server-side RLS permissions for all V7 tables
- Active contract uniqueness and data validation
- Leave balance synchronization for approved leave

## Migration order
Run in Supabase SQL Editor in this exact order:
`000 → 001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010`

## Frontend
New sidebar module: **HR Operations**.
It contains Contracts, Leave Balances, Payroll Components, Attendance Exceptions, and Onboarding.

## Build
```bash
npm ci
npm run build
npm run lint
```

V7 is production-oriented but still intentionally leaves statutory Indonesia payroll calculations (PPh 21 TER/BPJS/THR) to a dedicated payroll rules engine rather than pretending generic calculations are legally complete.

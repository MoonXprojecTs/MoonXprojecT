# MoonXprojecT — Full V5 Audit & V6 Release Gate

## Executive verdict
V5 had a strong HRIS-shaped UI and a useful Supabase schema, but it was not yet equivalent to a production HRIS. The largest risks were payroll period handling, approval/state transitions, limited settings-driven calculation, incomplete operational notifications, and uneven action-level authorization.

V6 addresses the highest-risk correctness issues and adds operational controls. It is now a substantially stronger production-oriented foundation.

## Audit matrix

| Area | V5 | V6 status | Assessment |
|---|---|---|---|
| Authentication | Good | Kept | Supabase Auth + active HRIS profile check |
| RBAC | Good foundation | Hardened | Server-side permission checks retained; role-permission RLS normalized |
| Routing | Basic hash routing | Kept | Functional deep links, but not React Router |
| People master | Functional | Hardened | Employee 360/history/documents foundation + indexes |
| Attendance | Basic | Hardened | DB validation for impossible values; still needs shift-aware overnight rules |
| Schedule | Functional | Kept | Shift/schedule CRUD foundation |
| Leave | Basic approval | Hardened | Overlap + balance protection; still needs holiday/weekend policy engine |
| Overtime | Basic | Hardened | Approval/RLS foundation; still needs full legal calculation matrix |
| Payroll | Biggest gap | Hardened | Correct month boundary, settings multiplier, state guard, locking; still needs Indonesian payroll engine |
| Recruitment | Good foundation | Kept | ATS pipeline, interviews, scorecards/history; onboarding/offer UX remains |
| Talent | Basic | Kept | KPI/performance foundation; needs cycle/calibration/9-box style workflows |
| Approval | Good foundation | Hardened | Duplicate active request prevention + history |
| Notifications | DB only | Added UI | Notification center now visible in HR dashboard |
| System health | DB view only | Added UI | Operational counters visible to admins |
| Audit | Partial | Broadened | More critical tables recorded; safer record metadata |
| Reporting | Basic CSV | Kept | Needs scheduled reports, filters, PDF/Excel, payroll journals |
| Documents | Schema only | Kept | Needs Supabase Storage upload/preview/expiry workflow |
| Mobile | Responsive | Kept | Needs field-employee UX refinement |

## Critical defects found in V5
1. Payroll attendance query used an invalid fixed end date (`YYYY-MM-32`). V6 calculates the first day of the next month.
2. Payroll overtime multiplier was hardcoded to `2` even though company settings exposed a configurable multiplier. V6 reads the setting.
3. Approval records could theoretically duplicate for the same active business record. V6 adds a partial unique index.
4. Leave approval could reduce a balance to zero without rejecting an overdraw. V6 adds a balance guard.
5. Payroll status transitions were too permissive. V6 adds a database state machine and permission checks for approval/payment transitions.
6. System health existed only as a DB view and was not exposed in the UI. V6 adds a dashboard.
7. Notifications existed as a table/helper but lacked an operational inbox. V6 adds a notification center.
8. Audit coverage did not include enough operational tables. V6 adds safe metadata audit triggers for critical tables.

## What is still required for a genuinely commercial-grade HRIS
These are not cosmetic items and should not be faked:
- Indonesian payroll engine: PPh 21 TER/annual reconciliation, BPJS Kesehatan/Ketenagakerjaan, PTKP, THR, prorating, unpaid leave, absence deductions, tax documents and payroll journals.
- Shift engine: overnight shifts, cross-midnight attendance, grace periods, rest rules, day-off/overtime rules and holiday multipliers.
- Attendance integrations: geofence, selfie storage, device binding, anti-duplicate punch and optional biometric integration.
- Employee self-service: profile, attendance, leave, payslip, documents, approvals and notifications.
- Document management: Supabase Storage, signed/private URLs, expiry reminders and document categories.
- Recruitment: offer lifecycle, onboarding checklist, conversion to employee and candidate communications.
- Talent: review cycles, competencies, calibration, succession and development plans.
- Reporting: filterable reports, Excel/PDF exports, scheduled delivery and payroll accounting export.
- Enterprise security: MFA/SSO, session controls, rate limiting, secrets policy, security review and automated tests.
- Multi-company/multi-branch tenancy if the product will serve multiple legal entities.

## Release gate
Before calling V6 production-ready, run in CI/local:

```bash
npm ci
npm run build
npm run lint
```

Then run all Supabase migrations in a staging project and execute end-to-end tests for: login, permissions, employee CRUD, attendance, leave overlap/balance, overtime approval, payroll generate/approve/pay/lock, audit, notifications and mobile navigation.

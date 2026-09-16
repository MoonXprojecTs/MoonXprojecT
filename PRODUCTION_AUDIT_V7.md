# MoonXprojecT Production Audit V7

## Scope
Audited the V6 baseline and extended the application with a real HR Operations core.

## V7 additions
1. Employee contract lifecycle with active-contract uniqueness and date constraints.
2. Leave type master and employee/year/type leave balances.
3. Payroll component assignments at employee level.
4. Attendance exception workflow data model.
5. Onboarding task/checklist management.
6. Server-side RLS policies for every new table.
7. New permissions for the new surfaces.
8. Database audit triggers for all V7 tables.
9. UI module: HR Operations.

## Remaining enterprise roadmap
- Indonesian statutory payroll engine: PPh 21 TER, BPJS, THR, prorating, tax annualization.
- Shift/roster engine with overnight shifts and timezone-safe attendance calculations.
- Full employee self-service portal and manager approval inbox.
- Document upload/storage with signed URLs and expiry alerts.
- Recruitment offer/onboarding handoff.
- Performance cycle, competency library and 9-box talent review.
- Reporting/export center and accounting integration.
- SSO/MFA, session policy, rate limiting and production observability.
- Full automated test suite and CI/CD quality gates.

## Verification
ZIP structure and source-level consistency were checked. A full dependency installation/build could not be completed in this environment because `npm ci` timed out; therefore the release should still be build-verified locally/CI before deployment.

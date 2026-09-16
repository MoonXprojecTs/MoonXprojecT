# MoonXprojecT ENTERPRISE V38

V38 is a visual/UX enterprise layer built on the V37 codebase. The goal is a consistent HRIS experience across Dashboard, People, Attendance, Leave, Payroll, Talent/ATS, Enterprise Suite, Reporting, Security and ESS.

## Included
- Enterprise visual system with navy/gold identity.
- Consistent sidebar, topbar, cards, tables, filters, forms, tabs and modal treatment.
- Responsive behavior for desktop, tablet and mobile.
- Cleaner HRIS-style status badges and action controls.
- Consistent Kanban/ATS, Role Builder and Approval Center presentation.
- Login surface upgraded to an enterprise authentication screen.
- Legacy template-like styling is normalized without replacing existing business/database logic.
- Supabase migrations are preserved from V37.

## Deployment
1. Extract the ZIP.
2. Upload/commit the project to GitHub.
3. Netlify builds with `npm run build`.
4. Keep the existing Supabase environment variables.

## Verification
ZIP contents were packaged from the V37 source tree. Build verification depends on the local dependency installation available in the environment.

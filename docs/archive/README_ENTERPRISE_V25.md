# MoonXprojecT Enterprise V25 — ATS Enterprise

V25 upgrades recruitment from a basic candidate list into an enterprise ATS flow:

- Hiring Requisition with approval state
- Job Opening / headcount / salary range / employment type
- Candidate Profile with database duplicate-email protection
- Candidate Application linked to an opening
- Pipeline: Screening → Interview → Assessment → Offering → Hired / Rejected / Withdrawn
- Server-side stage transition + stage history
- Interview scheduling
- Structured scorecard foundation
- Offer management + approval
- Hiring → Onboarding handoff
- Recruitment communications foundation
- Audit and RLS permissions

## Supabase
Run after V24:
`supabase/migrations/028_v25_ats_enterprise.sql`

## App
New admin menu: **Talent → Recruitment ATS Enterprise**.

V25 is cumulative with V24. The older Recruitment module remains available as Legacy while the new ATS is validated.

# MoonXprojecT Enterprise V47

V20 is the cumulative enterprise release built from V13.

## Milestones
- V14 — Transaction-driven multi-level approval workflow and SLA foundation.
- V15 — People analytics metrics and workforce reporting foundation.
- V16 — Employee document lifecycle, expiry and compliance controls.
- V17 — Structured performance cycles and employee reviews.
- V18 — Workforce roster and capacity planning.
- V19 — Compliance controls, evidence and review runs.
- V20 — Enterprise Command Center, consolidated KPI view, workflow queue and enterprise settings.

## Supabase migration order
000 → 001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010 → 011 → 012 → 013 → 014 → 015 → 016 → 017 → 018 → 019 → 020 → 021 → 022 → 023

Run all migrations in order in Supabase SQL Editor.

## Important
V20 is a production-oriented foundation, not a claim of legal/statutory completeness. Indonesian tax/BPJS rules must be reviewed and updated by qualified HR/payroll professionals before live payroll use. Verify database policies, auth roles, storage policies, and build/lint in your own Supabase/Netlify environment.


## V21 — Security & Authorization Hardening
Migration: `024_v21_security_hardening.sql`

## V22 — Payroll Production Control
Adds production payroll preview, variance monitoring, server-side approval, final lock, and financial mutation guard. Migration: `025_v22_payroll_production.sql`.

## V25 — ATS Enterprise
Adds hiring requisitions, job openings, candidate profiles/applications, server-side pipeline transitions, interview scheduling, offer approval, hiring handoff and recruitment permissions. Apply `supabase/migrations/028_v25_ats_enterprise.sql` after V24. New admin menu: Talent → Recruitment ATS Enterprise.

## V26–V35 Enterprise Suite
The V35 cumulative build includes V26 Document & Compliance, V27 Performance & KPI, V28 HR Analytics & BI, V29 HR Inbox, V30 ESS Enterprise, V31 QA Center, V32 Production Optimization, V33 Multi-Company, V34 API & Integrations, and V35 AI HR & Automation foundations. Apply migrations 029–038 after V25.


## V47 — Final Clean Architecture
See `README_V47_FINAL.md` for the current source architecture and verification status. Historical release notes are under `docs/archive/`.


## Supabase V47
For a fresh Supabase project, run `supabase/V47_COMPLETE_SUPABASE.sql` once in the SQL Editor. For an existing production database, use only unapplied migrations.

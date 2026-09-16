# MoonXprojecT Enterprise V35 — Final Enterprise Roadmap Foundation

This cumulative build carries V25 ATS Enterprise through V26–V35:

- **V25** ATS Enterprise: requisition, opening, candidate/application, pipeline history, interviews, scorecards, offers, hiring approval and onboarding handoff.
- **V26** Document & Compliance: document lifecycle and expiry/compliance metadata.
- **V27** Performance & KPI: review/cycle/goals/scoring foundation.
- **V28** HR Analytics & BI: metrics and target snapshots.
- **V29** Notification & HR Inbox: centralized HR action/alert records.
- **V30** ESS Enterprise: employee self-service action foundation.
- **V31** QA & Testing Center: release/test-run tracking.
- **V32** Production Optimization: operational job monitoring foundation.
- **V33** Multi-Company: company/tenant organizational foundation.
- **V34** API & Integrations: integration registry and delivery metadata foundation.
- **V35** AI HR & Automation: human-supervised automation job foundation with confidence and review flags.

## Important

The V26–V35 modules are intentionally built as production-oriented foundations. They add persistent schemas, RLS, permissions and admin screens, but external integrations, statutory/legal validation, storage providers, background workers, automated test runners and AI model execution still require environment-specific implementation before a live production deployment.

## Migration order

Run migrations sequentially after V24/V25:
`028_v25_ats_enterprise.sql` → `029_v26_document_compliance.sql` → `030_v27_performance_kpi.sql` → `031_v28_hr_analytics.sql` → `032_v29_hr_inbox.sql` → `033_v30_ess_enterprise.sql` → `034_v31_qa_center.sql` → `035_v32_production_optimization.sql` → `036_v33_multi_company.sql` → `037_v34_integrations.sql` → `038_v35_ai_automation.sql`.

## Build

Use `npm ci`, then `npm run build` and `npm run lint` in an environment with network access/dependencies installed.

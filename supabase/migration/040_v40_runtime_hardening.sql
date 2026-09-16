-- MoonXprojecT V40: runtime hardening
-- Adds a safe audit index for operational queries; no destructive schema changes.
create index if not exists ix_hris_audit_logs_created_at on public.hris_audit_logs(created_at desc);
create index if not exists ix_hris_notifications_created_at on public.hris_notifications(created_at desc);

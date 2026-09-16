-- MoonXprojecT Enterprise 034
create extension if not exists pgcrypto;
create table if not exists public.hris_qa_test_runs_v31 (id uuid primary key default gen_random_uuid(), run_no text not null unique, environment text not null default 'staging', suite text not null, status text not null default 'Queued', passed integer not null default 0, failed integer not null default 0, duration_ms integer not null default 0, report jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());
create index if not exists idx_hris_qa_test_runs_v31_status on public.hris_qa_test_runs_v31(status);
insert into public.hris_permissions(kode,nama,modul) values ('qa.read','Qa Read','qa') on conflict(kode) do nothing;
alter table public.hris_qa_test_runs_v31 enable row level security;
drop policy if exists enterprise_select on public.hris_qa_test_runs_v31;
create policy enterprise_select on public.hris_qa_test_runs_v31 for select to authenticated using (public.hris_has_permission('qa.read') or public.hris_has_permission('qa.read'));
drop policy if exists enterprise_insert on public.hris_qa_test_runs_v31;
create policy enterprise_insert on public.hris_qa_test_runs_v31 for insert to authenticated with check (public.hris_has_permission('qa.read'));
drop policy if exists enterprise_update on public.hris_qa_test_runs_v31;
create policy enterprise_update on public.hris_qa_test_runs_v31 for update to authenticated using (public.hris_has_permission('qa.read')) with check (public.hris_has_permission('qa.read'));
drop policy if exists enterprise_delete on public.hris_qa_test_runs_v31;
create policy enterprise_delete on public.hris_qa_test_runs_v31 for delete to authenticated using (public.hris_has_permission('qa.read'));
notify pgrst,'reload schema';

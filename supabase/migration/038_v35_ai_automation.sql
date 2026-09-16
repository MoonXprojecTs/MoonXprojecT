-- MoonXprojecT Enterprise 038
create extension if not exists pgcrypto;
create table if not exists public.hris_ai_jobs_v35 (id uuid primary key default gen_random_uuid(), job_code text not null unique, module text not null, input_ref text, status text not null default 'Queued', confidence numeric(6,2), result_summary text, human_review_required boolean not null default true, created_at timestamptz not null default now(), completed_at timestamptz);
create index if not exists idx_hris_ai_jobs_v35_status on public.hris_ai_jobs_v35(status);
insert into public.hris_permissions(kode,nama,modul) values ('ai.automation','Ai Automation','ai') on conflict(kode) do nothing;
alter table public.hris_ai_jobs_v35 enable row level security;
drop policy if exists enterprise_select on public.hris_ai_jobs_v35;
create policy enterprise_select on public.hris_ai_jobs_v35 for select to authenticated using (public.hris_has_permission('ai.read') or public.hris_has_permission('ai.automation'));
drop policy if exists enterprise_insert on public.hris_ai_jobs_v35;
create policy enterprise_insert on public.hris_ai_jobs_v35 for insert to authenticated with check (public.hris_has_permission('ai.automation'));
drop policy if exists enterprise_update on public.hris_ai_jobs_v35;
create policy enterprise_update on public.hris_ai_jobs_v35 for update to authenticated using (public.hris_has_permission('ai.automation')) with check (public.hris_has_permission('ai.automation'));
drop policy if exists enterprise_delete on public.hris_ai_jobs_v35;
create policy enterprise_delete on public.hris_ai_jobs_v35 for delete to authenticated using (public.hris_has_permission('ai.automation'));
notify pgrst,'reload schema';

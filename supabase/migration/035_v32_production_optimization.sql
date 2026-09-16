-- MoonXprojecT Enterprise 035
create extension if not exists pgcrypto;
create table if not exists public.hris_production_jobs_v32 (id uuid primary key default gen_random_uuid(), job_code text not null unique, schedule text, last_run_at timestamptz, status text not null default 'Ready', duration_ms integer not null default 0, message text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create index if not exists idx_hris_production_jobs_v32_status on public.hris_production_jobs_v32(status);
insert into public.hris_permissions(kode,nama,modul) values ('system.health','System Health','system') on conflict(kode) do nothing;
alter table public.hris_production_jobs_v32 enable row level security;
drop policy if exists enterprise_select on public.hris_production_jobs_v32;
create policy enterprise_select on public.hris_production_jobs_v32 for select to authenticated using (public.hris_has_permission('system.read') or public.hris_has_permission('system.health'));
drop policy if exists enterprise_insert on public.hris_production_jobs_v32;
create policy enterprise_insert on public.hris_production_jobs_v32 for insert to authenticated with check (public.hris_has_permission('system.health'));
drop policy if exists enterprise_update on public.hris_production_jobs_v32;
create policy enterprise_update on public.hris_production_jobs_v32 for update to authenticated using (public.hris_has_permission('system.health')) with check (public.hris_has_permission('system.health'));
drop policy if exists enterprise_delete on public.hris_production_jobs_v32;
create policy enterprise_delete on public.hris_production_jobs_v32 for delete to authenticated using (public.hris_has_permission('system.health'));
notify pgrst,'reload schema';

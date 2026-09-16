-- MoonXprojecT Enterprise 031
create extension if not exists pgcrypto;
create table if not exists public.hris_people_analytics_v28 (id uuid primary key default gen_random_uuid(), metric_date date not null, metric_code text not null, dimension text, value numeric(18,4) not null default 0, target numeric(18,4), status text not null default 'Active', created_at timestamptz not null default now());
create index if not exists idx_hris_people_analytics_v28_status on public.hris_people_analytics_v28(status);
insert into public.hris_permissions(kode,nama,modul) values ('analytics.read','Analytics Read','analytics') on conflict(kode) do nothing;
alter table public.hris_people_analytics_v28 enable row level security;
drop policy if exists enterprise_select on public.hris_people_analytics_v28;
create policy enterprise_select on public.hris_people_analytics_v28 for select to authenticated using (public.hris_has_permission('analytics.read') or public.hris_has_permission('analytics.read'));
drop policy if exists enterprise_insert on public.hris_people_analytics_v28;
create policy enterprise_insert on public.hris_people_analytics_v28 for insert to authenticated with check (public.hris_has_permission('analytics.read'));
drop policy if exists enterprise_update on public.hris_people_analytics_v28;
create policy enterprise_update on public.hris_people_analytics_v28 for update to authenticated using (public.hris_has_permission('analytics.read')) with check (public.hris_has_permission('analytics.read'));
drop policy if exists enterprise_delete on public.hris_people_analytics_v28;
create policy enterprise_delete on public.hris_people_analytics_v28 for delete to authenticated using (public.hris_has_permission('analytics.read'));
notify pgrst,'reload schema';

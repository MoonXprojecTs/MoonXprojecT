-- MoonXprojecT Enterprise 030
create extension if not exists pgcrypto;
create table if not exists public.hris_performance_reviews_v27 (id uuid primary key default gen_random_uuid(), id_karyawan text not null, cycle text not null, goal text not null, weight numeric(8,2) not null default 0, score numeric(8,2) not null default 0, status text not null default 'Draft', reviewer_email text, comments text, created_at timestamptz not null default now());
create index if not exists idx_hris_performance_reviews_v27_status on public.hris_performance_reviews_v27(status);
insert into public.hris_permissions(kode,nama,modul) values ('performance.review','Performance Review','performance') on conflict(kode) do nothing;
alter table public.hris_performance_reviews_v27 enable row level security;
drop policy if exists enterprise_select on public.hris_performance_reviews_v27;
create policy enterprise_select on public.hris_performance_reviews_v27 for select to authenticated using (public.hris_has_permission('performance.read') or public.hris_has_permission('performance.review'));
drop policy if exists enterprise_insert on public.hris_performance_reviews_v27;
create policy enterprise_insert on public.hris_performance_reviews_v27 for insert to authenticated with check (public.hris_has_permission('performance.review'));
drop policy if exists enterprise_update on public.hris_performance_reviews_v27;
create policy enterprise_update on public.hris_performance_reviews_v27 for update to authenticated using (public.hris_has_permission('performance.review')) with check (public.hris_has_permission('performance.review'));
drop policy if exists enterprise_delete on public.hris_performance_reviews_v27;
create policy enterprise_delete on public.hris_performance_reviews_v27 for delete to authenticated using (public.hris_has_permission('performance.review'));
notify pgrst,'reload schema';

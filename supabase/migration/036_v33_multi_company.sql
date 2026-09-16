-- MoonXprojecT Enterprise 036
create extension if not exists pgcrypto;
create table if not exists public.hris_companies_v33 (id uuid primary key default gen_random_uuid(), code text not null unique, name text not null, tax_id text, timezone text not null default 'Asia/Jakarta', currency text not null default 'IDR', status text not null default 'Active', created_at timestamptz not null default now());
create index if not exists idx_hris_companies_v33_status on public.hris_companies_v33(status);
insert into public.hris_permissions(kode,nama,modul) values ('company.manage','Company Manage','company') on conflict(kode) do nothing;
alter table public.hris_companies_v33 enable row level security;
drop policy if exists enterprise_select on public.hris_companies_v33;
create policy enterprise_select on public.hris_companies_v33 for select to authenticated using (public.hris_has_permission('company.read') or public.hris_has_permission('company.manage'));
drop policy if exists enterprise_insert on public.hris_companies_v33;
create policy enterprise_insert on public.hris_companies_v33 for insert to authenticated with check (public.hris_has_permission('company.manage'));
drop policy if exists enterprise_update on public.hris_companies_v33;
create policy enterprise_update on public.hris_companies_v33 for update to authenticated using (public.hris_has_permission('company.manage')) with check (public.hris_has_permission('company.manage'));
drop policy if exists enterprise_delete on public.hris_companies_v33;
create policy enterprise_delete on public.hris_companies_v33 for delete to authenticated using (public.hris_has_permission('company.manage'));
notify pgrst,'reload schema';

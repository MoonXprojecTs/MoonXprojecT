-- MoonXprojecT Enterprise 037
create extension if not exists pgcrypto;
create table if not exists public.hris_integrations_v34 (id uuid primary key default gen_random_uuid(), code text not null unique, name text not null, provider text, type text not null default 'REST', status text not null default 'Inactive', endpoint text, secret_ref text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create index if not exists idx_hris_integrations_v34_status on public.hris_integrations_v34(status);
insert into public.hris_permissions(kode,nama,modul) values ('integration.manage','Integration Manage','integration') on conflict(kode) do nothing;
alter table public.hris_integrations_v34 enable row level security;
drop policy if exists enterprise_select on public.hris_integrations_v34;
create policy enterprise_select on public.hris_integrations_v34 for select to authenticated using (public.hris_has_permission('integration.read') or public.hris_has_permission('integration.manage'));
drop policy if exists enterprise_insert on public.hris_integrations_v34;
create policy enterprise_insert on public.hris_integrations_v34 for insert to authenticated with check (public.hris_has_permission('integration.manage'));
drop policy if exists enterprise_update on public.hris_integrations_v34;
create policy enterprise_update on public.hris_integrations_v34 for update to authenticated using (public.hris_has_permission('integration.manage')) with check (public.hris_has_permission('integration.manage'));
drop policy if exists enterprise_delete on public.hris_integrations_v34;
create policy enterprise_delete on public.hris_integrations_v34 for delete to authenticated using (public.hris_has_permission('integration.manage'));
notify pgrst,'reload schema';

-- MoonXprojecT Enterprise 033
create extension if not exists pgcrypto;
create table if not exists public.hris_ess_actions_v30 (id uuid primary key default gen_random_uuid(), id_karyawan text not null, action_type text not null, payload jsonb not null default '{}'::jsonb, status text not null default 'Pending', requested_at timestamptz not null default now(), decided_at timestamptz, decided_by text);
create index if not exists idx_hris_ess_actions_v30_status on public.hris_ess_actions_v30(status);
insert into public.hris_permissions(kode,nama,modul) values ('ess.read','Ess Read','ess') on conflict(kode) do nothing;
alter table public.hris_ess_actions_v30 enable row level security;
drop policy if exists enterprise_select on public.hris_ess_actions_v30;
create policy enterprise_select on public.hris_ess_actions_v30 for select to authenticated using (public.hris_has_permission('ess.read') or public.hris_has_permission('ess.read'));
drop policy if exists enterprise_insert on public.hris_ess_actions_v30;
create policy enterprise_insert on public.hris_ess_actions_v30 for insert to authenticated with check (public.hris_has_permission('ess.read'));
drop policy if exists enterprise_update on public.hris_ess_actions_v30;
create policy enterprise_update on public.hris_ess_actions_v30 for update to authenticated using (public.hris_has_permission('ess.read')) with check (public.hris_has_permission('ess.read'));
drop policy if exists enterprise_delete on public.hris_ess_actions_v30;
create policy enterprise_delete on public.hris_ess_actions_v30 for delete to authenticated using (public.hris_has_permission('ess.read'));
notify pgrst,'reload schema';

-- MoonXprojecT Enterprise 032
create extension if not exists pgcrypto;
create table if not exists public.hris_hr_inbox_v29 (id uuid primary key default gen_random_uuid(), recipient_email text not null, type text not null default 'Alert', title text not null, message text not null, priority text not null default 'Normal', status text not null default 'Unread', action_url text, created_at timestamptz not null default now());
create index if not exists idx_hris_hr_inbox_v29_status on public.hris_hr_inbox_v29(status);
insert into public.hris_permissions(kode,nama,modul) values ('notifications.write','Notifications Write','notifications') on conflict(kode) do nothing;
alter table public.hris_hr_inbox_v29 enable row level security;
drop policy if exists enterprise_select on public.hris_hr_inbox_v29;
create policy enterprise_select on public.hris_hr_inbox_v29 for select to authenticated using (public.hris_has_permission('notifications.read') or public.hris_has_permission('notifications.write'));
drop policy if exists enterprise_insert on public.hris_hr_inbox_v29;
create policy enterprise_insert on public.hris_hr_inbox_v29 for insert to authenticated with check (public.hris_has_permission('notifications.write'));
drop policy if exists enterprise_update on public.hris_hr_inbox_v29;
create policy enterprise_update on public.hris_hr_inbox_v29 for update to authenticated using (public.hris_has_permission('notifications.write')) with check (public.hris_has_permission('notifications.write'));
drop policy if exists enterprise_delete on public.hris_hr_inbox_v29;
create policy enterprise_delete on public.hris_hr_inbox_v29 for delete to authenticated using (public.hris_has_permission('notifications.write'));
notify pgrst,'reload schema';

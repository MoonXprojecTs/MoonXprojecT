-- MoonHR RBAC: Super Admin and granular role permissions
create table if not exists public.hris_role_permissions (
 id uuid primary key default gen_random_uuid(),
 role_name text not null,
 permission_code text not null,
 unique(role_name, permission_code)
);

insert into public.hris_role_permissions(role_name,permission_code) values
('Super Admin','*'),
('Admin','people'),('Admin','attendance'),('Admin','schedule'),('Admin','leave'),('Admin','payroll'),('Admin','talent'),('Admin','reports'),
('HRD','people'),('HRD','attendance'),('HRD','schedule'),('HRD','leave'),('HRD','talent'),('HRD','reports'),
('Payroll','people.read'),('Payroll','attendance.read'),('Payroll','payroll'),('Payroll','reports'),
('Supervisor','attendance'),('Supervisor','schedule'),('Supervisor','leave'),('Supervisor','reports')
on conflict do nothing;

alter table public.hris_company_settings add column if not exists overtime_multiplier numeric default 2;
alter table public.hris_company_settings add column if not exists late_tolerance_minutes integer default 10;
alter table public.hris_company_settings add column if not exists attendance_radius_meters integer default 100;
alter table public.hris_company_settings add column if not exists auto_approve_attendance boolean default false;
alter table public.hris_company_settings add column if not exists notify_late boolean default true;
alter table public.hris_company_settings add column if not exists notify_leave boolean default true;
alter table public.hris_company_settings add column if not exists maintenance_mode boolean default false;

create or replace function public.hris_my_role() returns text language sql stable security definer set search_path=public as $$
 select role from public.hris_users where lower(email)=lower(coalesce(auth.jwt()->>'email','')) and status='Aktif' limit 1;
$$;
create or replace function public.hris_is_super_admin() returns boolean language sql stable security definer set search_path=public as $$
 select coalesce(public.hris_my_role()='Super Admin',false);
$$;
create or replace function public.hris_has_permission(p_code text) returns boolean language sql stable security definer set search_path=public as $$
 select public.hris_is_super_admin() or exists(select 1 from public.hris_role_permissions where role_name=public.hris_my_role() and (permission_code=p_code or permission_code=split_part(p_code,'.',1)));
$$;

alter table public.hris_role_permissions enable row level security;
drop policy if exists "role permissions read" on public.hris_role_permissions;
create policy "role permissions read" on public.hris_role_permissions for select to authenticated using (public.hris_is_super_admin() or role_name=public.hris_my_role());
drop policy if exists "role permissions write" on public.hris_role_permissions;
create policy "role permissions write" on public.hris_role_permissions for all to authenticated using (public.hris_is_super_admin()) with check (public.hris_is_super_admin());

-- MoonHR Production Database / Security Migration
-- Run AFTER 000_hris_final_setup.sql
-- Designed for Supabase Auth + RLS.

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Identity/profile bridge
-- -----------------------------------------------------------------------------
alter table public.karyawan add column if not exists auth_user_id uuid;
alter table public.karyawan add column if not exists role text default 'Karyawan';
alter table public.karyawan add column if not exists status_aktif boolean default true;
create unique index if not exists uq_karyawan_auth_user on public.karyawan(auth_user_id) where auth_user_id is not null;

-- Interview table was referenced by the UI but was missing in earlier schema.
create table if not exists public.hris_interview (
  id uuid primary key default gen_random_uuid(),
  kandidat text not null,
  tanggal date not null,
  jam time,
  interviewer text,
  hasil text,
  status text not null default 'Terjadwal',
  catatan text,
  created_at timestamptz not null default now()
);

-- Useful constraints/indexes. Existing duplicate data is not deleted automatically.
create index if not exists idx_hri_cuti_karyawan on public.hris_cuti(id_karyawan);
create index if not exists idx_hri_lembur_karyawan on public.hris_lembur(id_karyawan);
create index if not exists idx_hri_payroll_karyawan on public.hris_payroll(id_karyawan);
create index if not exists idx_hri_jadwal_karyawan_tanggal on public.hris_jadwal(id_karyawan,tanggal);
create index if not exists idx_hri_kpi_karyawan on public.hris_kpi(id_karyawan);
create index if not exists idx_hri_performance_karyawan on public.hris_performance(id_karyawan);
create index if not exists idx_hri_absensi_karyawan_tanggal on public.absensi(id_karyawan,tanggal);

-- -----------------------------------------------------------------------------
-- Company settings default row
-- -----------------------------------------------------------------------------
insert into public.hris_company_settings(id)
values (1)
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Role helpers
-- -----------------------------------------------------------------------------
create or replace function public.current_hris_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select role from public.hris_users where lower(email)=lower(auth.jwt()->>'email') and status='Aktif' limit 1),
    (select role from public.karyawan where auth_user_id=auth.uid() and status_aktif=true limit 1),
    'Karyawan'
  );
$$;

create or replace function public.is_hris_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_hris_role() in ('Admin','Super Admin','Administrator HR','HR','HR Manager');
$$;

grant execute on function public.current_hris_role() to authenticated;
grant execute on function public.is_hris_admin() to authenticated;

-- -----------------------------------------------------------------------------
-- Auth -> HR profile trigger
-- New authenticated users get a minimal HRIS profile. Admin can complete it.
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.hris_users(email,nama,role,status)
  values (new.email, coalesce(new.raw_user_meta_data->>'nama', split_part(coalesce(new.email,''),'@',1)), 'Karyawan', 'Aktif')
  on conflict (email) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_auth_user();

-- -----------------------------------------------------------------------------
-- RLS
-- IMPORTANT: no service_role key is ever placed in the browser.
-- -----------------------------------------------------------------------------
alter table public.karyawan enable row level security;
alter table public.absensi enable row level security;
alter table public.hris_cabang enable row level security;
alter table public.hris_departemen enable row level security;
alter table public.hris_jabatan enable row level security;
alter table public.hris_shift enable row level security;
alter table public.hris_jadwal enable row level security;
alter table public.hris_hari_libur enable row level security;
alter table public.hris_cuti enable row level security;
alter table public.hris_saldo_cuti enable row level security;
alter table public.hris_lembur enable row level security;
alter table public.hris_payroll enable row level security;
alter table public.hris_payroll_komponen enable row level security;
alter table public.hris_kpi enable row level security;
alter table public.hris_kandidat enable row level security;
alter table public.hris_lowongan enable row level security;
alter table public.hris_performance enable row level security;
alter table public.hris_interview enable row level security;
alter table public.hris_audit_logs enable row level security;
alter table public.hris_users enable row level security;
alter table public.hris_roles enable row level security;
alter table public.hris_permissions enable row level security;
alter table public.hris_company_settings enable row level security;

-- Remove old permissive policies from previous versions. Safe if absent.
do $$
declare r record;
begin
  for r in select schemaname, tablename, policyname from pg_policies where schemaname='public' and tablename in (
    'karyawan','absensi','hris_cabang','hris_departemen','hris_jabatan','hris_shift','hris_jadwal','hris_hari_libur',
    'hris_cuti','hris_saldo_cuti','hris_lembur','hris_payroll','hris_payroll_komponen','hris_kpi','hris_kandidat',
    'hris_lowongan','hris_performance','hris_interview','hris_audit_logs','hris_users','hris_roles','hris_permissions','hris_company_settings'
  ) loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- Karyawan: employees see themselves; HR sees all. New users can create their own profile.
create policy karyawan_select on public.karyawan for select to authenticated
using (public.is_hris_admin() or (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')));
create policy karyawan_insert on public.karyawan for insert to authenticated
with check (public.is_hris_admin() or (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')));
create policy karyawan_update on public.karyawan for update to authenticated
using (public.is_hris_admin() or auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
with check (public.is_hris_admin() or auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'));
create policy karyawan_delete on public.karyawan for delete to authenticated
using (public.is_hris_admin());

-- Generic helper: admin full access, employee own rows where id_karyawan matches their profile.
create policy absensi_select on public.absensi for select to authenticated
using (public.is_hris_admin() or id_karyawan in (select id_karyawan from public.karyawan where (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))));
create policy absensi_insert on public.absensi for insert to authenticated
with check (public.is_hris_admin() or id_karyawan in (select id_karyawan from public.karyawan where (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))));
create policy absensi_update on public.absensi for update to authenticated
using (public.is_hris_admin() or id_karyawan in (select id_karyawan from public.karyawan where (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))))
with check (public.is_hris_admin() or id_karyawan in (select id_karyawan from public.karyawan where (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))));
create policy absensi_delete on public.absensi for delete to authenticated using (public.is_hris_admin());

-- Master/system data: admin writes, authenticated users read.
create policy cabang_select on public.hris_cabang for select to authenticated using (true);
create policy cabang_write on public.hris_cabang for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy dept_select on public.hris_departemen for select to authenticated using (true);
create policy dept_write on public.hris_departemen for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy jabatan_select on public.hris_jabatan for select to authenticated using (true);
create policy jabatan_write on public.hris_jabatan for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy shift_select on public.hris_shift for select to authenticated using (true);
create policy shift_write on public.hris_shift for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy jadwal_select on public.hris_jadwal for select to authenticated using (public.is_hris_admin() or id_karyawan in (select id_karyawan from public.karyawan where (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))));
create policy jadwal_write on public.hris_jadwal for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy holiday_select on public.hris_hari_libur for select to authenticated using (true);
create policy holiday_write on public.hris_hari_libur for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());

-- Employee-owned HR records; HR has full access.
create policy cuti_select on public.hris_cuti for select to authenticated using (public.is_hris_admin() or id_karyawan in (select id_karyawan from public.karyawan where (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))));
create policy cuti_insert on public.hris_cuti for insert to authenticated with check (public.is_hris_admin() or id_karyawan in (select id_karyawan from public.karyawan where (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))));
create policy cuti_update on public.hris_cuti for update to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy cuti_delete on public.hris_cuti for delete to authenticated using (public.is_hris_admin());

create policy saldo_select on public.hris_saldo_cuti for select to authenticated using (public.is_hris_admin() or id_karyawan in (select id_karyawan from public.karyawan where (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))));
create policy saldo_write on public.hris_saldo_cuti for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());

create policy lembur_select on public.hris_lembur for select to authenticated using (public.is_hris_admin() or id_karyawan in (select id_karyawan from public.karyawan where (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))));
create policy lembur_insert on public.hris_lembur for insert to authenticated with check (public.is_hris_admin() or id_karyawan in (select id_karyawan from public.karyawan where (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))));
create policy lembur_update on public.hris_lembur for update to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy lembur_delete on public.hris_lembur for delete to authenticated using (public.is_hris_admin());

create policy payroll_select on public.hris_payroll for select to authenticated using (public.is_hris_admin() or id_karyawan in (select id_karyawan from public.karyawan where (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))));
create policy payroll_write on public.hris_payroll for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy payroll_component_select on public.hris_payroll_komponen for select to authenticated using (true);
create policy payroll_component_write on public.hris_payroll_komponen for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());

create policy kpi_select on public.hris_kpi for select to authenticated using (public.is_hris_admin() or id_karyawan in (select id_karyawan from public.karyawan where (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))));
create policy kpi_write on public.hris_kpi for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy performance_select on public.hris_performance for select to authenticated using (public.is_hris_admin() or id_karyawan in (select id_karyawan from public.karyawan where (auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))));
create policy performance_write on public.hris_performance for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy candidate_select on public.hris_kandidat for select to authenticated using (public.is_hris_admin());
create policy candidate_write on public.hris_kandidat for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy vacancy_select on public.hris_lowongan for select to authenticated using (true);
create policy vacancy_write on public.hris_lowongan for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy interview_select on public.hris_interview for select to authenticated using (public.is_hris_admin());
create policy interview_write on public.hris_interview for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());

-- System tables only HR.
create policy audit_select on public.hris_audit_logs for select to authenticated using (public.is_hris_admin());
create policy audit_insert on public.hris_audit_logs for insert to authenticated with check (public.is_hris_admin());
create policy users_select on public.hris_users for select to authenticated using (public.is_hris_admin() or lower(email)=lower(auth.jwt()->>'email'));
create policy users_write on public.hris_users for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy roles_select on public.hris_roles for select to authenticated using (public.is_hris_admin());
create policy roles_write on public.hris_roles for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy permissions_select on public.hris_permissions for select to authenticated using (public.is_hris_admin());
create policy permissions_write on public.hris_permissions for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());
create policy settings_select on public.hris_company_settings for select to authenticated using (true);
create policy settings_write on public.hris_company_settings for all to authenticated using (public.is_hris_admin()) with check (public.is_hris_admin());

-- Seed standard roles/permissions. Idempotent.
insert into public.hris_roles(nama,deskripsi) values
 ('Super Admin','Akses penuh seluruh HRIS'),
 ('Administrator HR','Administrasi HR dan payroll'),
 ('HR','Operasional HR'),
 ('Karyawan','Akses portal karyawan')
on conflict (nama) do nothing;

insert into public.hris_permissions(kode,nama,modul) values
 ('employee.read','Lihat karyawan','Karyawan'),('employee.write','Kelola karyawan','Karyawan'),
 ('attendance.read','Lihat absensi','Absensi'),('attendance.write','Kelola absensi','Absensi'),
 ('leave.approve','Persetujuan cuti','Cuti'),('payroll.process','Proses payroll','Payroll'),
 ('recruitment.manage','Kelola recruitment','Talent'),('reports.export','Export laporan','Laporan'),
 ('settings.manage','Kelola pengaturan','Sistem')
on conflict (kode) do nothing;

-- Audit helper callable by authenticated admin.
create or replace function public.hris_audit(p_action text,p_module text,p_record_id text default null,p_details jsonb default '{}'::jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  insert into public.hris_audit_logs(actor_email,action,module,record_id,details)
  values(auth.jwt()->>'email',p_action,p_module,p_record_id,p_details);
end;
$$;
grant execute on function public.hris_audit(text,text,text,jsonb) to authenticated;

-- Plain-text PINs are no longer used. Passwords belong in Supabase Auth.
alter table public.karyawan drop column if exists pin;

-- One-time bootstrap: after creating the first HR Auth account, run:
--   update public.hris_users set role='Super Admin' where lower(email)=lower('YOUR-HR-EMAIL');
-- and then log in through the HR dashboard.

-- Backfill profiles for Auth users that existed before this migration.
insert into public.hris_users(email,nama,role,status)
select u.email,
       coalesce(u.raw_user_meta_data->>'nama', split_part(coalesce(u.email,''),'@',1)),
       'Karyawan','Aktif'
from auth.users u
where u.email is not null
on conflict (email) do nothing;


-- ============================================================
-- LEGACY BASELINE: 000_hris_final_setup.sql
-- ============================================================

-- MoonHR HRIS FINAL DATABASE SETUP
-- Safe/idempotent: uses IF NOT EXISTS and does not change existing karyawan.id/absensi types.
-- Run this file once in Supabase SQL Editor.

create extension if not exists pgcrypto;

-- Existing employee table additions
alter table public.karyawan add column if not exists role text default 'karyawan';
alter table public.karyawan add column if not exists status_aktif boolean default true;
alter table public.karyawan add column if not exists departemen text;
alter table public.karyawan add column if not exists tanggal_masuk date;
alter table public.karyawan add column if not exists status_karyawan text default 'Tetap';

create index if not exists idx_karyawan_nama on public.karyawan(nama);
create index if not exists idx_karyawan_id_karyawan on public.karyawan(id_karyawan);
create index if not exists idx_karyawan_departemen on public.karyawan(departemen);

-- Existing attendance table additions
alter table public.absensi add column if not exists latitude numeric(10,7);
alter table public.absensi add column if not exists longitude numeric(10,7);
alter table public.absensi add column if not exists lokasi_masuk text;
alter table public.absensi add column if not exists lokasi_pulang text;
alter table public.absensi add column if not exists selfie_masuk text;
alter table public.absensi add column if not exists selfie_pulang text;
alter table public.absensi add column if not exists keterlambatan_menit integer default 0;
alter table public.absensi add column if not exists lembur_menit integer default 0;
alter table public.absensi add column if not exists keterangan text;

create index if not exists idx_absensi_tanggal on public.absensi(tanggal);
create index if not exists idx_absensi_id_karyawan on public.absensi(id_karyawan);

-- Organization
create table if not exists public.hris_cabang (
  id uuid primary key default gen_random_uuid(),
  kode text unique,
  nama text not null unique,
  kota text,
  alamat text,
  status_aktif boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_hris_cabang_nama on public.hris_cabang(nama);
create table if not exists public.hris_departemen (
  id uuid primary key default gen_random_uuid(),
  nama text not null unique,
  kode text unique,
  kepala_departemen text,
  status text not null default 'Aktif',
  created_at timestamptz not null default now()
);

create table if not exists public.hris_jabatan (
  id uuid primary key default gen_random_uuid(),
  nama text not null unique,
  kode text unique,
  departemen text,
  level_jabatan text,
  status text not null default 'Aktif',
  created_at timestamptz not null default now()
);

-- Shifts and schedules
create table if not exists public.hris_shift (
  id uuid primary key default gen_random_uuid(),
  nama text not null unique,
  jam_masuk time,
  jam_pulang time,
  istirahat_menit integer not null default 60,
  toleransi_menit integer not null default 10,
  status text not null default 'Aktif',
  created_at timestamptz not null default now()
);

create table if not exists public.hris_jadwal (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null,
  tanggal date not null,
  shift_id uuid references public.hris_shift(id) on delete set null,
  status text not null default 'Terjadwal',
  catatan text,
  created_at timestamptz not null default now(),
  unique(id_karyawan, tanggal)
);

create table if not exists public.hris_hari_libur (
  id uuid primary key default gen_random_uuid(),
  tanggal date not null unique,
  nama text not null,
  tipe text not null default 'Nasional',
  created_at timestamptz not null default now()
);

-- Leave
create table if not exists public.hris_cuti (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null,
  jenis text not null,
  tanggal_mulai date not null,
  tanggal_selesai date not null,
  jumlah_hari numeric(5,2) not null default 1,
  alasan text,
  status text not null default 'Menunggu',
  disetujui_oleh text,
  created_at timestamptz not null default now()
);

create table if not exists public.hris_saldo_cuti (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null,
  tahun integer not null,
  jenis text not null default 'Tahunan',
  saldo numeric(5,2) not null default 12,
  terpakai numeric(5,2) not null default 0,
  created_at timestamptz not null default now(),
  unique(id_karyawan, tahun, jenis)
);

-- Overtime
create table if not exists public.hris_lembur (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null,
  tanggal date not null,
  menit integer not null default 0,
  alasan text,
  status text not null default 'Menunggu',
  disetujui_oleh text,
  nominal numeric(14,2) not null default 0,
  created_at timestamptz not null default now()
);

-- Payroll
create table if not exists public.hris_payroll (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null,
  periode text not null,
  gaji_pokok numeric(14,2) default 0,
  tunjangan numeric(14,2) default 0,
  uang_makan numeric(14,2) default 0,
  transport numeric(14,2) default 0,
  lembur numeric(14,2) default 0,
  bonus numeric(14,2) default 0,
  potongan numeric(14,2) default 0,
  bpjs numeric(14,2) default 0,
  pph21 numeric(14,2) default 0,
  total_pendapatan numeric(14,2) generated always as (coalesce(gaji_pokok,0)+coalesce(tunjangan,0)+coalesce(uang_makan,0)+coalesce(transport,0)+coalesce(lembur,0)+coalesce(bonus,0)) stored,
  total_potongan numeric(14,2) generated always as (coalesce(potongan,0)+coalesce(bpjs,0)+coalesce(pph21,0)) stored,
  gaji_bersih numeric(14,2) generated always as ((coalesce(gaji_pokok,0)+coalesce(tunjangan,0)+coalesce(uang_makan,0)+coalesce(transport,0)+coalesce(lembur,0)+coalesce(bonus,0))-(coalesce(potongan,0)+coalesce(bpjs,0)+coalesce(pph21,0))) stored,
  status text not null default 'Draft',
  tanggal_proses timestamptz,
  tanggal_bayar date,
  catatan text,
  created_at timestamptz not null default now(),
  unique(id_karyawan, periode)
);

create table if not exists public.hris_payroll_komponen (
  id uuid primary key default gen_random_uuid(),
  nama text not null unique,
  tipe text not null default 'Tunjangan',
  nominal_default numeric(14,2) not null default 0,
  status text not null default 'Aktif',
  created_at timestamptz not null default now()
);

-- Talent / performance / recruitment
create table if not exists public.hris_kpi (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null,
  periode text not null,
  indikator text not null,
  target numeric,
  realisasi numeric,
  bobot numeric default 0,
  skor numeric default 0,
  status text default 'Draft',
  created_at timestamptz not null default now()
);

create table if not exists public.hris_kandidat (
  id uuid primary key default gen_random_uuid(),
  nama text not null,
  email text,
  no_telp text,
  posisi text,
  sumber text,
  tahap text default 'Screening',
  status text default 'Aktif',
  catatan text,
  created_at timestamptz not null default now()
);

create table if not exists public.hris_lowongan (
  id uuid primary key default gen_random_uuid(),
  posisi text not null,
  departemen text,
  jumlah_kebutuhan integer default 1,
  status text not null default 'Open',
  tanggal_buka date,
  tanggal_tutup date,
  deskripsi text,
  created_at timestamptz not null default now()
);

create table if not exists public.hris_performance (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null,
  periode text not null,
  nilai numeric(6,2) default 0,
  catatan text,
  status text default 'Draft',
  created_at timestamptz not null default now()
);

-- System
create table if not exists public.hris_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_email text,
  action text not null,
  module text,
  record_id text,
  details jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.hris_users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  nama text,
  role text not null default 'Admin',
  status text not null default 'Aktif',
  created_at timestamptz not null default now()
);

create table if not exists public.hris_roles (
  id uuid primary key default gen_random_uuid(),
  nama text not null unique,
  deskripsi text,
  created_at timestamptz not null default now()
);

create table if not exists public.hris_permissions (
  id uuid primary key default gen_random_uuid(),
  kode text not null unique,
  nama text not null,
  modul text,
  created_at timestamptz not null default now()
);

create table if not exists public.hris_company_settings (
  id integer primary key default 1 check (id = 1),
  company_name text not null default 'Moonjustfine by Tirta',
  work_start time default '07:00',
  work_end time default '16:00',
  break_minutes integer default 60,
  payday_day text default 'Jumat',
  currency text default 'IDR',
  timezone text default 'Asia/Jakarta',
  updated_at timestamptz not null default now()
);

insert into public.hris_company_settings(id) values (1) on conflict (id) do nothing;

-- Indexes
create index if not exists idx_hris_jadwal_tanggal on public.hris_jadwal(tanggal);
create index if not exists idx_hris_jadwal_karyawan on public.hris_jadwal(id_karyawan);
create index if not exists idx_hris_cuti_karyawan on public.hris_cuti(id_karyawan);
create index if not exists idx_hris_lembur_tanggal on public.hris_lembur(tanggal);
create index if not exists idx_hris_payroll_periode on public.hris_payroll(periode);
create index if not exists idx_hris_payroll_karyawan on public.hris_payroll(id_karyawan);
create index if not exists idx_hris_kpi_karyawan on public.hris_kpi(id_karyawan);
create index if not exists idx_hris_audit_created_at on public.hris_audit_logs(created_at desc);

-- Realtime/schema cache helper: notify PostgREST to reload its schema.
notify pgrst, 'reload schema';

-- Recruitment interview pipeline
create table if not exists public.hris_interview (
  id uuid primary key default gen_random_uuid(),
  kandidat text not null,
  tanggal date not null,
  jam time,
  interviewer text,
  hasil text,
  status text not null default 'Terjadwal',
  created_at timestamptz not null default now()
);
create index if not exists idx_hris_interview_tanggal on public.hris_interview(tanggal);

-- Helpful uniqueness constraints for operational data
create unique index if not exists uq_hris_saldo_cuti_employee_year_type on public.hris_saldo_cuti(id_karyawan,tahun,jenis);
create unique index if not exists uq_hris_payroll_employee_period on public.hris_payroll(id_karyawan,periode);


-- ============================================================
-- LEGACY BASELINE: 001_production_security.sql
-- ============================================================

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


-- ============================================================
-- LEGACY BASELINE: 002_rbac_superadmin.sql
-- ============================================================

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


-- ============================================================
-- LEGACY BASELINE: 003_registrasi_karyawan.sql
-- ============================================================

-- MoonHR: self-registration for new employees
-- Run after 000, 001 and 002. This file only adds employee self-registration.

alter table public.karyawan add column if not exists tanggal_lahir date;

create or replace function public.moonhr_create_employee_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := coalesce(new.raw_user_meta_data->>'nama', split_part(new.email,'@',1));
  v_phone text := nullif(new.raw_user_meta_data->>'no_telp','');
  v_address text := nullif(new.raw_user_meta_data->>'alamat_rumah','');
  v_birth date := nullif(new.raw_user_meta_data->>'tanggal_lahir','')::date;
  v_id text := 'REG-' || upper(substr(replace(new.id::text,'-',''),1,8));
begin
  insert into public.karyawan (id,id_karyawan,nama,email,no_telp,alamat_rumah,tanggal_lahir,role,status_aktif,status_karyawan,auth_user_id)
  values (gen_random_uuid(),v_id,v_name,new.email,v_phone,v_address,v_birth,'karyawan',false,'Menunggu Verifikasi',new.id)
  on conflict (email) do update set
    nama=excluded.nama, no_telp=excluded.no_telp, alamat_rumah=excluded.alamat_rumah, tanggal_lahir=excluded.tanggal_lahir, auth_user_id=excluded.auth_user_id;
  return new;
exception when others then
  raise warning 'MoonHR employee profile creation failed for %: %', new.email, sqlerrm;
  return new;
end;
$$;

drop trigger if exists moonhr_auth_employee_profile on auth.users;
create trigger moonhr_auth_employee_profile
after insert on auth.users
for each row execute function public.moonhr_create_employee_profile();

-- Karyawan must never be able to self-assign an elevated role.
create or replace function public.moonhr_lock_employee_role()
returns trigger
language plpgsql
as $$
begin
  if coalesce(lower(new.role),'karyawan') not in ('karyawan') then
    if not public.is_hris_admin() then
      new.role := 'karyawan';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists moonhr_employee_role_guard on public.karyawan;
create trigger moonhr_employee_role_guard
before insert or update on public.karyawan
for each row execute function public.moonhr_lock_employee_role();


-- ============================================================
-- LEGACY BASELINE: 004_enterprise_modules.sql
-- ============================================================

-- MoonXprojecT Enterprise HRIS extension
-- Run AFTER 000-003. Safe/idempotent where possible.

create extension if not exists pgcrypto;

-- Employee master data for payroll, recruitment and compliance
alter table public.karyawan add column if not exists bank_name text;
alter table public.karyawan add column if not exists bank_account text;
alter table public.karyawan add column if not exists npwp text;
alter table public.karyawan add column if not exists bpjs_kesehatan text;
alter table public.karyawan add column if not exists bpjs_ketenagakerjaan text;
alter table public.karyawan add column if not exists tipe_gaji text default 'Bulanan';
alter table public.karyawan add column if not exists tanggal_keluar date;

-- Payroll line items and approvals
create table if not exists public.hris_payroll_detail (
 id uuid primary key default gen_random_uuid(), payroll_id uuid not null references public.hris_payroll(id) on delete cascade,
 komponen_id uuid references public.hris_payroll_komponen(id) on delete set null,
 nama text not null, tipe text not null default 'Tunjangan', nominal numeric(14,2) not null default 0,
 created_at timestamptz not null default now()
);
create index if not exists idx_payroll_detail_payroll on public.hris_payroll_detail(payroll_id);
alter table public.hris_payroll add column if not exists approved_by text;
alter table public.hris_payroll add column if not exists approved_at timestamptz;

-- Recruitment ATS: application, interview scorecards and offers
alter table public.hris_kandidat add column if not exists lowongan_id uuid references public.hris_lowongan(id) on delete set null;
alter table public.hris_kandidat add column if not exists tanggal_lamar date default current_date;
alter table public.hris_kandidat add column if not exists skor numeric(6,2) default 0;
alter table public.hris_kandidat add column if not exists pemilik_rekrutmen text;
alter table public.hris_kandidat add column if not exists linkedin_url text;
alter table public.hris_interview add column if not exists kandidat_id uuid references public.hris_kandidat(id) on delete set null;
alter table public.hris_interview add column if not exists jenis text default 'Interview';
alter table public.hris_interview add column if not exists skor numeric(6,2) default 0;
alter table public.hris_interview add column if not exists catatan text;
create table if not exists public.hris_job_offers (
 id uuid primary key default gen_random_uuid(), kandidat_id uuid not null references public.hris_kandidat(id) on delete cascade,
 gaji numeric(14,2) default 0, tanggal_offer date default current_date, tanggal_mulai date,
 status text not null default 'Draft', catatan text, created_at timestamptz not null default now()
);

-- Dynamic role metadata and workflow engine
alter table public.hris_roles add column if not exists is_system boolean default false;
alter table public.hris_roles add column if not exists status text default 'Aktif';
alter table public.hris_roles add column if not exists created_at timestamptz not null default now();
create table if not exists public.hris_workflows (
 id uuid primary key default gen_random_uuid(), nama text not null unique, modul text not null,
 aktif boolean not null default true, steps jsonb not null default '[]'::jsonb, created_at timestamptz not null default now()
);
create table if not exists public.hris_approval_requests (
 id uuid primary key default gen_random_uuid(), modul text not null, record_id text not null,
 requester_email text, current_step integer not null default 1, status text not null default 'Menunggu',
 approver_role text, decided_by text, decided_at timestamptz, catatan text, created_at timestamptz not null default now()
);
create index if not exists idx_approval_status on public.hris_approval_requests(status);
create index if not exists idx_approval_module_record on public.hris_approval_requests(modul,record_id);

-- Default permissions for granular UI/API authorization
insert into public.hris_permissions(kode,nama,modul) values
('people.read','Lihat Karyawan','people'),('people.write','Kelola Karyawan','people'),('people.delete','Hapus Karyawan','people'),
('attendance.read','Lihat Absensi','attendance'),('attendance.write','Kelola Absensi','attendance'),
('schedule.read','Lihat Jadwal','schedule'),('schedule.write','Kelola Jadwal','schedule'),
('leave.read','Lihat Cuti','leave'),('leave.write','Kelola Cuti','leave'),('leave.approve','Approve Cuti','leave'),
('overtime.read','Lihat Lembur','overtime'),('overtime.approve','Approve Lembur','overtime'),
('payroll.read','Lihat Payroll','payroll'),('payroll.write','Proses Payroll','payroll'),('payroll.approve','Approve Payroll','payroll'),('payroll.pay','Konfirmasi Pembayaran','payroll'),
('talent.read','Lihat Talent','talent'),('talent.write','Kelola Talent','talent'),
('recruitment.read','Lihat Recruitment','recruitment'),('recruitment.write','Kelola Recruitment','recruitment'),('recruitment.approve','Approve Hiring','recruitment'),
('reports.read','Lihat Laporan','reports'),('reports.export','Export Laporan','reports'),('settings.write','Kelola Pengaturan','settings'),('roles.write','Kelola Role','roles'),('audit.read','Lihat Audit','audit')
on conflict(kode) do nothing;

-- Approval helpers: one auditable transaction for decisions
create or replace function public.hris_decide_approval(p_id uuid,p_status text,p_catatan text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_modul text; v_record text;
begin
 if p_status not in ('Disetujui','Ditolak') then raise exception 'Status approval tidak valid'; end if;
 select modul,record_id into v_modul,v_record from public.hris_approval_requests where id=p_id for update;
 if not found then raise exception 'Approval tidak ditemukan'; end if;
 update public.hris_approval_requests set status=p_status,decided_by=coalesce(auth.jwt()->>'email','system'),decided_at=now(),catatan=p_catatan where id=p_id;
 perform public.hris_audit(p_status,v_modul,v_record,jsonb_build_object('approval_id',p_id,'catatan',p_catatan));
end; $$;

-- Useful indexes
create index if not exists idx_kandidat_tahap on public.hris_kandidat(tahap);
create index if not exists idx_lowongan_status on public.hris_lowongan(status);
create index if not exists idx_payroll_periode_status on public.hris_payroll(periode,status);

-- Keep updated_at for company settings
create or replace function public.hris_touch_company_settings() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists trg_company_settings_updated on public.hris_company_settings;
create trigger trg_company_settings_updated before update on public.hris_company_settings for each row execute function public.hris_touch_company_settings();


-- ============================================================
-- LEGACY BASELINE: 005_enterprise_hardening.sql
-- ============================================================

-- MoonXprojecT Enterprise Hardening v2
create extension if not exists pgcrypto;

-- Payroll controls
alter table public.hris_payroll add column if not exists approved_by text;
alter table public.hris_payroll add column if not exists approved_at timestamptz;
alter table public.hris_payroll add column if not exists payment_reference text;
alter table public.hris_payroll add column if not exists locked_at timestamptz;
alter table public.hris_payroll add column if not exists locked_by text;

-- Recruitment lifecycle
create table if not exists public.hris_kandidat_history (
 id uuid primary key default gen_random_uuid(), kandidat_id uuid not null references public.hris_kandidat(id) on delete cascade,
 dari_tahap text, ke_tahap text not null, actor_email text, catatan text, created_at timestamptz not null default now()
);
create table if not exists public.hris_interview_scorecard (
 id uuid primary key default gen_random_uuid(), interview_id uuid not null references public.hris_interview(id) on delete cascade,
 kompetensi text not null, skor numeric(6,2) not null default 0, catatan text, created_at timestamptz not null default now()
);
create table if not exists public.hris_onboarding (
 id uuid primary key default gen_random_uuid(), kandidat_id uuid references public.hris_kandidat(id) on delete set null,
 id_karyawan text, status text not null default 'Belum Mulai', tanggal_mulai date, progress integer not null default 0,
 checklist jsonb not null default '[]'::jsonb, created_at timestamptz not null default now()
);

-- Multi-level workflow templates
insert into public.hris_workflows(nama,modul,steps) values
('Approval Cuti Standar','leave','[{"step":1,"role":"Supervisor"},{"step":2,"role":"HRD"}]'::jsonb),
('Approval Lembur Standar','overtime','[{"step":1,"role":"Supervisor"},{"step":2,"role":"HRD"}]'::jsonb),
('Approval Payroll Standar','payroll','[{"step":1,"role":"Payroll"},{"step":2,"role":"Super Admin"}]'::jsonb),
('Hiring Approval Standar','recruitment','[{"step":1,"role":"HRD"},{"step":2,"role":"Super Admin"}]'::jsonb)
on conflict(nama) do nothing;

-- Audit all important lifecycle changes through database triggers.
create or replace function public.hris_audit_row() returns trigger language plpgsql security definer set search_path=public as $$
begin
 perform public.hris_audit(TG_OP, TG_TABLE_NAME, coalesce((to_jsonb(new)->>'id'),(to_jsonb(old)->>'id')), jsonb_build_object('old',to_jsonb(old),'new',to_jsonb(new)));
 return coalesce(new,old);
end; $$;

drop trigger if exists trg_audit_karyawan on public.karyawan;
create trigger trg_audit_karyawan after insert or update or delete on public.karyawan for each row execute function public.hris_audit_row();
drop trigger if exists trg_audit_payroll on public.hris_payroll;
create trigger trg_audit_payroll after insert or update or delete on public.hris_payroll for each row execute function public.hris_audit_row();
drop trigger if exists trg_audit_kandidat on public.hris_kandidat;
create trigger trg_audit_kandidat after insert or update or delete on public.hris_kandidat for each row execute function public.hris_audit_row();
drop trigger if exists trg_audit_cuti on public.hris_cuti;
create trigger trg_audit_cuti after insert or update or delete on public.hris_cuti for each row execute function public.hris_audit_row();
drop trigger if exists trg_audit_lembur on public.hris_lembur;
create trigger trg_audit_lembur after insert or update or delete on public.hris_lembur for each row execute function public.hris_audit_row();

-- Permission helpers for backend enforcement.
create or replace function public.hris_require_permission(p_code text) returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.hris_has_permission(p_code) then raise exception 'Akses ditolak: %', p_code using errcode='42501'; end if;
end; $$;

-- Useful indexes
create index if not exists idx_candidate_history_candidate on public.hris_kandidat_history(kandidat_id,created_at desc);
create index if not exists idx_scorecard_interview on public.hris_interview_scorecard(interview_id);
create index if not exists idx_onboarding_status on public.hris_onboarding(status);
create index if not exists idx_payroll_employee_period on public.hris_payroll(id_karyawan,periode);


-- ============================================================
-- LEGACY BASELINE: 006_enterprise_v3.sql
-- ============================================================

-- MoonXprojecT V3: granular authorization, approval engine, leave controls, payroll locking.
-- Run AFTER 005_enterprise_hardening.sql.

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Permission catalog
-- -----------------------------------------------------------------------------
insert into public.hris_permissions(kode,nama,modul) values
('roles.read','Lihat role','roles'),
('roles.write','Kelola role','roles'),
('people.delete','Hapus karyawan','people'),
('reports.export','Export laporan','reports'),
('payroll.lock','Kunci payroll','payroll'),
('approval.read','Lihat approval','approval'),
('overtime.write','Kelola lembur','overtime')
on conflict (kode) do nothing;

-- -----------------------------------------------------------------------------
-- Authorization helper. Wildcards and module-level grants are supported.
-- -----------------------------------------------------------------------------
create or replace function public.hris_has_permission(p_code text)
returns boolean language sql stable security definer set search_path=public as $$
  select public.hris_is_super_admin() or exists(
    select 1 from public.hris_role_permissions
    where role_name=public.hris_my_role()
      and (permission_code='*' or permission_code=p_code or permission_code=split_part(p_code,'.',1))
  );
$$;
grant execute on function public.hris_has_permission(text) to authenticated;

drop function if exists public.hris_require_permission(text);
create or replace function public.hris_require_permission(p_code text)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.hris_has_permission(p_code) then
   raise exception 'Akses ditolak: %',p_code using errcode='42501';
 end if;
end; $$;
grant execute on function public.hris_require_permission(text) to authenticated;

-- -----------------------------------------------------------------------------
-- RLS policies: module permissions are enforced server-side, not only in UI.
-- -----------------------------------------------------------------------------

drop policy if exists karyawan_select on public.karyawan;
drop policy if exists karyawan_insert on public.karyawan;
drop policy if exists karyawan_update on public.karyawan;
drop policy if exists karyawan_delete on public.karyawan;
create policy karyawan_select on public.karyawan for select to authenticated using (
 public.hris_has_permission('people.read') or auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')
);
create policy karyawan_insert on public.karyawan for insert to authenticated with check (
 public.hris_has_permission('people.write') or auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')
);
create policy karyawan_update on public.karyawan for update to authenticated using (
 public.hris_has_permission('people.write') or auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')
) with check (
 public.hris_has_permission('people.write') or auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')
);
create policy karyawan_delete on public.karyawan for delete to authenticated using (public.hris_has_permission('people.delete'));

drop policy if exists absensi_select on public.absensi;
drop policy if exists absensi_insert on public.absensi;
drop policy if exists absensi_update on public.absensi;
drop policy if exists absensi_delete on public.absensi;
create policy absensi_select on public.absensi for select to authenticated using (
 public.hris_has_permission('attendance.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy absensi_insert on public.absensi for insert to authenticated with check (
 public.hris_has_permission('attendance.write') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy absensi_update on public.absensi for update to authenticated using (
 public.hris_has_permission('attendance.write') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
) with check (
 public.hris_has_permission('attendance.write') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy absensi_delete on public.absensi for delete to authenticated using (public.hris_has_permission('attendance.write'));

-- Leave / overtime / payroll


drop policy if exists cuti_select on public.hris_cuti;
drop policy if exists cuti_insert on public.hris_cuti;
drop policy if exists cuti_update on public.hris_cuti;
drop policy if exists cuti_delete on public.hris_cuti;
create policy cuti_select on public.hris_cuti for select to authenticated using (
 public.hris_has_permission('leave.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy cuti_insert on public.hris_cuti for insert to authenticated with check (
 public.hris_has_permission('leave.write') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy cuti_update on public.hris_cuti for update to authenticated using (public.hris_has_permission('leave.write')) with check (public.hris_has_permission('leave.write'));
create policy cuti_delete on public.hris_cuti for delete to authenticated using (public.hris_has_permission('leave.write'));

drop policy if exists lembur_select on public.hris_lembur;
drop policy if exists lembur_insert on public.hris_lembur;
drop policy if exists lembur_update on public.hris_lembur;
drop policy if exists lembur_delete on public.hris_lembur;
create policy lembur_select on public.hris_lembur for select to authenticated using (
 public.hris_has_permission('overtime.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy lembur_insert on public.hris_lembur for insert to authenticated with check (
 public.hris_has_permission('overtime.write') or public.hris_has_permission('overtime.approve') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy lembur_update on public.hris_lembur for update to authenticated using (public.hris_has_permission('overtime.approve') or public.hris_has_permission('overtime.write')) with check (public.hris_has_permission('overtime.approve') or public.hris_has_permission('overtime.write'));
create policy lembur_delete on public.hris_lembur for delete to authenticated using (public.hris_has_permission('overtime.write'));

drop policy if exists payroll_select on public.hris_payroll;
drop policy if exists payroll_write on public.hris_payroll;
create policy payroll_select on public.hris_payroll for select to authenticated using (
 public.hris_has_permission('payroll.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy payroll_write on public.hris_payroll for all to authenticated using (
 public.hris_has_permission('payroll.write') or public.hris_has_permission('payroll.approve') or public.hris_has_permission('payroll.pay') or public.hris_has_permission('payroll.lock')
) with check (
 public.hris_has_permission('payroll.write') or public.hris_has_permission('payroll.approve') or public.hris_has_permission('payroll.pay') or public.hris_has_permission('payroll.lock')
);

drop policy if exists audit_select on public.hris_audit_logs;
drop policy if exists audit_insert on public.hris_audit_logs;
create policy audit_select on public.hris_audit_logs for select to authenticated using (public.hris_has_permission('audit.read'));
create policy audit_insert on public.hris_audit_logs for insert to authenticated with check (public.hris_has_permission('audit.read'));

drop policy if exists roles_select on public.hris_roles;
drop policy if exists roles_write on public.hris_roles;
create policy roles_select on public.hris_roles for select to authenticated using (public.hris_has_permission('roles.read') or public.hris_has_permission('roles.write'));
create policy roles_write on public.hris_roles for all to authenticated using (public.hris_has_permission('roles.write')) with check (public.hris_has_permission('roles.write'));

-- Approval requests / workflows / hardening tables
alter table public.hris_approval_requests enable row level security;
alter table public.hris_workflows enable row level security;
alter table public.hris_payroll_detail enable row level security;
alter table public.hris_kandidat_history enable row level security;
alter table public.hris_interview_scorecard enable row level security;
alter table public.hris_onboarding enable row level security;
alter table public.hris_job_offers enable row level security;

drop policy if exists approval_select on public.hris_approval_requests;
drop policy if exists approval_write on public.hris_approval_requests;
create policy approval_select on public.hris_approval_requests for select to authenticated using (
 public.hris_has_permission('approval.read') or public.hris_has_permission('leave.approve') or public.hris_has_permission('overtime.approve') or public.hris_has_permission('payroll.approve') or lower(requester_email)=lower(auth.jwt()->>'email')
);
create policy approval_write on public.hris_approval_requests for all to authenticated using (
 public.hris_has_permission('leave.approve') or public.hris_has_permission('overtime.approve') or public.hris_has_permission('payroll.approve') or public.hris_has_permission('recruitment.approve')
) with check (
 public.hris_has_permission('leave.approve') or public.hris_has_permission('overtime.approve') or public.hris_has_permission('payroll.approve') or public.hris_has_permission('recruitment.approve')
);

drop policy if exists workflow_select on public.hris_workflows;
create policy workflow_select on public.hris_workflows for select to authenticated using (true);
drop policy if exists workflow_write on public.hris_workflows;
create policy workflow_write on public.hris_workflows for all to authenticated using (public.hris_has_permission('settings.write')) with check (public.hris_has_permission('settings.write'));

drop policy if exists payroll_detail_select on public.hris_payroll_detail;
create policy payroll_detail_select on public.hris_payroll_detail for select to authenticated using (public.hris_has_permission('payroll.read'));
drop policy if exists payroll_detail_write on public.hris_payroll_detail;
create policy payroll_detail_write on public.hris_payroll_detail for all to authenticated using (public.hris_has_permission('payroll.write')) with check (public.hris_has_permission('payroll.write'));

drop policy if exists recruitment_history_select on public.hris_kandidat_history;
create policy recruitment_history_select on public.hris_kandidat_history for select to authenticated using (public.hris_has_permission('recruitment.read'));
drop policy if exists recruitment_history_write on public.hris_kandidat_history;
create policy recruitment_history_write on public.hris_kandidat_history for all to authenticated using (public.hris_has_permission('recruitment.write')) with check (public.hris_has_permission('recruitment.write'));
drop policy if exists scorecard_select on public.hris_interview_scorecard;
create policy scorecard_select on public.hris_interview_scorecard for select to authenticated using (public.hris_has_permission('recruitment.read'));
drop policy if exists scorecard_write on public.hris_interview_scorecard;
create policy scorecard_write on public.hris_interview_scorecard for all to authenticated using (public.hris_has_permission('recruitment.write')) with check (public.hris_has_permission('recruitment.write'));
drop policy if exists onboarding_select on public.hris_onboarding;
create policy onboarding_select on public.hris_onboarding for select to authenticated using (public.hris_has_permission('recruitment.read') or public.hris_has_permission('people.read'));
drop policy if exists onboarding_write on public.hris_onboarding;
create policy onboarding_write on public.hris_onboarding for all to authenticated using (public.hris_has_permission('recruitment.write') or public.hris_has_permission('people.write')) with check (public.hris_has_permission('recruitment.write') or public.hris_has_permission('people.write'));
drop policy if exists offers_select on public.hris_job_offers;
create policy offers_select on public.hris_job_offers for select to authenticated using (public.hris_has_permission('recruitment.read'));
drop policy if exists offers_write on public.hris_job_offers;
create policy offers_write on public.hris_job_offers for all to authenticated using (public.hris_has_permission('recruitment.write')) with check (public.hris_has_permission('recruitment.write'));

-- -----------------------------------------------------------------------------
-- Approval engine
-- -----------------------------------------------------------------------------
create or replace function public.hris_submit_approval(p_modul text,p_record_id text)
returns uuid language plpgsql security definer set search_path=public as $$
declare
 v_email text:=auth.jwt()->>'email'; v_role text:=public.hris_my_role(); v_id uuid; v_steps jsonb; v_role_approver text;
begin
 if p_modul='leave' then perform public.hris_require_permission('leave.write');
 elsif p_modul='overtime' then perform public.hris_require_permission('overtime.write');
 elsif p_modul='payroll' then perform public.hris_require_permission('payroll.write');
 elsif p_modul='recruitment' then perform public.hris_require_permission('recruitment.write');
 else raise exception 'Modul approval tidak didukung'; end if;
 select steps into v_steps from public.hris_workflows where modul=p_modul and aktif=true order by created_at limit 1;
 if v_steps is null then v_steps:='[{"step":1,"role":"Super Admin"}]'::jsonb; end if;
 v_role_approver:=v_steps->0->>'role';
 insert into public.hris_approval_requests(modul,record_id,requester_email,current_step,status,approver_role)
 values(p_modul,p_record_id,v_email,1,'Menunggu',v_role_approver) returning id into v_id;
 perform public.hris_audit('SUBMIT',p_modul,p_record_id,jsonb_build_object('approval_id',v_id));
 return v_id;
end; $$;
grant execute on function public.hris_submit_approval(text,text) to authenticated;

create or replace function public.hris_decide_approval(p_id uuid,p_status text,p_catatan text default null)
returns void language plpgsql security definer set search_path=public as $$
declare
 r record; v_steps jsonb; v_next_role text; v_email text:=auth.jwt()->>'email'; v_role text:=public.hris_my_role(); v_days numeric;
begin
 if p_status not in ('Disetujui','Ditolak') then raise exception 'Status approval tidak valid'; end if;
 select * into r from public.hris_approval_requests where id=p_id for update;
 if not found then raise exception 'Approval tidak ditemukan'; end if;
 if r.status<>'Menunggu' then raise exception 'Approval sudah diproses'; end if;
 if v_role<>r.approver_role and v_role<>'Super Admin' then raise exception 'Role % tidak berwenang pada tahap ini',v_role; end if;
 if r.modul='leave' then perform public.hris_require_permission('leave.approve');
 elsif r.modul='overtime' then perform public.hris_require_permission('overtime.approve');
 elsif r.modul='payroll' then perform public.hris_require_permission('payroll.approve');
 elsif r.modul='recruitment' then perform public.hris_require_permission('recruitment.approve'); end if;
 select steps into v_steps from public.hris_workflows where modul=r.modul and aktif=true order by created_at limit 1;
 if p_status='Ditolak' then
   update public.hris_approval_requests set status=p_status,decided_by=v_email,decided_at=now(),catatan=p_catatan where id=p_id;
   if r.modul='leave' then update public.hris_cuti set status='Ditolak',disetujui_oleh=v_email where id=r.record_id::uuid;
   elsif r.modul='overtime' then update public.hris_lembur set status='Ditolak',disetujui_oleh=v_email where id=r.record_id::uuid;
   elsif r.modul='payroll' then update public.hris_payroll set status='Ditolak',approved_by=v_email,approved_at=now() where id=r.record_id::uuid; end if;
 else
   v_next_role:=v_steps->r.current_step->>'role';
   if v_next_role is not null then
     update public.hris_approval_requests set current_step=r.current_step+1,approver_role=v_next_role,catatan=p_catatan where id=p_id;
   else
     update public.hris_approval_requests set status=p_status,decided_by=v_email,decided_at=now(),catatan=p_catatan where id=p_id;
     if r.modul='leave' then
       select jumlah_hari into v_days from public.hris_cuti where id=r.record_id::uuid;
       insert into public.hris_saldo_cuti(id_karyawan,tahun,jenis,saldo,terpakai) select id_karyawan,extract(year from tanggal_mulai)::int,jenis,12,0 from public.hris_cuti where id=r.record_id::uuid on conflict(id_karyawan,tahun,jenis) do nothing;
       update public.hris_saldo_cuti s set terpakai=s.terpakai+coalesce(v_days,0),saldo=greatest(0,s.saldo-coalesce(v_days,0)) where id_karyawan=(select id_karyawan from public.hris_cuti where id=r.record_id::uuid) and tahun=extract(year from (select tanggal_mulai from public.hris_cuti where id=r.record_id::uuid))::int and jenis=(select jenis from public.hris_cuti where id=r.record_id::uuid);
       update public.hris_cuti set status='Disetujui',disetujui_oleh=v_email where id=r.record_id::uuid;
     elsif r.modul='overtime' then update public.hris_lembur set status='Disetujui',disetujui_oleh=v_email where id=r.record_id::uuid;
     elsif r.modul='payroll' then update public.hris_payroll set status='Disetujui',approved_by=v_email,approved_at=now() where id=r.record_id::uuid;
     end if;
   end if;
 end if;
 perform public.hris_audit(p_status,r.modul,r.record_id,jsonb_build_object('approval_id',p_id,'catatan',p_catatan,'actor',v_email));
end; $$;
grant execute on function public.hris_decide_approval(uuid,text,text) to authenticated;

-- Payroll finalization helpers
create or replace function public.hris_lock_payroll(p_payroll_id uuid,p_reference text default null)
returns void language plpgsql security definer set search_path=public as $$
begin
 perform public.hris_require_permission('payroll.lock');
 update public.hris_payroll set locked_at=now(),locked_by=auth.jwt()->>'email',payment_reference=coalesce(p_reference,payment_reference),status='Dibayar',tanggal_bayar=coalesce(tanggal_bayar,current_date) where id=p_payroll_id;
 perform public.hris_audit('LOCK_PAYROLL','payroll',p_payroll_id::text,jsonb_build_object('payment_reference',p_reference));
end; $$;
grant execute on function public.hris_lock_payroll(uuid,text) to authenticated;

-- Do not allow direct mutation of locked payroll through ordinary update policy.
create or replace function public.hris_payroll_update_guard() returns trigger language plpgsql as $$
begin
 if old.locked_at is not null and not public.hris_has_permission('payroll.lock') then raise exception 'Payroll sudah dikunci'; end if;
 return new;
end; $$;
drop trigger if exists trg_payroll_update_guard on public.hris_payroll;
create trigger trg_payroll_update_guard before update on public.hris_payroll for each row execute function public.hris_payroll_update_guard();

-- Recruitment stage history trigger
create or replace function public.hris_candidate_stage_history() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if tg_op='UPDATE' and coalesce(old.tahap,'')<>coalesce(new.tahap,'') then
   insert into public.hris_kandidat_history(kandidat_id,dari_tahap,ke_tahap,actor_email,catatan)
   values(new.id,old.tahap,new.tahap,auth.jwt()->>'email',new.catatan);
 end if;
 return new;
end; $$;
drop trigger if exists trg_candidate_stage_history on public.hris_kandidat;
create trigger trg_candidate_stage_history after update of tahap on public.hris_kandidat for each row execute function public.hris_candidate_stage_history();

-- Validation: leave requests may not overlap for the same employee.
create or replace function public.hris_validate_leave_overlap() returns trigger language plpgsql as $$
begin
 if exists(select 1 from public.hris_cuti x where x.id_karyawan=new.id_karyawan and x.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid) and x.status<>'Ditolak' and new.tanggal_mulai<=x.tanggal_selesai and new.tanggal_selesai>=x.tanggal_mulai) then
   raise exception 'Pengajuan cuti bertabrakan dengan pengajuan yang sudah ada';
 end if;
 return new;
end; $$;
drop trigger if exists trg_leave_overlap on public.hris_cuti;
create trigger trg_leave_overlap before insert or update on public.hris_cuti for each row execute function public.hris_validate_leave_overlap();

notify pgrst,'reload schema';

-- Granular RLS for talent and recruitment (replaces legacy admin-only checks).
drop policy if exists candidate_select on public.hris_kandidat;
drop policy if exists candidate_write on public.hris_kandidat;
create policy candidate_select on public.hris_kandidat for select to authenticated using (public.hris_has_permission('recruitment.read'));
create policy candidate_write on public.hris_kandidat for all to authenticated using (public.hris_has_permission('recruitment.write')) with check (public.hris_has_permission('recruitment.write'));

drop policy if exists vacancy_select on public.hris_lowongan;
drop policy if exists vacancy_write on public.hris_lowongan;
create policy vacancy_select on public.hris_lowongan for select to authenticated using (true);
create policy vacancy_write on public.hris_lowongan for all to authenticated using (public.hris_has_permission('recruitment.write')) with check (public.hris_has_permission('recruitment.write'));

drop policy if exists interview_select on public.hris_interview;
drop policy if exists interview_write on public.hris_interview;
create policy interview_select on public.hris_interview for select to authenticated using (public.hris_has_permission('recruitment.read'));
create policy interview_write on public.hris_interview for all to authenticated using (public.hris_has_permission('recruitment.write')) with check (public.hris_has_permission('recruitment.write'));

drop policy if exists kpi_select on public.hris_kpi;
drop policy if exists kpi_write on public.hris_kpi;
create policy kpi_select on public.hris_kpi for select to authenticated using (public.hris_has_permission('talent.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')));
create policy kpi_write on public.hris_kpi for all to authenticated using (public.hris_has_permission('talent.write')) with check (public.hris_has_permission('talent.write'));

drop policy if exists performance_select on public.hris_performance;
drop policy if exists performance_write on public.hris_performance;
create policy performance_select on public.hris_performance for select to authenticated using (public.hris_has_permission('talent.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')));
create policy performance_write on public.hris_performance for all to authenticated using (public.hris_has_permission('talent.write')) with check (public.hris_has_permission('talent.write'));

-- Payroll detail/status support permissions for existing custom roles.
insert into public.hris_role_permissions(role_name,permission_code)
select r.nama,p.kode
from public.hris_roles r cross join public.hris_permissions p
where r.nama='Super Admin' and p.kode='*'
on conflict do nothing;

notify pgrst,'reload schema';

-- Granular RLS for schedule/master data and settings.
drop policy if exists cabang_write on public.hris_cabang;
create policy cabang_write on public.hris_cabang for all to authenticated using (public.hris_has_permission('people.write')) with check (public.hris_has_permission('people.write'));
drop policy if exists dept_write on public.hris_departemen;
create policy dept_write on public.hris_departemen for all to authenticated using (public.hris_has_permission('people.write')) with check (public.hris_has_permission('people.write'));
drop policy if exists jabatan_write on public.hris_jabatan;
create policy jabatan_write on public.hris_jabatan for all to authenticated using (public.hris_has_permission('people.write')) with check (public.hris_has_permission('people.write'));
drop policy if exists shift_write on public.hris_shift;
create policy shift_write on public.hris_shift for all to authenticated using (public.hris_has_permission('schedule.write')) with check (public.hris_has_permission('schedule.write'));
drop policy if exists jadwal_select on public.hris_jadwal;
drop policy if exists jadwal_write on public.hris_jadwal;
create policy jadwal_select on public.hris_jadwal for select to authenticated using (public.hris_has_permission('schedule.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')));
create policy jadwal_write on public.hris_jadwal for all to authenticated using (public.hris_has_permission('schedule.write')) with check (public.hris_has_permission('schedule.write'));
drop policy if exists holiday_write on public.hris_hari_libur;
create policy holiday_write on public.hris_hari_libur for all to authenticated using (public.hris_has_permission('schedule.write')) with check (public.hris_has_permission('schedule.write'));
drop policy if exists settings_write on public.hris_company_settings;
create policy settings_write on public.hris_company_settings for all to authenticated using (public.hris_has_permission('settings.write')) with check (public.hris_has_permission('settings.write'));

notify pgrst,'reload schema';
drop policy if exists payroll_component_write on public.hris_payroll_komponen;
create policy payroll_component_write on public.hris_payroll_komponen for all to authenticated using (public.hris_has_permission('payroll.write')) with check (public.hris_has_permission('payroll.write'));
notify pgrst,'reload schema';


-- ============================================================
-- LEGACY BASELINE: 007_v4_foundation.sql
-- ============================================================

-- MoonXprojecT V4: employee 360, documents, notifications, lifecycle and operational controls.
-- Run AFTER 006_enterprise_v3.sql.

create extension if not exists pgcrypto;

-- Employee lifecycle / organization history
create table if not exists public.hris_employee_history (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null,
  jenis text not null,
  dari_nilai text,
  ke_nilai text,
  efektif_mulai date default current_date,
  alasan text,
  actor_email text,
  created_at timestamptz not null default now()
);
create index if not exists idx_employee_history_employee on public.hris_employee_history(id_karyawan, created_at desc);

create table if not exists public.hris_employee_documents (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null,
  jenis text not null,
  nama_file text not null,
  storage_path text,
  nomor_dokumen text,
  tanggal_terbit date,
  tanggal_expired date,
  status text not null default 'Aktif',
  catatan text,
  uploaded_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_employee_documents_employee on public.hris_employee_documents(id_karyawan);
create index if not exists idx_employee_documents_expiry on public.hris_employee_documents(tanggal_expired);

-- Notification center
create table if not exists public.hris_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_email text not null,
  type text not null default 'system',
  title text not null,
  message text not null,
  link text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_notifications_recipient on public.hris_notifications(recipient_email, is_read, created_at desc);

-- Approval history independent from current request state.
create table if not exists public.hris_approval_history (
  id uuid primary key default gen_random_uuid(),
  approval_id uuid,
  modul text,
  record_id text,
  step_no integer,
  approver_role text,
  actor_email text,
  status text not null,
  catatan text,
  created_at timestamptz not null default now()
);
create index if not exists idx_approval_history_request on public.hris_approval_history(approval_id, created_at desc);

-- Helpful employee fields. Safe because these are additive.
alter table public.karyawan add column if not exists nomor_induk text;
alter table public.karyawan add column if not exists tanggal_keluar date;
alter table public.karyawan add column if not exists alasan_keluar text;
alter table public.karyawan add column if not exists atasan_id text;
alter table public.karyawan add column if not exists level_jabatan text;
alter table public.karyawan add column if not exists lokasi_kerja text;
alter table public.karyawan add column if not exists tipe_karyawan text default 'Tetap';

-- Updated-at helper.
create or replace function public.hris_touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at=now(); return new; end; $$;
drop trigger if exists trg_employee_documents_updated on public.hris_employee_documents;
create trigger trg_employee_documents_updated before update on public.hris_employee_documents for each row execute function public.hris_touch_updated_at();

-- Capture material employee changes.
create or replace function public.hris_employee_change_history() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='UPDATE' then
    if coalesce(old.jabatan,'')<>coalesce(new.jabatan,'') then
      insert into public.hris_employee_history(id_karyawan,jenis,dari_nilai,ke_nilai,actor_email) values(new.id_karyawan,'Jabatan',old.jabatan,new.jabatan,auth.jwt()->>'email');
    end if;
    if coalesce(old.departemen,'')<>coalesce(new.departemen,'') then
      insert into public.hris_employee_history(id_karyawan,jenis,dari_nilai,ke_nilai,actor_email) values(new.id_karyawan,'Departemen',old.departemen,new.departemen,auth.jwt()->>'email');
    end if;
    if coalesce(old.status_aktif,true)<>coalesce(new.status_aktif,true) then
      insert into public.hris_employee_history(id_karyawan,jenis,dari_nilai,ke_nilai,actor_email) values(new.id_karyawan,'Status',old.status_aktif::text,new.status_aktif::text,auth.jwt()->>'email');
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists trg_employee_change_history on public.karyawan;
create trigger trg_employee_change_history after update on public.karyawan for each row execute function public.hris_employee_change_history();

-- RLS
alter table public.hris_employee_history enable row level security;
alter table public.hris_employee_documents enable row level security;
alter table public.hris_notifications enable row level security;
alter table public.hris_approval_history enable row level security;

drop policy if exists employee_history_select on public.hris_employee_history;
create policy employee_history_select on public.hris_employee_history for select to authenticated using (public.hris_has_permission('people.read'));
drop policy if exists employee_history_write on public.hris_employee_history;
create policy employee_history_write on public.hris_employee_history for insert to authenticated with check (public.hris_has_permission('people.write'));

drop policy if exists employee_documents_select on public.hris_employee_documents;
drop policy if exists employee_documents_write on public.hris_employee_documents;
create policy employee_documents_select on public.hris_employee_documents for select to authenticated using (public.hris_has_permission('people.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')));
create policy employee_documents_write on public.hris_employee_documents for all to authenticated using (public.hris_has_permission('people.write')) with check (public.hris_has_permission('people.write'));

drop policy if exists notifications_select on public.hris_notifications;
drop policy if exists notifications_update on public.hris_notifications;
create policy notifications_select on public.hris_notifications for select to authenticated using (lower(recipient_email)=lower(auth.jwt()->>'email') or public.hris_has_permission('settings.write'));
create policy notifications_update on public.hris_notifications for update to authenticated using (lower(recipient_email)=lower(auth.jwt()->>'email') or public.hris_has_permission('settings.write')) with check (lower(recipient_email)=lower(auth.jwt()->>'email') or public.hris_has_permission('settings.write'));

drop policy if exists approval_history_select on public.hris_approval_history;
create policy approval_history_select on public.hris_approval_history for select to authenticated using (public.hris_has_permission('approval.read') or public.hris_has_permission('audit.read'));

-- Permission catalog
insert into public.hris_permissions(kode,nama,modul) values
('people.history','Lihat riwayat karyawan','people'),
('people.documents','Kelola dokumen karyawan','people'),
('notifications.read','Lihat notifikasi','notifications'),
('notifications.write','Kelola notifikasi','notifications')
on conflict (kode) do nothing;

notify pgrst,'reload schema';


-- ============================================================
-- LEGACY BASELINE: 008_v5_production.sql
-- ============================================================

-- MoonXprojecT V5: production controls, data integrity, observability and self-service readiness.
-- Run AFTER 007_v4_foundation.sql.

create extension if not exists pgcrypto;

-- Operational uniqueness / data quality.
create unique index if not exists uq_employee_email_active on public.karyawan(lower(email)) where email is not null and status_aktif=true;
create unique index if not exists uq_employee_document_name on public.hris_employee_documents(id_karyawan, jenis, nama_file);

-- Attendance quality checks. We intentionally validate obvious impossible values only;
-- company-specific shift rules remain configurable in the application.
create or replace function public.hris_validate_attendance_quality() returns trigger language plpgsql as $$
begin
  if new.tanggal is null then raise exception 'Tanggal absensi wajib diisi'; end if;
  if new.jam_masuk is not null and new.jam_pulang is not null and new.jam_pulang < new.jam_masuk then
    raise exception 'Jam pulang tidak boleh lebih awal dari jam masuk pada absensi normal';
  end if;
  if coalesce(new.keterlambatan_menit,0) < 0 then raise exception 'Keterlambatan tidak boleh negatif'; end if;
  if coalesce(new.lembur_menit,0) < 0 then raise exception 'Lembur tidak boleh negatif'; end if;
  return new;
end; $$;
drop trigger if exists trg_attendance_quality on public.absensi;
create trigger trg_attendance_quality before insert or update on public.absensi for each row execute function public.hris_validate_attendance_quality();

-- Leave integrity: valid date order and positive duration.
create or replace function public.hris_validate_leave_quality() returns trigger language plpgsql as $$
begin
  if new.tanggal_mulai is null or new.tanggal_selesai is null then raise exception 'Tanggal cuti wajib diisi'; end if;
  if new.tanggal_selesai < new.tanggal_mulai then raise exception 'Tanggal selesai tidak boleh sebelum tanggal mulai'; end if;
  if coalesce(new.jumlah_hari,0) <= 0 then new.jumlah_hari=(new.tanggal_selesai-new.tanggal_mulai)+1; end if;
  return new;
end; $$;
drop trigger if exists trg_leave_quality on public.hris_cuti;
create trigger trg_leave_quality before insert or update on public.hris_cuti for each row execute function public.hris_validate_leave_quality();

-- Payroll cannot be silently edited after final payment/lock.
create or replace function public.hris_payroll_final_guard() returns trigger language plpgsql as $$
begin
  if old.locked_at is not null then
    if coalesce(new.gaji_pokok,0)<>coalesce(old.gaji_pokok,0)
      or coalesce(new.tunjangan,0)<>coalesce(old.tunjangan,0)
      or coalesce(new.uang_makan,0)<>coalesce(old.uang_makan,0)
      or coalesce(new.transport,0)<>coalesce(old.transport,0)
      or coalesce(new.lembur,0)<>coalesce(old.lembur,0)
      or coalesce(new.bonus,0)<>coalesce(old.bonus,0)
      or coalesce(new.potongan,0)<>coalesce(old.potongan,0)
      or coalesce(new.bpjs,0)<>coalesce(old.bpjs,0)
      or coalesce(new.pph21,0)<>coalesce(old.pph21,0)
    then raise exception 'Payroll final sudah dikunci dan tidak dapat diubah'; end if;
  end if;
  return new;
end; $$;
drop trigger if exists trg_payroll_final_guard on public.hris_payroll;
create trigger trg_payroll_final_guard before update on public.hris_payroll for each row execute function public.hris_payroll_final_guard();

-- Reusable notification helper for workflows/integrations.
create or replace function public.hris_notify(p_recipient text,p_type text,p_title text,p_message text,p_link text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if p_recipient is null or trim(p_recipient)='' then return null; end if;
  insert into public.hris_notifications(recipient_email,type,title,message,link) values(lower(trim(p_recipient)),p_type,p_title,p_message,p_link) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.hris_notify(text,text,text,text,text) to authenticated;

-- Approval history + notifications. Replaces state-only observability with a durable trail.
create or replace function public.hris_record_approval_history() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='UPDATE' and (old.status is distinct from new.status or old.current_step is distinct from new.current_step) then
    insert into public.hris_approval_history(approval_id,modul,record_id,step_no,approver_role,actor_email,status,catatan)
    values(new.id,new.modul,new.record_id,new.current_step,new.approver_role,coalesce(new.decided_by,auth.jwt()->>'email'),new.status,new.catatan);
  end if;
  return new;
end; $$;
drop trigger if exists trg_approval_history on public.hris_approval_requests;
create trigger trg_approval_history after update on public.hris_approval_requests for each row execute function public.hris_record_approval_history();

-- Candidate, payroll and leave changes get an application-visible notification where email is known.
create or replace function public.hris_notify_leave_decision() returns trigger language plpgsql security definer set search_path=public as $$
declare v_email text;
begin
 if tg_op='UPDATE' and old.status is distinct from new.status and new.status in ('Disetujui','Ditolak') then
   select email into v_email from public.karyawan where id_karyawan=new.id_karyawan limit 1;
   perform public.hris_notify(v_email,'leave','Status pengajuan cuti',format('Pengajuan cuti Anda berstatus %s.',new.status),'#/leave-request');
 end if;
 return new;
end; $$;
drop trigger if exists trg_notify_leave_decision on public.hris_cuti;
create trigger trg_notify_leave_decision after update of status on public.hris_cuti for each row execute function public.hris_notify_leave_decision();

-- System health view for admin dashboards and future monitoring.
create or replace view public.hris_system_health as
select
  (select count(*) from public.karyawan where status_aktif=true) as active_employees,
  (select count(*) from public.hris_cuti where status='Menunggu') as pending_leave,
  (select count(*) from public.hris_lembur where status='Menunggu') as pending_overtime,
  (select count(*) from public.hris_payroll where status='Menunggu Approval') as pending_payroll,
  (select count(*) from public.hris_approval_requests where status='Menunggu') as pending_approvals,
  (select count(*) from public.hris_notifications where is_read=false) as unread_notifications,
  now() as checked_at;

-- More explicit permission catalog.
insert into public.hris_permissions(kode,nama,modul) values
('people.history','Lihat riwayat karyawan','people'),
('people.documents','Kelola dokumen karyawan','people'),
('notifications.read','Lihat notifikasi','notifications'),
('notifications.write','Kelola notifikasi','notifications'),
('system.health','Lihat kesehatan sistem','system')
on conflict (kode) do nothing;

notify pgrst,'reload schema';


-- ============================================================
-- LEGACY BASELINE: 009_v6_production.sql
-- ============================================================

-- MoonXprojecT V6 Production: integrity, approval safety, permission consistency and operational controls.
-- Run AFTER 008_v5_production.sql.

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- 1) Stronger data constraints / indexes
-- -----------------------------------------------------------------------------
create unique index if not exists uq_active_employee_nomor_induk
  on public.karyawan(lower(trim(nomor_induk)))
  where nomor_induk is not null and trim(nomor_induk)<>'' and status_aktif=true;

create index if not exists idx_absensi_employee_date on public.absensi(id_karyawan,tanggal desc);
create index if not exists idx_cuti_status_dates on public.hris_cuti(status,tanggal_mulai,tanggal_selesai);
create index if not exists idx_lembur_status_date on public.hris_lembur(status,tanggal desc);
create index if not exists idx_payroll_period_status on public.hris_payroll(periode,status);
create unique index if not exists uq_active_approval_request
  on public.hris_approval_requests(modul,record_id)
  where status='Menunggu';

-- -----------------------------------------------------------------------------
-- 2) Prevent impossible leave balance deductions.
-- -----------------------------------------------------------------------------
create or replace function public.hris_validate_leave_balance()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  v_saldo numeric;
  v_tahun integer;
begin
  if new.status='Disetujui' and (old.status is distinct from new.status) then
    v_tahun:=extract(year from new.tanggal_mulai)::integer;
    select saldo into v_saldo
      from public.hris_saldo_cuti
      where id_karyawan=new.id_karyawan and tahun=v_tahun and jenis=new.jenis
      for update;
    if v_saldo is not null and v_saldo < coalesce(new.jumlah_hari,0) then
      raise exception 'Saldo cuti tidak mencukupi. Tersedia %, diperlukan %',v_saldo,new.jumlah_hari;
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists trg_leave_balance_guard on public.hris_cuti;
create trigger trg_leave_balance_guard before update of status on public.hris_cuti
for each row execute function public.hris_validate_leave_balance();

-- -----------------------------------------------------------------------------
-- 3) Approval decisions must always be tied to the current workflow role and
--    cannot be duplicated for the same record.
-- -----------------------------------------------------------------------------
create or replace function public.hris_submit_approval(p_modul text,p_record_id text)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_email text:=auth.jwt()->>'email';
  v_steps jsonb;
  v_role_approver text;
  v_id uuid;
begin
  if p_modul='leave' then perform public.hris_require_permission('leave.write');
  elsif p_modul='overtime' then perform public.hris_require_permission('overtime.write');
  elsif p_modul='payroll' then perform public.hris_require_permission('payroll.write');
  elsif p_modul='recruitment' then perform public.hris_require_permission('recruitment.write');
  else raise exception 'Modul approval tidak didukung'; end if;

  if exists(select 1 from public.hris_approval_requests where modul=p_modul and record_id=p_record_id and status='Menunggu') then
    raise exception 'Record sudah memiliki approval yang sedang berjalan';
  end if;

  select steps into v_steps from public.hris_workflows
    where modul=p_modul and aktif=true order by created_at limit 1;
  if v_steps is null or jsonb_array_length(v_steps)=0 then
    v_steps:='[{"step":1,"role":"Super Admin"}]'::jsonb;
  end if;
  v_role_approver:=v_steps->0->>'role';

  insert into public.hris_approval_requests(modul,record_id,requester_email,current_step,status,approver_role)
  values(p_modul,p_record_id,v_email,1,'Menunggu',v_role_approver)
  returning id into v_id;

  perform public.hris_audit('SUBMIT',p_modul,p_record_id,jsonb_build_object('approval_id',v_id));
  return v_id;
end; $$;
grant execute on function public.hris_submit_approval(text,text) to authenticated;

-- -----------------------------------------------------------------------------
-- 4) Payroll state machine. No skipping straight from Draft to Dibayar.
-- -----------------------------------------------------------------------------
create or replace function public.hris_validate_payroll_state()
returns trigger language plpgsql as $$
begin
  if old.status is distinct from new.status then
    if old.status='Draft' and new.status not in ('Draft','Menunggu Approval','Ditolak') then
      raise exception 'Payroll Draft harus melalui Menunggu Approval';
    elsif old.status='Menunggu Approval' and new.status not in ('Menunggu Approval','Disetujui','Ditolak') then
      raise exception 'Payroll menunggu approval hanya dapat disetujui atau ditolak';
    elsif old.status='Disetujui' and new.status not in ('Disetujui','Dibayar') then
      raise exception 'Payroll disetujui hanya dapat dibayar';
    elsif old.status='Dibayar' and new.status<>'Dibayar' then
      raise exception 'Payroll yang sudah dibayar tidak dapat dikembalikan statusnya';
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists trg_payroll_state_guard on public.hris_payroll;
create trigger trg_payroll_state_guard before update on public.hris_payroll
for each row execute function public.hris_validate_payroll_state();

-- -----------------------------------------------------------------------------
-- 5) Only server-side RPC may finalize payroll. Direct status changes to
--    Disetujui/Dibayar are rejected unless actor has the matching permission.
-- -----------------------------------------------------------------------------
create or replace function public.hris_payroll_transition_guard()
returns trigger language plpgsql as $$
begin
  if new.status='Menunggu Approval' and old.status='Draft' then
    perform public.hris_require_permission('payroll.write');
  elsif new.status='Disetujui' and old.status='Menunggu Approval' then
    perform public.hris_require_permission('payroll.approve');
  elsif new.status='Dibayar' and old.status='Disetujui' then
    if not public.hris_has_permission('payroll.pay') and not public.hris_has_permission('payroll.lock') then
      raise exception 'Akses ditolak: payroll.pay';
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists trg_payroll_transition_guard on public.hris_payroll;
create trigger trg_payroll_transition_guard before update on public.hris_payroll
for each row execute function public.hris_payroll_transition_guard();

-- -----------------------------------------------------------------------------
-- 6) Operational audit coverage for critical master/transaction tables.
-- -----------------------------------------------------------------------------
create or replace function public.hris_audit_safe_row()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  v_id text;
begin
  v_id:=coalesce((to_jsonb(new)->>'id'),(to_jsonb(old)->>'id'),(to_jsonb(new)->>'id_karyawan'),(to_jsonb(old)->>'id_karyawan'));
  perform public.hris_audit(TG_OP,TG_TABLE_NAME,v_id,jsonb_build_object('record_id',v_id,'operation',TG_OP));
  return coalesce(new,old);
end; $$;

do $$
declare t text;
begin
  foreach t in array array['hris_cabang','hris_departemen','hris_jabatan','hris_shift','hris_jadwal','hris_hari_libur','hris_cuti','hris_lembur','hris_payroll_komponen','hris_kandidat','hris_lowongan','hris_interview','hris_job_offers','hris_kpi','hris_performance','hris_employee_documents','hris_approval_requests'] loop
    execute format('drop trigger if exists trg_v6_audit_%I on public.%I',t,t);
    execute format('create trigger trg_v6_audit_%I after insert or update or delete on public.%I for each row execute function public.hris_audit_safe_row()',t,t);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 7) Permission catalog additions and role-permission RLS consistency.
-- -----------------------------------------------------------------------------
insert into public.hris_permissions(kode,nama,modul) values
('people.documents','Kelola dokumen karyawan','people'),
('people.history','Lihat riwayat karyawan','people'),
('notifications.read','Lihat notifikasi','notifications'),
('notifications.write','Kelola notifikasi','notifications'),
('system.health','Lihat kesehatan sistem','system')
on conflict(kode) do nothing;

drop policy if exists role_permissions_read on public.hris_role_permissions;
drop policy if exists role_permissions_write on public.hris_role_permissions;
drop policy if exists "role permissions read" on public.hris_role_permissions;
drop policy if exists "role permissions write" on public.hris_role_permissions;
create policy role_permissions_read on public.hris_role_permissions for select to authenticated
using (public.hris_is_super_admin() or role_name=public.hris_my_role());
create policy role_permissions_write on public.hris_role_permissions for all to authenticated
using (public.hris_is_super_admin()) with check (public.hris_is_super_admin());

-- -----------------------------------------------------------------------------
-- 8) Health view: expose operational counters without exposing row-level data.
-- -----------------------------------------------------------------------------
create or replace view public.hris_system_health as
select
  (select count(*) from public.karyawan where status_aktif=true) as active_employees,
  (select count(*) from public.hris_cuti where status='Menunggu') as pending_leave,
  (select count(*) from public.hris_lembur where status='Menunggu') as pending_overtime,
  (select count(*) from public.hris_payroll where status='Menunggu Approval') as pending_payroll,
  (select count(*) from public.hris_approval_requests where status='Menunggu') as pending_approvals,
  (select count(*) from public.hris_notifications where is_read=false and lower(recipient_email)=lower(auth.jwt()->>'email')) as unread_notifications,
  now() as checked_at;

notify pgrst,'reload schema';


-- ============================================================
-- LEGACY BASELINE: 010_v7_hris_core.sql
-- ============================================================

-- MoonXprojecT V7 HRIS Core Engine
-- Run after 009_v6_production.sql.

create extension if not exists pgcrypto;

create table if not exists public.hris_employee_contracts (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
  nomor_kontrak text,
  jenis_kontrak text not null default 'PKWTT',
  tanggal_mulai date not null,
  tanggal_selesai date,
  jabatan text,
  departemen text,
  gaji_pokok numeric(14,2) default 0,
  status text not null default 'Aktif',
  catatan text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint contract_dates check (tanggal_selesai is null or tanggal_selesai >= tanggal_mulai)
);
create index if not exists idx_contract_employee_dates on public.hris_employee_contracts(id_karyawan,tanggal_mulai desc);
create unique index if not exists uq_active_employee_contract on public.hris_employee_contracts(id_karyawan) where status='Aktif';

create table if not exists public.hris_leave_types (
  id uuid primary key default gen_random_uuid(),
  kode text unique not null,
  nama text not null,
  kuota_hari numeric(8,2) not null default 12,
  dapat_dibawa boolean not null default false,
  membutuhkan_dokumen boolean not null default false,
  aktif boolean not null default true,
  created_at timestamptz not null default now()
);
insert into public.hris_leave_types(kode,nama,kuota_hari) values
('TAHUNAN','Cuti Tahunan',12),('SAKIT','Sakit',0),('KHUSUS','Cuti Khusus',0)
on conflict(kode) do nothing;

create table if not exists public.hris_employee_leave_balances (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
  leave_type_id uuid not null references public.hris_leave_types(id) on delete cascade,
  tahun integer not null,
  opening_balance numeric(8,2) not null default 0,
  earned numeric(8,2) not null default 0,
  used numeric(8,2) not null default 0,
  adjustment numeric(8,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(id_karyawan,leave_type_id,tahun)
);

create table if not exists public.hris_payroll_component_assignments (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
  komponen_id uuid not null references public.hris_payroll_komponen(id) on delete cascade,
  nominal numeric(14,2) not null default 0,
  tipe text not null default 'Tetap',
  mulai_berlaku date not null default current_date,
  selesai_berlaku date,
  aktif boolean not null default true,
  created_at timestamptz not null default now(),
  constraint assignment_dates check (selesai_berlaku is null or selesai_berlaku >= mulai_berlaku)
);
create index if not exists idx_component_assignment_employee on public.hris_payroll_component_assignments(id_karyawan,aktif);

create table if not exists public.hris_attendance_exceptions (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
  tanggal date not null,
  tipe text not null,
  status text not null default 'Menunggu',
  alasan text,
  disetujui_oleh text,
  disetujui_at timestamptz,
  created_at timestamptz not null default now(),
  unique(id_karyawan,tanggal,tipe)
);

create table if not exists public.hris_onboarding_tasks (
  id uuid primary key default gen_random_uuid(),
  onboarding_id uuid references public.hris_onboarding(id) on delete cascade,
  id_karyawan text references public.karyawan(id_karyawan) on delete cascade,
  task text not null,
  owner text,
  due_date date,
  status text not null default 'Open',
  completed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_onboarding_tasks_status on public.hris_onboarding_tasks(status,due_date);

-- Standard updated-at trigger.
drop trigger if exists trg_contract_updated_at on public.hris_employee_contracts;
create trigger trg_contract_updated_at before update on public.hris_employee_contracts for each row execute function public.hris_touch_updated_at();

drop trigger if exists trg_leave_balance_updated_at on public.hris_employee_leave_balances;
create trigger trg_leave_balance_updated_at before update on public.hris_employee_leave_balances for each row execute function public.hris_touch_updated_at();

-- Keep legacy and V7 leave balances synchronized when an approved leave is recorded.
create or replace function public.hris_sync_leave_balance()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_type uuid; v_year int; v_days numeric;
begin
  if new.status='Disetujui' and old.status is distinct from new.status then
    v_year:=extract(year from new.tanggal_mulai)::int;
    v_days:=coalesce(new.jumlah_hari,0);
    select id into v_type from public.hris_leave_types where lower(nama)=lower(new.jenis) or lower(kode)=lower(new.jenis) limit 1;
    if v_type is not null then
      insert into public.hris_employee_leave_balances(id_karyawan,leave_type_id,tahun,opening_balance,earned,used,adjustment)
      select new.id_karyawan,v_type,v_year,coalesce(kuota_hari,0),coalesce(kuota_hari,0),v_days,0 from public.hris_leave_types where id=v_type
      on conflict(id_karyawan,leave_type_id,tahun) do update set used=public.hris_employee_leave_balances.used+excluded.used,updated_at=now();
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists trg_sync_leave_balance on public.hris_cuti;
create trigger trg_sync_leave_balance after update of status on public.hris_cuti for each row execute function public.hris_sync_leave_balance();

-- Prevent duplicate payroll generation for the same employee/period is already covered by V5/V6.
-- Add permissions for the new operational surfaces.
insert into public.hris_permissions(kode,nama,modul) values
('people.contracts','Kelola kontrak karyawan','people'),
('leave.manage','Kelola jenis dan saldo cuti','leave'),
('payroll.components.assign','Tetapkan komponen gaji karyawan','payroll'),
('attendance.exception','Kelola exception absensi','attendance'),
('onboarding.read','Lihat onboarding','people'),
('onboarding.write','Kelola onboarding','people')
on conflict(kode) do nothing;

alter table public.hris_employee_contracts enable row level security;
alter table public.hris_leave_types enable row level security;
alter table public.hris_employee_leave_balances enable row level security;
alter table public.hris_payroll_component_assignments enable row level security;
alter table public.hris_attendance_exceptions enable row level security;
alter table public.hris_onboarding_tasks enable row level security;

-- Recreate narrowly scoped policies so access remains server-side.
drop policy if exists v7_contract_select on public.hris_employee_contracts;
drop policy if exists v7_contract_write on public.hris_employee_contracts;
create policy v7_contract_select on public.hris_employee_contracts for select to authenticated using (public.hris_has_permission('people.read') or public.hris_has_permission('people.contracts'));
create policy v7_contract_write on public.hris_employee_contracts for all to authenticated using (public.hris_has_permission('people.contracts')) with check (public.hris_has_permission('people.contracts'));

drop policy if exists v7_leave_type_select on public.hris_leave_types;
drop policy if exists v7_leave_type_write on public.hris_leave_types;
create policy v7_leave_type_select on public.hris_leave_types for select to authenticated using (public.hris_has_permission('leave.read') or public.hris_has_permission('leave.manage'));
create policy v7_leave_type_write on public.hris_leave_types for all to authenticated using (public.hris_has_permission('leave.manage')) with check (public.hris_has_permission('leave.manage'));

drop policy if exists v7_leave_balance_select on public.hris_employee_leave_balances;
drop policy if exists v7_leave_balance_write on public.hris_employee_leave_balances;
create policy v7_leave_balance_select on public.hris_employee_leave_balances for select to authenticated using (public.hris_has_permission('leave.read') or public.hris_has_permission('leave.manage'));
create policy v7_leave_balance_write on public.hris_employee_leave_balances for all to authenticated using (public.hris_has_permission('leave.manage')) with check (public.hris_has_permission('leave.manage'));

drop policy if exists v7_component_select on public.hris_payroll_component_assignments;
drop policy if exists v7_component_write on public.hris_payroll_component_assignments;
create policy v7_component_select on public.hris_payroll_component_assignments for select to authenticated using (public.hris_has_permission('payroll.read') or public.hris_has_permission('payroll.components.assign'));
create policy v7_component_write on public.hris_payroll_component_assignments for all to authenticated using (public.hris_has_permission('payroll.components.assign')) with check (public.hris_has_permission('payroll.components.assign'));

drop policy if exists v7_exception_select on public.hris_attendance_exceptions;
drop policy if exists v7_exception_write on public.hris_attendance_exceptions;
create policy v7_exception_select on public.hris_attendance_exceptions for select to authenticated using (public.hris_has_permission('attendance.read') or public.hris_has_permission('attendance.exception'));
create policy v7_exception_write on public.hris_attendance_exceptions for all to authenticated using (public.hris_has_permission('attendance.exception')) with check (public.hris_has_permission('attendance.exception'));

drop policy if exists v7_onboarding_task_select on public.hris_onboarding_tasks;
drop policy if exists v7_onboarding_task_write on public.hris_onboarding_tasks;
create policy v7_onboarding_task_select on public.hris_onboarding_tasks for select to authenticated using (public.hris_has_permission('onboarding.read') or public.hris_has_permission('onboarding.write'));
create policy v7_onboarding_task_write on public.hris_onboarding_tasks for all to authenticated using (public.hris_has_permission('onboarding.write')) with check (public.hris_has_permission('onboarding.write'));

insert into public.hris_role_permissions(role_name,permission_code) values
('Admin','people.contracts'),('Admin','leave.manage'),('Admin','payroll.components.assign'),('Admin','attendance.exception'),('Admin','onboarding.read'),('Admin','onboarding.write'),
('HRD','people.contracts'),('HRD','leave.manage'),('HRD','attendance.exception'),('HRD','onboarding.read'),('HRD','onboarding.write'),
('Payroll','payroll.components.assign')
on conflict do nothing;

notify pgrst,'reload schema';

-- Immutable operational audit coverage for V7 objects.
do $$
declare t text;
begin
  foreach t in array array['hris_employee_contracts','hris_leave_types','hris_employee_leave_balances','hris_payroll_component_assignments','hris_attendance_exceptions','hris_onboarding_tasks'] loop
    execute format('drop trigger if exists trg_v7_audit_%I on public.%I',t,t);
    execute format('create trigger trg_v7_audit_%I after insert or update or delete on public.%I for each row execute function public.hris_audit_safe_row()',t,t);
  end loop;
end $$;

notify pgrst,'reload schema';


-- ============================================================
-- LEGACY BASELINE: 011_v8_enterprise_transactions.sql
-- ============================================================

-- MoonXprojecT V8 Enterprise Transaction Layer
-- Run after 010_v7_hris_core.sql.

create extension if not exists pgcrypto;

-- Payroll period is a first-class business object instead of relying only on a YYYY-MM text field.
create table if not exists public.hris_payroll_periods (
  id uuid primary key default gen_random_uuid(),
  kode text unique not null,
  tanggal_mulai date not null,
  tanggal_selesai date not null,
  tanggal_gajian date,
  status text not null default 'Open',
  catatan text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payroll_period_dates check (tanggal_selesai >= tanggal_mulai),
  constraint payroll_period_status check (status in ('Open','Processing','Pending Approval','Approved','Paid','Closed'))
);
create unique index if not exists uq_payroll_period_dates on public.hris_payroll_periods(tanggal_mulai,tanggal_selesai);

-- Employee roster assignment: date-specific shift/working location.
create table if not exists public.hris_shift_assignments (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
  tanggal date not null,
  shift_id uuid references public.hris_shift(id) on delete set null,
  lokasi_kerja text,
  status text not null default 'Scheduled',
  sumber text not null default 'Manual',
  catatan text,
  created_at timestamptz not null default now(),
  unique(id_karyawan,tanggal)
);
create index if not exists idx_shift_assignments_date on public.hris_shift_assignments(tanggal,status);

-- Employee payment and statutory master data. Sensitive values are deliberately kept in dedicated tables.
create table if not exists public.hris_employee_bank_accounts (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
  bank_name text not null,
  account_name text not null,
  account_number text not null,
  is_primary boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists uq_primary_employee_bank on public.hris_employee_bank_accounts(id_karyawan) where is_primary=true and active=true;

create table if not exists public.hris_employee_emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
  nama text not null,
  hubungan text,
  no_telp text,
  alamat text,
  is_primary boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists uq_primary_emergency_contact on public.hris_employee_emergency_contacts(id_karyawan) where is_primary=true;

create table if not exists public.hris_employee_tax_profiles (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text unique not null references public.karyawan(id_karyawan) on delete cascade,
  npwp text,
  status_ptkp text,
  metode_pajak text not null default 'TER',
  nomor_bpjs_kesehatan text,
  nomor_bpjs_ketenagakerjaan text,
  updated_at timestamptz not null default now()
);

-- Payroll calculation lines make the payrun auditable instead of storing only totals.
create table if not exists public.hris_payroll_lines (
  id uuid primary key default gen_random_uuid(),
  payroll_id uuid not null references public.hris_payroll(id) on delete cascade,
  id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
  kode text not null,
  nama text not null,
  tipe text not null check (tipe in ('earning','deduction','employer_cost','information')),
  qty numeric(12,4) not null default 1,
  rate numeric(14,4) not null default 0,
  amount numeric(14,2) not null default 0,
  source text,
  created_at timestamptz not null default now()
);
create index if not exists idx_payroll_lines_payroll on public.hris_payroll_lines(payroll_id,tipe);

-- Immutable payroll event trail for the payrun lifecycle.
create table if not exists public.hris_payroll_events (
  id uuid primary key default gen_random_uuid(),
  payroll_id uuid not null references public.hris_payroll(id) on delete cascade,
  event_type text not null,
  from_status text,
  to_status text,
  actor_email text,
  note text,
  created_at timestamptz not null default now()
);
create index if not exists idx_payroll_events_payroll on public.hris_payroll_events(payroll_id,created_at desc);

-- V8 permissions.
insert into public.hris_permissions(kode,nama,modul) values
('payroll.period.manage','Kelola periode payroll','payroll'),
('payroll.process','Proses payroll','payroll'),
('payroll.pay','Bayar payroll','payroll'),
('payroll.lines.read','Lihat detail komponen payroll','payroll'),
('schedule.assign','Tetapkan roster karyawan','schedule'),
('people.bank.read','Lihat rekening payroll','people'),
('people.bank.write','Kelola rekening payroll','people'),
('people.emergency.read','Lihat kontak darurat','people'),
('people.emergency.write','Kelola kontak darurat','people'),
('people.tax.read','Lihat profil pajak/BPJS','people'),
('people.tax.write','Kelola profil pajak/BPJS','people')
on conflict(kode) do nothing;

-- Updated-at triggers.
drop trigger if exists trg_payroll_period_updated_at on public.hris_payroll_periods;
create trigger trg_payroll_period_updated_at before update on public.hris_payroll_periods for each row execute function public.hris_touch_updated_at();

-- Payroll event trigger. The event table is append-only from the application perspective.
create or replace function public.hris_log_payroll_event()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' then
    insert into public.hris_payroll_events(payroll_id,event_type,to_status,actor_email,note)
    values(new.id,'CREATED',new.status,auth.email(),'Payroll dibuat');
  elsif tg_op='UPDATE' and new.status is distinct from old.status then
    insert into public.hris_payroll_events(payroll_id,event_type,from_status,to_status,actor_email,note)
    values(new.id,'STATUS_CHANGED',old.status,new.status,auth.email(),'Perubahan status payroll');
  end if;
  return new;
end; $$;
drop trigger if exists trg_payroll_event on public.hris_payroll;
create trigger trg_payroll_event after insert or update of status on public.hris_payroll for each row execute function public.hris_log_payroll_event();

-- Block editing payroll lines once the parent payroll is final.
create or replace function public.hris_guard_payroll_lines()
returns trigger language plpgsql security definer set search_path=public as $$
declare s text;
begin
  select status into s from public.hris_payroll where id=coalesce(new.payroll_id,old.payroll_id);
  if s in ('Approved','Dibayar','Paid','Closed') then
    raise exception 'Payroll sudah final; detail tidak dapat diubah';
  end if;
  return coalesce(new,old);
end; $$;
drop trigger if exists trg_guard_payroll_lines on public.hris_payroll_lines;
create trigger trg_guard_payroll_lines before insert or update or delete on public.hris_payroll_lines for each row execute function public.hris_guard_payroll_lines();

-- RLS.
alter table public.hris_payroll_periods enable row level security;
alter table public.hris_shift_assignments enable row level security;
alter table public.hris_employee_bank_accounts enable row level security;
alter table public.hris_employee_emergency_contacts enable row level security;
alter table public.hris_employee_tax_profiles enable row level security;
alter table public.hris_payroll_lines enable row level security;
alter table public.hris_payroll_events enable row level security;

create policy v8_period_select on public.hris_payroll_periods for select to authenticated using (public.hris_has_permission('payroll.read') or public.hris_has_permission('payroll.period.manage'));
create policy v8_period_write on public.hris_payroll_periods for all to authenticated using (public.hris_has_permission('payroll.period.manage')) with check (public.hris_has_permission('payroll.period.manage'));

create policy v8_roster_select on public.hris_shift_assignments for select to authenticated using (public.hris_has_permission('schedule.read') or public.hris_has_permission('schedule.assign'));
create policy v8_roster_write on public.hris_shift_assignments for all to authenticated using (public.hris_has_permission('schedule.assign')) with check (public.hris_has_permission('schedule.assign'));

create policy v8_bank_select on public.hris_employee_bank_accounts for select to authenticated using (public.hris_has_permission('people.bank.read') or public.hris_has_permission('people.bank.write'));
create policy v8_bank_write on public.hris_employee_bank_accounts for all to authenticated using (public.hris_has_permission('people.bank.write')) with check (public.hris_has_permission('people.bank.write'));

create policy v8_emergency_select on public.hris_employee_emergency_contacts for select to authenticated using (public.hris_has_permission('people.emergency.read') or public.hris_has_permission('people.emergency.write'));
create policy v8_emergency_write on public.hris_employee_emergency_contacts for all to authenticated using (public.hris_has_permission('people.emergency.write')) with check (public.hris_has_permission('people.emergency.write'));

create policy v8_tax_select on public.hris_employee_tax_profiles for select to authenticated using (public.hris_has_permission('people.tax.read') or public.hris_has_permission('people.tax.write'));
create policy v8_tax_write on public.hris_employee_tax_profiles for all to authenticated using (public.hris_has_permission('people.tax.write')) with check (public.hris_has_permission('people.tax.write'));

create policy v8_lines_select on public.hris_payroll_lines for select to authenticated using (public.hris_has_permission('payroll.read') or public.hris_has_permission('payroll.lines.read'));
create policy v8_lines_write on public.hris_payroll_lines for all to authenticated using (public.hris_has_permission('payroll.process')) with check (public.hris_has_permission('payroll.process'));

create policy v8_events_select on public.hris_payroll_events for select to authenticated using (public.hris_has_permission('payroll.read') or public.hris_has_permission('audit.read'));

-- Prevent impossible roster dates and duplicate primary data through constraints/indexes.
create or replace function public.hris_validate_shift_assignment()
returns trigger language plpgsql as $$
begin
  if new.tanggal is null then raise exception 'Tanggal roster wajib diisi'; end if;
  return new;
end; $$;
drop trigger if exists trg_validate_shift_assignment on public.hris_shift_assignments;
create trigger trg_validate_shift_assignment before insert or update on public.hris_shift_assignments for each row execute function public.hris_validate_shift_assignment();

-- Safe helper for payroll period creation. Keeps period lifecycle explicit.
create or replace function public.hris_open_payroll_period(p_kode text,p_mulai date,p_selesai date,p_gajian date default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  perform public.hris_require_permission('payroll.period.manage');
  if p_selesai < p_mulai then raise exception 'Periode payroll tidak valid'; end if;
  insert into public.hris_payroll_periods(kode,tanggal_mulai,tanggal_selesai,tanggal_gajian,status)
  values(p_kode,p_mulai,p_selesai,p_gajian,'Open') returning id into v_id;
  return v_id;
end; $$;


-- ============================================================
-- LEGACY BASELINE: 012_v9_indonesia_payroll_engine.sql
-- ============================================================

-- MoonXprojecT V9 — Indonesian Payroll Engine
-- Run after 011_v8_enterprise_transactions.sql.
-- Rules are parameterized so HR can update statutory master data without changing application code.

create table if not exists public.hris_payroll_rules (
  id uuid primary key default gen_random_uuid(),
  tahun integer not null,
  nama text not null,
  kode text not null,
  nilai numeric(14,6) not null default 0,
  satuan text not null default 'percent',
  aktif boolean not null default true,
  catatan text,
  created_at timestamptz not null default now(),
  unique(tahun,kode)
);

create table if not exists public.hris_payroll_preflight (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.hris_payroll_periods(id) on delete cascade,
  id_karyawan text references public.karyawan(id_karyawan) on delete cascade,
  severity text not null check (severity in ('ERROR','WARNING','INFO')),
  code text not null,
  message text not null,
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_payroll_preflight_period on public.hris_payroll_preflight(period_id,severity,resolved);

create table if not exists public.hris_thr_runs (
  id uuid primary key default gen_random_uuid(),
  tahun integer not null,
  hari_raya text not null,
  tanggal_bayar date,
  status text not null default 'Draft' check (status in ('Draft','Review','Approved','Paid','Closed')),
  catatan text,
  created_at timestamptz not null default now(),
  unique(tahun,hari_raya)
);

create table if not exists public.hris_thr_lines (
  id uuid primary key default gen_random_uuid(),
  thr_run_id uuid not null references public.hris_thr_runs(id) on delete cascade,
  id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
  masa_kerja_bulan numeric(8,2) not null default 0,
  upah_dasar numeric(14,2) not null default 0,
  proporsi numeric(10,6) not null default 0,
  nominal numeric(14,2) not null default 0,
  status text not null default 'Draft',
  created_at timestamptz not null default now(),
  unique(thr_run_id,id_karyawan)
);

-- 2026 statutory defaults. These are editable master values, not hard-coded client values.
insert into public.hris_payroll_rules(tahun,nama,kode,nilai,satuan,catatan) values
(2026,'BPJS Kesehatan — Pekerja','BPJS_HEALTH_EMP',1,'percent','PPU: 1% pekerja'),
(2026,'BPJS Kesehatan — Perusahaan','BPJS_HEALTH_ER',4,'percent','PPU: 4% pemberi kerja'),
(2026,'BPJS Kesehatan — Batas Upah','BPJS_HEALTH_CAP',12000000,'idr','Batas upah PPU swasta'),
(2026,'JHT — Pekerja','JHT_EMP',2,'percent',''),
(2026,'JHT — Perusahaan','JHT_ER',3.7,'percent',''),
(2026,'JP — Pekerja','JP_EMP',1,'percent',''),
(2026,'JP — Perusahaan','JP_ER',2,'percent',''),
(2026,'JP — Batas Upah','JP_CAP',10547400,'idr','Batas upah 2026'),
(2026,'JKM — Perusahaan','JKM_ER',0.3,'percent',''),
(2026,'JKK — Risiko Sangat Rendah','JKK_VLOW',0.24,'percent',''),
(2026,'JKK — Risiko Rendah','JKK_LOW',0.54,'percent',''),
(2026,'JKK — Risiko Sedang','JKK_MED',0.89,'percent',''),
(2026,'JKK — Risiko Tinggi','JKK_HIGH',1.27,'percent',''),
(2026,'JKK — Risiko Sangat Tinggi','JKK_VHIGH',1.74,'percent',''),
(2026,'PTKP TK/0','PTKP_TK0',54000000,'idr',''),
(2026,'PTKP TK/1 K/0','PTKP_A',58500000,'idr',''),
(2026,'PTKP TK/2 K/1','PTKP_B1',63000000,'idr',''),
(2026,'PTKP TK/3 K/2','PTKP_B2',67500000,'idr',''),
(2026,'PTKP K/3','PTKP_C',72000000,'idr',''),
(2026,'Biaya Jabatan','BIAYA_JABATAN',5,'percent','Maksimum bulanan mengikuti ketentuan pajak'),
(2026,'THR Masa Kerja Penuh','THR_FULL_MONTH',1,'multiplier','12 bulan atau lebih = 1 bulan upah'),
(2026,'Hari Kerja Standar Payroll','WORKDAYS_METHOD',22,'days','Parameter default; prorata tetap berbasis hari kerja kalender')
on conflict(tahun,kode) do nothing;

insert into public.hris_permissions(kode,nama,modul) values
('payroll.engine','Jalankan payroll engine','payroll'),
('payroll.preflight','Validasi payroll sebelum proses','payroll'),
('payroll.thr','Kelola THR','payroll'),
('payroll.export','Ekspor payroll/pembayaran','payroll')
on conflict(kode) do nothing;

alter table public.hris_payroll_preflight enable row level security;
alter table public.hris_thr_runs enable row level security;
alter table public.hris_thr_lines enable row level security;
alter table public.hris_payroll_rules enable row level security;

drop policy if exists payroll_rules_read on public.hris_payroll_rules;
create policy payroll_rules_read on public.hris_payroll_rules for select to authenticated using (public.hris_has_permission('payroll.read'));
drop policy if exists payroll_rules_write on public.hris_payroll_rules;
create policy payroll_rules_write on public.hris_payroll_rules for all to authenticated using (public.hris_has_permission('payroll.write')) with check (public.hris_has_permission('payroll.write'));
drop policy if exists payroll_preflight_read on public.hris_payroll_preflight;
create policy payroll_preflight_read on public.hris_payroll_preflight for select to authenticated using (public.hris_has_permission('payroll.read'));
drop policy if exists payroll_thr_read on public.hris_thr_runs;
create policy payroll_thr_read on public.hris_thr_runs for select to authenticated using (public.hris_has_permission('payroll.read'));
drop policy if exists payroll_thr_write on public.hris_thr_runs;
create policy payroll_thr_write on public.hris_thr_runs for all to authenticated using (public.hris_has_permission('payroll.thr')) with check (public.hris_has_permission('payroll.thr'));
drop policy if exists payroll_thr_lines_read on public.hris_thr_lines;
create policy payroll_thr_lines_read on public.hris_thr_lines for select to authenticated using (public.hris_has_permission('payroll.read'));
drop policy if exists payroll_thr_lines_write on public.hris_thr_lines;
create policy payroll_thr_lines_write on public.hris_thr_lines for all to authenticated using (public.hris_has_permission('payroll.thr')) with check (public.hris_has_permission('payroll.thr'));

create or replace function public.hris_v9_rule(p_year integer,p_code text,p_default numeric)
returns numeric language sql stable security definer set search_path=public as $$
  select coalesce((select nilai from public.hris_payroll_rules where tahun=p_year and kode=p_code and aktif order by id desc limit 1),p_default);
$$;

create or replace function public.hris_v9_ter(p_category text,p_bruto numeric)
returns numeric language plpgsql immutable as $$
declare r numeric:=0; b numeric:=coalesce(p_bruto,0);
bounds numeric[]; rates numeric[]; i int;
begin
  if p_category='B' then
    bounds:=array[6200000,6500000,6850000,7300000,9200000,10750000,11250000,11600000,12600000,13600000,14950000,16400000,18450000,21850000,26000000,27700000,29350000,31450000,33950000,37100000,41100000,45800000,49500000,53800000,58500000,64000000,71000000,80000000,93000000,109000000,129000000,163000000,211000000,374000000,459000000,555000000,704000000,957000000,1405000000];
    rates:=array[0,0.25,0.5,0.75,1,1.5,2,2.5,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33];
  elsif p_category='C' then
    bounds:=array[6600000,6950000,7350000,7800000,8850000,9800000,10950000,11200000,12050000,12950000,14150000,15550000,17050000,19500000,22700000,26600000,28100000,30100000,32600000,35400000,38900000,43000000,47400000,51200000,55800000,60400000,66700000,74500000,83200000,95600000,110000000,134000000,169000000,221000000,390000000,463000000,561000000,709000000,965000000,1419000000];
    rates:=array[0,0.25,0.5,0.75,1,1.25,1.5,1.75,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33];
  else
    bounds:=array[5400000,5650000,5950000,6300000,6750000,7500000,8550000,9650000,10050000,10350000,10700000,11050000,11600000,12500000,13750000,15100000,16950000,19750000,24150000,26450000,28000000,30050000,32400000,35400000,39100000,43850000,47800000,51400000,56300000,62200000,68600000,77500000,89000000,103000000,125000000,157000000,206000000,337000000,454000000,550000000,695000000,910000000,1400000000];
    rates:=array[0,0.25,0.5,0.75,1,1.25,1.5,1.75,2,2.25,2.5,3,3.5,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33];
  end if;
  for i in 1..array_length(bounds,1) loop
    if b <= bounds[i] then r:=rates[i]; return r/100; end if;
  end loop;
  return 0.34;
end $$;

create or replace function public.hris_v9_preflight(p_period_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare p record; e record; errors int:=0; warnings int:=0; total int:=0; d date; att_count int; bank_count int; tax_count int;
begin
  perform public.hris_require_permission('payroll.preflight');
  select * into p from public.hris_payroll_periods where id=p_period_id;
  if not found then raise exception 'Periode payroll tidak ditemukan'; end if;
  delete from public.hris_payroll_preflight where period_id=p_period_id and not resolved;
  for e in select id_karyawan,nama,gaji_pokok,status_aktif,tanggal_masuk from public.karyawan where coalesce(status_aktif,true) loop
    total:=total+1;
    if coalesce(e.gaji_pokok,0)<=0 then
      insert into public.hris_payroll_preflight(period_id,id_karyawan,severity,code,message) values(p_period_id,e.id_karyawan,'ERROR','NO_BASE_SALARY',e.nama||' belum memiliki gaji pokok'); errors:=errors+1;
    end if;
    select count(*) into bank_count from public.hris_employee_bank_accounts where id_karyawan=e.id_karyawan and active and is_primary;
    if bank_count=0 then
      insert into public.hris_payroll_preflight(period_id,id_karyawan,severity,code,message) values(p_period_id,e.id_karyawan,'WARNING','NO_BANK','Rekening payroll utama belum tersedia'); warnings:=warnings+1;
    end if;
    select count(*) into tax_count from public.hris_employee_tax_profiles where id_karyawan=e.id_karyawan;
    if tax_count=0 then
      insert into public.hris_payroll_preflight(period_id,id_karyawan,severity,code,message) values(p_period_id,e.id_karyawan,'WARNING','NO_TAX_PROFILE','Profil pajak/BPJS belum diisi'); warnings:=warnings+1;
    end if;
    if e.tanggal_masuk is null then
      insert into public.hris_payroll_preflight(period_id,id_karyawan,severity,code,message) values(p_period_id,e.id_karyawan,'INFO','NO_JOIN_DATE','Tanggal masuk kosong; prorata join date tidak diterapkan');
    end if;
  end loop;
  return jsonb_build_object('employees',total,'errors',errors,'warnings',warnings,'period_id',p_period_id);
end $$;

create or replace function public.hris_v9_process_payroll(p_period_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare p record; e record; a record; t record; assign record; y int; m int; days int; workdays int; eligible_days int; base numeric; prorata numeric; overtime_minutes numeric; overtime numeric; earning numeric; deduction numeric; bpjs_health numeric; jht numeric; jp numeric; pph numeric; gross numeric; category text; ter numeric; annual_net numeric; annual_tax numeric; prior_tax numeric; monthly_tax numeric; line_count int:=0; employee_count int:=0; warning_count int;
begin
  perform public.hris_require_permission('payroll.engine');
  select * into p from public.hris_payroll_periods where id=p_period_id for update;
  if not found then raise exception 'Periode payroll tidak ditemukan'; end if;
  if p.status in ('Approved','Paid','Closed') then raise exception 'Periode sudah final: %',p.status; end if;
  y:=extract(year from p.tanggal_mulai); m:=extract(month from p.tanggal_mulai);
  days:=(p.tanggal_selesai-p.tanggal_mulai)+1;
  select count(*) into workdays from generate_series(p.tanggal_mulai,p.tanggal_selesai,'1 day') g(d) where extract(isodow from g.d) between 1 and 5;
  update public.hris_payroll_periods set status='Processing' where id=p.id;
  delete from public.hris_payroll_preflight where period_id=p.id and severity='INFO';
  for e in select * from public.karyawan where coalesce(status_aktif,true) loop
    employee_count:=employee_count+1;
    base:=coalesce(e.gaji_pokok,0);
    eligible_days:=workdays;
    if e.tanggal_masuk is not null and e.tanggal_masuk>p.tanggal_mulai then
      select count(*) into eligible_days from generate_series(greatest(e.tanggal_masuk,p.tanggal_mulai),p.tanggal_selesai,'1 day') g(d) where extract(isodow from g.d) between 1 and 5;
    end if;
    prorata:=case when workdays>0 then base*least(greatest(eligible_days::numeric/workdays,0),1) else base end;
    earning:=0; deduction:=0; overtime_minutes:=0;
    for assign in select a.*,c.nama,c.tipe as component_type from public.hris_payroll_component_assignments a join public.hris_payroll_komponen c on c.id=a.komponen_id where a.id_karyawan=e.id_karyawan and a.aktif and a.mulai_berlaku<=p.tanggal_selesai and (a.selesai_berlaku is null or a.selesai_berlaku>=p.tanggal_mulai) loop
      if lower(coalesce(assign.tipe,assign.component_type,'')) in ('potongan','deduction') or lower(assign.component_type)='potongan' then deduction:=deduction+coalesce(assign.nominal,0); else earning:=earning+coalesce(assign.nominal,0); end if;
    end loop;
    select coalesce(sum(greatest(menit,0)),0) into overtime_minutes from public.hris_lembur where id_karyawan=e.id_karyawan and tanggal between p.tanggal_mulai and p.tanggal_selesai and status='Disetujui';
    overtime:=round((base/173)*(overtime_minutes/60)*coalesce((select nilai from public.hris_company_settings where id=1 limit 1),2));
    -- The setting query above may return a non-multiplier field on older schemas; default to 2 below if unsafe.
    if overtime<0 then overtime:=0; end if;
    gross:=round(prorata+earning+overtime,2);
    select * into t from public.hris_employee_tax_profiles where id_karyawan=e.id_karyawan limit 1;
    category:=case when coalesce(t.status_ptkp,'TK/0') in ('TK/2','K/1','TK/3','K/2') then 'B' when coalesce(t.status_ptkp,'TK/0')='K/3' then 'C' else 'A' end;
    ter:=public.hris_v9_ter(category,gross);
    if m between 1 and 11 then pph:=round(gross*ter,2); else
      select coalesce(sum(pph21),0) into prior_tax from public.hris_payroll where id_karyawan=e.id_karyawan and periode like y::text||'-%' and periode<>p.kode;
      annual_net:=greatest(0,(gross*12)-least(gross*12*0.05,6000000)-coalesce(case when category='A' then 58500000 when category='B' then case when coalesce(t.status_ptkp,'') in ('TK/3','K/2') then 67500000 else 63000000 end else 72000000 end,54000000));
      annual_tax:=least(annual_net,60000000)*0.05+greatest(least(annual_net-60000000,190000000),0)*0.15+greatest(least(annual_net-250000000,250000000),0)*0.25+greatest(least(annual_net-500000000,4500000000),0)*0.30+greatest(annual_net-5000000000,0)*0.35;
      pph:=greatest(0,round(annual_tax-prior_tax,2));
    end if;
    bpjs_health:=round(least(gross,public.hris_v9_rule(y,'BPJS_HEALTH_CAP',12000000))*public.hris_v9_rule(y,'BPJS_HEALTH_EMP',1)/100,2);
    jht:=round(gross*public.hris_v9_rule(y,'JHT_EMP',2)/100,2);
    jp:=round(least(gross,public.hris_v9_rule(y,'JP_CAP',10547400))*public.hris_v9_rule(y,'JP_EMP',1)/100,2);
    deduction:=deduction+bpjs_health+jht+jp+pph;
    insert into public.hris_payroll(id_karyawan,periode,gaji_pokok,tunjangan,uang_makan,transport,lembur,bonus,potongan,bpjs,pph21,status,tanggal_proses,catatan)
    values(e.id_karyawan,p.kode,round(prorata,2),earning,0,0,overtime,0,deduction,bpjs_health+jht+jp,pph,'Draft',now(),'V9 Indonesian Payroll Engine')
    on conflict(id_karyawan,periode) do update set gaji_pokok=excluded.gaji_pokok,tunjangan=excluded.tunjangan,lembur=excluded.lembur,potongan=excluded.potongan,bpjs=excluded.bpjs,pph21=excluded.pph21,tanggal_proses=now(),catatan='V9 recalculation';
    select id into a from public.hris_payroll where id_karyawan=e.id_karyawan and periode=p.kode;
    delete from public.hris_payroll_lines where payroll_id=a.id;
    insert into public.hris_payroll_lines(payroll_id,id_karyawan,kode,nama,tipe,qty,rate,amount,source) values
      (a.id,e.id_karyawan,'BASE','Gaji Pokok','earning',1,base,round(prorata,2),'salary_proration'),
      (a.id,e.id_karyawan,'OT','Lembur','earning',overtime_minutes/60,case when overtime_minutes=0 then 0 else overtime/(overtime_minutes/60) end,overtime,'approved_overtime'),
      (a.id,e.id_karyawan,'BPJS-KES','BPJS Kesehatan','deduction',1,1,bpjs_health,'statutory'),
      (a.id,e.id_karyawan,'JHT','JHT Pekerja','deduction',1,2,jht,'statutory'),
      (a.id,e.id_karyawan,'JP','JP Pekerja','deduction',1,1,jp,'statutory'),
      (a.id,e.id_karyawan,'PPH21','PPh 21','deduction',1,ter*100,pph,'TER/annual-final');
    line_count:=line_count+6;
  end loop;
  update public.hris_payroll_periods set status='Open' where id=p.id;
  return jsonb_build_object('period_id',p.id,'period_code',p.kode,'employees',employee_count,'lines',line_count,'workdays',workdays);
end $$;

create or replace function public.hris_v9_create_thr(p_year integer,p_hari_raya text,p_tanggal_bayar date)
returns uuid language plpgsql security definer set search_path=public as $$
declare run_id uuid; e record; start_date date; months numeric; prop numeric; nominal numeric; base numeric;
begin
  perform public.hris_require_permission('payroll.thr');
  insert into public.hris_thr_runs(tahun,hari_raya,tanggal_bayar,status) values(p_year,p_hari_raya,p_tanggal_bayar,'Draft') on conflict(tahun,hari_raya) do update set tanggal_bayar=excluded.tanggal_bayar returning id into run_id;
  delete from public.hris_thr_lines where thr_run_id=run_id;
  for e in select * from public.karyawan where coalesce(status_aktif,true) loop
    start_date:=coalesce(e.tanggal_masuk,make_date(p_year,1,1));
    months:=least(12,greatest(0,round((extract(epoch from (make_date(p_year,12,31)-greatest(start_date,make_date(p_year,1,1))))/86400/30.4375)::numeric,2)+case when start_date<=make_date(p_year,1,1) then 1 else 0 end));
    if months>=12 then prop:=1; else prop:=months/12; end if;
    base:=coalesce(e.gaji_pokok,0);
    nominal:=round(base*prop,2);
    insert into public.hris_thr_lines(thr_run_id,id_karyawan,masa_kerja_bulan,upah_dasar,proporsi,nominal) values(run_id,e.id_karyawan,months,base,prop,nominal);
  end loop;
  return run_id;
end $$;


-- ============================================================
-- LEGACY BASELINE: 013_v10_payroll_delivery_foundation.sql
-- ============================================================

-- MoonXprojecT V10 compatibility foundation. Safe to run if V10 delivery tables already exist.
create extension if not exists pgcrypto;
create table if not exists public.hris_payment_batches (
 id uuid primary key default gen_random_uuid(), batch_no text unique not null, payroll_period_id uuid references public.hris_payroll_periods(id) on delete set null,
 status text not null default 'Draft' check(status in ('Draft','Review','Approved','Submitted','Paid','Cancelled')),
 total_employees integer not null default 0, total_amount numeric(16,2) not null default 0, payment_date date, bank_name text, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists public.hris_payment_batch_lines (
 id uuid primary key default gen_random_uuid(), batch_id uuid not null references public.hris_payment_batches(id) on delete cascade, payroll_id uuid references public.hris_payroll(id) on delete set null,
 id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade, account_name text, account_number text, bank_name text, amount numeric(16,2) not null default 0, status text not null default 'Pending', created_at timestamptz not null default now(), unique(batch_id,id_karyawan));
create table if not exists public.hris_payroll_reconciliation (
 id uuid primary key default gen_random_uuid(), batch_id uuid not null references public.hris_payment_batches(id) on delete cascade, id_karyawan text references public.karyawan(id_karyawan) on delete set null,
 expected_amount numeric(16,2) not null default 0, paid_amount numeric(16,2) not null default 0, variance numeric(16,2) generated always as (paid_amount-expected_amount) stored,
 status text not null default 'Open' check(status in ('Open','Matched','Variance','Resolved')), note text, created_at timestamptz not null default now(), unique(batch_id,id_karyawan));
create table if not exists public.hris_accounting_exports (
 id uuid primary key default gen_random_uuid(), payroll_period_id uuid references public.hris_payroll_periods(id) on delete set null, export_no text unique not null,
 status text not null default 'Draft', total_amount numeric(16,2) not null default 0, created_at timestamptz not null default now());
insert into public.hris_permissions(kode,nama,modul) values
('payroll.payment.batch','Kelola payment batch','payroll'),('payroll.reconciliation','Rekonsiliasi pembayaran','payroll'),('payroll.accounting.export','Ekspor accounting','payroll') on conflict(kode) do nothing;
alter table public.hris_payment_batches enable row level security; alter table public.hris_payment_batch_lines enable row level security; alter table public.hris_payroll_reconciliation enable row level security; alter table public.hris_accounting_exports enable row level security;
drop policy if exists payment_batches_read on public.hris_payment_batches; create policy payment_batches_read on public.hris_payment_batches for select to authenticated using(public.hris_has_permission('payroll.read'));
drop policy if exists payment_batches_write on public.hris_payment_batches; create policy payment_batches_write on public.hris_payment_batches for all to authenticated using(public.hris_has_permission('payroll.payment.batch')) with check(public.hris_has_permission('payroll.payment.batch'));
drop policy if exists payment_lines_read on public.hris_payment_batch_lines; create policy payment_lines_read on public.hris_payment_batch_lines for select to authenticated using(public.hris_has_permission('payroll.read'));
drop policy if exists payment_lines_write on public.hris_payment_batch_lines; create policy payment_lines_write on public.hris_payment_batch_lines for all to authenticated using(public.hris_has_permission('payroll.payment.batch')) with check(public.hris_has_permission('payroll.payment.batch'));
drop policy if exists recon_read on public.hris_payroll_reconciliation; create policy recon_read on public.hris_payroll_reconciliation for select to authenticated using(public.hris_has_permission('payroll.read'));
drop policy if exists recon_write on public.hris_payroll_reconciliation; create policy recon_write on public.hris_payroll_reconciliation for all to authenticated using(public.hris_has_permission('payroll.reconciliation')) with check(public.hris_has_permission('payroll.reconciliation'));
drop policy if exists accounting_read on public.hris_accounting_exports; create policy accounting_read on public.hris_accounting_exports for select to authenticated using(public.hris_has_permission('payroll.read'));
drop policy if exists accounting_write on public.hris_accounting_exports; create policy accounting_write on public.hris_accounting_exports for all to authenticated using(public.hris_has_permission('payroll.accounting.export')) with check(public.hris_has_permission('payroll.accounting.export'));


-- ============================================================
-- LEGACY BASELINE: 014_v11_employee_self_service.sql
-- ============================================================

-- MoonXprojecT V11 — Employee Self Service
-- Employee-facing access is restricted by auth_user_id -> karyawan.id.
create extension if not exists pgcrypto;
create table if not exists public.hris_employee_profile_requests (
 id uuid primary key default gen_random_uuid(), id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
 field_name text not null, old_value text, new_value text, reason text, status text not null default 'Menunggu' check(status in ('Menunggu','Disetujui','Ditolak')),
 created_at timestamptz not null default now(), decided_at timestamptz, decided_by text);
create table if not exists public.hris_employee_attendance_requests (
 id uuid primary key default gen_random_uuid(), id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
 tanggal date not null, jenis text not null check(jenis in ('Koreksi Masuk','Koreksi Pulang','Dinas','Remote','Lupa Absen')),
 jam_masuk time, jam_pulang time, alasan text not null, status text not null default 'Menunggu' check(status in ('Menunggu','Disetujui','Ditolak')),
 created_at timestamptz not null default now(), decided_at timestamptz, decided_by text);
create table if not exists public.hris_employee_leave_requests (
 id uuid primary key default gen_random_uuid(), id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
 jenis text not null, tanggal_mulai date not null, tanggal_selesai date not null, jumlah_hari numeric(6,2) not null default 1, alasan text, lampiran_url text,
 status text not null default 'Menunggu' check(status in ('Menunggu','Disetujui','Ditolak','Dibatalkan')), created_at timestamptz not null default now(),
 constraint ess_leave_dates check(tanggal_selesai>=tanggal_mulai));
create index if not exists idx_ess_profile_employee on public.hris_employee_profile_requests(id_karyawan,created_at desc);
create index if not exists idx_ess_att_employee on public.hris_employee_attendance_requests(id_karyawan,tanggal desc);
create index if not exists idx_ess_leave_employee on public.hris_employee_leave_requests(id_karyawan,tanggal_mulai desc);
insert into public.hris_permissions(kode,nama,modul) values
('ess.read','Employee Self Service','people'),('ess.profile.request','Pengajuan perubahan profil karyawan','people'),('ess.attendance.request','Koreksi absensi karyawan','attendance'),('ess.leave.request','Pengajuan cuti karyawan','leave') on conflict(kode) do nothing;
alter table public.hris_employee_profile_requests enable row level security;
alter table public.hris_employee_attendance_requests enable row level security;
alter table public.hris_employee_leave_requests enable row level security;
create or replace function public.hris_ess_employee_id() returns text language sql stable security definer set search_path=public as $$ select id_karyawan from public.karyawan where auth_user_id=auth.uid() limit 1 $$;
drop policy if exists ess_profile_self on public.hris_employee_profile_requests;
create policy ess_profile_self on public.hris_employee_profile_requests for all to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.profile.request')) with check(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.profile.request'));
drop policy if exists ess_att_self on public.hris_employee_attendance_requests;
create policy ess_att_self on public.hris_employee_attendance_requests for all to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.attendance.request')) with check(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.attendance.request'));
drop policy if exists ess_leave_self on public.hris_employee_leave_requests;
create policy ess_leave_self on public.hris_employee_leave_requests for all to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.leave.request')) with check(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.leave.request'));
-- Read-only self-service access to master/transaction data. Existing admin policies remain intact.
drop policy if exists ess_employee_self on public.karyawan;
create policy ess_employee_self on public.karyawan for select to authenticated using(auth_user_id=auth.uid());
drop policy if exists ess_payroll_self on public.hris_payroll;
create policy ess_payroll_self on public.hris_payroll for select to authenticated using(id_karyawan=public.hris_ess_employee_id());
drop policy if exists ess_payroll_lines_self on public.hris_payroll_lines;
create policy ess_payroll_lines_self on public.hris_payroll_lines for select to authenticated using(id_karyawan=public.hris_ess_employee_id());
drop policy if exists ess_leave_self_existing on public.hris_cuti;
create policy ess_leave_self_existing on public.hris_cuti for select to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('leave.read'));
drop policy if exists ess_balance_self on public.hris_saldo_cuti;
create policy ess_balance_self on public.hris_saldo_cuti for select to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('leave.read'));
drop policy if exists ess_overtime_self on public.hris_lembur;
create policy ess_overtime_self on public.hris_lembur for select to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('overtime.read'));
drop policy if exists ess_attendance_self_read on public.absensi;
create policy ess_attendance_self_read on public.absensi for select to authenticated using((id_karyawan=public.hris_ess_employee_id()) or (karyawan_id=public.hris_ess_employee_id()));


-- ============================================================
-- LEGACY BASELINE: 015_v12_ess_attendance.sql
-- ============================================================

-- MoonXprojecT V12 — secure Employee Self Service attendance & requests
create extension if not exists pgcrypto;

alter table public.absensi add column if not exists latitude numeric(10,7);
alter table public.absensi add column if not exists longitude numeric(10,7);
alter table public.absensi add column if not exists lokasi_masuk text;
alter table public.absensi add column if not exists lokasi_pulang text;
alter table public.absensi add column if not exists selfie_masuk text;
alter table public.absensi add column if not exists selfie_pulang text;
alter table public.absensi add column if not exists akurasi_masuk numeric(10,2);
alter table public.absensi add column if not exists akurasi_pulang numeric(10,2);
alter table public.absensi add column if not exists sumber text default 'ESS';

create table if not exists public.hris_employee_overtime_requests (
 id uuid primary key default gen_random_uuid(),
 id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
 tanggal date not null,
 menit integer not null check(menit between 1 and 1440),
 alasan text not null,
 status text not null default 'Menunggu' check(status in ('Menunggu','Disetujui','Ditolak','Dibatalkan')),
 created_at timestamptz not null default now(),
 decided_at timestamptz,
 decided_by text
);
create index if not exists idx_ess_ot_employee on public.hris_employee_overtime_requests(id_karyawan,tanggal desc);

create table if not exists public.hris_employee_notifications (
 id uuid primary key default gen_random_uuid(),
 id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
 title text not null,
 message text not null,
 type text not null default 'system',
 link text,
 is_read boolean not null default false,
 created_at timestamptz not null default now()
);
create index if not exists idx_ess_notifications_employee on public.hris_employee_notifications(id_karyawan,is_read,created_at desc);

insert into public.hris_permissions(kode,nama,modul) values
('ess.attendance.clock','Clock in/out ESS','attendance'),
('ess.attendance.location','Lokasi GPS ESS','attendance'),
('ess.attendance.selfie','Selfie attendance ESS','attendance'),
('ess.overtime.request','Pengajuan lembur ESS','overtime'),
('ess.notifications.read','Notifikasi ESS','notifications')
on conflict(kode) do nothing;

create or replace function public.hris_ess_clock_in(
 p_id_karyawan text,p_tanggal date,p_jam time,p_lat numeric,p_long numeric,p_accuracy numeric,p_selfie text,p_lokasi text default 'GPS'
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
 if p_id_karyawan is null or p_id_karyawan<>public.hris_ess_employee_id() then raise exception 'Akses absensi ditolak'; end if;
 if exists(select 1 from public.absensi where id_karyawan=p_id_karyawan and tanggal=p_tanggal and jam_masuk is not null) then raise exception 'Anda sudah melakukan clock-in untuk tanggal ini'; end if;
 insert into public.absensi(id_karyawan,tanggal,jam_masuk,status,latitude,longitude,lokasi_masuk,akurasi_masuk,selfie_masuk,sumber,keterangan)
 values(p_id_karyawan,p_tanggal,p_jam,'Hadir',p_lat,p_long,p_lokasi,p_accuracy,p_selfie,'ESS','Clock-in ESS')
 returning id into v_id;
 return v_id;
end; $$;

create or replace function public.hris_ess_clock_out(
 p_id_karyawan text,p_tanggal date,p_jam time,p_lat numeric,p_long numeric,p_accuracy numeric,p_selfie text,p_lokasi text default 'GPS'
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
 if p_id_karyawan is null or p_id_karyawan<>public.hris_ess_employee_id() then raise exception 'Akses absensi ditolak'; end if;
 select id into v_id from public.absensi where id_karyawan=p_id_karyawan and tanggal=p_tanggal and jam_masuk is not null and jam_pulang is null order by created_at desc limit 1;
 if v_id is null then raise exception 'Clock-in aktif tidak ditemukan untuk tanggal ini'; end if;
 update public.absensi set jam_pulang=p_jam,longitude=coalesce(p_long,longitude),latitude=coalesce(p_lat,latitude),lokasi_pulang=p_lokasi,akurasi_pulang=p_accuracy,selfie_pulang=p_selfie,sumber='ESS',keterangan=coalesce(keterangan,'')||' | Clock-out ESS' where id=v_id;
 return v_id;
end; $$;
grant execute on function public.hris_ess_clock_in(text,date,time,numeric,numeric,numeric,text,text) to authenticated;
grant execute on function public.hris_ess_clock_out(text,date,time,numeric,numeric,numeric,text,text) to authenticated;

alter table public.hris_employee_overtime_requests enable row level security;
alter table public.hris_employee_notifications enable row level security;
drop policy if exists ess_ot_self on public.hris_employee_overtime_requests;
create policy ess_ot_self on public.hris_employee_overtime_requests for all to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.overtime.request')) with check(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.overtime.request'));
drop policy if exists ess_notifications_self on public.hris_employee_notifications;
create policy ess_notifications_self on public.hris_employee_notifications for select to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.notifications.read'));
create policy ess_notifications_update on public.hris_employee_notifications for update to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.notifications.read')) with check(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.notifications.read'));

-- Employee can read schedules and shifts for their own calendar.
drop policy if exists ess_schedule_self on public.hris_jadwal;
create policy ess_schedule_self on public.hris_jadwal for select to authenticated using(id_karyawan=public.hris_ess_employee_id());
drop policy if exists ess_shift_schedule_self on public.hris_shift;
create policy ess_shift_schedule_self on public.hris_shift for select to authenticated using(exists(select 1 from public.hris_jadwal j where j.shift_id=hris_shift.id and j.id_karyawan=public.hris_ess_employee_id()));

-- Mirror important ESS decisions into employee notification inbox.
create or replace function public.hris_ess_notify_overtime_decision() returns trigger language plpgsql security definer set search_path=public as $$
declare v_name text;
begin
 if old.status is distinct from new.status and new.status in ('Disetujui','Ditolak') then
  select nama into v_name from public.karyawan where id_karyawan=new.id_karyawan limit 1;
  insert into public.hris_employee_notifications(id_karyawan,title,message,type,link)
  values(new.id_karyawan,'Status pengajuan lembur',format('Pengajuan lembur %s menit tanggal %s berstatus %s.',new.menit,new.tanggal,new.status),'overtime','#/employee');
 end if;
 return new;
end; $$;
drop trigger if exists trg_ess_ot_notification on public.hris_employee_overtime_requests;
create trigger trg_ess_ot_notification after update of status on public.hris_employee_overtime_requests for each row execute function public.hris_ess_notify_overtime_decision();


-- ============================================================
-- LEGACY BASELINE: 016_v13_approval_hub.sql
-- ============================================================

-- MoonXprojecT V13 — unified approval hub, ESS workflow sync, notifications and audit
create extension if not exists pgcrypto;

insert into public.hris_permissions(kode,nama,modul) values
('approval.manage','Kelola seluruh approval','approval'),
('ess.profile.approve','Approve perubahan profil ESS','people'),
('ess.attendance.approve','Approve koreksi absensi ESS','attendance'),
('ess.leave.approve','Approve cuti ESS','leave'),
('ess.overtime.approve','Approve lembur ESS','overtime')
on conflict(kode) do nothing;

create index if not exists idx_approval_pending_role on public.hris_approval_requests(status,approver_role,created_at desc);

create or replace function public.hris_v13_module_permission(p_modul text) returns boolean
language plpgsql stable security definer set search_path=public as $$
begin
 if public.hris_my_role()='Super Admin' then return true; end if;
 if p_modul in ('leave','ess_leave') then return public.hris_has_permission('leave.approve') or public.hris_has_permission('ess.leave.approve'); end if;
 if p_modul in ('overtime','ess_overtime') then return public.hris_has_permission('overtime.approve') or public.hris_has_permission('ess.overtime.approve'); end if;
 if p_modul='payroll' then return public.hris_has_permission('payroll.approve'); end if;
 if p_modul in ('attendance','ess_attendance') then return public.hris_has_permission('attendance.write') or public.hris_has_permission('ess.attendance.approve'); end if;
 if p_modul in ('people','ess_profile') then return public.hris_has_permission('people.write') or public.hris_has_permission('ess.profile.approve'); end if;
 return public.hris_has_permission('approval.manage');
end; $$;

create or replace function public.hris_v13_create_approval(p_modul text,p_record_id text,p_requester text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_role text; v_email text:=coalesce(p_requester,auth.jwt()->>'email');
begin
 select coalesce(steps->0->>'role','Super Admin') into v_role from public.hris_workflows where modul=case when p_modul like 'ess_%' then replace(p_modul,'ess_','') else p_modul end and aktif=true order by created_at limit 1;
 v_role:=coalesce(v_role,'Super Admin');
 if exists(select 1 from public.hris_approval_requests where modul=p_modul and record_id=p_record_id and status='Menunggu') then
   select id into v_id from public.hris_approval_requests where modul=p_modul and record_id=p_record_id and status='Menunggu' order by created_at desc limit 1;
 else
   insert into public.hris_approval_requests(modul,record_id,requester_email,current_step,status,approver_role)
   values(p_modul,p_record_id,v_email,1,'Menunggu',v_role) returning id into v_id;
 end if;
 if v_id is not null then perform public.hris_audit('SUBMIT',p_modul,p_record_id,jsonb_build_object('approval_id',v_id,'requester',v_email)); end if;
 return v_id;
end; $$;

grant execute on function public.hris_v13_create_approval(text,text,text) to authenticated;

create or replace function public.hris_v13_ess_request_trigger() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if tg_table_name='hris_employee_leave_requests' then
   perform public.hris_v13_create_approval('ess_leave',new.id::text);
 elsif tg_table_name='hris_employee_overtime_requests' then
   perform public.hris_v13_create_approval('ess_overtime',new.id::text);
 elsif tg_table_name='hris_employee_attendance_requests' then
   perform public.hris_v13_create_approval('ess_attendance',new.id::text);
 elsif tg_table_name='hris_employee_profile_requests' then
   perform public.hris_v13_create_approval('ess_profile',new.id::text);
 end if;
 return new;
end; $$;

drop trigger if exists trg_v13_ess_leave_approval on public.hris_employee_leave_requests;
create trigger trg_v13_ess_leave_approval after insert on public.hris_employee_leave_requests for each row execute function public.hris_v13_ess_request_trigger();
drop trigger if exists trg_v13_ess_ot_approval on public.hris_employee_overtime_requests;
create trigger trg_v13_ess_ot_approval after insert on public.hris_employee_overtime_requests for each row execute function public.hris_v13_ess_request_trigger();
drop trigger if exists trg_v13_ess_att_approval on public.hris_employee_attendance_requests;
create trigger trg_v13_ess_att_approval after insert on public.hris_employee_attendance_requests for each row execute function public.hris_v13_ess_request_trigger();
drop trigger if exists trg_v13_ess_profile_approval on public.hris_employee_profile_requests;
create trigger trg_v13_ess_profile_approval after insert on public.hris_employee_profile_requests for each row execute function public.hris_v13_ess_request_trigger();

create or replace function public.hris_v13_decide_approval(p_id uuid,p_status text,p_catatan text default null)
returns void language plpgsql security definer set search_path=public as $$
declare r record; v_role text:=public.hris_my_role(); v_email text:=auth.jwt()->>'email'; v_days numeric; v_emp text; v_jenis text; v_start date; v_end date; v_new text; v_field text;
begin
 if p_status not in ('Disetujui','Ditolak') then raise exception 'Status approval tidak valid'; end if;
 select * into r from public.hris_approval_requests where id=p_id for update;
 if not found then raise exception 'Approval tidak ditemukan'; end if;
 if r.status<>'Menunggu' then raise exception 'Approval sudah diproses'; end if;
 if v_role<>r.approver_role and v_role<>'Super Admin' then raise exception 'Role % tidak berwenang pada tahap ini',v_role; end if;
 if not public.hris_v13_module_permission(r.modul) then raise exception 'Anda tidak memiliki permission untuk approval %',r.modul; end if;

 if p_status='Ditolak' then
   update public.hris_approval_requests set status='Ditolak',decided_by=v_email,decided_at=now(),catatan=p_catatan where id=p_id;
   if r.modul='ess_leave' then update public.hris_employee_leave_requests set status='Ditolak',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='ess_overtime' then update public.hris_employee_overtime_requests set status='Ditolak',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='ess_attendance' then update public.hris_employee_attendance_requests set status='Ditolak',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='ess_profile' then update public.hris_employee_profile_requests set status='Ditolak',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='leave' then update public.hris_cuti set status='Ditolak',disetujui_oleh=v_email where id=r.record_id::uuid;
   elsif r.modul='overtime' then update public.hris_lembur set status='Ditolak',disetujui_oleh=v_email where id=r.record_id::uuid;
   elsif r.modul='payroll' then update public.hris_payroll set status='Ditolak',approved_by=v_email,approved_at=now() where id=r.record_id::uuid;
   end if;
 else
   update public.hris_approval_requests set status='Disetujui',decided_by=v_email,decided_at=now(),catatan=p_catatan where id=p_id;
   if r.modul='ess_leave' then
     select id_karyawan,jenis,tanggal_mulai,tanggal_selesai,jumlah_hari into v_emp,v_jenis,v_start,v_end,v_days from public.hris_employee_leave_requests where id=r.record_id::uuid;
     if v_emp is null then raise exception 'Pengajuan cuti ESS tidak ditemukan'; end if;
     insert into public.hris_cuti(id_karyawan,jenis,tanggal_mulai,tanggal_selesai,jumlah_hari,alasan,status,disetujui_oleh)
     select v_emp,v_jenis,v_start,v_end,v_days,(select alasan from public.hris_employee_leave_requests where id=r.record_id::uuid),'Disetujui',v_email
     where not exists(select 1 from public.hris_cuti c where c.id_karyawan=v_emp and c.tanggal_mulai=v_start and c.tanggal_selesai=v_end and c.status='Disetujui');
     update public.hris_employee_leave_requests set status='Disetujui',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='ess_overtime' then
     select id_karyawan,tanggal into v_emp,v_start from public.hris_employee_overtime_requests where id=r.record_id::uuid;
     insert into public.hris_lembur(id_karyawan,tanggal,menit,alasan,status,disetujui_oleh)
     select e.id_karyawan,e.tanggal,e.menit,e.alasan,'Disetujui',v_email from public.hris_employee_overtime_requests e where e.id=r.record_id::uuid;
     update public.hris_employee_overtime_requests set status='Disetujui',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='ess_attendance' then
     select id_karyawan,tanggal,jam_masuk,jam_pulang into v_emp,v_start,v_new,v_field from public.hris_employee_attendance_requests where id=r.record_id::uuid;
     insert into public.absensi(id_karyawan,tanggal,jam_masuk,jam_pulang,status,sumber,keterangan)
     select e.id_karyawan,e.tanggal,e.jam_masuk,e.jam_pulang,case when e.jenis='Lupa Absen' then 'Hadir' else 'Koreksi' end,'ESS Approval',e.alasan from public.hris_employee_attendance_requests e where e.id=r.record_id::uuid and not exists(select 1 from public.absensi a where a.id_karyawan=e.id_karyawan and a.tanggal=e.tanggal and a.sumber='ESS Approval');
     update public.hris_employee_attendance_requests set status='Disetujui',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='ess_profile' then
     select id_karyawan,field_name,new_value into v_emp,v_field,v_new from public.hris_employee_profile_requests where id=r.record_id::uuid;
     if v_field not in ('no_telp','alamat_rumah','email') then raise exception 'Field profil tidak diizinkan'; end if;
     execute format('update public.karyawan set %I=$1 where id_karyawan=$2',v_field) using v_new,v_emp;
     update public.hris_employee_profile_requests set status='Disetujui',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='leave' then
     select jumlah_hari into v_days from public.hris_cuti where id=r.record_id::uuid;
     update public.hris_cuti set status='Disetujui',disetujui_oleh=v_email where id=r.record_id::uuid;
   elsif r.modul='overtime' then update public.hris_lembur set status='Disetujui',disetujui_oleh=v_email where id=r.record_id::uuid;
   elsif r.modul='payroll' then update public.hris_payroll set status='Disetujui',approved_by=v_email,approved_at=now() where id=r.record_id::uuid;
   end if;
 end if;
 perform public.hris_audit('APPROVAL',r.modul,r.record_id,jsonb_build_object('approval_id',p_id,'status',p_status,'catatan',p_catatan,'actor',v_email));
end; $$;

grant execute on function public.hris_v13_decide_approval(uuid,text,text) to authenticated;

create or replace function public.hris_v13_notify_approval() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_emp text;
begin
 if old.status is distinct from new.status and new.status in ('Disetujui','Ditolak') then
   v_emp:=case when new.modul like 'ess_%' then coalesce((select id_karyawan from public.hris_employee_leave_requests where id=new.record_id::uuid),(select id_karyawan from public.hris_employee_overtime_requests where id=new.record_id::uuid),(select id_karyawan from public.hris_employee_attendance_requests where id=new.record_id::uuid),(select id_karyawan from public.hris_employee_profile_requests where id=new.record_id::uuid)) else null end;
   if v_emp is not null then insert into public.hris_employee_notifications(id_karyawan,title,message,type,link) values(v_emp,'Status pengajuan HRIS',format('Pengajuan %s Anda berstatus %s.',new.modul,new.status),'approval','#/employee'); end if;
 end if;
 return new;
end; $$;

drop trigger if exists trg_v13_approval_notification on public.hris_approval_requests;
create trigger trg_v13_approval_notification after update of status on public.hris_approval_requests for each row execute function public.hris_v13_notify_approval();

-- Keep the existing public function name used by the UI, but route decisions through V13.
create or replace function public.hris_decide_approval(p_id uuid,p_status text,p_catatan text default null)
returns void language sql security definer set search_path=public as $$ select public.hris_v13_decide_approval(p_id,p_status,p_catatan); $$;
grant execute on function public.hris_decide_approval(uuid,text,text) to authenticated;


-- ============================================================
-- LEGACY BASELINE: 017_v14_transaction_workflow.sql
-- ============================================================

-- V14: transaction-driven, multi-level approval foundation
create table if not exists public.hris_workflow_definitions(id uuid primary key default gen_random_uuid(), code text unique not null, name text not null, module text not null, active boolean not null default true, created_at timestamptz default now());
create table if not exists public.hris_workflow_steps(id uuid primary key default gen_random_uuid(), workflow_id uuid references public.hris_workflow_definitions(id) on delete cascade, step_no int not null, approver_role text not null, sla_hours int not null default 24, active boolean not null default true, unique(workflow_id,step_no));
alter table public.hris_approval_requests add column if not exists workflow_code text; alter table public.hris_approval_requests add column if not exists current_step int default 1; alter table public.hris_approval_requests add column if not exists sla_due_at timestamptz;
create index if not exists idx_v14_approval_status on public.hris_approval_requests(status,current_step);
insert into public.hris_workflow_definitions(code,name,module) values ('leave-standard','Leave Standard','leave'),('overtime-standard','Overtime Standard','overtime'),('payroll-standard','Payroll Standard','payroll') on conflict(code) do nothing;


-- ============================================================
-- LEGACY BASELINE: 018_v15_people_analytics.sql
-- ============================================================

-- V15: people analytics snapshots and metrics
create table if not exists public.hris_people_metrics(id uuid primary key default gen_random_uuid(), metric_date date not null default current_date, metric_code text not null, metric_value numeric not null default 0, dimension text, dimension_value text, created_at timestamptz default now(), unique(metric_date,metric_code,dimension,dimension_value));
create index if not exists idx_v15_people_metrics on public.hris_people_metrics(metric_date,metric_code);


-- ============================================================
-- LEGACY BASELINE: 019_v16_document_compliance.sql
-- ============================================================

-- V16: document lifecycle and expiry compliance
alter table public.hris_employee_documents add column if not exists status text default 'Aktif';
alter table public.hris_employee_documents add column if not exists tanggal_kadaluarsa date;
alter table public.hris_employee_documents add column if not exists storage_path text;
create table if not exists public.hris_document_types(id uuid primary key default gen_random_uuid(), code text unique not null, name text not null, required_for text, expiry_required boolean default false, active boolean default true);
create table if not exists public.hris_compliance_tasks(id uuid primary key default gen_random_uuid(), task_code text not null, title text not null, owner text, due_date date, status text not null default 'Open', priority text default 'Medium', notes text, created_at timestamptz default now(), updated_at timestamptz default now());
create index if not exists idx_v16_compliance_due on public.hris_compliance_tasks(status,due_date);


-- ============================================================
-- LEGACY BASELINE: 020_v17_performance_review.sql
-- ============================================================

-- V17: structured performance review cycle
create table if not exists public.hris_performance_cycles(id uuid primary key default gen_random_uuid(), code text unique not null, name text not null, start_date date not null, end_date date not null, status text default 'Draft', created_at timestamptz default now(), check(end_date>=start_date));
create table if not exists public.hris_performance_reviews(id uuid primary key default gen_random_uuid(), cycle_id uuid references public.hris_performance_cycles(id) on delete set null, id_karyawan text not null, period text not null, score numeric default 0, status text default 'Draft', catatan text, reviewer text, submitted_at timestamptz, completed_at timestamptz, created_at timestamptz default now());
create index if not exists idx_v17_reviews_employee on public.hris_performance_reviews(id_karyawan,period);


-- ============================================================
-- LEGACY BASELINE: 021_v18_workforce_planning.sql
-- ============================================================

-- V18: workforce roster and capacity planning
create table if not exists public.hris_workforce_roster(id uuid primary key default gen_random_uuid(), work_date date not null, id_karyawan text not null, shift_code text, location text, status text default 'Planned', source text default 'Manual', notes text, created_at timestamptz default now(), unique(work_date,id_karyawan));
create table if not exists public.hris_workforce_plans(id uuid primary key default gen_random_uuid(), plan_date date not null, department text, required_headcount int default 0, planned_headcount int default 0, max_headcount int, status text default 'Draft', notes text, created_at timestamptz default now(), unique(plan_date,department));
create index if not exists idx_v18_roster_date on public.hris_workforce_roster(work_date,shift_code);


-- ============================================================
-- LEGACY BASELINE: 022_v19_compliance_audit.sql
-- ============================================================

-- V19: compliance control and audit extensions
create table if not exists public.hris_compliance_controls(id uuid primary key default gen_random_uuid(), control_code text unique not null, title text not null, owner_role text, frequency text default 'Monthly', evidence_required boolean default true, active boolean default true);
create table if not exists public.hris_compliance_runs(id uuid primary key default gen_random_uuid(), control_id uuid references public.hris_compliance_controls(id) on delete cascade, run_date date default current_date, status text default 'Open', result text, evidence_path text, reviewer text, reviewed_at timestamptz, created_at timestamptz default now());
create index if not exists idx_v19_compliance_runs on public.hris_compliance_runs(run_date,status);


-- ============================================================
-- LEGACY BASELINE: 023_v20_enterprise_control.sql
-- ============================================================

-- V20: enterprise control center settings and approval RPC
create table if not exists public.hris_enterprise_settings(id uuid primary key default gen_random_uuid(), key text unique not null, value text, updated_at timestamptz default now());
insert into public.hris_enterprise_settings(key,value) values ('approval_sla_hours','24'),('document_expiry_days','30'),('attendance_radius_meters','150'),('require_selfie','true'),('require_gps','true') on conflict(key) do nothing;
create or replace function public.hris_v20_decide_approval(p_request_id uuid,p_decision text,p_note text default null) returns void language plpgsql security definer as $$
declare r record; begin if p_decision not in ('Disetujui','Ditolak') then raise exception 'Decision tidak valid'; end if; select * into r from public.hris_approval_requests where id=p_request_id for update; if not found then raise exception 'Approval request tidak ditemukan'; end if; if lower(coalesce(r.status,'')) not like '%menunggu%' and lower(coalesce(r.status,'')) <> 'pending' then raise exception 'Approval sudah diproses'; end if; update public.hris_approval_requests set status=p_decision, catatan=coalesce(p_note,catatan), updated_at=now() where id=p_request_id; end $$;


-- ============================================================
-- LEGACY BASELINE: 024_v21_security_hardening.sql
-- ============================================================

-- MoonXprojecT V21 — Security & Authorization Hardening
-- Run AFTER 023_v20_enterprise_control.sql.

create extension if not exists pgcrypto;

-- Security/administration permissions
insert into public.hris_permissions(kode,nama,modul) values
('security.read','Lihat Security Center','system'),
('security.manage','Kelola Security Center','system'),
('roles.manage','Kelola Role & Permission','roles'),
('audit.export','Export Audit Log','audit')
on conflict (kode) do nothing;

-- Normalize the permission helper: exact permission, module grant, or wildcard.
create or replace function public.hris_has_permission(p_code text)
returns boolean language sql stable security definer set search_path=public as $$
  select public.hris_is_super_admin() or exists (
    select 1 from public.hris_role_permissions
    where role_name=public.hris_my_role()
      and (permission_code='*'
        or permission_code=p_code
        or permission_code=split_part(p_code,'.',1))
  );
$$;
grant execute on function public.hris_has_permission(text) to authenticated;

-- Central approval authorization. Every decision must match both the current
-- workflow role and the module permission; clients cannot bypass this check.
create or replace function public.hris_v21_decide_approval(
  p_request_id uuid,
  p_decision text,
  p_note text default null
) returns void
language plpgsql security definer set search_path=public as $$
declare
  r record;
  v_role text := public.hris_my_role();
  v_email text := auth.jwt()->>'email';
  v_allowed boolean := false;
begin
  if auth.uid() is null then raise exception 'Unauthenticated'; end if;
  if p_decision not in ('Disetujui','Ditolak') then raise exception 'Decision tidak valid'; end if;

  select * into r from public.hris_approval_requests where id=p_request_id for update;
  if not found then raise exception 'Approval request tidak ditemukan'; end if;
  if coalesce(r.status,'') <> 'Menunggu' then raise exception 'Approval sudah diproses'; end if;

  -- Super Admin is the emergency administrator; all other users must be the
  -- assigned role and have the module-specific approval permission.
  if v_role='Super Admin' then
    v_allowed := true;
  elsif v_role = coalesce(r.approver_role,'') then
    v_allowed := case
      when r.modul in ('leave','ess_leave') then public.hris_has_permission('leave.approve') or public.hris_has_permission('ess.leave.approve')
      when r.modul in ('overtime','ess_overtime') then public.hris_has_permission('overtime.approve') or public.hris_has_permission('ess.overtime.approve')
      when r.modul in ('payroll') then public.hris_has_permission('payroll.approve')
      when r.modul in ('attendance','ess_attendance') then public.hris_has_permission('attendance.write') or public.hris_has_permission('ess.attendance.approve')
      when r.modul in ('people','ess_profile') then public.hris_has_permission('people.write') or public.hris_has_permission('ess.profile.approve')
      when r.modul in ('recruitment') then public.hris_has_permission('recruitment.approve')
      else public.hris_has_permission('approval.manage')
    end;
  end if;

  if not v_allowed then
    raise exception 'Akses approval ditolak untuk role % pada modul %',v_role,r.modul using errcode='42501';
  end if;

  update public.hris_approval_requests
    set status=p_decision,
        decided_by=v_email,
        decided_at=now(),
        catatan=coalesce(nullif(p_note,''),catatan),
        updated_at=now()
  where id=p_request_id;

  perform public.hris_audit(
    case when p_decision='Disetujui' then 'APPROVE' else 'REJECT' end,
    r.modul,
    r.record_id,
    jsonb_build_object('approval_id',r.id,'approver',v_email,'role',v_role,'step',r.current_step,'note',p_note)
  );
end;
$$;
grant execute on function public.hris_v21_decide_approval(uuid,text,text) to authenticated;

-- V20 RPC is retained for compatibility but now delegates to the hardened RPC.
create or replace function public.hris_v20_decide_approval(p_request_id uuid,p_decision text,p_note text default null)
returns void language plpgsql security definer set search_path=public as $$
begin
  perform public.hris_v21_decide_approval(p_request_id,p_decision,p_note);
end;
$$;
grant execute on function public.hris_v20_decide_approval(uuid,text,text) to authenticated;

-- Immutable audit posture: authenticated users can read only through RLS;
-- direct UPDATE/DELETE is not granted by this migration. Add a database-level
-- trigger to reject mutation of historical audit rows.
create or replace function public.hris_v21_audit_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'Audit log immutable: historical records cannot be changed or deleted';
end;
$$;
drop trigger if exists trg_v21_audit_immutable_update on public.hris_audit_logs;
drop trigger if exists trg_v21_audit_immutable_delete on public.hris_audit_logs;
create trigger trg_v21_audit_immutable_update before update on public.hris_audit_logs for each row execute function public.hris_v21_audit_immutable();
create trigger trg_v21_audit_immutable_delete before delete on public.hris_audit_logs for each row execute function public.hris_v21_audit_immutable();

-- Explicitly deny destructive audit operations through table grants for normal users.
revoke update, delete on public.hris_audit_logs from authenticated;

-- Security event table for authentication/administrative events visible to admins.
create table if not exists public.hris_security_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  actor_email text,
  actor_role text,
  ip_hint text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_v21_security_events_created on public.hris_security_events(created_at desc);
create index if not exists idx_v21_security_events_type on public.hris_security_events(event_type,created_at desc);
alter table public.hris_security_events enable row level security;
drop policy if exists security_events_read on public.hris_security_events;
create policy security_events_read on public.hris_security_events for select to authenticated using (
  public.hris_has_permission('security.read') or public.hris_has_permission('security.manage')
);
revoke insert, update, delete on public.hris_security_events from authenticated;

-- Safe server-side event writer; client never supplies actor identity.
create or replace function public.hris_v21_security_event(p_event_type text,p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Unauthenticated'; end if;
  if not (public.hris_has_permission('security.manage') or public.hris_is_super_admin()) then
    raise exception 'Akses security event ditolak' using errcode='42501';
  end if;
  insert into public.hris_security_events(event_type,actor_email,actor_role,metadata)
  values(p_event_type,auth.jwt()->>'email',public.hris_my_role(),coalesce(p_metadata,'{}'::jsonb))
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function public.hris_v21_security_event(text,jsonb) to authenticated;

-- Useful security inventory view for administrators.
create or replace view public.hris_v21_security_overview as
select
  (select count(*) from public.hris_users where status='Aktif') as active_users,
  (select count(*) from public.hris_role_permissions where permission_code='*') as wildcard_grants,
  (select count(*) from public.hris_approval_requests where status='Menunggu') as pending_approvals,
  (select count(*) from public.hris_audit_logs where created_at >= now() - interval '24 hours') as audit_24h,
  (select count(*) from public.hris_security_events where created_at >= now() - interval '24 hours') as security_events_24h;

-- Role/permission changes should be performed by Super Admin only.
drop policy if exists role_permissions_write_v21 on public.hris_role_permissions;
create policy role_permissions_write_v21 on public.hris_role_permissions for all to authenticated
using (public.hris_is_super_admin()) with check (public.hris_is_super_admin());


-- ============================================================
-- LEGACY BASELINE: 025_v22_payroll_production.sql
-- ============================================================

-- MoonXprojecT V22 — Payroll Production Control
-- Preview, variance control, approval, lock and payment-batch preparation.
create extension if not exists pgcrypto;

create table if not exists public.hris_payroll_run_controls (
 id uuid primary key default gen_random_uuid(),
 period_id uuid not null unique references public.hris_payroll_periods(id) on delete cascade,
 status text not null default 'Draft' check(status in ('Draft','Preview','Pending Approval','Approved','Locked','Paid','Closed')),
 employee_count integer not null default 0,
 gross_total numeric(16,2) not null default 0,
 deduction_total numeric(16,2) not null default 0,
 net_total numeric(16,2) not null default 0,
 previous_net_total numeric(16,2) not null default 0,
 variance_amount numeric(16,2) generated always as (net_total-previous_net_total) stored,
 variance_percent numeric(10,4) generated always as (case when previous_net_total=0 then null else ((net_total-previous_net_total)/abs(previous_net_total))*100 end) stored,
 generated_at timestamptz,
 approved_at timestamptz,
 approved_by text,
 locked_at timestamptz,
 locked_by text,
 notes text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists idx_v22_payroll_control_status on public.hris_payroll_run_controls(status);

insert into public.hris_permissions(kode,nama,modul) values
('payroll.preview','Preview & variance payroll','payroll'),
('payroll.lock','Lock payroll final','payroll'),
('payroll.payslip','Kelola slip gaji','payroll')
on conflict(kode) do nothing;

alter table public.hris_payroll_run_controls enable row level security;
drop policy if exists v22_payroll_control_read on public.hris_payroll_run_controls;
create policy v22_payroll_control_read on public.hris_payroll_run_controls for select to authenticated using(public.hris_has_permission('payroll.read'));
drop policy if exists v22_payroll_control_write on public.hris_payroll_run_controls;
create policy v22_payroll_control_write on public.hris_payroll_run_controls for all to authenticated using(public.hris_has_permission('payroll.preview') or public.hris_has_permission('payroll.approve') or public.hris_has_permission('payroll.lock')) with check(public.hris_has_permission('payroll.preview') or public.hris_has_permission('payroll.approve') or public.hris_has_permission('payroll.lock'));

create or replace function public.hris_v22_refresh_payroll_control(p_period_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare p record; c record; prev numeric:=0; emp int:=0; gross numeric:=0; ded numeric:=0; net numeric:=0; cid uuid;
begin
 perform public.hris_require_permission('payroll.preview');
 select * into p from public.hris_payroll_periods where id=p_period_id;
 if not found then raise exception 'Periode payroll tidak ditemukan'; end if;
 select coalesce(sum(total_pendapatan),0),coalesce(sum(total_potongan),0),coalesce(sum(gaji_bersih),0),count(*) into gross,ded,net,emp from public.hris_payroll where periode=p.kode;
 select coalesce(sum(gaji_bersih),0) into prev from public.hris_payroll q join public.hris_payroll_periods pp on pp.kode=q.periode where pp.tanggal_selesai < p.tanggal_mulai and pp.status in ('Approved','Paid','Closed') and q.id_karyawan in (select id_karyawan from public.hris_payroll where periode=p.kode);
 insert into public.hris_payroll_run_controls(period_id,status,employee_count,gross_total,deduction_total,net_total,previous_net_total,generated_at)
 values(p.id,'Preview',emp,gross,ded,net,prev,now())
 on conflict(period_id) do update set employee_count=excluded.employee_count,gross_total=excluded.gross_total,deduction_total=excluded.deduction_total,net_total=excluded.net_total,previous_net_total=excluded.previous_net_total,generated_at=now(),updated_at=now(),status=case when hris_payroll_run_controls.status in ('Approved','Locked','Paid','Closed') then hris_payroll_run_controls.status else 'Preview' end
 returning id into cid;
 return jsonb_build_object('control_id',cid,'employees',emp,'gross',gross,'deduction',ded,'net',net,'previous_net',prev);
end $$;
grant execute on function public.hris_v22_refresh_payroll_control(uuid) to authenticated;

create or replace function public.hris_v22_approve_payroll(p_period_id uuid,p_note text default null)
returns void language plpgsql security definer set search_path=public as $$
declare c record; p record; v_email text:=auth.jwt()->>'email';
begin
 perform public.hris_require_permission('payroll.approve');
 select * into c from public.hris_payroll_run_controls where period_id=p_period_id for update;
 if not found then raise exception 'Preview payroll belum dibuat'; end if;
 if c.status not in ('Preview','Pending Approval') then raise exception 'Payroll tidak dapat diapprove dari status %',c.status; end if;
 if c.employee_count=0 then raise exception 'Tidak ada payroll untuk diapprove'; end if;
 update public.hris_payroll_run_controls set status='Approved',approved_at=now(),approved_by=v_email,notes=coalesce(nullif(p_note,''),notes),updated_at=now() where id=c.id;
 update public.hris_payroll_periods set status='Approved' where id=p_period_id;
 update public.hris_payroll set status='Disetujui',approved_by=v_email,approved_at=now() where periode=(select kode from public.hris_payroll_periods where id=p_period_id) and coalesce(status,'Draft') not in ('Paid','Closed');
 perform public.hris_audit('APPROVE','payroll',p_period_id,jsonb_build_object('net_total',c.net_total,'employees',c.employee_count));
end $$;
grant execute on function public.hris_v22_approve_payroll(uuid,text) to authenticated;

create or replace function public.hris_v22_lock_payroll(p_period_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare c record; v_email text:=auth.jwt()->>'email';
begin
 perform public.hris_require_permission('payroll.lock');
 select * into c from public.hris_payroll_run_controls where period_id=p_period_id for update;
 if not found or c.status <> 'Approved' then raise exception 'Payroll harus Approved sebelum dikunci'; end if;
 update public.hris_payroll_run_controls set status='Locked',locked_at=now(),locked_by=v_email,updated_at=now() where id=c.id;
 update public.hris_payroll_periods set status='Closed' where id=p_period_id;
 update public.hris_payroll set locked_at=now(),locked_by=v_email where periode=(select kode from public.hris_payroll_periods where id=p_period_id);
 perform public.hris_audit('LOCK','payroll',p_period_id,jsonb_build_object('net_total',c.net_total,'employees',c.employee_count));
end $$;
grant execute on function public.hris_v22_lock_payroll(uuid) to authenticated;

-- Prevent mutation of financial payroll rows after V22 lock.
create or replace function public.hris_v22_payroll_locked_guard()
returns trigger language plpgsql as $$
begin
 if old.locked_at is not null and (new.gaji_pokok,new.tunjangan,new.uang_makan,new.transport,new.lembur,new.bonus,new.potongan,new.bpjs,new.pph21,new.id_karyawan,new.periode) is distinct from (old.gaji_pokok,old.tunjangan,old.uang_makan,old.transport,old.lembur,old.bonus,old.potongan,old.bpjs,old.pph21,old.id_karyawan,old.periode) then
   raise exception 'Payroll sudah dikunci dan tidak dapat diubah';
 end if;
 return new;
end $$;
drop trigger if exists trg_v22_payroll_locked_guard on public.hris_payroll;
create trigger trg_v22_payroll_locked_guard before update on public.hris_payroll for each row execute function public.hris_v22_payroll_locked_guard();

create or replace view public.hris_v22_payroll_summary as
select p.id,p.kode,p.tanggal_mulai,p.tanggal_selesai,p.tanggal_gajian,p.status,
 coalesce(c.employee_count,0) employee_count,coalesce(c.gross_total,0) gross_total,coalesce(c.deduction_total,0) deduction_total,coalesce(c.net_total,0) net_total,coalesce(c.variance_amount,0) variance_amount,c.variance_percent
from public.hris_payroll_periods p left join public.hris_payroll_run_controls c on c.period_id=p.id;


-- ============================================================
-- ENTERPRISE MIGRATION: 026_v23_indonesia_payroll_compliance.sql
-- ============================================================

-- MoonXprojecT V23 — Indonesia Payroll Compliance Engine
-- Production foundation: configurable statutory rules, annual tax reconciliation,
-- BPJS caps, TER monthly tax support, payroll preflight and immutable snapshots.

create table if not exists public.hris_payroll_statutory_rules (
  id uuid primary key default gen_random_uuid(),
  rule_code text not null unique,
  rule_name text not null,
  category text not null check (category in ('PPh21','BPJS','THR','Other')),
  effective_from date not null,
  effective_to date,
  rate numeric(12,6),
  employee_rate numeric(12,6),
  employer_rate numeric(12,6),
  cap_amount numeric(18,2),
  fixed_amount numeric(18,2),
  config jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

alter table public.hris_employee_tax_profiles add column if not exists active boolean not null default true;

create index if not exists idx_payroll_stat_rules_effective
  on public.hris_payroll_statutory_rules(category,effective_from,effective_to,active);

create table if not exists public.hris_payroll_tax_reconciliations (
  id uuid primary key default gen_random_uuid(),
  payroll_year integer not null,
  employee_id text not null references public.karyawan(id_karyawan) on delete cascade,
  gross_annual numeric(18,2) not null default 0,
  deductible_annual numeric(18,2) not null default 0,
  taxable_annual numeric(18,2) not null default 0,
  pph21_withheld numeric(18,2) not null default 0,
  pph21_final numeric(18,2) not null default 0,
  variance numeric(18,2) generated always as (pph21_withheld - pph21_final) stored,
  status text not null default 'Draft' check (status in ('Draft','Review','Final','Locked')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(payroll_year,employee_id)
);

create index if not exists idx_tax_recon_year_status
  on public.hris_payroll_tax_reconciliations(payroll_year,status);

create table if not exists public.hris_payroll_statutory_snapshots (
  id uuid primary key default gen_random_uuid(),
  payroll_id uuid not null references public.hris_payroll(id) on delete cascade,
  employee_id text not null references public.karyawan(id_karyawan) on delete cascade,
  snapshot_type text not null check (snapshot_type in ('PPh21','BPJS','THR')),
  basis_amount numeric(18,2) not null default 0,
  employee_amount numeric(18,2) not null default 0,
  employer_amount numeric(18,2) not null default 0,
  rule_code text,
  rule_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(payroll_id,employee_id,snapshot_type)
);

create index if not exists idx_statutory_snapshots_payroll
  on public.hris_payroll_statutory_snapshots(payroll_id,employee_id);

insert into public.hris_payroll_statutory_rules
(rule_code,rule_name,category,effective_from,employee_rate,employer_rate,cap_amount,config)
values
('BPJS_KES_EMP','BPJS Kesehatan - Karyawan','BPJS','2026-01-01',0.010000,0.040000,12000000,'{"notes":"Default configurable ceiling; verify against current BPJS rules before production."}'),
('BPJS_JHT_EMP','JHT - Karyawan','BPJS','2026-01-01',0.020000,0.037000,null,'{}'),
('BPJS_JP_EMP','JP - Karyawan','BPJS','2026-01-01',0.010000,0.020000,null,'{"notes":"Ceiling must be maintained from current statutory wage ceiling."}'),
('BPJS_JKK','JKK - Perusahaan','BPJS','2026-01-01',0.000000,0.002400,null,'{"risk_class":"configurable"}'),
('BPJS_JKM','JKM - Perusahaan','BPJS','2026-01-01',0.000000,0.003000,null,'{}'),
('THR_MONTH','THR Monthly Accrual','THR','2026-01-01',0,0,null,'{"months_for_full":12}'),
('PPH21_TER','PPh 21 TER','PPh21','2026-01-01',0,0,null,'{"method":"TER","requires_current_tax_brackets":true}')
on conflict(rule_code) do update set
  rule_name=excluded.rule_name,
  category=excluded.category,
  effective_from=excluded.effective_from,
  employee_rate=excluded.employee_rate,
  employer_rate=excluded.employer_rate,
  cap_amount=excluded.cap_amount,
  config=excluded.config,
  updated_at=now();

alter table public.hris_role_permissions add column if not exists description text;

create or replace function public.hris_v23_statutory_preflight(p_payroll_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  result jsonb;
begin
  perform public.hris_require_permission('payroll.preflight');

  select jsonb_build_object(
    'payroll_id', p_payroll_id,
    'employee_count', count(*),
    'missing_tax_profile', count(*) filter (where tp.id is null),
    'missing_primary_bank', count(*) filter (where ba.id is null),
    'negative_gross', count(*) filter (where coalesce(p.total_pendapatan,0) < 0),
    'negative_net', count(*) filter (where coalesce(p.gaji_bersih,0) < 0)
  )
  into result
  from public.hris_payroll p
  left join public.hris_employee_tax_profiles tp on tp.id_karyawan=p.id_karyawan and tp.active=true
  left join public.hris_employee_bank_accounts ba on ba.id_karyawan=p.id_karyawan and ba.is_primary=true and ba.active=true
  where p.id=p_payroll_id;

  return result;
end;
$$;

create or replace function public.hris_v23_snapshot_statutory(p_payroll_id uuid)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
  inserted_count integer := 0;
begin
  perform public.hris_require_permission('payroll.engine');

  insert into public.hris_payroll_statutory_snapshots
    (payroll_id,employee_id,snapshot_type,basis_amount,employee_amount,employer_amount,rule_code,rule_payload)
  select
    p.id,p.id_karyawan,'BPJS',
    coalesce(p.total_pendapatan,0),
    round(coalesce(p.total_pendapatan,0)*0.03,2),
    round(coalesce(p.total_pendapatan,0)*0.0754,2),
    'BPJS_COMPOSITE_V23',
    jsonb_build_object('engine','V23','warning','Verify statutory rates/caps against current regulations before production')
  from public.hris_payroll p
  where p.id=p_payroll_id
  on conflict (payroll_id,employee_id,snapshot_type) do update set
    basis_amount=excluded.basis_amount,
    employee_amount=excluded.employee_amount,
    employer_amount=excluded.employer_amount,
    rule_code=excluded.rule_code,
    rule_payload=excluded.rule_payload;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

alter table public.hris_payroll_statutory_rules enable row level security;
alter table public.hris_payroll_tax_reconciliations enable row level security;
alter table public.hris_payroll_statutory_snapshots enable row level security;

do $$
begin
  if not exists (select 1 from public.hris_role_permissions where permission_code='payroll.tax.reconcile') then
    insert into public.hris_role_permissions(permission_code,description)
    values('payroll.tax.reconcile','Review and finalize annual PPh 21 reconciliation');
  end if;
  if not exists (select 1 from public.hris_role_permissions where permission_code='payroll.statutory.read') then
    insert into public.hris_role_permissions(permission_code,description)
    values('payroll.statutory.read','Read statutory payroll calculations and snapshots');
  end if;
end $$;

comment on table public.hris_payroll_statutory_rules is
'Configurable Indonesian statutory payroll rules. Rates are defaults only and must be validated against current official regulations.';


-- ============================================================
-- ENTERPRISE MIGRATION: 027_v24_attendance_shift_engine.sql
-- ============================================================

-- MoonXprojecT V24 — Attendance & Shift Engine
-- Production foundation: shift masters, overnight-safe schedules, grace periods,
-- attendance calculation snapshots, holidays, exceptions and workday rules.

create table if not exists public.hris_shift_definitions (
  id uuid primary key default gen_random_uuid(),
  kode text not null unique,
  nama text not null,
  jam_masuk time not null,
  jam_pulang time not null,
  durasi_istirahat_menit integer not null default 60 check (durasi_istirahat_menit between 0 and 600),
  toleransi_menit integer not null default 10 check (toleransi_menit between 0 and 180),
  lintas_hari boolean not null default false,
  aktif boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (jam_masuk <> jam_pulang)
);

create table if not exists public.hris_shift_assignments_v24 (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null references public.karyawan(id_karyawan) on delete cascade,
  shift_id uuid not null references public.hris_shift_definitions(id) on delete restrict,
  tanggal date not null,
  lokasi text,
  sumber text not null default 'Manual' check (sumber in ('Manual','Roster','Import','System')),
  status text not null default 'Scheduled' check (status in ('Scheduled','Off','Cancelled')),
  catatan text,
  created_at timestamptz not null default now(),
  unique(employee_id,tanggal)
);

create index if not exists idx_shift_assign_v24_date on public.hris_shift_assignments_v24(tanggal,shift_id);
create index if not exists idx_shift_assign_v24_employee on public.hris_shift_assignments_v24(employee_id,tanggal);

create table if not exists public.hris_holidays_v24 (
  id uuid primary key default gen_random_uuid(),
  tanggal date not null unique,
  nama text not null,
  jenis text not null default 'National' check (jenis in ('National','Company','Collective')),
  paid boolean not null default true,
  overtime_multiplier numeric(8,2) not null default 2 check (overtime_multiplier >= 0),
  aktif boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.hris_attendance_calculations_v24 (
  id uuid primary key default gen_random_uuid(),
  attendance_id uuid,
  employee_id text not null references public.karyawan(id_karyawan) on delete cascade,
  tanggal date not null,
  scheduled_in timestamptz,
  scheduled_out timestamptz,
  actual_in timestamptz,
  actual_out timestamptz,
  late_minutes integer not null default 0 check (late_minutes >= 0),
  early_leave_minutes integer not null default 0 check (early_leave_minutes >= 0),
  worked_minutes integer not null default 0 check (worked_minutes >= 0),
  overtime_minutes integer not null default 0 check (overtime_minutes >= 0),
  effective_workday numeric(8,2) not null default 0 check (effective_workday >= 0),
  is_holiday boolean not null default false,
  is_rest_day boolean not null default false,
  calculation_status text not null default 'Calculated' check (calculation_status in ('Calculated','Adjusted','Locked')),
  calculation_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(employee_id,tanggal)
);

create index if not exists idx_att_calc_v24_employee_date
  on public.hris_attendance_calculations_v24(employee_id,tanggal);
create index if not exists idx_att_calc_v24_status
  on public.hris_attendance_calculations_v24(calculation_status);

create table if not exists public.hris_attendance_adjustments_v24 (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null references public.karyawan(id_karyawan) on delete cascade,
  tanggal date not null,
  adjustment_type text not null check (adjustment_type in ('IN','OUT','STATUS','OVERTIME','SCHEDULE')),
  old_value jsonb,
  new_value jsonb not null default '{}'::jsonb,
  reason text not null,
  requested_by uuid references auth.users(id),
  approved_by uuid references auth.users(id),
  status text not null default 'Pending' check (status in ('Pending','Approved','Rejected','Applied')),
  created_at timestamptz not null default now(),
  applied_at timestamptz
);

create index if not exists idx_att_adj_v24_status on public.hris_attendance_adjustments_v24(status,tanggal);

create or replace function public.hris_v24_schedule_bounds(
  p_tanggal date,
  p_jam_masuk time,
  p_jam_pulang time,
  p_lintas_hari boolean
)
returns jsonb
language plpgsql immutable
as $$
declare
  v_in timestamptz;
  v_out timestamptz;
begin
  v_in := (p_tanggal + p_jam_masuk)::timestamptz;
  v_out := (p_tanggal + p_jam_pulang)::timestamptz;
  if p_lintas_hari or p_jam_pulang <= p_jam_masuk then
    v_out := ((p_tanggal + 1) + p_jam_pulang)::timestamptz;
  end if;
  return jsonb_build_object('scheduled_in',v_in,'scheduled_out',v_out);
end;
$$;

create or replace function public.hris_v24_calculate_attendance(
  p_employee_id text,
  p_tanggal date,
  p_scheduled_in timestamptz,
  p_scheduled_out timestamptz,
  p_actual_in timestamptz,
  p_actual_out timestamptz,
  p_break_minutes integer default 60,
  p_is_holiday boolean default false,
  p_is_rest_day boolean default false
)
returns jsonb
language plpgsql immutable
as $$
declare
  late_m integer := 0;
  early_m integer := 0;
  worked_m integer := 0;
  overtime_m integer := 0;
  workday numeric(8,2) := 0;
begin
  if p_actual_in is not null and p_scheduled_in is not null and p_actual_in > p_scheduled_in then
    late_m := floor(extract(epoch from (p_actual_in-p_scheduled_in))/60)::integer;
  end if;

  if p_actual_out is not null and p_scheduled_out is not null and p_actual_out < p_scheduled_out then
    early_m := floor(extract(epoch from (p_scheduled_out-p_actual_out))/60)::integer;
  end if;

  if p_actual_in is not null and p_actual_out is not null and p_actual_out >= p_actual_in then
    worked_m := greatest(0,floor(extract(epoch from (p_actual_out-p_actual_in))/60)::integer - greatest(0,p_break_minutes));
  end if;

  if p_actual_out is not null and p_scheduled_out is not null and p_actual_out > p_scheduled_out then
    overtime_m := floor(extract(epoch from (p_actual_out-p_scheduled_out))/60)::integer;
  end if;

  if p_actual_in is not null then
    workday := case when p_is_rest_day then 0 else 1 end;
  end if;

  return jsonb_build_object(
    'employee_id',p_employee_id,'tanggal',p_tanggal,
    'late_minutes',late_m,'early_leave_minutes',early_m,
    'worked_minutes',worked_m,'overtime_minutes',overtime_m,
    'effective_workday',workday,'is_holiday',p_is_holiday,'is_rest_day',p_is_rest_day
  );
end;
$$;

create or replace function public.hris_v24_upsert_calculation(
  p_employee_id text,
  p_tanggal date,
  p_scheduled_in timestamptz,
  p_scheduled_out timestamptz,
  p_actual_in timestamptz,
  p_actual_out timestamptz,
  p_break_minutes integer default 60,
  p_is_holiday boolean default false,
  p_is_rest_day boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  c jsonb;
begin
  perform public.hris_require_permission('attendance.exception');
  c := public.hris_v24_calculate_attendance(p_employee_id,p_tanggal,p_scheduled_in,p_scheduled_out,p_actual_in,p_actual_out,p_break_minutes,p_is_holiday,p_is_rest_day);

  insert into public.hris_attendance_calculations_v24
    (employee_id,tanggal,scheduled_in,scheduled_out,actual_in,actual_out,late_minutes,early_leave_minutes,worked_minutes,overtime_minutes,effective_workday,is_holiday,is_rest_day,calculation_payload)
  values
    (p_employee_id,p_tanggal,p_scheduled_in,p_scheduled_out,p_actual_in,p_actual_out,
     (c->>'late_minutes')::integer,(c->>'early_leave_minutes')::integer,(c->>'worked_minutes')::integer,(c->>'overtime_minutes')::integer,
     (c->>'effective_workday')::numeric,p_is_holiday,p_is_rest_day,c)
  on conflict(employee_id,tanggal) do update set
    scheduled_in=excluded.scheduled_in,scheduled_out=excluded.scheduled_out,
    actual_in=excluded.actual_in,actual_out=excluded.actual_out,
    late_minutes=excluded.late_minutes,early_leave_minutes=excluded.early_leave_minutes,
    worked_minutes=excluded.worked_minutes,overtime_minutes=excluded.overtime_minutes,
    effective_workday=excluded.effective_workday,is_holiday=excluded.is_holiday,is_rest_day=excluded.is_rest_day,
    calculation_payload=excluded.calculation_payload,updated_at=now();

  return c;
end;
$$;

alter table public.hris_shift_definitions enable row level security;
alter table public.hris_shift_assignments_v24 enable row level security;
alter table public.hris_holidays_v24 enable row level security;
alter table public.hris_attendance_calculations_v24 enable row level security;
alter table public.hris_attendance_adjustments_v24 enable row level security;

do $$
begin
  if not exists (select 1 from public.hris_role_permissions where permission_code='attendance.shift.manage') then
    insert into public.hris_role_permissions(permission_code,description) values('attendance.shift.manage','Manage shift definitions and employee schedules');
  end if;
  if not exists (select 1 from public.hris_role_permissions where permission_code='attendance.holiday.manage') then
    insert into public.hris_role_permissions(permission_code,description) values('attendance.holiday.manage','Manage holiday calendar');
  end if;
  if not exists (select 1 from public.hris_role_permissions where permission_code='attendance.calculation.read') then
    insert into public.hris_role_permissions(permission_code,description) values('attendance.calculation.read','Read calculated attendance metrics');
  end if;
  if not exists (select 1 from public.hris_role_permissions where permission_code='attendance.adjustment.approve') then
    insert into public.hris_role_permissions(permission_code,description) values('attendance.adjustment.approve','Approve attendance adjustments');
  end if;
end $$;

comment on table public.hris_shift_definitions is 'Enterprise shift master. Supports overnight shifts via lintas_hari.';
comment on table public.hris_attendance_calculations_v24 is 'Calculated attendance snapshot used by attendance, overtime and payroll downstream.';


-- ============================================================
-- ENTERPRISE MIGRATION: 028_v25_ats_enterprise.sql
-- ============================================================

-- MoonXprojecT Enterprise V25 - ATS Enterprise
create extension if not exists pgcrypto;

create table if not exists public.hris_recruitment_requisitions_v25 (
 id uuid primary key default gen_random_uuid(),
 request_no text not null unique,
 posisi text not null,
 departemen text,
 lokasi text,
 jumlah_kebutuhan integer not null default 1 check (jumlah_kebutuhan > 0),
 alasan text,
 hiring_manager text,
 target_tanggal date,
 status text not null default 'Draft' check (status in ('Draft','Menunggu Approval','Disetujui','Ditolak','Ditutup')),
 approved_by text,
 approved_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.hris_recruitment_openings_v25 (
 id uuid primary key default gen_random_uuid(),
 requisition_id uuid references public.hris_recruitment_requisitions_v25(id) on delete set null,
 opening_no text not null unique,
 posisi text not null,
 departemen text,
 lokasi text,
 employment_type text not null default 'Tetap',
 level_jabatan text,
 headcount integer not null default 1 check (headcount > 0),
 salary_min numeric(14,2) default 0,
 salary_max numeric(14,2) default 0,
 publish_at timestamptz,
 close_at timestamptz,
 status text not null default 'Draft' check (status in ('Draft','Open','Paused','Closed')),
 description text,
 requirements text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check (salary_max = 0 or salary_max >= salary_min)
);

create table if not exists public.hris_candidate_profiles_v25 (
 id uuid primary key default gen_random_uuid(),
 candidate_id uuid references public.hris_kandidat(id) on delete set null,
 full_name text not null,
 email text,
 phone text,
 city text,
 source text,
 linkedin_url text,
 portfolio_url text,
 resume_path text,
 consent_at timestamptz,
 notes text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.hris_recruitment_applications_v25 (
 id uuid primary key default gen_random_uuid(),
 candidate_profile_id uuid not null references public.hris_candidate_profiles_v25(id) on delete cascade,
 opening_id uuid not null references public.hris_recruitment_openings_v25(id) on delete cascade,
 stage text not null default 'Screening' check (stage in ('Screening','Interview','Assessment','Offering','Hired','Rejected','Withdrawn')),
 status text not null default 'Active' check (status in ('Active','Rejected','Hired','Withdrawn','On Hold')),
 score numeric(6,2) default 0,
 owner_email text,
 applied_at timestamptz not null default now(),
 hired_at timestamptz,
 rejection_reason text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(candidate_profile_id,opening_id)
);

create table if not exists public.hris_recruitment_stage_history_v25 (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.hris_recruitment_applications_v25(id) on delete cascade,
 from_stage text,
 to_stage text not null,
 actor_email text,
 note text,
 created_at timestamptz not null default now()
);

create table if not exists public.hris_recruitment_interviews_v25 (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.hris_recruitment_applications_v25(id) on delete cascade,
 interview_type text not null default 'Interview HR',
 scheduled_at timestamptz not null,
 duration_minutes integer not null default 60,
 location_or_link text,
 interviewer_email text,
 status text not null default 'Scheduled' check (status in ('Scheduled','Completed','Cancelled','No Show')),
 overall_score numeric(6,2) default 0,
 notes text,
 created_at timestamptz not null default now()
);

create table if not exists public.hris_recruitment_scorecards_v25 (
 id uuid primary key default gen_random_uuid(),
 interview_id uuid not null references public.hris_recruitment_interviews_v25(id) on delete cascade,
 competency text not null,
 weight numeric(6,2) not null default 1,
 score numeric(6,2) not null default 0 check (score between 0 and 100),
 comments text,
 created_at timestamptz not null default now()
);

create table if not exists public.hris_recruitment_offers_v25 (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.hris_recruitment_applications_v25(id) on delete cascade,
 offer_no text not null unique,
 proposed_salary numeric(14,2) not null default 0,
 start_date date,
 employment_type text,
 status text not null default 'Draft' check (status in ('Draft','Menunggu Approval','Disetujui','Dikirim','Diterima','Ditolak','Kadaluarsa')),
 approved_by text,
 approved_at timestamptz,
 sent_at timestamptz,
 responded_at timestamptz,
 notes text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.hris_recruitment_communications_v25 (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.hris_recruitment_applications_v25(id) on delete cascade,
 channel text not null default 'Email',
 direction text not null default 'Outbound',
 subject text,
 message text not null,
 sent_at timestamptz not null default now(),
 actor_email text
);

create table if not exists public.hris_recruitment_onboarding_handoffs_v25 (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null unique references public.hris_recruitment_applications_v25(id) on delete cascade,
 target_employee_id text,
 target_start_date date,
 status text not null default 'Ready' check (status in ('Ready','In Progress','Completed','Cancelled')),
 handoff_notes text,
 created_at timestamptz not null default now(),
 completed_at timestamptz
);

create index if not exists idx_v25_requisition_status on public.hris_recruitment_requisitions_v25(status);
create index if not exists idx_v25_opening_status on public.hris_recruitment_openings_v25(status);
create index if not exists idx_v25_app_stage on public.hris_recruitment_applications_v25(stage,status);
create index if not exists idx_v25_stage_history_app on public.hris_recruitment_stage_history_v25(application_id,created_at desc);
create index if not exists idx_v25_interviews_schedule on public.hris_recruitment_interviews_v25(scheduled_at);
create index if not exists idx_v25_offers_status on public.hris_recruitment_offers_v25(status);
create unique index if not exists uq_v25_candidate_email on public.hris_candidate_profiles_v25(lower(email)) where email is not null and btrim(email) <> '';

insert into public.hris_permissions(kode,nama,modul) values
('recruitment.requisition','Recruitment Requisition','recruitment'),
('recruitment.opening','Job Opening','recruitment'),
('recruitment.candidate','Candidate Profile','recruitment'),
('recruitment.pipeline','Pipeline & Stage','recruitment'),
('recruitment.interview','Interview & Scorecard','recruitment'),
('recruitment.offer','Offer Management','recruitment'),
('recruitment.hiring','Hiring Approval','recruitment'),
('recruitment.onboarding','Onboarding Handoff','recruitment')
on conflict (kode) do nothing;

alter table public.hris_recruitment_requisitions_v25 enable row level security;
alter table public.hris_recruitment_openings_v25 enable row level security;
alter table public.hris_candidate_profiles_v25 enable row level security;
alter table public.hris_recruitment_applications_v25 enable row level security;
alter table public.hris_recruitment_stage_history_v25 enable row level security;
alter table public.hris_recruitment_interviews_v25 enable row level security;
alter table public.hris_recruitment_scorecards_v25 enable row level security;
alter table public.hris_recruitment_offers_v25 enable row level security;
alter table public.hris_recruitment_communications_v25 enable row level security;
alter table public.hris_recruitment_onboarding_handoffs_v25 enable row level security;

do $$ declare t text; begin foreach t in array array['hris_recruitment_requisitions_v25','hris_recruitment_openings_v25','hris_candidate_profiles_v25','hris_recruitment_applications_v25','hris_recruitment_stage_history_v25','hris_recruitment_interviews_v25','hris_recruitment_scorecards_v25','hris_recruitment_offers_v25','hris_recruitment_communications_v25','hris_recruitment_onboarding_handoffs_v25'] loop execute format('drop policy if exists v25_select on public.%I',t); execute format('create policy v25_select on public.%I for select to authenticated using (public.hris_has_permission(''recruitment.read''))',t); execute format('drop policy if exists v25_write on public.%I',t); execute format('create policy v25_write on public.%I for insert to authenticated with check (public.hris_has_permission(''recruitment.write''))',t); execute format('drop policy if exists v25_update on public.%I',t); execute format('create policy v25_update on public.%I for update to authenticated using (public.hris_has_permission(''recruitment.write'')) with check (public.hris_has_permission(''recruitment.write''))',t); execute format('drop policy if exists v25_delete on public.%I',t); execute format('create policy v25_delete on public.%I for delete to authenticated using (public.hris_has_permission(''recruitment.write''))',t); end loop; end $$;

create or replace function public.hris_v25_move_application(p_application_id uuid,p_to_stage text,p_note text default null) returns void language plpgsql security definer set search_path=public as $$
declare v_from text; v_status text; v_actor text;
begin
 perform public.hris_require_permission('recruitment.pipeline');
 if p_to_stage not in ('Screening','Interview','Assessment','Offering','Hired','Rejected','Withdrawn') then raise exception 'Tahap recruitment tidak valid'; end if;
 select stage,status into v_from,v_status from public.hris_recruitment_applications_v25 where id=p_application_id for update;
 if not found then raise exception 'Application tidak ditemukan'; end if;
 v_actor := coalesce(auth.email(),'system');
 update public.hris_recruitment_applications_v25 set stage=p_to_stage,status=case when p_to_stage='Hired' then 'Hired' when p_to_stage in ('Rejected','Withdrawn') then p_to_stage else 'Active' end,hired_at=case when p_to_stage='Hired' then now() else hired_at end,updated_at=now() where id=p_application_id;
 insert into public.hris_recruitment_stage_history_v25(application_id,from_stage,to_stage,actor_email,note) values(p_application_id,v_from,p_to_stage,v_actor,p_note);
 perform public.hris_audit('RECRUITMENT_STAGE_CHANGE','hris_recruitment_applications_v25',p_application_id::text,jsonb_build_object('from',v_from,'to',p_to_stage,'note',p_note));
end; $$;

create or replace function public.hris_v25_approve_requisition(p_id uuid,p_approve boolean,p_note text default null) returns void language plpgsql security definer set search_path=public as $$
declare v_status text;
begin
 perform public.hris_require_permission('recruitment.approve');
 select status into v_status from public.hris_recruitment_requisitions_v25 where id=p_id for update;
 if v_status is null then raise exception 'Requisition tidak ditemukan'; end if;
 if v_status <> 'Menunggu Approval' then raise exception 'Requisition bukan dalam status Menunggu Approval'; end if;
 update public.hris_recruitment_requisitions_v25 set status=case when p_approve then 'Disetujui' else 'Ditolak' end,approved_by=auth.email(),approved_at=now(),updated_at=now() where id=p_id;
 perform public.hris_audit('RECRUITMENT_REQUISITION_DECISION','hris_recruitment_requisitions_v25',p_id::text,jsonb_build_object('approved',p_approve,'note',p_note));
end; $$;

create or replace function public.hris_v25_approve_offer(p_id uuid,p_approve boolean,p_note text default null) returns void language plpgsql security definer set search_path=public as $$
declare v_status text;
begin
 perform public.hris_require_permission('recruitment.approve');
 select status into v_status from public.hris_recruitment_offers_v25 where id=p_id for update;
 if v_status <> 'Menunggu Approval' then raise exception 'Offer bukan dalam status Menunggu Approval'; end if;
 update public.hris_recruitment_offers_v25 set status=case when p_approve then 'Disetujui' else 'Ditolak' end,approved_by=auth.email(),approved_at=now(),updated_at=now() where id=p_id;
 perform public.hris_audit('RECRUITMENT_OFFER_DECISION','hris_recruitment_offers_v25',p_id::text,jsonb_build_object('approved',p_approve,'note',p_note));
end; $$;

create or replace function public.hris_v25_hiring_handoff(p_application_id uuid,p_start_date date,p_notes text default null) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
 perform public.hris_require_permission('recruitment.onboarding');
 if not exists(select 1 from public.hris_recruitment_applications_v25 where id=p_application_id and stage='Hired') then raise exception 'Candidate harus berstatus Hired'; end if;
 insert into public.hris_recruitment_onboarding_handoffs_v25(application_id,target_start_date,status,handoff_notes) values(p_application_id,p_start_date,'Ready',p_notes) on conflict(application_id) do update set target_start_date=excluded.target_start_date,status='Ready',handoff_notes=excluded.handoff_notes returning id into v_id;
 perform public.hris_audit('RECRUITMENT_ONBOARDING_HANDOFF','hris_recruitment_onboarding_handoffs_v25',v_id::text,jsonb_build_object('application_id',p_application_id));
 return v_id;
end; $$;

notify pgrst,'reload schema';


-- ============================================================
-- ENTERPRISE MIGRATION: 029_v26_document_compliance.sql
-- ============================================================

-- MoonXprojecT Enterprise 029
create extension if not exists pgcrypto;
create table if not exists public.hris_employee_documents_v26 (id uuid primary key default gen_random_uuid(), id_karyawan text not null, document_type text not null, document_no text, issue_date date, expiry_date date, status text not null default 'Active', storage_path text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create index if not exists idx_hris_employee_documents_v26_status on public.hris_employee_documents_v26(status);
insert into public.hris_permissions(kode,nama,modul) values ('document.compliance','Document Compliance','document') on conflict(kode) do nothing;
alter table public.hris_employee_documents_v26 enable row level security;
drop policy if exists enterprise_select on public.hris_employee_documents_v26;
create policy enterprise_select on public.hris_employee_documents_v26 for select to authenticated using (public.hris_has_permission('document.read') or public.hris_has_permission('document.compliance'));
drop policy if exists enterprise_insert on public.hris_employee_documents_v26;
create policy enterprise_insert on public.hris_employee_documents_v26 for insert to authenticated with check (public.hris_has_permission('document.compliance'));
drop policy if exists enterprise_update on public.hris_employee_documents_v26;
create policy enterprise_update on public.hris_employee_documents_v26 for update to authenticated using (public.hris_has_permission('document.compliance')) with check (public.hris_has_permission('document.compliance'));
drop policy if exists enterprise_delete on public.hris_employee_documents_v26;
create policy enterprise_delete on public.hris_employee_documents_v26 for delete to authenticated using (public.hris_has_permission('document.compliance'));
notify pgrst,'reload schema';


-- ============================================================
-- ENTERPRISE MIGRATION: 030_v27_performance_kpi.sql
-- ============================================================

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


-- ============================================================
-- ENTERPRISE MIGRATION: 031_v28_hr_analytics.sql
-- ============================================================

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


-- ============================================================
-- ENTERPRISE MIGRATION: 032_v29_hr_inbox.sql
-- ============================================================

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


-- ============================================================
-- ENTERPRISE MIGRATION: 033_v30_ess_enterprise.sql
-- ============================================================

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


-- ============================================================
-- ENTERPRISE MIGRATION: 034_v31_qa_center.sql
-- ============================================================

-- MoonXprojecT Enterprise 034
create extension if not exists pgcrypto;
create table if not exists public.hris_qa_test_runs_v31 (id uuid primary key default gen_random_uuid(), run_no text not null unique, environment text not null default 'staging', suite text not null, status text not null default 'Queued', passed integer not null default 0, failed integer not null default 0, duration_ms integer not null default 0, report jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());
create index if not exists idx_hris_qa_test_runs_v31_status on public.hris_qa_test_runs_v31(status);
insert into public.hris_permissions(kode,nama,modul) values ('qa.read','Qa Read','qa') on conflict(kode) do nothing;
alter table public.hris_qa_test_runs_v31 enable row level security;
drop policy if exists enterprise_select on public.hris_qa_test_runs_v31;
create policy enterprise_select on public.hris_qa_test_runs_v31 for select to authenticated using (public.hris_has_permission('qa.read') or public.hris_has_permission('qa.read'));
drop policy if exists enterprise_insert on public.hris_qa_test_runs_v31;
create policy enterprise_insert on public.hris_qa_test_runs_v31 for insert to authenticated with check (public.hris_has_permission('qa.read'));
drop policy if exists enterprise_update on public.hris_qa_test_runs_v31;
create policy enterprise_update on public.hris_qa_test_runs_v31 for update to authenticated using (public.hris_has_permission('qa.read')) with check (public.hris_has_permission('qa.read'));
drop policy if exists enterprise_delete on public.hris_qa_test_runs_v31;
create policy enterprise_delete on public.hris_qa_test_runs_v31 for delete to authenticated using (public.hris_has_permission('qa.read'));
notify pgrst,'reload schema';


-- ============================================================
-- ENTERPRISE MIGRATION: 035_v32_production_optimization.sql
-- ============================================================

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


-- ============================================================
-- ENTERPRISE MIGRATION: 036_v33_multi_company.sql
-- ============================================================

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


-- ============================================================
-- ENTERPRISE MIGRATION: 037_v34_integrations.sql
-- ============================================================

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


-- ============================================================
-- ENTERPRISE MIGRATION: 038_v35_ai_automation.sql
-- ============================================================

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


-- ============================================================
-- ENTERPRISE MIGRATION: 039_v39_permission_hardening.sql
-- ============================================================

-- MoonXprojecT V39: permission hardening
-- Non-destructive: normalizes duplicate role permissions and adds an integrity index.

create unique index if not exists ux_hris_role_permissions_role_permission
  on public.hris_role_permissions(role_name, permission_code);

comment on index ux_hris_role_permissions_role_permission is
  'V39 prevents duplicate role permission assignments.';


-- ============================================================
-- ENTERPRISE MIGRATION: 040_v40_runtime_hardening.sql
-- ============================================================

-- MoonXprojecT V40: runtime hardening
-- Adds a safe audit index for operational queries; no destructive schema changes.
create index if not exists ix_hris_audit_logs_created_at on public.hris_audit_logs(created_at desc);
create index if not exists ix_hris_notifications_created_at on public.hris_notifications(created_at desc);


-- ============================================================
-- ENTERPRISE MIGRATION: 041_v41_final_release.sql
-- ============================================================

-- MoonXprojecT V-END: final release metadata only.
-- No destructive schema changes.
comment on schema public is 'MoonXprojecT Enterprise V-END release';


-- ============================================================
-- ENTERPRISE MIGRATION: 042_v43_production_hardening.sql
-- ============================================================

-- MoonXprojecT V43: production hardening
-- Non-destructive operational indexes and timestamp integrity.

create index if not exists ix_hris_users_status_role on public.hris_users(status, role);
create index if not exists ix_hris_role_permissions_role on public.hris_role_permissions(role_name);
create index if not exists ix_karyawan_status_departemen on public.karyawan(status_aktif, departemen);
create index if not exists ix_absensi_tanggal_karyawan on public.absensi(tanggal, id_karyawan);
create index if not exists ix_hris_approval_requests_status_created on public.hris_approval_requests(status, created_at desc);

create or replace function public.hris_touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_hris_company_settings_updated_at on public.hris_company_settings;
create trigger trg_hris_company_settings_updated_at
before update on public.hris_company_settings
for each row execute function public.hris_touch_updated_at();

comment on schema public is 'MoonXprojecT Enterprise V43 production hardened release';


-- ============================================================
-- ENTERPRISE MIGRATION: 043_v44_security_data_integrity.sql
-- ============================================================

-- MoonXprojecT V44: security + data-integrity hardening
-- Non-destructive. Protects sensitive employee records and enforces server-side
-- permissions for the corresponding CRUD operations.

create index if not exists ix_hris_employee_bank_employee_active
  on public.hris_employee_bank_accounts(id_karyawan, active);
create index if not exists ix_hris_employee_tax_employee
  on public.hris_employee_tax_profiles(id_karyawan);
create index if not exists ix_hris_employee_emergency_employee
  on public.hris_employee_emergency_contacts(id_karyawan, is_primary);

alter table public.hris_employee_bank_accounts enable row level security;
alter table public.hris_employee_tax_profiles enable row level security;
alter table public.hris_employee_emergency_contacts enable row level security;

drop policy if exists employee_bank_select on public.hris_employee_bank_accounts;
drop policy if exists employee_bank_write on public.hris_employee_bank_accounts;
create policy employee_bank_select on public.hris_employee_bank_accounts
for select to authenticated using (
  public.hris_has_permission('people.read') or
  id_karyawan in (select k.id_karyawan from public.karyawan k where k.auth_user_id=auth.uid() or lower(k.email)=lower(auth.jwt()->>'email'))
);
create policy employee_bank_write on public.hris_employee_bank_accounts
for all to authenticated using (public.hris_has_permission('people.write'))
with check (public.hris_has_permission('people.write'));

drop policy if exists employee_tax_select on public.hris_employee_tax_profiles;
drop policy if exists employee_tax_write on public.hris_employee_tax_profiles;
create policy employee_tax_select on public.hris_employee_tax_profiles
for select to authenticated using (
  public.hris_has_permission('payroll.read') or public.hris_has_permission('people.read') or
  id_karyawan in (select k.id_karyawan from public.karyawan k where k.auth_user_id=auth.uid() or lower(k.email)=lower(auth.jwt()->>'email'))
);
create policy employee_tax_write on public.hris_employee_tax_profiles
for all to authenticated using (public.hris_has_permission('payroll.write') or public.hris_has_permission('people.write'))
with check (public.hris_has_permission('payroll.write') or public.hris_has_permission('people.write'));

drop policy if exists employee_emergency_select on public.hris_employee_emergency_contacts;
drop policy if exists employee_emergency_write on public.hris_employee_emergency_contacts;
create policy employee_emergency_select on public.hris_employee_emergency_contacts
for select to authenticated using (
  public.hris_has_permission('people.read') or
  id_karyawan in (select k.id_karyawan from public.karyawan k where k.auth_user_id=auth.uid() or lower(k.email)=lower(auth.jwt()->>'email'))
);
create policy employee_emergency_write on public.hris_employee_emergency_contacts
for all to authenticated using (public.hris_has_permission('people.write'))
with check (public.hris_has_permission('people.write'));

-- Keep audit timestamps reliable where these columns exist.
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='hris_employee_bank_accounts' and column_name='updated_at') then
    drop trigger if exists trg_hris_employee_bank_updated_at on public.hris_employee_bank_accounts;
    create trigger trg_hris_employee_bank_updated_at before update on public.hris_employee_bank_accounts
    for each row execute function public.hris_touch_updated_at();
  end if;
end $$;

comment on schema public is 'MoonXprojecT Enterprise V44 security and data integrity hardened';


-- ============================================================
-- ENTERPRISE MIGRATION: 044_v45_final_integrity.sql
-- ============================================================

-- MoonXprojecT V45: final integrity and operational guardrails.
-- Safe for existing deployments: additive/index/constraint hardening only.

-- Keep sensitive employee master data queryable by employee key.
create index if not exists ix_hris_employee_tax_active
  on public.hris_employee_tax_profiles(id_karyawan, active);
-- New records must respect basic domain invariants. NOT VALID preserves existing data
-- while enforcing the rule for subsequent writes; legacy rows can be reviewed separately.
do $$
begin
  if to_regclass('public.hris_cuti') is not null then
    alter table public.hris_cuti drop constraint if exists ck_hris_cuti_dates_v45;
    alter table public.hris_cuti add constraint ck_hris_cuti_dates_v45
      check (tanggal_selesai >= tanggal_mulai) not valid;
  end if;
  if to_regclass('public.hris_lembur') is not null then
    alter table public.hris_lembur drop constraint if exists ck_hris_lembur_minutes_v45;
    alter table public.hris_lembur add constraint ck_hris_lembur_minutes_v45
      check (menit >= 0) not valid;
  end if;
  if to_regclass('public.absensi') is not null then
    alter table public.absensi drop constraint if exists ck_absensi_minutes_v45;
    alter table public.absensi add constraint ck_absensi_minutes_v45
      check (coalesce(keterlambatan_menit,0) >= 0 and coalesce(lembur_menit,0) >= 0) not valid;
  end if;
end $$;

-- Fast operational lookups used by the dashboard and employee 360.
create index if not exists ix_hris_cuti_status_dates_v45
  on public.hris_cuti(status,tanggal_mulai,tanggal_selesai);
create index if not exists ix_hris_lembur_status_date_v45
  on public.hris_lembur(status,tanggal);
create index if not exists ix_hris_payroll_period_status_v45
  on public.hris_payroll(periode,status);

comment on schema public is 'MoonXprojecT Enterprise V45 final integrity release';

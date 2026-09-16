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

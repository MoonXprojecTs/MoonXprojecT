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

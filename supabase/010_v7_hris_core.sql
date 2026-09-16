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

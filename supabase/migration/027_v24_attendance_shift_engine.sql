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

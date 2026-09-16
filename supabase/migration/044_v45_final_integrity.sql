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

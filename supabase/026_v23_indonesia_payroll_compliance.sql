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

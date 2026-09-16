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

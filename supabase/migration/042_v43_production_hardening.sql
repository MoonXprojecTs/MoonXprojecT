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

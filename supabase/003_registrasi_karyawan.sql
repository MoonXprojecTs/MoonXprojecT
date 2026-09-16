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

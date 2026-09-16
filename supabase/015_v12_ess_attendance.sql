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

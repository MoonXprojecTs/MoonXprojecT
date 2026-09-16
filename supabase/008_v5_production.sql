-- MoonXprojecT V5: production controls, data integrity, observability and self-service readiness.
-- Run AFTER 007_v4_foundation.sql.

create extension if not exists pgcrypto;

-- Operational uniqueness / data quality.
create unique index if not exists uq_employee_email_active on public.karyawan(lower(email)) where email is not null and status_aktif=true;
create unique index if not exists uq_employee_document_name on public.hris_employee_documents(id_karyawan, jenis, nama_file);

-- Attendance quality checks. We intentionally validate obvious impossible values only;
-- company-specific shift rules remain configurable in the application.
create or replace function public.hris_validate_attendance_quality() returns trigger language plpgsql as $$
begin
  if new.tanggal is null then raise exception 'Tanggal absensi wajib diisi'; end if;
  if new.jam_masuk is not null and new.jam_pulang is not null and new.jam_pulang < new.jam_masuk then
    raise exception 'Jam pulang tidak boleh lebih awal dari jam masuk pada absensi normal';
  end if;
  if coalesce(new.keterlambatan_menit,0) < 0 then raise exception 'Keterlambatan tidak boleh negatif'; end if;
  if coalesce(new.lembur_menit,0) < 0 then raise exception 'Lembur tidak boleh negatif'; end if;
  return new;
end; $$;
drop trigger if exists trg_attendance_quality on public.absensi;
create trigger trg_attendance_quality before insert or update on public.absensi for each row execute function public.hris_validate_attendance_quality();

-- Leave integrity: valid date order and positive duration.
create or replace function public.hris_validate_leave_quality() returns trigger language plpgsql as $$
begin
  if new.tanggal_mulai is null or new.tanggal_selesai is null then raise exception 'Tanggal cuti wajib diisi'; end if;
  if new.tanggal_selesai < new.tanggal_mulai then raise exception 'Tanggal selesai tidak boleh sebelum tanggal mulai'; end if;
  if coalesce(new.jumlah_hari,0) <= 0 then new.jumlah_hari=(new.tanggal_selesai-new.tanggal_mulai)+1; end if;
  return new;
end; $$;
drop trigger if exists trg_leave_quality on public.hris_cuti;
create trigger trg_leave_quality before insert or update on public.hris_cuti for each row execute function public.hris_validate_leave_quality();

-- Payroll cannot be silently edited after final payment/lock.
create or replace function public.hris_payroll_final_guard() returns trigger language plpgsql as $$
begin
  if old.locked_at is not null then
    if coalesce(new.gaji_pokok,0)<>coalesce(old.gaji_pokok,0)
      or coalesce(new.tunjangan,0)<>coalesce(old.tunjangan,0)
      or coalesce(new.uang_makan,0)<>coalesce(old.uang_makan,0)
      or coalesce(new.transport,0)<>coalesce(old.transport,0)
      or coalesce(new.lembur,0)<>coalesce(old.lembur,0)
      or coalesce(new.bonus,0)<>coalesce(old.bonus,0)
      or coalesce(new.potongan,0)<>coalesce(old.potongan,0)
      or coalesce(new.bpjs,0)<>coalesce(old.bpjs,0)
      or coalesce(new.pph21,0)<>coalesce(old.pph21,0)
    then raise exception 'Payroll final sudah dikunci dan tidak dapat diubah'; end if;
  end if;
  return new;
end; $$;
drop trigger if exists trg_payroll_final_guard on public.hris_payroll;
create trigger trg_payroll_final_guard before update on public.hris_payroll for each row execute function public.hris_payroll_final_guard();

-- Reusable notification helper for workflows/integrations.
create or replace function public.hris_notify(p_recipient text,p_type text,p_title text,p_message text,p_link text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if p_recipient is null or trim(p_recipient)='' then return null; end if;
  insert into public.hris_notifications(recipient_email,type,title,message,link) values(lower(trim(p_recipient)),p_type,p_title,p_message,p_link) returning id into v_id;
  return v_id;
end; $$;
grant execute on function public.hris_notify(text,text,text,text,text) to authenticated;

-- Approval history + notifications. Replaces state-only observability with a durable trail.
create or replace function public.hris_record_approval_history() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='UPDATE' and (old.status is distinct from new.status or old.current_step is distinct from new.current_step) then
    insert into public.hris_approval_history(approval_id,modul,record_id,step_no,approver_role,actor_email,status,catatan)
    values(new.id,new.modul,new.record_id,new.current_step,new.approver_role,coalesce(new.decided_by,auth.jwt()->>'email'),new.status,new.catatan);
  end if;
  return new;
end; $$;
drop trigger if exists trg_approval_history on public.hris_approval_requests;
create trigger trg_approval_history after update on public.hris_approval_requests for each row execute function public.hris_record_approval_history();

-- Candidate, payroll and leave changes get an application-visible notification where email is known.
create or replace function public.hris_notify_leave_decision() returns trigger language plpgsql security definer set search_path=public as $$
declare v_email text;
begin
 if tg_op='UPDATE' and old.status is distinct from new.status and new.status in ('Disetujui','Ditolak') then
   select email into v_email from public.karyawan where id_karyawan=new.id_karyawan limit 1;
   perform public.hris_notify(v_email,'leave','Status pengajuan cuti',format('Pengajuan cuti Anda berstatus %s.',new.status),'#/leave-request');
 end if;
 return new;
end; $$;
drop trigger if exists trg_notify_leave_decision on public.hris_cuti;
create trigger trg_notify_leave_decision after update of status on public.hris_cuti for each row execute function public.hris_notify_leave_decision();

-- System health view for admin dashboards and future monitoring.
create or replace view public.hris_system_health as
select
  (select count(*) from public.karyawan where status_aktif=true) as active_employees,
  (select count(*) from public.hris_cuti where status='Menunggu') as pending_leave,
  (select count(*) from public.hris_lembur where status='Menunggu') as pending_overtime,
  (select count(*) from public.hris_payroll where status='Menunggu Approval') as pending_payroll,
  (select count(*) from public.hris_approval_requests where status='Menunggu') as pending_approvals,
  (select count(*) from public.hris_notifications where is_read=false) as unread_notifications,
  now() as checked_at;

-- More explicit permission catalog.
insert into public.hris_permissions(kode,nama,modul) values
('people.history','Lihat riwayat karyawan','people'),
('people.documents','Kelola dokumen karyawan','people'),
('notifications.read','Lihat notifikasi','notifications'),
('notifications.write','Kelola notifikasi','notifications'),
('system.health','Lihat kesehatan sistem','system')
on conflict (kode) do nothing;

notify pgrst,'reload schema';

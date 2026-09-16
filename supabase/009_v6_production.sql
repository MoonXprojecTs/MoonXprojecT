-- MoonXprojecT V6 Production: integrity, approval safety, permission consistency and operational controls.
-- Run AFTER 008_v5_production.sql.

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- 1) Stronger data constraints / indexes
-- -----------------------------------------------------------------------------
create unique index if not exists uq_active_employee_nomor_induk
  on public.karyawan(lower(trim(nomor_induk)))
  where nomor_induk is not null and trim(nomor_induk)<>'' and status_aktif=true;

create index if not exists idx_absensi_employee_date on public.absensi(id_karyawan,tanggal desc);
create index if not exists idx_cuti_status_dates on public.hris_cuti(status,tanggal_mulai,tanggal_selesai);
create index if not exists idx_lembur_status_date on public.hris_lembur(status,tanggal desc);
create index if not exists idx_payroll_period_status on public.hris_payroll(periode,status);
create unique index if not exists uq_active_approval_request
  on public.hris_approval_requests(modul,record_id)
  where status='Menunggu';

-- -----------------------------------------------------------------------------
-- 2) Prevent impossible leave balance deductions.
-- -----------------------------------------------------------------------------
create or replace function public.hris_validate_leave_balance()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  v_saldo numeric;
  v_tahun integer;
begin
  if new.status='Disetujui' and (old.status is distinct from new.status) then
    v_tahun:=extract(year from new.tanggal_mulai)::integer;
    select saldo into v_saldo
      from public.hris_saldo_cuti
      where id_karyawan=new.id_karyawan and tahun=v_tahun and jenis=new.jenis
      for update;
    if v_saldo is not null and v_saldo < coalesce(new.jumlah_hari,0) then
      raise exception 'Saldo cuti tidak mencukupi. Tersedia %, diperlukan %',v_saldo,new.jumlah_hari;
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists trg_leave_balance_guard on public.hris_cuti;
create trigger trg_leave_balance_guard before update of status on public.hris_cuti
for each row execute function public.hris_validate_leave_balance();

-- -----------------------------------------------------------------------------
-- 3) Approval decisions must always be tied to the current workflow role and
--    cannot be duplicated for the same record.
-- -----------------------------------------------------------------------------
create or replace function public.hris_submit_approval(p_modul text,p_record_id text)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_email text:=auth.jwt()->>'email';
  v_steps jsonb;
  v_role_approver text;
  v_id uuid;
begin
  if p_modul='leave' then perform public.hris_require_permission('leave.write');
  elsif p_modul='overtime' then perform public.hris_require_permission('overtime.write');
  elsif p_modul='payroll' then perform public.hris_require_permission('payroll.write');
  elsif p_modul='recruitment' then perform public.hris_require_permission('recruitment.write');
  else raise exception 'Modul approval tidak didukung'; end if;

  if exists(select 1 from public.hris_approval_requests where modul=p_modul and record_id=p_record_id and status='Menunggu') then
    raise exception 'Record sudah memiliki approval yang sedang berjalan';
  end if;

  select steps into v_steps from public.hris_workflows
    where modul=p_modul and aktif=true order by created_at limit 1;
  if v_steps is null or jsonb_array_length(v_steps)=0 then
    v_steps:='[{"step":1,"role":"Super Admin"}]'::jsonb;
  end if;
  v_role_approver:=v_steps->0->>'role';

  insert into public.hris_approval_requests(modul,record_id,requester_email,current_step,status,approver_role)
  values(p_modul,p_record_id,v_email,1,'Menunggu',v_role_approver)
  returning id into v_id;

  perform public.hris_audit('SUBMIT',p_modul,p_record_id,jsonb_build_object('approval_id',v_id));
  return v_id;
end; $$;
grant execute on function public.hris_submit_approval(text,text) to authenticated;

-- -----------------------------------------------------------------------------
-- 4) Payroll state machine. No skipping straight from Draft to Dibayar.
-- -----------------------------------------------------------------------------
create or replace function public.hris_validate_payroll_state()
returns trigger language plpgsql as $$
begin
  if old.status is distinct from new.status then
    if old.status='Draft' and new.status not in ('Draft','Menunggu Approval','Ditolak') then
      raise exception 'Payroll Draft harus melalui Menunggu Approval';
    elsif old.status='Menunggu Approval' and new.status not in ('Menunggu Approval','Disetujui','Ditolak') then
      raise exception 'Payroll menunggu approval hanya dapat disetujui atau ditolak';
    elsif old.status='Disetujui' and new.status not in ('Disetujui','Dibayar') then
      raise exception 'Payroll disetujui hanya dapat dibayar';
    elsif old.status='Dibayar' and new.status<>'Dibayar' then
      raise exception 'Payroll yang sudah dibayar tidak dapat dikembalikan statusnya';
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists trg_payroll_state_guard on public.hris_payroll;
create trigger trg_payroll_state_guard before update on public.hris_payroll
for each row execute function public.hris_validate_payroll_state();

-- -----------------------------------------------------------------------------
-- 5) Only server-side RPC may finalize payroll. Direct status changes to
--    Disetujui/Dibayar are rejected unless actor has the matching permission.
-- -----------------------------------------------------------------------------
create or replace function public.hris_payroll_transition_guard()
returns trigger language plpgsql as $$
begin
  if new.status='Menunggu Approval' and old.status='Draft' then
    perform public.hris_require_permission('payroll.write');
  elsif new.status='Disetujui' and old.status='Menunggu Approval' then
    perform public.hris_require_permission('payroll.approve');
  elsif new.status='Dibayar' and old.status='Disetujui' then
    if not public.hris_has_permission('payroll.pay') and not public.hris_has_permission('payroll.lock') then
      raise exception 'Akses ditolak: payroll.pay';
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists trg_payroll_transition_guard on public.hris_payroll;
create trigger trg_payroll_transition_guard before update on public.hris_payroll
for each row execute function public.hris_payroll_transition_guard();

-- -----------------------------------------------------------------------------
-- 6) Operational audit coverage for critical master/transaction tables.
-- -----------------------------------------------------------------------------
create or replace function public.hris_audit_safe_row()
returns trigger language plpgsql security definer set search_path=public as $$
declare
  v_id text;
begin
  v_id:=coalesce((to_jsonb(new)->>'id'),(to_jsonb(old)->>'id'),(to_jsonb(new)->>'id_karyawan'),(to_jsonb(old)->>'id_karyawan'));
  perform public.hris_audit(TG_OP,TG_TABLE_NAME,v_id,jsonb_build_object('record_id',v_id,'operation',TG_OP));
  return coalesce(new,old);
end; $$;

do $$
declare t text;
begin
  foreach t in array array['hris_cabang','hris_departemen','hris_jabatan','hris_shift','hris_jadwal','hris_hari_libur','hris_cuti','hris_lembur','hris_payroll_komponen','hris_kandidat','hris_lowongan','hris_interview','hris_job_offers','hris_kpi','hris_performance','hris_employee_documents','hris_approval_requests'] loop
    execute format('drop trigger if exists trg_v6_audit_%I on public.%I',t,t);
    execute format('create trigger trg_v6_audit_%I after insert or update or delete on public.%I for each row execute function public.hris_audit_safe_row()',t,t);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 7) Permission catalog additions and role-permission RLS consistency.
-- -----------------------------------------------------------------------------
insert into public.hris_permissions(kode,nama,modul) values
('people.documents','Kelola dokumen karyawan','people'),
('people.history','Lihat riwayat karyawan','people'),
('notifications.read','Lihat notifikasi','notifications'),
('notifications.write','Kelola notifikasi','notifications'),
('system.health','Lihat kesehatan sistem','system')
on conflict(kode) do nothing;

drop policy if exists role_permissions_read on public.hris_role_permissions;
drop policy if exists role_permissions_write on public.hris_role_permissions;
drop policy if exists "role permissions read" on public.hris_role_permissions;
drop policy if exists "role permissions write" on public.hris_role_permissions;
create policy role_permissions_read on public.hris_role_permissions for select to authenticated
using (public.hris_is_super_admin() or role_name=public.hris_my_role());
create policy role_permissions_write on public.hris_role_permissions for all to authenticated
using (public.hris_is_super_admin()) with check (public.hris_is_super_admin());

-- -----------------------------------------------------------------------------
-- 8) Health view: expose operational counters without exposing row-level data.
-- -----------------------------------------------------------------------------
create or replace view public.hris_system_health as
select
  (select count(*) from public.karyawan where status_aktif=true) as active_employees,
  (select count(*) from public.hris_cuti where status='Menunggu') as pending_leave,
  (select count(*) from public.hris_lembur where status='Menunggu') as pending_overtime,
  (select count(*) from public.hris_payroll where status='Menunggu Approval') as pending_payroll,
  (select count(*) from public.hris_approval_requests where status='Menunggu') as pending_approvals,
  (select count(*) from public.hris_notifications where is_read=false and lower(recipient_email)=lower(auth.jwt()->>'email')) as unread_notifications,
  now() as checked_at;

notify pgrst,'reload schema';

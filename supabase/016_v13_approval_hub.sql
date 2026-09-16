-- MoonXprojecT V13 — unified approval hub, ESS workflow sync, notifications and audit
create extension if not exists pgcrypto;

insert into public.hris_permissions(kode,nama,modul) values
('approval.manage','Kelola seluruh approval','approval'),
('ess.profile.approve','Approve perubahan profil ESS','people'),
('ess.attendance.approve','Approve koreksi absensi ESS','attendance'),
('ess.leave.approve','Approve cuti ESS','leave'),
('ess.overtime.approve','Approve lembur ESS','overtime')
on conflict(kode) do nothing;

create index if not exists idx_approval_pending_role on public.hris_approval_requests(status,approver_role,created_at desc);

create or replace function public.hris_v13_module_permission(p_modul text) returns boolean
language plpgsql stable security definer set search_path=public as $$
begin
 if public.hris_my_role()='Super Admin' then return true; end if;
 if p_modul in ('leave','ess_leave') then return public.hris_has_permission('leave.approve') or public.hris_has_permission('ess.leave.approve'); end if;
 if p_modul in ('overtime','ess_overtime') then return public.hris_has_permission('overtime.approve') or public.hris_has_permission('ess.overtime.approve'); end if;
 if p_modul='payroll' then return public.hris_has_permission('payroll.approve'); end if;
 if p_modul in ('attendance','ess_attendance') then return public.hris_has_permission('attendance.write') or public.hris_has_permission('ess.attendance.approve'); end if;
 if p_modul in ('people','ess_profile') then return public.hris_has_permission('people.write') or public.hris_has_permission('ess.profile.approve'); end if;
 return public.hris_has_permission('approval.manage');
end; $$;

create or replace function public.hris_v13_create_approval(p_modul text,p_record_id text,p_requester text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_role text; v_email text:=coalesce(p_requester,auth.jwt()->>'email');
begin
 select coalesce(steps->0->>'role','Super Admin') into v_role from public.hris_workflows where modul=case when p_modul like 'ess_%' then replace(p_modul,'ess_','') else p_modul end and aktif=true order by created_at limit 1;
 v_role:=coalesce(v_role,'Super Admin');
 if exists(select 1 from public.hris_approval_requests where modul=p_modul and record_id=p_record_id and status='Menunggu') then
   select id into v_id from public.hris_approval_requests where modul=p_modul and record_id=p_record_id and status='Menunggu' order by created_at desc limit 1;
 else
   insert into public.hris_approval_requests(modul,record_id,requester_email,current_step,status,approver_role)
   values(p_modul,p_record_id,v_email,1,'Menunggu',v_role) returning id into v_id;
 end if;
 if v_id is not null then perform public.hris_audit('SUBMIT',p_modul,p_record_id,jsonb_build_object('approval_id',v_id,'requester',v_email)); end if;
 return v_id;
end; $$;

grant execute on function public.hris_v13_create_approval(text,text,text) to authenticated;

create or replace function public.hris_v13_ess_request_trigger() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if tg_table_name='hris_employee_leave_requests' then
   perform public.hris_v13_create_approval('ess_leave',new.id::text);
 elsif tg_table_name='hris_employee_overtime_requests' then
   perform public.hris_v13_create_approval('ess_overtime',new.id::text);
 elsif tg_table_name='hris_employee_attendance_requests' then
   perform public.hris_v13_create_approval('ess_attendance',new.id::text);
 elsif tg_table_name='hris_employee_profile_requests' then
   perform public.hris_v13_create_approval('ess_profile',new.id::text);
 end if;
 return new;
end; $$;

drop trigger if exists trg_v13_ess_leave_approval on public.hris_employee_leave_requests;
create trigger trg_v13_ess_leave_approval after insert on public.hris_employee_leave_requests for each row execute function public.hris_v13_ess_request_trigger();
drop trigger if exists trg_v13_ess_ot_approval on public.hris_employee_overtime_requests;
create trigger trg_v13_ess_ot_approval after insert on public.hris_employee_overtime_requests for each row execute function public.hris_v13_ess_request_trigger();
drop trigger if exists trg_v13_ess_att_approval on public.hris_employee_attendance_requests;
create trigger trg_v13_ess_att_approval after insert on public.hris_employee_attendance_requests for each row execute function public.hris_v13_ess_request_trigger();
drop trigger if exists trg_v13_ess_profile_approval on public.hris_employee_profile_requests;
create trigger trg_v13_ess_profile_approval after insert on public.hris_employee_profile_requests for each row execute function public.hris_v13_ess_request_trigger();

create or replace function public.hris_v13_decide_approval(p_id uuid,p_status text,p_catatan text default null)
returns void language plpgsql security definer set search_path=public as $$
declare r record; v_role text:=public.hris_my_role(); v_email text:=auth.jwt()->>'email'; v_days numeric; v_emp text; v_jenis text; v_start date; v_end date; v_new text; v_field text;
begin
 if p_status not in ('Disetujui','Ditolak') then raise exception 'Status approval tidak valid'; end if;
 select * into r from public.hris_approval_requests where id=p_id for update;
 if not found then raise exception 'Approval tidak ditemukan'; end if;
 if r.status<>'Menunggu' then raise exception 'Approval sudah diproses'; end if;
 if v_role<>r.approver_role and v_role<>'Super Admin' then raise exception 'Role % tidak berwenang pada tahap ini',v_role; end if;
 if not public.hris_v13_module_permission(r.modul) then raise exception 'Anda tidak memiliki permission untuk approval %',r.modul; end if;

 if p_status='Ditolak' then
   update public.hris_approval_requests set status='Ditolak',decided_by=v_email,decided_at=now(),catatan=p_catatan where id=p_id;
   if r.modul='ess_leave' then update public.hris_employee_leave_requests set status='Ditolak',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='ess_overtime' then update public.hris_employee_overtime_requests set status='Ditolak',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='ess_attendance' then update public.hris_employee_attendance_requests set status='Ditolak',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='ess_profile' then update public.hris_employee_profile_requests set status='Ditolak',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='leave' then update public.hris_cuti set status='Ditolak',disetujui_oleh=v_email where id=r.record_id::uuid;
   elsif r.modul='overtime' then update public.hris_lembur set status='Ditolak',disetujui_oleh=v_email where id=r.record_id::uuid;
   elsif r.modul='payroll' then update public.hris_payroll set status='Ditolak',approved_by=v_email,approved_at=now() where id=r.record_id::uuid;
   end if;
 else
   update public.hris_approval_requests set status='Disetujui',decided_by=v_email,decided_at=now(),catatan=p_catatan where id=p_id;
   if r.modul='ess_leave' then
     select id_karyawan,jenis,tanggal_mulai,tanggal_selesai,jumlah_hari into v_emp,v_jenis,v_start,v_end,v_days from public.hris_employee_leave_requests where id=r.record_id::uuid;
     if v_emp is null then raise exception 'Pengajuan cuti ESS tidak ditemukan'; end if;
     insert into public.hris_cuti(id_karyawan,jenis,tanggal_mulai,tanggal_selesai,jumlah_hari,alasan,status,disetujui_oleh)
     select v_emp,v_jenis,v_start,v_end,v_days,(select alasan from public.hris_employee_leave_requests where id=r.record_id::uuid),'Disetujui',v_email
     where not exists(select 1 from public.hris_cuti c where c.id_karyawan=v_emp and c.tanggal_mulai=v_start and c.tanggal_selesai=v_end and c.status='Disetujui');
     update public.hris_employee_leave_requests set status='Disetujui',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='ess_overtime' then
     select id_karyawan,tanggal into v_emp,v_start from public.hris_employee_overtime_requests where id=r.record_id::uuid;
     insert into public.hris_lembur(id_karyawan,tanggal,menit,alasan,status,disetujui_oleh)
     select e.id_karyawan,e.tanggal,e.menit,e.alasan,'Disetujui',v_email from public.hris_employee_overtime_requests e where e.id=r.record_id::uuid;
     update public.hris_employee_overtime_requests set status='Disetujui',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='ess_attendance' then
     select id_karyawan,tanggal,jam_masuk,jam_pulang into v_emp,v_start,v_new,v_field from public.hris_employee_attendance_requests where id=r.record_id::uuid;
     insert into public.absensi(id_karyawan,tanggal,jam_masuk,jam_pulang,status,sumber,keterangan)
     select e.id_karyawan,e.tanggal,e.jam_masuk,e.jam_pulang,case when e.jenis='Lupa Absen' then 'Hadir' else 'Koreksi' end,'ESS Approval',e.alasan from public.hris_employee_attendance_requests e where e.id=r.record_id::uuid and not exists(select 1 from public.absensi a where a.id_karyawan=e.id_karyawan and a.tanggal=e.tanggal and a.sumber='ESS Approval');
     update public.hris_employee_attendance_requests set status='Disetujui',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='ess_profile' then
     select id_karyawan,field_name,new_value into v_emp,v_field,v_new from public.hris_employee_profile_requests where id=r.record_id::uuid;
     if v_field not in ('no_telp','alamat_rumah','email') then raise exception 'Field profil tidak diizinkan'; end if;
     execute format('update public.karyawan set %I=$1 where id_karyawan=$2',v_field) using v_new,v_emp;
     update public.hris_employee_profile_requests set status='Disetujui',decided_by=v_email,decided_at=now() where id=r.record_id::uuid;
   elsif r.modul='leave' then
     select jumlah_hari into v_days from public.hris_cuti where id=r.record_id::uuid;
     update public.hris_cuti set status='Disetujui',disetujui_oleh=v_email where id=r.record_id::uuid;
   elsif r.modul='overtime' then update public.hris_lembur set status='Disetujui',disetujui_oleh=v_email where id=r.record_id::uuid;
   elsif r.modul='payroll' then update public.hris_payroll set status='Disetujui',approved_by=v_email,approved_at=now() where id=r.record_id::uuid;
   end if;
 end if;
 perform public.hris_audit('APPROVAL',r.modul,r.record_id,jsonb_build_object('approval_id',p_id,'status',p_status,'catatan',p_catatan,'actor',v_email));
end; $$;

grant execute on function public.hris_v13_decide_approval(uuid,text,text) to authenticated;

create or replace function public.hris_v13_notify_approval() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_emp text;
begin
 if old.status is distinct from new.status and new.status in ('Disetujui','Ditolak') then
   v_emp:=case when new.modul like 'ess_%' then coalesce((select id_karyawan from public.hris_employee_leave_requests where id=new.record_id::uuid),(select id_karyawan from public.hris_employee_overtime_requests where id=new.record_id::uuid),(select id_karyawan from public.hris_employee_attendance_requests where id=new.record_id::uuid),(select id_karyawan from public.hris_employee_profile_requests where id=new.record_id::uuid)) else null end;
   if v_emp is not null then insert into public.hris_employee_notifications(id_karyawan,title,message,type,link) values(v_emp,'Status pengajuan HRIS',format('Pengajuan %s Anda berstatus %s.',new.modul,new.status),'approval','#/employee'); end if;
 end if;
 return new;
end; $$;

drop trigger if exists trg_v13_approval_notification on public.hris_approval_requests;
create trigger trg_v13_approval_notification after update of status on public.hris_approval_requests for each row execute function public.hris_v13_notify_approval();

-- Keep the existing public function name used by the UI, but route decisions through V13.
create or replace function public.hris_decide_approval(p_id uuid,p_status text,p_catatan text default null)
returns void language sql security definer set search_path=public as $$ select public.hris_v13_decide_approval(p_id,p_status,p_catatan); $$;
grant execute on function public.hris_decide_approval(uuid,text,text) to authenticated;

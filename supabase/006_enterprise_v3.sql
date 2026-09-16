-- MoonXprojecT V3: granular authorization, approval engine, leave controls, payroll locking.
-- Run AFTER 005_enterprise_hardening.sql.

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Permission catalog
-- -----------------------------------------------------------------------------
insert into public.hris_permissions(kode,nama,modul) values
('roles.read','Lihat role','roles'),
('roles.write','Kelola role','roles'),
('people.delete','Hapus karyawan','people'),
('reports.export','Export laporan','reports'),
('payroll.lock','Kunci payroll','payroll'),
('approval.read','Lihat approval','approval'),
('overtime.write','Kelola lembur','overtime')
on conflict (kode) do nothing;

-- -----------------------------------------------------------------------------
-- Authorization helper. Wildcards and module-level grants are supported.
-- -----------------------------------------------------------------------------
create or replace function public.hris_has_permission(p_code text)
returns boolean language sql stable security definer set search_path=public as $$
  select public.hris_is_super_admin() or exists(
    select 1 from public.hris_role_permissions
    where role_name=public.hris_my_role()
      and (permission_code='*' or permission_code=p_code or permission_code=split_part(p_code,'.',1))
  );
$$;
grant execute on function public.hris_has_permission(text) to authenticated;

drop function if exists public.hris_require_permission(text);
create or replace function public.hris_require_permission(p_code text)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.hris_has_permission(p_code) then
   raise exception 'Akses ditolak: %',p_code using errcode='42501';
 end if;
end; $$;
grant execute on function public.hris_require_permission(text) to authenticated;

-- -----------------------------------------------------------------------------
-- RLS policies: module permissions are enforced server-side, not only in UI.
-- -----------------------------------------------------------------------------

drop policy if exists karyawan_select on public.karyawan;
drop policy if exists karyawan_insert on public.karyawan;
drop policy if exists karyawan_update on public.karyawan;
drop policy if exists karyawan_delete on public.karyawan;
create policy karyawan_select on public.karyawan for select to authenticated using (
 public.hris_has_permission('people.read') or auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')
);
create policy karyawan_insert on public.karyawan for insert to authenticated with check (
 public.hris_has_permission('people.write') or auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')
);
create policy karyawan_update on public.karyawan for update to authenticated using (
 public.hris_has_permission('people.write') or auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')
) with check (
 public.hris_has_permission('people.write') or auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')
);
create policy karyawan_delete on public.karyawan for delete to authenticated using (public.hris_has_permission('people.delete'));

drop policy if exists absensi_select on public.absensi;
drop policy if exists absensi_insert on public.absensi;
drop policy if exists absensi_update on public.absensi;
drop policy if exists absensi_delete on public.absensi;
create policy absensi_select on public.absensi for select to authenticated using (
 public.hris_has_permission('attendance.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy absensi_insert on public.absensi for insert to authenticated with check (
 public.hris_has_permission('attendance.write') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy absensi_update on public.absensi for update to authenticated using (
 public.hris_has_permission('attendance.write') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
) with check (
 public.hris_has_permission('attendance.write') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy absensi_delete on public.absensi for delete to authenticated using (public.hris_has_permission('attendance.write'));

-- Leave / overtime / payroll


drop policy if exists cuti_select on public.hris_cuti;
drop policy if exists cuti_insert on public.hris_cuti;
drop policy if exists cuti_update on public.hris_cuti;
drop policy if exists cuti_delete on public.hris_cuti;
create policy cuti_select on public.hris_cuti for select to authenticated using (
 public.hris_has_permission('leave.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy cuti_insert on public.hris_cuti for insert to authenticated with check (
 public.hris_has_permission('leave.write') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy cuti_update on public.hris_cuti for update to authenticated using (public.hris_has_permission('leave.write')) with check (public.hris_has_permission('leave.write'));
create policy cuti_delete on public.hris_cuti for delete to authenticated using (public.hris_has_permission('leave.write'));

drop policy if exists lembur_select on public.hris_lembur;
drop policy if exists lembur_insert on public.hris_lembur;
drop policy if exists lembur_update on public.hris_lembur;
drop policy if exists lembur_delete on public.hris_lembur;
create policy lembur_select on public.hris_lembur for select to authenticated using (
 public.hris_has_permission('overtime.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy lembur_insert on public.hris_lembur for insert to authenticated with check (
 public.hris_has_permission('overtime.write') or public.hris_has_permission('overtime.approve') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy lembur_update on public.hris_lembur for update to authenticated using (public.hris_has_permission('overtime.approve') or public.hris_has_permission('overtime.write')) with check (public.hris_has_permission('overtime.approve') or public.hris_has_permission('overtime.write'));
create policy lembur_delete on public.hris_lembur for delete to authenticated using (public.hris_has_permission('overtime.write'));

drop policy if exists payroll_select on public.hris_payroll;
drop policy if exists payroll_write on public.hris_payroll;
create policy payroll_select on public.hris_payroll for select to authenticated using (
 public.hris_has_permission('payroll.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email'))
);
create policy payroll_write on public.hris_payroll for all to authenticated using (
 public.hris_has_permission('payroll.write') or public.hris_has_permission('payroll.approve') or public.hris_has_permission('payroll.pay') or public.hris_has_permission('payroll.lock')
) with check (
 public.hris_has_permission('payroll.write') or public.hris_has_permission('payroll.approve') or public.hris_has_permission('payroll.pay') or public.hris_has_permission('payroll.lock')
);

drop policy if exists audit_select on public.hris_audit_logs;
drop policy if exists audit_insert on public.hris_audit_logs;
create policy audit_select on public.hris_audit_logs for select to authenticated using (public.hris_has_permission('audit.read'));
create policy audit_insert on public.hris_audit_logs for insert to authenticated with check (public.hris_has_permission('audit.read'));

drop policy if exists roles_select on public.hris_roles;
drop policy if exists roles_write on public.hris_roles;
create policy roles_select on public.hris_roles for select to authenticated using (public.hris_has_permission('roles.read') or public.hris_has_permission('roles.write'));
create policy roles_write on public.hris_roles for all to authenticated using (public.hris_has_permission('roles.write')) with check (public.hris_has_permission('roles.write'));

-- Approval requests / workflows / hardening tables
alter table public.hris_approval_requests enable row level security;
alter table public.hris_workflows enable row level security;
alter table public.hris_payroll_detail enable row level security;
alter table public.hris_kandidat_history enable row level security;
alter table public.hris_interview_scorecard enable row level security;
alter table public.hris_onboarding enable row level security;
alter table public.hris_job_offers enable row level security;

drop policy if exists approval_select on public.hris_approval_requests;
drop policy if exists approval_write on public.hris_approval_requests;
create policy approval_select on public.hris_approval_requests for select to authenticated using (
 public.hris_has_permission('approval.read') or public.hris_has_permission('leave.approve') or public.hris_has_permission('overtime.approve') or public.hris_has_permission('payroll.approve') or lower(requester_email)=lower(auth.jwt()->>'email')
);
create policy approval_write on public.hris_approval_requests for all to authenticated using (
 public.hris_has_permission('leave.approve') or public.hris_has_permission('overtime.approve') or public.hris_has_permission('payroll.approve') or public.hris_has_permission('recruitment.approve')
) with check (
 public.hris_has_permission('leave.approve') or public.hris_has_permission('overtime.approve') or public.hris_has_permission('payroll.approve') or public.hris_has_permission('recruitment.approve')
);

drop policy if exists workflow_select on public.hris_workflows;
create policy workflow_select on public.hris_workflows for select to authenticated using (true);
drop policy if exists workflow_write on public.hris_workflows;
create policy workflow_write on public.hris_workflows for all to authenticated using (public.hris_has_permission('settings.write')) with check (public.hris_has_permission('settings.write'));

drop policy if exists payroll_detail_select on public.hris_payroll_detail;
create policy payroll_detail_select on public.hris_payroll_detail for select to authenticated using (public.hris_has_permission('payroll.read'));
drop policy if exists payroll_detail_write on public.hris_payroll_detail;
create policy payroll_detail_write on public.hris_payroll_detail for all to authenticated using (public.hris_has_permission('payroll.write')) with check (public.hris_has_permission('payroll.write'));

drop policy if exists recruitment_history_select on public.hris_kandidat_history;
create policy recruitment_history_select on public.hris_kandidat_history for select to authenticated using (public.hris_has_permission('recruitment.read'));
drop policy if exists recruitment_history_write on public.hris_kandidat_history;
create policy recruitment_history_write on public.hris_kandidat_history for all to authenticated using (public.hris_has_permission('recruitment.write')) with check (public.hris_has_permission('recruitment.write'));
drop policy if exists scorecard_select on public.hris_interview_scorecard;
create policy scorecard_select on public.hris_interview_scorecard for select to authenticated using (public.hris_has_permission('recruitment.read'));
drop policy if exists scorecard_write on public.hris_interview_scorecard;
create policy scorecard_write on public.hris_interview_scorecard for all to authenticated using (public.hris_has_permission('recruitment.write')) with check (public.hris_has_permission('recruitment.write'));
drop policy if exists onboarding_select on public.hris_onboarding;
create policy onboarding_select on public.hris_onboarding for select to authenticated using (public.hris_has_permission('recruitment.read') or public.hris_has_permission('people.read'));
drop policy if exists onboarding_write on public.hris_onboarding;
create policy onboarding_write on public.hris_onboarding for all to authenticated using (public.hris_has_permission('recruitment.write') or public.hris_has_permission('people.write')) with check (public.hris_has_permission('recruitment.write') or public.hris_has_permission('people.write'));
drop policy if exists offers_select on public.hris_job_offers;
create policy offers_select on public.hris_job_offers for select to authenticated using (public.hris_has_permission('recruitment.read'));
drop policy if exists offers_write on public.hris_job_offers;
create policy offers_write on public.hris_job_offers for all to authenticated using (public.hris_has_permission('recruitment.write')) with check (public.hris_has_permission('recruitment.write'));

-- -----------------------------------------------------------------------------
-- Approval engine
-- -----------------------------------------------------------------------------
create or replace function public.hris_submit_approval(p_modul text,p_record_id text)
returns uuid language plpgsql security definer set search_path=public as $$
declare
 v_email text:=auth.jwt()->>'email'; v_role text:=public.hris_my_role(); v_id uuid; v_steps jsonb; v_role_approver text;
begin
 if p_modul='leave' then perform public.hris_require_permission('leave.write');
 elsif p_modul='overtime' then perform public.hris_require_permission('overtime.write');
 elsif p_modul='payroll' then perform public.hris_require_permission('payroll.write');
 elsif p_modul='recruitment' then perform public.hris_require_permission('recruitment.write');
 else raise exception 'Modul approval tidak didukung'; end if;
 select steps into v_steps from public.hris_workflows where modul=p_modul and aktif=true order by created_at limit 1;
 if v_steps is null then v_steps:='[{"step":1,"role":"Super Admin"}]'::jsonb; end if;
 v_role_approver:=v_steps->0->>'role';
 insert into public.hris_approval_requests(modul,record_id,requester_email,current_step,status,approver_role)
 values(p_modul,p_record_id,v_email,1,'Menunggu',v_role_approver) returning id into v_id;
 perform public.hris_audit('SUBMIT',p_modul,p_record_id,jsonb_build_object('approval_id',v_id));
 return v_id;
end; $$;
grant execute on function public.hris_submit_approval(text,text) to authenticated;

create or replace function public.hris_decide_approval(p_id uuid,p_status text,p_catatan text default null)
returns void language plpgsql security definer set search_path=public as $$
declare
 r record; v_steps jsonb; v_next_role text; v_email text:=auth.jwt()->>'email'; v_role text:=public.hris_my_role(); v_days numeric;
begin
 if p_status not in ('Disetujui','Ditolak') then raise exception 'Status approval tidak valid'; end if;
 select * into r from public.hris_approval_requests where id=p_id for update;
 if not found then raise exception 'Approval tidak ditemukan'; end if;
 if r.status<>'Menunggu' then raise exception 'Approval sudah diproses'; end if;
 if v_role<>r.approver_role and v_role<>'Super Admin' then raise exception 'Role % tidak berwenang pada tahap ini',v_role; end if;
 if r.modul='leave' then perform public.hris_require_permission('leave.approve');
 elsif r.modul='overtime' then perform public.hris_require_permission('overtime.approve');
 elsif r.modul='payroll' then perform public.hris_require_permission('payroll.approve');
 elsif r.modul='recruitment' then perform public.hris_require_permission('recruitment.approve'); end if;
 select steps into v_steps from public.hris_workflows where modul=r.modul and aktif=true order by created_at limit 1;
 if p_status='Ditolak' then
   update public.hris_approval_requests set status=p_status,decided_by=v_email,decided_at=now(),catatan=p_catatan where id=p_id;
   if r.modul='leave' then update public.hris_cuti set status='Ditolak',disetujui_oleh=v_email where id=r.record_id::uuid;
   elsif r.modul='overtime' then update public.hris_lembur set status='Ditolak',disetujui_oleh=v_email where id=r.record_id::uuid;
   elsif r.modul='payroll' then update public.hris_payroll set status='Ditolak',approved_by=v_email,approved_at=now() where id=r.record_id::uuid; end if;
 else
   v_next_role:=v_steps->r.current_step->>'role';
   if v_next_role is not null then
     update public.hris_approval_requests set current_step=r.current_step+1,approver_role=v_next_role,catatan=p_catatan where id=p_id;
   else
     update public.hris_approval_requests set status=p_status,decided_by=v_email,decided_at=now(),catatan=p_catatan where id=p_id;
     if r.modul='leave' then
       select jumlah_hari into v_days from public.hris_cuti where id=r.record_id::uuid;
       insert into public.hris_saldo_cuti(id_karyawan,tahun,jenis,saldo,terpakai) select id_karyawan,extract(year from tanggal_mulai)::int,jenis,12,0 from public.hris_cuti where id=r.record_id::uuid on conflict(id_karyawan,tahun,jenis) do nothing;
       update public.hris_saldo_cuti s set terpakai=s.terpakai+coalesce(v_days,0),saldo=greatest(0,s.saldo-coalesce(v_days,0)) where id_karyawan=(select id_karyawan from public.hris_cuti where id=r.record_id::uuid) and tahun=extract(year from (select tanggal_mulai from public.hris_cuti where id=r.record_id::uuid))::int and jenis=(select jenis from public.hris_cuti where id=r.record_id::uuid);
       update public.hris_cuti set status='Disetujui',disetujui_oleh=v_email where id=r.record_id::uuid;
     elsif r.modul='overtime' then update public.hris_lembur set status='Disetujui',disetujui_oleh=v_email where id=r.record_id::uuid;
     elsif r.modul='payroll' then update public.hris_payroll set status='Disetujui',approved_by=v_email,approved_at=now() where id=r.record_id::uuid;
     end if;
   end if;
 end if;
 perform public.hris_audit(p_status,r.modul,r.record_id,jsonb_build_object('approval_id',p_id,'catatan',p_catatan,'actor',v_email));
end; $$;
grant execute on function public.hris_decide_approval(uuid,text,text) to authenticated;

-- Payroll finalization helpers
create or replace function public.hris_lock_payroll(p_payroll_id uuid,p_reference text default null)
returns void language plpgsql security definer set search_path=public as $$
begin
 perform public.hris_require_permission('payroll.lock');
 update public.hris_payroll set locked_at=now(),locked_by=auth.jwt()->>'email',payment_reference=coalesce(p_reference,payment_reference),status='Dibayar',tanggal_bayar=coalesce(tanggal_bayar,current_date) where id=p_payroll_id;
 perform public.hris_audit('LOCK_PAYROLL','payroll',p_payroll_id::text,jsonb_build_object('payment_reference',p_reference));
end; $$;
grant execute on function public.hris_lock_payroll(uuid,text) to authenticated;

-- Do not allow direct mutation of locked payroll through ordinary update policy.
create or replace function public.hris_payroll_update_guard() returns trigger language plpgsql as $$
begin
 if old.locked_at is not null and not public.hris_has_permission('payroll.lock') then raise exception 'Payroll sudah dikunci'; end if;
 return new;
end; $$;
drop trigger if exists trg_payroll_update_guard on public.hris_payroll;
create trigger trg_payroll_update_guard before update on public.hris_payroll for each row execute function public.hris_payroll_update_guard();

-- Recruitment stage history trigger
create or replace function public.hris_candidate_stage_history() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if tg_op='UPDATE' and coalesce(old.tahap,'')<>coalesce(new.tahap,'') then
   insert into public.hris_kandidat_history(kandidat_id,dari_tahap,ke_tahap,actor_email,catatan)
   values(new.id,old.tahap,new.tahap,auth.jwt()->>'email',new.catatan);
 end if;
 return new;
end; $$;
drop trigger if exists trg_candidate_stage_history on public.hris_kandidat;
create trigger trg_candidate_stage_history after update of tahap on public.hris_kandidat for each row execute function public.hris_candidate_stage_history();

-- Validation: leave requests may not overlap for the same employee.
create or replace function public.hris_validate_leave_overlap() returns trigger language plpgsql as $$
begin
 if exists(select 1 from public.hris_cuti x where x.id_karyawan=new.id_karyawan and x.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid) and x.status<>'Ditolak' and new.tanggal_mulai<=x.tanggal_selesai and new.tanggal_selesai>=x.tanggal_mulai) then
   raise exception 'Pengajuan cuti bertabrakan dengan pengajuan yang sudah ada';
 end if;
 return new;
end; $$;
drop trigger if exists trg_leave_overlap on public.hris_cuti;
create trigger trg_leave_overlap before insert or update on public.hris_cuti for each row execute function public.hris_validate_leave_overlap();

notify pgrst,'reload schema';

-- Granular RLS for talent and recruitment (replaces legacy admin-only checks).
drop policy if exists candidate_select on public.hris_kandidat;
drop policy if exists candidate_write on public.hris_kandidat;
create policy candidate_select on public.hris_kandidat for select to authenticated using (public.hris_has_permission('recruitment.read'));
create policy candidate_write on public.hris_kandidat for all to authenticated using (public.hris_has_permission('recruitment.write')) with check (public.hris_has_permission('recruitment.write'));

drop policy if exists vacancy_select on public.hris_lowongan;
drop policy if exists vacancy_write on public.hris_lowongan;
create policy vacancy_select on public.hris_lowongan for select to authenticated using (true);
create policy vacancy_write on public.hris_lowongan for all to authenticated using (public.hris_has_permission('recruitment.write')) with check (public.hris_has_permission('recruitment.write'));

drop policy if exists interview_select on public.hris_interview;
drop policy if exists interview_write on public.hris_interview;
create policy interview_select on public.hris_interview for select to authenticated using (public.hris_has_permission('recruitment.read'));
create policy interview_write on public.hris_interview for all to authenticated using (public.hris_has_permission('recruitment.write')) with check (public.hris_has_permission('recruitment.write'));

drop policy if exists kpi_select on public.hris_kpi;
drop policy if exists kpi_write on public.hris_kpi;
create policy kpi_select on public.hris_kpi for select to authenticated using (public.hris_has_permission('talent.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')));
create policy kpi_write on public.hris_kpi for all to authenticated using (public.hris_has_permission('talent.write')) with check (public.hris_has_permission('talent.write'));

drop policy if exists performance_select on public.hris_performance;
drop policy if exists performance_write on public.hris_performance;
create policy performance_select on public.hris_performance for select to authenticated using (public.hris_has_permission('talent.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')));
create policy performance_write on public.hris_performance for all to authenticated using (public.hris_has_permission('talent.write')) with check (public.hris_has_permission('talent.write'));

-- Payroll detail/status support permissions for existing custom roles.
insert into public.hris_role_permissions(role_name,permission_code)
select r.nama,p.kode
from public.hris_roles r cross join public.hris_permissions p
where r.nama='Super Admin' and p.kode='*'
on conflict do nothing;

notify pgrst,'reload schema';

-- Granular RLS for schedule/master data and settings.
drop policy if exists cabang_write on public.hris_cabang;
create policy cabang_write on public.hris_cabang for all to authenticated using (public.hris_has_permission('people.write')) with check (public.hris_has_permission('people.write'));
drop policy if exists dept_write on public.hris_departemen;
create policy dept_write on public.hris_departemen for all to authenticated using (public.hris_has_permission('people.write')) with check (public.hris_has_permission('people.write'));
drop policy if exists jabatan_write on public.hris_jabatan;
create policy jabatan_write on public.hris_jabatan for all to authenticated using (public.hris_has_permission('people.write')) with check (public.hris_has_permission('people.write'));
drop policy if exists shift_write on public.hris_shift;
create policy shift_write on public.hris_shift for all to authenticated using (public.hris_has_permission('schedule.write')) with check (public.hris_has_permission('schedule.write'));
drop policy if exists jadwal_select on public.hris_jadwal;
drop policy if exists jadwal_write on public.hris_jadwal;
create policy jadwal_select on public.hris_jadwal for select to authenticated using (public.hris_has_permission('schedule.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')));
create policy jadwal_write on public.hris_jadwal for all to authenticated using (public.hris_has_permission('schedule.write')) with check (public.hris_has_permission('schedule.write'));
drop policy if exists holiday_write on public.hris_hari_libur;
create policy holiday_write on public.hris_hari_libur for all to authenticated using (public.hris_has_permission('schedule.write')) with check (public.hris_has_permission('schedule.write'));
drop policy if exists settings_write on public.hris_company_settings;
create policy settings_write on public.hris_company_settings for all to authenticated using (public.hris_has_permission('settings.write')) with check (public.hris_has_permission('settings.write'));

notify pgrst,'reload schema';
drop policy if exists payroll_component_write on public.hris_payroll_komponen;
create policy payroll_component_write on public.hris_payroll_komponen for all to authenticated using (public.hris_has_permission('payroll.write')) with check (public.hris_has_permission('payroll.write'));
notify pgrst,'reload schema';

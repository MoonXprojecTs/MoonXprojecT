-- MoonXprojecT V21 — Security & Authorization Hardening
-- Run AFTER 023_v20_enterprise_control.sql.

create extension if not exists pgcrypto;

-- Security/administration permissions
insert into public.hris_permissions(kode,nama,modul) values
('security.read','Lihat Security Center','system'),
('security.manage','Kelola Security Center','system'),
('roles.manage','Kelola Role & Permission','roles'),
('audit.export','Export Audit Log','audit')
on conflict (kode) do nothing;

-- Normalize the permission helper: exact permission, module grant, or wildcard.
create or replace function public.hris_has_permission(p_code text)
returns boolean language sql stable security definer set search_path=public as $$
  select public.hris_is_super_admin() or exists (
    select 1 from public.hris_role_permissions
    where role_name=public.hris_my_role()
      and (permission_code='*'
        or permission_code=p_code
        or permission_code=split_part(p_code,'.',1))
  );
$$;
grant execute on function public.hris_has_permission(text) to authenticated;

-- Central approval authorization. Every decision must match both the current
-- workflow role and the module permission; clients cannot bypass this check.
create or replace function public.hris_v21_decide_approval(
  p_request_id uuid,
  p_decision text,
  p_note text default null
) returns void
language plpgsql security definer set search_path=public as $$
declare
  r record;
  v_role text := public.hris_my_role();
  v_email text := auth.jwt()->>'email';
  v_allowed boolean := false;
begin
  if auth.uid() is null then raise exception 'Unauthenticated'; end if;
  if p_decision not in ('Disetujui','Ditolak') then raise exception 'Decision tidak valid'; end if;

  select * into r from public.hris_approval_requests where id=p_request_id for update;
  if not found then raise exception 'Approval request tidak ditemukan'; end if;
  if coalesce(r.status,'') <> 'Menunggu' then raise exception 'Approval sudah diproses'; end if;

  -- Super Admin is the emergency administrator; all other users must be the
  -- assigned role and have the module-specific approval permission.
  if v_role='Super Admin' then
    v_allowed := true;
  elsif v_role = coalesce(r.approver_role,'') then
    v_allowed := case
      when r.modul in ('leave','ess_leave') then public.hris_has_permission('leave.approve') or public.hris_has_permission('ess.leave.approve')
      when r.modul in ('overtime','ess_overtime') then public.hris_has_permission('overtime.approve') or public.hris_has_permission('ess.overtime.approve')
      when r.modul in ('payroll') then public.hris_has_permission('payroll.approve')
      when r.modul in ('attendance','ess_attendance') then public.hris_has_permission('attendance.write') or public.hris_has_permission('ess.attendance.approve')
      when r.modul in ('people','ess_profile') then public.hris_has_permission('people.write') or public.hris_has_permission('ess.profile.approve')
      when r.modul in ('recruitment') then public.hris_has_permission('recruitment.approve')
      else public.hris_has_permission('approval.manage')
    end;
  end if;

  if not v_allowed then
    raise exception 'Akses approval ditolak untuk role % pada modul %',v_role,r.modul using errcode='42501';
  end if;

  update public.hris_approval_requests
    set status=p_decision,
        decided_by=v_email,
        decided_at=now(),
        catatan=coalesce(nullif(p_note,''),catatan),
        updated_at=now()
  where id=p_request_id;

  perform public.hris_audit(
    case when p_decision='Disetujui' then 'APPROVE' else 'REJECT' end,
    r.modul,
    r.record_id,
    jsonb_build_object('approval_id',r.id,'approver',v_email,'role',v_role,'step',r.current_step,'note',p_note)
  );
end;
$$;
grant execute on function public.hris_v21_decide_approval(uuid,text,text) to authenticated;

-- V20 RPC is retained for compatibility but now delegates to the hardened RPC.
create or replace function public.hris_v20_decide_approval(p_request_id uuid,p_decision text,p_note text default null)
returns void language plpgsql security definer set search_path=public as $$
begin
  perform public.hris_v21_decide_approval(p_request_id,p_decision,p_note);
end;
$$;
grant execute on function public.hris_v20_decide_approval(uuid,text,text) to authenticated;

-- Immutable audit posture: authenticated users can read only through RLS;
-- direct UPDATE/DELETE is not granted by this migration. Add a database-level
-- trigger to reject mutation of historical audit rows.
create or replace function public.hris_v21_audit_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'Audit log immutable: historical records cannot be changed or deleted';
end;
$$;
drop trigger if exists trg_v21_audit_immutable_update on public.hris_audit_logs;
drop trigger if exists trg_v21_audit_immutable_delete on public.hris_audit_logs;
create trigger trg_v21_audit_immutable_update before update on public.hris_audit_logs for each row execute function public.hris_v21_audit_immutable();
create trigger trg_v21_audit_immutable_delete before delete on public.hris_audit_logs for each row execute function public.hris_v21_audit_immutable();

-- Explicitly deny destructive audit operations through table grants for normal users.
revoke update, delete on public.hris_audit_logs from authenticated;

-- Security event table for authentication/administrative events visible to admins.
create table if not exists public.hris_security_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  actor_email text,
  actor_role text,
  ip_hint text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_v21_security_events_created on public.hris_security_events(created_at desc);
create index if not exists idx_v21_security_events_type on public.hris_security_events(event_type,created_at desc);
alter table public.hris_security_events enable row level security;
drop policy if exists security_events_read on public.hris_security_events;
create policy security_events_read on public.hris_security_events for select to authenticated using (
  public.hris_has_permission('security.read') or public.hris_has_permission('security.manage')
);
revoke insert, update, delete on public.hris_security_events from authenticated;

-- Safe server-side event writer; client never supplies actor identity.
create or replace function public.hris_v21_security_event(p_event_type text,p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Unauthenticated'; end if;
  if not (public.hris_has_permission('security.manage') or public.hris_is_super_admin()) then
    raise exception 'Akses security event ditolak' using errcode='42501';
  end if;
  insert into public.hris_security_events(event_type,actor_email,actor_role,metadata)
  values(p_event_type,auth.jwt()->>'email',public.hris_my_role(),coalesce(p_metadata,'{}'::jsonb))
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function public.hris_v21_security_event(text,jsonb) to authenticated;

-- Useful security inventory view for administrators.
create or replace view public.hris_v21_security_overview as
select
  (select count(*) from public.hris_users where status='Aktif') as active_users,
  (select count(*) from public.hris_role_permissions where permission_code='*') as wildcard_grants,
  (select count(*) from public.hris_approval_requests where status='Menunggu') as pending_approvals,
  (select count(*) from public.hris_audit_logs where created_at >= now() - interval '24 hours') as audit_24h,
  (select count(*) from public.hris_security_events where created_at >= now() - interval '24 hours') as security_events_24h;

-- Role/permission changes should be performed by Super Admin only.
drop policy if exists role_permissions_write_v21 on public.hris_role_permissions;
create policy role_permissions_write_v21 on public.hris_role_permissions for all to authenticated
using (public.hris_is_super_admin()) with check (public.hris_is_super_admin());

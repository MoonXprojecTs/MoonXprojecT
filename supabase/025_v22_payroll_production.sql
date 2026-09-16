-- MoonXprojecT V22 — Payroll Production Control
-- Preview, variance control, approval, lock and payment-batch preparation.
create extension if not exists pgcrypto;

create table if not exists public.hris_payroll_run_controls (
 id uuid primary key default gen_random_uuid(),
 period_id uuid not null unique references public.hris_payroll_periods(id) on delete cascade,
 status text not null default 'Draft' check(status in ('Draft','Preview','Pending Approval','Approved','Locked','Paid','Closed')),
 employee_count integer not null default 0,
 gross_total numeric(16,2) not null default 0,
 deduction_total numeric(16,2) not null default 0,
 net_total numeric(16,2) not null default 0,
 previous_net_total numeric(16,2) not null default 0,
 variance_amount numeric(16,2) generated always as (net_total-previous_net_total) stored,
 variance_percent numeric(10,4) generated always as (case when previous_net_total=0 then null else ((net_total-previous_net_total)/abs(previous_net_total))*100 end) stored,
 generated_at timestamptz,
 approved_at timestamptz,
 approved_by text,
 locked_at timestamptz,
 locked_by text,
 notes text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists idx_v22_payroll_control_status on public.hris_payroll_run_controls(status);

insert into public.hris_permissions(kode,nama,modul) values
('payroll.preview','Preview & variance payroll','payroll'),
('payroll.lock','Lock payroll final','payroll'),
('payroll.payslip','Kelola slip gaji','payroll')
on conflict(kode) do nothing;

alter table public.hris_payroll_run_controls enable row level security;
drop policy if exists v22_payroll_control_read on public.hris_payroll_run_controls;
create policy v22_payroll_control_read on public.hris_payroll_run_controls for select to authenticated using(public.hris_has_permission('payroll.read'));
drop policy if exists v22_payroll_control_write on public.hris_payroll_run_controls;
create policy v22_payroll_control_write on public.hris_payroll_run_controls for all to authenticated using(public.hris_has_permission('payroll.preview') or public.hris_has_permission('payroll.approve') or public.hris_has_permission('payroll.lock')) with check(public.hris_has_permission('payroll.preview') or public.hris_has_permission('payroll.approve') or public.hris_has_permission('payroll.lock'));

create or replace function public.hris_v22_refresh_payroll_control(p_period_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare p record; c record; prev numeric:=0; emp int:=0; gross numeric:=0; ded numeric:=0; net numeric:=0; cid uuid;
begin
 perform public.hris_require_permission('payroll.preview');
 select * into p from public.hris_payroll_periods where id=p_period_id;
 if not found then raise exception 'Periode payroll tidak ditemukan'; end if;
 select coalesce(sum(total_pendapatan),0),coalesce(sum(total_potongan),0),coalesce(sum(gaji_bersih),0),count(*) into gross,ded,net,emp from public.hris_payroll where periode=p.kode;
 select coalesce(sum(gaji_bersih),0) into prev from public.hris_payroll q join public.hris_payroll_periods pp on pp.kode=q.periode where pp.tanggal_selesai < p.tanggal_mulai and pp.status in ('Approved','Paid','Closed') and q.id_karyawan in (select id_karyawan from public.hris_payroll where periode=p.kode);
 insert into public.hris_payroll_run_controls(period_id,status,employee_count,gross_total,deduction_total,net_total,previous_net_total,generated_at)
 values(p.id,'Preview',emp,gross,ded,net,prev,now())
 on conflict(period_id) do update set employee_count=excluded.employee_count,gross_total=excluded.gross_total,deduction_total=excluded.deduction_total,net_total=excluded.net_total,previous_net_total=excluded.previous_net_total,generated_at=now(),updated_at=now(),status=case when hris_payroll_run_controls.status in ('Approved','Locked','Paid','Closed') then hris_payroll_run_controls.status else 'Preview' end
 returning id into cid;
 return jsonb_build_object('control_id',cid,'employees',emp,'gross',gross,'deduction',ded,'net',net,'previous_net',prev);
end $$;
grant execute on function public.hris_v22_refresh_payroll_control(uuid) to authenticated;

create or replace function public.hris_v22_approve_payroll(p_period_id uuid,p_note text default null)
returns void language plpgsql security definer set search_path=public as $$
declare c record; p record; v_email text:=auth.jwt()->>'email';
begin
 perform public.hris_require_permission('payroll.approve');
 select * into c from public.hris_payroll_run_controls where period_id=p_period_id for update;
 if not found then raise exception 'Preview payroll belum dibuat'; end if;
 if c.status not in ('Preview','Pending Approval') then raise exception 'Payroll tidak dapat diapprove dari status %',c.status; end if;
 if c.employee_count=0 then raise exception 'Tidak ada payroll untuk diapprove'; end if;
 update public.hris_payroll_run_controls set status='Approved',approved_at=now(),approved_by=v_email,notes=coalesce(nullif(p_note,''),notes),updated_at=now() where id=c.id;
 update public.hris_payroll_periods set status='Approved' where id=p_period_id;
 update public.hris_payroll set status='Disetujui',approved_by=v_email,approved_at=now() where periode=(select kode from public.hris_payroll_periods where id=p_period_id) and coalesce(status,'Draft') not in ('Paid','Closed');
 perform public.hris_audit('APPROVE','payroll',p_period_id,jsonb_build_object('net_total',c.net_total,'employees',c.employee_count));
end $$;
grant execute on function public.hris_v22_approve_payroll(uuid,text) to authenticated;

create or replace function public.hris_v22_lock_payroll(p_period_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare c record; v_email text:=auth.jwt()->>'email';
begin
 perform public.hris_require_permission('payroll.lock');
 select * into c from public.hris_payroll_run_controls where period_id=p_period_id for update;
 if not found or c.status <> 'Approved' then raise exception 'Payroll harus Approved sebelum dikunci'; end if;
 update public.hris_payroll_run_controls set status='Locked',locked_at=now(),locked_by=v_email,updated_at=now() where id=c.id;
 update public.hris_payroll_periods set status='Closed' where id=p_period_id;
 update public.hris_payroll set locked_at=now(),locked_by=v_email where periode=(select kode from public.hris_payroll_periods where id=p_period_id);
 perform public.hris_audit('LOCK','payroll',p_period_id,jsonb_build_object('net_total',c.net_total,'employees',c.employee_count));
end $$;
grant execute on function public.hris_v22_lock_payroll(uuid) to authenticated;

-- Prevent mutation of financial payroll rows after V22 lock.
create or replace function public.hris_v22_payroll_locked_guard()
returns trigger language plpgsql as $$
begin
 if old.locked_at is not null and (new.gaji_pokok,new.tunjangan,new.uang_makan,new.transport,new.lembur,new.bonus,new.potongan,new.bpjs,new.pph21,new.id_karyawan,new.periode) is distinct from (old.gaji_pokok,old.tunjangan,old.uang_makan,old.transport,old.lembur,old.bonus,old.potongan,old.bpjs,old.pph21,old.id_karyawan,old.periode) then
   raise exception 'Payroll sudah dikunci dan tidak dapat diubah';
 end if;
 return new;
end $$;
drop trigger if exists trg_v22_payroll_locked_guard on public.hris_payroll;
create trigger trg_v22_payroll_locked_guard before update on public.hris_payroll for each row execute function public.hris_v22_payroll_locked_guard();

create or replace view public.hris_v22_payroll_summary as
select p.id,p.kode,p.tanggal_mulai,p.tanggal_selesai,p.tanggal_gajian,p.status,
 coalesce(c.employee_count,0) employee_count,coalesce(c.gross_total,0) gross_total,coalesce(c.deduction_total,0) deduction_total,coalesce(c.net_total,0) net_total,coalesce(c.variance_amount,0) variance_amount,c.variance_percent
from public.hris_payroll_periods p left join public.hris_payroll_run_controls c on c.period_id=p.id;

-- MoonXprojecT V11 — Employee Self Service
-- Employee-facing access is restricted by auth_user_id -> karyawan.id.
create extension if not exists pgcrypto;
create table if not exists public.hris_employee_profile_requests (
 id uuid primary key default gen_random_uuid(), id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
 field_name text not null, old_value text, new_value text, reason text, status text not null default 'Menunggu' check(status in ('Menunggu','Disetujui','Ditolak')),
 created_at timestamptz not null default now(), decided_at timestamptz, decided_by text);
create table if not exists public.hris_employee_attendance_requests (
 id uuid primary key default gen_random_uuid(), id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
 tanggal date not null, jenis text not null check(jenis in ('Koreksi Masuk','Koreksi Pulang','Dinas','Remote','Lupa Absen')),
 jam_masuk time, jam_pulang time, alasan text not null, status text not null default 'Menunggu' check(status in ('Menunggu','Disetujui','Ditolak')),
 created_at timestamptz not null default now(), decided_at timestamptz, decided_by text);
create table if not exists public.hris_employee_leave_requests (
 id uuid primary key default gen_random_uuid(), id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
 jenis text not null, tanggal_mulai date not null, tanggal_selesai date not null, jumlah_hari numeric(6,2) not null default 1, alasan text, lampiran_url text,
 status text not null default 'Menunggu' check(status in ('Menunggu','Disetujui','Ditolak','Dibatalkan')), created_at timestamptz not null default now(),
 constraint ess_leave_dates check(tanggal_selesai>=tanggal_mulai));
create index if not exists idx_ess_profile_employee on public.hris_employee_profile_requests(id_karyawan,created_at desc);
create index if not exists idx_ess_att_employee on public.hris_employee_attendance_requests(id_karyawan,tanggal desc);
create index if not exists idx_ess_leave_employee on public.hris_employee_leave_requests(id_karyawan,tanggal_mulai desc);
insert into public.hris_permissions(kode,nama,modul) values
('ess.read','Employee Self Service','people'),('ess.profile.request','Pengajuan perubahan profil karyawan','people'),('ess.attendance.request','Koreksi absensi karyawan','attendance'),('ess.leave.request','Pengajuan cuti karyawan','leave') on conflict(kode) do nothing;
alter table public.hris_employee_profile_requests enable row level security;
alter table public.hris_employee_attendance_requests enable row level security;
alter table public.hris_employee_leave_requests enable row level security;
create or replace function public.hris_ess_employee_id() returns text language sql stable security definer set search_path=public as $$ select id_karyawan from public.karyawan where auth_user_id=auth.uid() limit 1 $$;
drop policy if exists ess_profile_self on public.hris_employee_profile_requests;
create policy ess_profile_self on public.hris_employee_profile_requests for all to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.profile.request')) with check(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.profile.request'));
drop policy if exists ess_att_self on public.hris_employee_attendance_requests;
create policy ess_att_self on public.hris_employee_attendance_requests for all to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.attendance.request')) with check(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.attendance.request'));
drop policy if exists ess_leave_self on public.hris_employee_leave_requests;
create policy ess_leave_self on public.hris_employee_leave_requests for all to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.leave.request')) with check(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('ess.leave.request'));
-- Read-only self-service access to master/transaction data. Existing admin policies remain intact.
drop policy if exists ess_employee_self on public.karyawan;
create policy ess_employee_self on public.karyawan for select to authenticated using(auth_user_id=auth.uid());
drop policy if exists ess_payroll_self on public.hris_payroll;
create policy ess_payroll_self on public.hris_payroll for select to authenticated using(id_karyawan=public.hris_ess_employee_id());
drop policy if exists ess_payroll_lines_self on public.hris_payroll_lines;
create policy ess_payroll_lines_self on public.hris_payroll_lines for select to authenticated using(id_karyawan=public.hris_ess_employee_id());
drop policy if exists ess_leave_self_existing on public.hris_cuti;
create policy ess_leave_self_existing on public.hris_cuti for select to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('leave.read'));
drop policy if exists ess_balance_self on public.hris_saldo_cuti;
create policy ess_balance_self on public.hris_saldo_cuti for select to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('leave.read'));
drop policy if exists ess_overtime_self on public.hris_lembur;
create policy ess_overtime_self on public.hris_lembur for select to authenticated using(id_karyawan=public.hris_ess_employee_id() or public.hris_has_permission('overtime.read'));
drop policy if exists ess_attendance_self_read on public.absensi;
create policy ess_attendance_self_read on public.absensi for select to authenticated using((id_karyawan=public.hris_ess_employee_id()) or (karyawan_id=public.hris_ess_employee_id()));

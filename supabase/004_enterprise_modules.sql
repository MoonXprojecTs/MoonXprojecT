-- MoonXprojecT Enterprise HRIS extension
-- Run AFTER 000-003. Safe/idempotent where possible.

create extension if not exists pgcrypto;

-- Employee master data for payroll, recruitment and compliance
alter table public.karyawan add column if not exists bank_name text;
alter table public.karyawan add column if not exists bank_account text;
alter table public.karyawan add column if not exists npwp text;
alter table public.karyawan add column if not exists bpjs_kesehatan text;
alter table public.karyawan add column if not exists bpjs_ketenagakerjaan text;
alter table public.karyawan add column if not exists tipe_gaji text default 'Bulanan';
alter table public.karyawan add column if not exists tanggal_keluar date;

-- Payroll line items and approvals
create table if not exists public.hris_payroll_detail (
 id uuid primary key default gen_random_uuid(), payroll_id uuid not null references public.hris_payroll(id) on delete cascade,
 komponen_id uuid references public.hris_payroll_komponen(id) on delete set null,
 nama text not null, tipe text not null default 'Tunjangan', nominal numeric(14,2) not null default 0,
 created_at timestamptz not null default now()
);
create index if not exists idx_payroll_detail_payroll on public.hris_payroll_detail(payroll_id);
alter table public.hris_payroll add column if not exists approved_by text;
alter table public.hris_payroll add column if not exists approved_at timestamptz;

-- Recruitment ATS: application, interview scorecards and offers
alter table public.hris_kandidat add column if not exists lowongan_id uuid references public.hris_lowongan(id) on delete set null;
alter table public.hris_kandidat add column if not exists tanggal_lamar date default current_date;
alter table public.hris_kandidat add column if not exists skor numeric(6,2) default 0;
alter table public.hris_kandidat add column if not exists pemilik_rekrutmen text;
alter table public.hris_kandidat add column if not exists linkedin_url text;
alter table public.hris_interview add column if not exists kandidat_id uuid references public.hris_kandidat(id) on delete set null;
alter table public.hris_interview add column if not exists jenis text default 'Interview';
alter table public.hris_interview add column if not exists skor numeric(6,2) default 0;
alter table public.hris_interview add column if not exists catatan text;
create table if not exists public.hris_job_offers (
 id uuid primary key default gen_random_uuid(), kandidat_id uuid not null references public.hris_kandidat(id) on delete cascade,
 gaji numeric(14,2) default 0, tanggal_offer date default current_date, tanggal_mulai date,
 status text not null default 'Draft', catatan text, created_at timestamptz not null default now()
);

-- Dynamic role metadata and workflow engine
alter table public.hris_roles add column if not exists is_system boolean default false;
alter table public.hris_roles add column if not exists status text default 'Aktif';
alter table public.hris_roles add column if not exists created_at timestamptz not null default now();
create table if not exists public.hris_workflows (
 id uuid primary key default gen_random_uuid(), nama text not null unique, modul text not null,
 aktif boolean not null default true, steps jsonb not null default '[]'::jsonb, created_at timestamptz not null default now()
);
create table if not exists public.hris_approval_requests (
 id uuid primary key default gen_random_uuid(), modul text not null, record_id text not null,
 requester_email text, current_step integer not null default 1, status text not null default 'Menunggu',
 approver_role text, decided_by text, decided_at timestamptz, catatan text, created_at timestamptz not null default now()
);
create index if not exists idx_approval_status on public.hris_approval_requests(status);
create index if not exists idx_approval_module_record on public.hris_approval_requests(modul,record_id);

-- Default permissions for granular UI/API authorization
insert into public.hris_permissions(kode,nama,modul) values
('people.read','Lihat Karyawan','people'),('people.write','Kelola Karyawan','people'),('people.delete','Hapus Karyawan','people'),
('attendance.read','Lihat Absensi','attendance'),('attendance.write','Kelola Absensi','attendance'),
('schedule.read','Lihat Jadwal','schedule'),('schedule.write','Kelola Jadwal','schedule'),
('leave.read','Lihat Cuti','leave'),('leave.write','Kelola Cuti','leave'),('leave.approve','Approve Cuti','leave'),
('overtime.read','Lihat Lembur','overtime'),('overtime.approve','Approve Lembur','overtime'),
('payroll.read','Lihat Payroll','payroll'),('payroll.write','Proses Payroll','payroll'),('payroll.approve','Approve Payroll','payroll'),('payroll.pay','Konfirmasi Pembayaran','payroll'),
('talent.read','Lihat Talent','talent'),('talent.write','Kelola Talent','talent'),
('recruitment.read','Lihat Recruitment','recruitment'),('recruitment.write','Kelola Recruitment','recruitment'),('recruitment.approve','Approve Hiring','recruitment'),
('reports.read','Lihat Laporan','reports'),('reports.export','Export Laporan','reports'),('settings.write','Kelola Pengaturan','settings'),('roles.write','Kelola Role','roles'),('audit.read','Lihat Audit','audit')
on conflict(kode) do nothing;

-- Approval helpers: one auditable transaction for decisions
create or replace function public.hris_decide_approval(p_id uuid,p_status text,p_catatan text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_modul text; v_record text;
begin
 if p_status not in ('Disetujui','Ditolak') then raise exception 'Status approval tidak valid'; end if;
 select modul,record_id into v_modul,v_record from public.hris_approval_requests where id=p_id for update;
 if not found then raise exception 'Approval tidak ditemukan'; end if;
 update public.hris_approval_requests set status=p_status,decided_by=coalesce(auth.jwt()->>'email','system'),decided_at=now(),catatan=p_catatan where id=p_id;
 perform public.hris_audit(p_status,v_modul,v_record,jsonb_build_object('approval_id',p_id,'catatan',p_catatan));
end; $$;

-- Useful indexes
create index if not exists idx_kandidat_tahap on public.hris_kandidat(tahap);
create index if not exists idx_lowongan_status on public.hris_lowongan(status);
create index if not exists idx_payroll_periode_status on public.hris_payroll(periode,status);

-- Keep updated_at for company settings
create or replace function public.hris_touch_company_settings() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists trg_company_settings_updated on public.hris_company_settings;
create trigger trg_company_settings_updated before update on public.hris_company_settings for each row execute function public.hris_touch_company_settings();

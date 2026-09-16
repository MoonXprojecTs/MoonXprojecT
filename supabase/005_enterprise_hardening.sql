-- MoonXprojecT Enterprise Hardening v2
create extension if not exists pgcrypto;

-- Payroll controls
alter table public.hris_payroll add column if not exists approved_by text;
alter table public.hris_payroll add column if not exists approved_at timestamptz;
alter table public.hris_payroll add column if not exists payment_reference text;
alter table public.hris_payroll add column if not exists locked_at timestamptz;
alter table public.hris_payroll add column if not exists locked_by text;

-- Recruitment lifecycle
create table if not exists public.hris_kandidat_history (
 id uuid primary key default gen_random_uuid(), kandidat_id uuid not null references public.hris_kandidat(id) on delete cascade,
 dari_tahap text, ke_tahap text not null, actor_email text, catatan text, created_at timestamptz not null default now()
);
create table if not exists public.hris_interview_scorecard (
 id uuid primary key default gen_random_uuid(), interview_id uuid not null references public.hris_interview(id) on delete cascade,
 kompetensi text not null, skor numeric(6,2) not null default 0, catatan text, created_at timestamptz not null default now()
);
create table if not exists public.hris_onboarding (
 id uuid primary key default gen_random_uuid(), kandidat_id uuid references public.hris_kandidat(id) on delete set null,
 id_karyawan text, status text not null default 'Belum Mulai', tanggal_mulai date, progress integer not null default 0,
 checklist jsonb not null default '[]'::jsonb, created_at timestamptz not null default now()
);

-- Multi-level workflow templates
insert into public.hris_workflows(nama,modul,steps) values
('Approval Cuti Standar','leave','[{"step":1,"role":"Supervisor"},{"step":2,"role":"HRD"}]'::jsonb),
('Approval Lembur Standar','overtime','[{"step":1,"role":"Supervisor"},{"step":2,"role":"HRD"}]'::jsonb),
('Approval Payroll Standar','payroll','[{"step":1,"role":"Payroll"},{"step":2,"role":"Super Admin"}]'::jsonb),
('Hiring Approval Standar','recruitment','[{"step":1,"role":"HRD"},{"step":2,"role":"Super Admin"}]'::jsonb)
on conflict(nama) do nothing;

-- Audit all important lifecycle changes through database triggers.
create or replace function public.hris_audit_row() returns trigger language plpgsql security definer set search_path=public as $$
begin
 perform public.hris_audit(TG_OP, TG_TABLE_NAME, coalesce((to_jsonb(new)->>'id'),(to_jsonb(old)->>'id')), jsonb_build_object('old',to_jsonb(old),'new',to_jsonb(new)));
 return coalesce(new,old);
end; $$;

drop trigger if exists trg_audit_karyawan on public.karyawan;
create trigger trg_audit_karyawan after insert or update or delete on public.karyawan for each row execute function public.hris_audit_row();
drop trigger if exists trg_audit_payroll on public.hris_payroll;
create trigger trg_audit_payroll after insert or update or delete on public.hris_payroll for each row execute function public.hris_audit_row();
drop trigger if exists trg_audit_kandidat on public.hris_kandidat;
create trigger trg_audit_kandidat after insert or update or delete on public.hris_kandidat for each row execute function public.hris_audit_row();
drop trigger if exists trg_audit_cuti on public.hris_cuti;
create trigger trg_audit_cuti after insert or update or delete on public.hris_cuti for each row execute function public.hris_audit_row();
drop trigger if exists trg_audit_lembur on public.hris_lembur;
create trigger trg_audit_lembur after insert or update or delete on public.hris_lembur for each row execute function public.hris_audit_row();

-- Permission helpers for backend enforcement.
create or replace function public.hris_require_permission(p_code text) returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.hris_has_permission(p_code) then raise exception 'Akses ditolak: %', p_code using errcode='42501'; end if;
end; $$;

-- Useful indexes
create index if not exists idx_candidate_history_candidate on public.hris_kandidat_history(kandidat_id,created_at desc);
create index if not exists idx_scorecard_interview on public.hris_interview_scorecard(interview_id);
create index if not exists idx_onboarding_status on public.hris_onboarding(status);
create index if not exists idx_payroll_employee_period on public.hris_payroll(id_karyawan,periode);

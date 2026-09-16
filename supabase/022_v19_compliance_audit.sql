-- V19: compliance control and audit extensions
create table if not exists public.hris_compliance_controls(id uuid primary key default gen_random_uuid(), control_code text unique not null, title text not null, owner_role text, frequency text default 'Monthly', evidence_required boolean default true, active boolean default true);
create table if not exists public.hris_compliance_runs(id uuid primary key default gen_random_uuid(), control_id uuid references public.hris_compliance_controls(id) on delete cascade, run_date date default current_date, status text default 'Open', result text, evidence_path text, reviewer text, reviewed_at timestamptz, created_at timestamptz default now());
create index if not exists idx_v19_compliance_runs on public.hris_compliance_runs(run_date,status);

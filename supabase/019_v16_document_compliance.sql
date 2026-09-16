-- V16: document lifecycle and expiry compliance
alter table public.hris_employee_documents add column if not exists status text default 'Aktif';
alter table public.hris_employee_documents add column if not exists tanggal_kadaluarsa date;
alter table public.hris_employee_documents add column if not exists storage_path text;
create table if not exists public.hris_document_types(id uuid primary key default gen_random_uuid(), code text unique not null, name text not null, required_for text, expiry_required boolean default false, active boolean default true);
create table if not exists public.hris_compliance_tasks(id uuid primary key default gen_random_uuid(), task_code text not null, title text not null, owner text, due_date date, status text not null default 'Open', priority text default 'Medium', notes text, created_at timestamptz default now(), updated_at timestamptz default now());
create index if not exists idx_v16_compliance_due on public.hris_compliance_tasks(status,due_date);

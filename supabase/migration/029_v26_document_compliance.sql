-- MoonXprojecT Enterprise 029
create extension if not exists pgcrypto;
create table if not exists public.hris_employee_documents_v26 (id uuid primary key default gen_random_uuid(), id_karyawan text not null, document_type text not null, document_no text, issue_date date, expiry_date date, status text not null default 'Active', storage_path text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create index if not exists idx_hris_employee_documents_v26_status on public.hris_employee_documents_v26(status);
insert into public.hris_permissions(kode,nama,modul) values ('document.compliance','Document Compliance','document') on conflict(kode) do nothing;
alter table public.hris_employee_documents_v26 enable row level security;
drop policy if exists enterprise_select on public.hris_employee_documents_v26;
create policy enterprise_select on public.hris_employee_documents_v26 for select to authenticated using (public.hris_has_permission('document.read') or public.hris_has_permission('document.compliance'));
drop policy if exists enterprise_insert on public.hris_employee_documents_v26;
create policy enterprise_insert on public.hris_employee_documents_v26 for insert to authenticated with check (public.hris_has_permission('document.compliance'));
drop policy if exists enterprise_update on public.hris_employee_documents_v26;
create policy enterprise_update on public.hris_employee_documents_v26 for update to authenticated using (public.hris_has_permission('document.compliance')) with check (public.hris_has_permission('document.compliance'));
drop policy if exists enterprise_delete on public.hris_employee_documents_v26;
create policy enterprise_delete on public.hris_employee_documents_v26 for delete to authenticated using (public.hris_has_permission('document.compliance'));
notify pgrst,'reload schema';

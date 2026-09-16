-- MoonXprojecT V10 compatibility foundation. Safe to run if V10 delivery tables already exist.
create extension if not exists pgcrypto;
create table if not exists public.hris_payment_batches (
 id uuid primary key default gen_random_uuid(), batch_no text unique not null, payroll_period_id uuid references public.hris_payroll_periods(id) on delete set null,
 status text not null default 'Draft' check(status in ('Draft','Review','Approved','Submitted','Paid','Cancelled')),
 total_employees integer not null default 0, total_amount numeric(16,2) not null default 0, payment_date date, bank_name text, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists public.hris_payment_batch_lines (
 id uuid primary key default gen_random_uuid(), batch_id uuid not null references public.hris_payment_batches(id) on delete cascade, payroll_id uuid references public.hris_payroll(id) on delete set null,
 id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade, account_name text, account_number text, bank_name text, amount numeric(16,2) not null default 0, status text not null default 'Pending', created_at timestamptz not null default now(), unique(batch_id,id_karyawan));
create table if not exists public.hris_payroll_reconciliation (
 id uuid primary key default gen_random_uuid(), batch_id uuid not null references public.hris_payment_batches(id) on delete cascade, id_karyawan text references public.karyawan(id_karyawan) on delete set null,
 expected_amount numeric(16,2) not null default 0, paid_amount numeric(16,2) not null default 0, variance numeric(16,2) generated always as (paid_amount-expected_amount) stored,
 status text not null default 'Open' check(status in ('Open','Matched','Variance','Resolved')), note text, created_at timestamptz not null default now(), unique(batch_id,id_karyawan));
create table if not exists public.hris_accounting_exports (
 id uuid primary key default gen_random_uuid(), payroll_period_id uuid references public.hris_payroll_periods(id) on delete set null, export_no text unique not null,
 status text not null default 'Draft', total_amount numeric(16,2) not null default 0, created_at timestamptz not null default now());
insert into public.hris_permissions(kode,nama,modul) values
('payroll.payment.batch','Kelola payment batch','payroll'),('payroll.reconciliation','Rekonsiliasi pembayaran','payroll'),('payroll.accounting.export','Ekspor accounting','payroll') on conflict(kode) do nothing;
alter table public.hris_payment_batches enable row level security; alter table public.hris_payment_batch_lines enable row level security; alter table public.hris_payroll_reconciliation enable row level security; alter table public.hris_accounting_exports enable row level security;
drop policy if exists payment_batches_read on public.hris_payment_batches; create policy payment_batches_read on public.hris_payment_batches for select to authenticated using(public.hris_has_permission('payroll.read'));
drop policy if exists payment_batches_write on public.hris_payment_batches; create policy payment_batches_write on public.hris_payment_batches for all to authenticated using(public.hris_has_permission('payroll.payment.batch')) with check(public.hris_has_permission('payroll.payment.batch'));
drop policy if exists payment_lines_read on public.hris_payment_batch_lines; create policy payment_lines_read on public.hris_payment_batch_lines for select to authenticated using(public.hris_has_permission('payroll.read'));
drop policy if exists payment_lines_write on public.hris_payment_batch_lines; create policy payment_lines_write on public.hris_payment_batch_lines for all to authenticated using(public.hris_has_permission('payroll.payment.batch')) with check(public.hris_has_permission('payroll.payment.batch'));
drop policy if exists recon_read on public.hris_payroll_reconciliation; create policy recon_read on public.hris_payroll_reconciliation for select to authenticated using(public.hris_has_permission('payroll.read'));
drop policy if exists recon_write on public.hris_payroll_reconciliation; create policy recon_write on public.hris_payroll_reconciliation for all to authenticated using(public.hris_has_permission('payroll.reconciliation')) with check(public.hris_has_permission('payroll.reconciliation'));
drop policy if exists accounting_read on public.hris_accounting_exports; create policy accounting_read on public.hris_accounting_exports for select to authenticated using(public.hris_has_permission('payroll.read'));
drop policy if exists accounting_write on public.hris_accounting_exports; create policy accounting_write on public.hris_accounting_exports for all to authenticated using(public.hris_has_permission('payroll.accounting.export')) with check(public.hris_has_permission('payroll.accounting.export'));

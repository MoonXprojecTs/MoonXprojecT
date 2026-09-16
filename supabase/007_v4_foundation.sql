-- MoonXprojecT V4: employee 360, documents, notifications, lifecycle and operational controls.
-- Run AFTER 006_enterprise_v3.sql.

create extension if not exists pgcrypto;

-- Employee lifecycle / organization history
create table if not exists public.hris_employee_history (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null,
  jenis text not null,
  dari_nilai text,
  ke_nilai text,
  efektif_mulai date default current_date,
  alasan text,
  actor_email text,
  created_at timestamptz not null default now()
);
create index if not exists idx_employee_history_employee on public.hris_employee_history(id_karyawan, created_at desc);

create table if not exists public.hris_employee_documents (
  id uuid primary key default gen_random_uuid(),
  id_karyawan text not null,
  jenis text not null,
  nama_file text not null,
  storage_path text,
  nomor_dokumen text,
  tanggal_terbit date,
  tanggal_expired date,
  status text not null default 'Aktif',
  catatan text,
  uploaded_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_employee_documents_employee on public.hris_employee_documents(id_karyawan);
create index if not exists idx_employee_documents_expiry on public.hris_employee_documents(tanggal_expired);

-- Notification center
create table if not exists public.hris_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_email text not null,
  type text not null default 'system',
  title text not null,
  message text not null,
  link text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_notifications_recipient on public.hris_notifications(recipient_email, is_read, created_at desc);

-- Approval history independent from current request state.
create table if not exists public.hris_approval_history (
  id uuid primary key default gen_random_uuid(),
  approval_id uuid,
  modul text,
  record_id text,
  step_no integer,
  approver_role text,
  actor_email text,
  status text not null,
  catatan text,
  created_at timestamptz not null default now()
);
create index if not exists idx_approval_history_request on public.hris_approval_history(approval_id, created_at desc);

-- Helpful employee fields. Safe because these are additive.
alter table public.karyawan add column if not exists nomor_induk text;
alter table public.karyawan add column if not exists tanggal_keluar date;
alter table public.karyawan add column if not exists alasan_keluar text;
alter table public.karyawan add column if not exists atasan_id text;
alter table public.karyawan add column if not exists level_jabatan text;
alter table public.karyawan add column if not exists lokasi_kerja text;
alter table public.karyawan add column if not exists tipe_karyawan text default 'Tetap';

-- Updated-at helper.
create or replace function public.hris_touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at=now(); return new; end; $$;
drop trigger if exists trg_employee_documents_updated on public.hris_employee_documents;
create trigger trg_employee_documents_updated before update on public.hris_employee_documents for each row execute function public.hris_touch_updated_at();

-- Capture material employee changes.
create or replace function public.hris_employee_change_history() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='UPDATE' then
    if coalesce(old.jabatan,'')<>coalesce(new.jabatan,'') then
      insert into public.hris_employee_history(id_karyawan,jenis,dari_nilai,ke_nilai,actor_email) values(new.id_karyawan,'Jabatan',old.jabatan,new.jabatan,auth.jwt()->>'email');
    end if;
    if coalesce(old.departemen,'')<>coalesce(new.departemen,'') then
      insert into public.hris_employee_history(id_karyawan,jenis,dari_nilai,ke_nilai,actor_email) values(new.id_karyawan,'Departemen',old.departemen,new.departemen,auth.jwt()->>'email');
    end if;
    if coalesce(old.status_aktif,true)<>coalesce(new.status_aktif,true) then
      insert into public.hris_employee_history(id_karyawan,jenis,dari_nilai,ke_nilai,actor_email) values(new.id_karyawan,'Status',old.status_aktif::text,new.status_aktif::text,auth.jwt()->>'email');
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists trg_employee_change_history on public.karyawan;
create trigger trg_employee_change_history after update on public.karyawan for each row execute function public.hris_employee_change_history();

-- RLS
alter table public.hris_employee_history enable row level security;
alter table public.hris_employee_documents enable row level security;
alter table public.hris_notifications enable row level security;
alter table public.hris_approval_history enable row level security;

drop policy if exists employee_history_select on public.hris_employee_history;
create policy employee_history_select on public.hris_employee_history for select to authenticated using (public.hris_has_permission('people.read'));
drop policy if exists employee_history_write on public.hris_employee_history;
create policy employee_history_write on public.hris_employee_history for insert to authenticated with check (public.hris_has_permission('people.write'));

drop policy if exists employee_documents_select on public.hris_employee_documents;
drop policy if exists employee_documents_write on public.hris_employee_documents;
create policy employee_documents_select on public.hris_employee_documents for select to authenticated using (public.hris_has_permission('people.read') or id_karyawan in (select id_karyawan from public.karyawan where auth_user_id=auth.uid() or lower(email)=lower(auth.jwt()->>'email')));
create policy employee_documents_write on public.hris_employee_documents for all to authenticated using (public.hris_has_permission('people.write')) with check (public.hris_has_permission('people.write'));

drop policy if exists notifications_select on public.hris_notifications;
drop policy if exists notifications_update on public.hris_notifications;
create policy notifications_select on public.hris_notifications for select to authenticated using (lower(recipient_email)=lower(auth.jwt()->>'email') or public.hris_has_permission('settings.write'));
create policy notifications_update on public.hris_notifications for update to authenticated using (lower(recipient_email)=lower(auth.jwt()->>'email') or public.hris_has_permission('settings.write')) with check (lower(recipient_email)=lower(auth.jwt()->>'email') or public.hris_has_permission('settings.write'));

drop policy if exists approval_history_select on public.hris_approval_history;
create policy approval_history_select on public.hris_approval_history for select to authenticated using (public.hris_has_permission('approval.read') or public.hris_has_permission('audit.read'));

-- Permission catalog
insert into public.hris_permissions(kode,nama,modul) values
('people.history','Lihat riwayat karyawan','people'),
('people.documents','Kelola dokumen karyawan','people'),
('notifications.read','Lihat notifikasi','notifications'),
('notifications.write','Kelola notifikasi','notifications')
on conflict (kode) do nothing;

notify pgrst,'reload schema';

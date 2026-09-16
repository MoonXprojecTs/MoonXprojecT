-- MoonXprojecT Enterprise V25 - ATS Enterprise
create extension if not exists pgcrypto;

create table if not exists public.hris_recruitment_requisitions_v25 (
 id uuid primary key default gen_random_uuid(),
 request_no text not null unique,
 posisi text not null,
 departemen text,
 lokasi text,
 jumlah_kebutuhan integer not null default 1 check (jumlah_kebutuhan > 0),
 alasan text,
 hiring_manager text,
 target_tanggal date,
 status text not null default 'Draft' check (status in ('Draft','Menunggu Approval','Disetujui','Ditolak','Ditutup')),
 approved_by text,
 approved_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.hris_recruitment_openings_v25 (
 id uuid primary key default gen_random_uuid(),
 requisition_id uuid references public.hris_recruitment_requisitions_v25(id) on delete set null,
 opening_no text not null unique,
 posisi text not null,
 departemen text,
 lokasi text,
 employment_type text not null default 'Tetap',
 level_jabatan text,
 headcount integer not null default 1 check (headcount > 0),
 salary_min numeric(14,2) default 0,
 salary_max numeric(14,2) default 0,
 publish_at timestamptz,
 close_at timestamptz,
 status text not null default 'Draft' check (status in ('Draft','Open','Paused','Closed')),
 description text,
 requirements text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check (salary_max = 0 or salary_max >= salary_min)
);

create table if not exists public.hris_candidate_profiles_v25 (
 id uuid primary key default gen_random_uuid(),
 candidate_id uuid references public.hris_kandidat(id) on delete set null,
 full_name text not null,
 email text,
 phone text,
 city text,
 source text,
 linkedin_url text,
 portfolio_url text,
 resume_path text,
 consent_at timestamptz,
 notes text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.hris_recruitment_applications_v25 (
 id uuid primary key default gen_random_uuid(),
 candidate_profile_id uuid not null references public.hris_candidate_profiles_v25(id) on delete cascade,
 opening_id uuid not null references public.hris_recruitment_openings_v25(id) on delete cascade,
 stage text not null default 'Screening' check (stage in ('Screening','Interview','Assessment','Offering','Hired','Rejected','Withdrawn')),
 status text not null default 'Active' check (status in ('Active','Rejected','Hired','Withdrawn','On Hold')),
 score numeric(6,2) default 0,
 owner_email text,
 applied_at timestamptz not null default now(),
 hired_at timestamptz,
 rejection_reason text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(candidate_profile_id,opening_id)
);

create table if not exists public.hris_recruitment_stage_history_v25 (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.hris_recruitment_applications_v25(id) on delete cascade,
 from_stage text,
 to_stage text not null,
 actor_email text,
 note text,
 created_at timestamptz not null default now()
);

create table if not exists public.hris_recruitment_interviews_v25 (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.hris_recruitment_applications_v25(id) on delete cascade,
 interview_type text not null default 'Interview HR',
 scheduled_at timestamptz not null,
 duration_minutes integer not null default 60,
 location_or_link text,
 interviewer_email text,
 status text not null default 'Scheduled' check (status in ('Scheduled','Completed','Cancelled','No Show')),
 overall_score numeric(6,2) default 0,
 notes text,
 created_at timestamptz not null default now()
);

create table if not exists public.hris_recruitment_scorecards_v25 (
 id uuid primary key default gen_random_uuid(),
 interview_id uuid not null references public.hris_recruitment_interviews_v25(id) on delete cascade,
 competency text not null,
 weight numeric(6,2) not null default 1,
 score numeric(6,2) not null default 0 check (score between 0 and 100),
 comments text,
 created_at timestamptz not null default now()
);

create table if not exists public.hris_recruitment_offers_v25 (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.hris_recruitment_applications_v25(id) on delete cascade,
 offer_no text not null unique,
 proposed_salary numeric(14,2) not null default 0,
 start_date date,
 employment_type text,
 status text not null default 'Draft' check (status in ('Draft','Menunggu Approval','Disetujui','Dikirim','Diterima','Ditolak','Kadaluarsa')),
 approved_by text,
 approved_at timestamptz,
 sent_at timestamptz,
 responded_at timestamptz,
 notes text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.hris_recruitment_communications_v25 (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.hris_recruitment_applications_v25(id) on delete cascade,
 channel text not null default 'Email',
 direction text not null default 'Outbound',
 subject text,
 message text not null,
 sent_at timestamptz not null default now(),
 actor_email text
);

create table if not exists public.hris_recruitment_onboarding_handoffs_v25 (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null unique references public.hris_recruitment_applications_v25(id) on delete cascade,
 target_employee_id text,
 target_start_date date,
 status text not null default 'Ready' check (status in ('Ready','In Progress','Completed','Cancelled')),
 handoff_notes text,
 created_at timestamptz not null default now(),
 completed_at timestamptz
);

create index if not exists idx_v25_requisition_status on public.hris_recruitment_requisitions_v25(status);
create index if not exists idx_v25_opening_status on public.hris_recruitment_openings_v25(status);
create index if not exists idx_v25_app_stage on public.hris_recruitment_applications_v25(stage,status);
create index if not exists idx_v25_stage_history_app on public.hris_recruitment_stage_history_v25(application_id,created_at desc);
create index if not exists idx_v25_interviews_schedule on public.hris_recruitment_interviews_v25(scheduled_at);
create index if not exists idx_v25_offers_status on public.hris_recruitment_offers_v25(status);
create unique index if not exists uq_v25_candidate_email on public.hris_candidate_profiles_v25(lower(email)) where email is not null and btrim(email) <> '';

insert into public.hris_permissions(kode,nama,modul) values
('recruitment.requisition','Recruitment Requisition','recruitment'),
('recruitment.opening','Job Opening','recruitment'),
('recruitment.candidate','Candidate Profile','recruitment'),
('recruitment.pipeline','Pipeline & Stage','recruitment'),
('recruitment.interview','Interview & Scorecard','recruitment'),
('recruitment.offer','Offer Management','recruitment'),
('recruitment.hiring','Hiring Approval','recruitment'),
('recruitment.onboarding','Onboarding Handoff','recruitment')
on conflict (kode) do nothing;

alter table public.hris_recruitment_requisitions_v25 enable row level security;
alter table public.hris_recruitment_openings_v25 enable row level security;
alter table public.hris_candidate_profiles_v25 enable row level security;
alter table public.hris_recruitment_applications_v25 enable row level security;
alter table public.hris_recruitment_stage_history_v25 enable row level security;
alter table public.hris_recruitment_interviews_v25 enable row level security;
alter table public.hris_recruitment_scorecards_v25 enable row level security;
alter table public.hris_recruitment_offers_v25 enable row level security;
alter table public.hris_recruitment_communications_v25 enable row level security;
alter table public.hris_recruitment_onboarding_handoffs_v25 enable row level security;

do $$ declare t text; begin foreach t in array array['hris_recruitment_requisitions_v25','hris_recruitment_openings_v25','hris_candidate_profiles_v25','hris_recruitment_applications_v25','hris_recruitment_stage_history_v25','hris_recruitment_interviews_v25','hris_recruitment_scorecards_v25','hris_recruitment_offers_v25','hris_recruitment_communications_v25','hris_recruitment_onboarding_handoffs_v25'] loop execute format('drop policy if exists v25_select on public.%I',t); execute format('create policy v25_select on public.%I for select to authenticated using (public.hris_has_permission(''recruitment.read''))',t); execute format('drop policy if exists v25_write on public.%I',t); execute format('create policy v25_write on public.%I for insert to authenticated with check (public.hris_has_permission(''recruitment.write''))',t); execute format('drop policy if exists v25_update on public.%I',t); execute format('create policy v25_update on public.%I for update to authenticated using (public.hris_has_permission(''recruitment.write'')) with check (public.hris_has_permission(''recruitment.write''))',t); execute format('drop policy if exists v25_delete on public.%I',t); execute format('create policy v25_delete on public.%I for delete to authenticated using (public.hris_has_permission(''recruitment.write''))',t); end loop; end $$;

create or replace function public.hris_v25_move_application(p_application_id uuid,p_to_stage text,p_note text default null) returns void language plpgsql security definer set search_path=public as $$
declare v_from text; v_status text; v_actor text;
begin
 perform public.hris_require_permission('recruitment.pipeline');
 if p_to_stage not in ('Screening','Interview','Assessment','Offering','Hired','Rejected','Withdrawn') then raise exception 'Tahap recruitment tidak valid'; end if;
 select stage,status into v_from,v_status from public.hris_recruitment_applications_v25 where id=p_application_id for update;
 if not found then raise exception 'Application tidak ditemukan'; end if;
 v_actor := coalesce(auth.email(),'system');
 update public.hris_recruitment_applications_v25 set stage=p_to_stage,status=case when p_to_stage='Hired' then 'Hired' when p_to_stage in ('Rejected','Withdrawn') then p_to_stage else 'Active' end,hired_at=case when p_to_stage='Hired' then now() else hired_at end,updated_at=now() where id=p_application_id;
 insert into public.hris_recruitment_stage_history_v25(application_id,from_stage,to_stage,actor_email,note) values(p_application_id,v_from,p_to_stage,v_actor,p_note);
 perform public.hris_audit('RECRUITMENT_STAGE_CHANGE','hris_recruitment_applications_v25',p_application_id::text,jsonb_build_object('from',v_from,'to',p_to_stage,'note',p_note));
end; $$;

create or replace function public.hris_v25_approve_requisition(p_id uuid,p_approve boolean,p_note text default null) returns void language plpgsql security definer set search_path=public as $$
declare v_status text;
begin
 perform public.hris_require_permission('recruitment.approve');
 select status into v_status from public.hris_recruitment_requisitions_v25 where id=p_id for update;
 if v_status is null then raise exception 'Requisition tidak ditemukan'; end if;
 if v_status <> 'Menunggu Approval' then raise exception 'Requisition bukan dalam status Menunggu Approval'; end if;
 update public.hris_recruitment_requisitions_v25 set status=case when p_approve then 'Disetujui' else 'Ditolak' end,approved_by=auth.email(),approved_at=now(),updated_at=now() where id=p_id;
 perform public.hris_audit('RECRUITMENT_REQUISITION_DECISION','hris_recruitment_requisitions_v25',p_id::text,jsonb_build_object('approved',p_approve,'note',p_note));
end; $$;

create or replace function public.hris_v25_approve_offer(p_id uuid,p_approve boolean,p_note text default null) returns void language plpgsql security definer set search_path=public as $$
declare v_status text;
begin
 perform public.hris_require_permission('recruitment.approve');
 select status into v_status from public.hris_recruitment_offers_v25 where id=p_id for update;
 if v_status <> 'Menunggu Approval' then raise exception 'Offer bukan dalam status Menunggu Approval'; end if;
 update public.hris_recruitment_offers_v25 set status=case when p_approve then 'Disetujui' else 'Ditolak' end,approved_by=auth.email(),approved_at=now(),updated_at=now() where id=p_id;
 perform public.hris_audit('RECRUITMENT_OFFER_DECISION','hris_recruitment_offers_v25',p_id::text,jsonb_build_object('approved',p_approve,'note',p_note));
end; $$;

create or replace function public.hris_v25_hiring_handoff(p_application_id uuid,p_start_date date,p_notes text default null) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
 perform public.hris_require_permission('recruitment.onboarding');
 if not exists(select 1 from public.hris_recruitment_applications_v25 where id=p_application_id and stage='Hired') then raise exception 'Candidate harus berstatus Hired'; end if;
 insert into public.hris_recruitment_onboarding_handoffs_v25(application_id,target_start_date,status,handoff_notes) values(p_application_id,p_start_date,'Ready',p_notes) on conflict(application_id) do update set target_start_date=excluded.target_start_date,status='Ready',handoff_notes=excluded.handoff_notes returning id into v_id;
 perform public.hris_audit('RECRUITMENT_ONBOARDING_HANDOFF','hris_recruitment_onboarding_handoffs_v25',v_id::text,jsonb_build_object('application_id',p_application_id));
 return v_id;
end; $$;

notify pgrst,'reload schema';

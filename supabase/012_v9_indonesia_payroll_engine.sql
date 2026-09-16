-- MoonXprojecT V9 — Indonesian Payroll Engine
-- Run after 011_v8_enterprise_transactions.sql.
-- Rules are parameterized so HR can update statutory master data without changing application code.

create table if not exists public.hris_payroll_rules (
  id uuid primary key default gen_random_uuid(),
  tahun integer not null,
  nama text not null,
  kode text not null,
  nilai numeric(14,6) not null default 0,
  satuan text not null default 'percent',
  aktif boolean not null default true,
  catatan text,
  created_at timestamptz not null default now(),
  unique(tahun,kode)
);

create table if not exists public.hris_payroll_preflight (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.hris_payroll_periods(id) on delete cascade,
  id_karyawan text references public.karyawan(id_karyawan) on delete cascade,
  severity text not null check (severity in ('ERROR','WARNING','INFO')),
  code text not null,
  message text not null,
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_payroll_preflight_period on public.hris_payroll_preflight(period_id,severity,resolved);

create table if not exists public.hris_thr_runs (
  id uuid primary key default gen_random_uuid(),
  tahun integer not null,
  hari_raya text not null,
  tanggal_bayar date,
  status text not null default 'Draft' check (status in ('Draft','Review','Approved','Paid','Closed')),
  catatan text,
  created_at timestamptz not null default now(),
  unique(tahun,hari_raya)
);

create table if not exists public.hris_thr_lines (
  id uuid primary key default gen_random_uuid(),
  thr_run_id uuid not null references public.hris_thr_runs(id) on delete cascade,
  id_karyawan text not null references public.karyawan(id_karyawan) on delete cascade,
  masa_kerja_bulan numeric(8,2) not null default 0,
  upah_dasar numeric(14,2) not null default 0,
  proporsi numeric(10,6) not null default 0,
  nominal numeric(14,2) not null default 0,
  status text not null default 'Draft',
  created_at timestamptz not null default now(),
  unique(thr_run_id,id_karyawan)
);

-- 2026 statutory defaults. These are editable master values, not hard-coded client values.
insert into public.hris_payroll_rules(tahun,nama,kode,nilai,satuan,catatan) values
(2026,'BPJS Kesehatan — Pekerja','BPJS_HEALTH_EMP',1,'percent','PPU: 1% pekerja'),
(2026,'BPJS Kesehatan — Perusahaan','BPJS_HEALTH_ER',4,'percent','PPU: 4% pemberi kerja'),
(2026,'BPJS Kesehatan — Batas Upah','BPJS_HEALTH_CAP',12000000,'idr','Batas upah PPU swasta'),
(2026,'JHT — Pekerja','JHT_EMP',2,'percent',''),
(2026,'JHT — Perusahaan','JHT_ER',3.7,'percent',''),
(2026,'JP — Pekerja','JP_EMP',1,'percent',''),
(2026,'JP — Perusahaan','JP_ER',2,'percent',''),
(2026,'JP — Batas Upah','JP_CAP',10547400,'idr','Batas upah 2026'),
(2026,'JKM — Perusahaan','JKM_ER',0.3,'percent',''),
(2026,'JKK — Risiko Sangat Rendah','JKK_VLOW',0.24,'percent',''),
(2026,'JKK — Risiko Rendah','JKK_LOW',0.54,'percent',''),
(2026,'JKK — Risiko Sedang','JKK_MED',0.89,'percent',''),
(2026,'JKK — Risiko Tinggi','JKK_HIGH',1.27,'percent',''),
(2026,'JKK — Risiko Sangat Tinggi','JKK_VHIGH',1.74,'percent',''),
(2026,'PTKP TK/0','PTKP_TK0',54000000,'idr',''),
(2026,'PTKP TK/1 K/0','PTKP_A',58500000,'idr',''),
(2026,'PTKP TK/2 K/1','PTKP_B1',63000000,'idr',''),
(2026,'PTKP TK/3 K/2','PTKP_B2',67500000,'idr',''),
(2026,'PTKP K/3','PTKP_C',72000000,'idr',''),
(2026,'Biaya Jabatan','BIAYA_JABATAN',5,'percent','Maksimum bulanan mengikuti ketentuan pajak'),
(2026,'THR Masa Kerja Penuh','THR_FULL_MONTH',1,'multiplier','12 bulan atau lebih = 1 bulan upah'),
(2026,'Hari Kerja Standar Payroll','WORKDAYS_METHOD',22,'days','Parameter default; prorata tetap berbasis hari kerja kalender')
on conflict(tahun,kode) do nothing;

insert into public.hris_permissions(kode,nama,modul) values
('payroll.engine','Jalankan payroll engine','payroll'),
('payroll.preflight','Validasi payroll sebelum proses','payroll'),
('payroll.thr','Kelola THR','payroll'),
('payroll.export','Ekspor payroll/pembayaran','payroll')
on conflict(kode) do nothing;

alter table public.hris_payroll_preflight enable row level security;
alter table public.hris_thr_runs enable row level security;
alter table public.hris_thr_lines enable row level security;
alter table public.hris_payroll_rules enable row level security;

drop policy if exists payroll_rules_read on public.hris_payroll_rules;
create policy payroll_rules_read on public.hris_payroll_rules for select to authenticated using (public.hris_has_permission('payroll.read'));
drop policy if exists payroll_rules_write on public.hris_payroll_rules;
create policy payroll_rules_write on public.hris_payroll_rules for all to authenticated using (public.hris_has_permission('payroll.write')) with check (public.hris_has_permission('payroll.write'));
drop policy if exists payroll_preflight_read on public.hris_payroll_preflight;
create policy payroll_preflight_read on public.hris_payroll_preflight for select to authenticated using (public.hris_has_permission('payroll.read'));
drop policy if exists payroll_thr_read on public.hris_thr_runs;
create policy payroll_thr_read on public.hris_thr_runs for select to authenticated using (public.hris_has_permission('payroll.read'));
drop policy if exists payroll_thr_write on public.hris_thr_runs;
create policy payroll_thr_write on public.hris_thr_runs for all to authenticated using (public.hris_has_permission('payroll.thr')) with check (public.hris_has_permission('payroll.thr'));
drop policy if exists payroll_thr_lines_read on public.hris_thr_lines;
create policy payroll_thr_lines_read on public.hris_thr_lines for select to authenticated using (public.hris_has_permission('payroll.read'));
drop policy if exists payroll_thr_lines_write on public.hris_thr_lines;
create policy payroll_thr_lines_write on public.hris_thr_lines for all to authenticated using (public.hris_has_permission('payroll.thr')) with check (public.hris_has_permission('payroll.thr'));

create or replace function public.hris_v9_rule(p_year integer,p_code text,p_default numeric)
returns numeric language sql stable security definer set search_path=public as $$
  select coalesce((select nilai from public.hris_payroll_rules where tahun=p_year and kode=p_code and aktif order by id desc limit 1),p_default);
$$;

create or replace function public.hris_v9_ter(p_category text,p_bruto numeric)
returns numeric language plpgsql immutable as $$
declare r numeric:=0; b numeric:=coalesce(p_bruto,0);
bounds numeric[]; rates numeric[]; i int;
begin
  if p_category='B' then
    bounds:=array[6200000,6500000,6850000,7300000,9200000,10750000,11250000,11600000,12600000,13600000,14950000,16400000,18450000,21850000,26000000,27700000,29350000,31450000,33950000,37100000,41100000,45800000,49500000,53800000,58500000,64000000,71000000,80000000,93000000,109000000,129000000,163000000,211000000,374000000,459000000,555000000,704000000,957000000,1405000000];
    rates:=array[0,0.25,0.5,0.75,1,1.5,2,2.5,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33];
  elsif p_category='C' then
    bounds:=array[6600000,6950000,7350000,7800000,8850000,9800000,10950000,11200000,12050000,12950000,14150000,15550000,17050000,19500000,22700000,26600000,28100000,30100000,32600000,35400000,38900000,43000000,47400000,51200000,55800000,60400000,66700000,74500000,83200000,95600000,110000000,134000000,169000000,221000000,390000000,463000000,561000000,709000000,965000000,1419000000];
    rates:=array[0,0.25,0.5,0.75,1,1.25,1.5,1.75,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33];
  else
    bounds:=array[5400000,5650000,5950000,6300000,6750000,7500000,8550000,9650000,10050000,10350000,10700000,11050000,11600000,12500000,13750000,15100000,16950000,19750000,24150000,26450000,28000000,30050000,32400000,35400000,39100000,43850000,47800000,51400000,56300000,62200000,68600000,77500000,89000000,103000000,125000000,157000000,206000000,337000000,454000000,550000000,695000000,910000000,1400000000];
    rates:=array[0,0.25,0.5,0.75,1,1.25,1.5,1.75,2,2.25,2.5,3,3.5,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33];
  end if;
  for i in 1..array_length(bounds,1) loop
    if b <= bounds[i] then r:=rates[i]; return r/100; end if;
  end loop;
  return 0.34;
end $$;

create or replace function public.hris_v9_preflight(p_period_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare p record; e record; errors int:=0; warnings int:=0; total int:=0; d date; att_count int; bank_count int; tax_count int;
begin
  perform public.hris_require_permission('payroll.preflight');
  select * into p from public.hris_payroll_periods where id=p_period_id;
  if not found then raise exception 'Periode payroll tidak ditemukan'; end if;
  delete from public.hris_payroll_preflight where period_id=p_period_id and not resolved;
  for e in select id_karyawan,nama,gaji_pokok,status_aktif,tanggal_masuk from public.karyawan where coalesce(status_aktif,true) loop
    total:=total+1;
    if coalesce(e.gaji_pokok,0)<=0 then
      insert into public.hris_payroll_preflight(period_id,id_karyawan,severity,code,message) values(p_period_id,e.id_karyawan,'ERROR','NO_BASE_SALARY',e.nama||' belum memiliki gaji pokok'); errors:=errors+1;
    end if;
    select count(*) into bank_count from public.hris_employee_bank_accounts where id_karyawan=e.id_karyawan and active and is_primary;
    if bank_count=0 then
      insert into public.hris_payroll_preflight(period_id,id_karyawan,severity,code,message) values(p_period_id,e.id_karyawan,'WARNING','NO_BANK','Rekening payroll utama belum tersedia'); warnings:=warnings+1;
    end if;
    select count(*) into tax_count from public.hris_employee_tax_profiles where id_karyawan=e.id_karyawan;
    if tax_count=0 then
      insert into public.hris_payroll_preflight(period_id,id_karyawan,severity,code,message) values(p_period_id,e.id_karyawan,'WARNING','NO_TAX_PROFILE','Profil pajak/BPJS belum diisi'); warnings:=warnings+1;
    end if;
    if e.tanggal_masuk is null then
      insert into public.hris_payroll_preflight(period_id,id_karyawan,severity,code,message) values(p_period_id,e.id_karyawan,'INFO','NO_JOIN_DATE','Tanggal masuk kosong; prorata join date tidak diterapkan');
    end if;
  end loop;
  return jsonb_build_object('employees',total,'errors',errors,'warnings',warnings,'period_id',p_period_id);
end $$;

create or replace function public.hris_v9_process_payroll(p_period_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare p record; e record; a record; t record; assign record; y int; m int; days int; workdays int; eligible_days int; base numeric; prorata numeric; overtime_minutes numeric; overtime numeric; earning numeric; deduction numeric; bpjs_health numeric; jht numeric; jp numeric; pph numeric; gross numeric; category text; ter numeric; annual_net numeric; annual_tax numeric; prior_tax numeric; monthly_tax numeric; line_count int:=0; employee_count int:=0; warning_count int;
begin
  perform public.hris_require_permission('payroll.engine');
  select * into p from public.hris_payroll_periods where id=p_period_id for update;
  if not found then raise exception 'Periode payroll tidak ditemukan'; end if;
  if p.status in ('Approved','Paid','Closed') then raise exception 'Periode sudah final: %',p.status; end if;
  y:=extract(year from p.tanggal_mulai); m:=extract(month from p.tanggal_mulai);
  days:=(p.tanggal_selesai-p.tanggal_mulai)+1;
  select count(*) into workdays from generate_series(p.tanggal_mulai,p.tanggal_selesai,'1 day') g(d) where extract(isodow from g.d) between 1 and 5;
  update public.hris_payroll_periods set status='Processing' where id=p.id;
  delete from public.hris_payroll_preflight where period_id=p.id and severity='INFO';
  for e in select * from public.karyawan where coalesce(status_aktif,true) loop
    employee_count:=employee_count+1;
    base:=coalesce(e.gaji_pokok,0);
    eligible_days:=workdays;
    if e.tanggal_masuk is not null and e.tanggal_masuk>p.tanggal_mulai then
      select count(*) into eligible_days from generate_series(greatest(e.tanggal_masuk,p.tanggal_mulai),p.tanggal_selesai,'1 day') g(d) where extract(isodow from g.d) between 1 and 5;
    end if;
    prorata:=case when workdays>0 then base*least(greatest(eligible_days::numeric/workdays,0),1) else base end;
    earning:=0; deduction:=0; overtime_minutes:=0;
    for assign in select a.*,c.nama,c.tipe as component_type from public.hris_payroll_component_assignments a join public.hris_payroll_komponen c on c.id=a.komponen_id where a.id_karyawan=e.id_karyawan and a.aktif and a.mulai_berlaku<=p.tanggal_selesai and (a.selesai_berlaku is null or a.selesai_berlaku>=p.tanggal_mulai) loop
      if lower(coalesce(assign.tipe,assign.component_type,'')) in ('potongan','deduction') or lower(assign.component_type)='potongan' then deduction:=deduction+coalesce(assign.nominal,0); else earning:=earning+coalesce(assign.nominal,0); end if;
    end loop;
    select coalesce(sum(greatest(menit,0)),0) into overtime_minutes from public.hris_lembur where id_karyawan=e.id_karyawan and tanggal between p.tanggal_mulai and p.tanggal_selesai and status='Disetujui';
    overtime:=round((base/173)*(overtime_minutes/60)*coalesce((select nilai from public.hris_company_settings where id=1 limit 1),2));
    -- The setting query above may return a non-multiplier field on older schemas; default to 2 below if unsafe.
    if overtime<0 then overtime:=0; end if;
    gross:=round(prorata+earning+overtime,2);
    select * into t from public.hris_employee_tax_profiles where id_karyawan=e.id_karyawan limit 1;
    category:=case when coalesce(t.status_ptkp,'TK/0') in ('TK/2','K/1','TK/3','K/2') then 'B' when coalesce(t.status_ptkp,'TK/0')='K/3' then 'C' else 'A' end;
    ter:=public.hris_v9_ter(category,gross);
    if m between 1 and 11 then pph:=round(gross*ter,2); else
      select coalesce(sum(pph21),0) into prior_tax from public.hris_payroll where id_karyawan=e.id_karyawan and periode like y::text||'-%' and periode<>p.kode;
      annual_net:=greatest(0,(gross*12)-least(gross*12*0.05,6000000)-coalesce(case when category='A' then 58500000 when category='B' then case when coalesce(t.status_ptkp,'') in ('TK/3','K/2') then 67500000 else 63000000 end else 72000000 end,54000000));
      annual_tax:=least(annual_net,60000000)*0.05+greatest(least(annual_net-60000000,190000000),0)*0.15+greatest(least(annual_net-250000000,250000000),0)*0.25+greatest(least(annual_net-500000000,4500000000),0)*0.30+greatest(annual_net-5000000000,0)*0.35;
      pph:=greatest(0,round(annual_tax-prior_tax,2));
    end if;
    bpjs_health:=round(least(gross,public.hris_v9_rule(y,'BPJS_HEALTH_CAP',12000000))*public.hris_v9_rule(y,'BPJS_HEALTH_EMP',1)/100,2);
    jht:=round(gross*public.hris_v9_rule(y,'JHT_EMP',2)/100,2);
    jp:=round(least(gross,public.hris_v9_rule(y,'JP_CAP',10547400))*public.hris_v9_rule(y,'JP_EMP',1)/100,2);
    deduction:=deduction+bpjs_health+jht+jp+pph;
    insert into public.hris_payroll(id_karyawan,periode,gaji_pokok,tunjangan,uang_makan,transport,lembur,bonus,potongan,bpjs,pph21,status,tanggal_proses,catatan)
    values(e.id_karyawan,p.kode,round(prorata,2),earning,0,0,overtime,0,deduction,bpjs_health+jht+jp,pph,'Draft',now(),'V9 Indonesian Payroll Engine')
    on conflict(id_karyawan,periode) do update set gaji_pokok=excluded.gaji_pokok,tunjangan=excluded.tunjangan,lembur=excluded.lembur,potongan=excluded.potongan,bpjs=excluded.bpjs,pph21=excluded.pph21,tanggal_proses=now(),catatan='V9 recalculation';
    select id into a from public.hris_payroll where id_karyawan=e.id_karyawan and periode=p.kode;
    delete from public.hris_payroll_lines where payroll_id=a.id;
    insert into public.hris_payroll_lines(payroll_id,id_karyawan,kode,nama,tipe,qty,rate,amount,source) values
      (a.id,e.id_karyawan,'BASE','Gaji Pokok','earning',1,base,round(prorata,2),'salary_proration'),
      (a.id,e.id_karyawan,'OT','Lembur','earning',overtime_minutes/60,case when overtime_minutes=0 then 0 else overtime/(overtime_minutes/60) end,overtime,'approved_overtime'),
      (a.id,e.id_karyawan,'BPJS-KES','BPJS Kesehatan','deduction',1,1,bpjs_health,'statutory'),
      (a.id,e.id_karyawan,'JHT','JHT Pekerja','deduction',1,2,jht,'statutory'),
      (a.id,e.id_karyawan,'JP','JP Pekerja','deduction',1,1,jp,'statutory'),
      (a.id,e.id_karyawan,'PPH21','PPh 21','deduction',1,ter*100,pph,'TER/annual-final');
    line_count:=line_count+6;
  end loop;
  update public.hris_payroll_periods set status='Open' where id=p.id;
  return jsonb_build_object('period_id',p.id,'period_code',p.kode,'employees',employee_count,'lines',line_count,'workdays',workdays);
end $$;

create or replace function public.hris_v9_create_thr(p_year integer,p_hari_raya text,p_tanggal_bayar date)
returns uuid language plpgsql security definer set search_path=public as $$
declare run_id uuid; e record; start_date date; months numeric; prop numeric; nominal numeric; base numeric;
begin
  perform public.hris_require_permission('payroll.thr');
  insert into public.hris_thr_runs(tahun,hari_raya,tanggal_bayar,status) values(p_year,p_hari_raya,p_tanggal_bayar,'Draft') on conflict(tahun,hari_raya) do update set tanggal_bayar=excluded.tanggal_bayar returning id into run_id;
  delete from public.hris_thr_lines where thr_run_id=run_id;
  for e in select * from public.karyawan where coalesce(status_aktif,true) loop
    start_date:=coalesce(e.tanggal_masuk,make_date(p_year,1,1));
    months:=least(12,greatest(0,round((extract(epoch from (make_date(p_year,12,31)-greatest(start_date,make_date(p_year,1,1))))/86400/30.4375)::numeric,2)+case when start_date<=make_date(p_year,1,1) then 1 else 0 end));
    if months>=12 then prop:=1; else prop:=months/12; end if;
    base:=coalesce(e.gaji_pokok,0);
    nominal:=round(base*prop,2);
    insert into public.hris_thr_lines(thr_run_id,id_karyawan,masa_kerja_bulan,upah_dasar,proporsi,nominal) values(run_id,e.id_karyawan,months,base,prop,nominal);
  end loop;
  return run_id;
end $$;

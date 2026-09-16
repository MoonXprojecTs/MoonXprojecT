-- V15: people analytics snapshots and metrics
create table if not exists public.hris_people_metrics(id uuid primary key default gen_random_uuid(), metric_date date not null default current_date, metric_code text not null, metric_value numeric not null default 0, dimension text, dimension_value text, created_at timestamptz default now(), unique(metric_date,metric_code,dimension,dimension_value));
create index if not exists idx_v15_people_metrics on public.hris_people_metrics(metric_date,metric_code);

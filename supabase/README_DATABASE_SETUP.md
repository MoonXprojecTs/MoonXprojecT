# MoonXprojecT — Database Deployment Guide

## Fresh Supabase project
Use `BOOTSTRAP_FRESH_DATABASE.sql` once in the Supabase SQL Editor. It contains the complete schema chain in dependency order: legacy foundation 000–025 followed by enterprise migrations 026 onward.

## Existing MoonXprojecT database
Do **not** blindly rerun the bootstrap file. Keep the database migration history already applied and run only the new migration files that are not yet applied, or use the Supabase CLI migration history for the project.

## Security
Never put a Supabase service-role key in Vite/Netlify client variables. The browser must use the publishable/anon key only. Database authorization is enforced with RLS and HRIS permission functions.

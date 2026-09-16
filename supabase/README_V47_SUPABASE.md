# MoonXprojecT V47 — Supabase Database

## Fresh Supabase project
Run `V47_COMPLETE_SUPABASE.sql` once in the Supabase SQL Editor.

It contains the complete dependency-ordered database chain used by MoonXprojecT, followed by the V47 final hardening section.

## Existing production database
Do **not** run the complete file over an already-populated production database. Keep the migration history already applied and run only unapplied migrations.

## Auth setup
Create the first HR account through Supabase Authentication. Then promote that account to Super Admin using the commented SQL instruction in the bootstrap/security section, replacing the email with the real HR account email.

## Client security
Use only the Supabase publishable/anon key in Netlify/Vite. Never put a service-role key in frontend environment variables.

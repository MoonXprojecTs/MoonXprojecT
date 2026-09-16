import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = String(import.meta.env.VITE_SUPABASE_URL || '').trim().replace(/\/$/, '')
const SUPABASE_PUBLISHABLE_KEY = String(import.meta.env.VITE_SUPABASE_ANON_KEY || '').trim()

export const isSupabaseConfigured = Boolean(SUPABASE_URL && SUPABASE_PUBLISHABLE_KEY)

// Keep the public landing page renderable even before deployment environment variables are set.
// Auth/data actions remain disabled until a real Supabase project is configured.
const clientUrl = SUPABASE_URL || 'https://placeholder.supabase.co'
const clientKey = SUPABASE_PUBLISHABLE_KEY || 'placeholder-anon-key'

export const supabase = createClient(clientUrl, clientKey, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
})

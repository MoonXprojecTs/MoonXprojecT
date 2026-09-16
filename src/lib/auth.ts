import { supabase } from './supabase/client'

export async function signIn(email: string, password: string) {
  return supabase.auth.signInWithPassword({ email: email.trim(), password })
}

export async function signOut() { return supabase.auth.signOut() }

export async function currentUser() {
  const { data } = await supabase.auth.getUser()
  return data.user
}

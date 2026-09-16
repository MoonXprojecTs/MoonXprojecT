
import { supabase } from './supabase/client'

export async function fetchEmployees() {
  return supabase.from('karyawan').select('*').order('nama')
}

export async function fetchAttendance(limit = 2000) {
  return supabase.from('absensi').select('*').order('created_at', { ascending: false }).limit(limit)
}

export async function createEmployee(payload: Record<string, unknown>) {
  return supabase.from('karyawan').insert(payload).select().single()
}

export async function updateEmployee(id: string, payload: Record<string, unknown>) {
  return supabase.from('karyawan').update(payload).eq('id', id).select().single()
}

export async function removeEmployee(id: string) {
  return supabase.from('karyawan').delete().eq('id', id)
}

export async function upsertAttendance(payload: Record<string, unknown>, existingId?: string) {
  if (existingId) return supabase.from('absensi').update(payload).eq('id', existingId).select().single()
  return supabase.from('absensi').insert(payload).select().single()
}

export function exportCsv(rows: Record<string, unknown>[], filename: string) {
  if (!rows.length) return false
  const keys = Object.keys(rows[0])
  const esc = (v: unknown) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [keys.join(';'), ...rows.map(r => keys.map(k => esc(r[k])).join(';'))].join('\n')
  const blob = new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8;' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = filename
  a.click()
  URL.revokeObjectURL(a.href)
  return true
}

export function rupiah(value: number) {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency', currency: 'IDR', maximumFractionDigits: 0
  }).format(Number(value) || 0)
}

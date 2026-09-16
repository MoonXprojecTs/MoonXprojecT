# MoonXprojecT Enterprise V43

V43 adalah production-hardening release berbasis V42 Organized.

## Fokus
- Runtime error boundary dan graceful recovery.
- Konfigurasi Supabase wajib melalui environment variable.
- RBAC menu tetap terhubung dengan permission database dan RLS/RPC server-side.
- Index operasional untuk users, roles, employees, attendance, dan approvals.
- Integritas `updated_at` untuk company settings.
- Struktur folder V42 dipertahankan.

## Environment
Set di Netlify/GitHub environment:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

## Build
```bash
npm ci
npm run build
npm run lint
```

V43 package tidak mengklaim build berhasil sampai command di atas benar-benar dijalankan pada environment dependency lengkap.

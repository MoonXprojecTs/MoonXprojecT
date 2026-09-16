# MoonXprojecT Enterprise V21

V21 focuses on Security & Authorization Hardening.

## Highlights
- Hardened approval RPC: assigned approver role + module permission are checked server-side.
- V20 approval RPC delegates to the hardened V21 authorization path.
- Audit log mutation protection (immutable update/delete trigger + grants).
- Security event log with server-derived actor identity.
- Security Center UI for effective permissions and security events.
- Role & Permission writes are restricted to Super Admin.

## Migration
Run `supabase/024_v21_security_hardening.sql` after migrations 000 through 023.

## Important
Build/lint must be verified in the GitHub/Netlify environment because dependencies are not bundled in this ZIP. Review Supabase RLS, Auth policies, Storage, and production secrets before go-live.

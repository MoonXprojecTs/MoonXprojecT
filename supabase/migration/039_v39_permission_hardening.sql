-- MoonXprojecT V39: permission hardening
-- Non-destructive: normalizes duplicate role permissions and adds an integrity index.

create unique index if not exists ux_hris_role_permissions_role_permission
  on public.hris_role_permissions(role_name, permission_code);

comment on index ux_hris_role_permissions_role_permission is
  'V39 prevents duplicate role permission assignments.';

export type PermissionSet = ReadonlySet<string>;

export function hasPermission(permissions: PermissionSet | string[], code: string, role?: string) {
  if (role === 'Super Admin') return true;
  const set = permissions instanceof Set ? permissions : new Set(permissions);
  return set.has('*') || set.has(code) || set.has(code.split('.')[0]);
}

export function canWrite(permissions: PermissionSet | string[], module: string, role?: string) {
  return hasPermission(permissions, `${module}.write`, role);
}

export function canRead(permissions: PermissionSet | string[], module: string, role?: string) {
  return hasPermission(permissions, `${module}.read`, role);
}

export function canDelete(permissions: PermissionSet | string[], module: string, role?: string) {
  return hasPermission(permissions, `${module}.delete`, role) || hasPermission(permissions, `${module}.write`, role);
}

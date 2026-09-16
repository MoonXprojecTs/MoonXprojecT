import type { CSSProperties } from 'react';

type IconName = string;

const paths: Record<string, string> = {
  chevronDown: 'M6 9l6 6 6-6',
  chevronRight: 'M9 6l6 6-6 6',
  logout: 'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4m7 14 5-5-5-5m5 5H9',
  menu: 'M4 6h16M4 12h16M4 18h16',
  refresh: 'M20 11a8 8 0 1 0 1 4m-1-4v-5m0 5h-5',
  search: 'M11 19a8 8 0 1 1 0-16 8 8 0 0 1 0 16m10 2-4.3-4.3',
  home: 'M3 10.5 12 3l9 7.5V21a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z',
  users: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8m6-3a4 4 0 0 1 4 4m-1-8a3 3 0 0 1 0 6',
  plus: 'M12 5v14M5 12h14',
  org: 'M4 4h16v16H4zM8 8h3v3H8zm5 0h3v3h-3zM8 13h3v3H8zm5 0h3v3h-3z',
  clock: 'M12 7v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0',
  check: 'm5 12 4 4L19 6',
  alert: 'M12 9v4m0 4h.01M10.3 3.9 2.7 17a2 2 0 0 0 1.7 3h15.2a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0',
  leave: 'M7 3h10v18H7zM10 12h7m0 0-3-3m3 3-3 3',
  arrow: 'M5 12h14m-6-6 6 6-6 6',
  camera: 'M4 7h3l2-2h6l2 2h3v12H4zM12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8',
  calendar: 'M4 5h16v16H4zM8 3v4m8-4v4M4 10h16',
  shift: 'M6 4h12v16H6zM9 8h6M9 12h6M9 16h4',
  holiday: 'M12 2l2.6 6.3 6.8.5-5.2 4.4 1.6 6.6-5.8-3.5-5.8 3.5 1.6-6.6-5.2-4.4 6.8-.5z',
  request: 'M6 3h12v18H6zM9 8h6M9 12h6M9 16h4',
  balance: 'M5 4h14v16H5zM9 8h6M9 12h3',
  payroll: 'M5 4h14v16H5zM8 8h8M8 12h8M8 16h5',
  components: 'M5 5h14M5 12h14M5 19h14',
  kpi: 'M5 20V10m7 10V4m7 16v-7',
  recruitment: 'M4 6h16v12H4zM8 10h8M8 14h5',
  report: 'M5 4h14v16H5zM8 9h8M8 13h8M8 17h5',
  settings: 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0-8m0-6v3m0 14v3m10-10h-3M5 12H2m17.1-7.1-2.1 2.1M7 17l-2.1 2.1m12.2 0L15 17M7 7 4.9 4.9',
  bell: 'M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4',
  health: 'M3 12h4l2-6 4 12 2-6h6',
  building: 'M5 21V4h14v17M8 8h2m4 0h2M8 12h2m4 0h2M8 16h2m4 0h2M3 21h18',
  file: 'M6 3h9l3 3v15H6zM14 3v4h4M9 11h6M9 15h6',
  lock: 'M7 10V7a5 5 0 0 1 10 0v3M5 10h14v11H5z',
  target: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18m0-5a4 4 0 1 0 0-8 4 4 0 0 0 0 8m0-4h.01',
  inbox: 'M4 4h16v16H4zM4 14h4l2 3h4l2-3h4',
  interview: 'M5 5h14v14H5zM8 9h8M8 13h5',
  people: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8m-7 9a7 7 0 0 1 14 0',
  folder: 'M3 6h7l2 2h9v11H3z',
};

const aliases: Record<string, string> = {
  dashboard: 'home',
  all: 'inbox',
  overtime: 'arrow',
  payroll: 'payroll',
  ess_leave: 'leave',
  ess_overtime: 'arrow',
  ess_attendance: 'clock',
  ess_profile: 'users',
  contracts: 'file',
  exceptions: 'alert',
  onboarding: 'check',
  vacancies: 'recruitment',
  interviews: 'calendar',
  candidates: 'users',
  pipeline: 'kpi',
  leave: 'leave',
  components: 'components',
  history: 'clock',
  summary: 'report',
  today: 'calendar',
  people: 'users',
};

export default function AdminIcon({ name, className = '', size = 17, style }: { name: IconName; className?: string; size?: number; style?: CSSProperties }) {
  const key = paths[name] ? name : aliases[name] || 'home';
  return (
    <svg
      className={`ui-icon ${className}`.trim()}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      style={style}
    >
      <path d={paths[key]} />
    </svg>
  );
}

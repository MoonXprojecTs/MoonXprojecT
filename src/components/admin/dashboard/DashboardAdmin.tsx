import PayrollIndonesiaV23 from '../payroll/PayrollIndonesiaV23';
import { useEffect, useMemo, useState, type FormEvent, type ReactNode, type CSSProperties } from 'react';
import { isSupabaseConfigured, supabase } from '../../../lib/supabase/client';
import { signIn, signOut } from '../../../lib/auth';
import { rupiah } from '../../../lib/hris';
import { canDelete, canWrite, hasPermission } from '../../../lib/security';
import '../../../styles/admin/admin.css';
import MasterData from '../employee/MasterData';
import { PayrollEnterprise, RecruitmentEnterprise, RoleEditorEnterprise, ApprovalCenter } from '../enterprise/EnterpriseModules';
import { PayrollEngineV9 } from '../payroll/PayrollEngineV9';
import Employee360 from '../employee/Employee360';
import HRISCore from '../core/HRISCore';
import ProductionHR from '../payroll/ProductionHR';
import EnterpriseV20 from '../enterprise/EnterpriseV20';
import SecurityCenterV21 from '../security/SecurityCenterV21';
import PayrollProductionV22 from '../payroll/PayrollProductionV22';
import RecruitmentATSv25 from '../recruitment/RecruitmentATSv25';
import EnterpriseRoadmapV26V35 from '../enterprise/EnterpriseRoadmapV26V35';
import moonLogo from '../../../assets/moon-logo.svg';

type Karyawan = {
  id: string;
  id_karyawan?: string;
  nama: string;
  jabatan?: string;
  email?: string;
  email_terverifikasi?: boolean;
  auth_user_id?: string;
  no_telp?: string;
  alamat_rumah?: string;
  gaji_pokok?: number;
  nik_ktp?: string;
  departemen?: string;
  status_aktif?: boolean;
  tanggal_masuk?: string;
  status_karyawan?: string;
  role?: string;
};type Absensi = {
  id: string; karyawan_id?: string; id_karyawan?: string; nama?: string; jabatan?: string;
  tanggal?: string; jam_masuk?: string; jam_pulang?: string; total_jam?: string;
  status?: string; lokasi?: string; foto?: string; selfie_masuk?: string;
  keterlambatan_menit?: number; lembur_menit?: number; lokasi_masuk?: string;
};
type MenuKey =
 | 'overview'|'employees'|'employee-360'|'employee-add'|'organization'|'attendance'|'attendance-today'|'late'|'leave'|'overtime'|'selfie'
 | 'schedule'|'shift'|'holiday'|'leave-request'|'leave-balance'|'payroll'|'payroll-components'|'payroll-overtime'|'payslip'
 | 'hr-operations'|'production-hr'|'payroll-engine'|'performance'|'kpi'|'recruitment'|'candidates'|'reports'|'settings'|'roles'|'audit'|'approvals'|'notifications'|'system-health'|'security-v21'|'payroll-production-v22'|'recruitment-v25'|'enterprise-v20'|'enterprise-v26'|'enterprise-v27'|'enterprise-v28'|'enterprise-v29'|'enterprise-v30'|'enterprise-v31'|'enterprise-v32'|'enterprise-v33'|'enterprise-v34'|'enterprise-v35'|'payroll-indonesia-v23';

const money=(n:number)=>rupiah(n);
const isoToday=()=>new Date().toISOString().slice(0,10);
const menuGroups: {title:string;items: readonly [MenuKey,string,string][]}[] = [
 {title:'UTAMA',items:[['overview','Overview','home']]},
 {title:'PEOPLE',items:[['employees','Semua Karyawan','users'],['employee-360','Employee 360°','users'],['employee-add','Tambah Karyawan','plus'],['organization','Organisasi','org'],['hr-operations','HR Operations','settings']]},
 {title:'ATTENDANCE',items:[['attendance','Rekap Absensi','clock'],['attendance-today','Absensi Hari Ini','check'],['late','Keterlambatan','alert'],['leave','Izin & Sakit','leave'],['overtime','Lembur','arrow'],['selfie','Monitoring Selfie','camera']]},
 {title:'SCHEDULE',items:[['schedule','Jadwal Kerja','calendar'],['shift','Shift','shift'],['holiday','Hari Libur','holiday']]},
 {title:'LEAVE',items:[['leave-request','Pengajuan Cuti','request'],['leave-balance','Saldo Cuti','balance']]},
 {title:'PAYROLL',items:[['payroll','Payroll Bulanan','payroll'],['production-hr','HR Transaction Center','settings'],['payroll-engine','Payroll Engine V9','payroll'],['payroll-production-v22','Payroll Production V22','payroll'],['payroll-components','Komponen Gaji','components'],['payroll-overtime','Payroll Lembur','arrow'],['payslip','Slip Gaji','calendar']]},
 {title:'TALENT',items:[['performance','Performance','arrow'],['kpi','KPI & Target','kpi'],['recruitment-v25','Recruitment ATS Enterprise','recruitment'],['recruitment','Recruitment Legacy','recruitment'],['candidates','Kandidat','users']]},
 {title:'ENTERPRISE SUITE',items:[['enterprise-v26','Documents & Compliance','request'],['enterprise-v27','Performance & KPI','kpi'],['enterprise-v28','HR Analytics & BI','kpi'],['enterprise-v29','HR Inbox','bell'],['enterprise-v30','ESS Enterprise','users'],['enterprise-v31','QA & Testing','check'],['enterprise-v32','Production Optimization','settings'],['enterprise-v33','Multi-Company','org'],['enterprise-v34','API & Integrations','settings'],['enterprise-v35','AI HR & Automation','kpi']]},
 {title:'REPORTING',items:[['reports','Laporan','report']]},
 {title:'SYSTEM',items:[['enterprise-v20','Enterprise Command Center','org'],['payroll-indonesia-v23','Payroll Indonesia Compliance','payroll'],['security-v21','Security Center','health'],['approvals','Pusat Persetujuan','check'],['notifications','Notifikasi','bell'],['system-health','System Health','health'],['settings','Pengaturan','settings'],['roles','Role & Permission','users'],['audit','Audit Log','request']]}
] as const;

const rolePermissions: Record<string,string[]> = {'Super Admin':['*'],'Admin':['people','attendance','schedule','leave','payroll','talent','reports','system'],'HRD':['people','attendance','schedule','leave','talent','reports'],'Payroll':['people.read','attendance.read','payroll','reports.payroll'],'Supervisor':['people.read','attendance.read','schedule.read','leave.read','leave.approve','reports.attendance'],'Karyawan':[]};
const menuGroup=(key:MenuKey)=>['employees','employee-360','employee-add','organization'].includes(key)?'people':['attendance','attendance-today','late','leave','overtime','selfie'].includes(key)?'attendance':['schedule','shift','holiday'].includes(key)?'schedule':['leave-request','leave-balance','approvals'].includes(key)?'leave':['payroll','payroll-components','payroll-overtime','payslip','production-hr','payroll-engine','payroll-production-v22'].includes(key)?'payroll':['performance','kpi'].includes(key)?'talent':['recruitment','candidates','recruitment-v25'].includes(key)?'recruitment':['enterprise-v26','enterprise-v27','enterprise-v28','enterprise-v29','enterprise-v30','enterprise-v31','enterprise-v32','enterprise-v33','enterprise-v34','enterprise-v35'].includes(key)?'system':key==='reports'?'reports':key==='settings'?'settings':key==='roles'?'roles':key==='audit'?'audit':key==='notifications'?'notifications':key==='system-health'?'system':(key==='enterprise-v26'||key==='payroll-indonesia-v23')||key==='security-v21'?'system':'overview';
const requiredPermission=(key:MenuKey)=>{if(key==='hr-operations')return 'people.read';if(key==='production-hr'||key==='payroll-engine'||key==='payroll-production-v22')return 'payroll.read';const g=menuGroup(key); if(key==='employee-add')return 'people.write'; if(key==='roles')return 'roles.read'; if(key==='settings')return 'settings.write'; if(key==='audit')return 'audit.read'; if(key==='approvals')return 'approval.read'; if(key==='notifications')return 'notifications.read'; if(key==='system-health')return 'system.health';if((key==='enterprise-v26'||key==='payroll-indonesia-v23'))return 'system.health'; if(key==='security-v21')return 'security.read'; if(key.startsWith('enterprise-v')) return 'system.health'; if(key==='overtime')return 'overtime.read'; if(key==='reports')return 'reports.read'; if(g==='recruitment')return 'recruitment.read'; if(g==='talent')return 'talent.read'; return g==='overview'?'':`${g}.read`;};
const menuPermissionForRole=(key:MenuKey,role:string,dbPerms:string[]=[])=>{if(role==='Super Admin'||requiredPermission(key)===''||dbPerms.includes('*'))return true;const req=requiredPermission(key);if(key==='approvals')return ['approval.read','leave.approve','overtime.approve','payroll.approve','recruitment.approve'].some(p=>hasPermission(dbPerms,p,role)||hasPermission(rolePermissions[role]||[],p,role));return hasPermission(dbPerms,req,role)||hasPermission(dbPerms,menuGroup(key),role)||hasPermission(rolePermissions[role]||[],req,role)||hasPermission(rolePermissions[role]||[],menuGroup(key),role);};

function Icon({name}:{name:string}){
 const paths:Record<string,string>={chevronDown:'M6 9l6 6 6-6',chevronRight:'M9 6l6 6-6 6',logout:'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4m7 14 5-5-5-5m5 5H9',menu:'M4 6h16M4 12h16M4 18h16',refresh:'M20 11a8 8 0 1 0 1 4m-1-4v-5m0 5h-5',search:'M11 19a8 8 0 1 1 0-16 8 8 0 0 1 0 16m10 2-4.3-4.3',home:'M3 10.5 12 3l9 7.5V21a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z',users:'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8m6-3a4 4 0 0 1 4 4m-1-8a3 3 0 0 1 0 6',plus:'M12 5v14M5 12h14',org:'M4 4h16v16H4zM8 8h3v3H8zm5 0h3v3h-3zM8 13h3v3H8zm5 0h3v3h-3z',clock:'M12 7v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0',check:'m5 12 4 4L19 6',alert:'M12 9v4m0 4h.01M10.3 3.9 2.7 17a2 2 0 0 0 1.7 3h15.2a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0',leave:'M7 3h10v18H7zM10 12h7m0 0-3-3m3 3-3 3',arrow:'M5 12h14m-6-6 6 6-6 6',camera:'M4 7h3l2-2h6l2 2h3v12H4zM12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8',calendar:'M4 5h16v16H4zM8 3v4m8-4v4M4 10h16',shift:'M6 4h12v16H6zM9 8h6M9 12h6M9 16h4',holiday:'M12 2l2.6 6.3 6.8.5-5.2 4.4 1.6 6.6-5.8-3.5-5.8 3.5 1.6-6.6-5.2-4.4 6.8-.5z',request:'M6 3h12v18H6zM9 8h6M9 12h6M9 16h4',balance:'M5 4h14v16H5zM9 8h6M9 12h3',payroll:'M5 4h14v16H5zM8 8h8M8 12h8M8 16h5',components:'M5 5h14M5 12h14M5 19h14',kpi:'M5 20V10m7 10V4m7 16v-7',recruitment:'M4 6h16v12H4zM8 10h8M8 14h5',report:'M5 4h14v16H5zM8 9h8M8 13h8M8 17h5',settings:'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8m0-6v3m0 14v3m10-10h-3M5 12H2m17.1-7.1-2.1 2.1M7 17l-2.1 2.1m12.2 0L15 17M7 7 4.9 4.9',bell:'M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9m-8 13h6',health:'M20 12h-4l-2 7-4-14-2 7H4',dashboard:'M4 4h6v6H4zm10 0h6v6h-6zM4 14h6v6H4zm10 0h6v6h-6z'}
 const d=paths[name]||paths.home; return <svg className="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={d}/></svg>
}

export default function DashboardAdmin(){
 const [logged,setLogged]=useState(false),[email,setEmail]=useState(''),[pin,setPin]=useState('');
 const [menu,setMenu]=useState<MenuKey>('overview'),[sidebar,setSidebar]=useState(true);
 const [open,setOpen]=useState<Record<string,boolean>>(Object.fromEntries(menuGroups.map(g=>[g.title,true])));
 const [employees,setEmployees]=useState<Karyawan[]>([]),[attendance,setAttendance]=useState<Absensi[]>([]);
 const [search,setSearch]=useState(''),[loading,setLoading]=useState(false),[error,setError]=useState(''),[toast,setToast]=useState('');
 const [editing,setEditing]=useState<Karyawan|null>(null),[userRole,setUserRole]=useState('');
 const [dbPerms,setDbPerms]=useState<string[]>([]);
 const [sessionChecking,setSessionChecking]=useState(true);

 useEffect(()=>{
  let active=true;
  const loadSession=async()=>{
   setSessionChecking(true);
   if(!isSupabaseConfigured){setError('Supabase belum dikonfigurasi. Isi VITE_SUPABASE_URL dan VITE_SUPABASE_ANON_KEY pada environment deployment.');setSessionChecking(false);return;}
   const {data}=await supabase.auth.getUser();
   if(!active)return;
   if(data.user?.email){
    const {data:p}=await supabase.from('hris_users').select('role,status').eq('email',data.user.email).maybeSingle();
    if(active&&p?.status==='Aktif'){
     setUserRole(p.role||'');
     const {data:rp}=await supabase.from('hris_role_permissions').select('permission_code').eq('role_name',p.role);
     if(active){setDbPerms((rp||[]).map(x=>x.permission_code));setEmail(data.user.email);setLogged(true);}
    } else if(active) { await supabase.auth.signOut(); setLogged(false); }
   }
   if(active)setSessionChecking(false);
  };
  loadSession();
  if(!isSupabaseConfigured)return()=>{active=false};
  const {data:listener}=supabase.auth.onAuthStateChange((event,session)=>{
   if(event==='SIGNED_OUT' || !session){setLogged(false);setUserRole('');setDbPerms([]);setSessionChecking(false);}
  });
  return()=>{active=false;listener.subscription.unsubscribe()};
 },[]);
 useEffect(()=>{if(logged)refresh()},[logged]);
 useEffect(()=>{const read=()=>{const candidate=location.hash.replace('#/','') as MenuKey;if(candidate&&menuGroups.flatMap(g=>g.items).some(x=>x[0]===candidate)&&menuPermissionForRole(candidate,userRole,dbPerms))setMenu(candidate)};read();window.addEventListener('hashchange',read);return()=>window.removeEventListener('hashchange',read)},[userRole,dbPerms]);
 const navigate=(next:MenuKey)=>{setMenu(next);location.hash=`/${next}`;if(window.innerWidth<900)setSidebar(false)};
  async function confirmEmployeeEmail(employee: Karyawan) {
  if (!employee.email) {
    setError('Karyawan belum memiliki email.');
    return;
  }

  if (!employee.auth_user_id) {
    setError(
      'Akun login karyawan belum terhubung dengan data karyawan.'
    );
    return;
  }

  if (employee.email_terverifikasi) {
    setToast(
      `Email ${employee.email} sudah terverifikasi.`
    );
    return;
  }

  const confirmed = window.confirm(
    `Konfirmasi email karyawan berikut?\n\n` +
    `Nama: ${employee.nama}\n` +
    `ID: ${employee.id_karyawan || '-'}\n` +
    `Email: ${employee.email}`
  );

  if (!confirmed) {
    return;
  }

  try {
    setError('');

    const {
      data: sessionData,
      error: sessionError,
    } = await supabase.auth.getSession();

    if (sessionError) {
      throw sessionError;
    }

    const accessToken =
      sessionData.session?.access_token;

    if (!accessToken) {
      throw new Error(
        'Sesi login HR tidak ditemukan. Silakan login ulang.'
      );
    }

    setLoading(true);

    const response = await fetch(
      '/.netlify/functions/confirm-email',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization:
            `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          employee_id: employee.id,
        }),
      }
    );

    let result: {
      success?: boolean;
      message?: string;
      error?: string;
    } = {};

    try {
      result = await response.json();
    } catch {
      result = {};
    }

    if (!response.ok) {
      throw new Error(
        result.error ||
        result.message ||
        'Konfirmasi email gagal.'
      );
    }

    setToast(
      result.message ||
      `Email ${employee.email} berhasil dikonfirmasi.`
    );

    await refresh();
  } catch (error: unknown) {
    const message =
      error instanceof Error
        ? error.message
        : 'Konfirmasi email gagal.';

    setError(message);
  } finally {
    setLoading(false);
  }
}
 async function refresh(){
  setLoading(true); setError('');
  const [k,a]=await Promise.all([
   supabase.from('karyawan').select('*').order('nama'),
   supabase.from('absensi').select('*').order('created_at',{ascending:false}).limit(2000)
  ]);
  if(k.error)setError(`Karyawan: ${k.error.message}`); else setEmployees(k.data||[]);
  if(a.error)setError(v=>v?`${v}\nAbsensi: ${a.error.message}`:`Absensi: ${a.error.message}`); else setAttendance(a.data||[]);
  setLoading(false);
 }
 async function login(e:FormEvent){
  e.preventDefault(); setError('');
  if(!isSupabaseConfigured){setError('Supabase belum dikonfigurasi. Isi VITE_SUPABASE_URL dan VITE_SUPABASE_ANON_KEY pada environment deployment.');return}
  setLoading(true);
  const {data,error:e2}=await signIn(email,pin);
  setLoading(false);
  if(e2 || !data.user){ setError(e2?.message || 'Email atau password tidak valid.'); return; }
  const {data:profile,error:pe}=await supabase.from('hris_users').select('role,status').ilike('email',data.user.email||'').maybeSingle();
  if(pe){ await signOut(); setError('Profil akses HR tidak dapat diverifikasi. Coba lagi atau hubungi administrator.'); return; }
  if(!profile || profile.status!=='Aktif'){
    await signOut(); setError('Akun tidak memiliki akses Dashboard HR.'); return;
  }
  setUserRole(profile.role);
  const {data:rp}=await supabase.from('hris_role_permissions').select('permission_code').eq('role_name',profile.role);
  setDbPerms((rp||[]).map(x=>x.permission_code));
  setLogged(true);
 }
 async function removeEmployee(k:Karyawan){
  if(!menuPermissionForRole('employees',userRole,dbPerms) || !canDelete(dbPerms,'people',userRole)){setError('Anda tidak memiliki permission people.delete.');return}
  if(!confirm(`Hapus ${k.nama}?`))return;
  const {error:e}=await supabase.from('karyawan').delete().eq('id',k.id);
  if(e)setError(e.message);else{setToast('Karyawan dihapus.');refresh()}
 }
 async function saveEdit(payload:Record<string,unknown>){
  if(!canWrite(dbPerms,'people',userRole)){setError('Anda tidak memiliki permission people.write.');return}
  if(!editing)return;
  const {error:e}=await supabase.from('karyawan').update(payload).eq('id',editing.id);
  if(e)setError(e.message);else{setEditing(null);setToast('Data karyawan tersimpan.');refresh()}
 }
 const filtered=useMemo(()=>employees.filter(k=>`${k.nama} ${k.id_karyawan||''} ${k.jabatan||''} ${k.departemen||''}`.toLowerCase().includes(search.toLowerCase())),[employees,search]);
 const filteredA=useMemo(()=>attendance.filter(a=>`${a.nama||''} ${a.id_karyawan||''} ${a.status||''}`.toLowerCase().includes(search.toLowerCase())),[attendance,search]);
 const today=attendance.filter(a=>a.tanggal===isoToday());
 const present=today.filter(a=>['Hadir','Tepat Waktu','Terlambat'].includes(a.status||'')).length;
 const late=today.filter(a=>(a.status||'').toLowerCase().includes('terlambat')||Number(a.keterlambatan_menit)>0).length;
 const payroll=employees.reduce((s,k)=>s+Number(k.gaji_pokok||0),0);
 const activeLabel=menuGroups.flatMap(g=>g.items).find((x) => x[0] === menu)?.[1] || 'Overview';
 const exportCsv=(rows:Record<string,unknown>[],filename:string)=>{
  if(!rows.length){setToast('Tidak ada data untuk diekspor.');return}
  const keys=Object.keys(rows[0]);const esc=(v:unknown)=>`"${String(v??'').replace(/"/g,'""')}"`;
  const csv=[keys.join(';'),...rows.map(r=>keys.map(k=>esc(r[k])).join(';'))].join('\n');
  const a=document.createElement('a');a.href=URL.createObjectURL(new Blob(['\ufeff'+csv],{type:'text/csv;charset=utf-8'}));a.download=filename;a.click();URL.revokeObjectURL(a.href);
 };
 if(sessionChecking)return <div className="login-wrap"><div className="login-card"><div className="loading">Memeriksa sesi keamanan...</div></div></div>;
 if(!logged)return <Login email={email} pin={pin} setEmail={setEmail} setPin={setPin} onSubmit={login} loading={loading} error={error}/>;
 return <div className="talenta-shell">
  <aside className={`talenta-sidebar ${sidebar?'':'collapsed'}`}>
 <div className="brand">
  <div className="brand-mark"><img src={moonLogo} alt="MoonXprojecT" /></div>
  {sidebar && (
    <div>
      <b>MoonXprojecT</b>
      <small>Human Resources Platform</small>
    </div>
  )}
</div>

{sidebar && (
  <div className="workspace">
    <span>WORKSPACE</span>
    <b>MoonXprojecT</b>
    <small>HR Management</small>
  </div>
)}

<nav className="sidebar-nav">
  {menuGroups.map(g => (
    <div className="nav-group" key={g.title}>
      {g.items.some(([key]) => menuPermissionForRole(key, userRole, dbPerms)) && sidebar && (
        <button className="group-title" onClick={() => setOpen(v => ({ ...v, [g.title]: !v[g.title] }))}>
          <span>{g.title}</span>
          <span><Icon name={open[g.title] ? 'chevronDown' : 'chevronRight'}/></span>
        </button>
      )}
      {(sidebar ? open[g.title] : true) && g.items.filter(([key]) => menuPermissionForRole(key, userRole, dbPerms)).map(([key, label, icon]) => (
        <button 
          key={key} 
          className={`nav-item ${menu === key ? 'active' : ''}`} 
          onClick={() => navigate(key as MenuKey)} 
          title={label}
        >
          <span className="nav-icon"><Icon name={icon}/></span>
          {sidebar && <span>{label}</span>}
          {key === 'employees' && sidebar && <em>{employees.length}</em>}
        </button>
      ))}
    </div>
  ))}
</nav>
   <div className="sidebar-bottom"><div className="admin-mini"><div className="avatar">HR</div>{sidebar&&<div><b>{userRole||'User'}</b><small>MoonXprojecT Access</small></div>}</div><button className="logout" onClick={async()=>{await signOut();setLogged(false);setUserRole('');setDbPerms([]);setMenu('overview');location.hash='/home'}}><Icon name="logout"/>{sidebar&&'Keluar'}</button></div>
  </aside>
  <main className="talenta-main"><header className="topbar"><button className="icon-btn" aria-label="Buka menu" onClick={()=>setSidebar(v=>!v)}><Icon name="menu"/></button><div className="crumb"><span>MoonXprojecT</span><b>/</b>{activeLabel}</div><div className="top-actions"><div className="search-global"><span><Icon name="search"/></span><input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Cari data..."/></div><button className="icon-btn" aria-label="Muat ulang" onClick={()=>refresh()}><Icon name="refresh"/></button><div className="avatar">HR</div></div></header>
   <section className="page">{loading&&<div className="loading">Memuat data…</div>}{error&&<div className="alert">{error}</div>}
    {menu==='overview'&&<Overview employees={employees} attendance={attendance} present={present} late={late} payroll={payroll} onNavigate={navigate}/>}
    {menu==='employees'&&<Employees data={filtered} onDelete={removeEmployee} onEdit={setEditing} onExport={()=>exportCsv(employees as any,'database-karyawan.csv')} onAdd={()=>navigate('employee-add')} onConfirmEmail={confirmEmployeeEmail}/> }
    {menu==='employee-360'&&<Employee360 employees={employees}/>}
    {menu==='employee-add'&&<AddEmployee refresh={refresh} onDone={()=>navigate('employees')}/>} {menu==='hr-operations'&&<HRISCore employees={employees}/>} {menu==='production-hr'&&<ProductionHR employees={employees}/>} 
    {menu==='organization'&&<MasterData initialTab="cabang"/>}
    {['attendance','attendance-today','late','leave','overtime','selfie'].includes(menu)&&<AttendanceModule type={menu} data={filteredA} onRefresh={refresh} onExport={()=>exportCsv(attendance as any,'laporan-absensi.csv')}/>}
    {menu==='schedule'&&<MasterData initialTab="jadwal"/>}{menu==='shift'&&<MasterData initialTab="shift"/>}
    {menu==='holiday'&&<HolidayModule/>}
    {['leave-request','leave-balance'].includes(menu)&&<LeaveModule initial={menu}/>}
    {['payroll','payroll-components','payroll-overtime','payslip'].includes(menu)&&<PayrollEnterprise employees={employees}/>}
    {menu==='payroll-engine'&&<PayrollEngineV9/>}{menu==='payroll-production-v22'&&<PayrollProductionV22/>}{menu==='payroll-indonesia-v23'&&<PayrollIndonesiaV23/>}
    {['performance','kpi'].includes(menu)&&<TalentModule initial={menu} employees={employees}/>} {menu==='recruitment-v25'&&<RecruitmentATSv25/>} {menu.startsWith('enterprise-v')&&menu!=='enterprise-v20'&&<EnterpriseRoadmapV26V35 version={menu.replace('enterprise-','') as any}/>} {['recruitment','candidates'].includes(menu)&&<RecruitmentEnterprise/>}
    {menu==='reports'&&<Reports employees={employees} attendance={attendance} onExport={exportCsv}/>}
    {menu==='settings'&&<Settings/>}{menu==='roles'&&<RoleEditorEnterprise userRole={userRole}/>} {menu==='audit'&&<Audit/>}{menu==='approvals'&&<ApprovalCenter/>}{menu==='notifications'&&<Notifications/>} {menu==='system-health'&&<SystemHealth/>}{menu==='enterprise-v20'&&<EnterpriseV20 employees={employees}/>}{menu==='security-v21'&&<SecurityCenterV21/>} 
    {editing&&<EmployeeEditor employee={editing} onClose={()=>setEditing(null)} onSave={saveEdit}/>}
    {toast&&<button className="toast" onClick={()=>setToast('')}>{toast} ×</button>}
   </section></main>
 </div>
}

function Login(p:{email:string;pin:string;setEmail:(v:string)=>void;setPin:(v:string)=>void;onSubmit:(e:FormEvent)=>void;error:string;loading:boolean}){
 return <div className="login-wrap"><div className="login-card"><div className="brand center"><div className="brand-mark"><img src={moonLogo} alt="MoonXprojecT" /></div><div><b>MoonXprojecT</b><small>People Platform</small></div></div><h1>Selamat datang kembali</h1><p>Masuk ke dashboard HR & payroll.</p><form onSubmit={p.onSubmit}><label>Email<input value={p.email} onChange={e=>p.setEmail(e.target.value)} required/></label><label>PIN / Password<input type="password" value={p.pin} onChange={e=>p.setPin(e.target.value)} required/></label>{p.error&&<div className="form-error">{p.error}</div>}<button className="primary full" disabled={p.loading}>{p.loading?'Memeriksa…':'Masuk ke Dashboard'}</button></form><small className="security-note">Gunakan email dan password Supabase Auth yang diberikan HR.</small></div></div>
}
function Heading({title,desc,action,onAction}:{title:string;desc:string;action?:string;onAction?:()=>void}){return <div className="page-heading"><div><h1>{title}</h1><p>{desc}</p></div>{action&&<button className="primary" onClick={onAction}>{action}</button>}</div>}
function Overview({employees,attendance,present,late,payroll,onNavigate}:{employees:Karyawan[];attendance:Absensi[];present:number;late:number;payroll:number;onNavigate:(m:MenuKey)=>void}){
 const active=employees.filter(k=>k.status_aktif!==false).length;
 const inactive=Math.max(0,employees.length-active);
 const absent=Math.max(0,employees.length-present-late);
 const attendanceRate=employees.length?Math.min(100,Math.round((present/Math.max(1,employees.length))*100)):0;
 const recent=attendance.slice(0,6);
 const dept=employees.reduce<Record<string,number>>((a,k)=>{const d=k.departemen||'Belum diatur';a[d]=(a[d]||0)+1;return a},{});
 const deptRows=Object.entries(dept).sort((a,b)=>b[1]-a[1]).slice(0,5);
 const maxDept=Math.max(1,...deptRows.map(x=>x[1]));
 return <div className="executive-dashboard">
  <Heading title="HR Command Center" desc="Ringkasan workforce, attendance, dan payroll dalam satu pusat kendali." action="Tambah Karyawan" onAction={()=>onNavigate('employee-add')}/>
  <div className="command-strip">
   <div><span className="eyebrow">OPERATIONAL STATUS</span><strong>Sistem HR aktif</strong><small>Data tersinkron dari database</small></div>
   <div className="strip-meta"><span className="status green">Operational</span><span>Update otomatis saat halaman dimuat</span></div>
  </div>
  <div className="stat-grid executive-stats">
   <Stat title="Total Karyawan" value={String(employees.length)} hint={`${active} aktif · ${inactive} nonaktif`} icon="users"/>
   <Stat title="Kehadiran Hari Ini" value={`${attendanceRate}%`} hint={`${present} hadir · ${late} terlambat`} icon="check"/>
   <Stat title="Payroll Workforce" value={money(payroll)} hint="Total gaji pokok" icon="payroll"/>
   <Stat title="Record Absensi" value={String(attendance.length)} hint="Data tersimpan" icon="clock"/>
  </div>
  <div className="dashboard-grid-top">
   <div className="panel executive-chart">
    <div className="panel-head"><div><span className="eyebrow">WORKFORCE</span><h2>Komposisi Workforce</h2><p>Distribusi karyawan berdasarkan departemen.</p></div><button className="link-btn" onClick={()=>onNavigate('employees')}>Buka master</button></div>
    <div className="department-bars">{deptRows.length?deptRows.map(([name,count])=><div className="dept-row" key={name}><div className="dept-label"><span>{name}</span><b>{count}</b></div><div className="progress"><span style={{width:`${Math.round(count/maxDept*100)}%`}}/></div></div>):<div className="empty-module"><h3>Belum ada data workforce</h3><p>Tambahkan karyawan untuk melihat distribusi.</p></div>}</div>
   </div>
   <div className="panel attendance-health">
    <div className="panel-head"><div><span className="eyebrow">TODAY</span><h2>Attendance Health</h2><p>Status kehadiran hari ini.</p></div></div>
    <div className="health-ring" style={{'--rate':`${attendanceRate*3.6}deg`} as CSSProperties}><div><strong>{attendanceRate}%</strong><small>Hadir</small></div></div>
    <div className="health-legend"><div><i className="dot present"/><span>Hadir</span><b>{present}</b></div><div><i className="dot late"/><span>Terlambat</span><b>{late}</b></div><div><i className="dot absent"/><span>Belum tercatat</span><b>{absent}</b></div></div>
   </div>
  </div>
  <div className="dashboard-grid-bottom">
   <div className="panel"><div className="panel-head"><div><span className="eyebrow">LIVE FEED</span><h2>Aktivitas Absensi Terbaru</h2><p>Record terbaru yang masuk ke sistem.</p></div><button className="link-btn" onClick={()=>onNavigate('attendance')}>Lihat semua</button></div><AttendanceMini rows={recent}/></div>
   <div className="panel quick executive-quick"><div className="panel-head"><div><span className="eyebrow">SHORTCUTS</span><h2>Akses cepat</h2><p>Masuk langsung ke proses HR utama.</p></div></div><Quick label="Tambah karyawan" icon="users" onClick={()=>onNavigate('employee-add')}/><Quick label="Jadwal kerja" icon="calendar" onClick={()=>onNavigate('schedule')}/><Quick label="Payroll" icon="payroll" onClick={()=>onNavigate('payroll')}/><Quick label="Pengajuan cuti" icon="request" onClick={()=>onNavigate('leave-request')}/></div>
  </div>
 </div>
}
function Stat({title,value,hint,icon}:{title:string;value:string;hint:string;icon:string}){return <div className="stat-card"><div className="stat-icon"><Icon name={icon}/></div><div><span>{title}</span><strong>{value}</strong><small>{hint}</small></div></div>}
function Quick({label,icon,onClick}:{label:string;icon:string;onClick:()=>void}){return <button className="quick-action" onClick={onClick}><span className="quick-icon"><Icon name={icon}/></span>{label}<span aria-hidden="true">›</span></button>}
function AttendanceMini({rows}:{rows:Absensi[]}){return <div className="table-wrap"><table><thead><tr><th>Karyawan</th><th>Tanggal</th><th>Masuk</th><th>Pulang</th><th>Status</th></tr></thead><tbody>{rows.length?rows.map((a,i)=><tr key={a.id||i}><td><b>{a.nama||'-'}</b><small>{a.id_karyawan||''}</small></td><td>{a.tanggal||'-'}</td><td className="green">{a.jam_masuk||'-'}</td><td>{a.jam_pulang||'-'}</td><td><Status value={a.status||'Hadir'}/></td></tr>):<Empty cols={5}/>}</tbody></table></div>}

function Employees({data,onDelete,onEdit,onExport,onAdd,onConfirmEmail}:{data:Karyawan[];onDelete:(k:Karyawan)=>void;onEdit:(k:Karyawan)=>void;onExport:()=>void;onAdd:()=>void;onConfirmEmail:(k:Karyawan)=>void}){
 return <><Heading title="Semua Karyawan" desc="Master data workforce yang tersimpan di Supabase." action="Tambah Karyawan" onAction={onAdd}/><div className="toolbar"><b>{data.length} karyawan</b><button className="secondary" onClick={onExport}>Export CSV</button></div><div className="panel table-panel"><div className="table-wrap"><table><thead><tr><th>Nama</th><th>ID</th><th>Jabatan</th><th>Departemen</th><th>Status</th><th>Gaji Pokok</th><th>Aksi</th></tr></thead><tbody>{data.length?data.map(k=><tr key={k.id}><td><div className="person"><div className="mini-avatar">{k.nama?.[0]||'K'}</div><b>{k.nama}</b></div></td><td>{k.id_karyawan||'-'}</td><td>{k.jabatan||'-'}</td><td>{k.departemen||'-'}</td><td><Status value={k.status_aktif===false?'Nonaktif':'Aktif'}/></td><td>{money(Number(k.gaji_pokok||0))}</td><td>
  <div className="row-actions">
    <button
      className="link-btn"
      onClick={() => onEdit(k)}
    >
      Edit
    </button>

    {k.email && (
  <button
    className="link-btn"
    onClick={() => onConfirmEmail(k)}
    disabled={!k.auth_user_id || k.email_terverifikasi}
    title={
      k.email_terverifikasi
        ? 'Email sudah terverifikasi'
        : !k.auth_user_id
          ? 'Akun login belum terhubung'
          : 'Konfirmasi email'
    }
  >
    {k.email_terverifikasi
      ? '✓ Email Terverifikasi'
      : !k.auth_user_id
        ? 'Akun Belum Terhubung'
        : 'Konfirmasi Email'}
  </button>
)}
    <button
      className="danger-text"
      onClick={() => onDelete(k)}
    >
      Hapus
    </button>
  </div>
</td></tr>):<Empty cols={7}/>}</tbody></table></div></div></>
}
function AddEmployee({onDone,refresh}:{onDone:()=>void;refresh:()=>void}){
 const [f,setF]=useState({id_karyawan:'',nama:'',jabatan:'',email:'',no_telp:'',departemen:'',tanggal_masuk:'',gaji_pokok:''}),[saving,setSaving]=useState(false),[msg,setMsg]=useState('');
 async function save(e:FormEvent){e.preventDefault();setSaving(true);setMsg('');const payload={...f,gaji_pokok:Number(f.gaji_pokok||0),status_aktif:true};const {error:e2}=await supabase.from('karyawan').insert(payload);setSaving(false);if(e2)setMsg(e2.message);else{refresh();onDone()}}
 return <><Heading title="Tambah Karyawan" desc="Simpan profil baru langsung ke tabel karyawan."/><div className="panel form-panel"><form className="form-grid" onSubmit={save}>{Object.entries(f).map(([k,v])=><label key={k}>{fieldLabel(k)}<input required={['id_karyawan','nama'].includes(k)} type={k==='gaji_pokok'?'number':k==='tanggal_masuk'?'date':'text'} value={String(v ?? '')} onChange={e=>setF({...f,[k]:e.target.value})}/></label>)}{msg&&<div className="form-error full-span">{msg}</div>}<div className="full-span form-actions"><button type="button" className="secondary" onClick={onDone}>Batal</button><button className="primary" disabled={saving}>{saving?'Menyimpan…':'Simpan Karyawan'}</button></div></form></div></>
}
function EmployeeEditor({employee,onClose,onSave}:{employee:Karyawan;onClose:()=>void;onSave:(p:Record<string,unknown>)=>void}){
 const [f,setF]=useState({nama:employee.nama||'',jabatan:employee.jabatan||'',email:employee.email||'',no_telp:employee.no_telp||'',departemen:employee.departemen||'',tanggal_masuk:employee.tanggal_masuk||'',gaji_pokok:String(employee.gaji_pokok||0),status_aktif:employee.status_aktif!==false});
 return <div className="drawer-backdrop" onMouseDown={e=>{if(e.currentTarget===e.target)onClose()}}><aside className="edit-drawer"><div className="drawer-head"><div><span>EMPLOYEE PROFILE</span><h2>Edit Karyawan</h2></div><button className="icon-btn" onClick={onClose}>×</button></div><div className="drawer-body">{Object.entries(f).filter(([k])=>k!=='status_aktif').map(([k,v])=><label key={k}>{fieldLabel(k)}<input type={k==='gaji_pokok'?'number':k==='tanggal_masuk'?'date':'text'} value={String(v ?? '')} onChange={e=>setF({...f,[k]:e.target.value})}/></label>)}<label className="switch-row"><span>Status Aktif</span><input type="checkbox" checked={f.status_aktif} onChange={e=>setF({...f,status_aktif:e.target.checked})}/></label></div><div className="drawer-foot"><button className="secondary" onClick={onClose}>Batal</button><button className="primary" onClick={()=>onSave({...f,gaji_pokok:Number(f.gaji_pokok||0)})}>Simpan Perubahan</button></div></aside></div>
}

function Branch({title,desc,items,tab,setTab,action,onAction,children}:{title:string;desc:string;items:{key:string;label:string;icon:string}[];tab:string;setTab:(v:string)=>void;action?:string;onAction?:()=>void;children:ReactNode}){return <><Heading title={title} desc={desc} action={action} onAction={onAction}/><div className="branch-nav">{items.map(i=><button key={i.key} className={tab===i.key?'active':''} onClick={()=>setTab(i.key)}><span>{i.icon}</span>{i.label}</button>)}</div>{children}</>}
function AttendanceModule({type,data,onRefresh,onExport}:{type:MenuKey;data:Absensi[];onRefresh:()=>void;onExport:()=>void}){
 const initial=type==='attendance-today'?'today':type==='late'?'late':type==='leave'?'leave':type==='overtime'?'overtime':type==='selfie'?'selfie':'summary';
 const [tab,setTab]=useState(initial),[open,setOpen]=useState(false),[employees,setEmployees]=useState<Karyawan[]>([]);
 const [f,setF]=useState({id_karyawan:'',tanggal:isoToday(),jam_masuk:'07:00',jam_pulang:'16:00',status:'Hadir',lokasi:'Manual HR',keterangan:''});
 useEffect(()=>{supabase.from('karyawan').select('*').order('nama').then(({data})=>setEmployees(data||[]))},[]);
 const items=[['summary','Rekap','clock'],['today','Hari Ini','check'],['late','Terlambat','alert'],['leave','Izin & Sakit','leave'],['overtime','Lembur','arrow'],['selfie','Monitoring Selfie','camera']];
 let rows=data;if(tab==='today')rows=data.filter(a=>a.tanggal===isoToday());if(tab==='late')rows=data.filter(a=>Number(a.keterlambatan_menit||0)>0||(a.status||'').toLowerCase().includes('terlambat'));if(tab==='leave')rows=data.filter(a=>/izin|sakit/i.test(a.status||''));if(tab==='overtime')rows=data.filter(a=>Number(a.lembur_menit||0)>0);if(tab==='selfie')rows=data.filter(a=>!!a.foto||!!a.selfie_masuk);
 const save=async(e:FormEvent)=>{e.preventDefault();const emp=employees.find(x=>x.id_karyawan===f.id_karyawan);if(!emp)return alert('Pilih karyawan.');const {error}=await supabase.from('absensi').insert({...f,nama:emp.nama,jabatan:emp.jabatan||'',total_jam:'8:00'});if(error)alert(error.message);else{setOpen(false);onRefresh()}};
 const del=async(id:string)=>{if(confirm('Hapus record absensi ini?')){const {error}=await supabase.from('absensi').delete().eq('id',id);if(error)alert(error.message);else onRefresh()}};
 return <Branch title="Absensi" desc="Rekap, input manual, review keterlambatan, lembur, dan selfie." items={items.map(([key,label,icon])=>({key,label,icon}))} tab={tab} setTab={setTab} action={tab==='summary'?'＋ Input Absensi': 'Export CSV'} onAction={tab==='summary'?()=>setOpen(true):onExport}>
  <div className="stat-grid three"><Stat title="Record" value={String(rows.length)} hint="Data ditampilkan" icon="calendar"/><Stat title="Hadir" value={String(rows.filter(a=>/hadir|tepat|terlambat/i.test(a.status||'')).length)} hint="Kehadiran" icon="check"/><Stat title="Perlu Review" value={String(rows.filter(a=>Number(a.lembur_menit||0)>0||Number(a.keterlambatan_menit||0)>0).length)} hint="Lembur / terlambat" icon="alert"/></div>
  <div className="panel table-panel"><div className="table-wrap"><table><thead><tr><th>Foto</th><th>Karyawan</th><th>Tanggal</th><th>Masuk</th><th>Pulang</th><th>Total</th><th>Status</th><th>Lokasi</th><th>Aksi</th></tr></thead><tbody>{rows.length?rows.map((a,i)=><tr key={a.id||i}><td>{a.foto||a.selfie_masuk?<img className="selfie" src={a.foto||a.selfie_masuk}/>:<div className="selfie blank">—</div>}</td><td><b>{a.nama||'-'}</b><small>{a.id_karyawan||''}</small></td><td>{a.tanggal||'-'}</td><td>{a.jam_masuk||'-'}</td><td>{a.jam_pulang||'-'}</td><td>{a.total_jam||'-'}</td><td><Status value={a.status||'-'}/></td><td>{a.lokasi||a.lokasi_masuk||'-'}</td><td>{a.id&&<button className="danger-text" onClick={()=>del(a.id)}>Hapus</button>}</td></tr>):<Empty cols={9}/>}</tbody></table></div></div>
  {open&&<SimpleModal title="Input Absensi Manual" onClose={()=>setOpen(false)} onSave={save}><label>Karyawan<select required value={f.id_karyawan} onChange={e=>setF({...f,id_karyawan:e.target.value})}><option value="">Pilih karyawan</option>{employees.map(k=><option key={k.id_karyawan} value={k.id_karyawan}>{k.nama} — {k.id_karyawan}</option>)}</select></label><label>Tanggal<input type="date" value={f.tanggal} onChange={e=>setF({...f,tanggal:e.target.value})}/></label><label>Jam Masuk<input type="time" value={f.jam_masuk} onChange={e=>setF({...f,jam_masuk:e.target.value})}/></label><label>Jam Pulang<input type="time" value={f.jam_pulang} onChange={e=>setF({...f,jam_pulang:e.target.value})}/></label><label>Status<select value={f.status} onChange={e=>setF({...f,status:e.target.value})}><option>Hadir</option><option>Terlambat</option><option>Izin</option><option>Sakit</option><option>Alpa</option></select></label><label>Lokasi<input value={f.lokasi} onChange={e=>setF({...f,lokasi:e.target.value})}/></label><label>Keterangan<textarea value={f.keterangan} onChange={e=>setF({...f,keterangan:e.target.value})}/></label></SimpleModal>}
 </Branch>
}

function HolidayModule(){
 const [rows,setRows]=useState<any[]>([]),[modal,setModal]=useState(false),[f,setF]=useState({tanggal:isoToday(),nama:'',tipe:'Nasional'}),[msg,setMsg]=useState('');
 const load=async()=>{const {data,error}=await supabase.from('hris_hari_libur').select('*').order('tanggal');if(error)setMsg(error.message);else setRows(data||[])};useEffect(()=>{load()},[]);
 const save=async(e:FormEvent)=>{e.preventDefault();const {error}=await supabase.from('hris_hari_libur').insert(f);if(error)setMsg(error.message);else{setModal(false);setF({tanggal:isoToday(),nama:'',tipe:'Nasional'});load()}};
 const del=async(id:string)=>{if(confirm('Hapus hari libur?')){const {error}=await supabase.from('hris_hari_libur').delete().eq('id',id);if(error)setMsg(error.message);else load()}};
 return <><Heading title="Hari Libur" desc="Kelola tanggal non-working day di database." action="＋ Tambah Hari Libur" onAction={()=>setModal(true)}/>{msg&&<div className="alert">{msg}</div>}<div className="panel table-panel"><div className="table-wrap"><table><thead><tr><th>Tanggal</th><th>Nama</th><th>Tipe</th><th>Aksi</th></tr></thead><tbody>{rows.length?rows.map(r=><tr key={r.id}><td>{r.tanggal}</td><td><b>{r.nama}</b></td><td><Status value={r.tipe}/></td><td><button className="danger-text" onClick={()=>del(r.id)}>Hapus</button></td></tr>):<Empty cols={4}/>}</tbody></table></div></div>{modal&&<SimpleModal title="Tambah Hari Libur" onClose={()=>setModal(false)} onSave={save}><label>Tanggal<input type="date" value={f.tanggal} onChange={e=>setF({...f,tanggal:e.target.value})}/></label><label>Nama Hari Libur<input required value={f.nama} onChange={e=>setF({...f,nama:e.target.value})}/></label><label>Tipe<select value={f.tipe} onChange={e=>setF({...f,tipe:e.target.value})}><option>Nasional</option><option>Perusahaan</option></select></label></SimpleModal>}</>
}

function LeaveModule({initial}:{initial:MenuKey}){
 const [tab,setTab]=useState(initial==='leave-balance'?'balance':'requests'),[rows,setRows]=useState<any[]>([]),[balances,setBalances]=useState<any[]>([]),[modal,setModal]=useState(false),[employees,setEmployees]=useState<Karyawan[]>([]);
 const [f,setF]=useState({id_karyawan:'',jenis:'Tahunan',tanggal_mulai:isoToday(),tanggal_selesai:isoToday(),jumlah_hari:'1',alasan:'',status:'Menunggu'});
 const load=async()=>{const [a,b,c]=await Promise.all([supabase.from('hris_cuti').select('*').order('created_at',{ascending:false}),supabase.from('hris_saldo_cuti').select('*').eq('tahun',new Date().getFullYear()),supabase.from('karyawan').select('*').order('nama')]);if(!a.error)setRows(a.data||[]);if(!b.error)setBalances(b.data||[]);if(!c.error)setEmployees(c.data||[])};useEffect(()=>{load()},[]);
 const save=async(e:FormEvent)=>{e.preventDefault();const {data,error}=await supabase.from('hris_cuti').insert({...f,jumlah_hari:Number(f.jumlah_hari)}).select('id').single();if(error){alert(error.message);return}if(data){const a=await supabase.rpc('hris_submit_approval',{p_modul:'leave',p_record_id:String(data.id)});if(a.error){await supabase.from('hris_cuti').delete().eq('id',data.id);alert(a.error.message);return}}setModal(false);load()};
 const update=async(id:string,status:string)=>{const {data:req,error:e1}=await supabase.from('hris_approval_requests').select('id').eq('modul','leave').eq('record_id',id).eq('status','Menunggu').maybeSingle();if(e1||!req){alert(e1?.message||'Workflow approval tidak ditemukan.');return}const {error}=await supabase.rpc('hris_decide_approval',{p_id:req.id,p_status:status,p_catatan:status==='Ditolak'?(window.prompt('Alasan penolakan:','')||null):null});if(error)alert(error.message);else load()};
 const ensureBalance=async(k:string)=>{const found=balances.find(x=>x.id_karyawan===k);if(found)return found;const {data,error}=await supabase.from('hris_saldo_cuti').insert({id_karyawan:k,tahun:new Date().getFullYear(),jenis:'Tahunan',saldo:12,terpakai:0}).select().single();if(error) return null;return data};
 const items=[['inbox','Approval Inbox','request'],['requests','Pengajuan Baru','＋'],['history','Riwayat','calendar'],['balance','Saldo Cuti','balance']].map(([key,label,icon])=>({key,label,icon}));
 return <Branch title="Cuti" desc="Pengajuan, approval, dan saldo cuti tersimpan di database." items={items} tab={tab} setTab={setTab} action={tab==='requests'?'＋ Buat Pengajuan':undefined} onAction={()=>setModal(true)}>{tab==='balance'?<div className="panel table-panel"><div className="table-wrap"><table><thead><tr><th>Karyawan</th><th>Jenis</th><th>Jatah</th><th>Terpakai</th><th>Sisa</th><th>Aksi</th></tr></thead><tbody>{employees.map(k=>{const b=balances.find(x=>x.id_karyawan===k.id_karyawan);const quota=Number((b?.saldo??12))+Number(b?.terpakai??0);const used=Number(b?.terpakai??0);return <tr key={k.id}><td><b>{k.nama}</b><small>{k.id_karyawan}</small></td><td>Tahunan</td><td>{quota}</td><td>{used}</td><td><Status value={String(Math.max(0,quota-used))}/></td><td><button className="link-btn" onClick={()=>k.id_karyawan && ensureBalance(k.id_karyawan).then(load)}>Inisialisasi</button></td></tr>})}</tbody></table></div></div>:<div className="panel table-panel"><div className="table-wrap"><table><thead><tr><th>Karyawan</th><th>Jenis</th><th>Tanggal</th><th>Alasan</th><th>Status</th><th>Aksi</th></tr></thead><tbody>{rows.length?rows.map(r=><tr key={r.id}><td>{r.id_karyawan}</td><td>{r.jenis}</td><td>{r.tanggal_mulai} s/d {r.tanggal_selesai}</td><td>{r.alasan||'-'}</td><td><Status value={r.status}/></td><td>{r.status==='Menunggu'&&<><button className="link-btn" onClick={()=>update(r.id,'Disetujui')}>Setujui</button> <button className="danger-text" onClick={()=>update(r.id,'Ditolak')}>Tolak</button></>}</td></tr>):<Empty cols={6}/>}</tbody></table></div></div>}{modal&&<SimpleModal title="Pengajuan Cuti" onClose={()=>setModal(false)} onSave={save}><label>Karyawan<select required value={f.id_karyawan} onChange={e=>setF({...f,id_karyawan:e.target.value})}><option value="">Pilih karyawan</option>{employees.map(k=><option key={k.id_karyawan} value={k.id_karyawan}>{k.nama} — {k.id_karyawan}</option>)}</select></label><label>Jenis<select value={f.jenis} onChange={e=>setF({...f,jenis:e.target.value})}><option>Tahunan</option><option>Sakit</option><option>Khusus</option></select></label><label>Mulai<input type="date" value={f.tanggal_mulai} onChange={e=>setF({...f,tanggal_mulai:e.target.value})}/></label><label>Selesai<input type="date" value={f.tanggal_selesai} onChange={e=>setF({...f,tanggal_selesai:e.target.value})}/></label><label>Jumlah Hari<input type="number" min="0.5" step="0.5" value={f.jumlah_hari} onChange={e=>setF({...f,jumlah_hari:e.target.value})}/></label><label>Alasan<textarea value={f.alasan} onChange={e=>setF({...f,alasan:e.target.value})}/></label></SimpleModal>}</Branch>
}

function TalentModule({initial,employees}:{initial:MenuKey;employees:Karyawan[]}){
 const [tab,setTab]=useState(initial==='kpi'?'kpi':initial==='recruitment'?'vacancies':initial==='candidates'?'candidates':'performance'),[rows,setRows]=useState<any[]>([]),[modal,setModal]=useState(false);
 const load=async()=>{const table=tab==='kpi'?'hris_kpi':tab==='vacancies'?'hris_lowongan':tab==='candidates'?'hris_kandidat':tab==='interviews'?'hris_interview':'hris_performance';const {data,error}=await supabase.from(table).select('*').order('created_at',{ascending:false});if(!error)setRows(data||[]);else setRows([])};useEffect(()=>{load()},[tab]);
 const items=[['performance','Performance','arrow'],['kpi','KPI & Target','kpi'],['vacancies','Lowongan','recruitment'],['candidates','Kandidat','users'],['interviews','Interview','calendar']];
 return <Branch title="Talent" desc="Performance, KPI, recruitment, kandidat, dan interview dengan data persisten." items={items.map(([key,label,icon])=>({key,label,icon}))} tab={tab} setTab={setTab} action="＋ Tambah" onAction={()=>setModal(true)}>{<TalentTable tab={tab} rows={rows}/>} {modal&&<TalentForm tab={tab} employees={employees} onClose={()=>setModal(false)} onSaved={()=>{setModal(false);load()}}/>}</Branch>
}
function TalentTable({tab,rows}:{tab:string;rows:any[]}){let cols:string[]=[];if(tab==='kpi')cols=['id_karyawan','periode','indikator','target','realisasi','skor','status'];else if(tab==='vacancies')cols=['posisi','departemen','jumlah_kebutuhan','status','tanggal_buka','tanggal_tutup'];else if(tab==='candidates')cols=['nama','email','no_telp','posisi','tahap','status'];else if(tab==='interviews')cols=['kandidat','tanggal','jam','interviewer','hasil','status'];else cols=['id_karyawan','periode','nilai','catatan','status'];return <div className="panel table-panel"><div className="table-wrap"><table><thead><tr>{cols.map(c=><th key={c}>{fieldLabel(c)}</th>)}</tr></thead><tbody>{rows.length?rows.map(r=><tr key={r.id}>{cols.map(c=><td key={c}>{c==='status'?<Status value={String(r[c]??'-')}/>:String(r[c]??'-')}</td>)}</tr>):<Empty cols={cols.length}/>}</tbody></table></div></div>}
function TalentForm({tab,employees,onClose,onSaved}:{tab:string;employees:Karyawan[];onClose:()=>void;onSaved:()=>void}){
 const [f,setF]=useState<any>(tab==='kpi'?{id_karyawan:'',periode:new Date().toISOString().slice(0,7),indikator:'',target:'',realisasi:'',bobot:'0',skor:'0',status:'Draft'}:tab==='vacancies'?{posisi:'',departemen:'',jumlah_kebutuhan:'1',status:'Open',tanggal_buka:isoToday(),tanggal_tutup:'',deskripsi:''}:tab==='candidates'?{nama:'',email:'',no_telp:'',posisi:'',sumber:'',tahap:'Screening',status:'Aktif',catatan:''}:tab==='interviews'?{kandidat:'',tanggal:isoToday(),jam:'09:00',interviewer:'',hasil:'',status:'Terjadwal'}:{id_karyawan:'',periode:new Date().toISOString().slice(0,7),nilai:'0',catatan:'',status:'Draft'});
 const table=tab==='kpi'?'hris_kpi':tab==='vacancies'?'hris_lowongan':tab==='candidates'?'hris_kandidat':tab==='interviews'?'hris_interview':'hris_performance';
 const save=async(e:FormEvent)=>{e.preventDefault();const numeric=['target','realisasi','bobot','skor','jumlah_kebutuhan','nilai'];const payload={...f};numeric.forEach(k=>{if(k in payload)payload[k]=Number(payload[k]||0)});const {error}=await supabase.from(table).insert(payload);if(error)alert(error.message);else onSaved()};
 return <SimpleModal title={`Tambah ${tab==='kpi'?'KPI':tab==='vacancies'?'Lowongan':tab==='candidates'?'Kandidat':tab==='interviews'?'Interview':'Performance'}`} onClose={onClose} onSave={save}>{Object.entries(f).map(([k,v])=><label key={k}>{fieldLabel(k)}{k==='id_karyawan'?<select required value={String(v)} onChange={e=>setF({...f,[k]:e.target.value})}><option value="">Pilih karyawan</option>{employees.map(x=><option key={x.id_karyawan} value={x.id_karyawan}>{x.nama} — {x.id_karyawan}</option>)}</select>:<input required={['nama','posisi','indikator','kandidat'].includes(k)} type={['target','realisasi','bobot','skor','jumlah_kebutuhan','nilai'].includes(k)?'number':k==='tanggal'||k.includes('tanggal')?'date':k==='jam'?'time':'text'} value={String(v??'')} onChange={e=>setF({...f,[k]:e.target.value})}/>}</label>)}</SimpleModal>
}
function Reports({employees,attendance,onExport}:{employees:Karyawan[];attendance:Absensi[];onExport:(r:any[],f:string)=>void}){const [tab,setTab]=useState('overview'),[payroll,setPayroll]=useState<any[]>([]);useEffect(()=>{if(tab==='payroll')supabase.from('hris_payroll').select('*').order('created_at',{ascending:false}).limit(2000).then(({data})=>setPayroll(data||[]))},[tab]);const items=[['overview','Analytics','report'],['attendance','Laporan Absensi','clock'],['payroll','Laporan Payroll','payroll'],['people','Laporan Karyawan','users']].map(([key,label,icon])=>({key,label,icon}));return <Branch title="Laporan" desc="Export data nyata dari database." items={items} tab={tab} setTab={setTab}>{tab==='overview'?<div className="report-grid"><ReportCard name="Master Karyawan" count={employees.length} onClick={()=>onExport(employees,'laporan-karyawan.csv')}/><ReportCard name="Absensi" count={attendance.length} onClick={()=>onExport(attendance,'laporan-absensi.csv')}/><ReportCard name="Payroll" count={payroll.length} onClick={()=>onExport(payroll,'laporan-payroll.csv')}/></div>:tab==='attendance'?<ReportCard name="Laporan Absensi" count={attendance.length} onClick={()=>onExport(attendance,'laporan-absensi.csv')}/>:tab==='people'?<ReportCard name="Laporan Karyawan" count={employees.length} onClick={()=>onExport(employees,'laporan-karyawan.csv')}/>:<ReportCard name="Laporan Payroll" count={payroll.length} onClick={()=>onExport(payroll,'laporan-payroll.csv')}/>}</Branch>}
function ReportCard({name,count,onClick}:{name:string;count:number;onClick:()=>void}){return <div className="report-card"><span>REPORT</span><h3>{name}</h3><b>{count}</b><p>record tersedia</p><button className="primary" onClick={onClick}>Export CSV</button></div>}
function Settings(){
  const [f,setF]=useState<any>({
    company_name:'MoonXprojecT',
    work_start:'07:00',
    work_end:'16:00',
    break_minutes:60,
    payday_day:'Jumat',
    currency:'IDR',
    timezone:'Asia/Jakarta',
    overtime_multiplier:2,
    late_tolerance_minutes:10,
    attendance_radius_meters:100,
    auto_approve_attendance:false,
    notify_late:true,
    notify_leave:true,
    maintenance_mode:false
  });

  const [tab,setTab]=useState('Perusahaan');
  const [msg,setMsg]=useState('');

  const [customTheme,setCustomTheme]=useState({
    primary:'#101a33',
    accent:'#d6ae58',
    background:'#f6f7fb',
    surface:'#ffffff',
    text:'#172033',
    border:'#d6ae58'
  });

  const themes=[
    {
      id:'moon',
      name:'MoonXprojecT — Navy Gold',
      description:'Tema utama enterprise MoonXprojecT.',
      primary:'#101a33',
      accent:'#d6ae58',
      background:'#f6f7fb',
      surface:'#ffffff',
      text:'#172033',
      border:'#d6ae58'
    },
    {
      id:'blue',
      name:'Corporate Blue',
      description:'Tampilan profesional biru korporat.',
      primary:'#123b63',
      accent:'#2f80ed',
      background:'#f4f7fb',
      surface:'#ffffff',
      text:'#172033',
      border:'#b8cee5'
    },
    {
      id:'green',
      name:'Professional Green',
      description:'Tema untuk operasional dan workforce.',
      primary:'#174d3b',
      accent:'#2e9d68',
      background:'#f4f8f6',
      surface:'#ffffff',
      text:'#172033',
      border:'#a9d7c0'
    },
    {
      id:'purple',
      name:'Modern Purple',
      description:'Tema modern untuk HR dan talent.',
      primary:'#3b2a63',
      accent:'#7c3aed',
      background:'#f7f5fb',
      surface:'#ffffff',
      text:'#172033',
      border:'#c8b8e8'
    },
    {
      id:'dark',
      name:'Dark Enterprise',
      description:'Mode gelap untuk penggunaan malam.',
      primary:'#0b132b',
      accent:'#d6ae58',
      background:'#101827',
      surface:'#172033',
      text:'#f8fafc',
      border:'#334155'
    },
    {
      id:'light',
      name:'Light Enterprise',
      description:'Tampilan terang dan minimalis.',
      primary:'#1f2937',
      accent:'#2563eb',
      background:'#f8fafc',
      surface:'#ffffff',
      text:'#111827',
      border:'#dbe3ee'
    }
  ];

  const applyTheme = (theme: any) => {
  const root = document.documentElement;

  const primary =
    theme.primary || '#101a33';

  const accent =
    theme.accent || '#d6ae58';

  const background =
    theme.background || '#f6f7fb';

  const surface =
    theme.surface || '#ffffff';

  const text =
    theme.text || '#172033';

  const border =
    theme.border || accent;

  root.style.setProperty(
    '--mx-primary',
    primary
  );

  root.style.setProperty(
    '--mx-accent',
    accent
  );

  root.style.setProperty(
    '--mx-background',
    background
  );

  root.style.setProperty(
    '--mx-surface',
    surface
  );

  root.style.setProperty(
    '--mx-text',
    text
  );

  root.style.setProperty(
    '--mx-border',
    border
  );

  /*
   * Compatibility dengan CSS lama
   */
  root.style.setProperty(
    '--blue',
    accent
  );

  root.style.setProperty(
    '--blue2',
    primary
  );

  root.style.setProperty(
    '--blue-soft',
    background
  );

  root.style.setProperty(
    '--ink',
    text
  );

  root.style.setProperty(
    '--line',
    border
  );

  root.style.setProperty(
    '--surface',
    surface
  );

  root.style.setProperty(
    '--bg',
    background
  );

  setCustomTheme({
    primary,
    accent,
    background,
    surface,
    text,
    border,
  });

  localStorage.setItem(
    'moonx-theme',
    JSON.stringify({
      ...theme,
      primary,
      accent,
      background,
      surface,
      text,
      border,
    })
  );

  setMsg(
    `Tema "${theme.name || 'Custom Theme'}" berhasil diterapkan.`
  );
};
  const updateCustomColor = (
  key: keyof typeof customTheme,
  value: string
) => {
  setCustomTheme(prev => ({
    ...prev,
    [key]: value,
  }));

  const root =
    document.documentElement;

  const map: Record<
    keyof typeof customTheme,
    string
  > = {
    primary: '--mx-primary',
    accent: '--mx-accent',
    background: '--mx-background',
    surface: '--mx-surface',
    text: '--mx-text',
    border: '--mx-border',
  };

  root.style.setProperty(
    map[key],
    value
  );

  /*
   * CSS lama
   */
  if (key === 'primary') {
    root.style.setProperty(
      '--blue2',
      value
    );
  }

  if (key === 'accent') {
    root.style.setProperty(
      '--blue',
      value
    );
  }

  if (key === 'background') {
    root.style.setProperty(
      '--bg',
      value
    );
  }

  if (key === 'surface') {
    root.style.setProperty(
      '--surface',
      value
    );
  }

  if (key === 'text') {
    root.style.setProperty(
      '--ink',
      value
    );
  }

  if (key === 'border') {
    root.style.setProperty(
      '--line',
      value
    );
  }
};
  useEffect(()=>{
    supabase
      .from('hris_company_settings')
      .select('*')
      .eq('id',1)
      .maybeSingle()
      .then(({data})=>{
        if(data)setF(data);
      });

    const saved=localStorage.getItem('moonx-theme');

    if(saved){
      try{
        const theme=JSON.parse(saved);

        applyTheme(theme);
      }catch{
        applyTheme(themes[0]);
      }
    }else{
      applyTheme(themes[0]);
    }
  },[]);

  const save=async()=>{
    const {error}=await supabase
      .from('hris_company_settings')
      .upsert({
        ...f,
        id:1
      });

    setMsg(
      error
        ? error.message
        : 'Pengaturan berhasil disimpan.'
    );
  };

const saveCustomTheme = () => {
  const theme = {
    id: 'custom',
    name: 'Custom Theme',
    description:
      'Tema kustom MoonXprojecT',
    ...customTheme,
  };

  const root =
    document.documentElement;

  root.style.setProperty(
    '--mx-primary',
    customTheme.primary
  );

  root.style.setProperty(
    '--mx-accent',
    customTheme.accent
  );

  root.style.setProperty(
    '--mx-background',
    customTheme.background
  );

  root.style.setProperty(
    '--mx-surface',
    customTheme.surface
  );

  root.style.setProperty(
    '--mx-text',
    customTheme.text
  );

  root.style.setProperty(
    '--mx-border',
    customTheme.border
  );

  root.style.setProperty(
    '--blue',
    customTheme.accent
  );

  root.style.setProperty(
    '--blue2',
    customTheme.primary
  );

  root.style.setProperty(
    '--blue-soft',
    customTheme.background
  );

  root.style.setProperty(
    '--ink',
    customTheme.text
  );

  root.style.setProperty(
    '--line',
    customTheme.border
  );

  root.style.setProperty(
    '--surface',
    customTheme.surface
  );

  root.style.setProperty(
    '--bg',
    customTheme.background
  );

  localStorage.setItem(
    'moonx-theme',
    JSON.stringify(theme)
  );

  setMsg(
    'Custom Theme berhasil disimpan dan diterapkan.'
  );
};
  const groups:any={
    'Perusahaan':[
      'company_name',
      'currency',
      'timezone'
    ],
    'Jam Kerja':[
      'work_start',
      'work_end',
      'break_minutes',
      'late_tolerance_minutes'
    ],
    'Payroll':[
      'payday_day',
      'overtime_multiplier'
    ],
    'Absensi':[
      'attendance_radius_meters',
      'auto_approve_attendance'
    ],
    'Notifikasi':[
      'notify_late',
      'notify_leave'
    ],
    'Keamanan':[
      'maintenance_mode'
    ]
  };

  const labels:any={
    company_name:'Nama Perusahaan',
    currency:'Mata Uang',
    timezone:'Zona Waktu',
    work_start:'Jam Masuk',
    work_end:'Jam Pulang',
    break_minutes:'Istirahat (menit)',
    late_tolerance_minutes:'Toleransi Terlambat (menit)',
    payday_day:'Hari Gajian',
    overtime_multiplier:'Pengali Lembur',
    attendance_radius_meters:'Radius Absensi (meter)',
    auto_approve_attendance:'Auto Approve Absensi',
    notify_late:'Notifikasi Keterlambatan',
    notify_leave:'Notifikasi Cuti',
    maintenance_mode:'Mode Maintenance'
  };

  return (
    <>
      <Heading
        title="Pengaturan"
        desc="Kelola konfigurasi perusahaan, operasional, payroll, absensi, keamanan, dan tampilan sistem."
        action="Simpan Perubahan"
        onAction={save}
      />

      {msg&&(
        <div className="theme-message">
          {msg}
        </div>
      )}

      <div className="settings-tabs">
        {Object.keys(groups).map(x=>(
          <button
            key={x}
            type="button"
            className={tab===x?'active':''}
            onClick={()=>setTab(x)}
          >
            {x}
          </button>
        ))}

        <button
          type="button"
          className={tab==='Tampilan & Tema'?'active':''}
          onClick={()=>setTab('Tampilan & Tema')}
        >
          🎨 Tampilan & Tema
        </button>
      </div>

      {tab==='Tampilan & Tema' ? (
        <div className="theme-manager">

          <div className="theme-manager-header">
            <div>
              <h2>Tampilan & Tema</h2>
              <p>
                Pilih tampilan visual yang digunakan oleh HRIS MoonXprojecT.
              </p>
            </div>
          </div>

          <div className="theme-grid">
            {themes.map(theme=>(
              <button
                type="button"
                key={theme.id}
                className="theme-card"
                onClick={()=>applyTheme(theme)}
              >
                <div
                  className="theme-preview"
                  style={{
                    background:theme.background
                  }}
                >
                  <div
                    className="theme-preview-sidebar"
                    style={{
                      background:theme.primary
                    }}
                  >
                    <span></span>
                    <span></span>
                    <span></span>
                    <span></span>
                  </div>

                  <div className="theme-preview-content">

                    <div
                      className="theme-preview-top"
                      style={{
                        borderColor:theme.border
                      }}
                    ></div>

                    <div className="theme-preview-cards">
                      <i
                        style={{
                          background:theme.accent
                        }}
                      ></i>

                      <i
                        style={{
                          background:theme.primary
                        }}
                      ></i>

                      <i
                        style={{
                          background:theme.border
                        }}
                      ></i>
                    </div>

                    <div
                      className="theme-preview-line"
                      style={{
                        background:theme.accent
                      }}
                    ></div>

                  </div>
                </div>

                <div className="theme-card-body">
                  <div>
                    <strong>
                      {theme.name}
                    </strong>

                    <small>
                      {theme.description}
                    </small>
                  </div>

                  <span
                    className="theme-color-dot"
                    style={{
                      background:theme.accent
                    }}
                  ></span>
                </div>
              </button>
            ))}
          </div>

          <div className="custom-theme-panel">

            <div>
              <h3>Custom Theme</h3>
              <p>
                Gunakan warna pilihan Anda untuk tampilan HRIS.
              </p>
            </div>

            <div className="custom-theme-controls">

              <label>
                Primary
                <input
                  type="color"
                  value={customTheme.primary}
                  onChange={e=>
                    updateCustomColor(
                      'primary',
                      e.target.value
                    )
                  }
                />
              </label>

              <label>
                Accent
                <input
                  type="color"
                  value={customTheme.accent}
                  onChange={e=>
                    updateCustomColor(
                      'accent',
                      e.target.value
                    )
                  }
                />
              </label>

              <label>
                Background
                <input
                  type="color"
                  value={customTheme.background}
                  onChange={e=>
                    updateCustomColor(
                      'background',
                      e.target.value
                    )
                  }
                />
              </label>

              <label>
                Surface
                <input
                  type="color"
                  value={customTheme.surface}
                  onChange={e=>
                    updateCustomColor(
                      'surface',
                      e.target.value
                    )
                  }
                />
              </label>

              <label>
                Text
                <input
                  type="color"
                  value={customTheme.text}
                  onChange={e=>
                    updateCustomColor(
                      'text',
                      e.target.value
                    )
                  }
                />
              </label>

              <label>
                Border
                <input
                  type="color"
                  value={customTheme.border}
                  onChange={e=>
                    updateCustomColor(
                      'border',
                      e.target.value
                    )
                  }
                />
              </label>

            </div>

            <div className="custom-theme-actions">
              <button
                type="button"
                className="primary theme-save-button"
                onClick={saveCustomTheme}
              >
                Simpan Custom Theme
              </button>
            </div>

          </div>

        </div>
      ) : (

        <div className="panel form-panel settings-content">

          <div className="form-grid">

            {groups[tab].map((k:string)=>{

              const v=f[k];

              const bool=[
                'auto_approve_attendance',
                'notify_late',
                'notify_leave',
                'maintenance_mode'
              ].includes(k);

              return (
                <label key={k}>

                  {labels[k]}

                  {bool ? (

                    <input
                      type="checkbox"
                      checked={!!v}
                      onChange={e=>
                        setF({
                          ...f,
                          [k]:e.target.checked
                        })
                      }
                    />

                  ) : (

                    <input
                      type={
                        [
                          'break_minutes',
                          'late_tolerance_minutes',
                          'attendance_radius_meters',
                          'overtime_multiplier'
                        ].includes(k)
                          ? 'number'
                          : k.includes('start')||k.includes('end')
                            ? 'time'
                            : 'text'
                      }
                      value={String(v??'')}
                      onChange={e=>
                        setF({
                          ...f,
                          [k]:
                            [
                              'break_minutes',
                              'late_tolerance_minutes',
                              'attendance_radius_meters',
                              'overtime_multiplier'
                            ].includes(k)
                              ? Number(e.target.value)
                              : e.target.value
                        })
                      }
                    />

                  )}

                </label>
              );
            })}

          </div>

        </div>
      )}

    </>
  );
}
function Audit() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [actionFilter, setActionFilter] = useState('ALL');
  const [moduleFilter, setModuleFilter] = useState('ALL');
  const [selected, setSelected] = useState<any | null>(null);
  useEffect(() => {
    let mounted = true;

    const loadAudit = async () => {
      setLoading(true);

      const { data, error } = await supabase
        .from('hris_audit_logs')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(500);

      if (mounted) {
        setRows(error ? [] : data || []);
        setLoading(false);
      }
    };

    loadAudit();

    return () => {
      mounted = false;
    };
  }, []);

  const normalize = (value: any) => {
    if (value === null || value === undefined) return '-';

    if (typeof value === 'object') {
      try {
        return JSON.stringify(value);
      } catch {
        return String(value);
      }
    }

    return String(value);
  };

  const getChangedFields = (row: any) => {
    const oldValue =
      row?.old ??
      row?.old_data ??
      row?.old_values ??
      row?.metadata?.old ??
      {};

    const newValue =
      row?.new ??
      row?.new_data ??
      row?.new_values ??
      row?.metadata?.new ??
      {};

    const oldObj =
      oldValue && typeof oldValue === 'object' ? oldValue : {};

    const newObj =
      newValue && typeof newValue === 'object' ? newValue : {};

    const keys = Array.from(
      new Set([...Object.keys(oldObj), ...Object.keys(newObj)])
    );

    return keys
      .filter(
        (key) =>
          JSON.stringify(oldObj[key]) !== JSON.stringify(newObj[key])
      )
      .map((key) => ({
        field: key,
        oldValue: oldObj[key],
        newValue: newObj[key],
      }));
  };

  const formatDate = (value: any) => {
    if (!value) return '-';

    try {
      return new Date(value).toLocaleString('id-ID', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
      });
    } catch {
      return String(value);
    }
  };

  const actionLabel = (action: any) => {
    const value = String(action || '-').toUpperCase();

    if (value === 'INSERT' || value === 'CREATE') return 'CREATE';
    if (value === 'UPDATE') return 'UPDATE';
    if (value === 'DELETE') return 'DELETE';

    return value;
  };

  const actionClass = (action: any) => {
    const value = actionLabel(action);

    if (value === 'CREATE') return 'audit-badge audit-create';
    if (value === 'UPDATE') return 'audit-badge audit-update';
    if (value === 'DELETE') return 'audit-badge audit-delete';

    return 'audit-badge';
  };

  const filteredRows = rows.filter((row) => {
    const action = actionLabel(row.action);
    const module = String(row.module || '-');

    const keyword = search.trim().toLowerCase();

    const searchable = [
      row.actor_email,
      row.actor_name,
      row.action,
      row.module,
      row.description,
      row.entity_id,
      row.entity_type,
      JSON.stringify(row.details || {}),
      JSON.stringify(row.old || {}),
      JSON.stringify(row.new || {}),
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();

    const matchesSearch =
      !keyword || searchable.includes(keyword);

    const matchesAction =
      actionFilter === 'ALL' || action === actionFilter;

    const matchesModule =
      moduleFilter === 'ALL' || module === moduleFilter;

    return matchesSearch && matchesAction && matchesModule;
  });

  const modules = Array.from(
    new Set(
      rows
        .map((row) => String(row.module || '-'))
        .filter(Boolean)
    )
  );

  return (
    <>
      <Heading
        title="Audit Log"
        desc="Riwayat aktivitas dan perubahan data yang tercatat di database."
      />

      <div className="panel" style={{ marginBottom: 16 }}>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns:
              'minmax(220px, 1fr) 180px 180px auto',
            gap: 10,
            alignItems: 'center',
          }}
        >
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Cari actor, action, module, ID..."
            style={{
              width: '100%',
              padding: '11px 13px',
              borderRadius: 10,
              border: '1px solid #d9dee8',
              outline: 'none',
            }}
          />

          <select
            value={actionFilter}
            onChange={(e) => setActionFilter(e.target.value)}
            style={{
              padding: '11px 13px',
              borderRadius: 10,
              border: '1px solid #d9dee8',
              background: '#fff',
            }}
          >
            <option value="ALL">Semua Action</option>
            <option value="CREATE">CREATE</option>
            <option value="UPDATE">UPDATE</option>
            <option value="DELETE">DELETE</option>
          </select>

          <select
            value={moduleFilter}
            onChange={(e) => setModuleFilter(e.target.value)}
            style={{
              padding: '11px 13px',
              borderRadius: 10,
              border: '1px solid #d9dee8',
              background: '#fff',
            }}
          >
            <option value="ALL">Semua Module</option>
            {modules.map((module) => (
              <option key={module} value={module}>
                {module}
              </option>
            ))}
          </select>

          <div
            style={{
              fontSize: 13,
              color: '#667085',
              whiteSpace: 'nowrap',
            }}
          >
            {filteredRows.length} aktivitas
          </div>
        </div>
      </div>

      <div className="panel table-panel">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Waktu</th>
                <th>Actor</th>
                <th>Action</th>
                <th>Module</th>
                <th>Entity</th>
                <th>Perubahan</th>
                <th style={{ textAlign: 'center' }}>Detail</th>
              </tr>
            </thead>

            <tbody>
              {loading ? (
                <tr>
                  <td
                    colSpan={7}
                    style={{
                      textAlign: 'center',
                      padding: 30,
                    }}
                  >
                    Memuat Audit Log...
                  </td>
                </tr>
              ) : filteredRows.length ? (
                filteredRows.map((row) => {
                  const changes = getChangedFields(row);

                  return (
                    <tr key={row.id}>
                      <td style={{ whiteSpace: 'nowrap' }}>
                        {formatDate(row.created_at)}
                      </td>

                      <td>
                        <div
                          style={{
                            fontWeight: 600,
                            color: '#101828',
                          }}
                        >
                          {row.actor_email ||
                            row.actor_name ||
                            '-'}
                        </div>
                      </td>

                      <td>
                        <span className={actionClass(row.action)}>
                          {actionLabel(row.action)}
                        </span>
                      </td>

                      <td>
                        {row.module || '-'}
                      </td>

                      <td>
                        <div>
                          <strong>
                            {row.entity_type || '-'}
                          </strong>
                        </div>

                        {row.entity_id && (
                          <small
                            style={{
                              color: '#667085',
                              wordBreak: 'break-all',
                            }}
                          >
                            {row.entity_id}
                          </small>
                        )}
                      </td>

                      <td>
                        {changes.length ? (
                          <div
                            style={{
                              display: 'flex',
                              flexDirection: 'column',
                              gap: 4,
                            }}
                          >
                            {changes
                              .slice(0, 3)
                              .map((change) => (
                                <div
                                  key={change.field}
                                  style={{
                                    fontSize: 12,
                                  }}
                                >
                                  <strong>
                                    {change.field}
                                  </strong>
                                  :{' '}
                                  <span
                                    style={{
                                      color: '#b42318',
                                    }}
                                  >
                                    {normalize(
                                      change.oldValue
                                    )}
                                  </span>
                                  {' → '}
                                  <span
                                    style={{
                                      color: '#027a48',
                                    }}
                                  >
                                    {normalize(
                                      change.newValue
                                    )}
                                  </span>
                                </div>
                              ))}

                            {changes.length > 3 && (
                              <small
                                style={{
                                  color: '#667085',
                                }}
                              >
                                +{changes.length - 3} perubahan
                                lainnya
                              </small>
                            )}
                          </div>
                        ) : (
                          <span
                            style={{
                              color: '#98a2b3',
                            }}
                          >
                            Tidak ada perubahan field
                          </span>
                        )}
                      </td>

                      <td style={{ textAlign: 'center' }}>
                        <button
                          type="button"
                          onClick={() => setSelected(row)}
                          style={{
                            border: '1px solid #d0d5dd',
                            background: '#fff',
                            borderRadius: 8,
                            padding: '7px 11px',
                            cursor: 'pointer',
                            fontWeight: 600,
                          }}
                        >
                          Detail
                        </button>
                      </td>
                    </tr>
                  );
                })
              ) : (
                <Empty cols={7} />
              )}
            </tbody>
          </table>
        </div>
      </div>

      {selected && (
        <div
          onClick={() => setSelected(null)}
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(15, 23, 42, 0.45)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 20,
            zIndex: 9999,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: 'min(1000px, 100%)',
              maxHeight: '85vh',
              overflow: 'auto',
              background: '#fff',
              borderRadius: 16,
              boxShadow: '0 20px 60px rgba(0,0,0,.2)',
              padding: 24,
            }}
          >
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: 20,
              }}
            >
              <div>
                <h2
                  style={{
                    margin: 0,
                    fontSize: 20,
                  }}
                >
                  Audit Detail
                </h2>

                <div
                  style={{
                    marginTop: 5,
                    color: '#667085',
                    fontSize: 13,
                  }}
                >
                  {formatDate(selected.created_at)}
                </div>
              </div>

              <button
                type="button"
                onClick={() => setSelected(null)}
                style={{
                  border: 'none',
                  background: '#f2f4f7',
                  borderRadius: 8,
                  padding: '8px 12px',
                  cursor: 'pointer',
                }}
              >
                Tutup
              </button>
            </div>

            <div
              style={{
                display: 'grid',
                gridTemplateColumns:
                  'repeat(4, minmax(0, 1fr))',
                gap: 12,
                marginBottom: 20,
              }}
            >
              <div>
                <small>Actor</small>
                <div style={{ fontWeight: 600 }}>
                  {selected.actor_email ||
                    selected.actor_name ||
                    '-'}
                </div>
              </div>

              <div>
                <small>Action</small>
                <div style={{ marginTop: 5 }}>
                  <span
                    className={actionClass(selected.action)}
                  >
                    {actionLabel(selected.action)}
                  </span>
                </div>
              </div>

              <div>
                <small>Module</small>
                <div style={{ fontWeight: 600 }}>
                  {selected.module || '-'}
                </div>
              </div>

              <div>
                <small>Entity</small>
                <div style={{ fontWeight: 600 }}>
                  {selected.entity_type || '-'}
                </div>
              </div>
            </div>

            <h3
              style={{
                margin: '0 0 12px',
                fontSize: 16,
              }}
            >
              Perubahan Data
            </h3>

            <div
              style={{
                border: '1px solid #eaecf0',
                borderRadius: 12,
                overflow: 'hidden',
              }}
            >
              <table>
                <thead>
                  <tr>
                    <th>Field</th>
                    <th>OLD VALUE</th>
                    <th>NEW VALUE</th>
                  </tr>
                </thead>

                <tbody>
                  {getChangedFields(selected).length ? (
                    getChangedFields(selected).map(
                      (change) => (
                        <tr key={change.field}>
                          <td>
                            <strong>
                              {change.field}
                            </strong>
                          </td>

                          <td>
                            <span
                              style={{
                                color: '#b42318',
                                wordBreak: 'break-word',
                              }}
                            >
                              {normalize(
                                change.oldValue
                              )}
                            </span>
                          </td>

                          <td>
                            <span
                              style={{
                                color: '#027a48',
                                wordBreak: 'break-word',
                              }}
                            >
                              {normalize(
                                change.newValue
                              )}
                            </span>
                          </td>
                        </tr>
                      )
                    )
                  ) : (
                    <tr>
                      <td
                        colSpan={3}
                        style={{
                          textAlign: 'center',
                          padding: 20,
                        }}
                      >
                        Tidak ada perubahan field.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            {selected.details && (
              <details style={{ marginTop: 20 }}>
                <summary
                  style={{
                    cursor: 'pointer',
                    fontWeight: 600,
                  }}
                >
                  Raw Details
                </summary>

                <pre
                  style={{
                    marginTop: 10,
                    background: '#101828',
                    color: '#f8fafc',
                    padding: 15,
                    borderRadius: 10,
                    overflow: 'auto',
                    fontSize: 12,
                  }}
                >
                  {JSON.stringify(
                    selected.details,
                    null,
                    2
                  )}
                </pre>
              </details>
            )}
          </div>
        </div>
      )}
    </>
  );
}
function Notifications(){const [rows,setRows]=useState<any[]>([]),[loading,setLoading]=useState(true);const load=async()=>{setLoading(true);const {data}=await supabase.from('hris_notifications').select('*').order('created_at',{ascending:false}).limit(100);setRows(data||[]);setLoading(false)};useEffect(()=>{load()},[]);const mark=async(id:string)=>{await supabase.from('hris_notifications').update({is_read:true}).eq('id',id);load()};return <><Heading title="Notifikasi" desc="Pusat pemberitahuan HRIS untuk approval, cuti, payroll, dan aktivitas penting."/><div className="panel table-panel"><div className="panel-head"><div><h2>Inbox HR</h2><p>{rows.filter(r=>!r.is_read).length} belum dibaca</p></div><button className="secondary" onClick={load}>Refresh</button></div><div className="notification-list">{loading?<div className="loading">Memuat…</div>:rows.length?rows.map(r=><button key={r.id} className={`notification-item ${r.is_read?'read':''}`} onClick={()=>mark(r.id)}><span className="notification-dot"/><span><b>{r.title}</b><small>{r.message}</small><em>{r.created_at?.replace('T',' ').slice(0,19)}</em></span></button>):<div className="empty-module"><h3>Tidak ada notifikasi</h3><p>Notifikasi sistem akan muncul di sini.</p></div>}</div></div></>}
function SystemHealth(){const [h,setH]=useState<any>(null),[err,setErr]=useState('');const load=async()=>{const {data,error}=await supabase.from('hris_system_health').select('*').maybeSingle();if(error)setErr(error.message);else setH(data)};useEffect(()=>{load()},[]);const cards=[['active_employees','Karyawan Aktif'],['pending_leave','Cuti Menunggu'],['pending_overtime','Lembur Menunggu'],['pending_payroll','Payroll Menunggu'],['pending_approvals','Approval Menunggu'],['unread_notifications','Notifikasi Belum Dibaca']];return <><Heading title="System Health" desc="Ringkasan kesehatan operasional HRIS dari database." action="Refresh" onAction={load}/>{err&&<div className="alert">{err}</div>}<div className="mini-kpi-row">{cards.map(([k,l])=><div className="stat-card" key={k}><span>{l}</span><strong>{h?.[k]??'—'}</strong></div>)}</div><div className="panel"><h3>Status layanan</h3><p>Database: <b>{h?'Operational':'Checking…'}</b></p><p>Terakhir diperiksa: {h?.checked_at?.replace('T',' ').slice(0,19)||'—'}</p></div></>}

function SimpleModal({title,onClose,onSave,children}:{title:string;onClose:()=>void;onSave:(e:FormEvent)=>void;children:ReactNode}){return <div className="drawer-backdrop"><aside className="edit-drawer"><div className="drawer-head"><h2>{title}</h2><button className="icon-btn" onClick={onClose}>×</button></div><form className="drawer-body" onSubmit={onSave}>{children}<div className="drawer-foot"><button type="button" className="secondary" onClick={onClose}>Batal</button><button className="primary">Simpan</button></div></form></aside></div>}
function Status({value}:{value:string}){const v=value.toLowerCase();const cls=v.includes('non')||v.includes('tolak')||v.includes('sakit')?'red':v.includes('terlambat')||v.includes('draft')||v.includes('menunggu')?'orange':v.includes('izin')?'blue':'green';return <span className={`status ${cls}`}>{value}</span>}
function Empty({cols}:{cols:number}){return <tr><td colSpan={cols} className="empty-cell">Belum ada data.</td></tr>}
function fieldLabel(k:string){return ({id_karyawan:'ID Karyawan',nama:'Nama Lengkap',jabatan:'Jabatan',email:'Email',no_telp:'No. Telepon',departemen:'Departemen',tanggal_masuk:'Tanggal Masuk',gaji_pokok:'Gaji Pokok',periode:'Periode',indikator:'Indikator',target:'Target',realisasi:'Realisasi',bobot:'Bobot',skor:'Skor',jumlah_kebutuhan:'Jumlah Kebutuhan',tanggal_buka:'Tanggal Buka',tanggal_tutup:'Tanggal Tutup',deskripsi:'Deskripsi',posisi:'Posisi',sumber:'Sumber',tahap:'Tahap',catatan:'Catatan',nilai:'Nilai',kandidat:'Kandidat',jam:'Jam',interviewer:'Interviewer',hasil:'Hasil',company_name:'Nama Perusahaan',work_start:'Jam Masuk',work_end:'Jam Pulang',break_minutes:'Istirahat (menit)',payday_day:'Hari Gajian',currency:'Mata Uang',timezone:'Timezone'})[k]||k}

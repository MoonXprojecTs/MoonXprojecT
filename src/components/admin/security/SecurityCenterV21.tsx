import {useEffect,useMemo,useState} from 'react';
import {supabase} from '../../../lib/supabase/client';

type SecurityEvent={id:string;event_type:string;actor_email:string|null;actor_role:string|null;metadata:Record<string,unknown>;created_at:string};
type Permission={permission_code:string};

const fmtDate=(v:string)=>new Intl.DateTimeFormat('id-ID',{dateStyle:'medium',timeStyle:'short'}).format(new Date(v));

export default function SecurityCenterV21(){
 const [role,setRole]=useState(''); const [email,setEmail]=useState(''); const [perms,setPerms]=useState<string[]>([]);
 const [events,setEvents]=useState<SecurityEvent[]>([]); const [search,setSearch]=useState(''); const [loading,setLoading]=useState(true); const [msg,setMsg]=useState('');
 const canManage=role==='Super Admin'||perms.includes('*')||perms.includes('security.manage');
 const canRead=canManage||perms.includes('security.read');
 async function load(){
  setLoading(true); setMsg('');
  const {data:u}=await supabase.auth.getUser(); const e=u.user?.email||''; setEmail(e);
  if(!e){setLoading(false);return;}
  const {data:p}=await supabase.from('hris_users').select('role,status').eq('email',e).maybeSingle();
  if(!p||p.status!=='Aktif'){setMsg('Akun tidak aktif.');setLoading(false);return;}
  setRole(p.role||''); const {data:rp}=await supabase.from('hris_role_permissions').select('permission_code').eq('role_name',p.role);
  const codes=(rp as Permission[]||[]).map(x=>x.permission_code); setPerms(codes);
  if(p.role==='Super Admin'||codes.includes('*')||codes.includes('security.read')||codes.includes('security.manage')){
   const {data:s,error}=await supabase.from('hris_security_events').select('*').order('created_at',{ascending:false}).limit(100);
   if(error)setMsg(error.message); else setEvents((s||[]) as SecurityEvent[]);
  }
  setLoading(false);
 }
 useEffect(()=>{load()},[]);
 const filtered=useMemo(()=>events.filter(x=>`${x.event_type} ${x.actor_email||''} ${x.actor_role||''}`.toLowerCase().includes(search.toLowerCase())),[events,search]);
 async function logTest(){if(!canManage)return;const {error}=await supabase.rpc('hris_v21_security_event',{p_event_type:'SECURITY_CENTER_VIEW',p_metadata:{source:'Security Center'}});if(error)setMsg(error.message);else{setMsg('Security event tercatat.');load()}}
 return <div className="module-page">
  <div className="module-head"><div><h2>Security Center</h2><p>Kontrol otorisasi, audit, dan event keamanan terpusat.</p></div><button className="primary-btn" disabled={!canManage} onClick={logTest}>Catat Security Event</button></div>
  <div className="ess-kpis">
   <div className="ess-kpi"><span>Role Aktif</span><strong>{role||'—'}</strong><small>{email||'Tidak terautentikasi'}</small></div>
   <div className="ess-kpi"><span>Permission</span><strong>{perms.length}</strong><small>{perms.includes('*')?'Wildcard / Full Access':'Granular access'}</small></div>
   <div className="ess-kpi"><span>Security Events</span><strong>{events.length}</strong><small>100 event terakhir</small></div>
   <div className="ess-kpi"><span>Mode</span><strong>{canManage?'Admin':'Read Only'}</strong><small>{canRead?'Monitoring tersedia':'Akses terbatas'}</small></div>
  </div>
  <div className="panel">
   <div className="panel-head"><div><h3>Permission efektif</h3><p>Permission yang terbaca dari role akun saat ini.</p></div></div>
   <div className="permission-chips">{perms.length?perms.map(p=><span className="permission-chip" key={p}>{p}</span>):<span className="muted">Tidak ada permission eksplisit.</span>}</div>
  </div>
  <div className="panel">
   <div className="panel-head"><div><h3>Security Event Log</h3><p>Event administratif yang dicatat server.</p></div><input className="table-search" value={search} onChange={e=>setSearch(e.target.value)} placeholder="Cari event, email, role..."/></div>
   {msg&&<div className="inline-alert">{msg}</div>}
   <div className="table-scroll"><table className="data-table"><thead><tr><th>Waktu</th><th>Event</th><th>Actor</th><th>Role</th><th>Metadata</th></tr></thead><tbody>{loading?<tr><td colSpan={5}>Memuat...</td></tr>:filtered.length?filtered.map(x=><tr key={x.id}><td>{fmtDate(x.created_at)}</td><td><b>{x.event_type}</b></td><td>{x.actor_email||'—'}</td><td>{x.actor_role||'—'}</td><td><code>{JSON.stringify(x.metadata||{})}</code></td></tr>):<tr><td colSpan={5}>Belum ada event.</td></tr>}</tbody></table></div>
  </div>
 </div>
}

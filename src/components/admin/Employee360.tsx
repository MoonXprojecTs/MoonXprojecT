import { useEffect, useMemo, useState } from 'react';
import { supabase } from '../../../lib/supabase/client';
import '../../../styles/admin/admin.css';

type Employee={id:string;id_karyawan?:string;nama:string;departemen?:string;jabatan?:string;email?:string;no_telp?:string;alamat_rumah?:string;gaji_pokok?:number;status_aktif?:boolean;tanggal_masuk?:string;status_karyawan?:string;tipe_karyawan?:string;lokasi_kerja?:string;level_jabatan?:string};
type Row=Record<string,any>;
const money=(n:number)=>new Intl.NumberFormat('id-ID',{style:'currency',currency:'IDR',maximumFractionDigits:0}).format(Number(n)||0);
function Stat({label,value}:{label:string;value:string|number}){return <div className="stat-card"><span>{label}</span><strong>{value}</strong></div>}
export default function Employee360({employees}:{employees:Employee[]}){
 const [selected,setSelected]=useState(employees[0]?.id_karyawan||''),[attendance,setAttendance]=useState<Row[]>([]),[leave,setLeave]=useState<Row[]>([]),[overtime,setOvertime]=useState<Row[]>([]),[payroll,setPayroll]=useState<Row[]>([]),[history,setHistory]=useState<Row[]>([]),[docs,setDocs]=useState<Row[]>([]),[tab,setTab]=useState('overview');
 const emp=useMemo(()=>employees.find(x=>x.id_karyawan===selected),[employees,selected]);
 useEffect(()=>{if(!selected)return; (async()=>{const [a,l,o,p,h,d]=await Promise.all([
  supabase.from('absensi').select('*').eq('id_karyawan',selected).order('tanggal',{ascending:false}).limit(100),
  supabase.from('hris_cuti').select('*').eq('id_karyawan',selected).order('tanggal_mulai',{ascending:false}).limit(50),
  supabase.from('hris_lembur').select('*').eq('id_karyawan',selected).order('tanggal',{ascending:false}).limit(50),
  supabase.from('hris_payroll').select('*').eq('id_karyawan',selected).order('periode',{ascending:false}).limit(24),
  supabase.from('hris_employee_history').select('*').eq('id_karyawan',selected).order('created_at',{ascending:false}).limit(50),
  supabase.from('hris_employee_documents').select('*').eq('id_karyawan',selected).order('created_at',{ascending:false}).limit(50)
 ]);setAttendance(a.data||[]);setLeave(l.data||[]);setOvertime(o.data||[]);setPayroll(p.data||[]);setHistory(h.data||[]);setDocs(d.data||[])})()},[selected]);
 if(!employees.length)return <div className="panel empty-state"><h3>Belum ada karyawan</h3><p>Tambahkan karyawan terlebih dahulu untuk menggunakan Employee 360°.</p></div>;
 return <><div className="page-heading"><div><span className="group-title">PEOPLE · 360°</span><h1>Employee 360°</h1><p>Satu layar untuk melihat profil, attendance, leave, overtime, payroll, dokumen dan riwayat karyawan.</p></div><select className="employee-picker" value={selected} onChange={e=>setSelected(e.target.value)}>{employees.map(x=><option key={x.id} value={x.id_karyawan}>{x.nama} — {x.id_karyawan}</option>)}</select></div>
 {emp&&<div className="employee-hero panel"><div className="employee-avatar">{emp.nama.slice(0,2).toUpperCase()}</div><div className="employee-hero-copy"><h2>{emp.nama}</h2><p>{emp.jabatan||'—'} · {emp.departemen||'—'}</p><small>{emp.email||'Email belum diisi'} · {emp.no_telp||'Telepon belum diisi'}</small></div><div className="employee-hero-meta"><b>{emp.status_aktif===false?'Nonaktif':'Aktif'}</b><span>{emp.tipe_karyawan||emp.status_karyawan||'Karyawan'}</span><span>{emp.lokasi_kerja||'Lokasi belum diisi'}</span></div></div>}
 <div className="mini-kpi-row"><Stat label="Attendance" value={attendance.length}/><Stat label="Cuti" value={leave.length}/><Stat label="Lembur" value={overtime.length}/><Stat label="Payroll" value={payroll.length}/><Stat label="Dokumen" value={docs.length}/></div>
 <div className="branch-nav">{[['overview','Ringkasan'],['attendance','Absensi'],['leave','Cuti'],['overtime','Lembur'],['payroll','Payroll'],['documents','Dokumen'],['history','Riwayat']].map(([k,l])=><button key={k} className={tab===k?'active':''} onClick={()=>setTab(k)}>{l}</button>)}</div>
 <div className="panel table-panel">
 {tab==='overview'&&<div className="employee-overview"><div><h3>Profil</h3><dl><dt>ID Karyawan</dt><dd>{emp?.id_karyawan}</dd><dt>Jabatan</dt><dd>{emp?.jabatan||'—'}</dd><dt>Level</dt><dd>{emp?.level_jabatan||'—'}</dd><dt>Departemen</dt><dd>{emp?.departemen||'—'}</dd><dt>Tanggal Masuk</dt><dd>{emp?.tanggal_masuk||'—'}</dd><dt>Gaji Pokok</dt><dd>{money(Number(emp?.gaji_pokok||0))}</dd></dl></div><div><h3>Payroll Terakhir</h3>{payroll[0]?<><b className="big-money">{money(payroll[0].gaji_bersih)}</b><p>Periode {payroll[0].periode} · {payroll[0].status}</p></>:<p>Belum ada payroll.</p>}<h3>Aktivitas Terbaru</h3>{history.slice(0,4).map(x=><p key={x.id}><b>{x.jenis}</b> · {x.ke_nilai||'—'} <small>{String(x.created_at||'').slice(0,10)}</small></p>)}</div></div>}
 {tab==='attendance'&&<Simple rows={attendance} cols={['tanggal','jam_masuk','jam_pulang','status','keterlambatan_menit','lembur_menit']}/>} 
 {tab==='leave'&&<Simple rows={leave} cols={['jenis','tanggal_mulai','tanggal_selesai','jumlah_hari','status']}/>} 
 {tab==='overtime'&&<Simple rows={overtime} cols={['tanggal','menit','nominal','status']}/>} 
 {tab==='payroll'&&<Simple rows={payroll} cols={['periode','gaji_pokok','lembur','total_pendapatan','total_potongan','gaji_bersih','status']}/>} 
 {tab==='documents'&&<Simple rows={docs} cols={['jenis','nama_file','nomor_dokumen','tanggal_terbit','tanggal_expired','status']}/>} 
 {tab==='history'&&<Simple rows={history} cols={['created_at','jenis','dari_nilai','ke_nilai','efektif_mulai','alasan','actor_email']}/>}
 </div></>
}
function Simple({rows,cols}:{rows:Row[];cols:string[]}){return <div className="table-wrap"><table><thead><tr>{cols.map(c=><th key={c}>{c.replaceAll('_',' ')}</th>)}</tr></thead><tbody>{rows.length?rows.map((r,i)=><tr key={r.id||i}>{cols.map(c=><td key={c}>{String(r[c]??'—')}</td>)}</tr>):<tr><td colSpan={cols.length} className="empty-cell">Belum ada data.</td></tr>}</tbody></table></div>}

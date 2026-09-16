import { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabase/client';

type Shift={id:string;kode:string;nama:string;jam_masuk:string;jam_pulang:string;durasi_istirahat_menit:number;toleransi_menit:number;lintas_hari:boolean;aktif:boolean};

export default function AttendanceShiftV24(){
  const [shifts,setShifts]=useState<Shift[]>([]);
  const [loading,setLoading]=useState(true);
  const [form,setForm]=useState({kode:'SHIFT-1',nama:'Shift 1',jam_masuk:'07:00',jam_pulang:'16:00',durasi_istirahat_menit:60,toleransi_menit:10,lintas_hari:false});
  const [message,setMessage]=useState('');

  const load=async()=>{
    setLoading(true);
    const {data,error}=await supabase.from('hris_shift_definitions').select('*').order('kode');
    if(error)setMessage(error.message); else setShifts((data||[]) as Shift[]);
    setLoading(false);
  };
  useEffect(()=>{load()},[]);

  const save=async()=>{
    setMessage('');
    const {error}=await supabase.from('hris_shift_definitions').insert({...form});
    if(error)setMessage(error.message); else {setMessage('Shift berhasil disimpan.');load();}
  };

  return <section className="module-page">
    <div className="module-header">
      <div><div className="eyebrow">ATTENDANCE • SHIFT</div><h1>Attendance & Shift Engine</h1><p>Master shift, overnight schedule, tolerance, holiday calendar, calculation snapshot dan adjustment workflow.</p></div>
      <button className="btn-primary" onClick={load}>Refresh</button>
    </div>
    {message&&<div className="alert">{message}</div>}
    <div className="table-card">
      <div className="module-header" style={{marginBottom:16}}>
        <div><h2>Shift Master</h2><p>Gunakan <b>Lintas Hari</b> untuk shift malam yang berakhir pada hari berikutnya.</p></div>
        <button className="btn-primary" onClick={save}>Tambah Shift</button>
      </div>
      <div className="form-two">
        <label>Kode<input value={form.kode} onChange={e=>setForm({...form,kode:e.target.value})}/></label>
        <label>Nama<input value={form.nama} onChange={e=>setForm({...form,nama:e.target.value})}/></label>
        <label>Jam Masuk<input type="time" value={form.jam_masuk} onChange={e=>setForm({...form,jam_masuk:e.target.value})}/></label>
        <label>Jam Pulang<input type="time" value={form.jam_pulang} onChange={e=>setForm({...form,jam_pulang:e.target.value})}/></label>
        <label>Istirahat (menit)<input type="number" value={form.durasi_istirahat_menit} onChange={e=>setForm({...form,durasi_istirahat_menit:Number(e.target.value)})}/></label>
        <label>Toleransi (menit)<input type="number" value={form.toleransi_menit} onChange={e=>setForm({...form,toleransi_menit:Number(e.target.value)})}/></label>
        <label className="checkbox-row"><input type="checkbox" checked={form.lintas_hari} onChange={e=>setForm({...form,lintas_hari:e.target.checked})}/> Lintas Hari</label>
      </div>
      <div className="table-scroll"><table><thead><tr><th>Kode</th><th>Shift</th><th>Masuk</th><th>Pulang</th><th>Istirahat</th><th>Toleransi</th><th>Lintas Hari</th></tr></thead>
      <tbody>{loading?<tr><td colSpan={7}>Memuat…</td></tr>:shifts.map(s=><tr key={s.id}><td><strong>{s.kode}</strong></td><td>{s.nama}</td><td>{s.jam_masuk}</td><td>{s.jam_pulang}</td><td>{s.durasi_istirahat_menit} m</td><td>{s.toleransi_menit} m</td><td>{s.lintas_hari?'Ya':'Tidak'}</td></tr>)}</tbody></table></div>
    </div>
    <div className="ess-kpis">
      <div className="ess-kpi"><span>Shift aktif</span><strong>{shifts.filter(s=>s.aktif).length}</strong></div>
      <div className="ess-kpi"><span>Shift lintas hari</span><strong>{shifts.filter(s=>s.lintas_hari).length}</strong></div>
      <div className="ess-kpi"><span>Toleransi default</span><strong>{shifts.length?Math.round(shifts.reduce((a,s)=>a+s.toleransi_menit,0)/shifts.length):0} m</strong></div>
      <div className="ess-kpi"><span>Calculation</span><strong>V24</strong></div>
    </div>
  </section>;
}

import { useEffect, useState } from 'react';
import { supabase } from '../../../lib/supabase/client';

type Rule = { id:string; rule_code:string; rule_name:string; category:string; effective_from:string; employee_rate:number|null; employer_rate:number|null; cap_amount:number|null; active:boolean };

export default function PayrollIndonesiaV23() {
  const [rules,setRules]=useState<Rule[]>([]);
  const [loading,setLoading]=useState(true);
  const [message,setMessage]=useState('');

  const load=async()=>{
    setLoading(true);
    const {data,error}=await supabase.from('hris_payroll_statutory_rules').select('*').order('category').order('rule_code');
    if(error) setMessage(error.message); else setRules((data||[]) as Rule[]);
    setLoading(false);
  };
  useEffect(()=>{load()},[]);

  const pct=(v:number|null)=>v==null?'—':`${(v*100).toFixed(2)}%`;
  return <section className="module-page">
    <div className="module-header">
      <div><div className="eyebrow">PAYROLL • INDONESIA</div><h1>Indonesia Payroll Compliance</h1><p>Statutory rule registry, preflight, BPJS/PPh 21 snapshot foundation and annual reconciliation.</p></div>
      <button className="btn-primary" onClick={load}>Refresh</button>
    </div>
    {message && <div className="alert">{message}</div>}
    <div className="ess-kpis">
      <div className="ess-kpi"><span>Rules</span><strong>{rules.length}</strong></div>
      <div className="ess-kpi"><span>BPJS</span><strong>{rules.filter(r=>r.category==='BPJS').length}</strong></div>
      <div className="ess-kpi"><span>PPh 21</span><strong>{rules.filter(r=>r.category==='PPh21').length}</strong></div>
      <div className="ess-kpi"><span>THR</span><strong>{rules.filter(r=>r.category==='THR').length}</strong></div>
    </div>
    <div className="table-card">
      <div className="table-scroll"><table><thead><tr><th>Rule</th><th>Kategori</th><th>Mulai</th><th>Rate Karyawan</th><th>Rate Perusahaan</th><th>Cap</th><th>Status</th></tr></thead>
      <tbody>{loading?<tr><td colSpan={7}>Memuat…</td></tr>:rules.map(r=><tr key={r.id}><td><strong>{r.rule_code}</strong><div>{r.rule_name}</div></td><td>{r.category}</td><td>{r.effective_from}</td><td>{pct(r.employee_rate)}</td><td>{pct(r.employer_rate)}</td><td>{r.cap_amount==null?'—':new Intl.NumberFormat('id-ID',{style:'currency',currency:'IDR',maximumFractionDigits:0}).format(r.cap_amount)}</td><td><span className="status-badge">{r.active?'Aktif':'Nonaktif'}</span></td></tr>)}</tbody>
      </table></div>
    </div>
    <div className="alert">V23 memakai rule registry yang dapat dikonfigurasi. Tarif, batas upah, TER, dan perlakuan pajak wajib diverifikasi terhadap regulasi Indonesia yang berlaku sebelum payroll produksi.</div>
  </section>;
}

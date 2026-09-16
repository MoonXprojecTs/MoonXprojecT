export default function ModulPayroll() {
  return (
    <div className="payroll-module">
      <div className="page-heading">
        <div><span className="group-title">PAYROLL</span><h1>Payroll & Kompensasi</h1><p>Kelola informasi penggajian dengan tampilan ringkas dan mudah dipantau.</p></div>
        <button className="primary">Export Laporan</button>
      </div>
      <div className="stat-grid three">
        <div className="stat-card"><div className="stat-icon">Rp</div><div><small>Total Payroll</small><b>Terintegrasi</b><span>Dengan data kehadiran</span></div></div>
        <div className="stat-card"><div className="stat-icon">OK</div><div><small>Status</small><b>Siap Diproses</b><span>Periode berjalan</span></div></div>
        <div className="stat-card"><div className="stat-icon">↗</div><div><small>Lembur</small><b>Otomatis</b><span>Berbasis jam aktual</span></div></div>
      </div>
      <div className="content-grid">
        <section className="panel"><div className="panel-head"><div><h2>Standar Kompensasi</h2><p>Kebijakan yang digunakan oleh sistem payroll.</p></div></div><div className="payroll-policy-list"><div><b>Gaji pokok</b><span>Diatur langsung oleh Admin HR sesuai data karyawan.</span></div><div><b>Lembur</b><span>Perhitungan berdasarkan total jam kerja aktual dan komponen yang berlaku.</span></div><div><b>Slip gaji</b><span>Karyawan dapat melihat dan mencetak slip dengan status pembayaran yang telah dikonfirmasi.</span></div></div></section>
        <section className="panel quick"><div className="panel-head"><div><h2>Alur Payroll</h2><p>Proses kerja yang disarankan.</p></div></div><div className="payroll-steps"><div><strong>01</strong><b>Absensi</b><span>Data kehadiran terkumpul</span></div><div><strong>02</strong><b>Perhitungan</b><span>Gaji, lembur, potongan</span></div><div><strong>03</strong><b>Pembayaran</b><span>Status dibayar</span></div></div></section>
      </div>
    </div>
  );
}

import moonLogo from '../../assets/moon-logo.svg';
import '../../styles/components/home.css';

interface HomeProps {
  onAdminLogin: () => void;
  onRegister: () => void;
}

export default function Home({
  onAdminLogin,
  onRegister,
}: HomeProps) {
  return (
    <main className="home-page">

      <section className="hero-section">

        <div className="hero-copy">

          <div className="hero-eyebrow">
            <span />
            ENTERPRISE HR MANAGEMENT PLATFORM
          </div>

          <h1>
            Human Resources,
            <br />
            <em>simplified.</em>
          </h1>

          <p className="hero-lead">
            Kelola karyawan, absensi, jadwal, payroll, cuti,
            dan laporan perusahaan melalui satu platform HRIS
            yang modern dan terintegrasi.
          </p>

          <div className="hero-actions">

            <button
              className="hero-primary"
              onClick={onAdminLogin}
            >
              Masuk ke Dashboard
              <span>→</span>
            </button>

            <button
              className="hero-secondary"
              onClick={onRegister}
            >
              Daftar sebagai Karyawan
            </button>

          </div>

          <div className="hero-trust">
            <span>OK</span>
            Secure workforce management

            <i />

            <span>OK</span>
            Real-time data
          </div>

        </div>

        <div
          <div className="hero-visual">

  <div className="brand-hero-image">
    <img
      src="/sakura-moon.jpg"
      alt="MoonXprojecT"
    />
  </div>

  <div className="visual-glow" />
          <div className="dashboard-preview">

            <div className="preview-top">

              <span className="preview-logo">
                <img
                  src={moonLogo}
                  alt=""
                />
              </span>

              <div>
                <b>MoonXprojecT</b>
                <small>HR Command Center</small>
              </div>

              <span className="preview-dot" />

            </div>

            <div className="preview-welcome">
              <small>GOOD MORNING</small>
              <b>HR Command Center</b>
            </div>

            <div className="preview-stats">

              <div>
                <small>Total Karyawan</small>
                <b>116</b>
                <span>Active workforce</span>
              </div>

              <div>
                <small>Hadir Hari Ini</small>
                <b>108</b>
                <span>93.1% attendance</span>
              </div>

            </div>

            <div className="preview-chart">

              <div className="chart-head">
                <b>Attendance overview</b>
                <span>Today</span>
              </div>

              <div className="bars">
                <i style={{ height: '42%' }} />
                <i style={{ height: '66%' }} />
                <i style={{ height: '54%' }} />
                <i style={{ height: '82%' }} />
                <i style={{ height: '71%' }} />
                <i style={{ height: '92%' }} />
                <i style={{ height: '78%' }} />
              </div>

            </div>

            <div className="preview-row">

              <span className="mini-person">
                A
              </span>

              <div>
                <b>Attendance</b>
                <small>On schedule</small>
              </div>

              <strong>98%</strong>

            </div>

          </div>

        </div>

      </section>

      <section className="feature-strip">

        <div>
          <span className="feature-icon">
            ♙
          </span>

          <div>
            <b>People Management</b>
            <small>Master data & organisasi</small>
          </div>
        </div>

        <div>
          <span className="feature-icon">
            ◷
          </span>

          <div>
            <b>Attendance</b>
            <small>Absensi & monitoring</small>
          </div>
        </div>

        <div>
          <span className="feature-icon">
            Rp
          </span>

          <div>
            <b>Payroll</b>
            <small>Payroll & slip gaji</small>
          </div>
        </div>

        <div>
          <span className="feature-icon">
            ▥
          </span>

          <div>
            <b>Reporting</b>
            <small>Laporan terintegrasi</small>
          </div>
        </div>

      </section>

    </main>
  );
}

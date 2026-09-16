import React, { useState } from 'react';
import { supabase } from '../../../lib/supabase/client';
import '../../../styles/employee/registration.css';

interface RegistrasiKaryawanProps {
  onBack?: () => void;
}

const RegistrasiKaryawan: React.FC<RegistrasiKaryawanProps> = ({
  onBack,
}) => {
  const [form, setForm] = useState({
    nama: '',
    email: '',
    no_telp: '',
    alamat_rumah: '',
    tanggal_lahir: '',
    password: '',
    konfirmasi: '',
  });

  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState('');

  const handleChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>
  ) => {
    setForm({
      ...form,
      [e.target.name]: e.target.value,
    });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    setError('');

    if (!form.nama.trim()) {
      setError('Nama lengkap wajib diisi.');
      return;
    }

    if (!form.email.trim()) {
      setError('Email wajib diisi.');
      return;
    }

    if (form.password.length < 6) {
      setError('Password minimal 6 karakter.');
      return;
    }

    if (form.password !== form.konfirmasi) {
      setError('Konfirmasi password tidak sama.');
      return;
    }

    setLoading(true);

    try {
      const { error: signUpError } = await supabase.auth.signUp({
        email: form.email.trim(),
        password: form.password,
        options: {
          data: {
            nama: form.nama.trim(),
            no_telp: form.no_telp.trim(),
            alamat_rumah: form.alamat_rumah.trim(),
            tanggal_lahir: form.tanggal_lahir || null,
          },
        },
      });

      if (signUpError) {
        throw signUpError;
      }

      setSuccess(true);
    } catch (err: any) {
      setError(err?.message || 'Pendaftaran gagal. Silakan coba lagi.');
    } finally {
      setLoading(false);
    }
  };

  if (success) {
    return (
      <div className="registration-page">
        <div className="registration-success">
          <div className="registration-logo">M</div>

          <h1>Pendaftaran Berhasil</h1>

          <p>
            Data Anda berhasil dikirim dan masuk ke proses verifikasi HR/Admin.
          </p>

          <div className="registration-success-box">
            <strong>Menunggu Verifikasi</strong>
            <span>
              Akun Anda akan dapat digunakan setelah HR/Admin mengaktifkannya.
            </span>
          </div>

          <button
            type="button"
            className="registration-button"
            onClick={onBack}
          >
            Kembali ke Login
          </button>
        </div>
      </div>
    );
  }

 return (
    <div className="registration-page">
      <div className="registration-shell">
        <div className="registration-brand">
          <div className="registration-logo">
  <img
    src="/sakura-moon.jpg"
    alt="MoonXprojecT"
  />
</div>

          <div>
            <strong>MoonXprojecT</strong>
      <span>Human Resources & Workforce Platform</span>
          </div>
        </div>

        <div className="registration-card">
          <div className="registration-heading">
            <span className="registration-eyebrow">
              EMPLOYEE REGISTRATION
            </span>

            <h1>Daftar sebagai Karyawan</h1>

            <p>
              Lengkapi data berikut untuk membuat akun karyawan MoonHR.
            </p>
          </div>

          {error && (
            <div className="registration-error">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit}>
            <div className="registration-section">
              <h3>Data Pribadi</h3>

              <div className="registration-field">
                <label>Nama Lengkap *</label>
                <input
                  name="nama"
                  value={form.nama}
                  onChange={handleChange}
                  placeholder="Masukkan nama lengkap"
                  required
                />
              </div>

              <div className="registration-row">
                <div className="registration-field">
                  <label>Email *</label>
                  <input
                    type="email"
                    name="email"
                    value={form.email}
                    onChange={handleChange}
                    placeholder="nama@email.com"
                    required
                  />
                </div>

                <div className="registration-field">
                  <label>No. Telepon</label>
                  <input
                    name="no_telp"
                    value={form.no_telp}
                    onChange={handleChange}
                    placeholder="08xxxxxxxxxx"
                  />
                </div>
              </div>

              <div className="registration-field">
                <label>Tanggal Lahir</label>
                <input
                  type="date"
                  name="tanggal_lahir"
                  value={form.tanggal_lahir}
                  onChange={handleChange}
                />
              </div>

              <div className="registration-field">
                <label>Alamat Rumah</label>
                <textarea
                  name="alamat_rumah"
                  value={form.alamat_rumah}
                  onChange={handleChange}
                  placeholder="Masukkan alamat lengkap"
                  rows={3}
                />
              </div>
            </div>

            <div className="registration-section">
              <h3>Keamanan Akun</h3>

              <div className="registration-row">
                <div className="registration-field">
                  <label>Password *</label>
                  <input
                    type="password"
                    name="password"
                    value={form.password}
                    onChange={handleChange}
                    placeholder="Minimal 6 karakter"
                    required
                  />
                </div>

                <div className="registration-field">
                  <label>Konfirmasi Password *</label>
                  <input
                    type="password"
                    name="konfirmasi"
                    value={form.konfirmasi}
                    onChange={handleChange}
                    placeholder="Ulangi password"
                    required
                  />
                </div>
              </div>
            </div>

            <div className="registration-role-note">
              <strong>Role akun:</strong>
              <span>Karyawan</span>
              <p>
                Role ditentukan otomatis dan tidak dapat dipilih sendiri.
              </p>
            </div>

            <button
              type="submit"
              className="registration-button"
              disabled={loading}
            >
              {loading ? 'Memproses...' : 'Daftar Sekarang'}
            </button>

            <button
              type="button"
              className="registration-back"
              onClick={onBack}
            >
              Sudah memiliki akun? Kembali ke Login
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default RegistrasiKaryawan;

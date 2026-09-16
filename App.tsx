import { useState, useEffect } from 'react';
import { isSupabaseConfigured, supabase } from './lib/supabase/client';
import Home from './pages/Home/Home';
import AdminDashboard from './pages/AdminDashboard/AdminDashboard';
import EmployeeRegister from './pages/EmployeeRegister/EmployeeRegister';
import EmployeePortal from './pages/EmployeePortal/EmployeePortal';
import ErrorBoundary from './components/common/ErrorBoundary';
import './styles/global/index.css'; // Pastikan CSS utama/Tailwind tetap termuat

type View = 'home' | 'admin' | 'register' | 'employee';

export default function App() {
  const [view, setView] = useState<View>(() => { const h=window.location.hash.replace('#/',''); return h==='admin'?'admin':h==='register'?'register':h==='employee'?'employee':'home'; });

  const navigate = (next: View) => { setView(next); window.location.hash = `/${next}`; window.scrollTo({top:0,behavior:'smooth'}); };

  useEffect(() => {
    const handleRegister = () => navigate('register');
    const handleHash = () => { const h=window.location.hash.replace('#/',''); setView(h==='admin'?'admin':h==='register'?'register':h==='employee'?'employee':'home'); };
    window.addEventListener('moonhr:register', handleRegister);
    window.addEventListener('hashchange', handleHash);

    let authSubscription: { unsubscribe: () => void } | null = null;
    if (isSupabaseConfigured) {
      const { data: authListener } = supabase.auth.onAuthStateChange((_event, session) => {
        const current = window.location.hash.replace('#/','');
        if (!session && (current === 'admin' || current === 'employee')) {
          setView('home');
          if (window.location.hash !== '#/home') window.location.hash = '/home';
        }
      });
      authSubscription = authListener.subscription;
    }

    return () => {
      authSubscription?.unsubscribe();
      window.removeEventListener('moonhr:register', handleRegister);
      window.removeEventListener('hashchange', handleHash);
    };
  }, []);

  return (
    <ErrorBoundary>
    <div className="app-root">

      {view !== 'admin' && view !== 'employee' && (
        <header className="public-nav">
          <button
            className="public-brand"
            onClick={() => navigate('home')}
            aria-label="MoonXprojecT Beranda"
          >
            <span className="brand-orbit">
              <span className="brand-orbit-mark" aria-hidden="true">M</span>
            </span>

            <span>
              <b>MoonXprojecT</b>
              {/* Teks "Human Resources Platform" sudah dihapus di sini */}
            </span>
          </button>

          <nav>
            <button
              className={view === 'home' ? 'active' : ''}
              onClick={() => navigate('home')}
            >
              Beranda
            </button>

            <button 
              className={view === 'register' ? 'active' : ''}
              onClick={() => navigate('register')}
            >
              Daftar Karyawan
            </button>

            <button
              className="nav-login"
              onClick={() => navigate('admin')}
            >
              Login HR
            </button>
          </nav>
        </header>
      )}

      {view === 'home' && (
        <Home
          onAdminLogin={() => navigate('admin')}
          onRegister={() => navigate('register')}
        />
      )}

      {view === 'register' && (
        <div className="public-page">
          <RegistrasiKaryawan
            onBack={() => navigate('home')}
          />
        </div>
      )}

      {view === 'admin' && (
        <AdminDashboard />
      )}

      {view === 'employee' && (
        <EmployeePortal />
      )}

    </div>
    </ErrorBoundary>
  );
}

import { useState, useEffect } from 'react';
import { isSupabaseConfigured, supabase } from './lib/supabase/client';

import Home from './pages/Home/Home';
import AdminDashboard from './pages/AdminDashboard/AdminDashboard';
import EmployeeRegister from './pages/EmployeeRegister/EmployeeRegister';
import EmployeePortal from './pages/EmployeePortal/EmployeePortal';

import ErrorBoundary from './components/common/ErrorBoundary';
import './styles/global/index.css';

type View = 'home' | 'admin' | 'register' | 'employee';

export default function App() {
  const [view, setView] = useState<View>(() => {
    const hash = window.location.hash.replace('#/', '');

    if (hash === 'admin') return 'admin';
    if (hash === 'register') return 'register';
    if (hash === 'employee') return 'employee';

    return 'home';
  });

  const navigate = (next: View) => {
    setView(next);
    window.location.hash = `/${next}`;
    window.scrollTo({
      top: 0,
      behavior: 'smooth',
    });
  };

  useEffect(() => {
    const handleRegister = () => {
      navigate('register');
    };

    const handleHash = () => {
      const hash = window.location.hash.replace('#/', '');

      // DashboardAdmin owns all internal menu routes (e.g. #/employees,
      // #/attendance, #/payroll). Do not let the top-level router turn
      // those dashboard routes back into the public home/login screen.
      if (hash === 'admin') {
        setView('admin');
      } else if (hash === 'register') {
        setView('register');
      } else if (hash === 'employee') {
        setView('employee');
      } else if (hash === 'home' || hash === '') {
        setView('home');
      }
    };

    window.addEventListener('moonhr:register', handleRegister);
    window.addEventListener('hashchange', handleHash);

    let authSubscription: { unsubscribe: () => void } | null = null;

    if (isSupabaseConfigured) {
      const {
        data: authListener,
      } = supabase.auth.onAuthStateChange((_event, session) => {
        const current = window.location.hash.replace('#/', '');

        if (
          !session &&
          (current === 'admin' || current === 'employee')
        ) {
          setView('home');

          if (window.location.hash !== '#/home') {
            window.location.hash = '/home';
          }
        }
      });

      authSubscription = authListener.subscription;
    }

    return () => {
      authSubscription?.unsubscribe();

      window.removeEventListener(
        'moonhr:register',
        handleRegister
      );

      window.removeEventListener(
        'hashchange',
        handleHash
      );
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
                <span
                  className="brand-orbit-mark"
                  aria-hidden="true"
                >
                  M
                </span>
              </span>

              <span>
                <b>MoonXprojecT</b>
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

<button
  className="nav-login employee-nav-login"
  onClick={() => navigate('employee')}
>
  Login Karyawan
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
            <EmployeeRegister
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

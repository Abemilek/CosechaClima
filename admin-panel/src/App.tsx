import { useEffect, useState } from 'react';
import { getToken, logout } from './api';
import LoginPage from './LoginPage';
import UsuariosPage from './UsuariosPage';
import ReglasPage from './ReglasPage';
import AlertasPage from './AlertasPage';
import { ConfirmModal } from './components';

type Vista = 'usuarios' | 'reglas' | 'alertas';

interface Sesion {
  nombre: string;
  email: string;
}

const SESION_KEY = 'cosechaclima_admin_sesion';

export default function App() {
  const [sesion, setSesion] = useState<Sesion | null>(() => {
    if (!getToken()) return null;
    const guardada = localStorage.getItem(SESION_KEY);
    return guardada ? (JSON.parse(guardada) as Sesion) : null;
  });
  const [vista, setVista] = useState<Vista>('usuarios');
  const [pidiendoConfirmacion, setPidiendoConfirmacion] = useState(false);

  useEffect(() => {
    if (sesion) localStorage.setItem(SESION_KEY, JSON.stringify(sesion));
  }, [sesion]);

  function onLoggedIn(nombre: string, email: string) {
    setSesion({ nombre, email });
  }

  function cerrarSesion() {
    logout();
    localStorage.removeItem(SESION_KEY);
    setSesion(null);
    setPidiendoConfirmacion(false);
  }

  if (!sesion) {
    return <LoginPage onLoggedIn={onLoggedIn} />;
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-sub">Administración</div>
          <div className="brand-title">CosechaClima</div>
        </div>

        <button
          className="nav-link"
          data-active={vista === 'usuarios'}
          onClick={() => setVista('usuarios')}
        >
          Usuarios
        </button>
        <button
          className="nav-link"
          data-active={vista === 'reglas'}
          onClick={() => setVista('reglas')}
        >
          Reglas de alerta
        </button>
        <button
          className="nav-link"
          data-active={vista === 'alertas'}
          onClick={() => setVista('alertas')}
        >
          Auditoría de alertas
        </button>

        <div className="sidebar-footer">
          <div className="user-chip">
            {sesion.nombre}
            <br />
            {sesion.email}
          </div>
          <button
            className="nav-link"
            onClick={() => setPidiendoConfirmacion(true)}
            style={{ color: 'var(--red)' }}
          >
            Cerrar sesión
          </button>
        </div>
      </aside>

      <main className="main">
        {vista === 'usuarios' && <UsuariosPage miEmail={sesion.email} />}
        {vista === 'reglas' && <ReglasPage />}
        {vista === 'alertas' && <AlertasPage />}
      </main>

      {pidiendoConfirmacion && (
        <ConfirmModal
          titulo="¿Deseas cerrar la sesión?"
          mensaje="Vas a salir del panel administrativo."
          confirmarTexto="Cerrar sesión"
          peligroso
          onConfirmar={cerrarSesion}
          onCancelar={() => setPidiendoConfirmacion(false)}
        />
      )}
    </div>
  );
}

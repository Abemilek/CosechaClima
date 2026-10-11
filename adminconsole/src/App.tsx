import { useEffect, useState } from 'react';
import { alExpirarSesion, logout, restaurarSesion } from './api';
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

export default function App() {
  const [sesion, setSesion] = useState<Sesion | null>(null);
  const [restaurando, setRestaurando] = useState(true);
  const [vista, setVista] = useState<Vista>('usuarios');
  const [pidiendoConfirmacion, setPidiendoConfirmacion] = useState(false);

  // Al abrir (o recargar) el panel se intenta recuperar la sesión con la cookie de refresh.
  useEffect(() => {
    let cancelado = false;
    restaurarSesion().then((datos) => {
      if (cancelado) return;
      if (datos) setSesion({ nombre: datos.nombre, email: datos.email });
      setRestaurando(false);
    });
    return () => {
      cancelado = true;
    };
  }, []);

  // Si el refresh falla en cualquier llamada, se vuelve al login.
  useEffect(() => alExpirarSesion(() => setSesion(null)), []);

  function onLoggedIn(nombre: string, email: string) {
    setSesion({ nombre, email });
  }

  async function cerrarSesion() {
    await logout();
    setSesion(null);
    setPidiendoConfirmacion(false);
  }

  if (restaurando) {
    return <div className="login-shell muted">Cargando...</div>;
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
          mensaje="Vas a salir del Admin Console."
          confirmarTexto="Cerrar sesión"
          peligroso
          onConfirmar={cerrarSesion}
          onCancelar={() => setPidiendoConfirmacion(false)}
        />
      )}
    </div>
  );
}

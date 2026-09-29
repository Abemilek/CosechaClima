import { useState, type FormEvent } from 'react';
import { login, ApiError } from './api';

interface Props {
  onLoggedIn: (nombre: string, email: string) => void;
}

export default function LoginPage({ onLoggedIn }: Props) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [cargando, setCargando] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setCargando(true);
    try {
      const datos = await login(email.trim(), password);
      onLoggedIn(datos.nombre, datos.email);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'No se pudo iniciar sesión.');
    } finally {
      setCargando(false);
    }
  }

  return (
    <div className="login-shell">
      <div className="login-card">
        <h1 style={{ fontSize: 22, marginBottom: 4 }}>CosechaClima</h1>
        <p className="muted" style={{ marginTop: 0, marginBottom: 20 }}>
          Panel administrativo
        </p>
        <form onSubmit={onSubmit}>
          <div className="field">
            <label htmlFor="email">Correo</label>
            <input
              id="email"
              type="email"
              autoComplete="username"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>
          <div className="field">
            <label htmlFor="password">Contraseña</label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>
          {error && <div className="error-banner">{error}</div>}
          <button
            type="submit"
            className="btn btn-primary"
            style={{ width: '100%' }}
            disabled={cargando}
          >
            {cargando ? 'Ingresando...' : 'Ingresar'}
          </button>
        </form>
        <p className="muted" style={{ fontSize: 12, marginTop: 16 }}>
          Solo cuentas con rol de administrador pueden entrar acá. Las cuentas
          de productores usan la app móvil.
        </p>
      </div>
    </div>
  );
}

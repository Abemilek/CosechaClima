import { useEffect, useState } from 'react';
import { adminApi, ApiError, type UsuarioAdmin } from './api';
import { EstadoPill, ConfirmModal } from './components';

export default function UsuariosPage({ miEmail }: { miEmail: string }) {
  const [usuarios, setUsuarios] = useState<UsuarioAdmin[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busqueda, setBusqueda] = useState('');
  const [pendiente, setPendiente] = useState<{
    usuario: UsuarioAdmin;
    accion: 'rol' | 'estado';
  } | null>(null);

  async function cargar() {
    setCargando(true);
    setError(null);
    try {
      setUsuarios(await adminApi.listarUsuarios());
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'No se pudo cargar la lista.');
    } finally {
      setCargando(false);
    }
  }

  useEffect(() => {
    cargar();
  }, []);

  async function confirmarAccion() {
    if (!pendiente) return;
    const { usuario, accion } = pendiente;
    try {
      if (accion === 'rol') {
        await adminApi.cambiarRol(usuario.id, !usuario.esAdmin);
      } else {
        await adminApi.cambiarEstado(usuario.id, !usuario.activo);
      }
      await cargar();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'No se pudo actualizar el usuario.');
    } finally {
      setPendiente(null);
    }
  }

  const filtrados = usuarios.filter(
    (u) =>
      u.nombre.toLowerCase().includes(busqueda.toLowerCase()) ||
      u.email.toLowerCase().includes(busqueda.toLowerCase()),
  );

  return (
    <div>
      <div className="page-header">
        <h1>Usuarios</h1>
        <p>Gestioná roles y el acceso de productores y administradores.</p>
      </div>

      {error && <div className="error-banner">{error}</div>}

      <div className="card">
        <div className="toolbar">
          <input
            placeholder="Buscar por nombre o correo..."
            value={busqueda}
            onChange={(e) => setBusqueda(e.target.value)}
            style={{ padding: '8px 12px', borderRadius: 10, border: '1px solid var(--border)', minWidth: 240 }}
          />
          <button className="btn" onClick={cargar}>
            Actualizar
          </button>
        </div>

        {cargando ? (
          <div className="empty-state">Cargando usuarios...</div>
        ) : filtrados.length === 0 ? (
          <div className="empty-state">No hay usuarios que coincidan con la búsqueda.</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Nombre</th>
                <th>Correo</th>
                <th>Proveedor</th>
                <th>Registrado</th>
                <th>Rol</th>
                <th>Estado</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {filtrados.map((u) => {
                const esYo = u.email.toLowerCase() === miEmail.toLowerCase();
                return (
                  <tr key={u.id}>
                    <td>{u.nombre}</td>
                    <td>{u.email}</td>
                    <td className="muted">{u.proveedor === 'Google' ? 'Google' : 'Correo'}</td>
                    <td className="muted">
                      {new Date(u.fechaRegistro).toLocaleDateString('es-NI')}
                    </td>
                    <td>
                      <EstadoPill activo={u.esAdmin} textoOn="Admin" textoOff="Productor" />
                    </td>
                    <td>
                      <EstadoPill activo={u.activo} textoOn="Activo" textoOff="Desactivado" />
                    </td>
                    <td className="text-right">
                      <button
                        className="btn btn-small"
                        disabled={esYo}
                        title={esYo ? 'No podés cambiar tu propio rol' : undefined}
                        onClick={() => setPendiente({ usuario: u, accion: 'rol' })}
                        style={{ marginRight: 6 }}
                      >
                        {u.esAdmin ? 'Quitar admin' : 'Hacer admin'}
                      </button>
                      <button
                        className="btn btn-small btn-outline-red"
                        disabled={esYo}
                        title={esYo ? 'No podés desactivar tu propia cuenta' : undefined}
                        onClick={() => setPendiente({ usuario: u, accion: 'estado' })}
                      >
                        {u.activo ? 'Desactivar' : 'Activar'}
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {pendiente && (
        <ConfirmModal
          titulo={pendiente.accion === 'rol' ? 'Cambiar rol' : 'Cambiar estado de la cuenta'}
          mensaje={
            pendiente.accion === 'rol'
              ? `${pendiente.usuario.esAdmin ? 'Quitarle' : 'Darle'} el rol de administrador a ${pendiente.usuario.nombre}?`
              : `${pendiente.usuario.activo ? 'Desactivar' : 'Activar'} la cuenta de ${pendiente.usuario.nombre}?`
          }
          peligroso={pendiente.accion === 'estado' && pendiente.usuario.activo}
          onConfirmar={confirmarAccion}
          onCancelar={() => setPendiente(null)}
        />
      )}
    </div>
  );
}

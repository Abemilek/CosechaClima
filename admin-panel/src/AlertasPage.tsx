import { useEffect, useMemo, useState } from 'react';
import { adminApi, ApiError, type Alerta, type Catalogo } from './api';
import { RiesgoPill } from './components';

export default function AlertasPage() {
  const [alertas, setAlertas] = useState<Alerta[]>([]);
  const [eventos, setEventos] = useState<Catalogo[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function cargar() {
    setCargando(true);
    setError(null);
    try {
      const [a, e] = await Promise.all([
        adminApi.listarAlertas(150),
        adminApi.listarEventos(),
      ]);
      setAlertas(a);
      setEventos(e);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'No se pudo cargar el historial.');
    } finally {
      setCargando(false);
    }
  }

  useEffect(() => {
    cargar();
  }, []);

  const nombreEvento = useMemo(() => {
    const mapa: Record<number, string> = {};
    for (const e of eventos) mapa[e.id] = e.nombre;
    return mapa;
  }, [eventos]);

  return (
    <div>
      <div className="page-header">
        <h1>Auditoría de alertas</h1>
        <p>Últimas alertas calculadas y emitidas por el motor de decisiones.</p>
      </div>

      {error && <div className="error-banner">{error}</div>}

      <div className="card">
        <div className="toolbar">
          <button className="btn" onClick={cargar}>
            Actualizar
          </button>
          <span className="muted" style={{ fontSize: 12 }}>
            {alertas.length} registros
          </span>
        </div>

        {cargando ? (
          <div className="empty-state">Cargando historial...</div>
        ) : alertas.length === 0 ? (
          <div className="empty-state">Todavía no se generó ninguna alerta.</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Fecha</th>
                <th>Parcela</th>
                <th>Usuario</th>
                <th>Evento</th>
                <th>Riesgo</th>
                <th>Generada</th>
              </tr>
            </thead>
            <tbody>
              {alertas.map((a) => (
                <tr key={a.id}>
                  <td>{new Date(a.fecha).toLocaleDateString('es-NI')}</td>
                  <td>#{a.parcelaId}</td>
                  <td>#{a.usuarioId}</td>
                  <td>{nombreEvento[a.eventoClimaticoId] ?? a.eventoClimaticoId}</td>
                  <td>
                    <RiesgoPill nivel={a.nivelRiesgo} />
                  </td>
                  <td className="muted">
                    {new Date(a.fechaGeneracion).toLocaleString('es-NI')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

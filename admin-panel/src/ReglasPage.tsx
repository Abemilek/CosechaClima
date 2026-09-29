import { useEffect, useMemo, useState } from 'react';
import { adminApi, ApiError, type Catalogo, type ReglaDecision } from './api';
import { RiesgoPill, EstadoPill } from './components';

function mapaDe(lista: Catalogo[]): Record<number, string> {
  const mapa: Record<number, string> = {};
  for (const item of lista) mapa[item.id] = item.nombre;
  return mapa;
}

export default function ReglasPage() {
  const [reglas, setReglas] = useState<ReglaDecision[]>([]);
  const [cultivos, setCultivos] = useState<Catalogo[]>([]);
  const [suelos, setSuelos] = useState<Catalogo[]>([]);
  const [eventos, setEventos] = useState<Catalogo[]>([]);
  const [etapas, setEtapas] = useState<Catalogo[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [soloActivas, setSoloActivas] = useState(false);
  const [editando, setEditando] = useState<ReglaDecision | null>(null);
  const [guardando, setGuardando] = useState(false);

  async function cargar() {
    setCargando(true);
    setError(null);
    try {
      const [r, c, s, e, et] = await Promise.all([
        adminApi.listarReglas(),
        adminApi.listarCultivos(),
        adminApi.listarTiposSuelo(),
        adminApi.listarEventos(),
        adminApi.listarEtapas(),
      ]);
      setReglas(r);
      setCultivos(c);
      setSuelos(s);
      setEventos(e);
      setEtapas(et);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'No se pudieron cargar las reglas.');
    } finally {
      setCargando(false);
    }
  }

  useEffect(() => {
    cargar();
  }, []);

  const nombreCultivo = useMemo(() => mapaDe(cultivos), [cultivos]);
  const nombreSuelo = useMemo(() => mapaDe(suelos), [suelos]);
  const nombreEvento = useMemo(() => mapaDe(eventos), [eventos]);
  const nombreEtapa = useMemo(() => mapaDe(etapas), [etapas]);

  const visibles = soloActivas ? reglas.filter((r) => r.activa) : reglas;

  async function alternarActiva(regla: ReglaDecision) {
    try {
      await adminApi.cambiarActivaRegla(regla.id, !regla.activa);
      setReglas((prev) =>
        prev.map((r) => (r.id === regla.id ? { ...r, activa: !r.activa } : r)),
      );
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'No se pudo cambiar el estado de la regla.');
    }
  }

  async function guardarEdicion() {
    if (!editando) return;
    setGuardando(true);
    try {
      await adminApi.actualizarRegla(editando.id, {
        nivelRiesgo: editando.nivelRiesgo,
        accion1: editando.accion1,
        accion2: editando.accion2,
        accion3: editando.accion3,
        descripcionAlerta: editando.descripcionAlerta,
      });
      setReglas((prev) => prev.map((r) => (r.id === editando.id ? editando : r)));
      setEditando(null);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'No se pudo guardar la regla.');
    } finally {
      setGuardando(false);
    }
  }

  return (
    <div>
      <div className="page-header">
        <h1>Reglas agroclimáticas</h1>
        <p>
          Umbrales por cultivo, evento climático, etapa fenológica y tipo de suelo. Desactivar
          una regla la excluye del motor de decisiones sin borrar su historial.
        </p>
      </div>

      {error && <div className="error-banner">{error}</div>}

      <div className="card">
        <div className="toolbar">
          <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13 }}>
            <input
              type="checkbox"
              checked={soloActivas}
              onChange={(e) => setSoloActivas(e.target.checked)}
            />
            Solo mostrar activas
          </label>
          <button className="btn" onClick={cargar}>
            Actualizar
          </button>
          <span className="muted" style={{ fontSize: 12 }}>
            {visibles.length} de {reglas.length} reglas
          </span>
        </div>

        {cargando ? (
          <div className="empty-state">Cargando reglas...</div>
        ) : visibles.length === 0 ? (
          <div className="empty-state">No hay reglas para mostrar.</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Cultivo</th>
                <th>Evento</th>
                <th>Etapa</th>
                <th>Suelo</th>
                <th>Riesgo</th>
                <th>Estado</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {visibles.map((r) => (
                <tr key={r.id}>
                  <td>{nombreCultivo[r.cultivoId] ?? r.cultivoId}</td>
                  <td>{nombreEvento[r.eventoClimaticoId] ?? r.eventoClimaticoId}</td>
                  <td>{nombreEtapa[r.etapaFenologicaId] ?? r.etapaFenologicaId}</td>
                  <td>{nombreSuelo[r.tipoSueloId] ?? r.tipoSueloId}</td>
                  <td>
                    <RiesgoPill nivel={r.nivelRiesgo} />
                  </td>
                  <td>
                    <EstadoPill activo={r.activa} textoOn="Activa" textoOff="Deshabilitada" />
                  </td>
                  <td className="text-right">
                    <button
                      className="btn btn-small"
                      onClick={() => setEditando(r)}
                      style={{ marginRight: 6 }}
                    >
                      Editar
                    </button>
                    <button
                      className={`btn btn-small ${r.activa ? 'btn-outline-red' : ''}`}
                      onClick={() => alternarActiva(r)}
                    >
                      {r.activa ? 'Deshabilitar' : 'Habilitar'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {editando && (
        <div className="modal-backdrop" onClick={() => setEditando(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <h3 style={{ fontSize: 18, marginBottom: 4 }}>Editar regla</h3>
            <p className="muted" style={{ marginTop: 0, fontSize: 13 }}>
              {nombreCultivo[editando.cultivoId]} · {nombreEvento[editando.eventoClimaticoId]} ·{' '}
              {nombreEtapa[editando.etapaFenologicaId]} · {nombreSuelo[editando.tipoSueloId]}
            </p>

            <div className="field">
              <label htmlFor="nivelRiesgo">Nivel de riesgo</label>
              <select
                id="nivelRiesgo"
                value={editando.nivelRiesgo}
                onChange={(e) => setEditando({ ...editando, nivelRiesgo: e.target.value })}
              >
                <option value="Bajo">Bajo</option>
                <option value="Medio">Medio</option>
                <option value="Alto">Alto</option>
              </select>
            </div>
            <div className="field">
              <label htmlFor="descripcion">Descripción de la alerta</label>
              <textarea
                id="descripcion"
                value={editando.descripcionAlerta}
                onChange={(e) => setEditando({ ...editando, descripcionAlerta: e.target.value })}
              />
            </div>
            <div className="field">
              <label htmlFor="accion1">Acción 1</label>
              <textarea
                id="accion1"
                value={editando.accion1}
                onChange={(e) => setEditando({ ...editando, accion1: e.target.value })}
              />
            </div>
            <div className="field">
              <label htmlFor="accion2">Acción 2</label>
              <textarea
                id="accion2"
                value={editando.accion2}
                onChange={(e) => setEditando({ ...editando, accion2: e.target.value })}
              />
            </div>
            <div className="field">
              <label htmlFor="accion3">Acción 3</label>
              <textarea
                id="accion3"
                value={editando.accion3}
                onChange={(e) => setEditando({ ...editando, accion3: e.target.value })}
              />
            </div>

            <div className="modal-actions">
              <button className="btn" onClick={() => setEditando(null)}>
                Cancelar
              </button>
              <button className="btn btn-primary" onClick={guardarEdicion} disabled={guardando}>
                {guardando ? 'Guardando...' : 'Guardar cambios'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

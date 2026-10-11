export function RiesgoPill({ nivel }: { nivel: string }) {
  const normal = nivel.trim().toLowerCase();
  const clase =
    normal === 'alto' ? 'pill pill-red' : normal === 'medio' ? 'pill pill-amber' : normal === 'bajo' ? 'pill pill-green' : 'pill pill-muted';
  return <span className={clase}>{nivel}</span>;
}

export function EstadoPill({ activo, textoOn, textoOff }: { activo: boolean; textoOn: string; textoOff: string }) {
  return <span className={`pill ${activo ? 'pill-green' : 'pill-muted'}`}>{activo ? textoOn : textoOff}</span>;
}

interface ConfirmModalProps {
  titulo: string;
  mensaje: string;
  confirmarTexto?: string;
  peligroso?: boolean;
  onConfirmar: () => void;
  onCancelar: () => void;
}

export function ConfirmModal({
  titulo,
  mensaje,
  confirmarTexto = 'Confirmar',
  peligroso,
  onConfirmar,
  onCancelar,
}: ConfirmModalProps) {
  return (
    <div className="modal-backdrop" onClick={onCancelar}>
      <div className="modal-card" onClick={(e) => e.stopPropagation()}>
        <h3 style={{ fontSize: 18, marginBottom: 8 }}>{titulo}</h3>
        <p className="muted" style={{ margin: 0 }}>
          {mensaje}
        </p>
        <div className="modal-actions">
          <button className="btn" onClick={onCancelar}>
            Cancelar
          </button>
          <button
            className={peligroso ? 'btn btn-outline-red' : 'btn btn-primary'}
            onClick={onConfirmar}
          >
            {confirmarTexto}
          </button>
        </div>
      </div>
    </div>
  );
}

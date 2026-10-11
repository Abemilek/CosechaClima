export const API_BASE_URL: string =
  (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/+$/, '') ||
  'http://localhost:8080';

// El access token vive SOLO en memoria (nunca en localStorage): un XSS no puede leerlo del
// almacenamiento y desaparece al cerrar la pestaña. La sesión larga la mantiene una cookie
// HttpOnly con el refresh token, que JavaScript no puede leer.
let tokenEnMemoria: string | null = null;

// Versiones anteriores del panel guardaban el token en localStorage: se borra si quedó algo.
try {
  localStorage.removeItem('cosechaclima_admin_token');
  localStorage.removeItem('cosechaclima_admin_sesion');
} catch {
  /* sin acceso a localStorage: nada que limpiar */
}

// Defensa CSRF para los endpoints que usan la cookie: una cabecera personalizada obliga al
// navegador a hacer preflight CORS, que el servidor solo acepta desde los orígenes configurados.
const CABECERA_CSRF = { 'X-Requested-With': 'cosechaclima-admin' };

type Suscriptor = () => void;
const suscriptoresExpiracion = new Set<Suscriptor>();

export function alExpirarSesion(cb: Suscriptor): () => void {
  suscriptoresExpiracion.add(cb);
  return () => suscriptoresExpiracion.delete(cb);
}

export function getToken(): string | null {
  return tokenEnMemoria;
}

export function setToken(token: string | null) {
  tokenEnMemoria = token;
}

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

let refrescando: Promise<LoginResponse | null> | null = null;

/** Pide un access token nuevo con la cookie de refresh. Una sola petición a la vez. */
export function refrescarSesion(): Promise<LoginResponse | null> {
  if (!refrescando) {
    refrescando = (async () => {
      try {
        const r = await fetch(`${API_BASE_URL}/api/auth/web/refresh`, {
          method: 'POST',
          credentials: 'include',
          headers: { ...CABECERA_CSRF },
        });
        if (!r.ok) {
          setToken(null);
          return null;
        }
        const datos = (await r.json()) as LoginResponse;
        if (!datos.esAdmin) {
          setToken(null);
          return null;
        }
        setToken(datos.token);
        return datos;
      } catch {
        // Sin red: no se puede saber si la sesión sigue viva; no se cierra por esto.
        return null;
      } finally {
        refrescando = null;
      }
    })();
  }
  return refrescando;
}

async function request<T>(
  path: string,
  options: RequestInit = {},
  yaReintentado = false,
): Promise<T> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...((options.headers as Record<string, string>) || {}),
  };

  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;

  let respuesta: Response;
  try {
    respuesta = await fetch(`${API_BASE_URL}${path}`, {
      ...options,
      headers,
      credentials: 'include',
    });
  } catch {
    throw new ApiError(0, 'No se pudo conectar con el servidor. Revisá tu conexión.');
  }

  if (respuesta.status === 401) {
    // El access token dura minutos: se intenta renovar una vez con la cookie antes de rendirse.
    if (!yaReintentado && (await refrescarSesion())) {
      return request<T>(path, options, true);
    }
    setToken(null);
    suscriptoresExpiracion.forEach((cb) => cb());
    throw new ApiError(401, 'Tu sesión expiró. Iniciá sesión de nuevo.');
  }

  if (respuesta.status === 204) return undefined as T;

  let cuerpo: unknown = null;
  const texto = await respuesta.text();
  if (texto) {
    try {
      cuerpo = JSON.parse(texto);
    } catch {
      cuerpo = texto;
    }
  }

  if (!respuesta.ok) {
    const mensaje =
      (cuerpo as { mensaje?: string; title?: string } | null)?.mensaje ??
      (cuerpo as { mensaje?: string; title?: string } | null)?.title ??
      `Error ${respuesta.status}`;
    throw new ApiError(respuesta.status, mensaje);
  }

  return cuerpo as T;
}

export const api = {
  get: <T>(path: string) => request<T>(path, { method: 'GET' }),
  post: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: 'POST', body: body ? JSON.stringify(body) : undefined }),
  put: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: 'PUT', body: body ? JSON.stringify(body) : undefined }),
};

export interface LoginResponse {
  token: string;
  expiraEnSegundos: number;
  nombre: string;
  email: string;
  fotoUrl: string | null;
  esAdmin: boolean;
}

export interface UsuarioAdmin {
  id: number;
  nombre: string;
  email: string;
  proveedor: string;
  fechaRegistro: string;
  activo: boolean;
  esAdmin: boolean;
}

export interface ReglaDecision {
  id: number;
  eventoClimaticoId: number;
  cultivoId: number;
  etapaFenologicaId: number;
  tipoSueloId: number;
  nivelRiesgo: string;
  accion1: string;
  accion2: string;
  accion3: string;
  descripcionAlerta: string;
  activa: boolean;
}

export interface Alerta {
  id: number;
  usuarioId: number;
  parcelaId: number;
  fecha: string;
  eventoClimaticoId: number;
  nivelRiesgo: string;
  accion1: string;
  accion2: string;
  accion3: string;
  descripcionAlerta: string;
  fechaGeneracion: string;
}

export interface Catalogo {
  id: number;
  nombre: string;
  descripcion?: string | null;
}

export async function login(email: string, password: string): Promise<LoginResponse> {
  // El servidor exige rol de administrador en este endpoint y deja el refresh token en una cookie HttpOnly.
  const datos = await api.post<LoginResponse>('/api/auth/web/login', { email, password });
  setToken(datos.token);
  return datos;
}

/** Al abrir el panel: si la cookie de refresh sigue vigente, recupera la sesión sin pedir clave. */
export async function restaurarSesion(): Promise<LoginResponse | null> {
  return refrescarSesion();
}

export async function logout(): Promise<void> {
  try {
    await fetch(`${API_BASE_URL}/api/auth/web/logout`, {
      method: 'POST',
      credentials: 'include',
      headers: { ...CABECERA_CSRF },
    });
  } catch {
    /* si no hay red, igualmente se descarta el token local */
  }
  setToken(null);
}

export const adminApi = {
  listarUsuarios: () => api.get<UsuarioAdmin[]>('/api/admin/usuarios'),
  cambiarRol: (id: number, esAdmin: boolean) =>
    api.put<void>(`/api/admin/usuarios/${id}/rol`, { esAdmin }),
  cambiarEstado: (id: number, activo: boolean) =>
    api.put<void>(`/api/admin/usuarios/${id}/estado`, { activo }),

  listarReglas: () => api.get<ReglaDecision[]>('/api/reglas'),
  actualizarRegla: (id: number, datos: {
    nivelRiesgo: string; accion1: string; accion2: string; accion3: string; descripcionAlerta: string;
  }) => api.put<void>(`/api/reglas/${id}`, datos),
  cambiarActivaRegla: (id: number, activa: boolean) =>
    api.put<void>(`/api/reglas/${id}/activa`, { activa }),

  listarAlertas: (limite = 100) => api.get<Alerta[]>(`/api/admin/alertas?limite=${limite}`),

  listarCultivos: () => api.get<Catalogo[]>('/api/catalogos/cultivos'),
  listarTiposSuelo: () => api.get<Catalogo[]>('/api/catalogos/tipos-suelo'),
  listarEventos: () => api.get<Catalogo[]>('/api/catalogos/eventos-climaticos'),
  listarEtapas: () => api.get<Catalogo[]>('/api/catalogos/etapas-fenologicas'),
};

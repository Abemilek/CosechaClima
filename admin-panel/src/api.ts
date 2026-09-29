const STORAGE_KEY = 'cosechaclima_admin_token';

export const API_BASE_URL: string =
  (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/+$/, '') ||
  'http://localhost:8080';

let tokenEnMemoria: string | null = localStorage.getItem(STORAGE_KEY);

export function getToken(): string | null {
  return tokenEnMemoria;
}

export function setToken(token: string | null) {
  tokenEnMemoria = token;
  if (token) localStorage.setItem(STORAGE_KEY, token);
  else localStorage.removeItem(STORAGE_KEY);
}

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function request<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...((options.headers as Record<string, string>) || {}),
  };

  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;

  let respuesta: Response;
  try {
    respuesta = await fetch(`${API_BASE_URL}${path}`, { ...options, headers });
  } catch {
    throw new ApiError(0, 'No se pudo conectar con el servidor. Revisá tu conexión.');
  }

  if (respuesta.status === 401) {
    setToken(null);
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
  const datos = await api.post<LoginResponse>('/api/auth/login', { email, password });
  if (!datos.esAdmin) {
    throw new ApiError(403, 'Esta cuenta no tiene permisos de administrador.');
  }
  setToken(datos.token);
  return datos;
}

export function logout() {
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

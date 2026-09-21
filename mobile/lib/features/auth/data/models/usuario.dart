class LoginResponse {
  final String token;
  final String nombre;
  final String email;
  final String? fotoUrl;
  final bool esAdmin;

  LoginResponse({
    required this.token,
    required this.nombre,
    required this.email,
    this.fotoUrl,
    required this.esAdmin,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    token: json['token'] as String,
    nombre: json['nombre'] as String,
    email: json['email'] as String? ?? '',
    fotoUrl: json['fotoUrl'] as String?,
    esAdmin: json['esAdmin'] as bool? ?? false,
  );
}

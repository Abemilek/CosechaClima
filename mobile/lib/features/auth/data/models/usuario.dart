class LoginResponse {
  final String token;
  final String nombre;

  LoginResponse({required this.token, required this.nombre});

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    token: json['token'] as String,
    nombre: json['nombre'] as String,
  );
}

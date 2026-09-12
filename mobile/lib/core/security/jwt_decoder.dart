import 'dart:convert';

class JwtDecoder {
  JwtDecoder._();

  static const _roleClaimUri =
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';

  static Map<String, dynamic> payload(String token) {
    final partes = token.split('.');
    if (partes.length != 3) return {};
    try {
      final normalizado = base64Url.normalize(partes[1]);
      final decodedBytes = base64Url.decode(normalizado);
      final decodedString = utf8.decode(decodedBytes);
      final decoded = jsonDecode(decodedString);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  static bool esAdmin(String token) {
    final claims = payload(token);
    final rol = claims[_roleClaimUri] ?? claims['role'];
    if (rol is String) return rol == 'Admin';
    if (rol is List) return rol.contains('Admin');
    return false;
  }
}

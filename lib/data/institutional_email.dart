/// Institutional addresses accepted by the school application.
abstract final class InstitutionalEmail {
  static const domain = 'china.tecnm.mx';
  static final _pattern = RegExp(
    r'^[a-z0-9][a-z0-9._%+-]*@china\.tecnm\.mx$',
    caseSensitive: false,
  );
  static String normalize(String value) => value.trim().toLowerCase();
  static bool isValid(String? value) =>
      value != null && _pattern.hasMatch(normalize(value));
  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Escribe tu correo institucional.';
    }
    return isValid(value) ? null : 'Usa una cuenta @$domain.';
  }
}

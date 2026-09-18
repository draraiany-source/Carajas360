/// Validadores de autenticação/cadastro (testáveis, sem dependência de UI).
abstract final class AuthValidators {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidEmail(String email) => _emailRe.hasMatch(email.trim());

  static String? emailError(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Campo obrigatório';
    if (!isValidEmail(email)) return 'E-mail inválido';
    return null;
  }

  static String? passwordError(String? value, {int minLength = 6}) {
    final pass = value ?? '';
    if (pass.isEmpty) return 'Campo obrigatório';
    if (pass.length < minLength) return 'Mínimo de $minLength caracteres';
    return null;
  }

  static String? confirmPasswordError(String? value, String password) {
    if ((value ?? '').isEmpty) return 'Confirme a senha';
    if (value != password) return 'As senhas não coincidem';
    return null;
  }

  static String? cpfError(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Campo obrigatório';
    if (!isValidCpf(digits)) return 'CPF inválido';
    return null;
  }

  /// Validação matemática do CPF (dígitos verificadores + rejeita sequências).
  static bool isValidCpf(String? value) {
    final cpf = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += int.parse(cpf[i]) * (10 - i);
    }
    var check = (sum * 10) % 11;
    if (check == 10) check = 0;
    if (check != int.parse(cpf[9])) return false;
    sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += int.parse(cpf[i]) * (11 - i);
    }
    check = (sum * 10) % 11;
    if (check == 10) check = 0;
    return check == int.parse(cpf[10]);
  }

  static String? phoneError(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Telefone inválido';
    return null;
  }
}

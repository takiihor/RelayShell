/// Keeps secret material out of logs and error surfaces (SPEC 35, 44.2, 44.6).
///
/// Two complementary tools:
///
/// * [Redactor] scrubs strings that are about to be logged.
/// * [Sensitive] wraps a value so that accidentally interpolating it into a
///   string produces a placeholder instead of the secret.
library;

/// Removes recognisable secret material from text destined for a log.
///
/// This is a backstop, not a licence to log freely: the app does not log
/// terminal output or full commands by default. It exists because a stack trace
/// or third-party error string can carry a key or password without asking.
class Redactor {
  const Redactor();

  static const String placeholder = '[redacted]';

  static final List<RegExp> _patterns = [
    // PEM blocks, including the OpenSSH private key format.
    RegExp(
      r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----',
    ),
    // `password=...`, `passphrase: ...`, `secret = ...`, `token=...`.
    RegExp(
      r'\b(password|passphrase|passwd|secret|token|api[_-]?key)\b\s*[:=]\s*\S+',
      caseSensitive: false,
    ),
    // Authorization headers. Matched to end of line rather than to the first
    // token, because the scheme and the credential are separate words
    // ("Bearer abc123") and stopping early would redact only the scheme.
    RegExp(r'\bAuthorization\s*:\s*.+', caseSensitive: false),
  ];

  /// Returns [input] with any recognised secret replaced.
  String scrub(String input) {
    var result = input;
    for (final pattern in _patterns) {
      result = result.replaceAllMapped(pattern, (match) {
        final text = match.group(0)!;
        // Keep the label so a log still says *what* was redacted.
        final separator = RegExp(r'[:=]').firstMatch(text);
        if (separator == null) return placeholder;
        return '${text.substring(0, separator.end)} $placeholder';
      });
    }
    return result;
  }

  /// Masks all but the last [visible] characters, for showing an identifier.
  String mask(String value, {int visible = 4}) {
    if (value.length <= visible) return '*' * value.length;
    return '${'*' * (value.length - visible)}${value.substring(value.length - visible)}';
  }
}

/// A value that must never appear in a log line or error message.
///
/// [toString] deliberately returns a placeholder, so `'$secret'` and
/// `print(secret)` cannot leak. Call [expose] at the exact point of use.
class Sensitive<T> {
  const Sensitive(this._value);

  final T _value;

  /// Returns the wrapped value. Every call site is a deliberate decision.
  T expose() => _value;

  @override
  String toString() => 'Sensitive<$T>(${Redactor.placeholder})';
}

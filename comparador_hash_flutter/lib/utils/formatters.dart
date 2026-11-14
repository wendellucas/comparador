/// Formata um número inteiro com separador de milhar em estilo pt-BR (`1.234.567`).
String formatThousands(int value) {
  final isNegative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  return isNegative ? '-$buffer' : buffer.toString();
}

/// Formata tamanhos em bytes nas unidades B, KB, MB ou GB acompanhados da contagem exata.
String formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final exact = '${formatThousands(bytes)} B';
  if (bytes < 1048576) {
    return '${(bytes / 1024).toStringAsFixed(2)} KB ($exact)';
  }
  if (bytes < 1073741824) {
    return '${(bytes / 1048576).toStringAsFixed(2)} MB ($exact)';
  }
  return '${(bytes / 1073741824).toStringAsFixed(2)} GB ($exact)';
}

/// Formata [DateTime] no padrão brasileiro local `dd/MM/yyyy HH:mm`.
String formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

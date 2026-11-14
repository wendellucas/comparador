import 'package:crypto/crypto.dart' as crypto;

/// Algoritmos criptográficos/checksum suportados para comparação de arquivos.
///
/// Todos os algoritmos são acumulados em paralelo durante uma única leitura em
/// streaming ([MultiHashAccumulator]), permitindo alternar o algoritmo na UI
/// sem precisar reler o arquivo do disco ou de permissões temporárias.
enum HashAlgorithm {
  sha256('SHA-256', crypto.sha256),
  md5('MD5', crypto.md5),
  sha1('SHA-1', crypto.sha1),
  sha512('SHA-512', crypto.sha512);

  const HashAlgorithm(this.label, this.digestAlgorithm);

  /// Nome legível exibido na interface (chips e cabeçalho do cartão).
  final String label;

  /// Implementação do algoritmo no pacote `package:crypto`.
  final crypto.Hash digestAlgorithm;
}

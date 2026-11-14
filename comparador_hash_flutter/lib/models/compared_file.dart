import 'package:cross_file/cross_file.dart';

import 'hash_algorithm.dart';

/// Ciclo de vida de um slot individual de comparação (Arquivo 1 ou Arquivo 2).
enum SlotStatus {
  empty,
  loading,
  ready,
  error,
}

/// Metadados e mapa completo de hashes calculados para um arquivo carregado.
class ComparedFile {
  const ComparedFile({
    required this.name,
    required this.sizeBytes,
    required this.hashes,
    this.localPath,
    this.directoryLabel,
    this.lastModified,
    this.sourceXFile,
  });

  /// Nome do arquivo exibido em destaque no cartão.
  final String name;

  /// Caminho real no sistema de arquivos local, quando disponível (Windows/local IO).
  final String? localPath;

  /// Subtítulo amigável indicando a pasta pai ou origem (Web, Android, etc.).
  final String? directoryLabel;

  /// Quantidade exata de bytes processados no cálculo dos hashes.
  final int sizeBytes;

  /// Data/hora da última modificação informada pelo sistema ou navegador.
  final DateTime? lastModified;

  /// Mapa com os hashes em hexadecimal minúsculo para todos os algoritmos suportados.
  final Map<HashAlgorithm, String> hashes;

  /// Referência persistente usada em "Recomparar Agora" quando a fonte suporta releitura.
  ///
  /// Para drops efêmeros sem caminho local (ex.: arraste Android/iOS), permanece nulo
  /// porque a concessão temporária do SO expira ao final do callback `onDrop`.
  final XFile? sourceXFile;

  /// Retorna o hash correspondente ao [algorithm] selecionado no momento.
  String? hashFor(HashAlgorithm algorithm) => hashes[algorithm];
}

/// Estado imutável consumido pelos cartões de arraste e pelo banner de veredito.
class FileSlotState {
  const FileSlotState._({
    required this.status,
    this.file,
    this.pendingFileName,
    this.progress,
    this.errorMessage,
  });

  const FileSlotState.empty() : this._(status: SlotStatus.empty);

  const FileSlotState.loading({
    String? pendingFileName,
    double? progress,
  }) : this._(
         status: SlotStatus.loading,
         pendingFileName: pendingFileName,
         progress: progress,
       );

  const FileSlotState.ready(ComparedFile file)
    : this._(status: SlotStatus.ready, file: file);

  const FileSlotState.error(String message, {String? fileName})
    : this._(
        status: SlotStatus.error,
        pendingFileName: fileName,
        errorMessage: message,
      );

  final SlotStatus status;
  final ComparedFile? file;
  final String? pendingFileName;
  final double? progress;
  final String? errorMessage;

  bool get isEmpty => status == SlotStatus.empty;
  bool get isLoading => status == SlotStatus.loading;
  bool get isReady => status == SlotStatus.ready && file != null;
  bool get hasError => status == SlotStatus.error;
}

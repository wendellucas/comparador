import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/hash_algorithm.dart';

/// Resultado consolidado do processamento em passagem única de um arquivo.
class HashComputationResult {
  const HashComputationResult({
    required this.hashes,
    required this.bytesRead,
  });

  final Map<HashAlgorithm, String> hashes;
  final int bytesRead;
}

class _SingleDigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) {
    digest = data;
  }

  @override
  void close() {}
}

/// Acumula blocos de bytes para todos os algoritmos em [HashAlgorithm.values]
/// simultaneamente em uma única leitura sequencial.
class MultiHashAccumulator {
  MultiHashAccumulator() {
    for (final algo in HashAlgorithm.values) {
      final sink = _SingleDigestSink();
      _digestSinks[algo] = sink;
      _byteSinks[algo] = algo.digestAlgorithm.startChunkedConversion(sink);
    }
  }

  final Map<HashAlgorithm, _SingleDigestSink> _digestSinks = {};
  final Map<HashAlgorithm, ByteConversionSink> _byteSinks = {};
  int _bytesRead = 0;

  int get bytesRead => _bytesRead;

  /// Alimenta um bloco de bytes não vazio em todos os sinks ativos.
  void addChunk(List<int> chunk) {
    if (chunk.isEmpty) return;
    _bytesRead += chunk.length;
    for (final sink in _byteSinks.values) {
      sink.add(chunk);
    }
  }

  /// Finaliza os digests e devolve os valores em hexadecimal minúsculo.
  HashComputationResult finish() {
    final hashes = <HashAlgorithm, String>{};
    for (final algo in HashAlgorithm.values) {
      _byteSinks[algo]!.close();
      hashes[algo] = _digestSinks[algo]!.digest.toString().toLowerCase();
    }
    return HashComputationResult(hashes: hashes, bytesRead: _bytesRead);
  }
}

/// Calcula todos os hashes a partir de qualquer [Stream] de bytes sem carregar
/// o arquivo inteiro em memória.
Future<HashComputationResult> computeAllHashesFromStream(
  Stream<List<int>> stream, {
  int? totalBytes,
  void Function(double? progress)? onProgress,
}) async {
  final accumulator = MultiHashAccumulator();
  var bytesSinceLastYield = 0;
  var lastReportedBytes = 0;
  const yieldThresholdBytes = 2 * 1024 * 1024;
  const progressStepBytes = 256 * 1024;

  onProgress?.call(totalBytes != null && totalBytes > 0 ? 0.0 : null);

  await for (final chunk in stream) {
    if (chunk.isEmpty) continue;
    accumulator.addChunk(chunk);
    bytesSinceLastYield += chunk.length;

    final totalRead = accumulator.bytesRead;
    if (totalRead - lastReportedBytes >= progressStepBytes) {
      lastReportedBytes = totalRead;
      if (totalBytes != null && totalBytes > 0) {
        onProgress?.call((totalRead / totalBytes).clamp(0.0, 1.0));
      } else {
        onProgress?.call(null);
      }
    }

    // Cede controle periodicamente ao loop de eventos para manter Web e UI responsivos.
    if (bytesSinceLastYield >= yieldThresholdBytes) {
      bytesSinceLastYield = 0;
      await Future<void>.delayed(Duration.zero);
    }
  }

  final result = accumulator.finish();
  onProgress?.call(1.0);
  return result;
}

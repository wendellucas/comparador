import 'dart:convert';

import 'package:comparador_hash/main.dart';
import 'package:comparador_hash/models/compared_file.dart';
import 'package:comparador_hash/models/hash_algorithm.dart';
import 'package:comparador_hash/services/hash_service.dart';
import 'package:comparador_hash/utils/formatters.dart';
import 'package:comparador_hash/widgets/app_logo.dart';
import 'package:comparador_hash/widgets/comparison_banner.dart';
import 'package:desktop_drop/src/native_transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    // Evita carregar desktop_drop_plugin.dll em testes headless da VM Dart.
    final transport = NativeTransport.testing()
      ..invokeHandler = (call) async => {'view': 0, 'generation': 1};
    NativeTransport.debugOverride = transport;
  });

  group('Formatters', () {
    test('formatThousands insere separadores de milhar pt-BR', () {
      expect(formatThousands(0), '0');
      expect(formatThousands(999), '999');
      expect(formatThousands(1000), '1.000');
      expect(formatThousands(1234567), '1.234.567');
      expect(formatThousands(-4200), '-4.200');
    });

    test('formatFileSize formata bytes, KB e MB corretamente', () {
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(1536), '1.50 KB (1.536 B)');
      expect(formatFileSize(2 * 1024 * 1024), '2.00 MB (2.097.152 B)');
    });

    test('formatDateTime formata data e hora locais', () {
      final dt = DateTime(2026, 4, 7, 9, 5);
      expect(formatDateTime(dt), '07/04/2026 09:05');
    });
  });

  group('HashService', () {
    test('calcula digests padrão para stream vazio', () async {
      final result = await computeAllHashesFromStream(
        const Stream<List<int>>.empty(),
        totalBytes: 0,
      );

      expect(result.bytesRead, 0);
      expect(
        result.hashes[HashAlgorithm.sha256],
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        result.hashes[HashAlgorithm.md5],
        'd41d8cd98f00b204e9800998ecf8427e',
      );
      expect(
        result.hashes[HashAlgorithm.sha1],
        'da39a3ee5e6b4b0d3255bfef95601890afd80709',
      );
      expect(
        result.hashes[HashAlgorithm.sha512],
        'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce'
        '47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e',
      );
    });

    test('calcula digests padrão em múltiplos blocos', () async {
      final progressUpdates = <double?>[];
      final stream = Stream<List<int>>.fromIterable([
        utf8.encode('a'),
        utf8.encode('b'),
        utf8.encode('c'),
      ]);

      final result = await computeAllHashesFromStream(
        stream,
        totalBytes: 3,
        onProgress: progressUpdates.add,
      );

      expect(result.bytesRead, 3);
      expect(
        result.hashes[HashAlgorithm.sha256],
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        result.hashes[HashAlgorithm.md5],
        '900150983cd24fb0d6963f7d28e17f72',
      );
      expect(
        result.hashes[HashAlgorithm.sha1],
        'a9993e364706816aba3e25717850c26c9cd0d89d',
      );
      expect(progressUpdates.last, 1.0);
    });
  });

  group('ComparisonBanner', () {
    ComparedFile makeFile({
      required String name,
      required int sizeBytes,
      required String sha256,
      String? localPath,
    }) {
      return ComparedFile(
        name: name,
        sizeBytes: sizeBytes,
        localPath: localPath,
        hashes: {
          HashAlgorithm.sha256: sha256,
          HashAlgorithm.md5: sha256.substring(0, 32),
          HashAlgorithm.sha1: sha256.substring(0, 40),
          HashAlgorithm.sha512: '$sha256$sha256',
        },
      );
    }

    testWidgets('exibe veredito idêntico quando os hashes coincidem', (
      tester,
    ) async {
      const digest =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final slot1 = FileSlotState.ready(
        makeFile(
          name: 'a.bin',
          sizeBytes: 128,
          sha256: digest,
          localPath: '/tmp/a.bin',
        ),
      );
      final slot2 = FileSlotState.ready(
        makeFile(
          name: 'b.bin',
          sizeBytes: 128,
          sha256: digest,
          localPath: '/tmp/b.bin',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComparisonBanner(
              slot1: slot1,
              slot2: slot2,
              algorithm: HashAlgorithm.sha256,
            ),
          ),
        ),
      );

      expect(find.textContaining('OS ARQUIVOS SÃO IDÊNTICOS!'), findsOneWidget);
    });

    testWidgets('exibe veredito diferente quando os hashes divergem', (
      tester,
    ) async {
      final slot1 = FileSlotState.ready(
        makeFile(
          name: 'a.bin',
          sizeBytes: 100,
          sha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      );
      final slot2 = FileSlotState.ready(
        makeFile(
          name: 'b.bin',
          sizeBytes: 100,
          sha256:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComparisonBanner(
              slot1: slot1,
              slot2: slot2,
              algorithm: HashAlgorithm.sha256,
            ),
          ),
        ),
      );

      expect(find.textContaining('OS ARQUIVOS SÃO DIFERENTES!'), findsOneWidget);
      expect(find.textContaining('mesmo tamanho'), findsOneWidget);
    });
  });

  group('ComparadorHashApp UI', () {
    testWidgets('exibe splash com logo e v0.2 e transiciona para HomeScreen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const ComparadorHashApp());

      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.text('v0.2'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.text('Comparador de Arquivos por Hash'), findsWidgets);
      expect(find.text('ARQUIVO 1'), findsOneWidget);
      expect(find.text('ARQUIVO 2'), findsOneWidget);
      expect(find.text('v0.2'), findsOneWidget);
      expect(find.text('Aguardando arquivos para comparação'), findsOneWidget);

      await tester.tap(find.text('MD5'));
      await tester.pumpAndSettle();

      expect(find.textContaining('(MD5)'), findsOneWidget);
    });

    testWidgets('renderiza sem overflow no celular e em janela livre Samsung DeX', (
      tester,
    ) async {
      // Celular retrato
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const ComparadorHashApp(showSplash: false));
      await tester.pumpAndSettle();

      expect(find.text('ARQUIVO 1'), findsOneWidget);
      expect(find.text('ARQUIVO 2'), findsOneWidget);
      expect(find.text('v0.2'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Janela redimensionada em modo Samsung DeX
      await tester.binding.setSurfaceSize(const Size(640, 520));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

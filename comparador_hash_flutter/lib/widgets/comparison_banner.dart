import 'package:flutter/material.dart';

import '../models/compared_file.dart';
import '../models/hash_algorithm.dart';
import '../utils/formatters.dart';

/// Banner dinâmico que resume em tempo real o veredito da comparação entre
/// os dois slots com base no algoritmo de hash selecionado.
class ComparisonBanner extends StatelessWidget {
  const ComparisonBanner({
    super.key,
    required this.slot1,
    required this.slot2,
    required this.algorithm,
  });

  final FileSlotState slot1;
  final FileSlotState slot2;
  final HashAlgorithm algorithm;

  @override
  Widget build(BuildContext context) {
    final visual = _resolveVisualState();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: visual.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: visual.borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: visual.iconBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(visual.icon, color: visual.iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visual.title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: visual.titleColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  visual.subtitle,
                  style: TextStyle(
                    fontSize: 12.8,
                    height: 1.35,
                    color: visual.subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _BannerVisualState _resolveVisualState() {
    if (slot1.isLoading || slot2.isLoading) {
      return const _BannerVisualState(
        backgroundColor: Color(0xFF1E293B),
        borderColor: Color(0xFF3B82F6),
        iconBackgroundColor: Color(0xFF0F172A),
        iconColor: Color(0xFF60A5FA),
        icon: Icons.sync_rounded,
        title: 'Calculando hash dos arquivos...',
        titleColor: Color(0xFF93C5FD),
        subtitle:
            'Aguarde enquanto a assinatura criptográfica é processada.',
        subtitleColor: Color(0xFF94A3B8),
      );
    }

    if (!slot1.isReady && !slot2.isReady) {
      return const _BannerVisualState(
        backgroundColor: Color(0xFF1E293B),
        borderColor: Color(0xFF334155),
        iconBackgroundColor: Color(0xFF0F172A),
        iconColor: Color(0xFF94A3B8),
        icon: Icons.balance_rounded,
        title: 'Aguardando arquivos para comparação',
        titleColor: Color(0xFFE2E8F0),
        subtitle:
            'Arraste dois arquivos (individualmente ou os dois juntos de uma vez) ou toque nas áreas acima para verificar se possuem o mesmo hash.',
        subtitleColor: Color(0xFF94A3B8),
      );
    }

    if (!slot1.isReady || !slot2.isReady) {
      final missing = !slot1.isReady ? '1º arquivo' : '2º arquivo';
      return _BannerVisualState(
        backgroundColor: const Color(0xFF1E293B),
        borderColor: const Color(0xFF3B82F6),
        iconBackgroundColor: const Color(0xFF0F172A),
        iconColor: const Color(0xFF60A5FA),
        icon: Icons.hourglass_top_rounded,
        title: 'Aguardando o $missing...',
        titleColor: const Color(0xFF93C5FD),
        subtitle:
            'Arraste ou selecione o outro arquivo na área ao lado para concluir a comparação.',
        subtitleColor: const Color(0xFF94A3B8),
      );
    }

    final file1 = slot1.file!;
    final file2 = slot2.file!;
    final hash1 = file1.hashFor(algorithm);
    final hash2 = file2.hashFor(algorithm);

    if (hash1 == hash2 && hash1 != null) {
      final samePath =
          file1.localPath != null &&
          file2.localPath != null &&
          file1.localPath!.toLowerCase() == file2.localPath!.toLowerCase();

      return _BannerVisualState(
        backgroundColor: const Color(0xFF064E3B),
        borderColor: const Color(0xFF10B981),
        iconBackgroundColor: const Color(0xFF065F46),
        iconColor: const Color(0xFF6EE7B7),
        icon: Icons.check_circle_rounded,
        title: 'OS ARQUIVOS SÃO IDÊNTICOS! (Hashes ${algorithm.label} iguais)',
        titleColor: const Color(0xFF6EE7B7),
        subtitle: samePath
            ? 'Nota: Ambos os lados apontam para exatamente o mesmo caminho de arquivo no disco.'
            : 'O conteúdo binário dos dois arquivos é 100% igual ($hash1).',
        subtitleColor: const Color(0xFFA7F3D0),
      );
    }

    final diffBytes = (file1.sizeBytes - file2.sizeBytes).abs();
    final diffText = file1.sizeBytes != file2.sizeBytes
        ? 'Os hashes não coincidem e os arquivos possuem tamanhos diferentes (diferença de ${formatThousands(diffBytes)} bytes).'
        : 'Os arquivos têm o mesmo tamanho, mas seus conteúdos e hashes ${algorithm.label} são diferentes.';

    return _BannerVisualState(
      backgroundColor: const Color(0xFF450A0A),
      borderColor: const Color(0xFFEF4444),
      iconBackgroundColor: const Color(0xFF7F1D1D),
      iconColor: const Color(0xFFFCA5A5),
      icon: Icons.cancel_rounded,
      title: 'OS ARQUIVOS SÃO DIFERENTES! (Hashes ${algorithm.label} distintos)',
      titleColor: const Color(0xFFFCA5A5),
      subtitle: diffText,
      subtitleColor: const Color(0xFFFECACA),
    );
  }
}

class _BannerVisualState {
  const _BannerVisualState({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.titleColor,
    required this.subtitle,
    required this.subtitleColor,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final IconData icon;
  final String title;
  final Color titleColor;
  final String subtitle;
  final Color subtitleColor;
}

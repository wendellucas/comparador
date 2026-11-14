import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/compared_file.dart';
import '../models/hash_algorithm.dart';
import '../utils/formatters.dart';
import 'dashed_border_painter.dart';

/// Cartão interativo responsável por um slot de arquivo (1 ou 2).
///
/// Combina área de arraste nativa ([DropTarget]) compatível com Windows, Web,
/// Android (incluindo janelas do Samsung DeX) e iOS com seleção por clique/toque,
/// exibição de metadados, hash selecionável e botão de cópia rápida.
class FileDropCard extends StatefulWidget {
  const FileDropCard({
    super.key,
    required this.slotNumber,
    required this.title,
    required this.accentColor,
    required this.slotState,
    required this.algorithm,
    required this.onBrowse,
    required this.onDropItems,
    required this.onClear,
  });

  final int slotNumber;
  final String title;
  final Color accentColor;
  final FileSlotState slotState;
  final HashAlgorithm algorithm;
  final VoidCallback onBrowse;
  final Future<void> Function(List<DropItem> items) onDropItems;
  final VoidCallback onClear;

  @override
  State<FileDropCard> createState() => _FileDropCardState();
}

class _FileDropCardState extends State<FileDropCard> {
  bool _isDragOver = false;
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void didUpdateWidget(covariant FileDropCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slotState.file != widget.slotState.file ||
        oldWidget.algorithm != widget.algorithm) {
      _resetCopiedFeedback();
    }
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  void _resetCopiedFeedback() {
    _copiedTimer?.cancel();
    if (_copied) {
      setState(() => _copied = false);
    }
  }

  Future<void> _copyHash(String hashValue) async {
    await Clipboard.setData(ClipboardData(text: hashValue));
    _copiedTimer?.cancel();
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  Future<void> _handleDrop(DropDetails details) async {
    if (mounted && _isDragOver) {
      setState(() => _isDragOver = false);
    }
    // Aguarda toda a leitura dentro do callback para preservar permissões temporárias do SO.
    await widget.onDropItems(details.items);
  }

  @override
  Widget build(BuildContext context) {
    final isDashed = !widget.slotState.isReady && !widget.slotState.isLoading;
    final borderColor = _resolveBorderColor();
    final backgroundColor = _isDragOver
        ? Color.alphaBlend(
            widget.accentColor.withValues(alpha: 0.14),
            const Color(0xFF1E293B),
          )
        : const Color(0xFF1E293B);

    return DropTarget(
      // Aceita arquivos e diretórios no hover para exibir aviso claro caso o usuário solte uma pasta.
      acceptedKinds: const {DropItemKind.file, DropItemKind.directory},
      behavior: HitTestBehavior.opaque,
      onEnter: (_) {
        if (mounted && !_isDragOver) {
          setState(() => _isDragOver = true);
        }
      },
      onLeave: () {
        if (mounted && _isDragOver) {
          setState(() => _isDragOver = false);
        }
      },
      onDrop: _handleDrop,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: CustomPaint(
          painter: DropCardBorderPainter(
            color: borderColor,
            dashed: isDashed && !_isDragOver,
            strokeWidth: _isDragOver ? 2.4 : 1.8,
            radius: 14,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCardHeader(),
                const SizedBox(height: 14),
                _buildBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _resolveBorderColor() {
    if (_isDragOver) {
      return widget.accentColor;
    }
    if (widget.slotState.hasError) {
      return const Color(0xFFEF4444);
    }
    if (widget.slotState.isLoading || widget.slotState.isReady) {
      return widget.accentColor.withValues(alpha: 0.85);
    }
    return const Color(0xFF334155);
  }

  Widget _buildCardHeader() {
    final canClear = !widget.slotState.isEmpty && !widget.slotState.isLoading;

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.accentColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            '${widget.slotNumber}',
            style: TextStyle(
              color: widget.accentColor,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              color: widget.accentColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
        ),
        if (canClear) ...[
          IconButton(
            onPressed: widget.onClear,
            tooltip: 'Remover arquivo deste slot',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF94A3B8),
              padding: const EdgeInsets.all(6),
            ),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
          const SizedBox(width: 4),
        ],
        OutlinedButton.icon(
          onPressed: widget.slotState.isLoading ? null : widget.onBrowse,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE2E8F0),
            backgroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFF334155)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.folder_open_rounded, size: 16),
          label: Text(
            widget.slotState.isReady ? 'Trocar...' : 'Procurar...',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (widget.slotState.status) {
      case SlotStatus.empty:
        return _buildEmptyBody();
      case SlotStatus.loading:
        return _buildLoadingBody();
      case SlotStatus.error:
        return _buildErrorBody();
      case SlotStatus.ready:
        return _buildReadyBody(widget.slotState.file!);
    }
  }

  Widget _buildEmptyBody() {
    final slotLabel = widget.slotNumber == 1 ? '1º arquivo' : '2º arquivo';

    // MouseRegion melhora a resposta tátil com mouse/touchpad em Windows, Web e Samsung DeX.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onBrowse,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 196),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: _isDragOver ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 160),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(
                        alpha: _isDragOver ? 0.22 : 0.12,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      _isDragOver
                          ? Icons.file_download_done_rounded
                          : Icons.upload_file_rounded,
                      color: widget.accentColor,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isDragOver
                      ? 'Solte para carregar no $slotLabel'
                      : 'Arraste o $slotLabel aqui',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ou clique aqui para selecionar (pode escolher 1 ou 2 arquivos)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBody() {
    final progress = widget.slotState.progress;
    final name = widget.slotState.pendingFileName ?? 'Processando arquivo...';

    return Container(
      constraints: const BoxConstraints(minHeight: 196),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              strokeWidth: 3.2,
              valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFF0F172A),
              valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progress != null
                ? 'Calculando hashes... ${(progress * 100).round()}%'
                : 'Lendo arquivo e calculando hashes...',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBody() {
    final message =
        widget.slotState.errorMessage ?? 'Não foi possível ler o item.';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onBrowse,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 196),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF450A0A),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFCA5A5),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFECACA),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Arraste outro arquivo ou clique para tentar novamente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadyBody(ComparedFile file) {
    final hashValue = file.hashFor(widget.algorithm) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.insert_drive_file_rounded,
                color: widget.accentColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    file.name,
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (file.directoryLabel != null &&
                      file.directoryLabel!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    SelectableText(
                      file.directoryLabel!,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetadataChip(
              icon: Icons.data_usage_rounded,
              label: formatFileSize(file.sizeBytes),
            ),
            if (file.lastModified != null)
              _MetadataChip(
                icon: Icons.schedule_rounded,
                label: 'Modificado: ${formatDateTime(file.lastModified!)}',
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.algorithm.label,
                      style: TextStyle(
                        color: widget.accentColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: hashValue.isEmpty
                        ? null
                        : () => _copyHash(hashValue),
                    style: TextButton.styleFrom(
                      foregroundColor: _copied
                          ? const Color(0xFF34D399)
                          : const Color(0xFFCBD5E1),
                      backgroundColor: _copied
                          ? const Color(0xFF064E3B)
                          : const Color(0xFF1E293B),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    icon: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 15,
                    ),
                    label: Text(
                      _copied ? 'Copiado!' : 'Copiar Hash',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                hashValue,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 12.2,
                  height: 1.45,
                  fontFamily: 'monospace',
                  fontFamilyFallback: ['Consolas', 'Courier New', 'Menlo'],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

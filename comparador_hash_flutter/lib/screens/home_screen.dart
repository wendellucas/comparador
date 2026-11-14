import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../models/compared_file.dart';
import '../models/hash_algorithm.dart';
import '../services/file_loader.dart';
import '../services/native_file_picker.dart';
import '../widgets/app_logo.dart';
import '../widgets/comparison_banner.dart';
import '../widgets/file_drop_card.dart';

/// Tela principal do Comparador de Arquivos por Hash.
///
/// Gerencia os dois slots de comparação, seleção de algoritmo, fluxo paralelo
/// quando dois arquivos são soltos/selecionados de uma só vez e layout
/// adaptativo para celular, janela livre do Samsung DeX, desktop e Web.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _slot1Color = Color(0xFF38BDF8);
  static const Color _slot2Color = Color(0xFFA78BFA);

  HashAlgorithm _selectedAlgorithm = HashAlgorithm.sha256;
  FileSlotState _slot1 = const FileSlotState.empty();
  FileSlotState _slot2 = const FileSlotState.empty();

  // Contadores de geração impedem que leituras antigas atrasadas sobrescrevam
  // um arquivo mais recente após limpeza ou nova seleção no mesmo slot.
  int _slot1Generation = 0;
  int _slot2Generation = 0;

  bool get _isBusy => _slot1.isLoading || _slot2.isLoading;
  bool get _hasAnyContent => !_slot1.isEmpty || !_slot2.isEmpty;

  FileSlotState _slotStateFor(int slot) => slot == 1 ? _slot1 : _slot2;

  void _setSlotState(int slot, FileSlotState nextState) {
    if (!mounted) return;
    setState(() {
      if (slot == 1) {
        _slot1 = nextState;
      } else {
        _slot2 = nextState;
      }
    });
  }

  int _bumpGeneration(int slot) {
    if (slot == 1) {
      return ++_slot1Generation;
    }
    return ++_slot2Generation;
  }

  bool _isCurrentGeneration(int slot, int generation) {
    return slot == 1
        ? _slot1Generation == generation
        : _slot2Generation == generation;
  }

  void _clearSlot(int slot) {
    _bumpGeneration(slot);
    _setSlotState(slot, const FileSlotState.empty());
  }

  void _clearAll() {
    _slot1Generation++;
    _slot2Generation++;
    setState(() {
      _slot1 = const FileSlotState.empty();
      _slot2 = const FileSlotState.empty();
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFF7F1D1D)
              : const Color(0xFF1E293B),
          content: Text(
            message,
            style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 13),
          ),
        ),
      );
  }

  Future<void> _browseForSlot(int targetSlot) async {
    try {
      final picked = await NativeFilePicker.pickFiles();
      if (!mounted || picked.isEmpty) return;

      if (picked.length >= 2) {
        if (picked.length > 2) {
          _showMessage(
            '${picked.length} arquivos selecionados; os 2 primeiros foram carregados.',
          );
        }
        await Future.wait([
          _loadXFileIntoSlot(1, picked[0]),
          _loadXFileIntoSlot(2, picked[1]),
        ]);
      } else {
        await _loadXFileIntoSlot(targetSlot, picked.first);
      }
    } catch (error) {
      _showMessage('Erro ao abrir seletor de arquivos: $error', isError: true);
    }
  }

  Future<void> _handleDropForSlot(int targetSlot, List<DropItem> items) async {
    if (items.isEmpty) {
      _showMessage(
        'Nenhum arquivo válido encontrado no item arrastado.',
        isError: true,
      );
      return;
    }

    if (items.length >= 2) {
      if (items.length > 2) {
        _showMessage(
          '${items.length} itens arrastados; os 2 primeiros foram carregados.',
        );
      }
      await Future.wait([
        _loadDropItemIntoSlot(1, items[0]),
        _loadDropItemIntoSlot(2, items[1]),
      ]);
      return;
    }

    await _loadDropItemIntoSlot(targetSlot, items.first);
  }

  Future<void> _loadXFileIntoSlot(int slot, XFile xFile) async {
    String? initialName;
    try {
      initialName = await xFile.name();
    } catch (_) {
      initialName = null;
    }

    await _runSlotLoad(
      slot: slot,
      initialName: initialName,
      task: (onName, onProgress) {
        return FileLoader.loadFromXFile(
          xFile,
          preferredName: initialName,
          onFileNameResolved: onName,
          onProgress: onProgress,
        );
      },
    );
  }

  Future<void> _loadDropItemIntoSlot(int slot, DropItem item) async {
    final initialName = switch (item) {
      DropFileItem(:final name) || DropDirectoryItem(:final name) => name,
      DropStringItem() => null,
    };

    await _runSlotLoad(
      slot: slot,
      initialName: initialName,
      task: (onName, onProgress) => FileLoader.loadFromDropItem(
        item,
        onFileNameResolved: onName,
        onProgress: onProgress,
      ),
    );
  }

  Future<void> _runSlotLoad({
    required int slot,
    String? initialName,
    required Future<ComparedFile> Function(
      void Function(String?) onName,
      void Function(double?) onProgress,
    ) task,
  }) async {
    final generation = _bumpGeneration(slot);
    String? resolvedName = initialName;

    _setSlotState(
      slot,
      FileSlotState.loading(pendingFileName: resolvedName),
    );

    try {
      final result = await task(
        (name) {
          if (name != null && name.isNotEmpty) {
            resolvedName = name;
          }
          if (!mounted || !_isCurrentGeneration(slot, generation)) return;
          _setSlotState(
            slot,
            FileSlotState.loading(
              pendingFileName: resolvedName,
              progress: _slotStateFor(slot).progress,
            ),
          );
        },
        (progress) {
          if (!mounted || !_isCurrentGeneration(slot, generation)) return;
          _setSlotState(
            slot,
            FileSlotState.loading(
              pendingFileName: resolvedName,
              progress: progress,
            ),
          );
        },
      );

      if (!mounted || !_isCurrentGeneration(slot, generation)) return;
      _setSlotState(slot, FileSlotState.ready(result));
    } on InvalidFileDropException catch (error) {
      if (!mounted || !_isCurrentGeneration(slot, generation)) return;
      _setSlotState(
        slot,
        FileSlotState.error(error.message, fileName: resolvedName),
      );
      _showMessage(error.message, isError: true);
    } catch (error) {
      if (!mounted || !_isCurrentGeneration(slot, generation)) return;
      final message = 'Falha ao ler o arquivo: $error';
      _setSlotState(
        slot,
        FileSlotState.error(message, fileName: resolvedName),
      );
      _showMessage(message, isError: true);
    }
  }

  Future<void> _recompareNow() async {
    final file1 = _slot1.file;
    final file2 = _slot2.file;

    if (file1 == null && file2 == null) {
      _showMessage('Selecione ou arraste arquivos antes de recomparar.');
      return;
    }

    final tasks = <Future<void>>[];

    void enqueueRefresh(int slot, ComparedFile file) {
      final xFile = file.sourceXFile;
      if (xFile != null) {
        tasks.add(_loadXFileIntoSlot(slot, xFile));
      } else if (file.localPath != null && file.localPath!.isNotEmpty) {
        tasks.add(_loadXFileIntoSlot(slot, XFile.fileSystem(path: file.localPath!)));
      }
    }

    if (file1 != null) enqueueRefresh(1, file1);
    if (file2 != null) enqueueRefresh(2, file2);

    if (tasks.isEmpty) {
      _showMessage('Comparação atualizada (${_selectedAlgorithm.label}).');
      return;
    }

    await Future.wait(tasks);
    if (mounted) {
      _showMessage('Hashes recalculados (${_selectedAlgorithm.label}).');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            // Breakpoint pensado para desktop, Web e janelas médias/grandes no Samsung DeX.
            final isWide = viewport.maxWidth >= 720;
            final horizontalPadding = viewport.maxWidth >= 900 ? 28.0 : 16.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(isWide),
                      const SizedBox(height: 20),
                      _buildDropZones(isWide),
                      const SizedBox(height: 16),
                      ComparisonBanner(
                        slot1: _slot1,
                        slot2: _slot2,
                        algorithm: _selectedAlgorithm,
                      ),
                      const SizedBox(height: 18),
                      _buildFooter(isWide),
                      const SizedBox(height: 18),
                      _buildVersionFooter(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWide) {
    final titleSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const AppLogo(size: 40),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Comparador de Arquivos por Hash',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Arraste dois arquivos para verificar se são idênticos (${_selectedAlgorithm.label}).',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ],
    );

    final algorithmSelector = _AlgorithmSelector(
      selected: _selectedAlgorithm,
      onChanged: (next) {
        setState(() => _selectedAlgorithm = next);
      },
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: titleSection),
          const SizedBox(width: 16),
          algorithmSelector,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titleSection,
        const SizedBox(height: 14),
        algorithmSelector,
      ],
    );
  }

  Widget _buildDropZones(bool isWide) {
    final card1 = FileDropCard(
      slotNumber: 1,
      title: 'ARQUIVO 1',
      accentColor: _slot1Color,
      slotState: _slot1,
      algorithm: _selectedAlgorithm,
      onBrowse: () => _browseForSlot(1),
      onDropItems: (items) => _handleDropForSlot(1, items),
      onClear: () => _clearSlot(1),
    );

    final card2 = FileDropCard(
      slotNumber: 2,
      title: 'ARQUIVO 2',
      accentColor: _slot2Color,
      slotState: _slot2,
      algorithm: _selectedAlgorithm,
      onBrowse: () => _browseForSlot(2),
      onDropItems: (items) => _handleDropForSlot(2, items),
      onClear: () => _clearSlot(2),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: card1),
          const SizedBox(width: 16),
          Expanded(child: card2),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card1,
        const SizedBox(height: 14),
        card2,
      ],
    );
  }

  Widget _buildFooter(bool isWide) {
    const tipWidget = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.lightbulb_outline_rounded, size: 17, color: Color(0xFF94A3B8)),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Dica: Você pode arrastar ou selecionar 2 arquivos de uma vez para preencher ambos os lados automaticamente.',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.2,
              height: 1.35,
            ),
          ),
        ),
      ],
    );

    final actionsWidget = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: (_hasAnyContent && !_isBusy) ? _clearAll : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE2E8F0),
            disabledForegroundColor: const Color(0xFF475569),
            backgroundColor: const Color(0xFF1E293B),
            side: BorderSide(
              color: (_hasAnyContent && !_isBusy)
                  ? const Color(0xFF475569)
                  : const Color(0xFF1E293B),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.delete_sweep_rounded, size: 18),
          label: const Text(
            'Limpar Tudo',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton.icon(
          onPressed:
              ((_slot1.isReady || _slot2.isReady) && !_isBusy) ? _recompareNow : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF1E293B),
            disabledForegroundColor: const Color(0xFF475569),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text(
            'Recomparar Agora',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(child: tipWidget),
          const SizedBox(width: 16),
          actionsWidget,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        actionsWidget,
        const SizedBox(height: 12),
        tipWidget,
      ],
    );
  }

  /// Rodapé discreto exibindo a identificação de versão do aplicativo (`v0.2`).
  Widget _buildVersionFooter() {
    return Column(
      children: [
        const Divider(color: Color(0xFF1E293B), height: 1),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Text(
              'Comparador de Arquivos por Hash',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Text(
                'v0.2',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AlgorithmSelector extends StatelessWidget {
  const _AlgorithmSelector({
    required this.selected,
    required this.onChanged,
  });

  final HashAlgorithm selected;
  final ValueChanged<HashAlgorithm> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: HashAlgorithm.values.map((algorithm) {
          final isSelected = algorithm == selected;
          return ChoiceChip(
            label: Text(algorithm.label),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onChanged(algorithm),
            labelStyle: TextStyle(
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFCBD5E1),
              fontSize: 12.2,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: Colors.transparent,
            selectedColor: const Color(0xFF38BDF8),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          );
        }).toList(),
      ),
    );
  }
}

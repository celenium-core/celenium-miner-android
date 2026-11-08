import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../services/cen_wallet.dart';
import '../services/keystore.dart';
import '../theme/layout.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/brand_mark.dart';
import '../widgets/cen_ui.dart';

/// Recovery words.
///
/// This is the screen that answers "what happens if the app is deleted". The
/// coins live on the blockchain tied to an address; the only thing that can be
/// lost is the phrase that produces the key for that address. So this screen
/// exists to get that phrase written down somewhere that survives the phone.
///
/// The phrase is shown exactly once, behind a confirmation, and the "backed
/// up" flag is stored separately from the phrase so the warning can clear
/// without revealing it again.
class BackupScreen extends StatefulWidget {
  const BackupScreen({
    required this.onDone,
    super.key,
    this.keystore,
    this.wordlist,
  });

  final VoidCallback onDone;
  final Keystore? keystore;

  /// The BIP39 wordlist. Injected rather than loaded here so the screen can be
  /// driven in a test without the asset bundle; the app passes it in after
  /// loading it once at startup.
  final List<String>? wordlist;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

enum _Stage { loading, none, reveal, confirm, saved, import }

class _BackupScreenState extends State<BackupScreen> {
  late final Keystore _keystore = widget.keystore ?? Keystore();
  List<String> _wordlist = const [];

  _Stage _stage = _Stage.loading;
  List<String> _words = const [];
  bool _confirmed = false;
  bool _busy = false;

  final _importController = TextEditingController();
  String? _importError;
  String? _importAddress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wordlist = widget.wordlist ?? await loadBip39Wordlist(rootBundle);
    final phrase = await _keystore.readPhrase();
    final backedUp = await _keystore.hasBackedUp();
    if (!mounted) return;
    setState(() {
      _wordlist = wordlist;
      if (phrase == null) {
        _stage = _Stage.none;
      } else {
        _words = Mnemonic.fromPhrase(phrase).words;
        _stage = backedUp ? _Stage.saved : _Stage.confirm;
      }
    });
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    final mnemonic = generateMnemonic(wordlist: _wordlist);
    await _keystore.savePhrase(mnemonic.phrase);
    if (!mounted) return;
    setState(() {
      _words = mnemonic.words;
      _confirmed = false;
      _stage = _Stage.reveal;
      _busy = false;
    });
  }

  Future<void> _confirmBackedUp() async {
    await _keystore.setBackedUp(true);
    if (!mounted) return;
    setState(() => _stage = _Stage.saved);
  }

  Future<void> _revealAgain() async {
    final phrase = await _keystore.readPhrase();
    if (!mounted || phrase == null) return;
    setState(() {
      _words = Mnemonic.fromPhrase(phrase).words;
      _confirmed = false;
      _stage = _Stage.reveal;
    });
  }

  Future<void> _runImport() async {
    final l10n = l10nOf(context);
    final mnemonic = Mnemonic.fromPhrase(_importController.text);
    if (!isValidMnemonic(mnemonic, _wordlist)) {
      setState(() {
        _importError = l10n.backupImportError;
        _importAddress = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _importError = null;
    });

    try {
      final wallet = CenWallet.fromMnemonic(mnemonic, CenNetwork.mainnet);
      await _keystore.savePhrase(mnemonic.phrase);
      await _keystore.setBackedUp(true);
      if (!mounted) return;
      setState(() {
        _words = mnemonic.words;
        _stage = _Stage.saved;
        _busy = false;
      });
      // The address is the proof the phrase was accepted, so it is shown
      // rather than silently replaced.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupImported(wallet.address))),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _importError = error.toString();
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.backupTitle),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          // A cross-fade keeps the switch calm, and there is no layout
          // animation for pumpAndSettle to wait on forever.
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: _buildStage(),
        ),
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _Stage.loading:
        return const Center(child: CircularProgressIndicator());
      case _Stage.none:
        return _buildIntro();
      case _Stage.reveal:
        return _buildReveal();
      case _Stage.confirm:
        return _buildConfirm();
      case _Stage.saved:
        return _buildSaved();
      case _Stage.import:
        return _buildImport();
    }
  }

  Widget _buildIntro() {
    final l10n = l10nOf(context);
    return CenContent(
      child: ListView(
        key: const ValueKey('intro'),
        padding: const EdgeInsets.all(Palette.lg),
        children: [
          Center(
            child: Column(
              children: [
                const SizedBox(height: Palette.lg),
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    color: Palette.surfaceHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: BrandMark(size: 50, onDark: true)),
                ),
                const SizedBox(height: Palette.lg),
                Text(
                  l10n.backupRecoveryWords,
                  style: TypeScale.screenTitle(context),
                ),
                const SizedBox(height: Palette.sm),
                Text(
                  l10n.backupIntro,
                  textAlign: TextAlign.center,
                  style: TypeScale.label(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: Palette.xl),
          CenCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(l10n.backupWhyTitle),
                const SizedBox(height: Palette.sm),
                Text(l10n.backupWhyBody, style: _bodyStyle),
              ],
            ),
          ),
          const SizedBox(height: Palette.md),
          CenCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(l10n.backupHowTitle),
                const SizedBox(height: Palette.sm),
                Text(l10n.backupHowBody, style: _bodyStyle),
              ],
            ),
          ),
          const SizedBox(height: Palette.xl),
          GoldButton(
            label: _busy ? l10n.backupCreating : l10n.backupCreateWords,
            icon: Icons.add,
            onPressed: _busy ? null : _generate,
          ),
          const SizedBox(height: Palette.md),
          GhostButton(
            label: l10n.backupHaveWords,
            icon: Icons.download_outlined,
            onPressed: () => setState(() => _stage = _Stage.import),
          ),
        ],
      ),
    );
  }

  Widget _buildReveal() {
    final l10n = l10nOf(context);
    return CenContent(
      child: ListView(
        key: const ValueKey('reveal'),
        padding: const EdgeInsets.all(Palette.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(Palette.lg),
            decoration: BoxDecoration(
              color: Palette.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Palette.rowRadius),
              border: Border.all(color: Palette.red.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_outlined,
                      size: 18,
                      color: Palette.red,
                    ),
                    const SizedBox(width: Palette.sm),
                    Text(
                      l10n.backupWriteNow,
                      style: TypeScale.title(context)
                          .copyWith(color: Palette.red),
                    ),
                  ],
                ),
                const SizedBox(height: Palette.sm),
                Text(
                  l10n.backupWarningBody,
                  style: TypeScale.caption(context)
                      .copyWith(color: Palette.red),
                ),
              ],
            ),
          ),
          const SizedBox(height: Palette.xl),
          Eyebrow(l10n.backupWordsTitle),
          const SizedBox(height: Palette.sm),
          _WordGrid(words: _words),
          const SizedBox(height: Palette.xl),
          Row(
            children: [
              Checkbox(
                value: _confirmed,
                onChanged: (value) =>
                    setState(() => _confirmed = value ?? false),
                activeColor: Palette.gold,
                checkColor: Palette.white,
              ),
              Expanded(
                child: Text(
                  l10n.backupWrittenCheck,
                  style: const TextStyle(
                    fontFamily: TypeScale.bodyFamily,
                    fontSize: 13,
                    color: Palette.cream,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Palette.md),
          GoldButton(
            label: l10n.commonContinue,
            onPressed: _confirmed ? _confirmBackedUp : null,
          ),
        ],
      ),
    );
  }

  Widget _buildConfirm() {
    final l10n = l10nOf(context);
    return ListView(
      key: const ValueKey('confirm'),
      padding: const EdgeInsets.all(Palette.lg),
      children: [
        const SizedBox(height: Palette.xxl),
        Center(
          child: Column(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 44,
                color: Palette.goldLight,
              ),
              const SizedBox(height: Palette.lg),
              Text(l10n.backupNotYet, style: TypeScale.screenTitle(context)),
              const SizedBox(height: Palette.sm),
              Text(
                l10n.backupNotYetBody,
                textAlign: TextAlign.center,
                style: TypeScale.label(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: Palette.xl),
        GoldButton(
          label: l10n.backupShowWords,
          icon: Icons.visibility_outlined,
          onPressed: _revealAgain,
        ),
      ],
    );
  }

  Widget _buildSaved() {
    final l10n = l10nOf(context);
    return ListView(
      key: const ValueKey('saved'),
      padding: const EdgeInsets.all(Palette.lg),
      children: [
        const SizedBox(height: Palette.xxl),
        Center(
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Palette.green.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 34,
                  color: Palette.greenDim,
                ),
              ),
              const SizedBox(height: Palette.lg),
              Text(l10n.backupDone, style: TypeScale.screenTitle(context)),
              const SizedBox(height: Palette.sm),
              Text(
                l10n.backupDoneBody,
                textAlign: TextAlign.center,
                style: TypeScale.label(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: Palette.xl),
        CenCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(l10n.backupIfDeletedTitle),
              const SizedBox(height: Palette.sm),
              Text(l10n.backupIfDeletedBody, style: _bodyStyle),
            ],
          ),
        ),
        const SizedBox(height: Palette.xl),
        GhostButton(
          label: l10n.backupShowAgain,
          icon: Icons.visibility_outlined,
          onPressed: _revealAgain,
        ),
        const SizedBox(height: Palette.md),
        TextButton(onPressed: widget.onDone, child: Text(l10n.commonDone)),
      ],
    );
  }

  Widget _buildImport() {
    final l10n = l10nOf(context);
    return ListView(
      key: const ValueKey('import'),
      padding: const EdgeInsets.all(Palette.lg),
      children: [
        Text(l10n.backupImportTitle, style: TypeScale.screenTitle(context)),
        const SizedBox(height: Palette.sm),
        Text(l10n.backupImportIntro, style: TypeScale.label(context)),
        const SizedBox(height: Palette.xl),
        TextField(
          controller: _importController,
          maxLines: 4,
          autocorrect: false,
          enableSuggestions: false,
          style: TypeScale.mono(
            context,
            size: 13,
          ).copyWith(color: Palette.cream),
          decoration: const InputDecoration(hintText: 'abandon ability able …'),
        ),
        if (_importError != null) ...[
          const SizedBox(height: Palette.sm),
          Text(
            _importError!,
            style: TypeScale.caption(context).copyWith(color: Palette.red),
          ),
        ],
        if (_importAddress != null) ...[
          const SizedBox(height: Palette.sm),
          Text(
            _importAddress!,
            style: TypeScale.mono(
              context,
              size: 11,
            ).copyWith(color: Palette.greenDim),
          ),
        ],
        const SizedBox(height: Palette.xl),
        GoldButton(
          label: _busy ? l10n.commonChecking : l10n.commonImport,
          onPressed: _busy ? null : _runImport,
        ),
        const SizedBox(height: Palette.md),
        GhostButton(
          label: l10n.commonCancel,
          onPressed: () => setState(() {
            _importError = null;
            _stage = _Stage.none;
          }),
        ),
      ],
    );
  }
}

/// The long-form body copy, identical in every card on this screen.
const TextStyle _bodyStyle = TextStyle(
  fontFamily: TypeScale.bodyFamily,
  fontSize: 13,
  color: Palette.slateLight,
  height: 1.55,
);

/// The words in a numbered grid. Numbers are part of the data: the order is
/// what makes the phrase sufficient.
class _WordGrid extends StatelessWidget {
  const _WordGrid({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Palette.sm,
      runSpacing: Palette.sm,
      children: [
        for (var i = 0; i < words.length; i++)
          Container(
            width:
                (MediaQuery.sizeOf(context).width -
                    Palette.lg * 2 -
                    Palette.sm * 2) /
                3,
            padding: const EdgeInsets.symmetric(
              horizontal: Palette.sm,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Palette.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Palette.goldDim.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}', style: TypeScale.monoMuted(context, size: 9)),
                const SizedBox(height: 2),
                Text(
                  words[i],
                  style: TypeScale.mono(
                    context,
                    size: 12,
                  ).copyWith(color: Palette.cream),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
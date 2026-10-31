import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cen_wallet.dart';
import '../services/keystore.dart';
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
    final mnemonic = Mnemonic.fromPhrase(_importController.text);
    if (!isValidMnemonic(mnemonic, _wordlist)) {
      setState(() {
        _importError = 'That phrase is not a valid BIP39 phrase. Check the words and try again.';
        _importAddress = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _importError = null;
    });

    try {
      final wallet = CenWallet.fromMnemonic(mnemonic, CenNetwork.simnet);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${wallet.address}')),
        );
      }
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('RECOVERY'),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          // A cross-fade keeps the switch calm, and there is no layout
          // animation for pumpAndSettle to wait on forever.
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
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
    return ListView(
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
                decoration: const BoxDecoration(color: Palette.cream, shape: BoxShape.circle),
                child: Center(child: BrandMark(size: 50)),
              ),
              const SizedBox(height: Palette.lg),
              Text('Recovery words', style: TypeScale.screenTitle(context)),
              const SizedBox(height: Palette.sm),
              Text(
                'Twelve words that rebuild your key on any device.',
                textAlign: TextAlign.center,
                style: TypeScale.label(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: Palette.xl),
        const CenCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('Why this matters'),
              SizedBox(height: Palette.sm),
              Text(
                'Your coins sit on the blockchain, tied to an address. They survive '
                'the app being deleted. The one thing that does not survive is the '
                'key to that address, and these twelve words are the key.',
                style: TextStyle(
                  fontFamily: TypeScale.bodyFamily,
                  fontSize: 13,
                  color: Palette.slateLight,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Palette.md),
        const CenCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('What to do with them'),
              SizedBox(height: Palette.sm),
              Text(
                'Write them on paper, in order, and keep the paper somewhere that '
                'is not this phone. Do not store them in a notes app, a '
                'screenshot, or a message to yourself.',
                style: TextStyle(
                  fontFamily: TypeScale.bodyFamily,
                  fontSize: 13,
                  color: Palette.slateLight,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Palette.xl),
        GoldButton(
          label: _busy ? 'Creating…' : 'Create recovery words',
          icon: Icons.add,
          onPressed: _busy ? null : _generate,
        ),
        const SizedBox(height: Palette.md),
        GhostButton(
          label: 'I already have words',
          icon: Icons.download_outlined,
          onPressed: () => setState(() => _stage = _Stage.import),
        ),
      ],
    );
  }

  Widget _buildReveal() {
    return ListView(
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
                  const Icon(Icons.warning_amber_outlined, size: 18, color: Palette.red),
                  const SizedBox(width: Palette.sm),
                  Text(
                    'Write these down now',
                    style: TypeScale.title(context).copyWith(color: Palette.red),
                  ),
                ],
              ),
              const SizedBox(height: Palette.sm),
              Text(
                'Anyone who reads these twelve words can move every coin at your '
                'address. They are shown once. After you leave this screen they '
                'are not shown again.',
                style: TypeScale.caption(context).copyWith(color: Palette.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: Palette.xl),
        Eyebrow('Your 12 words, in order'),
        const SizedBox(height: Palette.sm),
        _WordGrid(words: _words),
        const SizedBox(height: Palette.xl),
        Row(
          children: [
            Checkbox(
              value: _confirmed,
              onChanged: (value) => setState(() => _confirmed = value ?? false),
              activeColor: Palette.gold,
              checkColor: Palette.ink,
            ),
            const Expanded(
              child: Text(
                'I have written all twelve words down in order',
                style: TextStyle(
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
          label: 'Continue',
          onPressed: _confirmed ? _confirmBackedUp : null,
        ),
      ],
    );
  }

  Widget _buildConfirm() {
    return ListView(
      key: const ValueKey('confirm'),
      padding: const EdgeInsets.all(Palette.lg),
      children: [
        const SizedBox(height: Palette.xxl),
        Center(
          child: Column(
            children: [
              const Icon(Icons.shield_outlined, size: 44, color: Palette.goldLight),
              const SizedBox(height: Palette.lg),
              Text('Not backed up yet', style: TypeScale.screenTitle(context)),
              const SizedBox(height: Palette.sm),
              Text(
                'Recovery words exist on this device but have not been confirmed as '
                'written down. Until they are, losing this phone loses the key.',
                textAlign: TextAlign.center,
                style: TypeScale.label(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: Palette.xl),
        GoldButton(label: 'Show my words', icon: Icons.visibility_outlined, onPressed: _revealAgain),
      ],
    );
  }

  Widget _buildSaved() {
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
                child: const Icon(Icons.check, size: 34, color: Palette.greenDim),
              ),
              const SizedBox(height: Palette.lg),
              Text('Backed up', style: TypeScale.screenTitle(context)),
              const SizedBox(height: Palette.sm),
              Text(
                'Your recovery words are confirmed as written down. Keep the paper '
                'somewhere this phone is not.',
                textAlign: TextAlign.center,
                style: TypeScale.label(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: Palette.xl),
        const CenCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('If the app is deleted'),
              SizedBox(height: Palette.sm),
              Text(
                'Coins are not lost: they stay on the blockchain at your address. '
                'Reinstall the app, choose "I already have words", and enter the '
                'twelve words to take control of the address again.',
                style: TextStyle(
                  fontFamily: TypeScale.bodyFamily,
                  fontSize: 13,
                  color: Palette.slateLight,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Palette.xl),
        GhostButton(
          label: 'Show my words again',
          icon: Icons.visibility_outlined,
          onPressed: _revealAgain,
        ),
        const SizedBox(height: Palette.md),
        TextButton(
          onPressed: widget.onDone,
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildImport() {
    return ListView(
      key: const ValueKey('import'),
      padding: const EdgeInsets.all(Palette.lg),
      children: [
        Text('Import words', style: TypeScale.screenTitle(context)),
        const SizedBox(height: Palette.sm),
        Text(
          'Enter your existing 12 or 24 words to take control of that address on '
          'this device.',
          style: TypeScale.label(context),
        ),
        const SizedBox(height: Palette.xl),
        TextField(
          controller: _importController,
          maxLines: 4,
          autocorrect: false,
          enableSuggestions: false,
          style: TypeScale.mono(context, size: 13).copyWith(color: Palette.cream),
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
            style: TypeScale.mono(context, size: 11).copyWith(color: Palette.greenDim),
          ),
        ],
        const SizedBox(height: Palette.xl),
        GoldButton(
          label: _busy ? 'Checking…' : 'Import',
          onPressed: _busy ? null : _runImport,
        ),
        const SizedBox(height: Palette.md),
        GhostButton(
          label: 'Cancel',
          onPressed: () => setState(() {
            _importError = null;
            _stage = _Stage.none;
          }),
        ),
      ],
    );
  }
}

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
            width: (MediaQuery.sizeOf(context).width - Palette.lg * 2 - Palette.sm * 2) / 3,
            padding: const EdgeInsets.symmetric(horizontal: Palette.sm, vertical: 10),
            decoration: BoxDecoration(
              color: Palette.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Palette.goldDim.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}',
                  style: TypeScale.monoMuted(context, size: 9),
                ),
                const SizedBox(height: 2),
                Text(
                  words[i],
                  style: TypeScale.mono(context, size: 12).copyWith(color: Palette.cream),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

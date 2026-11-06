// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonClose => 'Close';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonDone => 'Done';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get commonImport => 'Import';

  @override
  String get commonChecking => 'Checking…';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonToday => 'TODAY';

  @override
  String get commonYesterday => 'YESTERDAY';

  @override
  String get commonNoWorker => 'No worker';

  @override
  String get statusActive => 'ACTIVE';

  @override
  String get statusIdle => 'IDLE';

  @override
  String get statusOnline => 'ONLINE';

  @override
  String get statusOffline => 'OFFLINE';

  @override
  String get navMine => 'Mine';

  @override
  String get navWallet => 'Wallet';

  @override
  String get navProfile => 'Profile';

  @override
  String get splashEnterSemantics => 'Enter the mining console';

  @override
  String get splashEnter => 'ENTER';

  @override
  String get mineNodeNotSet => 'node not set';

  @override
  String get mineHashRate => 'Hash rate';

  @override
  String get mineMiningActive => 'MINING ACTIVE';

  @override
  String get mineBridgeSilent =>
      'The bridge has not answered. Set its address to start reading live figures.';

  @override
  String get mineSetBridge => 'Set bridge address';

  @override
  String get mineTapWorkers => '[ TAP FOR WORKERS ]';

  @override
  String get mineWaitingShare => '> waiting for first share';

  @override
  String mineShareAccepted(String hash) {
    return '> share accepted $hash';
  }

  @override
  String get mineAcceptanceSemantics => 'Share acceptance. Open workers.';

  @override
  String get mineAcceptanceNoShares => 'ACCEPTANCE\nno shares yet';

  @override
  String mineAcceptanceRate(String rate) {
    return 'ACCEPTANCE\n$rate%';
  }

  @override
  String get mineSessionLabel => 'session';

  @override
  String get mineTotalLabel => 'total';

  @override
  String get mineSharesUnit => 'shares';

  @override
  String get mineAcceptedLabel => 'accepted';

  @override
  String get mineNoBlock => 'no block accepted yet';

  @override
  String mineBlockAccepted(String hash) {
    return 'block accepted $hash';
  }

  @override
  String get walletTitle => 'Wallet';

  @override
  String get walletTransactions => 'Transactions';

  @override
  String get walletSeeAll => 'SEE ALL';

  @override
  String get walletNoTxReason =>
      'No transactions yet. Blocks your workers mine appear here as they land.';

  @override
  String get walletTotalBalance => 'Total balance';

  @override
  String get walletNoBalanceNote =>
      'Balance appears once the bridge is connected to a synced node.';

  @override
  String get walletMiningAddress => 'Mining address';

  @override
  String get walletAddressCopied => 'Address copied';

  @override
  String get walletCopyAddress => 'Copy address';

  @override
  String get walletSend => 'Send';

  @override
  String get walletReceive => 'Receive';

  @override
  String get walletSwap => 'Swap';

  @override
  String get walletBackupWords => 'Back up recovery words';

  @override
  String get walletSwapUnavailable => 'Swap is not available';

  @override
  String get walletSwapBody =>
      'Swapping CEN for another asset needs a market to swap against. CEN is not listed on any exchange or decentralised venue yet, so there is nothing to swap with.';

  @override
  String get walletReceiveNote =>
      'Anyone with this address can send coins to it. It is safe to share.';

  @override
  String get walletMiningReward => 'Mining reward';

  @override
  String get walletSendTitle => 'Send CEN';

  @override
  String get walletSendRecipient => 'Recipient address';

  @override
  String get walletSendAmount => 'Amount';

  @override
  String get walletSendFee => 'Network fee';

  @override
  String get walletSendConfirm => 'Send';

  @override
  String get walletSendSending => 'Sending…';

  @override
  String get walletSendNeedRecipient => 'Enter a recipient address.';

  @override
  String get walletSendInvalidAmount =>
      'Enter a valid amount (up to 8 decimal places).';

  @override
  String get walletSendNoKey =>
      'No recovery words on this device. Back them up first.';

  @override
  String get walletSendKeyMismatch =>
      'This device\'s recovery words do not own the mining address. Import the matching words first.';

  @override
  String get walletSendFailed => 'The node rejected the transfer.';

  @override
  String get walletSendSuccess => 'Transfer sent';

  @override
  String get walletSendSuccessBody =>
      'The transaction is now in the mempool and lands on-chain once a block includes it.';

  @override
  String get walletSendTxId => 'Transaction id';

  @override
  String get walletSendNoAddress => 'No wallet address yet';

  @override
  String get walletSendNoAddressBody =>
      'The address appears once the bridge mines its first block. Until then there is nothing to send from.';

  @override
  String get walletSendNodeDown => 'The node isn\'t reachable';

  @override
  String get walletSendNodeDownBody =>
      'The wallet reaches your node through the bridge. Open the Miner tab and connect a node first.';

  @override
  String get backupTitle => 'RECOVERY';

  @override
  String get backupImportError =>
      'That phrase is not a valid BIP39 phrase. Check the words and try again.';

  @override
  String backupImported(String address) {
    return 'Imported $address';
  }

  @override
  String get backupRecoveryWords => 'Recovery words';

  @override
  String get backupIntro => 'Twelve words that rebuild your key on any device.';

  @override
  String get backupWhyTitle => 'Why this matters';

  @override
  String get backupWhyBody =>
      'Your coins sit on the blockchain, tied to an address. They survive the app being deleted. The one thing that does not survive is the key to that address, and these twelve words are the key.';

  @override
  String get backupHowTitle => 'What to do with them';

  @override
  String get backupHowBody =>
      'Write them on paper, in order, and keep the paper somewhere that is not this phone. Do not store them in a notes app, a screenshot, or a message to yourself.';

  @override
  String get backupCreating => 'Creating…';

  @override
  String get backupCreateWords => 'Create recovery words';

  @override
  String get backupHaveWords => 'I already have words';

  @override
  String get backupWriteNow => 'Write these down now';

  @override
  String get backupWarningBody =>
      'Anyone who reads these twelve words can move every coin at your address. They are shown once. After you leave this screen they are not shown again.';

  @override
  String get backupWordsTitle => 'Your 12 words, in order';

  @override
  String get backupWrittenCheck =>
      'I have written all twelve words down in order';

  @override
  String get backupNotYet => 'Not backed up yet';

  @override
  String get backupNotYetBody =>
      'Recovery words exist on this device but have not been confirmed as written down. Until they are, losing this phone loses the key.';

  @override
  String get backupShowWords => 'Show my words';

  @override
  String get backupDone => 'Backed up';

  @override
  String get backupDoneBody =>
      'Your recovery words are confirmed as written down. Keep the paper somewhere this phone is not.';

  @override
  String get backupIfDeletedTitle => 'If the app is deleted';

  @override
  String get backupIfDeletedBody =>
      'Coins are not lost: they stay on the blockchain at your address. Reinstall the app, choose \"I already have words\", and enter the twelve words to take control of the address again.';

  @override
  String get backupShowAgain => 'Show my words again';

  @override
  String get backupImportTitle => 'Import words';

  @override
  String get backupImportIntro =>
      'Enter your existing 12 or 24 words to take control of that address on this device.';

  @override
  String get bridgeTitle => 'BRIDGE';

  @override
  String get bridgeSaved => 'Bridge address saved';

  @override
  String get bridgeAddress => 'Bridge address';

  @override
  String get bridgeAddressNote =>
      'The bridge serves mining results over HTTP. No account and no credentials are sent with the request.';

  @override
  String get bridgePollInterval => 'Poll interval';

  @override
  String get bridgePollNote =>
      'How often the app asks the bridge for fresh figures. A shorter interval updates faster and uses more battery.';

  @override
  String get bridgeAdUnit => 'Ad unit id';

  @override
  String get bridgeAdNote =>
      'Optional. Leave it empty to use the unit built into the app. The banner only appears once a real ad is served: an empty slot reserves no space and shows nothing.';

  @override
  String get bridgeNode => 'Node';

  @override
  String get bridgeInfoAddress => 'Address';

  @override
  String get bridgeInfoVersion => 'Version';

  @override
  String get bridgeInfoInstances => 'Instances';

  @override
  String get workersTitle => 'WORKERS';

  @override
  String get workersEmpty =>
      'No workers reported. Point a miner at the bridge stratum port with your CEN address as the worker name and they appear here.';

  @override
  String get workersHashRate => 'hash rate';

  @override
  String get workersBlocks => 'blocks';

  @override
  String workersStaleInvalid(int stale, int invalid) {
    return '$stale stale · $invalid invalid';
  }

  @override
  String workersSession(String duration) {
    return 'session $duration';
  }

  @override
  String get logTitle => 'ACTIVITY';

  @override
  String get logEmpty =>
      'Nothing logged yet. Connection changes and newly accepted blocks are recorded here as they happen.';

  @override
  String logBridgeReachable(String address) {
    return 'Bridge reachable at $address';
  }

  @override
  String get logBridgeUnreachable => 'Bridge unreachable';

  @override
  String logBlockAccepted(int newCount, int total) {
    return 'Block accepted ($newCount new, $total total)';
  }

  @override
  String get logMinerStarted => 'Internal CPU miner started';

  @override
  String get logMinerStopped => 'Internal CPU miner stopped';

  @override
  String logStaleShares(int count) {
    return '$count stale share(s) reported';
  }

  @override
  String get logPollFailed => 'Poll failed';

  @override
  String get logAdRequestFailed => 'Ad request failed';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileBlocks => 'blocks';

  @override
  String get profileShares => 'shares';

  @override
  String get profileWorkers => 'workers';

  @override
  String get profileGhs => 'gh/s';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileNotSet => 'not set';

  @override
  String get profileBridgeRow => 'Bridge';

  @override
  String get profileWorkersRow => 'Workers';

  @override
  String get profileActivityRow => 'Activity log';

  @override
  String get profileRecoveryRow => 'Recovery words';

  @override
  String get profileAboutRow => 'About';

  @override
  String get profileNoAddress => 'no address reported';

  @override
  String profileMiningTo(String address) {
    return 'mining to $address';
  }

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileLanguageSystem => 'System default';

  @override
  String get profileLanguageDone => 'Language saved';

  @override
  String get aboutTitle => 'ABOUT';

  @override
  String get aboutWhatTitle => 'What this app does';

  @override
  String get aboutWhatBody =>
      'It reads mining results from a Celenium bridge and shows them on your phone. It holds no account, no database, and no coins: the results live on the blockchain and the bridge, and this app is a window onto them.';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutCreatedBy => 'Created by';
}

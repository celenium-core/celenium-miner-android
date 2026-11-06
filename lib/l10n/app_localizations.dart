import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get commonSaving;

  /// No description provided for @commonImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commonImport;

  /// No description provided for @commonChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get commonChecking;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get commonToday;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'YESTERDAY'**
  String get commonYesterday;

  /// No description provided for @commonNoWorker.
  ///
  /// In en, this message translates to:
  /// **'No worker'**
  String get commonNoWorker;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get statusActive;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'IDLE'**
  String get statusIdle;

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'ONLINE'**
  String get statusOnline;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get statusOffline;

  /// No description provided for @navMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get navMine;

  /// No description provided for @navWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get navWallet;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @splashEnterSemantics.
  ///
  /// In en, this message translates to:
  /// **'Enter the mining console'**
  String get splashEnterSemantics;

  /// No description provided for @splashEnter.
  ///
  /// In en, this message translates to:
  /// **'ENTER'**
  String get splashEnter;

  /// No description provided for @mineNodeNotSet.
  ///
  /// In en, this message translates to:
  /// **'node not set'**
  String get mineNodeNotSet;

  /// No description provided for @mineHashRate.
  ///
  /// In en, this message translates to:
  /// **'Hash rate'**
  String get mineHashRate;

  /// No description provided for @mineMiningActive.
  ///
  /// In en, this message translates to:
  /// **'MINING ACTIVE'**
  String get mineMiningActive;

  /// No description provided for @mineBridgeSilent.
  ///
  /// In en, this message translates to:
  /// **'The bridge has not answered. Set its address to start reading live figures.'**
  String get mineBridgeSilent;

  /// No description provided for @mineSetBridge.
  ///
  /// In en, this message translates to:
  /// **'Set bridge address'**
  String get mineSetBridge;

  /// No description provided for @mineTapWorkers.
  ///
  /// In en, this message translates to:
  /// **'[ TAP FOR WORKERS ]'**
  String get mineTapWorkers;

  /// No description provided for @mineWaitingShare.
  ///
  /// In en, this message translates to:
  /// **'> waiting for first share'**
  String get mineWaitingShare;

  /// No description provided for @mineShareAccepted.
  ///
  /// In en, this message translates to:
  /// **'> share accepted {hash}'**
  String mineShareAccepted(String hash);

  /// No description provided for @mineAcceptanceSemantics.
  ///
  /// In en, this message translates to:
  /// **'Share acceptance. Open workers.'**
  String get mineAcceptanceSemantics;

  /// No description provided for @mineAcceptanceNoShares.
  ///
  /// In en, this message translates to:
  /// **'ACCEPTANCE\nno shares yet'**
  String get mineAcceptanceNoShares;

  /// No description provided for @mineAcceptanceRate.
  ///
  /// In en, this message translates to:
  /// **'ACCEPTANCE\n{rate}%'**
  String mineAcceptanceRate(String rate);

  /// No description provided for @mineSessionLabel.
  ///
  /// In en, this message translates to:
  /// **'session'**
  String get mineSessionLabel;

  /// No description provided for @mineTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'total'**
  String get mineTotalLabel;

  /// No description provided for @mineSharesUnit.
  ///
  /// In en, this message translates to:
  /// **'shares'**
  String get mineSharesUnit;

  /// No description provided for @mineAcceptedLabel.
  ///
  /// In en, this message translates to:
  /// **'accepted'**
  String get mineAcceptedLabel;

  /// No description provided for @mineNoBlock.
  ///
  /// In en, this message translates to:
  /// **'no block accepted yet'**
  String get mineNoBlock;

  /// No description provided for @mineBlockAccepted.
  ///
  /// In en, this message translates to:
  /// **'block accepted {hash}'**
  String mineBlockAccepted(String hash);

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletTitle;

  /// No description provided for @walletTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get walletTransactions;

  /// No description provided for @walletSeeAll.
  ///
  /// In en, this message translates to:
  /// **'SEE ALL'**
  String get walletSeeAll;

  /// No description provided for @walletNoTxReason.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet. Blocks your workers mine appear here as they land.'**
  String get walletNoTxReason;

  /// No description provided for @walletTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get walletTotalBalance;

  /// No description provided for @walletNoBalanceNote.
  ///
  /// In en, this message translates to:
  /// **'Balance appears once the bridge is connected to a synced node.'**
  String get walletNoBalanceNote;

  /// No description provided for @walletMiningAddress.
  ///
  /// In en, this message translates to:
  /// **'Mining address'**
  String get walletMiningAddress;

  /// No description provided for @walletAddressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get walletAddressCopied;

  /// No description provided for @walletCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get walletCopyAddress;

  /// No description provided for @walletSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get walletSend;

  /// No description provided for @walletReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get walletReceive;

  /// No description provided for @walletSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get walletSwap;

  /// No description provided for @walletBackupWords.
  ///
  /// In en, this message translates to:
  /// **'Back up recovery words'**
  String get walletBackupWords;

  /// No description provided for @walletSwapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Swap is not available'**
  String get walletSwapUnavailable;

  /// No description provided for @walletSwapBody.
  ///
  /// In en, this message translates to:
  /// **'Swapping CEN for another asset needs a market to swap against. CEN is not listed on any exchange or decentralised venue yet, so there is nothing to swap with.'**
  String get walletSwapBody;

  /// No description provided for @walletReceiveNote.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this address can send coins to it. It is safe to share.'**
  String get walletReceiveNote;

  /// No description provided for @walletMiningReward.
  ///
  /// In en, this message translates to:
  /// **'Mining reward'**
  String get walletMiningReward;

  /// No description provided for @walletSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send CEN'**
  String get walletSendTitle;

  /// No description provided for @walletSendRecipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient address'**
  String get walletSendRecipient;

  /// No description provided for @walletSendAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get walletSendAmount;

  /// No description provided for @walletSendFee.
  ///
  /// In en, this message translates to:
  /// **'Network fee'**
  String get walletSendFee;

  /// No description provided for @walletSendConfirm.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get walletSendConfirm;

  /// No description provided for @walletSendSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get walletSendSending;

  /// No description provided for @walletSendNeedRecipient.
  ///
  /// In en, this message translates to:
  /// **'Enter a recipient address.'**
  String get walletSendNeedRecipient;

  /// No description provided for @walletSendInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount (up to 8 decimal places).'**
  String get walletSendInvalidAmount;

  /// No description provided for @walletSendNoKey.
  ///
  /// In en, this message translates to:
  /// **'No recovery words on this device. Back them up first.'**
  String get walletSendNoKey;

  /// No description provided for @walletSendKeyMismatch.
  ///
  /// In en, this message translates to:
  /// **'This device\'s recovery words do not own the mining address. Import the matching words first.'**
  String get walletSendKeyMismatch;

  /// No description provided for @walletSendFailed.
  ///
  /// In en, this message translates to:
  /// **'The node rejected the transfer.'**
  String get walletSendFailed;

  /// No description provided for @walletSendSuccess.
  ///
  /// In en, this message translates to:
  /// **'Transfer sent'**
  String get walletSendSuccess;

  /// No description provided for @walletSendSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'The transaction is now in the mempool and lands on-chain once a block includes it.'**
  String get walletSendSuccessBody;

  /// No description provided for @walletSendTxId.
  ///
  /// In en, this message translates to:
  /// **'Transaction id'**
  String get walletSendTxId;

  /// No description provided for @walletSendNoAddress.
  ///
  /// In en, this message translates to:
  /// **'No wallet address yet'**
  String get walletSendNoAddress;

  /// No description provided for @walletSendNoAddressBody.
  ///
  /// In en, this message translates to:
  /// **'The address appears once the bridge mines its first block. Until then there is nothing to send from.'**
  String get walletSendNoAddressBody;

  /// No description provided for @walletSendNodeDown.
  ///
  /// In en, this message translates to:
  /// **'The node isn\'t reachable'**
  String get walletSendNodeDown;

  /// No description provided for @walletSendNodeDownBody.
  ///
  /// In en, this message translates to:
  /// **'The wallet reaches your node through the bridge. Open the Miner tab and connect a node first.'**
  String get walletSendNodeDownBody;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'RECOVERY'**
  String get backupTitle;

  /// No description provided for @backupImportError.
  ///
  /// In en, this message translates to:
  /// **'That phrase is not a valid BIP39 phrase. Check the words and try again.'**
  String get backupImportError;

  /// No description provided for @backupImported.
  ///
  /// In en, this message translates to:
  /// **'Imported {address}'**
  String backupImported(String address);

  /// No description provided for @backupRecoveryWords.
  ///
  /// In en, this message translates to:
  /// **'Recovery words'**
  String get backupRecoveryWords;

  /// No description provided for @backupIntro.
  ///
  /// In en, this message translates to:
  /// **'Twelve words that rebuild your key on any device.'**
  String get backupIntro;

  /// No description provided for @backupWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why this matters'**
  String get backupWhyTitle;

  /// No description provided for @backupWhyBody.
  ///
  /// In en, this message translates to:
  /// **'Your coins sit on the blockchain, tied to an address. They survive the app being deleted. The one thing that does not survive is the key to that address, and these twelve words are the key.'**
  String get backupWhyBody;

  /// No description provided for @backupHowTitle.
  ///
  /// In en, this message translates to:
  /// **'What to do with them'**
  String get backupHowTitle;

  /// No description provided for @backupHowBody.
  ///
  /// In en, this message translates to:
  /// **'Write them on paper, in order, and keep the paper somewhere that is not this phone. Do not store them in a notes app, a screenshot, or a message to yourself.'**
  String get backupHowBody;

  /// No description provided for @backupCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get backupCreating;

  /// No description provided for @backupCreateWords.
  ///
  /// In en, this message translates to:
  /// **'Create recovery words'**
  String get backupCreateWords;

  /// No description provided for @backupHaveWords.
  ///
  /// In en, this message translates to:
  /// **'I already have words'**
  String get backupHaveWords;

  /// No description provided for @backupWriteNow.
  ///
  /// In en, this message translates to:
  /// **'Write these down now'**
  String get backupWriteNow;

  /// No description provided for @backupWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Anyone who reads these twelve words can move every coin at your address. They are shown once. After you leave this screen they are not shown again.'**
  String get backupWarningBody;

  /// No description provided for @backupWordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your 12 words, in order'**
  String get backupWordsTitle;

  /// No description provided for @backupWrittenCheck.
  ///
  /// In en, this message translates to:
  /// **'I have written all twelve words down in order'**
  String get backupWrittenCheck;

  /// No description provided for @backupNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not backed up yet'**
  String get backupNotYet;

  /// No description provided for @backupNotYetBody.
  ///
  /// In en, this message translates to:
  /// **'Recovery words exist on this device but have not been confirmed as written down. Until they are, losing this phone loses the key.'**
  String get backupNotYetBody;

  /// No description provided for @backupShowWords.
  ///
  /// In en, this message translates to:
  /// **'Show my words'**
  String get backupShowWords;

  /// No description provided for @backupDone.
  ///
  /// In en, this message translates to:
  /// **'Backed up'**
  String get backupDone;

  /// No description provided for @backupDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Your recovery words are confirmed as written down. Keep the paper somewhere this phone is not.'**
  String get backupDoneBody;

  /// No description provided for @backupIfDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'If the app is deleted'**
  String get backupIfDeletedTitle;

  /// No description provided for @backupIfDeletedBody.
  ///
  /// In en, this message translates to:
  /// **'Coins are not lost: they stay on the blockchain at your address. Reinstall the app, choose \"I already have words\", and enter the twelve words to take control of the address again.'**
  String get backupIfDeletedBody;

  /// No description provided for @backupShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Show my words again'**
  String get backupShowAgain;

  /// No description provided for @backupImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import words'**
  String get backupImportTitle;

  /// No description provided for @backupImportIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your existing 12 or 24 words to take control of that address on this device.'**
  String get backupImportIntro;

  /// No description provided for @bridgeTitle.
  ///
  /// In en, this message translates to:
  /// **'BRIDGE'**
  String get bridgeTitle;

  /// No description provided for @bridgeSaved.
  ///
  /// In en, this message translates to:
  /// **'Bridge address saved'**
  String get bridgeSaved;

  /// No description provided for @bridgeAddress.
  ///
  /// In en, this message translates to:
  /// **'Bridge address'**
  String get bridgeAddress;

  /// No description provided for @bridgeAddressNote.
  ///
  /// In en, this message translates to:
  /// **'The bridge serves mining results over HTTP. No account and no credentials are sent with the request.'**
  String get bridgeAddressNote;

  /// No description provided for @bridgePollInterval.
  ///
  /// In en, this message translates to:
  /// **'Poll interval'**
  String get bridgePollInterval;

  /// No description provided for @bridgePollNote.
  ///
  /// In en, this message translates to:
  /// **'How often the app asks the bridge for fresh figures. A shorter interval updates faster and uses more battery.'**
  String get bridgePollNote;

  /// No description provided for @bridgeAdUnit.
  ///
  /// In en, this message translates to:
  /// **'Ad unit id'**
  String get bridgeAdUnit;

  /// No description provided for @bridgeAdNote.
  ///
  /// In en, this message translates to:
  /// **'Optional. Leave it empty to use the unit built into the app. The banner only appears once a real ad is served: an empty slot reserves no space and shows nothing.'**
  String get bridgeAdNote;

  /// No description provided for @bridgeNode.
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get bridgeNode;

  /// No description provided for @bridgeInfoAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get bridgeInfoAddress;

  /// No description provided for @bridgeInfoVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get bridgeInfoVersion;

  /// No description provided for @bridgeInfoInstances.
  ///
  /// In en, this message translates to:
  /// **'Instances'**
  String get bridgeInfoInstances;

  /// No description provided for @workersTitle.
  ///
  /// In en, this message translates to:
  /// **'WORKERS'**
  String get workersTitle;

  /// No description provided for @workersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No workers reported. Point a miner at the bridge stratum port with your CEN address as the worker name and they appear here.'**
  String get workersEmpty;

  /// No description provided for @workersHashRate.
  ///
  /// In en, this message translates to:
  /// **'hash rate'**
  String get workersHashRate;

  /// No description provided for @workersBlocks.
  ///
  /// In en, this message translates to:
  /// **'blocks'**
  String get workersBlocks;

  /// No description provided for @workersStaleInvalid.
  ///
  /// In en, this message translates to:
  /// **'{stale} stale · {invalid} invalid'**
  String workersStaleInvalid(int stale, int invalid);

  /// No description provided for @workersSession.
  ///
  /// In en, this message translates to:
  /// **'session {duration}'**
  String workersSession(String duration);

  /// No description provided for @logTitle.
  ///
  /// In en, this message translates to:
  /// **'ACTIVITY'**
  String get logTitle;

  /// No description provided for @logEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet. Connection changes and newly accepted blocks are recorded here as they happen.'**
  String get logEmpty;

  /// No description provided for @logBridgeReachable.
  ///
  /// In en, this message translates to:
  /// **'Bridge reachable at {address}'**
  String logBridgeReachable(String address);

  /// No description provided for @logBridgeUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Bridge unreachable'**
  String get logBridgeUnreachable;

  /// No description provided for @logBlockAccepted.
  ///
  /// In en, this message translates to:
  /// **'Block accepted ({newCount} new, {total} total)'**
  String logBlockAccepted(int newCount, int total);

  /// No description provided for @logMinerStarted.
  ///
  /// In en, this message translates to:
  /// **'Internal CPU miner started'**
  String get logMinerStarted;

  /// No description provided for @logMinerStopped.
  ///
  /// In en, this message translates to:
  /// **'Internal CPU miner stopped'**
  String get logMinerStopped;

  /// No description provided for @logStaleShares.
  ///
  /// In en, this message translates to:
  /// **'{count} stale share(s) reported'**
  String logStaleShares(int count);

  /// No description provided for @logPollFailed.
  ///
  /// In en, this message translates to:
  /// **'Poll failed'**
  String get logPollFailed;

  /// No description provided for @logAdRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Ad request failed'**
  String get logAdRequestFailed;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileBlocks.
  ///
  /// In en, this message translates to:
  /// **'blocks'**
  String get profileBlocks;

  /// No description provided for @profileShares.
  ///
  /// In en, this message translates to:
  /// **'shares'**
  String get profileShares;

  /// No description provided for @profileWorkers.
  ///
  /// In en, this message translates to:
  /// **'workers'**
  String get profileWorkers;

  /// No description provided for @profileGhs.
  ///
  /// In en, this message translates to:
  /// **'gh/s'**
  String get profileGhs;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// No description provided for @profileNotSet.
  ///
  /// In en, this message translates to:
  /// **'not set'**
  String get profileNotSet;

  /// No description provided for @profileBridgeRow.
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get profileBridgeRow;

  /// No description provided for @profileWorkersRow.
  ///
  /// In en, this message translates to:
  /// **'Workers'**
  String get profileWorkersRow;

  /// No description provided for @profileActivityRow.
  ///
  /// In en, this message translates to:
  /// **'Activity log'**
  String get profileActivityRow;

  /// No description provided for @profileRecoveryRow.
  ///
  /// In en, this message translates to:
  /// **'Recovery words'**
  String get profileRecoveryRow;

  /// No description provided for @profileAboutRow.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileAboutRow;

  /// No description provided for @profileNoAddress.
  ///
  /// In en, this message translates to:
  /// **'no address reported'**
  String get profileNoAddress;

  /// No description provided for @profileMiningTo.
  ///
  /// In en, this message translates to:
  /// **'mining to {address}'**
  String profileMiningTo(String address);

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @profileLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get profileLanguageSystem;

  /// No description provided for @profileLanguageDone.
  ///
  /// In en, this message translates to:
  /// **'Language saved'**
  String get profileLanguageDone;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get aboutTitle;

  /// No description provided for @aboutWhatTitle.
  ///
  /// In en, this message translates to:
  /// **'What this app does'**
  String get aboutWhatTitle;

  /// No description provided for @aboutWhatBody.
  ///
  /// In en, this message translates to:
  /// **'It reads mining results from a Celenium bridge and shows them on your phone. It holds no account, no database, and no coins: the results live on the blockchain and the bridge, and this app is a window onto them.'**
  String get aboutWhatBody;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @aboutCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get aboutCreatedBy;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

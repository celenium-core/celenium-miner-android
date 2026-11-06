// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get commonClose => 'Tutup';

  @override
  String get commonCancel => 'Batal';

  @override
  String get commonContinue => 'Lanjutkan';

  @override
  String get commonDone => 'Selesai';

  @override
  String get commonSave => 'Simpan';

  @override
  String get commonSaving => 'Menyimpan…';

  @override
  String get commonImport => 'Impor';

  @override
  String get commonChecking => 'Memeriksa…';

  @override
  String get commonCopy => 'Salin';

  @override
  String get commonToday => 'HARI INI';

  @override
  String get commonYesterday => 'KEMARIN';

  @override
  String get commonNoWorker => 'Belum ada worker';

  @override
  String get statusActive => 'AKTIF';

  @override
  String get statusIdle => 'IDLE';

  @override
  String get statusOnline => 'TERSAMBUNG';

  @override
  String get statusOffline => 'TERPUTUS';

  @override
  String get navMine => 'Tambang';

  @override
  String get navWallet => 'Dompet';

  @override
  String get navProfile => 'Profil';

  @override
  String get splashEnterSemantics => 'Masuk ke konsol mining';

  @override
  String get splashEnter => 'MASUK';

  @override
  String get mineNodeNotSet => 'node belum diatur';

  @override
  String get mineHashRate => 'Laju hash';

  @override
  String get mineMiningActive => 'SEDANG MENAMBANG';

  @override
  String get mineBridgeSilent =>
      'Bridge belum menjawab. Atur alamatnya untuk mulai membaca angka langsung.';

  @override
  String get mineSetBridge => 'Atur alamat bridge';

  @override
  String get mineTapWorkers => '[ TAP UNTUK WORKER ]';

  @override
  String get mineWaitingShare => '> menunggu share pertama';

  @override
  String mineShareAccepted(String hash) {
    return '> share diterima $hash';
  }

  @override
  String get mineAcceptanceSemantics => 'Rasio share diterima. Buka worker.';

  @override
  String get mineAcceptanceNoShares => 'PENERIMAAN\nbelum ada share';

  @override
  String mineAcceptanceRate(String rate) {
    return 'PENERIMAAN\n$rate%';
  }

  @override
  String get mineSessionLabel => 'sesi';

  @override
  String get mineTotalLabel => 'total';

  @override
  String get mineSharesUnit => 'share';

  @override
  String get mineAcceptedLabel => 'diterima';

  @override
  String get mineNoBlock => 'belum ada blok diterima';

  @override
  String mineBlockAccepted(String hash) {
    return 'blok diterima $hash';
  }

  @override
  String get walletTitle => 'Dompet';

  @override
  String get walletTransactions => 'Transaksi';

  @override
  String get walletSeeAll => 'LIHAT SEMUA';

  @override
  String get walletNoTxReason =>
      'Belum ada transaksi. Blok yang ditambang worker kamu muncul di sini begitu diterima.';

  @override
  String get walletTotalBalance => 'Saldo total';

  @override
  String get walletNoBalanceNote =>
      'Saldo muncul setelah bridge terhubung ke node yang tersinkron.';

  @override
  String get walletMiningAddress => 'Alamat mining';

  @override
  String get walletAddressCopied => 'Alamat disalin';

  @override
  String get walletCopyAddress => 'Salin alamat';

  @override
  String get walletSend => 'Kirim';

  @override
  String get walletReceive => 'Terima';

  @override
  String get walletSwap => 'Tukar';

  @override
  String get walletBackupWords => 'Cadangkan kata pemulihan';

  @override
  String get walletSwapUnavailable => 'Tukar belum tersedia';

  @override
  String get walletSwapBody =>
      'Menukar CEN dengan aset lain butuh pasar sebagai lawan tukar. CEN belum terdaftar di bursa mana pun, jadi belum ada yang bisa ditukar.';

  @override
  String get walletReceiveNote =>
      'Siapa pun yang punya alamat ini bisa mengirim koin ke sana. Aman untuk dibagikan.';

  @override
  String get walletMiningReward => 'Imbalan mining';

  @override
  String get walletSendTitle => 'Kirim CEN';

  @override
  String get walletSendRecipient => 'Alamat tujuan';

  @override
  String get walletSendAmount => 'Jumlah';

  @override
  String get walletSendFee => 'Biaya jaringan';

  @override
  String get walletSendConfirm => 'Kirim';

  @override
  String get walletSendSending => 'Mengirim…';

  @override
  String get walletSendNeedRecipient => 'Masukkan alamat tujuan.';

  @override
  String get walletSendInvalidAmount =>
      'Masukkan jumlah yang valid (maksimal 8 angka desimal).';

  @override
  String get walletSendNoKey =>
      'Belum ada kata pemulihan di perangkat ini. Buat cadangannya dulu.';

  @override
  String get walletSendKeyMismatch =>
      'Kata pemulihan di perangkat ini bukan pemilik alamat mining tersebut. Impor kata yang sesuai dulu.';

  @override
  String get walletSendFailed => 'Node menolak transaksi ini.';

  @override
  String get walletSendSuccess => 'Transaksi terkirim';

  @override
  String get walletSendSuccessBody =>
      'Transaksi kini di mempool dan masuk ke chain begitu ada blok yang memuatnya.';

  @override
  String get walletSendTxId => 'ID transaksi';

  @override
  String get walletSendNoAddress => 'Belum ada alamat wallet';

  @override
  String get walletSendNoAddressBody =>
      'Alamat muncul setelah bridge menambang blok pertama. Sebelum itu belum ada yang bisa dikirim.';

  @override
  String get walletSendNodeDown => 'Node tidak terjangkau';

  @override
  String get walletSendNodeDownBody =>
      'Wallet terhubung ke node lewat bridge. Buka tab Miner dan sambungkan node dulu.';

  @override
  String get backupTitle => 'PEMULIHAN';

  @override
  String get backupImportError =>
      'Frasa itu bukan frasa BIP39 yang valid. Periksa kata-katanya lalu coba lagi.';

  @override
  String backupImported(String address) {
    return 'Terimpor $address';
  }

  @override
  String get backupRecoveryWords => 'Kata pemulihan';

  @override
  String get backupIntro =>
      'Dua belas kata yang membangun ulang kunci kamu di perangkat mana pun.';

  @override
  String get backupWhyTitle => 'Kenapa ini penting';

  @override
  String get backupWhyBody =>
      'Koin kamu berada di blockchain, terikat pada sebuah alamat. Koin itu tetap ada walau aplikasi dihapus. Yang tidak ikut tersimpan adalah kunci alamat tersebut, dan dua belas kata inilah kuncinya.';

  @override
  String get backupHowTitle => 'Yang harus dilakukan';

  @override
  String get backupHowBody =>
      'Tulis di kertas sesuai urutan, lalu simpan kertasnya di tempat selain ponsel ini. Jangan simpan di aplikasi catatan, tangkapan layar, atau pesan ke diri sendiri.';

  @override
  String get backupCreating => 'Membuat…';

  @override
  String get backupCreateWords => 'Buat kata pemulihan';

  @override
  String get backupHaveWords => 'Saya sudah punya kata';

  @override
  String get backupWriteNow => 'Tulis sekarang';

  @override
  String get backupWarningBody =>
      'Siapa pun yang membaca dua belas kata ini bisa memindahkan semua koin di alamat kamu. Kata-kata ini hanya ditampilkan sekali. Setelah kamu keluar dari layar ini, kata-kata itu tidak tampil lagi.';

  @override
  String get backupWordsTitle => '12 kata kamu, sesuai urutan';

  @override
  String get backupWrittenCheck =>
      'Saya sudah menulis kedua belas kata sesuai urutan';

  @override
  String get backupNotYet => 'Belum dicadangkan';

  @override
  String get backupNotYetBody =>
      'Kata pemulihan sudah ada di perangkat ini tapi belum dikonfirmasi tertulis. Selama belum, kehilangan ponsel ini berarti kehilangan kuncinya.';

  @override
  String get backupShowWords => 'Tampilkan kata saya';

  @override
  String get backupDone => 'Sudah dicadangkan';

  @override
  String get backupDoneBody =>
      'Kata pemulihan kamu sudah dikonfirmasi tertulis. Simpan kertasnya di tempat selain ponsel ini.';

  @override
  String get backupIfDeletedTitle => 'Kalau aplikasi dihapus';

  @override
  String get backupIfDeletedBody =>
      'Koin tidak hilang: koin tetap di blockchain pada alamat kamu. Pasang ulang aplikasinya, pilih \"Saya sudah punya kata\", lalu masukkan kedua belas kata untuk mengambil alih alamat itu lagi.';

  @override
  String get backupShowAgain => 'Tampilkan kata lagi';

  @override
  String get backupImportTitle => 'Impor kata';

  @override
  String get backupImportIntro =>
      'Masukkan 12 atau 24 kata yang sudah kamu punya untuk mengambil alih alamat itu di perangkat ini.';

  @override
  String get bridgeTitle => 'BRIDGE';

  @override
  String get bridgeSaved => 'Alamat bridge disimpan';

  @override
  String get bridgeAddress => 'Alamat bridge';

  @override
  String get bridgeAddressNote =>
      'Bridge menyajikan hasil mining lewat HTTP. Tidak ada akun dan tidak ada kredensial yang ikut dikirim.';

  @override
  String get bridgePollInterval => 'Interval polling';

  @override
  String get bridgePollNote =>
      'Seberapa sering aplikasi meminta angka baru ke bridge. Interval lebih pendek membuat tampilan lebih cepat berubah dan lebih boros baterai.';

  @override
  String get bridgeAdUnit => 'ID unit iklan';

  @override
  String get bridgeAdNote =>
      'Opsional. Kosongkan untuk memakai unit bawaan aplikasi. Banner hanya muncul setelah iklan benar-benar tersedia: slot kosong tidak memakan ruang dan tidak menampilkan apa pun.';

  @override
  String get bridgeNode => 'Node';

  @override
  String get bridgeInfoAddress => 'Alamat';

  @override
  String get bridgeInfoVersion => 'Versi';

  @override
  String get bridgeInfoInstances => 'Instans';

  @override
  String get workersTitle => 'WORKER';

  @override
  String get workersEmpty =>
      'Belum ada worker yang melapor. Arahkan miner ke port stratum bridge dengan alamat CEN kamu sebagai nama worker, maka worker itu muncul di sini.';

  @override
  String get workersHashRate => 'laju hash';

  @override
  String get workersBlocks => 'blok';

  @override
  String workersStaleInvalid(int stale, int invalid) {
    return '$stale usang · $invalid tidak valid';
  }

  @override
  String workersSession(String duration) {
    return 'sesi $duration';
  }

  @override
  String get logTitle => 'AKTIVITAS';

  @override
  String get logEmpty =>
      'Belum ada catatan. Perubahan koneksi dan blok yang baru diterima dicatat di sini saat terjadi.';

  @override
  String logBridgeReachable(String address) {
    return 'Bridge terhubung di $address';
  }

  @override
  String get logBridgeUnreachable => 'Bridge tidak terhubung';

  @override
  String logBlockAccepted(int newCount, int total) {
    return 'Blok diterima ($newCount baru, $total total)';
  }

  @override
  String get logMinerStarted => 'CPU miner internal mulai jalan';

  @override
  String get logMinerStopped => 'CPU miner internal berhenti';

  @override
  String logStaleShares(int count) {
    return '$count share usang dilaporkan';
  }

  @override
  String get logPollFailed => 'Polling gagal';

  @override
  String get logAdRequestFailed => 'Permintaan iklan gagal';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileBlocks => 'blok';

  @override
  String get profileShares => 'share';

  @override
  String get profileWorkers => 'worker';

  @override
  String get profileGhs => 'gh/s';

  @override
  String get profileSettings => 'Pengaturan';

  @override
  String get profileNotSet => 'belum diatur';

  @override
  String get profileBridgeRow => 'Bridge';

  @override
  String get profileWorkersRow => 'Worker';

  @override
  String get profileActivityRow => 'Log aktivitas';

  @override
  String get profileRecoveryRow => 'Kata pemulihan';

  @override
  String get profileAboutRow => 'Tentang';

  @override
  String get profileNoAddress => 'belum ada alamat dilaporkan';

  @override
  String profileMiningTo(String address) {
    return 'menambang ke $address';
  }

  @override
  String get profileLanguage => 'Bahasa';

  @override
  String get profileLanguageSystem => 'Ikuti sistem';

  @override
  String get profileLanguageDone => 'Bahasa disimpan';

  @override
  String get aboutTitle => 'TENTANG';

  @override
  String get aboutWhatTitle => 'Fungsi aplikasi ini';

  @override
  String get aboutWhatBody =>
      'Aplikasi ini membaca hasil mining dari sebuah bridge Celenium dan menampilkannya di ponsel kamu. Tidak ada akun, basis data, maupun koin yang disimpan di sini: hasilnya berada di blockchain dan di bridge, dan aplikasi ini hanya jendela untuk melihatnya.';

  @override
  String get aboutVersion => 'Versi';

  @override
  String get aboutCreatedBy => 'Dibuat oleh';
}

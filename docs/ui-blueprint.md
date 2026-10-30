# CEN UI/UX Blueprint

Dokumen ini acuan untuk mendesain UI/UX dua hal: **layar Wallet** (baru) dan **layout desktop aplikasi mining** (perombakan). Semua yang ditulis di sini sudah dicek terhadap kode yang ada, bukan karangan.

---

## 0. Design system yang sudah berjalan

Pakai ini sebagai basis. Jangan buat palet baru.

### Warna

| Token | Nilai | Pakai untuk |
|---|---|---|
| `field` | `#070B0F` | Latar paling dalam |
| `surface` | `#111820` | Kartu, panel |
| `surfaceHigh` | `#18212B` | Elemen di atas panel |
| `accent` | `#00F0FF` | Aksen utama, angka penting |
| `accentDim` | `#0A6E78` | Aksen redup, batas aktif |
| `textPrimary` | `#F2F6F8` | Teks utama |
| `textSecondary` | `#8A9BA8` | Label, keterangan |
| `warn` | `#FFB454` | Peringatan, belum backup |
| `danger` | `#FF6B6B` | Error, aksi merusak |

Aturan: aksen hanya di momen kunci. Jangan spam `accent` ke semua elemen.

### Tipografi

| Token | Font | Pakai untuk |
|---|---|---|
| `display` | Sora | Judul, angka besar |
| `body` | Manrope | Teks isi, label |
| `tabular` | FontFeature tabular | Semua angka yang berubah (hashrate, saldo) |

### Spacing & radius

| Token | Nilai |
|---|---|
| `xs` / `sm` / `md` | 4 / 8 / 12 |
| `lg` / `xl` / `xxl` | 16 / 24 / 32 |
| `pill` | 999 |

---

## 1. Arsitektur navigasi

### Kondisi sekarang

Aplikasi punya 4 destinasi:

| Destinasi | Label | Ikon |
|---|---|---|
| `dashboard` | Mining | `bolt_outlined` |
| `workers` | Workers | `dns_outlined` |
| `node` | Node | `settings_ethernet_outlined` |
| `activity` | Activity | `receipt_long_outlined` |

Responsif: `NavigationRail` di layar lebar, `NavigationBar` di layar sempit.

### Usulan: tambah 1 destinasi

| Destinasi | Label | Ikon usulan |
|---|---|---|
| `wallet` | Wallet | `account_balance_wallet_outlined` |

Total jadi 5. Di mobile, 5 item di bottom nav masih aman (batas nyaman 5).

Urutan usulan: **Mining, Workers, Wallet, Node, Activity**.

Alasan Wallet di posisi ketiga: setelah orang selesai mining, langkah berikutnya adalah melihat dan memindahkan hasilnya. Node dan Activity adalah layar teknis yang lebih jarang dibuka.

---

## 2. WALLET (layar baru)

### 2.1 Prinsip desain

Wallet di aplikasi ini **bukan penyimpan koin**. Dia tempat:

1. melihat alamat `cen69:...`
2. menyimpan dan memulihkan 12 kata rahasia
3. mengirim dan menerima (nanti, butuh node)

Konsekuensi desain: **jangan pernah tampilkan 12 kata tanpa penjaga.** Jangan pernah pakai ikon "mata" biasa yang bisa diketuk tanpa konfirmasi.

### 2.2 Layar W1: Wallet Home

**Pekerjaan layar:** user ingin tahu "berapa saldo saya dan apa alamat saya".

**Satu keputusan yang diambil di sini:** salin alamat, atau buka kirim/terima.

**Struktur atas ke bawah:**

| Urutan | Blok | Isi | Sumber data |
|---|---|---|---|
| 1 | **Saldo** | Angka besar + ticker `CEN` | Node, kalau tersambung |
| 2 | **Status koneksi** | Satu baris: node tersambung atau tidak | Bridge |
| 3 | **Alamat** | Alamat `cen69:...` + tombol Salin + tombol Terima | Lokal, selalu ada |
| 4 | **Peringatan backup** | Muncul hanya kalau 12 kata belum dicadangkan | Lokal |
| 5 | **Aksi** | Dua tombol: Terima, Kirim | Kirim butuh node |
| 6 | **Riwayat** | Daftar transaksi | Node |
| 7 | **Catatan kaki** | "Kunci Anda tidak pernah meninggalkan perangkat ini" | Statis |

**Tiga keadaan blok Saldo:**

| Keadaan | Yang tampil |
|---|---|
| Wallet belum dibuat | Ajakan buat wallet, satu tombol |
| Wallet ada, node tidak tersambung | "Sambungkan node untuk melihat saldo" + tombol ke layar Node |
| Wallet ada, node tersambung | Angka saldo |

Jangan tampilkan `0.00` saat node tidak tersambung. Itu bohong, user akan mengira koinnya hilang.

### 2.3 Layar W2: Buat Wallet (sekali saja)

**Pekerjaan layar:** user membuat kunci baru tanpa paham kriptografi.

**Alur 4 langkah, tidak bisa dilewati:**

| Langkah | Layar | Catatan desain |
|---|---|---|
| 1 | Penjelasan singkat | "Wallet dibuat di perangkat ini. Tidak ada akun, tidak ada email, tidak ada password." |
| 2 | **12 kata muncul** | Grid bernomor. Peringatan tegas di atas. |
| 3 | Konfirmasi | User harus memilih atau mengetik ulang 3 kata acak dari 12 |
| 4 | Selesai | Alamat `cen69:...` tampil, tombol salin |

**Aturan keras untuk langkah 2:**

- 12 kata tampil **sekali saja**. Tidak ada tombol "lihat lagi" tanpa backup.
- Peringatan harus menyebut konsekuensi: siapa pun yang punya 12 kata ini bisa memindahkan seluruh koin.
- Tidak boleh ada tombol screenshot yang memudahkan (biarkan screenshot OS, tapi jangan sediakan tombol "bagung").
- Grid 12 kata: mobile 2 kolom x 6 baris atau 3 x 4, desktop 4 x 3 atau 6 x 2. Nomor urut wajib ada, karena urutan menentukan kecukupan.

### 2.4 Layar W3: Cadangkan / Lihat 12 Kata

**Pekerjaan layar:** user menyelamatkan 12 kata ke media luar HP.

**Struktur:**

| Urutan | Blok | Isi |
|---|---|---|
| 1 | Peringatan | Teks konsekuensi, warna `warn` atau `danger` |
| 2 | Grid 12 kata | Bernomor, font monospace atau `tabular` |
| 3 | Kotak centang | "Saya sudah menulis 12 kata ini di tempat aman" |
| 4 | Tombol Salin | Nonaktif sampai kotak centang dicentang |
| 5 | Tombol Selesai | Kembali ke Wallet Home |

**Catatan penting:** kalau sidik jari sudah dipasang, layar ini yang jadi gerbang. Tapi status "sudah dicadangkan" harus bisa dicatat **tanpa** sidik jari, supaya peringatan di Wallet Home bisa hilang setelah user benar-benar backup.

Artinya perlu dua hal yang disimpan terpisah: 12 kata (rahasia) dan status "sudah dicadangkan" (bukan rahasia).

### 2.5 Layar W4: Import Wallet

**Pekerjaan layar:** user pindah HP atau pulihkan wallet lama.

**Struktur:**

| Urutan | Blok | Isi |
|---|---|---|
| 1 | Peringatan | "Ini akan mengganti wallet di perangkat ini" |
| 2 | Field 12/24 kata | Multiline, autocomplete kata BIP39 |
| 3 | Validasi langsung | Cek checksum BIP39 saat mengetik |
| 4 | Pratinjau alamat | Alamat hasil import tampil sebelum konfirmasi |
| 5 | Konfirmasi | Ketik kata tertentu, atau ketik "GANTI" |
| 6 | Selesai | Masuk Wallet Home dengan wallet baru |

**Aturan:** jangan pernah import langsung tanpa pratinjau alamat. User harus bisa memastikan itu alamat yang benar sebelum wallet lama diganti.

### 2.6 Layar W5: Terima

**Pekerjaan layar:** user memberi alamat ke orang lain atau ke bridge mining.

**Struktur:**

| Urutan | Blok | Isi |
|---|---|---|
| 1 | Label jaringan | `cen69` (mainnet) atau `cen69test` (testnet) |
| 2 | QR code | Alamat ter-encode |
| 3 | Alamat lengkap | Monospace, wrap, bisa diseleksi |
| 4 | Tombol Salin | |
| 5 | Peringatan testnet | Muncul hanya kalau jaringan testnet |

Peringatan testnet wajib: "Anda di testnet. Koin di sini tidak punya nilai." Ini mencegah orang mengira mereka kaya.

### 2.7 Layar W6: Kirim

**Pekerjaan layar:** user memindahkan koin ke alamat lain.

**Catatan jujur:** layar ini butuh node untuk broadcast dan untuk tahu saldo serta UTXO. Selama node publik belum ada, desainnya bisa dibuat tapi fungsinya terbatas.

**Struktur:**

| Urutan | Blok | Isi |
|---|---|---|
| 1 | Alamat tujuan | Validasi prefix + checksum bech32 saat mengetik |
| 2 | Jumlah | Dengan tombol "Semua" |
| 3 | Perkiraan biaya | Dari node |
| 4 | Ringkasan | Tujuan, jumlah, biaya, total |
| 5 | Konfirmasi | Sidik jari kalau ada |
| 6 | Hasil | ID transaksi + link eksplorer |

**Validasi alamat tujuan harus menolak:**
- prefix jaringan yang berbeda (kirim `cen69test:` ke alamat `cen69:`)
- checksum bech32 salah
- alamat kosong

Kalau salah satu, jangan diam diam menerima. Tampilkan alasannya.

---

## 3. DESKTOP MINING APP (perombakan layout)

### 3.1 Masalah layout sekarang

Aplikasi sekarang memakai satu layout untuk semua lebar: `NavigationRail` di lebar, `NavigationBar` di sempit. Isi layar **sama** di keduanya, cuma navigasinya yang pindah.

Itu berarti di desktop, panel panel yang dirancang untuk kolom sempit direntangkan jadi satu kolom panjang. Layar 1920px jadi terlihat kosong dan jauh sekali antar elemen.

### 3.2 Tiga keadaan, bukan dua

| Lebar | Nama | Navigasi | Isi |
|---|---|---|---|
| < 640px | Phone | Bottom `NavigationBar` | Satu kolom |
| 640 - 1024px | Tablet | `NavigationRail` ringkas (ikon saja) | Satu atau dua kolom |
| ≥ 1024px | Desktop | `NavigationRail` penuh dengan label | Dua kolom |

Jangan pakai breakpoint berdasarkan daftar HP (375, 414, 768). Taruh breakpoint di tempat isi benar-benar berhenti enak dibaca.

### 3.3 Layout Desktop

**Kerangka:**

| Zona | Lebar | Isi |
|---|---|---|
| Kiri | 88 - 240px | `NavigationRail`, 5 destinasi, label selalu tampil |
| Kanan | Sisa | Konten, padding `xl` (24) |
| Bawah kanan | Overlay | Banner iklan, hanya kalau iklan asli sudah masuk |

**Per destinasi di desktop:**

#### Mining (dashboard)

Dua kolom. Kolom kiri lebih lebar karena di situ angka utama.

| Kolom | Isi |
|---|---|
| Kiri (60%) | Hashrate terbesar + grafik + blok terbaru |
| Kanan (40%) | Panel jaringan + panel payout + batas instance |

Angka hashrate pakai `display` font dan `tabular`, karena berubah tiap detik. Kalau tidak tabular, angka akan bergoyang dan menyakitkan dibaca.

#### Workers

Desktop layak untuk **tabel**, bukan kartu. Tabel memuat lebih banyak kolom tanpa scroll horizontal.

| Kolom | Alasan dipilih |
|---|---|
| Instance | Menentukan node mana |
| Worker | Menentukan perangkat |
| Hashrate | Angka utama |
| Shares | Bukti kerja |
| Stale / Invalid | Deteksi masalah |
| Blocks | Hasil nyata |
| Status | Terakhir terlihat |

Di phone, tabel ini jadi kartu per worker. Kolom Stale dan Invalid bisa disembunyikan kalau semuanya nol.

#### Node

Dua kolom: pengaturan di kiri, informasi privasi dan iklan di kanan. Ini layar yang jarang dibuka, jadi kepadatan boleh lebih tinggi.

#### Activity

Satu kolom penuh, log memakai lebar penuh. Ada filter tingkat (info, warn, error) di atas. Di desktop, baris log panjang muat tanpa wrap.

### 3.4 Layout Phone

| Zona | Isi |
|---|---|
| Atas | Judul layar + tombol refresh |
| Tengah | Satu kolom, semua panel menumpuk |
| Bawah | `NavigationBar` 5 item |
| Atas bottom nav | Overlay banner iklan |

**Wajib:** beri jarak bawah konten setinggi bottom nav + banner, supaya item terakhir tidak tertutup.

### 3.5 Banner iklan (sudah jadi, untuk konsistensi desain)

Aturan yang sudah dipakai di kode, pertahankan di desain:

| Aturan | Alasan |
|---|---|
| Banner hanya muncul kalau iklan asli sudah masuk | Placeholder yang menahan ruang bukan iklan |
| Slot kosong tidak reservasi ruang sama sekali | Jangan ada kotak kosong |
| Banner mengambang, tidak mendorong konten | Konten tidak bergeser saat iklan muncul |
| Footprint tetap `tinggi + Space.sm` | Tidak ada layout shift |
| Bisa ditutup permanen | User punya kendali |

---

## 4. Matriks ketersediaan data

Ini yang paling penting untuk desainer. Banyak blok tidak punya data di semua keadaan, dan desain harus punya jawaban untuk masing-masing.

### Wallet

| Blok | Wallet belum ada | Wallet ada, node mati | Wallet + node |
|---|---|---|---|
| Saldo | Ajakan buat wallet | Pesan sambungkan node | Angka |
| Alamat | Ajakan buat wallet | Alamat | Alamat |
| Peringatan backup | Tidak relevan | Tampil kalau belum backup | Tampil kalau belum backup |
| Tombol Kirim | Tidak aktif | Tidak aktif | Aktif |
| Riwayat | Tidak relevan | Pesan sambungkan node | Daftar |
| Lihat 12 kata | Tidak ada | Aktif | Aktif |

### Mining

| Blok | Bridge mati | Bridge hidup, tidak mining | Bridge hidup, mining |
|---|---|---|---|
| Hashrate | Pesan sambungkan bridge | 0.00 GH/s | Angka nyata |
| Workers | Pesan | Daftar kosong + ajakan | Daftar worker |
| Blok | Pesan | "Belum ada blok" | Daftar blok |
| Alamat payout | Pesan | Alamat dari node | Alamat dari node |

**Aturan untuk semua keadaan kosong:** sebutkan penyebabnya dan beri satu aksi yang mengisinya. Jangan tulis "Tidak ada data".

---

## 5. Empty, loading, error

| Keadaan | Yang harus ada | Contoh penulisan |
|---|---|---|
| Kosong | Penyebab + 1 aksi | "Belum ada blok. Mulai mining untuk melihat hasil di sini." |
| Memuat | Apa yang sedang dimuat | "Menyambungkan ke node..." |
| Error | Apa yang gagal + apa yang harus dilakukan | "Tidak bisa menyambung ke 127.0.0.1:26510. Periksa alamat bridge di layar Node." |
| Offline | Bedakan dari error | "Node tidak tersambung. Saldo tidak bisa diperiksa sekarang." |

Jangan pakai ilustrasi dekoratif di empty state. Teks yang jelas sudah cukup.

---

## 6. Checklist serahkan ke desainer

Sebelum desain dianggap siap, pastikan:

- [ ] Palet memakai token di bagian 0, tidak ada warna baru tanpa alasan
- [ ] Aksen `accent` tidak dipakai di semua elemen
- [ ] Tidak ada emoji sebagai hiasan di teks UI
- [ ] Semua angka di state kosong atau loading ditandai jelas, tidak ada angka karangan
- [ ] Setiap layar punya empty, loading, dan error state
- [ ] Target sentuh minimal 44 x 44 px dengan jarak antar tombol
- [ ] Semua interaksi punya padanan tap, tidak ada yang hover-only
- [ ] Bottom nav tidak menutupi konten terakhir
- [ ] Ada tiga keadaan lebar, bukan dua
- [ ] Tidak ada scroll horizontal di lebar paling sempit
- [ ] Setelah wallet ada, 12 kata tidak bisa dilihat tanpa penjaga
- [ ] Ada penanda jelas kalau pengguna di testnet

---

## 7. Yang belum bisa dijanjikan

Agar desain tidak menjanjikan sesuatu yang belum ada:

| Fitur | Status |
|---|---|
| Saldo, riwayat, kirim | Butuh node yang bisa dijangkau |
| Sidik jari | Belum dipasang, dan tingkat kekuatannya masih harus diputuskan |
| Notifikasi push | Butuh server, belum ada |
| Sinkronisasi antar perangkat | Tidak direncanakan, dan memang tidak perlu |

Kalau desain memuat fitur di tabel ini, tandai jelas sebagai "Coming soon" atau keluarkan dari cakupan.

ANTI-GDl32 - Pembersih virus Floxif untuk folder Atlantica Eternal
==================================================================

APA MASALAHNYA?
Beberapa salinan klien Atlantica Eternal yang beredar (BUKAN dari launcher resmi)
membawa virus Floxif (Virus:Win32/Floxif.H). Tandanya:
  - ada file GDl32.dll (huruf L kecil) di folder game
  - d3dx10_39.dll berukuran 546.263 byte (aslinya 467.984 byte)
  - bdaudio32.dll berukuran 355.271 byte (aslinya 276.992 byte)
Menghapus GDl32.dll saja TIDAK cukup: file itu dibuat ulang setiap game dibuka
selama d3dx10_39.dll / bdaudio32.dll yang tertular masih ada.

CARA PAKAI
1. Tutup game dan launcher.
2. Double-click JALANKAN.bat, klik Yes pada jendela UAC.
3. Pilih nomor folder game Atlantica Anda (atau pilih manual).
4. Tunggu sampai muncul HASIL.
5. Buka game sekali, tutup, lalu jalankan JALANKAN.bat lagi -> harus "BERSIH".
6. Jalankan Windows Security > Full scan, lalu Microsoft Defender Offline scan.

APA YANG DILAKUKAN SKRIP
- Menghapus GDl32.dll, gdl32.dll.000, dan file lain yang hash-nya = DLL Floxif.
- Mengganti d3dx10_39.dll dan bdaudio32.dll yang tertular dengan versi resmi
  (ada di folder "files", diambil dari installer resmi Eternal).
- Menghapus vcredist_x86.exe dan vcredist_x86(2005).exe di folder Update bila tertular
  (installer lama, tidak dipakai game).
- Menghapus salinan virus di folder Windows (symsrv.dll, dlcoer.dll, conres.dll)
  HANYA jika hash-nya cocok dengan Floxif. File lain tidak disentuh.
- Catatan setiap proses disimpan di folder "log".

BATASAN
Skrip ini hanya membersihkan folder game dan salinan virus yang sudah dikenal.
Jika PC Anda tidak punya antivirus aktif (mis. Windows Specter / Windows modifikasi),
program lain di PC kemungkinan sudah ikut tertular. Backup data pribadi saja
(dokumen, foto, video - jangan file .exe/.dll), lalu install ulang Windows resmi.

Mode cek saja (tidak mengubah apa pun), dari PowerShell:
  powershell -ExecutionPolicy Bypass -File Anti-GDl32.ps1 -CekSaja

Hash DLL Floxif (SHA256):
  DE055A89DE246E629A8694BDE18AF2B1605E4B9B493C7E4AEF669DD67ACF5085

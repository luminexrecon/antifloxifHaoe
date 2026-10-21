<#
  Anti-GDl32 - membersihkan infeksi Floxif (GDl32.dll) dari folder game Atlantica.

  Cara pakai: double-click JALANKAN.bat (lihat BACA-SAYA.txt).

  Parameter opsional:
    -GameDir "D:\Atlantica Eternal INA"  langsung pilih folder game
    -CekSaja                              hanya memeriksa, tidak mengubah apa pun
    -TanpaAdmin                           untuk pengujian: lewati pembersihan file sistem
    -TanpaJeda                            jangan menunggu ENTER di akhir

  Indikator diambil dari analisis 21-10-2026: Windows Defender (Virus:Win32/Floxif.H),
  VirusTotal, dan perbandingan CRC32 dengan installer resmi Eternal di server patch.
#>
param(
    [string]$GameDir,
    [switch]$CekSaja,
    [switch]$TanpaAdmin,
    [switch]$TanpaJeda
)

$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $PSCommandPath

# --- Indikator infeksi ---------------------------------------------------------------
$FloxifSha256 = 'DE055A89DE246E629A8694BDE18AF2B1605E4B9B493C7E4AEF669DD67ACF5085'
$FloxifSize   = 69337
$InfectGrowth = 78279   # file yang tertular selalu bertambah tepat sebesar ini

# DLL game yang dimuat Atlantica.exe; versi resmi dibundel di folder "files".
$OfficialDll = [ordered]@{
    'd3dx10_39.dll' = @{ Size = 467984; Sha256 = '613AFDB8B44BB3BED945279229D9604A3CD553F8C2B9B091235CBAB8CD00DE61' }
    'bdaudio32.dll' = @{ Size = 276992; Sha256 = '74573DC9A902CF1FD1A4802CD6646B7871034396B7AC1FFDEEA9288367C7A266' }
}
# Installer lama yang tidak dipakai game; cukup dihapus bila tertular.
$OfficialInstallerSize = [ordered]@{
    'Update\vcredist_x86.exe'       = 4485976
    'Update\vcredist_x86(2005).exe' = 2705744
}
# Lokasi tempat virus menaruh salinan dirinya; dihapus HANYA jika hash-nya Floxif.
$DropPaths = @(
    'C:\Program Files\Common Files\System\symsrv.dll',
    'C:\Program Files (x86)\Common Files\System\symsrv.dll',
    "$env:WINDIR\SysWOW64\dlcoer.dll",
    "$env:WINDIR\System32\dlcoer.dll",
    "$env:TEMP\conres.dll",
    "$env:WINDIR\Temp\conres.dll"
)

# --- Tampilan --------------------------------------------------------------------------
function Write-Ok($m)   { Write-Host "  [OK]    $m" -ForegroundColor Green }
function Write-Bad($m)  { Write-Host "  [!]     $m" -ForegroundColor Red }
function Write-Fix($m)  { Write-Host "  [FIX]   $m" -ForegroundColor Yellow }
function Write-Info($m) { Write-Host $m -ForegroundColor Cyan }
function Pause-End {
    if (-not $TanpaJeda) { Write-Host ''; Read-Host 'Tekan ENTER untuk menutup' | Out-Null }
}

# --- Hak admin -------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $CekSaja -and -not $TanpaAdmin) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($GameDir) { $argList += @('-GameDir', "`"$GameDir`"") }
    try { Start-Process powershell -Verb RunAs -ArgumentList $argList }
    catch { Write-Bad 'Butuh hak Administrator. Klik Yes pada jendela UAC.'; Pause-End }
    return
}

$logDir = Join-Path $Here 'log'
try {
    New-Item -ItemType Directory -Force $logDir | Out-Null
    Start-Transcript -Path (Join-Path $logDir ("Anti-GDl32_{0:yyyyMMdd_HHmmss}.txt" -f (Get-Date))) | Out-Null
} catch { }

Write-Host ''
Write-Host '=== Anti-GDl32 : pembersih Floxif untuk folder Atlantica ===' -ForegroundColor White
if ($CekSaja) { Write-Host '    MODE CEK SAJA - tidak ada file yang diubah' -ForegroundColor Magenta }
Write-Host ''

# --- Pilih folder game -----------------------------------------------------------------
function Find-AtlanticaFolders {
    $found = New-Object System.Collections.Generic.List[string]
    try {
        $reg = (Get-ItemProperty 'HKCU:\Software\Valofe\Atlantica' -ErrorAction Stop).PATH
        if ($reg) { $found.Add($reg.TrimEnd('\')) }
    } catch { }
    $drives = [IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.DriveType -in 'Fixed', 'Removable' }
    foreach ($d in $drives) {
        foreach ($l1 in (Get-ChildItem $d.RootDirectory.FullName -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin 'Windows', '$Recycle.Bin', 'System Volume Information' })) {
            $found.Add($l1.FullName)
            foreach ($l2 in (Get-ChildItem $l1.FullName -Directory -ErrorAction SilentlyContinue)) { $found.Add($l2.FullName) }
        }
    }
    $found | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'Atlantica.exe') } | Sort-Object -Unique
}

if ($GameDir) {
    $GameDir = $GameDir.TrimEnd('\')
} else {
    Write-Info 'Mencari folder yang berisi Atlantica.exe...'
    $candidates = @(Find-AtlanticaFolders)
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        $tag = if (Test-Path -LiteralPath (Join-Path $candidates[$i] 'ATLauncher.exe')) { '  (Eternal)' } else { '' }
        Write-Host ("  [{0}] {1}{2}" -f ($i + 1), $candidates[$i], $tag)
    }
    Write-Host '  [0] Pilih folder lain secara manual'
    $pick = Read-Host 'Ketik nomor folder yang akan dibersihkan'
    if ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $candidates.Count) {
        $GameDir = $candidates[[int]$pick - 1]
    } else {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Pilih folder game Atlantica (yang berisi Atlantica.exe)'
        if ($dlg.ShowDialog() -eq 'OK') { $GameDir = $dlg.SelectedPath.TrimEnd('\') }
    }
}
if (-not $GameDir -or -not (Test-Path -LiteralPath (Join-Path $GameDir 'Atlantica.exe'))) {
    Write-Bad "Folder tidak valid (Atlantica.exe tidak ditemukan): $GameDir"
    try { Stop-Transcript | Out-Null } catch { }
    Pause-End; return
}
Write-Info "Folder game: $GameDir"

# --- Game harus tertutup ---------------------------------------------------------------
function Test-Locked($path) {
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    try { $fs = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None'); $fs.Close(); return $false } catch { return $true }
}
$running = Get-Process -Name Atlantica, ATLauncher -ErrorAction SilentlyContinue | Where-Object {
    try { $_.Path -and $_.Path.StartsWith($GameDir + '\', [StringComparison]::OrdinalIgnoreCase) } catch { $false }
}
if ($running -or (Test-Locked (Join-Path $GameDir 'd3dx10_39.dll')) -or (Test-Locked (Join-Path $GameDir 'GDl32.dll'))) {
    Write-Bad 'Game atau launcher dari folder ini masih berjalan. Tutup dulu, lalu jalankan skrip ini lagi.'
    try { Stop-Transcript | Out-Null } catch { }
    Pause-End; return
}

$found = 0; $fixed = 0; $failed = 0
function Remove-Infected($path, $why) {
    $script:found++
    if ($CekSaja) { Write-Bad "$why : $path"; return }
    try {
        Set-ItemProperty -LiteralPath $path -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $path -Force
        $script:fixed++; Write-Fix "dihapus ($why): $path"
    } catch { $script:failed++; Write-Bad "GAGAL menghapus $path : $($_.Exception.Message)" }
}

# --- 1. File virus di folder game ------------------------------------------------------
Write-Info "`n[1/4] Mencari file virus (GDl32.dll dan salinannya)..."
$before = $found
foreach ($n in 'GDl32.dll', 'gdl32.dll.000') {
    $p = Join-Path $GameDir $n
    if (Test-Path -LiteralPath $p) { Remove-Infected $p 'file virus Floxif' }
}
Get-ChildItem -LiteralPath $GameDir -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -eq $FloxifSize -and $_.Name -ne 'GDl32.dll' } |
    ForEach-Object {
        if ((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash -eq $FloxifSha256) {
            Remove-Infected $_.FullName 'salinan DLL Floxif'
        }
    }
if ($found -eq $before) { Write-Ok 'Tidak ada file virus.' }

# --- 2. DLL game yang tertular ---------------------------------------------------------
Write-Info "`n[2/4] Memeriksa DLL game yang biasa tertular..."
foreach ($n in $OfficialDll.Keys) {
    $p = Join-Path $GameDir $n
    $ref = $OfficialDll[$n]
    if (-not (Test-Path -LiteralPath $p)) { Write-Ok "$n tidak ada (dilewati)"; continue }
    $hash = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
    $size = (Get-Item -LiteralPath $p).Length
    if ($hash -eq $ref.Sha256) { Write-Ok "$n asli"; continue }
    if ($size -ne $ref.Size + $InfectGrowth) {
        Write-Host "  [?]     $n berbeda dari versi Eternal tapi bukan pola Floxif ($size byte) - dibiarkan" -ForegroundColor DarkYellow
        continue
    }
    $found++
    if ($CekSaja) { Write-Bad "$n TERTULAR ($size byte, seharusnya $($ref.Size))"; continue }
    $src = Join-Path $Here "files\$n"
    if (-not (Test-Path -LiteralPath $src) -or (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash -ne $ref.Sha256) {
        $failed++; Write-Bad "File pengganti $src hilang/rusak - $n TIDAK diganti"; continue
    }
    try { Copy-Item -LiteralPath $src -Destination $p -Force; $fixed++; Write-Fix "$n diganti dengan versi resmi" }
    catch { $failed++; Write-Bad "GAGAL mengganti $n : $($_.Exception.Message)" }
}

# --- 3. Installer lama yang tertular ---------------------------------------------------
Write-Info "`n[3/4] Memeriksa installer lama di folder Update..."
$before = $found
foreach ($rel in $OfficialInstallerSize.Keys) {
    $p = Join-Path $GameDir $rel
    if ((Test-Path -LiteralPath $p) -and (Get-Item -LiteralPath $p).Length -eq $OfficialInstallerSize[$rel] + $InfectGrowth) {
        Remove-Infected $p 'installer tertular, tidak dipakai game'
    }
}
if ($found -eq $before) { Write-Ok 'Aman.' }

# --- 4. Salinan virus di folder Windows ------------------------------------------------
Write-Info "`n[4/4] Memeriksa salinan virus di folder Windows..."
$before = $found
foreach ($p in $DropPaths) {
    if (-not (Test-Path -LiteralPath $p)) { continue }
    $hash = try { (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash } catch { '' }
    if ($hash -ne $FloxifSha256) { Write-Ok "$p ada tapi bukan Floxif (dibiarkan)"; continue }
    if ($TanpaAdmin -and -not $isAdmin) { $found++; Write-Bad "Floxif ditemukan (butuh admin untuk menghapus): $p"; continue }
    Remove-Infected $p 'salinan Floxif di sistem'
}
if ($found -eq $before) { Write-Ok 'Tidak ada salinan virus di folder Windows.' }

# --- Ringkasan -------------------------------------------------------------------------
Write-Host ''
Write-Host '=== HASIL ===' -ForegroundColor White
if ($found -eq 0) {
    Write-Host '  BERSIH - tidak ditemukan tanda infeksi Floxif di folder ini.' -ForegroundColor Green
} elseif ($CekSaja) {
    Write-Host "  TERINFEKSI - $found temuan. Jalankan lagi TANPA -CekSaja untuk membersihkan." -ForegroundColor Red
} elseif ($failed -eq 0) {
    Write-Host "  DIBERSIHKAN - $fixed perbaikan berhasil." -ForegroundColor Yellow
    Write-Host '  Buka game sekali, tutup, lalu jalankan skrip ini lagi: hasilnya harus BERSIH.'
} else {
    Write-Host "  SEBAGIAN GAGAL - $fixed berhasil, $failed gagal. Lihat pesan [!] di atas." -ForegroundColor Red
}
Write-Host ''
Write-Host 'PENTING:' -ForegroundColor White
Write-Host '  - Skrip ini hanya membersihkan folder game dan salinan virus yang sudah dikenal.'
Write-Host '  - Lanjutkan dengan Windows Security > Full scan, lalu Microsoft Defender Offline scan.'
Write-Host '  - Jika Windows Anda tanpa antivirus (mis. Windows Specter / Windows modifikasi), program'
Write-Host '    lain di PC kemungkinan sudah ikut tertular: backup data pribadi saja (jangan file .exe/.dll),'
Write-Host '    lalu install ulang Windows resmi.'
Write-Host '  - Pasang Atlantica Eternal hanya lewat launcher resmi, jangan dari paket salinan orang lain.'

try { Stop-Transcript | Out-Null } catch { }
Pause-End

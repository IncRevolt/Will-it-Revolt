# ============================================================
#  Will It Revolt?  —  RR Turbo compatibility checker
#  READ-ONLY. It only reads your specs. It changes nothing,
#  installs nothing, and needs no administrator rights.
#  build 2026-11-01  (three-tier verdict + free AI tier + TURN-KEY activation read)
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

# ---- RR Turbo 7.7 Core — minimum floor ----
# Gate on THREADS, not physical cores: a modern 2c/4t chip (Zen, etc.)
# outruns an old 4c/4t Atom, and threads track real-world feel better.
$minThreads = 4; $minRAMgb = 4; $minDiskGB = 64
# ---- Recommended — AI editions (7.5 / 7.6 / 7.8) ----
$recThreads = 8; $recClockGHz = 3.0; $recRAMgb = 16; $recVRAMgb = 4

function GB($bytes) { if ($bytes) { [math]::Round($bytes / 1GB, 1) } else { 0 } }
function Mark($ok)  { if ($ok) { '[ PASS ]' } else { '[ UNDER ]' } }

# ---- CPU ----
$cpu     = Get-CimInstance Win32_Processor | Select-Object -First 1
$cores   = [int]$cpu.NumberOfCores
$threads = [int]$cpu.NumberOfLogicalProcessors
$clock   = [math]::Round($cpu.MaxClockSpeed / 1000, 1)   # rated/base - not boost
$is64    = [Environment]::Is64BitOperatingSystem

# ---- Memory ----
# INSTALLED RAM = sum of the physical sticks (the real, headline number).
# USABLE RAM (Win32_ComputerSystem) is lower - the iGPU and firmware reserve
# some - so never gate on it, or a true 4 GB machine fails its own 4 GB floor.
$installed = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
$usableRaw = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
if (-not $installed) { $installed = $usableRaw }   # fallback for odd VMs
$ramGB    = GB $installed
$usableGB = GB $usableRaw

# ---- System drive ----
$sys       = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
$diskTotGB = GB $sys.Size
$diskFreeGB= GB $sys.FreeSpace

# ---- Firmware / Secure Boot (no admin; read-only) ----
$sb = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' -EA SilentlyContinue
if ($sb) { $uefi = $true;  $sbOn = ($sb.UEFISecureBootEnabled -eq 1) }
else     { $uefi = $false; $sbOn = $false }
$fw = if ($uefi) { 'UEFI' } else { 'Legacy BIOS (best-effort)' }

# ---- TPM ----
$tpmVer = 'none detected (or needs admin)'
$tpm = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -Class Win32_Tpm -EA SilentlyContinue
if ($tpm -and $tpm.SpecVersion) { $tpmVer = ($tpm.SpecVersion -split ',')[0].Trim() }
$tpm2 = ($tpmVer -like '2.0*')

# ---- SSE4.2 / POPCNT  (the real 24H2+ hard floor) ----
$sse42 = 'Unknown'
$build = [Environment]::OSVersion.Version.Build
if ($build -ge 26100) {
  $sse42 = 'Present'            # running 24H2+ => supported by definition
} elseif ($PSVersionTable.PSVersion.Major -ge 7) {
  try { if ([System.Runtime.Intrinsics.X86.Sse42]::IsSupported) { $sse42 = 'Present' } else { $sse42 = 'Missing' } } catch { }
}
if ($sse42 -eq 'Unknown') {
  $ancient = 'Core 2|Core2|Pentium 4|Pentium D |Pentium Dual|Pentium E2|Pentium E5|Pentium E6|Atom N2|Atom N4|Atom N5|Atom D4|Atom D5|Phenom|Athlon 64|Athlon II|Athlon X2|Turion|Sempron'
  if ($cpu.Name -match $ancient) { $sse42 = 'LikelyMissing' } else { $sse42 = 'LikelyPresent' }
}
$sse42ok       = ($sse42 -eq 'Present' -or $sse42 -eq 'LikelyPresent')
$sse42hardfail = ($sse42 -eq 'Missing')
switch ($sse42) {
  'Present'       { $sse42txt = 'PRESENT' }
  'LikelyPresent' { $sse42txt = 'present (estimate)' }
  'LikelyMissing' { $sse42txt = 'LIKELY MISSING - verify (estimate)' }
  'Missing'       { $sse42txt = 'MISSING - will NOT run 24H2+' }
}

# ---- Embedded Windows license + TURN-KEY read (firmware EDITION decides) ----
# RR Turbo v8 ships Home, so a Home firmware license = auto-activation (turn-key).
# "Core" is Microsoft's internal name for the Home family (incl. Single Language).
$sls     = Get-CimInstance -ClassName SoftwareLicensingService
$oemKey  = $sls.OA3xOriginalProductKey
$oemDesc = "$($sls.OA3xOriginalProductKeyDescription)"
if ([string]::IsNullOrWhiteSpace($oemKey)) {
  $lic = 'none found in firmware';                 $turnkey = 'MAYBE'
} elseif ($oemDesc -match 'Core') {
  $lic = 'Windows Home - built into firmware';     $turnkey = 'YES'
} elseif ($oemDesc -match 'Professional') {
  $lic = 'Windows Pro - built into firmware';      $turnkey = 'PRO'
} else {
  $lic = "embedded license ($oemDesc)";            $turnkey = 'MAYBE'
}

# ---- GPU + VRAM (best-effort; AdapterRAM overflows above 4 GB) ----
$gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name } | Select-Object -First 1
$vramGB = 0
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -EA SilentlyContinue | ForEach-Object {
  $v = (Get-ItemProperty $_.PSPath -Name 'HardwareInformation.qwMemorySize' -EA SilentlyContinue).'HardwareInformation.qwMemorySize'
  if ($v -and $v -gt $vramGB) { $vramGB = $v }
}
$vramGB = GB $vramGB
if ($vramGB -le 0 -and $gpu.AdapterRAM) { $vramGB = GB $gpu.AdapterRAM }

# ============================================================
Write-Host ""
Write-Host "==========================================================="
Write-Host "   Will It Revolt?  -  RR Turbo compatibility check"
Write-Host "   (read-only - nothing on your PC is changed)"
Write-Host "==========================================================="
Write-Host ""
Write-Host "YOUR MACHINE"
"{0,-16}{1}" -f "Processor:", "$($cpu.Name.Trim())"                                   | Write-Host
"{0,-16}{1} cores / {2} threads @ {3} GHz base   {4}" -f "", $cores, $threads, $clock, (Mark ($threads -ge $minThreads)) | Write-Host
"{0,-16}{1} GB installed ({2} GB usable)   {3}" -f "Memory:", $ramGB, $usableGB, (Mark ($ramGB -ge $minRAMgb)) | Write-Host
"{0,-16}{1} GB total, {2} GB free   {3}" -f "System drive:", $diskTotGB, $diskFreeGB, (Mark ($diskTotGB -ge $minDiskGB)) | Write-Host
"{0,-16}{1}   {2}" -f "64-bit OS:", $(if($is64){'Yes'}else{'No'}), (Mark $is64)       | Write-Host
"{0,-16}{1}" -f "Graphics:", "$($gpu.Name)  (~$vramGB GB VRAM)"                        | Write-Host
"{0,-16}{1}" -f "Win license:", $lic                                                  | Write-Host
Write-Host ""
Write-Host "WINDOWS 11 WALLS"
"{0,-26}{1}" -f "CPU 24H2 floor (SSE4.2):", $sse42txt                                 | Write-Host
"{0,-26}{1}" -f "TPM:", $tpmVer                                                       | Write-Host
"{0,-26}{1}" -f "Firmware:", $fw                                                      | Write-Host
"{0,-26}{1}" -f "Secure Boot:", $(if($sbOn){'On'}elseif($uefi){'Off (UEFI-capable)'}else{'Not available (Legacy)'}) | Write-Host
Write-Host ""

# ---- Windows 11 native-install read (informational) ----
$passesNative = $tpm2 -and $uefi -and $sse42ok -and ($ramGB -ge 4)
Write-Host "-----------------------------------------------------------"
if ($sse42hardfail) {
  Write-Host "  Microsoft's gate:  N/A - CPU can't run 24H2 at all." -ForegroundColor Red
} elseif ($passesNative) {
  Write-Host "  Microsoft's gate:  likely PASSES natively (pending their CPU model list)." -ForegroundColor Green
} else {
  Write-Host "  Microsoft's gate:  would be BLOCKED - needs the RR bypass (Rufus)." -ForegroundColor Yellow
  Write-Host "  That's normal and expected for the machines RR Turbo exists to save."
}
Write-Host "-----------------------------------------------------------"
Write-Host ""

# ---- RR Turbo verdict: three tiers ----
#   RED   = below the floor, or a wall it can't pass
#   AMBER = meets the floor but sits at it (4 GB) - entry/focused use
#   GREEN = 8 GB+ and clears the floor - comfortable multitasking
$floorPass = ($threads -ge $minThreads) -and ($ramGB -ge $minRAMgb) -and ($diskTotGB -ge $minDiskGB) -and $is64 -and (-not $sse42hardfail)
if     (-not $floorPass) { $tier = 'RED' }
elseif ($ramGB -lt 8)    { $tier = 'AMBER' }
else                     { $tier = 'GREEN' }

# ---- AI capability (hardware decides; RR AI itself is free) ----
if     ($vramGB -ge 8) { $aiTier = 'Full local AI - the largest models' }
elseif ($vramGB -ge 4) { $aiTier = 'Standard local AI' }
elseif ($vramGB -ge 2) { $aiTier = 'Light local AI - smaller models' }
else                   { $aiTier = 'AI optional - small / CPU models, or skip AI' }

Write-Host "==========================================================="
switch ($tier) {
  'GREEN' {
    Write-Host "  RESULT: Revolts well." -ForegroundColor Green
    Write-Host "  Clean, fast Windows 11 with room to multitask."
  }
  'AMBER' {
    Write-Host "  RESULT: Revolts - entry tier." -ForegroundColor Yellow
    Write-Host "  Yes, RR Turbo runs. Great for one task at a time - web,"
    Write-Host "  email, documents, a chatbot. Tight if you stack many apps"
    Write-Host "  or browser tabs at once."
    if ($sse42 -eq 'LikelyMissing') {
      Write-Host "  CAUTION: this looks like a pre-2011 CPU that may lack SSE4.2 -" -ForegroundColor Yellow
      Write-Host "  confirm before relying on 24H2; that wall can't be bypassed." -ForegroundColor Yellow
    }
  }
  'RED' {
    Write-Host "  RESULT: Won't Revolt." -ForegroundColor Red
    $short = @()
    if ($sse42hardfail)            { $short += "a CPU with SSE4.2 (hard stop - Windows 11 24H2 won't run)" }
    if ($threads -lt $minThreads)  { $short += "$minThreads CPU threads" }
    if ($ramGB -lt $minRAMgb)      { $short += "$minRAMgb GB RAM" }
    if ($diskTotGB -lt $minDiskGB) { $short += "$minDiskGB GB storage" }
    if (-not $is64)                { $short += "a 64-bit CPU" }
    Write-Host ("  Short on: " + ($short -join "; ") + ".")
  }
}
Write-Host "==========================================================="

if ($tier -ne 'RED') {
  Write-Host ""
  switch ($turnkey) {
    'YES' {
      Write-Host "  TURN-KEY: YES." -ForegroundColor Green
      Write-Host "  A Windows Home license is built into this machine's firmware,"
      Write-Host "  so the Recovery Kit activates on its own - no key to enter,"
      Write-Host "  nothing to buy. It just works."
    }
    'PRO' {
      Write-Host "  TURN-KEY: almost." -ForegroundColor Yellow
      Write-Host "  This firmware carries a Windows PRO license. The kit installs"
      Write-Host "  and runs, but won't self-activate on a Pro license - you'd use"
      Write-Host "  your existing Pro key, or ask us about a Pro build."
    }
    'MAYBE' {
      Write-Host "  TURN-KEY: likely, possibly with a key." -ForegroundColor Yellow
      Write-Host "  No license was found baked into the firmware (common on older or"
      Write-Host "  already-upgraded machines). It installs and runs; Windows may"
      Write-Host "  activate from your existing digital license, or ask you for a key."
    }
  }
  Write-Host ""
  Write-Host "  -> The RR Turbo Recovery Kit will perfect this machine."
  Write-Host "     It installs Windows 11 even where Microsoft says no, by"
  Write-Host "     bypassing the TPM / Secure Boot / CPU-list gates at build time."
  Write-Host ("     On-device AI this hardware supports: " + $aiTier + ".")
  Write-Host "     RR AI is a free download - it sizes itself to your hardware."
}
Write-Host ""

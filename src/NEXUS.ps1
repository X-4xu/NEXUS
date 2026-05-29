<#
NEXUS v2.0 - Network Engine Xtreme Unified System
Safe Beast Windows Optimization Tool

NEVER does:
- No personal file deletion (Desktop, Documents, Downloads, Pictures, Videos, Music, game saves)
- No overclocking
- No driver deletion
- No disabling Windows Security or Firewall
- No forced process killing
- No risky registry edits
- No external downloads or dependencies
- No real usernames in log output (masked as %USERNAME%)
#>

[CmdletBinding()]
param(
    [ValidateSet('Scan','Optimize','Network','RAM','Startup')]
    [string]$Mode = 'Scan',

    [switch]$Interactive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$NexusVersion = '2.0'
$Root    = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$LogDir  = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp   = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$ReportPath = Join-Path $LogDir "NEXUS_${Mode}_$Stamp.txt"

$script:ReportLines    = New-Object System.Collections.Generic.List[string]
$script:ActionItems    = New-Object System.Collections.Generic.List[string]
$script:SectionTimings = New-Object System.Collections.Generic.List[string]

# ============================================================
# OUTPUT HELPERS
# ============================================================

function Mask-UserPath {
    param([string]$Text)
    try {
        $t = $Text
        if ($env:USERNAME)    { $t = $t -replace [regex]::Escape($env:USERNAME), '%USERNAME%' }
        if ($env:USERPROFILE) { $t = $t -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%' }
        return $t
    } catch { return $Text }
}

function Write-Line {
    param(
        [string]$Text = '',
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )
    try {
        $masked = Mask-UserPath $Text
        Write-Host $masked -ForegroundColor $Color
        [void]$script:ReportLines.Add($masked)
    } catch {
        Write-Host $Text
    }
}

function Write-Title {
    param([string]$Text)
    try {
        $ts = Get-Date -Format 'HH:mm:ss'
        [void]$script:SectionTimings.Add("$ts  $Text")
        Write-Line ''
        Write-Line ('=' * 74) Cyan
        Write-Line "  $Text" Cyan
        Write-Line ('=' * 74) Cyan
    } catch {
        Write-Line $Text Cyan
    }
}

function Write-SubTitle {
    param([string]$Text)
    try {
        Write-Line ''
        Write-Line ("-- $Text " + ('-' * [Math]::Max(1, 66 - $Text.Length))) DarkCyan
    } catch {
        Write-Line $Text DarkCyan
    }
}

function Write-Step  { param([string]$Text); try { Write-Line "[+] $Text" Green } catch {} }
function Write-Good  { param([string]$Text); try { Write-Line "[OK] $Text" Green } catch {} }
function Write-Warn  { param([string]$Text); try { Write-Line "[!] $Text" Yellow } catch {} }
function Write-Crit  { param([string]$Text); try { Write-Line "[!!] $Text" Red } catch {} }

function Add-Action {
    param([string]$Priority, [string]$Text)
    try {
        $item = "[$Priority] $Text"
        if (-not ($script:ActionItems -contains $item)) {
            [void]$script:ActionItems.Add($item)
        }
    } catch {}
}

# ============================================================
# BANNER
# ============================================================

function Show-Banner {
    try {
        Clear-Host
        $art = @(
            '    +-+-+-+-+-+',
            '    |N|E|X|U|S|',
            '    +-+-+-+-+-+',
            '',
            '    ##    ## ######## ##     ## ##     ##  ######',
            '    ###   ## ##        ##   ##  ##     ## ##    ##',
            '    ####  ## ##         ## ##   ##     ## ##',
            '    ## ## ## ######      ###    ##     ##  ######',
            '    ##  #### ##         ## ##   ##     ##       ##',
            '    ##   ### ##        ##   ##  ##     ## ##    ##',
            '    ##    ## ######## ##     ##  #######   ######'
        )
        foreach ($l in $art) { Write-Line $l Cyan }
        Write-Line ''
        Write-Line "    NETWORK  *  ENGINE  *  XTREME  *  UNIFIED  *  SYSTEM" Cyan
        Write-Line "    v$NexusVersion  |  Safe Beast Mode  |  No personal files touched" DarkGray
        Write-Line ''
    } catch {
        Write-Line "NEXUS v$NexusVersion" Cyan
    }
}

# ============================================================
# ADMIN CHECK
# ============================================================

function Test-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p  = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

# ============================================================
# SAFE COMMAND RUNNER
# ============================================================

function Invoke-SafeCommand {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Command,
        [switch]$AdminOnly,
        [switch]$Silent
    )
    if ($AdminOnly -and -not (Test-IsAdmin)) {
        Write-Warn "$Name skipped --- run as Administrator to enable this."
        return
    }
    if (-not $Silent) { Write-Step $Name }
    try {
        $out = & $Command 2>&1
        if ($null -ne $out) {
            $out | ForEach-Object {
                $t = Mask-UserPath $_.ToString()
                if ($t.Trim().Length -gt 0 -and -not $Silent) { Write-Line "    $t" }
            }
        }
    } catch {
        Write-Warn "$Name failed: $($_.Exception.Message)"
    }
}

# ============================================================
# FORMATTERS
# ============================================================

function Format-Bytes {
    param([double]$Bytes)
    try {
        if ($Bytes -ge 1TB) { return '{0:N2} TB' -f ($Bytes/1TB) }
        if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes/1GB) }
        if ($Bytes -ge 1MB) { return '{0:N2} MB' -f ($Bytes/1MB) }
        if ($Bytes -ge 1KB) { return '{0:N2} KB' -f ($Bytes/1KB) }
        return '{0:N0} B'   -f $Bytes
    } catch { return '0 B' }
}

function Format-Pct { param([object]$v); try { if ($null -eq $v) { return 'n/a' }; return '{0:N1}%' -f [double]$v } catch { return 'n/a' } }

function Write-Bar {
    param(
        [Parameter(Mandatory)][string]$Label,
        [object]$Value,
        [double]$Max = 100,
        [switch]$LowerIsBetter,
        [string]$Suffix = '%',
        [string]$Grade = ''
    )
    try {
        if ($null -eq $Value) {
            Write-Line ('{0,-20} [????????????????????] n/a' -f $Label) DarkGray
            return
        }
        $raw    = [double]$Value
        $pct    = [Math]::Max(0,[Math]::Min(100,($raw/$Max)*100))
        $filled = [int][Math]::Min(20,[Math]::Round($pct/5))
        $bar    = ("$([char]0x2588)" * $filled) + ("$([char]0x2591)" * (20-$filled))
        $vText  = if ($Suffix -eq '') { '{0:N1}' -f $raw } else { '{0:N1}{1}' -f $raw,$Suffix }
        $color  = [ConsoleColor]::Green
        if ($LowerIsBetter) {
            if ($pct -ge 85) { $color = [ConsoleColor]::Red }
            elseif ($pct -ge 65) { $color = [ConsoleColor]::Yellow }
        } else {
            if ($pct -lt 30) { $color = [ConsoleColor]::Red }
            elseif ($pct -lt 50) { $color = [ConsoleColor]::Yellow }
        }
        $suffix2 = if ($Grade) { "  $Grade" } else { '' }
        Write-Line ('{0,-20} [{1}] {2}{3}' -f $Label,$bar,$vText,$suffix2) $color
    } catch { Write-Warn "Bar render failed for $Label" }
}

# ============================================================
# SYSTEM METRICS
# ============================================================

function Get-CpuPct {
    try { return [double](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -EA Stop).PercentProcessorTime }
    catch { return $null }
}

function Get-MemStats {
    try {
        $os    = Get-CimInstance Win32_OperatingSystem -EA Stop
        $total = [double]$os.TotalVisibleMemorySize * 1KB
        $free  = [double]$os.FreePhysicalMemory * 1KB
        $used  = $total - $free
        return [pscustomobject]@{
            TotalBytes = $total
            FreeBytes  = $free
            UsedBytes  = $used
            UsedPct    = if ($total -gt 0) { [Math]::Round(($used/$total)*100,1) } else { 0 }
        }
    } catch {
        return [pscustomobject]@{ TotalBytes=0; FreeBytes=0; UsedBytes=0; UsedPct=$null }
    }
}

function Get-StandbyBytes {
    try {
        $m = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory -EA Stop
        $total = 0.0
        foreach ($p in @('StandbyCacheReserveBytes','StandbyCacheNormalPriorityBytes','StandbyCacheCoreBytes')) {
            if ($m.PSObject.Properties[$p]) { $total += [double]$m.$p }
        }
        return $total
    } catch { return 0 }
}

function Get-MinDiskFreePct {
    try {
        $vals = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -EA Stop |
            Where-Object { $_.Size -gt 0 } |
            ForEach-Object { [Math]::Round(($_.FreeSpace/$_.Size)*100,1) })
        if ($vals.Count -eq 0) { return $null }
        return [double](($vals | Measure-Object -Minimum).Minimum)
    } catch { return $null }
}

function Test-PingTarget {
    param([string]$Target, [int]$Count = 4)
    try {
        $r     = Test-Connection -ComputerName $Target -Count $Count -EA Stop
        $times = @($r | ForEach-Object {
            if ($_.PSObject.Properties['ResponseTime']) { [double]$_.ResponseTime }
            elseif ($_.PSObject.Properties['Latency'])  { [double]$_.Latency }
        })
        if ($times.Count -eq 0) { throw 'No latency returned' }
        return [pscustomobject]@{
            Target = $Target; Ok = $true
            Min    = [Math]::Round(($times | Measure-Object -Minimum).Minimum,1)
            Avg    = [Math]::Round(($times | Measure-Object -Average).Average,1)
            Max    = [Math]::Round(($times | Measure-Object -Maximum).Maximum,1)
            Loss   = [Math]::Round((($Count - $times.Count)/$Count)*100,0)
            Error  = ''
        }
    } catch {
        return [pscustomobject]@{ Target=$Target; Ok=$false; Min=$null; Avg=$null; Max=$null; Loss=100; Error=$_.Exception.Message }
    }
}

# ============================================================
# CACHE MAP
# ============================================================

function Get-CacheMap {
    try {
        $m = [ordered]@{}
        $m['User Temp']                   = $env:TEMP
        $m['Windows Temp']                = "$env:WINDIR\Temp"
        $m['Windows Update Cache']        = "$env:WINDIR\SoftwareDistribution\Download"
        $m['Delivery Optimization Cache'] = "$env:ProgramData\Microsoft\Windows\DeliveryOptimization\Cache"
        $m['Recent Items Cache']          = "$env:APPDATA\Microsoft\Windows\Recent"
        $m['Explorer Thumbnail Cache']    = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        $m['DirectX Shader Cache']        = "$env:LOCALAPPDATA\D3DSCache"
        $m['NVIDIA DX Cache']             = "$env:LOCALAPPDATA\NVIDIA\DXCache"
        $m['NVIDIA GL Cache']             = "$env:LOCALAPPDATA\NVIDIA\GLCache"
        $m['AMD DX Cache']                = "$env:LOCALAPPDATA\AMD\DxCache"
        $m['AMD GL Cache']                = "$env:LOCALAPPDATA\AMD\GLCache"
        $m['WER Archive']                 = "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive"
        $m['WER Queue']                   = "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue"
        $m['Edge Cache']                  = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
        $m['Edge Code Cache']             = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
        $m['Edge GPU Cache']              = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache"
        $m['Chrome Cache']                = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
        $m['Chrome Code Cache']           = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"
        $m['Chrome GPU Cache']            = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache"
        $m['Brave Cache']                 = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache"
        $m['Brave Code Cache']            = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Code Cache"
        $m['Brave GPU Cache']             = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\GPUCache"
        $m['Firefox Cache']               = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
        $m['Discord Cache']               = "$env:APPDATA\discord\Cache"
        $m['Discord Code Cache']          = "$env:APPDATA\discord\Code Cache"
        $m['Discord GPU Cache']           = "$env:APPDATA\discord\GPUCache"
        $m['Telegram Cache']              = "$env:APPDATA\Telegram Desktop\tdata\user_data\cache"
        $m['VS Code Cache']               = "$env:APPDATA\Code\Cache"
        $m['VS Code GPU Cache']           = "$env:APPDATA\Code\GPUCache"
        return $m
    } catch { return [ordered]@{} }
}

function Test-ReparsePoint { param([System.IO.FileSystemInfo]$Item); try { return (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) } catch { return $false } }

function Get-FolderSize {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    try {
        $s = (Get-ChildItem -LiteralPath $Path -Force -Recurse -EA SilentlyContinue |
            Where-Object { -not $_.PSIsContainer -and -not (Test-ReparsePoint $_) } |
            Measure-Object -Property Length -Sum).Sum
        if ($null -eq $s) { return 0 }
        return [double]$s
    } catch { return 0 }
}

function Remove-Children {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $n = 0
    Get-ChildItem -LiteralPath $Path -Force -EA SilentlyContinue | ForEach-Object {
        try {
            if (Test-ReparsePoint $_) { return }
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -EA Stop
            $n++
        } catch {}
    }
    return $n
}

function Get-TotalCacheSize {
    try {
        $t = 0
        foreach ($e in (Get-CacheMap).GetEnumerator()) { $t += Get-FolderSize $e.Value }
        return $t
    } catch { return 0 }
}

# ============================================================
# STARTUP ITEMS
# ============================================================

function Get-StartupItems {
    $list  = New-Object System.Collections.Generic.List[object]
    $keys  = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    )
    foreach ($k in $keys) {
        if (Test-Path $k) {
            try {
                (Get-ItemProperty -Path $k -EA Stop).PSObject.Properties |
                    Where-Object { $_.Name -notmatch '^PS' } |
                    ForEach-Object {
                        [void]$list.Add([pscustomobject]@{ Location=$k; Name=$_.Name; Command=$_.Value })
                    }
            } catch {}
        }
    }
    return $list
}

# ============================================================
# HEALTH SCORE (Weighted)
# ============================================================

function Get-HealthScore {
    param($CpuPct,$MemPct,$DiskFreePct,$CacheGB,$StartupCount,$PingAvg,$PageFilePeakPct,$BatteryPct,$TempC)

    try {
    $score = 100.0

    # CPU  15%
    if ($null -ne $CpuPct) {
        if ($CpuPct -ge 90) { $score -= 15 }
        elseif ($CpuPct -ge 70) { $score -= 8 }
        elseif ($CpuPct -ge 50) { $score -= 3 }
    }
    # RAM  20%
    if ($null -ne $MemPct) {
        if ($MemPct -ge 92) { $score -= 20 }
        elseif ($MemPct -ge 80) { $score -= 12 }
        elseif ($MemPct -ge 70) { $score -= 6 }
    }
    # Disk 15%
    if ($null -ne $DiskFreePct) {
        if ($DiskFreePct -lt 10) { $score -= 15 }
        elseif ($DiskFreePct -lt 15) { $score -= 10 }
        elseif ($DiskFreePct -lt 25) { $score -= 5 }
    }
    # Cache 10%
    if ($CacheGB -gt 15) { $score -= 10 }
    elseif ($CacheGB -gt 5) { $score -= 6 }
    elseif ($CacheGB -gt 2) { $score -= 3 }

    # Startup 10%
    if ($StartupCount -gt 20) { $score -= 10 }
    elseif ($StartupCount -gt 12) { $score -= 6 }
    elseif ($StartupCount -gt 8)  { $score -= 3 }

    # Ping 15%
    if ($null -ne $PingAvg) {
        if (-not $PingAvg) { $score -= 15 }
        elseif ($PingAvg -ge 200) { $score -= 15 }
        elseif ($PingAvg -ge 100) { $score -= 8 }
        elseif ($PingAvg -ge 60)  { $score -= 3 }
    }
    # Page file 5%
    if ($null -ne $PageFilePeakPct) {
        if ($PageFilePeakPct -ge 90) { $score -= 5 }
        elseif ($PageFilePeakPct -ge 75) { $score -= 3 }
    }
    # Battery 5%
    if ($null -ne $BatteryPct) {
        if ($BatteryPct -lt 40) { $score -= 5 }
        elseif ($BatteryPct -lt 60) { $score -= 3 }
    }
    # Temperature 5%
    if ($null -ne $TempC) {
        if ($TempC -ge 95) { $score -= 5 }
        elseif ($TempC -ge 85) { $score -= 3 }
        elseif ($TempC -ge 75) { $score -= 1 }
    }

    $score = [Math]::Max(0,[Math]::Min(100,$score))
    $grade = switch ([int]$score) {
        { $_ -ge 90 } { 'A  EXCELLENT'; break }
        { $_ -ge 75 } { 'B  GOOD'; break }
        { $_ -ge 60 } { 'C  FAIR'; break }
        { $_ -ge 40 } { 'D  POOR'; break }
        default        { 'F  CRITICAL' }
    }
    return [pscustomobject]@{ Score=[int]$score; Grade=$grade }
    } catch {
        return [pscustomobject]@{ Score=0; Grade='F  CRITICAL' }
    }
}

# ============================================================
# SYSTEM PULSE DASHBOARD
# ============================================================

function Show-SystemPulse {
    Write-Title 'NEXUS SYSTEM PULSE'

    $cpu      = Get-CpuPct
    $mem      = Get-MemStats
    $disk     = Get-MinDiskFreePct
    $cache    = Get-TotalCacheSize
    $cacheGB  = [Math]::Round($cache/1GB,2)
    $ping     = Test-PingTarget '1.1.1.1' 2
    $startup  = @(Get-StartupItems)

    # Page file
    $pfPeakPct = $null
    try {
        $pf = @(Get-CimInstance Win32_PageFileUsage -EA Stop)
        if ($pf.Count -gt 0 -and $pf[0].AllocatedBaseSize -gt 0) {
            $pfPeakPct = [Math]::Round(($pf[0].PeakUsage / $pf[0].AllocatedBaseSize)*100,1)
        }
    } catch {}

    # Battery
    $batPct = $null
    try {
        $bat = Get-CimInstance Win32_Battery -EA Stop | Select-Object -First 1
        if ($bat -and $bat.DesignCapacity -gt 0) {
            $batPct = [Math]::Round(($bat.FullChargeCapacity/$bat.DesignCapacity)*100,1)
        }
    } catch {}

    # Temperature
    $tempC = $null
    try {
        $tz = @(Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -EA Stop)
        if ($tz.Count -gt 0) {
            $temps = $tz | ForEach-Object { ($_.CurrentTemperature/10) - 273.15 }
            $tempC = [Math]::Round(($temps | Measure-Object -Maximum).Maximum,1)
        }
    } catch {}

    $pingAvgForScore = $null
    if ($ping.Ok) { $pingAvgForScore = $ping.Avg }

    $health = Get-HealthScore -CpuPct $cpu -MemPct $mem.UsedPct -DiskFreePct $disk `
        -CacheGB $cacheGB -StartupCount $startup.Count `
        -PingAvg $pingAvgForScore `
        -PageFilePeakPct $pfPeakPct -BatteryPct $batPct -TempC $tempC

    Write-Bar 'Health Score'   $health.Score  100 -Suffix '%' -Grade $health.Grade
    Write-Bar 'CPU Load'       $cpu           100 -LowerIsBetter -Suffix '%'
    Write-Bar 'RAM Used'       $mem.UsedPct   100 -LowerIsBetter -Suffix '%'
    Write-Bar 'Disk Free Min'  $disk          100 -Suffix '%'
    Write-Bar 'Cache Size'     $cacheGB        20 -LowerIsBetter -Suffix ' GB'
    if ($ping.Ok) {
        Write-Bar 'Ping 1.1.1.1'  $ping.Avg   200 -LowerIsBetter -Suffix ' ms'
    } else {
        Write-Line 'Ping 1.1.1.1         [????????????????????] FAILED' Yellow
    }
    if ($null -ne $tempC) {
        Write-Bar 'CPU Temp'       $tempC      110 -LowerIsBetter -Suffix ' C'
    }
    if ($null -ne $batPct) {
        Write-Bar 'Battery Health' $batPct     100 -Suffix '%'
    }

    Write-Line ''
    Write-Line "Startup entries  : $($startup.Count)"
    Write-Line "Cache removable  : $(Format-Bytes $cache)" Green
    Write-Line "RAM available    : $(Format-Bytes $mem.FreeBytes)" Green

    # Action hints
    if ($cacheGB -gt 3) { Add-Action 'HIGH'   "Cache is $(Format-Bytes $cache) --- run POWER BOOST [2]" }
    if ($startup.Count -gt 8)  { Add-Action 'MEDIUM' "Startup apps: $($startup.Count) --- use Startup Manager [5]" }
    if ($null -ne $mem.UsedPct -and $mem.UsedPct -ge 75) { Add-Action 'HIGH' "RAM at $(Format-Pct $mem.UsedPct) --- run RAM BOOST [4]" }
    if ($null -ne $disk -and $disk -lt 20) { Add-Action 'HIGH' "Disk free only $(Format-Pct $disk) --- free up space" }
    if ($ping.Ok -and $ping.Avg -ge 80) { Add-Action 'MEDIUM' "Ping $($ping.Avg)ms --- run NET BOOST [3]" }
    if ($null -ne $tempC -and $tempC -ge 80) { Add-Action 'MEDIUM' "CPU temp $($tempC)C --- check cooling / clean dust" }

    return [pscustomobject]@{
        CpuPct=$cpu; Memory=$mem; DiskFree=$disk; CacheBytes=$cache; CacheGB=$cacheGB
        PingAvg=$pingAvgForScore; PingOk=$ping.Ok
        StartupCount=$startup.Count; Health=$health; TempC=$tempC; BatPct=$batPct
    }
}

# ============================================================
# BOTTLENECK RADAR
# ============================================================

function Show-BottleneckRadar {
    param([Parameter(Mandatory)]$M)
    try {
        Write-Title 'BOTTLENECK RADAR'
        $found = $false

    if ($null -ne $M.CpuPct -and $M.CpuPct -ge 70) {
        $found = $true; Write-Crit "CPU load HIGH: $(Format-Pct $M.CpuPct) --- close heavy apps"
    }
    if ($null -ne $M.Memory.UsedPct -and $M.Memory.UsedPct -ge 75) {
        $found = $true; Add-Action 'HIGH' "RAM $(Format-Pct $M.Memory.UsedPct) --- run RAM BOOST"
        Write-Warn "RAM pressure HIGH: $(Format-Pct $M.Memory.UsedPct) --- run RAM BOOST [4]"
    }
    if ($null -ne $M.DiskFree -and $M.DiskFree -lt 20) {
        $found = $true; Write-Warn "Low disk space: $(Format-Pct $M.DiskFree) free"
    }
    if ($M.CacheGB -gt 3) {
        $found = $true; Write-Warn "Cache large: $(Format-Bytes $M.CacheBytes) --- run POWER BOOST [2]"
    }
    if ($M.StartupCount -gt 8) {
        $found = $true; Write-Warn "Startup apps: $($M.StartupCount) --- use Startup Manager [5]"
    }
    if ($null -ne $M.TempC -and $M.TempC -ge 80) {
        $found = $true; Write-Warn "CPU temp: $($M.TempC)C --- clean dust, check airflow"
    }
    if ($M.PingOk -and $null -ne $M.PingAvg -and $M.PingAvg -ge 80) {
        $found = $true; Write-Warn "Ping HIGH: $($M.PingAvg)ms --- run NET BOOST [3]"
    } elseif (-not $M.PingOk) {
        $found = $true; Write-Crit 'Ping FAILED --- check internet connection'
    }
        if (-not $found) { Write-Good 'No critical bottleneck detected.' }
    } catch { Write-Warn "Bottleneck radar failed: $($_.Exception.Message)" }
}

# ============================================================
# SYSTEM HEALTH SECTION
# ============================================================

function Show-SystemHealth {
    Write-Title 'SYSTEM INFORMATION'
    try {
        $os  = Get-CimInstance Win32_OperatingSystem -EA Stop
        $cpu = Get-CimInstance Win32_Processor -EA Stop | Select-Object -First 1
        $cs  = Get-CimInstance Win32_ComputerSystem -EA Stop
        $gpu = @(Get-CimInstance Win32_VideoController -EA SilentlyContinue)
        $mem = Get-MemStats

        Write-Line "Windows  : $($os.Caption) build $($os.BuildNumber)"
        Write-Line "Uptime   : $((Get-Date) - $os.LastBootUpTime)"
        Write-Line "RAM      : $(Format-Bytes $mem.UsedBytes) / $(Format-Bytes $mem.TotalBytes) used ($(Format-Pct $mem.UsedPct))"
        Write-Line "CPU      : $($cpu.Name.Trim())"
        Write-Line "CPU Load : $(Format-Pct (Get-CpuPct)) now"
        Write-Line "Device   : $($cs.Manufacturer) $($cs.Model)"

        if ($gpu.Count -gt 0) {
            Write-Line 'GPUs:' Yellow
            $gpu | ForEach-Object {
                Write-Line "  $($_.Name)  Driver: $($_.DriverVersion)  $($_.VideoModeDescription)"
            }
        }
    } catch { Write-Warn "System info error: $($_.Exception.Message)" }

    # Page file
    Write-SubTitle 'Virtual Memory (Page File)'
    try {
        $pf = @(Get-CimInstance Win32_PageFileUsage -EA Stop)
        if ($pf.Count -gt 0) {
            foreach ($p in $pf) {
                $path     = Mask-UserPath $p.Name
                $allocMB  = $p.AllocatedBaseSize
                $usedMB   = $p.CurrentUsage
                $peakMB   = $p.PeakUsage
                $peakPct  = if ($allocMB -gt 0) { [Math]::Round(($peakMB/$allocMB)*100,1) } else { 0 }
                Write-Line "  File     : $path"
                Write-Line "  Allocated: $(Format-Bytes ($allocMB*1MB))"
                Write-Line "  Current  : $(Format-Bytes ($usedMB*1MB))"
                Write-Line "  Peak     : $(Format-Bytes ($peakMB*1MB))  ($($peakPct)% of allocated)"
                if ($peakPct -ge 80) {
                    Write-Warn 'Page file peak is high. Consider increasing virtual memory.'
                    Add-Action 'LOW' 'Increase virtual memory: Control Panel > System > Advanced > Performance > Virtual Memory'
                }
            }
        } else { Write-Line '  No page file found (may be on SSD, managed by Windows).' }
    } catch { Write-Warn "Page file info error: $($_.Exception.Message)" }

    # Battery
    Write-SubTitle 'Battery Health'
    try {
        $bat = Get-CimInstance Win32_Battery -EA Stop | Select-Object -First 1
        if ($bat) {
            $health = if ($bat.DesignCapacity -gt 0) { [Math]::Round(($bat.FullChargeCapacity/$bat.DesignCapacity)*100,1) } else { $null }
            Write-Line "  Status       : $($bat.BatteryStatus)"
            Write-Line "  Charge       : $($bat.EstimatedChargeRemaining)%"
            if ($null -ne $health) {
                Write-Line "  Health       : $($health)% of original design capacity"
                if ($health -lt 60) {
                    Write-Crit "Battery health critically low ($($health)%). System may throttle performance."
                    Add-Action 'MEDIUM' "Battery health $($health)% - consider replacement"
                } elseif ($health -lt 80) {
                    Write-Warn "Battery health degraded ($($health)%)."
                }
            }
        } else { Write-Line '  No battery detected (desktop PC).' }
    } catch { Write-Line '  Battery info unavailable.' DarkGray }

    # Temperature
    Write-SubTitle 'Thermal Status'
    try {
        $tz = @(Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -EA Stop)
        if ($tz.Count -gt 0) {
            $i = 0
            foreach ($z in $tz) {
                $c = [Math]::Round(($z.CurrentTemperature/10) - 273.15, 1)
                $st = if ($c -ge 95) { 'CRITICAL' } elseif ($c -ge 85) { 'HOT' } elseif ($c -ge 70) { 'WARM' } else { 'OK' }
                $col = if ($c -ge 85) { 'Red' } elseif ($c -ge 70) { 'Yellow' } else { 'Green' }
                Write-Line "  Zone $i : $c C  [$st]" $col
                $i++
            }
        } else { Write-Line '  Thermal sensor not readable via WMI on this system.' DarkGray }
    } catch { Write-Line '  Thermal data unavailable (normal on some systems).' DarkGray }
}

# ============================================================
# TOP PROCESSES
# ============================================================

function Show-TopProcesses {
    Write-Title 'TOP RESOURCE PROCESSES'
    $procs = @(Get-Process -EA SilentlyContinue | ForEach-Object {
        [pscustomobject]@{
            Name = $_.ProcessName
            Id   = $_.Id
            CPU  = $(try { [Math]::Round($_.TotalProcessorTime.TotalSeconds,2) } catch { 0.0 })
            RAM  = $(try { [double]$_.WorkingSet64 } catch { 0.0 })
            RAMF = $(try { Format-Bytes $_.WorkingSet64 } catch { '0 B' })
        }
    })

    Write-Line 'Top CPU processes:' Yellow
    $procs | Sort-Object CPU -Desc | Select-Object -First 12 |
        Select-Object Name,Id,CPU,RAMF |
        Format-Table -AutoSize | Out-String | ForEach-Object { Write-Line $_ }

    Write-Line 'Top RAM processes:' Yellow
    $procs | Sort-Object RAM -Desc | Select-Object -First 12 |
        Select-Object Name,Id,RAMF,CPU |
        Format-Table -AutoSize | Out-String | ForEach-Object { Write-Line $_ }
}

# ============================================================
# DISK HEALTH
# ============================================================

function Show-DiskHealth {
    Write-Title 'DISK HEALTH'
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -EA SilentlyContinue | ForEach-Object {
        $fp = if ($_.Size -gt 0) { [Math]::Round(($_.FreeSpace/$_.Size)*100,1) } else { 0 }
        $col = if ($fp -lt 10) { 'Red' } elseif ($fp -lt 20) { 'Yellow' } else { 'Green' }
        Write-Line "$($_.DeviceID)  Free: $(Format-Bytes $_.FreeSpace) / $(Format-Bytes $_.Size) ($($fp)%)" $col
        if ($fp -lt 15) { Add-Action 'HIGH' "$($_.DeviceID) disk only $($fp)% free - clean up files" }
    }
    try {
        Get-PhysicalDisk -EA Stop |
            Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,@{N='Size';E={Format-Bytes $_.Size}} |
            Format-Table -AutoSize | Out-String | ForEach-Object { Write-Line $_ }
    } catch {}
    Invoke-SafeCommand 'Disk integrity scan' { chkdsk /scan } -AdminOnly
}

# ============================================================
# STARTUP IMPACT
# ============================================================

function Show-StartupImpact {
    try {
        Write-Title 'STARTUP PROGRAMS'
        $items = @(Get-StartupItems)
        if ($items.Count -eq 0) { Write-Good 'No registry startup entries found.'; return }
        $items | Select-Object Location,Name | Format-Table -Wrap -AutoSize | Out-String | ForEach-Object { Write-Line $_ }
        if ($items.Count -gt 8) {
            Write-Warn "Startup count: $($items.Count) --- consider disabling unneeded apps."
            Write-Warn 'Use NEXUS option [5] Startup Manager to selectively disable.'
        } else {
            Write-Good "Startup count: $($items.Count) --- looks reasonable."
        }
    } catch { Write-Warn "Startup impact failed: $($_.Exception.Message)" }
}

# ============================================================
# POWER & GAME STATUS
# ============================================================

function Show-PowerStatus {
    Write-Title 'POWER & GAMING STATUS'
    Invoke-SafeCommand 'Active power plan' { powercfg /getactivescheme }
    try {
        $gb  = Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -EA SilentlyContinue
        $dvr = Get-ItemProperty 'HKCU:\System\GameConfigStore' -EA SilentlyContinue
        $gm  = if ($gb  -and $gb.PSObject.Properties['AutoGameModeEnabled']) { $gb.AutoGameModeEnabled } else { 'unknown' }
        $cap = if ($dvr -and $dvr.PSObject.Properties['GameDVR_Enabled'])    { $dvr.GameDVR_Enabled } else { 'unknown' }
        Write-Line "Game Mode  : $gm"
        Write-Line "Game DVR   : $cap"
    } catch {}
}

# ============================================================
# CACHE REPORT
# ============================================================

function Show-CacheReport {
    try {
        Write-Title 'CACHE MAP'
        $total = 0
        foreach ($e in (Get-CacheMap).GetEnumerator()) {
            $sz = Get-FolderSize $e.Value
            $total += $sz
            $col = if ($sz -gt 500MB) { 'Yellow' } else { 'Gray' }
            Write-Line ('{0,-30} {1,12}' -f $e.Key, (Format-Bytes $sz)) $col
        }
        Write-Line ''
        Write-Line "Total removable cache: $(Format-Bytes $total)" Green
        Write-Line 'Recycle Bin is NOT auto-emptied --- it may have files you want to restore.' Yellow
    } catch { Write-Warn "Cache report failed: $($_.Exception.Message)" }
}

# ============================================================
# DRIVER & EVENT SCAN
# ============================================================

function Show-PnpIssues {
    Write-Title 'DRIVER & DEVICE SCAN'
    try {
        $bad = @(Get-PnpDevice -PresentOnly -EA Stop | Where-Object { $_.Status -and $_.Status -notin @('OK','Unknown') })
        if ($bad.Count -eq 0) { Write-Good 'No Plug-and-Play device errors found.' }
        else {
            Write-Crit "$($bad.Count) device(s) with issues:"
            $bad | Select-Object -First 20 Status,Class,FriendlyName |
                Format-Table -Wrap -AutoSize | Out-String | ForEach-Object { Write-Line $_ }
            Add-Action 'MEDIUM' 'Device errors found --- check Device Manager'
        }
    } catch { Write-Warn "Device scan error: $($_.Exception.Message)" }
}

function Show-BootEvents {
    Write-Title 'BOOT & SHUTDOWN SLOWDOWN EVENTS'
    try {
        $ev = @(Get-WinEvent -FilterHashtable @{
            LogName='Microsoft-Windows-Diagnostics-Performance/Operational'
            Id=100,101,102,103,106,200,201,202,203
            StartTime=(Get-Date).AddDays(-14)
        } -MaxEvents 10 -EA Stop)
        if ($ev.Count -eq 0) { Write-Good 'No recent boot/shutdown slowdown events (last 14 days).' }
        else {
            $ev | Select-Object TimeCreated,Id,@{N='Message';E={($_.Message -replace "`r|`n",' ')}} |
                Format-Table -Wrap -AutoSize | Out-String | ForEach-Object { Write-Line $_ }
        }
    } catch {
        if ($_.Exception.Message -like '*No events*') { Write-Good 'No slowdown events found.' }
        else { Write-Warn "Event log error: $($_.Exception.Message)" }
    }
}

function Show-DefenderStatus {
    Write-Title 'WINDOWS SECURITY STATUS'
    try {
        if (-not (Get-Command Get-MpComputerStatus -EA SilentlyContinue)) {
            Write-Warn 'Defender cmdlets unavailable.'
            return
        }
        $s = Get-MpComputerStatus -EA Stop
        Write-Line "Antivirus enabled     : $($s.AntivirusEnabled)"
        Write-Line "Real-time protection  : $($s.RealTimeProtectionEnabled)"
        Write-Line "Antispyware enabled   : $($s.AntispywareEnabled)"
        Write-Line "AM service enabled    : $($s.AMServiceEnabled)"
        Write-Line "Quick scan age (days) : $($s.QuickScanAge)"
        Write-Line "Full scan age (days)  : $($s.FullScanAge)"
        if (-not $s.RealTimeProtectionEnabled) {
            Write-Crit 'Real-time protection is OFF. This tool does NOT disable security features.'
        }
        if ($s.FullScanAge -gt 30) {
            Write-Warn "Full scan is $($s.FullScanAge) days old. Run a Windows Defender full scan."
            Add-Action 'LOW' "Defender full scan is $($s.FullScanAge) days old --- run a scan"
        }
    } catch { Write-Warn "Security status error: $($_.Exception.Message)" }
}

# ============================================================
# NETWORK DIAGNOSTICS
# ============================================================

function Show-NetworkDiag {
    Write-Title 'NETWORK DIAGNOSTICS'

    $targets = @('1.1.1.1','8.8.8.8','google.com','cloudflare.com')
    $pingResults = @{}

    Write-SubTitle 'Ping Tests'
    $totalAvg = 0; $okCount = 0
    foreach ($t in $targets) {
        $r = Test-PingTarget $t 4
        $pingResults[$t] = $r
        if ($r.Ok) {
            $col = if ($r.Avg -lt 50) { 'Green' } elseif ($r.Avg -lt 100) { 'Yellow' } else { 'Red' }
            Write-Line ('{0,-20} min/avg/max: {1}/{2}/{3} ms   loss: {4}%' -f $t,$r.Min,$r.Avg,$r.Max,$r.Loss) $col
            $totalAvg += $r.Avg; $okCount++
        } else {
            Write-Warn "$t FAILED: $($r.Error)"
        }
    }
    if ($okCount -gt 0) {
        $netScore = [Math]::Max(0, 100 - ([Math]::Min(200,($totalAvg/$okCount)) / 2))
        $netGrade = if ($netScore -ge 85) {'EXCELLENT'} elseif ($netScore -ge 65) {'GOOD'} elseif ($netScore -ge 45) {'FAIR'} else {'POOR'}
        Write-Line ''
        Write-Line "Network Quality Score: $([int]$netScore)/100  [$netGrade]" $(if ($netScore -ge 65) {'Green'} else {'Yellow'})
    }

    Write-SubTitle 'DNS Resolution'
    foreach ($n in @('google.com','cloudflare.com','microsoft.com')) {
        try {
            $r = Resolve-DnsName -Name $n -EA Stop | Select-Object -First 3 Name,Type,IPAddress
            Write-Good "$n resolved:"
            $r | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Line $_ }
        } catch { Write-Warn "$n DNS failed: $($_.Exception.Message)" }
    }

    Write-SubTitle 'Active Network Adapters'
    try {
        Get-NetAdapter -EA Stop | Where-Object Status -eq 'Up' |
            Select-Object Name,InterfaceDescription,LinkSpeed,MacAddress |
            Format-Table -AutoSize | Out-String | ForEach-Object { Write-Line $_ }
    } catch {}

    Write-SubTitle 'DNS Servers'
    try {
        Get-DnsClientServerAddress -AddressFamily IPv4 -EA Stop |
            Where-Object { $_.ServerAddresses.Count -gt 0 } |
            Select-Object InterfaceAlias,ServerAddresses |
            Format-Table -AutoSize | Out-String | ForEach-Object { Write-Line $_ }
    } catch {}

    Write-SubTitle 'TCP Global Parameters'
    Invoke-SafeCommand 'TCP global state' { netsh int tcp show global }
}

# ============================================================
# CACHE PURGE
# ============================================================

function Invoke-CachePurge {
    Write-Title 'SAFE CACHE PURGE'
    Write-Warn 'Personal folders (Desktop, Documents, Downloads, Pictures, Videos, Music, game saves) are NOT touched.'
    Write-Warn 'Browser and shader caches rebuild on first use. First launch may be slightly slower once --- then normal.'

    $before = Get-TotalCacheSize
    Write-Line "Cache before: $(Format-Bytes $before)" Yellow

    foreach ($e in (Get-CacheMap).GetEnumerator()) {
        $path = $e.Value
        if (-not (Test-Path -LiteralPath $path)) {
            Write-Line "  Skip (not found): $($e.Key)" DarkGray
            continue
        }

        if ($e.Key -eq 'Explorer Thumbnail Cache') {
            Write-Step "Clear $($e.Key)"
            Get-ChildItem -LiteralPath $path -Force -Filter 'thumbcache_*.db' -EA SilentlyContinue |
                ForEach-Object {
                    try { Remove-Item -LiteralPath $_.FullName -Force -EA Stop; Write-Line "    removed $($_.Name)" }
                    catch { Write-Line "    locked  $($_.Name)" DarkGray }
                }
            continue
        }

        if ($e.Key -eq 'Firefox Cache') {
            Write-Step "Clear $($e.Key)"
            Get-ChildItem -LiteralPath $path -Directory -EA SilentlyContinue | ForEach-Object {
                $c2 = Join-Path $_.FullName 'cache2'
                $sc = Join-Path $_.FullName 'startupCache'
                if (Test-Path $c2) { Write-Line "    cache2: $(Remove-Children $c2) entries removed" }
                if (Test-Path $sc) { Write-Line "    startupCache: $(Remove-Children $sc) entries removed" }
            }
            continue
        }

        Write-Step "Clear $($e.Key)"
        $n = Remove-Children $path
        Write-Line "    removed: $n items"
    }

    $after = Get-TotalCacheSize
    $freed = $before - $after
    if ($freed -lt 0) { $freed = 0 }
    Write-Line ''
    Write-Line "Cache after  : $(Format-Bytes $after)" Green
    Write-Line "Freed        : $(Format-Bytes $freed)" Green
}

# ============================================================
# WINDOWS REPAIR STACK
# ============================================================

function Invoke-SystemRepairs {
    try {
        Write-Title 'WINDOWS REPAIR STACK'
        Invoke-SafeCommand 'Flush DNS cache'               { ipconfig /flushdns }
        Invoke-SafeCommand 'Reset MS Store cache'          { wsreset.exe -i }
        Invoke-SafeCommand 'DISM component scan'           { DISM /Online /Cleanup-Image /ScanHealth }    -AdminOnly
        Invoke-SafeCommand 'DISM component cleanup'        { DISM /Online /Cleanup-Image /StartComponentCleanup } -AdminOnly
        Invoke-SafeCommand 'System file checker'           { sfc /scannow }                               -AdminOnly
    } catch { Write-Warn "Repair stack failed: $($_.Exception.Message)" }
}

# ============================================================
# FPS & PERFORMANCE BOOST
# ============================================================

function Invoke-FpsBoost {
    try {
        Write-Title 'SAFE FPS & PERFORMANCE MODE'
        Write-Warn 'Safe only: no overclock, no voltage, no security changes, no driver edits.'

    Invoke-SafeCommand 'Enable Windows Game Mode' {
        $p = 'HKCU:\Software\Microsoft\GameBar'
        New-Item -Path $p -Force | Out-Null
        New-ItemProperty -Path $p -Name 'AllowAutoGameMode'   -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p -Name 'AutoGameModeEnabled' -Value 1 -PropertyType DWord -Force | Out-Null
        'Game Mode enabled.'
    }

    Invoke-SafeCommand 'Set High Performance power plan' {
        powercfg /setactive SCHEME_MIN
        powercfg /getactivescheme
    }

    Invoke-SafeCommand 'Disable Hardware Accelerated GPU Scheduling (if enabled, may reduce latency)' {
        $p = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
        if (Test-Path $p) {
            $cur = (Get-ItemProperty -Path $p -EA SilentlyContinue).HwSchMode
            if ($null -ne $cur) { Write-Line "    HwSchMode current: $cur (1=enabled, 2=disabled)" }
        }
        'No change made --- adjust manually in Windows Graphics settings if needed.'
    }

    Write-Line ''
    Write-Line 'FPS tips:' Yellow
    Write-Line '  * Shader caches cleared --- first game launch may be slightly slower, then normal.'
    Write-Line '  * Close heavy background apps (see Top Processes) before gaming.'
    Write-Line '  * Plug in power cable --- battery mode can cut GPU performance 30-50%.'
        Write-Line '  * Make sure Game Mode shows 1 in NEXUS SCAN.'
    } catch { Write-Warn "FPS boost failed: $($_.Exception.Message)" }
}

# ============================================================
# RAM OPTIMIZER --- Maximum Safe RAM Reclamation
# ============================================================

function Invoke-RamOptimizer {
    Write-Title 'RAM OPTIMIZER'
    Write-Warn 'Safe method: trims working sets. No process killing. No fake RAM cleaners.'

    $memBefore = Get-MemStats
    Write-Line "RAM before: $(Format-Bytes $memBefore.UsedBytes) used  ($(Format-Pct $memBefore.UsedPct))" Yellow

    # Load P/Invoke for EmptyWorkingSet
    $typeDef = @"
using System;
using System.Runtime.InteropServices;
public class NexusMemHelper {
    [DllImport("psapi.dll", SetLastError=true)]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint dwAccess, bool bInherit, int dwPid);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);
    public const uint PROCESS_SET_QUOTA      = 0x0100;
    public const uint PROCESS_QUERY_INFO     = 0x0400;
}
"@
    try {
        Add-Type -TypeDefinition $typeDef -EA Stop
    } catch {
        # Type may already be loaded in this session
    }

    $skipNames = @('System','Idle','lsass','csrss','winlogon','services',
                   'smss','wininit','MsMpEng','SecurityHealth','svchost',
                   'NVDisplay.Container','audiodg','dwm')

    $applied = 0; $failed = 0; $skipped = 0

    Write-Step 'Trimming working sets of user-mode processes'
    $procs = @(Get-Process -EA SilentlyContinue | Where-Object { $skipNames -notcontains $_.ProcessName })
    $allowTrim = $true
    if (-not (Test-IsAdmin) -and -not $Interactive) {
        $allowTrim = $false
        Write-Warn 'EmptyWorkingSet skipped in non-interactive non-admin mode. Run from NEXUS.cmd to confirm it.'
    } elseif (-not (Test-IsAdmin) -and $Interactive) {
        $answer = Read-Host 'Trim user-mode working sets now? No apps are killed. Type YES to continue'
        $allowTrim = ($answer -eq 'YES')
    }

    if ($allowTrim) {
        foreach ($proc in $procs) {
            try {
                $ptr = [System.Runtime.InteropServices.Marshal]::AllocCoTaskMem(1)
                [System.Runtime.InteropServices.Marshal]::FreeCoTaskMem($ptr)
                [GC]::Collect()

                $handle = [NexusMemHelper]::OpenProcess(
                    ([NexusMemHelper]::PROCESS_SET_QUOTA -bor [NexusMemHelper]::PROCESS_QUERY_INFO),
                    $false,
                    $proc.Id
                )
                if ($handle -ne [IntPtr]::Zero) {
                    $ok = [NexusMemHelper]::EmptyWorkingSet($handle)
                    [void][NexusMemHelper]::CloseHandle($handle)
                    if ($ok) { $applied++ } else { $failed++ }
                } else { $skipped++ }
            } catch { $skipped++ }
        }
    } else {
        $skipped = $procs.Count
    }

    Write-Line "    Applied to $applied processes  |  Skipped: $skipped  |  Failed: $failed"

    # Standby list flush (Admin only) via NtSetSystemInformation
    if (Test-IsAdmin) {
        Write-Step 'Flushing standby memory list (Admin)'
        $standbyBefore = Get-StandbyBytes
        $ntDef = @"
using System;
using System.Runtime.InteropServices;
public class NexusNtMem {
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int InfoClass, ref int pInfo, int cbSize);
    public const int SystemMemoryListInformation = 80;
    public const int MemoryPurgeStandbyList      = 3;
}
"@
        try {
            Add-Type -TypeDefinition $ntDef -EA Stop
        } catch {}

        try {
            $val    = [NexusNtMem]::MemoryPurgeStandbyList
            $status = [NexusNtMem]::NtSetSystemInformation([NexusNtMem]::SystemMemoryListInformation, [ref]$val, 4)
            Start-Sleep -Milliseconds 800
            $standbyAfter = Get-StandbyBytes
            $standbyFreed = [Math]::Max([double]0, ([double]$standbyBefore - [double]$standbyAfter))
            if ($status -eq 0) {
                Write-Line "    Standby list purged successfully. Freed ~$(Format-Bytes $standbyFreed)." Green
            } else {
                Write-Warn "    Standby flush returned NTSTATUS: 0x$($status.ToString('X8'))"
            }
        } catch { Write-Warn "Standby flush error: $($_.Exception.Message)" }
    } else {
        Write-Warn 'Standby list flush skipped --- run as Administrator for deeper RAM reclaim.'
    }

    Start-Sleep -Milliseconds 1500
    $memAfter = Get-MemStats
    $freed    = [Math]::Max([double]0, ([double]$memBefore.UsedBytes - [double]$memAfter.UsedBytes))

    Write-Line ''
    Write-Line "RAM after  : $(Format-Bytes $memAfter.UsedBytes) used  ($(Format-Pct $memAfter.UsedPct))" Green
    Write-Line "Freed      : ~$(Format-Bytes $freed)" Green

    if ($freed -lt 50MB) {
        Write-Line '  Note: Working set trim frees RAM gradually as Windows moves trimmed pages.' DarkGray
        Write-Line '  Real gain shows over the next few minutes as pages are reclaimed.' DarkGray
    }

    Show-TopProcesses
}

# ============================================================
# NETWORK BOOST --- Maximum Safe Internet Optimization
# ============================================================

function Invoke-NetworkBoost {
    Write-Title 'NET BOOST --- FULL NETWORK OPTIMIZATION'
    Write-Warn 'Reversible changes only. Does not change Wi-Fi password, delete profiles, or modify firewall.'

    # --- Before snapshot ---
    Write-SubTitle 'Ping BEFORE'
    $targets = @('1.1.1.1','8.8.8.8','google.com','cloudflare.com')
    $before  = @{}
    foreach ($t in $targets) {
        $r = Test-PingTarget $t 3
        $before[$t] = $r
        if ($r.Ok) { Write-Line ('{0,-20} avg: {1} ms' -f $t,$r.Avg) Gray }
        else       { Write-Warn "$t FAILED" }
    }

    # --- DNS Flush & Repair ---
    Write-SubTitle 'DNS Optimization'
    Invoke-SafeCommand 'Flush DNS resolver cache' { ipconfig /flushdns }

    # Ensure DNS Client service is running
    Invoke-SafeCommand 'Set DNS Cache service automatic and running' {
        Set-Service -Name 'Dnscache' -StartupType Automatic -EA SilentlyContinue
        $svc = Get-Service 'Dnscache' -EA SilentlyContinue
        if ($svc -and $svc.Status -ne 'Running') {
            Start-Service 'Dnscache' -EA SilentlyContinue
            'DNS Cache service started.'
        } else { 'DNS Cache service already running.' }
    } -AdminOnly

    # --- TCP/IP Stack Tuning (Admin) ---
    Write-SubTitle 'TCP/IP Stack Optimization (Admin required for most)'

    Invoke-SafeCommand 'TCP auto-tuning: normal'         { netsh int tcp set global autotuninglevel=normal }        -AdminOnly
    Invoke-SafeCommand 'Enable RSS (Receive Side Scaling)'{ netsh int tcp set global rss=enabled }                  -AdminOnly
    Invoke-SafeCommand 'Enable ECN (reduces packet loss)' { netsh int tcp set global ecncapability=enabled }        -AdminOnly
    Invoke-SafeCommand 'Set Initial RTO to 2000ms'        { netsh int tcp set global initialRto=2000 }              -AdminOnly
    Invoke-SafeCommand 'Disable NonSACK RTT resiliency'   { netsh int tcp set global nonsackrttresiliency=disabled } -AdminOnly
    Invoke-SafeCommand 'Set max SYN retransmissions: 2'   { netsh int tcp set global maxsynretransmissions=2 }      -AdminOnly
    Invoke-SafeCommand 'Enable TCP Fast Open'             { netsh int tcp set global fastopen=enabled }             -AdminOnly
    Invoke-SafeCommand 'Enable Fast Open Fallback'        { netsh int tcp set global fastopenFallback=enabled }     -AdminOnly
    Invoke-SafeCommand 'Enable Direct Cache Access'       { netsh int tcp set global dca=enabled }                  -AdminOnly
    Invoke-SafeCommand 'Enable NetDMA'                    { netsh int tcp set global netdma=enabled }               -AdminOnly
    Invoke-SafeCommand 'Disable chimney offload (latency)'{ netsh int tcp set global chimney=disabled }             -AdminOnly

    # --- QoS Bandwidth Fix ---
    Write-SubTitle 'QoS Bandwidth Fix'
    Invoke-SafeCommand 'Remove 20% bandwidth reservation (QoS)' {
        $qp = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched'
        if (-not (Test-Path $qp)) { New-Item -Path $qp -Force | Out-Null }
        New-ItemProperty -Path $qp -Name 'NonBestEffortLimit' -Value 0 -PropertyType DWord -Force | Out-Null
        'QoS bandwidth limit set to 0% (was up to 20% reserved by default).'
    } -AdminOnly

    # --- Safe Network Refresh ---
    Write-SubTitle 'Safe Network Refresh'
    Invoke-SafeCommand 'Reload NetBIOS name cache' { nbtstat -R } -AdminOnly
    Invoke-SafeCommand 'Refresh NetBIOS names'     { nbtstat -RR } -AdminOnly
    if ($Interactive) {
        Write-Warn 'IP release/renew may briefly disconnect the network.'
        $refreshAnswer = Read-Host 'Type YES to run ipconfig /release and /renew, or press Enter to skip'
        if ($refreshAnswer -eq 'YES') {
            Invoke-SafeCommand 'Release IPv4 address' { ipconfig /release }
            Invoke-SafeCommand 'Renew IPv4 address'   { ipconfig /renew }
        } else {
            Write-Warn 'IP release/renew skipped by user.'
        }
    } else {
        Write-Warn 'IP release/renew skipped in non-interactive validation mode.'
    }
    Invoke-SafeCommand 'Reset Winsock catalog' { netsh winsock reset } -AdminOnly

    # --- Network Adapter Tuning ---
    Write-SubTitle 'Network Adapter Tuning (Admin)'
    if (Test-IsAdmin) {
        try {
            $adapters = @(Get-NetAdapter -EA Stop | Where-Object {
                $_.Status -eq 'Up' -and
                $_.InterfaceDescription -notmatch 'VirtualBox|VMware|Virtual|Loopback|Bluetooth'
            })
            if ($adapters.Count -eq 0) { Write-Line '    No active physical adapters found to tune.' DarkGray }
            foreach ($a in $adapters) {
                Write-Step "Tuning $($a.Name)"
                try { Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName 'Receive Buffers' -DisplayValue '512' -EA SilentlyContinue } catch {}
                try { Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName 'Transmit Buffers' -DisplayValue '512' -EA SilentlyContinue } catch {}
                try { Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName 'Interrupt Moderation' -DisplayValue 'Disabled' -EA SilentlyContinue } catch {}
                
                # Power Management
                $netClassPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}'
                $keys = Get-ChildItem -Path $netClassPath -EA SilentlyContinue
                foreach ($k in $keys) {
                    $desc = (Get-ItemProperty -Path $k.PSPath -Name 'DriverDesc' -EA SilentlyContinue).DriverDesc
                    if ($desc -and $a.InterfaceDescription -match [regex]::Escape($desc)) {
                        New-ItemProperty -Path $k.PSPath -Name 'PnPCapabilities' -Value 24 -PropertyType DWord -Force -EA SilentlyContinue | Out-Null
                        break
                    }
                }
            }
        } catch { Write-Warn "Adapter tuning failed: $($_.Exception.Message)" }
    } else { Write-Warn 'Skipped physical adapter tuning (Admin required).' }

    # --- DNS Option ---
    Write-SubTitle 'Cloudflare DNS Override'
    $adapters = @(Get-NetAdapter -EA SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'VirtualBox|VMware|Virtual|Loopback|Bluetooth' })
    foreach ($adapter in $adapters) {
        $dns = Get-DnsClientServerAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -EA SilentlyContinue
        if ($dns -and $dns.ServerAddresses) {
            $firstDns = $dns.ServerAddresses[0]
            if ($firstDns -match '^192\.168\.' -or $firstDns -match '^10\.' -or $firstDns -match '^172\.(1[6-9]|2[0-9]|3[0-1])\.') {
                Write-Line ("Current DNS for {0} is {1} (Local/Router)." -f $adapter.Name, $firstDns) Yellow
                if (-not (Test-IsAdmin)) {
                    Write-Warn 'Cloudflare DNS change skipped: Administrator required.'
                    continue
                }
                if (-not $Interactive) {
                    Write-Warn 'Cloudflare DNS change skipped in non-interactive mode.'
                    continue
                }
                Write-Line 'Would you like to set DNS to 1.1.1.1 and 1.0.0.1 for faster resolution? Type YES to apply.' Cyan
                $resp = Read-Host ">"
                if ($resp -eq 'YES') {
                    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses ('1.1.1.1', '1.0.0.1') -EA SilentlyContinue
                    Write-Good ("DNS changed to Cloudflare (1.1.1.1, 1.0.0.1) for {0}." -f $adapter.Name)
                }
            }
        }
    }

    # --- After snapshot ---
    Write-SubTitle 'Ping AFTER'
    foreach ($t in $targets) {
        $r = Test-PingTarget $t 3
        if ($r.Ok) {
            $b = $before[$t]
            if ($b -and $b.Ok) {
                $diff = [Math]::Round($b.Avg - $r.Avg, 1)
                $txt = if ($diff -gt 0) { "Improved by $diff ms" } elseif ($diff -lt 0) { "Worse by $(-$diff) ms" } else { "No change" }
                $col = if ($r.Avg -lt 50) { 'Green' } elseif ($r.Avg -lt 100) { 'Yellow' } else { 'Red' }
                Write-Line ('{0,-20} avg: {1} ms  ({2})' -f $t,$r.Avg,$txt) $col
            } else {
                Write-Line ('{0,-20} avg: {1} ms' -f $t,$r.Avg) Gray
            }
        } else { Write-Warn "$t FAILED" }
    }
}

# ============================================================
# STARTUP MANAGER
# ============================================================

function Invoke-StartupManager {
    Write-Title 'STARTUP MANAGER'
    Write-Warn 'Selectively disable programs from booting with Windows.'
    Write-Warn 'Does NOT delete entries. Simply disables them reversibly.'
    
    $startups = Get-StartupItems
    if ($startups.Count -eq 0) { Write-Good 'No startup entries found.'; return }
    
    $valid = New-Object System.Collections.Generic.List[object]
    $i = 1
    foreach ($s in $startups) {
        $disabled = ($s.Name -match '^_DISABLED_')
        $status = if ($disabled) { '[DISABLED]' } else { '[ENABLED] ' }
        $scope = if ($s.Location -match 'HKLM') { 'System' } else { 'User  ' }
        
        $color = if ($disabled) { [ConsoleColor]::DarkGray } else { [ConsoleColor]::White }
        Write-Line ('[{0,2}] {1} ({2}) {3} -> {4}' -f $i, $status, $scope, $s.Name, $s.Command) $color
        [void]$valid.Add([pscustomobject]@{
            Index = $i
            Original = $s
            IsDisabled = $disabled
            IsSystem = ($scope -eq 'System')
        })
        $i++
    }
    
    Write-Line ''
    if (-not $Interactive) {
        Write-Warn 'Startup changes skipped in non-interactive mode. Open NEXUS.cmd option 5 to choose entries.'
        return
    }
    Write-Line 'Enter numbers to DISABLE (comma separated), or press Enter to skip:' Cyan
    $inputStr = Read-Host ">"
    if ([string]::IsNullOrWhiteSpace($inputStr)) { Write-Line 'No changes made.'; return }
    
    $selections = $inputStr -split ',' | ForEach-Object { $_.Trim() }
    $toProcess = @()
    
    foreach ($sel in $selections) {
        if ($sel -match '^\d+$') {
            $idx = [int]$sel - 1
            if ($idx -ge 0 -and $idx -lt $valid.Count) {
                $target = $valid[$idx]
                $name = $target.Original.Name
                
                if ($target.IsDisabled) {
                    Write-Warn "Skipping already disabled entry: $name"
                    continue
                }
                if (-not $target.IsDisabled -and $name -match 'SecurityHealth|RtkAudUService|Defender|Waves|Realtek') {
                    Write-Warn "Skipping critical/audio system startup: $name"
                    continue
                }
                if ($target.IsSystem -and -not (Test-IsAdmin)) {
                    Write-Warn "Cannot modify System startup without Admin: $name"
                    continue
                }
                $toProcess += $target
            }
        }
    }
    
    if ($toProcess.Count -eq 0) { return }
    Write-Warn 'Selected entries will be disabled by renaming registry values with _DISABLED_. This is reversible.'
    $confirm = Read-Host 'Type YES to apply startup changes'
    if ($confirm -ne 'YES') {
        Write-Line 'Startup changes cancelled.'
        return
    }
    
    foreach ($t in $toProcess) {
        $path = $t.Original.Location
        $oldName = $t.Original.Name
        $val = $t.Original.Command
        
        $newName = "_DISABLED_$oldName"
        try {
            Set-ItemProperty -Path $path -Name $newName -Value $val -EA Stop
            Remove-ItemProperty -Path $path -Name $oldName -EA Stop
            Write-Good "Disabled: $oldName"
        } catch { Write-Warn "Failed to disable $oldName" }
    }
}

# ============================================================
# MAIN
# ============================================================

try {
    Show-Banner
    
    switch ($Mode) {
        'Scan' {
            $m = Show-SystemPulse
            Show-BottleneckRadar $m
            Show-SystemHealth
            Show-TopProcesses
            Show-DiskHealth
            Show-StartupImpact
            Show-PowerStatus
            Show-CacheReport
            Show-PnpIssues
            Show-BootEvents
            Show-DefenderStatus
            Show-NetworkDiag
        }
        'Optimize' {
            Write-Title 'POWER BOOST & SYSTEM REPAIR'
            $before = Show-SystemPulse
            Invoke-CachePurge
            Invoke-SystemRepairs
            Invoke-FpsBoost
            Invoke-RamOptimizer
            $after = Show-SystemPulse
            Write-Title 'OPTIMIZATION SUMMARY'
            Write-Line "Health Score: $($before.Health.Score)  =>  $($after.Health.Score)" Green
            Write-Line "RAM Used    : $(Format-Pct $before.Memory.UsedPct)  =>  $(Format-Pct $after.Memory.UsedPct)" Green
            Write-Line "Cache Size  : $(Format-Bytes $before.CacheBytes)  =>  $(Format-Bytes $after.CacheBytes)" Green
        }
        'Network' {
            Invoke-NetworkBoost
        }
        'RAM' {
            Invoke-RamOptimizer
        }
        'Startup' {
            Invoke-StartupManager
        }
    }
} finally {
    Write-Line ''
    Write-Line ('=' * 74) Cyan
    Write-Line '  RECOMMENDED ACTIONS' Cyan
    Write-Line ('=' * 74) Cyan
    if ($script:ActionItems.Count -eq 0) {
        Write-Line '  System looks extremely healthy. No priority actions needed.' Green
    } else {
        foreach ($a in $script:ActionItems) {
            if ($a -match '\[HIGH\]') { Write-Line "  $a" Red }
            elseif ($a -match '\[MEDIUM\]') { Write-Line "  $a" Yellow }
            else { Write-Line "  $a" White }
        }
    }
    
    Write-Line ''
    Write-Line '  EXECUTION TIMINGS:' DarkGray
    foreach ($t in $script:SectionTimings) { Write-Line "  $t" DarkGray }
    
    $outText = ($script:ReportLines -join "`r`n")
    try {
        $outText | Out-File -FilePath $ReportPath -Encoding UTF8 -Force -EA Stop
        Write-Line ''
        Write-Line "Report saved: $ReportPath" DarkGray
    } catch {
        Write-Line ''
        Write-Line "Failed to save report: $($_.Exception.Message)" Red
    }
}


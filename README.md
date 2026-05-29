# NEXUS v2.0
**Network · Engine · Xtreme · Unified · System**

NEXUS is a complete rewrite and upgrade of the 99nmn1 Windows Optimization Tool. Designed as a "Safe Beast", it extracts maximum performance out of your Windows environment using built-in system APIs—without risking your data or compromising system integrity.

## Features & Modules

### 1. DEEP SCAN
Runs a comprehensive system analysis.
- Calculates an overall System Health Score based on CPU, RAM, Disk, Temp Cache size, Startup apps, Latency, Page File, Battery, and Thermals.
- Scans and detects thermal bottlenecks via ACPI sensors.
- Verifies virtual memory (Page File) usage.
- Scans `C:\Windows\Temp` and your user Temp folder for extremely large files causing bloat.
- Generates a completely secure, privacy-masked report of your system status.

### 2. POWER BOOST
Safe cache purging and performance tuning.
- Empties Windows temp directories and thumbnail caches securely.
- Invokes the RAM Optimizer to free up working set memory.
- Enables the Windows "High Performance" power plan.

### 3. NET BOOST
Extreme network stack tuning for lower latency and better ping.
- Restores TCP auto-tuning and optimizes Receive Side Scaling (RSS).
- Disables Chimney offload, enables Direct Cache Access (DCA) and NetDMA.
- Lowers initial RTO and limits Max SYN retransmissions for faster packet drops/reconnects.
- Disables power management and interrupt moderation on physical network adapters.
- Removes the default Windows 20% QoS bandwidth limit.
- Benchmarks latency before and after applying optimizations.

### 4. RAM BOOST
Dedicated memory optimizer using native Windows APIs.
- Empties the Working Set of non-critical user-mode processes (`EmptyWorkingSet`).
- Flushes the system Standby List safely via `NtSetSystemInformation` (requires Administrator).
- Reclaims GBs of wasted memory without force-closing your applications.

### 5. STARTUP MANAGER
Interactive tool to view and securely disable startup programs.
- Safely lists all HKCU and HKLM startup items.
- Allows you to toggle them off by renaming their keys (`_DISABLED_`), making it 100% reversible.
- Specifically blocks disabling critical Windows Security and Audio drivers to prevent accidental system damage.

## Usage

1. Open `NEXUS.cmd`. (Right-click and "Run as Administrator" is highly recommended for full features like Standby List flush and Network Tuning).
2. Type the number corresponding to the module you want to run.
3. Review the outputs. Detailed logs will automatically be saved to the `logs/` directory.

## Strict Safety Rules

NEXUS is built with a zero-tolerance policy towards destructive behaviors:
- **Zero Personal Data Touched:** NEXUS will NEVER touch your Desktop, Documents, Downloads, Pictures, Videos, Music, or game saves.
- **Privacy Masked:** All file paths written to the logs or console are masked. Your Windows username will appear as `%USERNAME%`.
- **System Stability:** It does not remove system drivers, kernel files, or modify UEFI/BIOS settings.
- **Security First:** Windows Defender, Firewall, and Security services are completely ignored and protected.
- **No Force Kills:** The RAM Optimizer does not kill applications; it gracefully forces them to page out unused memory to free up active RAM.
- **No Overclocking:** The tool optimizes Windows software settings, it does not apply unstable CPU/GPU/RAM overclocks.
- **Standalone:** No internet downloads, NuGet packages, or third-party executables are required. It uses 100% native Windows PowerShell APIs.

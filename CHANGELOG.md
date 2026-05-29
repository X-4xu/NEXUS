# CHANGELOG

## [v2.0] - NEXUS (Network . Engine . Xtreme . Unified . System)
*Complete Rewrite & Upgrade from 99nmn1*

### Added
- **RAM OPTIMIZER:** Maximum Safe RAM Reclamation using `EmptyWorkingSet` and `MemoryPurgeStandbyList` (NtSetSystemInformation).
- **NETWORK OPTIMIZER:** Comprehensive TCP/IP Stack Tuning (DCA, NetDMA, Initial RTO, Max SYN retransmissions).
- **NETWORK ADAPTER TUNING:** Dynamically disables power management and interrupt moderation on physical adapters.
- **QOS BANDWIDTH:** Removes the default 20% QoS bandwidth limit for better overall throughput.
- **PING BENCHMARK:** Added before-and-after latency tests for major DNS servers (1.1.1.1, 8.8.8.8, etc.).
- **STARTUP MANAGER:** Interactive tool to view and securely disable startup programs without deleting their keys (reversible).
- **THERMAL CHECK:** Reads ACPI Thermal Zone temperatures and categorizes system thermals.
- **PAGE FILE ANALYSIS:** Checks virtual memory utilization vs allocation to detect bottlenecks.
- **BATTERY HEALTH:** Identifies laptop battery wear levels to prevent performance throttling.
- **LATENCY SCORE:** Added Network Latency Quality Score to the Deep Scan module.
- **NEW UI:** Completely redesigned ASCII banner and responsive health bars.

### Improved
- **HEALTH SCORE:** Now uses a 9-factor weight formula (CPU, RAM, Disk, Cache, Startups, Ping, Page File, Battery, Thermal).
- **LOGGING:** Advanced timestamped reporting mechanism that securely masks all personal user paths (`%USERNAME%` and `%USERPROFILE%`).
- **ERROR HANDLING:** Fully rewritten in strict mode with safe fail-back for systems without Administrator privileges.

### Removed
- Deprecated legacy components from the original 99nmn1 structure to enforce the new strict safety rules.

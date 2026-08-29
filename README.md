# <p align="center"><img src="assets/banner.svg" alt="NEXUS Banner" width="100%"></p>

<p align="center">
  <a href="https://github.com/X-4xu/NEXUS/releases/latest"><img src="https://img.shields.io/badge/Release-v1.0.0-0284C7?style=for-the-badge" alt="Release: v1.0.0"></a>
  <img src="https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011-0082FC?style=for-the-badge&logo=windows&logoColor=white" alt="Platform: Windows">
  <img src="https://img.shields.io/badge/Language-PowerShell%205.1%2B-1786C4?style=for-the-badge&logo=powershell&logoColor=white" alt="Language: PowerShell">
  <img src="https://img.shields.io/badge/Safety-100%25%20Safe%20Beast-2EA44F?style=for-the-badge&logo=target" alt="Safety: 100% Safe">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/X-4xu/NEXUS?style=for-the-badge&color=orange" alt="License"></a>
</p>

---

## ⚡ What is NEXUS?

**NEXUS** (Network Engine Xtreme Unified System) is an advanced, lightweight command-line suite designed to extract maximum performance from Windows machines safely. 

Unlike generic "Windows Tweakers" that delete system drivers, disable security protections, or break Windows Update, NEXUS adheres to a **Strict Safety Standard** ("Safe Beast"). It utilizes built-in Windows APIs and native configurations to reduce network latency, optimize active memory, and streamline startup processes—fully protecting your privacy and OS stability.

---

## 🚀 Key Features & Modules

### 🔍 1. Deep System Scan
* **System Health Score:** Automatically calculates a health percentage based on thermals, memory pressure, disk bloat, and system latency.
* **Thermal Monitoring:** Checks hardware temperature sensors to detect performance throttling.
* **Smart Bloat Detection:** Scans temp directories for oversized files causing storage lag.

### 💨 2. Power Boost
* **RAM Standby Purging:** Invokes native memory APIs to clear cached standby RAM.
* **Cache Clean:** Safely deletes temporary, thumbnails, and update caches.
* **Ultimate Performance:** Activates high-performance power plans dynamically.

### 🌐 3. Net Boost (Latency & Ping Optimizer)
* **Stack Tuning:** Restores optimal TCP Auto-Tuning levels and enables Receive Side Scaling (RSS).
* **Adapter Tuning:** Disables physical adapter energy savings, limiters, and interrupt moderation to remove milliseconds off gaming ping.
* **QoS Optimization:** Unlocks the default 20% bandwidth restriction reserved by Windows.

### 🧠 4. RAM Optimizer
* **Graceful Release:** Signals non-essential applications to flush unused active memory (`EmptyWorkingSet`) back to the system.
* **Zero Crashes:** Unlike aggressive task killers, it never force-terminates applications, avoiding data loss.

### 🛠️ 5. Startup Manager
* **Interactive Control:** Lists startup programs launched from Registry hives.
* **Non-Destructive Disable:** Renames registry keys to `_DISABLED_` allowing one-click rollback.
* **Protected System Keys:** Hardcoded safety list ensures audio, graphics, and Windows security services can never be accidentally disabled.

---

## 🛡️ The "Safe Beast" Promise

Generic optimizers on the internet are risky. NEXUS guarantees:
* **Zero Personal Files Touched:** Your Desktop, Documents, Downloads, Pictures, and game saves are 100% untouched.
* **No Telemetry/Spyware:** Operates entirely offline with 100% open-source PowerShell script.
* **Windows Security Untouched:** Windows Defender, Firewall, and essential services remain fully active.
* **No Overclocking:** Modifies OS configurations, never touches physical voltages or clocks.

---

## 📦 How to Install & Run

1. **Clone or Download** this repository.
2. Open the `NEXUS/` folder.
3. Right-click **`NEXUS.cmd`** and select **Run as Administrator** *(Required for network tuning and deep registry optimization)*.
4. Select a module using the interactive menu options.

---

## 📊 Before & After Comparison

| Optimization Area | Generic Tweaks | NEXUS (Safe Beast) |
| :--- | :--- | :--- |
| **System Security** | ❌ Disables Defender / Firewall | ✅ Keeps Security 100% active |
| **RAM Optimization** | ❌ Kills processes, causes crashes | ✅ Native memory flush, zero crashes |
| **Network Latency** | ❌ Standard registry wipes | ✅ Physical adapter interrupt & RSS tuning |
| **Reversibility** | ❌ Permanent breaking edits | ✅ Safe disabled keys, easy to restore |

---

## 🤝 Contributing & Support

Contributions are welcome! If you have optimized configuration parameters or want to suggest new features, feel free to open an Issue or submit a Pull Request.

*Give a ⭐ if this project helped you optimize your Windows experience!*

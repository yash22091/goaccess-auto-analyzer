# GoAccess Auto Analyzer 

A powerful Bash utility to automate the installation, configuration, and usage of [GoAccess](https://goaccess.io/) — a real-time and historical web log analyzer. This script is ideal for DevOps, SOC teams, and sysadmins who want rapid visibility into web server traffic.

---

## Features

* Prerequisite checking for Nginx or Apache2 before installation
* One-command installation of GoAccess
* Real-time dashboards on `localhost:7890`
* Static HTML reports from current or rotated access logs
* Scheduled daily reports (for automation)
* Supports Nginx, Apache, and compressed `.gz` logs
* Date range filters (`--since` and `--until`)
* Lightweight and terminal-friendly
* Air-gapped/SOC compatible

---

## Script Overview

This script checks whether required services like **Nginx** or **Apache2** are already installed on the system. If neither of them is found, it will:

* Abort the installation of GoAccess
* Log the reason in `/var/log/goaccess_installer.log`
* Notify the user that a supported web server is missing

---

## Modes Supported

| Mode                 | Description                                            |
| -------------------- | ------------------------------------------------------ |
| `install`            | Checks for Nginx/Apache, installs GoAccess             |
| `run`                | Generates real-time or static reports from logs        |
| `daily-report`       | Parses yesterday's log and exports report to `/tmp/`   |
| `realtime-dashboard` | Launches a local dashboard at `http://localhost:7890/` |
| `help`               | Displays full usage guide                              |

---

## Prerequisites

* Linux-based system (Ubuntu, CentOS, etc.)
* Web server logs (Nginx, Apache)
* Internet access for installation (optional if GoAccess is already installed)

---

## Installation

```bash
git clone https://github.com/yash22091/goaccess-auto-analyzer.git
cd goaccess-auto-analyzer
chmod +x goaccess_installer.sh
./goaccess_installer.sh install
```

---

## Usage Examples

### ➔ Static HTML Report

```bash
./goaccess_installer.sh run --logfile /var/log/nginx/access.log --output /tmp/report.html
```

### ➔ Historical Log Report (Rotated)

```bash
./goaccess_installer.sh run --logfile /var/log/nginx/access.log.1 --since 2025-06-01 --until 2025-06-05 --output old_report.html
```

### ➔ Real-Time Dashboard

```bash
./goaccess_installer.sh run --real-time --ws-url ws://0.0.0.0:7890
```

### ➔ Daily Automation (cron)

```bash
0 2 * * * /path/to/goaccess_installer.sh daily-report
```

---

## Sample Output

* HTML Reports (`report.html`)
* Live dashboards at `http://localhost:7890/`
* Log visualization with geo, IPs, traffic status, referrers, user agents

---

## Contributing

Pull requests are welcome! If you have improvements, please fork the repo and submit a PR.

---

## License

MIT License

---

## Author

[Yash Patel] — script creator
Maintained and enhanced by the community.

---

## Related Projects

* [GoAccess Official](https://github.com/allinurl/goaccess)
* [GoAccess Documentation](https://goaccess.io/docs)

---

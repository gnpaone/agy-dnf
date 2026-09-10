# Antigravity Linux DNF Repository

```
 █████╗ ███╗   ██╗████████╗██╗ ██████╗ ██████╗  █████╗ ██╗   ██╗██╗████████╗██╗   ██╗
██╔══██╗████╗  ██║╚══██╔══╝██║██╔════╝ ██╔══██╗██╔══██╗██║   ██║██║╚══██╔══╝╚██╗ ██╔╝
███████║██╔██╗ ██║   ██║   ██║██║  ███╗██████╔╝███████║██║   ██║██║   ██║    ╚████╔╝
██╔══██║██║╚██╗██║   ██║   ██║██║   ██║██╔══██╗██╔══██║╚██╗ ██╔╝██║   ██║     ╚██╔╝
██║  ██║██║ ╚████║   ██║   ██║╚██████╔╝██║  ██║██║  ██║ ╚████╔╝ ██║   ██║      ██║
╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝   ╚═╝      ╚═╝
```

> **This is a community repository. Not affiliated with, endorsed by, or supported by Google.**

This repository hosts an automated RPM/DNF package repository for **Google Antigravity 2.0**, **Antigravity IDE**, and **Antigravity CLI** for Fedora, CentOS, RHEL, and other RPM-based Linux distributions. 

Packages are automatically built and updated from the official Google release tarballs.

## Setup Instructions

Add this DNF repository to your system to install and receive automatic updates for Antigravity:

```bash
sudo dnf config-manager --add-repo https://gnpaone.github.io/agy-dnf/antigravity.repo
```

## Available Packages

You can install any of the available packages using `dnf`:

### 1. Antigravity 2.0 (Desktop)
```bash
sudo dnf install antigravity
```

### 2. Antigravity IDE
```bash
sudo dnf install antigravity-ide
```

### 3. Antigravity CLI
```bash
sudo dnf install antigravity-cli
```

*(Note: The CLI is provided as a subpackage, so it can be installed alongside or independently from the desktop environment).*

## Updates
Once installed, the packages will automatically update whenever you run your normal system updates:
```bash
sudo dnf update
```

## Contributing
Contributions are welcome!.

## License
MIT. See [LICENSE](LICENSE).

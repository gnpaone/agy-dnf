#!/usr/bin/env bash
set -euo pipefail

mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
mkdir -p public/repo

echo "Fetching latest versions and generating spec..."
python3 - <<'EOF'
import json
import re
import urllib.request
import urllib.parse
from urllib.parse import urljoin, unquote
import os
import gzip

# 1. Fetch CLI
try:
    cli_manifest_url = "https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json"
    req = urllib.request.Request(cli_manifest_url, headers={'User-Agent': 'Mozilla/5.0'})
    resp = urllib.request.urlopen(req)
    cli_data = json.loads(resp.read().decode('utf-8'))
    cli_url = cli_data.get('url', '')
    cli_ver = cli_data.get('version', '1.0.0')
except Exception as e:
    print(f"Error fetching CLI: {e}")
    cli_url = ""
    cli_ver = "1.0.0"

# 2. Fetch Desktop & IDE
try:
    url = "https://antigravity.google/download"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    resp = urllib.request.urlopen(req)
    data = resp.read()
    if resp.info().get('Content-Encoding') == 'gzip':
        data = gzip.decompress(data)
    html = data.decode('utf-8', errors='replace')
    
    desktop_url = ""
    ide_url = ""

    m_desktop = re.search(r'https?://[^\s<>\)"\']*/linux-x64/Antigravity\.tar\.gz', html)
    if m_desktop:
        desktop_url = m_desktop.group(0)

    m_ide = re.search(r'https?://[^\s<>\)"\']*/linux-x64/Antigravity[^"\']*IDE\.tar\.gz', html)
    if m_ide:
        ide_url = m_ide.group(0)
    
    def extract_version(url_str):
        if not url_str:
            return '1.0.0'
        decoded = unquote(url_str)
        for pattern in (r'/antigravity-hub/([^/]+)/', r'/stable/([^/]+)/', r'/(\d+\.\d+\.\d+(?:-[^/]+)?)/'):
            m = re.search(pattern, decoded)
            if m:
                return m.group(1).split('-', 1)[0]
        return '1.0.0'

    desktop_ver = extract_version(desktop_url)
    ide_ver = extract_version(ide_url)
except Exception as e:
    print(f"Error fetching Desktop/IDE: {e}")
    desktop_url = ""
    desktop_ver = "1.0.0"
    ide_url = ""
    ide_ver = "1.0.0"

# Fallbacks if URLs are empty
if not desktop_url:
    desktop_url = "https://example.com/antigravity.tar.gz"
if not ide_url:
    ide_url = "https://example.com/antigravity-ide.tar.gz"
if not cli_url:
    cli_url = "https://example.com/cli_linux_x64.tar.gz"

print(f"CLI: {cli_ver} -> {cli_url}")
print(f"Desktop: {desktop_ver} -> {desktop_url}")
print(f"IDE: {ide_ver} -> {ide_url}")

# Write antigravity.spec
spec_content = f"""
Name:           antigravity
Version:        {desktop_ver}
Release:        1%{{?dist}}
Summary:        Google Antigravity 2.0 (Wrapper)
License:        Proprietary
URL:            https://antigravity.google
BuildArch:      x86_64
AutoReqProv:    no
Requires:       glibc >= 2.28, curl, tar, gzip

%description
Google Antigravity 2.0 desktop application downloader.

%package cli
Summary:        Google Antigravity CLI (Wrapper)
Version:        {cli_ver}
AutoReqProv:    no
Requires:       curl, tar, gzip

%description cli
Google Antigravity CLI application downloader.

%package ide
Summary:        Google Antigravity IDE (Wrapper)
Version:        {ide_ver}
AutoReqProv:    no
Requires:       curl, tar, gzip

%description ide
Google Antigravity IDE application downloader.

%prep
# Nothing to unpack

%build
# Nothing to build

%install
rm -rf %{{buildroot}}
mkdir -p %{{buildroot}}/%{{_datadir}}/applications

# Desktop file
cat <<'DESKTOP' > %{{buildroot}}/%{{_datadir}}/applications/antigravity.desktop
[Desktop Entry]
Name=Antigravity 2.0
Exec=/opt/antigravity/antigravity %U
Terminal=false
Type=Application
Icon=antigravity
StartupWMClass=antigravity
Categories=Development;
DESKTOP

# IDE Desktop file
cat <<'DESKTOP' > %{{buildroot}}/%{{_datadir}}/applications/antigravity-ide.desktop
[Desktop Entry]
Name=Antigravity IDE
Exec=/opt/antigravity-ide/antigravity-ide %U
Terminal=false
Type=Application
Icon=antigravity-ide
StartupWMClass=antigravity-ide
Categories=Development;IDE;
DESKTOP

%post
mkdir -p /opt/antigravity
echo "Downloading Antigravity Desktop {desktop_ver}..."
curl -sL "{desktop_url}" | tar -xz -C /opt/antigravity --strip-components=1 || true
ln -sf /opt/antigravity/antigravity %{{_bindir}}/antigravity || true
if [ -f /opt/antigravity/antigravity.png ]; then
    cp /opt/antigravity/antigravity.png %{{_datadir}}/icons/hicolor/512x512/apps/antigravity.png || true
fi
gtk-update-icon-cache -f -t %{{_datadir}}/icons/hicolor || true

%preun
if [ $1 -eq 0 ]; then
    rm -rf /opt/antigravity
    rm -f %{{_bindir}}/antigravity
    rm -f %{{_datadir}}/icons/hicolor/512x512/apps/antigravity.png
fi

%post cli
mkdir -p /opt/antigravity-cli
echo "Downloading Antigravity CLI {cli_ver}..."
curl -sL "{cli_url}" | tar -xz -C /opt/antigravity-cli || true
ln -sf /opt/antigravity-cli/agy %{{_bindir}}/agy || true

%preun cli
if [ $1 -eq 0 ]; then
    rm -rf /opt/antigravity-cli
    rm -f %{{_bindir}}/agy
fi

%post ide
mkdir -p /opt/antigravity-ide
echo "Downloading Antigravity IDE {ide_ver}..."
curl -sL "{ide_url}" | tar -xz -C /opt/antigravity-ide --strip-components=1 || true
ln -sf /opt/antigravity-ide/antigravity-ide %{{_bindir}}/antigravity-ide || true
if [ -f /opt/antigravity-ide/antigravity-ide.png ]; then
    cp /opt/antigravity-ide/antigravity-ide.png %{{_datadir}}/icons/hicolor/512x512/apps/antigravity-ide.png || true
fi
gtk-update-icon-cache -f -t %{{_datadir}}/icons/hicolor || true

%preun ide
if [ $1 -eq 0 ]; then
    rm -rf /opt/antigravity-ide
    rm -f %{{_bindir}}/antigravity-ide
    rm -f %{{_datadir}}/icons/hicolor/512x512/apps/antigravity-ide.png
fi

%files
%{{_datadir}}/applications/antigravity.desktop

%files ide
%{{_datadir}}/applications/antigravity-ide.desktop

%files cli

%changelog
* Sun Jul 12 2026 gnpaone <gnpaone@users.noreply.github.com> - {desktop_ver}-1
- Automatic wrapper build
"""
with open(os.path.expanduser("~/rpmbuild/SPECS/antigravity.spec"), "w") as f:
    f.write(spec_content)
EOF

echo "Building wrapper RPMs..."
rpmbuild -bb ~/rpmbuild/SPECS/antigravity.spec

echo "Copying RPMs to repo directory..."
cp ~/rpmbuild/RPMS/x86_64/*.rpm public/repo/

echo "Done."

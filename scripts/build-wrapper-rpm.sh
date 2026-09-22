#!/usr/bin/env bash
set -euo pipefail

mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
mkdir -p public/repo

echo "Fetching existing RPMs from repository..."
python3 - <<'EOF_FETCH'
import urllib.request
import xml.etree.ElementTree as ET
import gzip
import os

repo_url = "https://gnpaone.github.io/agy-dnf/repo/"

try:
    repomd_url = repo_url + "repodata/repomd.xml"
    req = urllib.request.Request(repomd_url, headers={'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'})
    resp = urllib.request.urlopen(req)
    repomd_xml = resp.read()

    root = ET.fromstring(repomd_xml)
    ns = {'repo': 'http://linux.duke.edu/metadata/repo'}
    primary_location = root.find(".//repo:data[@type='primary']/repo:location", ns)
    if primary_location is not None:
        primary_href = primary_location.attrib['href']
        
        primary_url = repo_url + primary_href
        req = urllib.request.Request(primary_url, headers={'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'})
        resp = urllib.request.urlopen(req)
        primary_gz = resp.read()
        primary_xml = gzip.decompress(primary_gz)

        primary_root = ET.fromstring(primary_xml)
        common_ns = {'common': 'http://linux.duke.edu/metadata/common'}
        for location in primary_root.findall(".//common:location", common_ns):
            rpm_href = location.attrib['href']
            rpm_url = repo_url + rpm_href
            rpm_filename = os.path.basename(rpm_href)
            print(f"Downloading existing RPM: {rpm_filename}")
            try:
                urllib.request.urlretrieve(rpm_url, os.path.join("public/repo", rpm_filename))
            except Exception as e:
                print(f"Failed to download {rpm_url}: {e}")
except Exception as e:
    print(f"Could not fetch existing repository metadata (might be first run): {e}")
EOF_FETCH

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
    req = urllib.request.Request(cli_manifest_url, headers={'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'})
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
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'})
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
Release:        2%{{?dist}}
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
MimeType=x-scheme-handler/antigravity;
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
MimeType=x-scheme-handler/antigravity-ide;
DESKTOP

%post
mkdir -p /opt/antigravity
echo "Downloading Antigravity Desktop {desktop_ver}..."
curl -sL "{desktop_url}" | tar -xz -C /opt/antigravity --strip-components=1 || true
ln -sf /opt/antigravity/antigravity %{{_bindir}}/antigravity || true
mkdir -p %{{_datadir}}/icons/hicolor/512x512/apps
curl -sL "https://antigravity.google/apple-touch-icon.png" > %{{_datadir}}/icons/hicolor/512x512/apps/antigravity.png || true
gtk-update-icon-cache -f -t %{{_datadir}}/icons/hicolor || true
update-desktop-database %{{_datadir}}/applications &> /dev/null || :

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
ln -sf /opt/antigravity-cli/antigravity %{{_bindir}}/agy || true

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
mkdir -p %{{_datadir}}/icons/hicolor/512x512/apps
curl -sL "https://antigravity.google/apple-touch-icon.png" > %{{_datadir}}/icons/hicolor/512x512/apps/antigravity-ide.png || true
gtk-update-icon-cache -f -t %{{_datadir}}/icons/hicolor || true
update-desktop-database %{{_datadir}}/applications &> /dev/null || :

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
cp -n ~/rpmbuild/RPMS/x86_64/*.rpm public/repo/ || true

echo "Done."

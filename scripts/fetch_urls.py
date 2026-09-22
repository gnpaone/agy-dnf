import json
import re
import urllib.request
from urllib.parse import urljoin, unquote

def get_desktop_and_ide_urls():
    url = "https://antigravity.google/download"
    import gzip
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'})
    resp = urllib.request.urlopen(req)
    data = resp.read()
    if resp.info().get('Content-Encoding') == 'gzip':
        data = gzip.decompress(data)
    html = data.decode('utf-8', errors='replace')
    
    desktop_url = None
    ide_url = None

    m_desktop = re.search(r'https?://[^\s<>\)"\']*/linux-x64/Antigravity\.tar\.gz', html)
    if m_desktop:
        desktop_url = m_desktop.group(0)

    m_ide = re.search(r'https?://[^\s<>\)"\']*/linux-x64/Antigravity[^"\']*IDE\.tar\.gz', html)
    if m_ide:
        ide_url = m_ide.group(0)

    return desktop_url, ide_url

def get_cli_url():
    url = "https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json"
    data = json.loads(urllib.request.urlopen(url).read().decode('utf-8'))
    return data.get('url'), data.get('version')

def extract_version(url):
    decoded = unquote(url)
    for pattern in (r'/antigravity-hub/([^/]+)/', r'/stable/([^/]+)/', r'/(\d+\.\d+\.\d+(?:-[^/]+)?)/'):
        m = re.search(pattern, decoded)
        if m:
            return m.group(1).split('-', 1)[0]
    return 'unknown'

if __name__ == '__main__':
    desktop_url, ide_url = get_desktop_and_ide_urls()
    cli_url, cli_ver = get_cli_url()
    
    print(f"DESKTOP_URL={desktop_url}")
    print(f"DESKTOP_VER={extract_version(desktop_url)}")
    print(f"IDE_URL={ide_url}")
    print(f"IDE_VER={extract_version(ide_url)}")
    print(f"CLI_URL={cli_url}")
    print(f"CLI_VER={cli_ver}")

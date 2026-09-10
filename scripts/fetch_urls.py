import json
import re
import urllib.request
from urllib.parse import urljoin, unquote

def get_desktop_and_ide_urls():
    url = "https://antigravity.google/download"
    req = urllib.request.Request(url, headers={'Accept-Encoding': 'identity'})
    html = urllib.request.urlopen(req).read().decode('utf-8', errors='replace')
    
    matches = re.findall(r'(?:src|href)=["\']([^"\']*main-[^"\']+\.js)["\']', html)
    if not matches:
        matches = re.findall(r'(?:src|href)=["\']([^"\']+\.js)["\']', html)
    
    js_url = urljoin(url, matches[-1])
    js = urllib.request.urlopen(js_url).read().decode('utf-8', errors='replace')
    
    desktop_url = None
    ide_url = None
    
    start = js.find('id:"antigravity-2"')
    if start != -1:
        end = js.find('id:"antigravity-cli"', start)
        section = js[start:end if end != -1 else None]
        pattern = r'https?://[^"\'\s<>)]*/linux-x64/Antigravity\.tar\.gz'
        m = re.findall(pattern, section)
        if m:
            desktop_url = m[-1]
    
    start = js.find('id:"antigravity-ide"')
    if start != -1:
        end = js.find('id:"antigravity-sdk"', start)
        section = js[start:end if end != -1 else None]
        for filename_re in [r'Antigravity%20IDE\.tar\.gz', r'Antigravity\+IDE\.tar\.gz', r'Antigravity IDE\.tar\.gz']:
            pattern = r'https?://[^"\'\s<>)]*/linux-x64/' + filename_re
            m = re.findall(pattern, section)
            if m:
                ide_url = m[-1]
                break

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

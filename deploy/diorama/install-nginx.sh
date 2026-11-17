#!/usr/bin/env bash
set -euo pipefail

# Run on the Ubuntu server with sudo, after uploading dist and this directory.
[ "$(id -u)" -eq 0 ] || { echo 'Run this script with sudo.' >&2; exit 1; }
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
site=/etc/nginx/sites-available/aisilol.com
snippet=/etc/nginx/conf.d/includes/diorama.conf
app=/home/aisilol/diorama
include='    include /etc/nginx/conf.d/includes/diorama.conf;'
anchor='    include /etc/nginx/conf.d/includes/nginx-access-guard.conf;'

for required in "$site" "$script_dir/nginx.conf" "$app/dist/index.html"; do
    [ -f "$required" ] || { echo "Missing file: $required" >&2; exit 1; }
done

# Validate placement before changing any configuration.
python3 - "$site" "$include" "$anchor" <<'PY'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
include, anchor = sys.argv[2:]
if text.count(anchor) != 1 or text.count(include) > 1:
    raise SystemExit('Expected exactly one access-guard anchor and at most one diorama include.')
if 'include /etc/nginx/conf.d/includes/diorama.conf;' in text and include not in text:
    raise SystemExit('Existing diorama include has unexpected formatting; inspect manually.')
PY

if ! command -v setfacl >/dev/null || ! command -v getfacl >/dev/null; then
    apt-get update
    apt-get install -y acl
fi

backup="$(mktemp -d "$app/nginx-backup-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
chmod 700 "$backup"
cp -a "$site" "$backup/site.conf"
if [ -e "$snippet" ]; then
    cp -a "$snippet" "$backup/snippet.conf"
else
    touch "$backup/snippet-was-absent"
fi
getfacl -p /home/aisilol "$app" > "$backup/acl.txt"
getfacl -p -R "$app/dist" >> "$backup/acl.txt"
echo "Backup: $backup"

rollback() {
    local status=$?
    trap - ERR
    cp -a "$backup/site.conf" "$site"
    if [ -e "$backup/snippet-was-absent" ]; then
        rm -f -- "$snippet"
    else
        cp -a "$backup/snippet.conf" "$snippet"
    fi
    setfacl --restore="$backup/acl.txt" || true
    echo "Installation failed; configuration and ACLs restored from $backup. No further reload attempted." >&2
    exit "$status"
}
trap rollback ERR

install -m 644 "$script_dir/nginx.conf" "$snippet"
python3 - "$site" "$include" "$anchor" <<'PY'
import pathlib, sys
site = pathlib.Path(sys.argv[1])
text = site.read_text()
include, anchor = sys.argv[2:]
if include not in text:
    site.write_text(text.replace(anchor, include + '\n' + anchor, 1))
PY

# Only allow nginx to traverse the private home and read the deployed build.
setfacl -m u:www-data:--x /home/aisilol "$app"
find "$app/dist" -type d -exec setfacl -m u:www-data:r-x {} +
find "$app/dist" -type f -exec setfacl -m u:www-data:r-- {} +
runuser -u www-data -- test -r "$app/dist/index.html"
nginx -t
systemctl reload nginx
trap - ERR
echo 'Ready: https://aisilol.com/diorama/'

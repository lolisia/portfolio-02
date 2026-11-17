# Forest Farm web deployment

This deploys the Three.js web version at `https://aisilol.com/diorama/`.
It does not export or deploy the Godot version. nginx serves the production build
directly; no Node process is needed on the server.

Build locally from the repository root:

```bash
npm ci
npm run build:diorama -- --outDir .artifact/diorama-build
```

Upload the **contents** of `.artifact/diorama-build/` to
`/home/aisilol/diorama/dist/` and the files in this directory to
`/home/aisilol/diorama/deploy/`. Upload only these runtime and deployment files;
do not upload the repository, `node_modules`, Godot files, or private data.
Normal `npm run build` retains root-path deployment support.

On the Ubuntu server, run:

```bash
sudo bash /home/aisilol/diorama/deploy/install-nginx.sh
```

The installer requires the existing access-guard include in the HTTPS server
block as its unique insertion anchor. It backs up the site config, existing
snippet, and ACLs under `~/diorama/nginx-backup-*`, installs an idempotent include,
and gives `www-data` permission to traverse the home directory and read only the
deployed build. It installs Ubuntu's `acl` package if needed. It tests nginx
before reload and restores config/ACLs if installation fails.

Check `/diorama` redirects to `/diorama/`, then open the page and confirm both
models and the environment controls load. Missing assets return 404; there is no
SPA fallback and no domain-root `/models/` alias.

To roll back, use the exact backup directory printed by the installer:

```bash
sudo -i
backup=/home/aisilol/diorama/nginx-backup-REPLACE-WITH-PRINTED-NAME
cp -a "$backup/site.conf" /etc/nginx/sites-available/aisilol.com
if [ -e "$backup/snippet-was-absent" ]; then
    rm -f /etc/nginx/conf.d/includes/diorama.conf
else
    cp -a "$backup/snippet.conf" /etc/nginx/conf.d/includes/diorama.conf
fi
setfacl --restore="$backup/acl.txt"
nginx -t && systemctl reload nginx
exit
```

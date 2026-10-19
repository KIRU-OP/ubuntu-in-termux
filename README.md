# ubuntu-in-termux (DomCloud edition)

Install Ubuntu 22.04 (jammy) with **proot** on — no root needed.
The rootfs is downloaded from GitHub (proot-distro releases), because  blocks the Ubuntu mirrors.
Works on both `x86_64` and `aarch64` servers.

> ## ⚠️ IMPORTANT: Root access
>
> Running `~/ubuntu-domcloud/startubuntu.sh` gives you a **root user inside Ubuntu** (`whoami` → `root`, `id` → `uid=0`).
> This is **fake root** (proot), not real root on the DomCloud server.
>
> - ✅ No `sudo` needed inside Ubuntu: run `apt install ...` directly
> - ✅ Full control over the Ubuntu filesystem (`/etc`, `/usr`, `/root`)
> - ❌ No real root on the host: no systemd, Docker, firewall changes, or ports 80/443
>
> See the **Root access** section below for details.

## Deploy

Open the DomCloud **Webshell** (or SSH into your site) and run:

```bash
cd ~
git clone https://github.com/KIRU-OP/ubuntu-in-termux
cd ubuntu-in-termux
chmod +x ubuntu.sh
./ubuntu.sh -y
```

If the repo is already cloned, update it first:

```bash
cd ~/ubuntu-in-termux
git pull
chmod +x ubuntu.sh
./ubuntu.sh -y
```

## Start Ubuntu

```bash
~/ubuntu-domcloud/startubuntu.sh
```

Or, if `~/.local/bin` is in your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
startubuntu
```

Leave Ubuntu with `exit`.

## More ways to use `startubuntu.sh`

Run a single command without entering the shell:

```bash
~/ubuntu-domcloud/startubuntu.sh apt update
~/ubuntu-domcloud/startubuntu.sh "cat /etc/os-release"
```

Create a short alias so `ubuntu` opens the shell:

```bash
echo 'alias ubuntu="~/ubuntu-domcloud/startubuntu.sh"' >> ~/.bashrc
source ~/.bashrc
ubuntu
```

## Root access

Inside Ubuntu you get **fake root**, not real root. `startubuntu.sh` uses `proot -0`, so `whoami` shows `root`, but you are still your normal DomCloud user on the host.

**You can:**
- Install packages with `apt install` (Python, Node.js, git, nano, ...)
- Create, edit and delete files inside the Ubuntu filesystem
- Work freely in `/root` and any folder inside Ubuntu

**You cannot:**
- Change host system files or read other users' files
- Run real `systemd` services or change `iptables` / firewall rules
- Load kernel modules, mount filesystems, or bind to low ports (80, 443)
- Run Docker

Real root / `sudo` on the DomCloud host is not available on shared hosting. Use a VPS if you need it.

## First-time setup inside Ubuntu

If `apt update` shows `NO_PUBKEY` errors, run:

```bash
apt-get -o Acquire::AllowInsecureRepositories=true \
        -o Acquire::AllowDowngradeToInsecureRepositories=true update
apt-get install -y --allow-unauthenticated ubuntu-keyring
apt-get update && apt-get upgrade -y
```

Check the version:

```bash
cat /etc/os-release
```

## Deploy with the DomCloud YAML config (optional)

Paste this in your site's **Deploy / Config** section (replace `<your-username>` with your fork's owner):

```yaml
source: https://github.com/<your-username>/ubuntu-in-termux
commands:
  - chmod +x ubuntu.sh
  - ./ubuntu.sh -y
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `FATAL: kernel too old` | Edit `~/ubuntu-domcloud/startubuntu.sh` and remove the `#` before `command+=" -k 4.14.81"` |
| `xz` not found | Ask DomCloud support / use a plan that has `xz`, it is needed to extract the rootfs |
| Rootfs download fails | Check that `github.com` is reachable: `curl -sI https://github.com \| head -1` |
| proot error / ptrace blocked | DomCloud's container may block ptrace; proot cannot run there |
| Reinstall from scratch | `rm -rf ~/ubuntu-domcloud` and run `./ubuntu.sh -y` again |

## Notes

- Install location: `~/ubuntu-domcloud`
- Your DomCloud home is available inside Ubuntu at `/host-home`
- Long-running background processes may be killed by shared hosting; check DomCloud's terms of service for allowed usage.

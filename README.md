# ubuntu-in-termux (DomCloud edition)

Install Ubuntu 22.04 (jammy) with **proot** on — no root needed.
The rootfs is downloaded from GitHub (proot-distro releases), because  blocks the Ubuntu mirrors.
Works on both `x86_64` and `aarch64` servers.

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
- Your home is available inside Ubuntu at `/host-home`
- Long-running background processes may be killed by shared hosting; check DomCloud's terms of service for allowed usage.

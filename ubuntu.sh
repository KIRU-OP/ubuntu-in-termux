#!/bin/bash
# Ubuntu (proot) installer for DomCloud (my.domcloud.co)
# Rootless: proot ke through chalta hai, root access ki zarurat nahi.

set -u

BASE_DIR="$HOME/ubuntu-domcloud"
DIRECTORY="$BASE_DIR/ubuntu-fs"
BIN_DIR="$HOME/.local/bin"
PROOT_VERSION="v5.3.0"
UBUNTU_SERIES="22.04"      # jammy LTS
# DomCloud pe ubuntu mirrors blocked hain, GitHub khula hai:
# proot-distro ka Ubuntu 22.04 (jammy) rootfs GitHub releases se
PD_VERSION="v4.11.0"

log()  { printf "\x1b[38;5;214m[%s]\e[0m \x1b[38;5;83m[INFO]:\e[0m \x1b[38;5;87m %s\e[0m\n" "$(date +%r)" "$*"; }
warn() { printf "\x1b[38;5;214m[%s]\e[0m \x1b[38;5;227m[WARNING]:\e[0m \x1b[38;5;87m %s\e[0m\n" "$(date +%r)" "$*"; }
err()  { printf "\x1b[38;5;214m[%s]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m %s\e[0m\n" "$(date +%r)" "$*"; exit 1; }

# ---- downloader (curl ya wget) ----
fetch() { # fetch URL OUTPUT
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then wget -q "$1" -O "$2"
  else err "curl ya wget install nahi hai."; fi
}
fetch_stdout() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"
  else wget -qO- "$1"; fi
}

# ---- architecture ----
case "$(uname -m)" in
  x86_64|amd64)  ARCH=amd64; PROOT_ARCH=x86_64 ;;
  aarch64|arm64) ARCH=arm64; PROOT_ARCH=aarch64 ;;
  armv7l|armv8l) ARCH=armhf; PROOT_ARCH=arm ;;
  *) err "Unknown architecture: $(uname -m)" ;;
esac

# ---- apt fix: NO_PUBKEY 871920D1991BC93C (proot) ----
fix_apt_keys() {
  log "Ubuntu apt keyring fix ho raha hai..."
  local APT_DIR="$DIRECTORY/etc/apt"
  local KEYFILE="$DIRECTORY/usr/share/keyrings/ubuntu-archive-keyring.gpg"

  # 1. proot me apt ka _apt sandbox user key nahi padh pata
  mkdir -p "$APT_DIR/apt.conf.d"
  echo 'APT::Sandbox::User "root";' > "$APT_DIR/apt.conf.d/99proot"

  # 2. keyring file adhuri/missing ho to package host se laao aur rootfs me extract karo
  if [ ! -s "$KEYFILE" ]; then
    warn "Keyring file missing, ubuntu-keyring package laa raha hoon..."
    local B="http://ports.ubuntu.com/ubuntu-ports/pool/main/u/ubuntu-keyring/"
    local F
    F="$(fetch_stdout "$B" | grep -oE 'ubuntu-keyring_[0-9.]+_all\.deb' | sort -uV | tail -n1)"
    if [ -n "$F" ] && fetch "$B$F" "$BASE_DIR/$F"; then
      mkdir -p "$BASE_DIR/kr-tmp" && ( cd "$BASE_DIR/kr-tmp" && ar x "../$F" 2>/dev/null )
      if ls "$BASE_DIR"/kr-tmp/data.tar.* >/dev/null 2>&1; then
        tar -xf "$BASE_DIR"/kr-tmp/data.tar.* -C "$DIRECTORY" 2>/dev/null
      elif command -v dpkg-deb >/dev/null 2>&1; then
        dpkg-deb -x "$BASE_DIR/$F" "$DIRECTORY"
      fi
      rm -rf "$BASE_DIR/kr-tmp" "$BASE_DIR/$F"
    fi
  fi
  [ -s "$KEYFILE" ] || { warn "Keyring file ab bhi nahi mili."; return 1; }

  # 3. sources.list ko keyring file se bind karo (idempotent)
  if [ -f "$APT_DIR/sources.list" ] && ! grep -q 'signed-by=' "$APT_DIR/sources.list"; then
    cp "$APT_DIR/sources.list" "$APT_DIR/sources.list.bak"
    sed -i -E 's#^deb (\[[^]]*\] )?#deb [signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] #' "$APT_DIR/sources.list"
  fi

  # 4. verify
  "$BASE_DIR/startubuntu.sh" 'apt-get update' \
    && log "apt update sahi chal raha hai." \
    || warn "apt update abhi bhi fail. Output README ke Troubleshooting me bhejo."
}

install_ubuntu() {
  mkdir -p "$BASE_DIR" "$BIN_DIR" "$BASE_DIR/ubuntu-binds"
  cd "$BASE_DIR" || err "Directory nahi mili: $BASE_DIR"

  # ---- proot ----
  if command -v proot >/dev/null 2>&1; then
    PROOT_BIN="$(command -v proot)"
  else
    log "proot nahi mila, static binary download ho rahi hai..."
    PROOT_BIN="$BIN_DIR/proot"
    fetch "https://github.com/proot-me/proot/releases/download/${PROOT_VERSION}/proot-${PROOT_VERSION}-${PROOT_ARCH}-static" "$PROOT_BIN" \
      || err "proot download fail. Network/egress check karo."
    chmod +x "$PROOT_BIN"
  fi
  log "proot: $PROOT_BIN"

  # ---- rootfs ----
  if [ -d "$DIRECTORY/bin" ] || [ -d "$DIRECTORY/usr" ]; then
    warn "Rootfs pehle se hai, download aur extraction skip."
  else
    ROOTFS_URL="https://github.com/termux/proot-distro/releases/download/${PD_VERSION}/ubuntu-jammy-${PROOT_ARCH}-pd-${PD_VERSION}.tar.xz"
    log "Downloading Ubuntu 22.04 rootfs (${PROOT_ARCH}) from GitHub..."
    rm -f ubuntu.tar.xz
    fetch "$ROOTFS_URL" ubuntu.tar.xz || err "Rootfs download fail: $ROOTFS_URL"
    command -v xz >/dev/null 2>&1 || err "xz install nahi hai (tar -J ke liye zaruri)."

    mkdir -p "$DIRECTORY"
    log "Extracting rootfs..."
    "$PROOT_BIN" --link2symlink tar -xJf ubuntu.tar.xz -C "$DIRECTORY" --strip-components=1 --exclude='dev' || :
    [ -x "$DIRECTORY/bin/bash" ] || err "Extraction fail."
    log "Rootfs extract ho gaya."

    log "DNS fix (resolv.conf)..."
    printf "nameserver 8.8.8.8\nnameserver 8.8.4.4\n" > "$DIRECTORY/etc/resolv.conf"

    log "Stubs likh raha hoon..."
    printf '#!/bin/sh\nexit\n' > "$DIRECTORY/usr/bin/groups"
    chmod +x "$DIRECTORY/usr/bin/groups"

    rm -f ubuntu.tar.xz
  fi

  # ---- start script ----
  log "Start script ban raha hai..."
  cat > "$BASE_DIR/startubuntu.sh" <<EOM
#!/bin/bash
cd "\$(dirname "\$0")"
unset LD_PRELOAD
command="$PROOT_BIN"
# 'FATAL: kernel too old' aaye to neeche wali line uncomment karo
#command+=" -k 4.14.81"
command+=" --link2symlink"
command+=" -0"
command+=" -r ubuntu-fs"
if [ -n "\$(ls -A ubuntu-binds 2>/dev/null)" ]; then
  for f in ubuntu-binds/*; do . "\$f"; done
fi
command+=" -b /dev"
command+=" -b /proc"
command+=" -b /sys"
command+=" -b ubuntu-fs/tmp:/dev/shm"
command+=" -b $HOME:/host-home"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=\${TERM:-xterm-256color}"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"
if [ -z "\$1" ]; then
  exec \$command
else
  \$command -c "\$*"
fi
EOM
  chmod +x "$BASE_DIR/startubuntu.sh"
  ln -sf "$BASE_DIR/startubuntu.sh" "$BIN_DIR/startubuntu"

  fix_apt_keys

  log "Install complete! Launch: $BASE_DIR/startubuntu.sh  (ya: startubuntu)"
  log "Agar 'startubuntu' na mile to: export PATH=\"\$HOME/.local/bin:\$PATH\""
}

case "${1:-}" in
  -y) install_ubuntu ;;
  "")
    printf "\x1b[38;5;214m[%s]\e[0m \x1b[38;5;127m[QUESTION]:\e[0m \x1b[38;5;87m Ubuntu install karna hai? [Y/n] \e[0m" "$(date +%r)"
    read -r ans
    case "$ans" in ""|y|Y) install_ubuntu ;; *) err "Installation aborted." ;; esac
    ;;
  *) err "Usage: $0 [-y]" ;;
esac

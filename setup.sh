#!/usr/bin/env bash
# =====================================================================
#  Tuan's dev computer setup — Kubuntu, Fedora + macOS
#  Follows "SOP — New or Reset Development Computer Setup" §2–§6.
#
#  Run it:      bash setup.sh            (installs what's missing)
#  Check only:  bash setup.sh --check    (changes nothing, just reports)
#
#  Safe to run again: anything already installed is skipped.
#  It never replaces system Python, never copies secrets, never
#  touches repositories (that is §9, done by hand).
# =====================================================================
set -uo pipefail

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

GIT_NAME="Tuan Le"
VSCODE_EXTENSIONS=(ms-python.python ms-python.vscode-pylance ms-python.debugpy)

# ---------- helpers ----------
bold() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
todo() { printf '  \033[33m•\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✘\033[0m %s\n' "$*"; FAILURES+=("$*"); }
has()  { command -v "$1" >/dev/null 2>&1; }
# Read from the keyboard even when the script is piped from curl.
ask()  { local reply; read -r -p "  $1 " reply </dev/tty || reply=""; printf '%s' "$reply"; }
FAILURES=()

case "$(uname -s)" in
  Linux)  OS=linux ;;
  Darwin) OS=mac ;;
  *) echo "Unsupported OS. On Windows use setup.ps1."; exit 1 ;;
esac

# Linux package manager: apt (Kubuntu/Ubuntu) or dnf (Fedora)
PKG=""
if [[ $OS == linux ]]; then
  if has apt-get; then PKG=apt
  elif has dnf; then PKG=dnf
  else echo "This script supports Kubuntu/Ubuntu (apt) and Fedora (dnf). Stopping."; exit 1; fi
fi
pkg_install() {
  if [[ $PKG == apt ]]; then sudo apt-get install -y "$@"; else sudo dnf install -y "$@"; fi
}

echo "Tuan's setup launcher — $OS${PKG:+ ($PKG)} — $( $CHECK_ONLY && echo 'CHECK ONLY' || echo 'INSTALL MISSING' )"

# Ask for the admin password once up front (Linux) so the rest runs smoothly.
if ! $CHECK_ONLY && [[ $OS == linux ]]; then sudo -v || exit 1; fi

# =====================================================================
# §2  OS updates
# =====================================================================
bold "§2 OS updates"
if $CHECK_ONLY; then
  todo "Skipped in --check mode"
elif [[ $PKG == apt ]]; then
  sudo apt-get update && sudo apt-get upgrade -y && ok "APT packages up to date" || fail "apt upgrade"
  [[ -f /var/run/reboot-required ]] && todo "A RESTART is required — finish this script, then restart."
  todo "Also check Discover → Updates for Flatpak/Snap apps."
elif [[ $PKG == dnf ]]; then
  sudo dnf upgrade -y --refresh && ok "DNF packages up to date" || fail "dnf upgrade"
  # needs-restarting exits 1 when a restart is needed (0 = not needed).
  if sudo dnf needs-restarting -r >/dev/null 2>&1; then :
  elif [[ $? -eq 1 ]]; then todo "A RESTART is required — finish this script, then restart."; fi
  todo "Also check Discover / GNOME Software → Updates for Flatpak apps."
else
  softwareupdate --list 2>&1 | sed 's/^/    /'
  if [[ "$(ask 'Install all Apple updates listed above now? [y/N]')" =~ ^[Yy] ]]; then
    sudo softwareupdate --install --all || todo "Finish in System Settings → General → Software Update"
  else
    todo "Skipped Apple updates — run later from System Settings."
  fi
fi

# =====================================================================
# macOS: Homebrew (also installs Xcode Command Line Tools → Git)
# =====================================================================
if [[ $OS == mac ]]; then
  bold "Homebrew"
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x $p ]] && eval "$($p shellenv)"
  done
  if has brew; then ok "Homebrew $(brew --version | head -1)"
  elif $CHECK_ONLY; then todo "Homebrew missing"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
    for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [[ -x $p ]] && eval "$($p shellenv)" && BREW_PATH=$p
    done
    if has brew; then
      # Put brew on PATH for future Terminal windows (the installer's "Next steps").
      LINE="eval \"\$(${BREW_PATH} shellenv)\""
      grep -qsF "$LINE" ~/.zprofile || echo "$LINE" >> ~/.zprofile
      ok "Homebrew installed"
    else fail "Homebrew install"; fi
  fi
fi

# =====================================================================
# §2  Chrome
# =====================================================================
bold "§2 Chrome"
chrome_present() {
  [[ $OS == mac ]] && [[ -d "/Applications/Google Chrome.app" ]] && return 0
  has google-chrome || has google-chrome-stable
}
if chrome_present; then ok "Chrome installed"
elif $CHECK_ONLY; then todo "Chrome missing"
elif [[ $PKG == dnf ]]; then
  if [[ "$(uname -m)" == x86_64 ]]; then
    # Google's .rpm also adds its repo so dnf keeps Chrome updated.
    sudo dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm \
      && ok "Chrome installed" || fail "Chrome install"
  else fail "Chrome .rpm is x86_64-only; install manually"; fi
elif [[ $PKG == apt ]]; then
  if [[ "$(dpkg --print-architecture)" == amd64 ]]; then
    tmp=$(mktemp -d)
    wget -qO "$tmp/chrome.deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
      && sudo apt-get install -y "$tmp/chrome.deb" && ok "Chrome installed" || fail "Chrome install"
    rm -rf "$tmp"
  else fail "Chrome .deb is amd64-only; install manually"; fi
else
  brew install --cask google-chrome && ok "Chrome installed" || fail "Chrome install"
fi

# =====================================================================
# §3  Git
# =====================================================================
bold "§3 Git"
if has git && git --version >/dev/null 2>&1; then ok "$(git --version)"
elif $CHECK_ONLY; then todo "Git missing"
elif [[ $OS == linux ]]; then
  pkg_install git && ok "$(git --version)" || fail "Git install"
else
  # Homebrew installs the Command Line Tools, which include Git.
  xcode-select -p >/dev/null 2>&1 || xcode-select --install
  has git && git --version >/dev/null 2>&1 && ok "$(git --version)" \
    || fail "Git — finish the Command Line Tools pop-up, then re-run"
fi

# =====================================================================
# §3  Python  (Kubuntu/Fedora: packaged python3 · Mac: Homebrew python@3.13)
# =====================================================================
bold "§3 Python"
if [[ $OS == linux ]]; then
  if has python3 && python3 -m pip --version >/dev/null 2>&1 && python3 -c 'import venv, ensurepip' 2>/dev/null; then
    ok "$(python3 --version), $(python3 -m pip --version | cut -d' ' -f1-2)"
  elif $CHECK_ONLY; then todo "python3 / pip / venv incomplete"
  else
    # Fedora's python3 already includes venv; Kubuntu needs python3-venv.
    if [[ $PKG == apt ]]; then pkg_install python3 python3-venv python3-pip
    else pkg_install python3 python3-pip; fi \
      && ok "$(python3 --version)" || fail "Python install"
  fi
  PY=python3
else
  if has python3.13; then ok "$(python3.13 --version)"
  elif $CHECK_ONLY; then todo "python3.13 missing"
  else brew install python@3.13 && ok "$(python3.13 --version)" || fail "Python 3.13 install"; fi
  PY=python3.13
fi

# =====================================================================
# §3  VS Code + Python extensions
# =====================================================================
bold "§3 VS Code"
MAC_CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
[[ $OS == mac && -d "$MAC_CODE" ]] && export PATH="$PATH:$MAC_CODE"
if has code; then ok "VS Code $(code --version | head -1)"
elif $CHECK_ONLY; then todo "VS Code missing"
elif [[ $PKG == dnf ]]; then
  # Microsoft's official Fedora/RHEL repo, so dnf keeps VS Code updated.
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  printf '%s\n' "[code]" "name=Visual Studio Code" \
    "baseurl=https://packages.microsoft.com/yumrepos/vscode" "enabled=1" "autorefresh=1" \
    "type=rpm-md" "gpgcheck=1" "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" \
    | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
  pkg_install code && ok "VS Code installed" || fail "VS Code install"
elif [[ $PKG == apt ]]; then
  tmp=$(mktemp -d)
  # The official .deb also adds Microsoft's repo so Discover/apt keep it updated.
  echo "code code/add-microsoft-repo boolean true" | sudo debconf-set-selections
  wget -qO "$tmp/code.deb" "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" \
    && sudo apt-get install -y "$tmp/code.deb" && ok "VS Code installed" || fail "VS Code install"
  rm -rf "$tmp"
else
  brew install --cask visual-studio-code && export PATH="$PATH:$MAC_CODE" \
    && ok "VS Code installed" || fail "VS Code install"
fi

if has code; then
  installed=$(code --list-extensions 2>/dev/null)
  for ext in "${VSCODE_EXTENSIONS[@]}"; do
    if grep -qix "$ext" <<<"$installed"; then ok "extension $ext"
    elif $CHECK_ONLY; then todo "extension $ext missing"
    else code --install-extension "$ext" --force >/dev/null && ok "extension $ext installed" || fail "extension $ext"; fi
  done
fi

# =====================================================================
# §4  Git identity
# =====================================================================
bold "§4 Git identity"
if has git; then
  if $CHECK_ONLY; then
    for k in user.name user.email init.defaultBranch; do
      v=$(git config --global --get $k) && ok "$k = $v" || todo "$k not set"
    done
  else
    git config --global user.name "$GIT_NAME"
    git config --global init.defaultBranch main
    if ! git config --global --get user.email >/dev/null; then
      echo "  GitHub → Settings → Emails: copy your verified or noreply address."
      email=$(ask "Paste GitHub email (Enter to skip):")
      [[ -n $email ]] && git config --global user.email "$email"
    fi
    for k in user.name user.email init.defaultBranch; do
      v=$(git config --global --get $k) && ok "$k = $v" || todo "$k not set — re-run later"
    done
  fi
fi

# =====================================================================
# §5  Disposable Python check
# =====================================================================
bold "§5 Python check"
if has "$PY"; then
  out=$("$PY" -c 'print("Tuan'"'"'s Python setup is working.")' 2>&1) && ok "$out" || fail "Python test: $out"
  if ! $CHECK_ONLY; then
    mkdir -p "$HOME/setup-check"
    [[ -f "$HOME/setup-check/hello.py" ]] || echo 'print("Tuan'"'"'s Python setup is working.")' > "$HOME/setup-check/hello.py"
    todo "Open ~/setup-check in VS Code → Python: Select Interpreter → Run hello.py"
  fi
fi

# =====================================================================
# §6  Inventory snapshot (same contents as the SOP's §6 block)
# =====================================================================
if ! $CHECK_ONLY; then
  bold "§6 Computer inventory report"
  report="$HOME/computer-inventory-$(date +%Y%m%d-%H%M%S).txt"
  {
    echo "COMPUTER SETUP SNAPSHOT"; date
    if [[ $OS == linux ]]; then
      echo "Hostname: $(hostname)"; echo "=== OS ==="; cat /etc/os-release; uname -r
      echo "=== Manufacturer / model / BIOS ==="
      for f in sys_vendor product_name product_version bios_version; do
        [[ -r /sys/class/dmi/id/$f ]] && printf '%s: %s\n' "$f" "$(cat /sys/class/dmi/id/$f)"
      done
      echo "=== CPU ==="; lscpu; echo "=== Memory ==="; free -h
      echo "=== Physical drives ==="; lsblk -d -e 7 -o NAME,MODEL,SIZE,TRAN
    else
      echo "Hostname: $(scutil --get LocalHostName)"; echo "=== OS ==="; sw_vers; uname -m
      echo "=== Hardware ==="; system_profiler SPHardwareDataType SPDisplaysDataType SPStorageDataType
    fi
    echo "=== Git ===";     has git && git --version || echo "Git not found"
    echo "=== Python ==="; has "$PY" && { "$PY" --version; "$PY" -m pip --version; } || echo "$PY not found"
    echo "=== VS Code ==="; has code && code --version || echo "code command not found"
    echo "=== Manual checks ==="
    echo "Setup status: TO CONFIRM"
    echo "Unresolved issues: ${FAILURES[*]:-None found by script}"
    echo "Chrome / Dashlane / settings sync / Python sample / backup restore: TO CONFIRM"
  } > "$report" 2>&1
  ok "Saved report: $report"
fi

# =====================================================================
# Summary + things only a human can do
# =====================================================================
bold "Summary"
if ((${#FAILURES[@]})); then
  for f in "${FAILURES[@]}"; do fail "$f"; done
  echo "  Fix the items above and run this script again."
elif $CHECK_ONLY; then
  ok "Check complete — any • items above get fixed by running without --check."
else
  ok "Everything the script can do is done."
fi

cat <<'EOF'

  Still yours to do by hand (sign-ins can't be scripted):
  [ ] Chrome: sign into your profile, review sync choices
  [ ] Install Dashlane extension → sign in → test a fill   https://www.dashlane.com/download
  [ ] In Chrome sign into GitHub (tunaflyby), ChatGPT, Claude, Notion, Drive, Dropbox
  [ ] VS Code → Accounts → Backup and Sync Settings → sign in with GitHub tunaflyby
  [ ] Run ~/setup-check/hello.py in VS Code (Select Interpreter first)
  [ ] Attach the computer-inventory-*.txt report to this computer's Notion Assets record
EOF

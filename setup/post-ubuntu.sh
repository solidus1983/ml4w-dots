#!/usr/bin/env bash

repo_path="${repo_path:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

[ -d "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin"

# --------------------------------------------------------------
# Systemd service guards — Hyprland-only
# Prevents Hyprland-specific user services from starting under
# GNOME and triggering Failed Units Monitor notifications.
# --------------------------------------------------------------

for _svc in hypridle hyprsunset swaync hyprpaper waybar; do
    _dropin="$HOME/.config/systemd/user/${_svc}.service.d"
    mkdir -p "$_dropin"
    cat > "$_dropin/hyprland-only.conf" <<EOF
[Unit]
ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland
EOF
done

# snapd-desktop-integration: the stable channel version fails at the
# GDM greeter and under some Wayland sessions. Switching to the
# candidate channel resolves this. The service is then conditioned to
# GNOME only so it does not start under Hyprland.
if command -v snap &>/dev/null; then
    echo ":: DO NOT PANIC: Fixing snapd-desktop-integration — this resolves the"
    echo ":: 'Failed Units' error shown on the GDM login screen. Please wait..."
    sleep 5
    sudo snap remove snapd-desktop-integration 2>/dev/null || true
    sudo snap install snapd-desktop-integration --channel=candidate 2>/dev/null || true
fi

systemctl --user mask snapd-desktop-integration 2>/dev/null || true

_snap_svc="snap.snapd-desktop-integration.snapd-desktop-integration.service"
mkdir -p "$HOME/.config/systemd/user/${_snap_svc}.d"
cat > "$HOME/.config/systemd/user/${_snap_svc}.d/gnome-only.conf" <<EOF
[Unit]
ConditionEnvironment=XDG_CURRENT_DESKTOP=ubuntu:GNOME
EOF

systemctl --user daemon-reload 2>/dev/null || true

# --------------------------------------------------------------
# XDG Desktop Portal routing
# --------------------------------------------------------------

sudo mkdir -p /usr/share/xdg-desktop-portal
sudo tee /usr/share/xdg-desktop-portal/hyprland-portals.conf > /dev/null <<'EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.Secret=gnome-keyring
EOF
sudo tee /usr/share/xdg-desktop-portal/gnome-portals.conf > /dev/null <<'EOF'
[preferred]
default=gnome;gtk
org.freedesktop.impl.portal.Secret=gnome-keyring
EOF

# --------------------------------------------------------------
# Fastfetch
# --------------------------------------------------------------

if ! command -v fastfetch &>/dev/null; then
    FASTFETCH_DEB=$(mktemp -t fastfetch-XXXXXX.deb)
    curl -L "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb" \
        -o "$FASTFETCH_DEB"
    sudo dpkg -i "$FASTFETCH_DEB"
    rm -f "$FASTFETCH_DEB"
fi

# --------------------------------------------------------------
# Oh My Posh
# --------------------------------------------------------------

if ! command -v oh-my-posh &>/dev/null; then
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
fi

# --------------------------------------------------------------
# ML4W Settings App
# --------------------------------------------------------------

if ! command -v gum &>/dev/null; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key \
        | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
        | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt-get update
    sudo apt-get install -y gum
fi

if [ ! -d "$HOME/.local/share/ml4w-dotfiles-settings" ]; then
    ML4W_SETTINGS_TMP=$(mktemp -d -t ml4w-settings-XXXXXX)
    git clone --depth=1 https://github.com/mylinuxforwork/ml4w-dotfiles-settings.git "$ML4W_SETTINGS_TMP"
    (cd "$ML4W_SETTINGS_TMP" && make install)
    rm -rf "$ML4W_SETTINGS_TMP"
fi

# --------------------------------------------------------------
# Rust / Cargo
# --------------------------------------------------------------

if ! command -v cargo &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    source "$HOME/.cargo/env"
elif ! source "$HOME/.cargo/env" 2>/dev/null; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# --------------------------------------------------------------
# awww (Wayland wallpaper daemon — replaces swww)
# --------------------------------------------------------------

if ! command -v awww &>/dev/null; then
    sudo apt-get install -y liblz4-1 liblz4-dev pkg-config ninja-build
    cargo install --git https://codeberg.org/LGFae/awww awww awww-daemon --locked
    sudo cp "$HOME/.cargo/bin/awww" /usr/local/bin/awww
    sudo cp "$HOME/.cargo/bin/awww-daemon" /usr/local/bin/awww-daemon
    echo ":: awww has been installed successfully."
fi

# --------------------------------------------------------------
# Cargo — matugen
# --------------------------------------------------------------

TARGET_VERSION="4.0.0"

force_install_matugen() {
    echo "Running: cargo install matugen --force"
    cargo install matugen --force
}

if ! command -v matugen &>/dev/null; then
    echo "'matugen' is not currently installed."
    force_install_matugen
else
    CURRENT_VERSION=$(matugen --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    LOWEST_VERSION=$(printf "%s\n%s" "$TARGET_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)
    if [ "$LOWEST_VERSION" = "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" != "$TARGET_VERSION" ]; then
        echo "Current version ($CURRENT_VERSION) is lower than $TARGET_VERSION. Updating..."
        force_install_matugen
    else
        echo "matugen is already up to date! (Current version: $CURRENT_VERSION)"
    fi
fi

# --------------------------------------------------------------
# Quickshell (build from source — pinned to v0.2.1)
# --------------------------------------------------------------

if ! command -v qs &>/dev/null; then
QS_SRC="$HOME/Downloads/quickshell-src"

sudo apt-get install -y \
    cmake ninja-build pkg-config \
    qt6-base-dev \
    qt6-declarative-dev \
    qt6-declarative-private-dev \
    qt6-shadertools-dev \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    qt6-svg-dev \
    libqt6svg6-dev \
    libwayland-dev \
    libwayland-bin \
    libegl1-mesa-dev \
    wayland-protocols \
    libxkbcommon-dev \
    libvulkan-dev \
    libdrm-dev \
    libgbm-dev \
    libpipewire-0.3-dev \
    libpam0g-dev \
    libglib2.0-dev \
    libpolkit-gobject-1-dev \
    libpolkit-agent-1-dev \
    libjemalloc-dev \
    libunwind-dev \
    libdwarf-dev \
    libxcb1-dev \
    libcli11-dev \
    zlib1g-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    spirv-tools \
    qml6-module-qtqml \
    qml6-module-qtqml-models \
    qml6-module-qtqml-workerscript \
    qml6-module-qtquick \
    qml6-module-qtquick-templates \
    qml6-module-qtquick-effects \
    qml6-module-qtquick-shapes \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qt-labs-qmlmodels \
    qml6-module-qt5compat-graphicaleffects

mkdir -p "$HOME/Downloads"
if [ -d "$QS_SRC" ]; then
    rm -rf "$QS_SRC"
fi

git clone --depth=1 --branch v0.2.1 https://github.com/quickshell-mirror/quickshell "$QS_SRC"
cmake -S "$QS_SRC" -B "$QS_SRC/build" \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DVENDOR_CPPTRACE=ON \
    -DCRASH_REPORTER=OFF
cmake --build "$QS_SRC/build"
sudo cmake --install "$QS_SRC/build"
rm -rf "$QS_SRC"
echo ":: Quickshell has been installed successfully."
fi

# --------------------------------------------------------------
# nwg-dock-hyprland (Go build; falls back to apt-installed version)
# --------------------------------------------------------------

if ! command -v nwg-dock-hyprland &>/dev/null; then
    sudo apt-get install -y \
        libgtk-4-dev \
        libgtk-3-dev \
        libgtk-layer-shell-dev \
        libglib2.0-dev \
        libgirepository1.0-dev \
        gir1.2-gtk-3.0
    if command -v go &>/dev/null; then
        NWG_DOCK_SRC=$(mktemp -d -t nwg-dock-XXXXXX)
        git clone --depth=1 https://github.com/nwg-piotr/nwg-dock-hyprland "$NWG_DOCK_SRC"
        (cd "$NWG_DOCK_SRC" && make get && make build && sudo make install)
        rm -rf "$NWG_DOCK_SRC"
        echo ":: nwg-dock-hyprland installed."
    else
        echo ":: Go not available; using apt-installed nwg-dock-hyprland"
    fi
fi

# --------------------------------------------------------------
# nwg-look (clone + make; falls back to apt-installed version)
# xcur2png built from source — not available in Ubuntu repos
# --------------------------------------------------------------

if ! command -v xcur2png &>/dev/null; then
    sudo apt-get install -y \
        libpng-dev \
        libx11-dev \
        libxcursor-dev \
        autoconf \
        automake
    XCUR_SRC=$(mktemp -d -t xcur2png-XXXXXX)
    git clone --depth=1 https://github.com/eworm-de/xcur2png "$XCUR_SRC"
    (cd "$XCUR_SRC" && autoreconf -fi && ./configure --prefix=/usr/local CFLAGS="-Wno-error=implicit-int -Wno-implicit-int" && make && sudo make install)
    rm -rf "$XCUR_SRC"
fi

if ! command -v nwg-look &>/dev/null; then
    if command -v go &>/dev/null; then
        NWG_LOOK_SRC=$(mktemp -d -t nwg-look-XXXXXX)
        git clone --depth=1 https://github.com/nwg-piotr/nwg-look "$NWG_LOOK_SRC"
        (cd "$NWG_LOOK_SRC" && make build && sudo make install)
        rm -rf "$NWG_LOOK_SRC"
        echo ":: nwg-look installed."
    else
        echo ":: Go not available; using apt-installed nwg-look"
    fi
fi

# --------------------------------------------------------------
# Walker (app launcher — Rust/GTK4)
# --------------------------------------------------------------

if ! command -v walker &>/dev/null; then
    sudo apt-get install -y \
        protobuf-compiler \
        libpoppler-glib-dev \
        libgtk4-layer-shell-dev
    WALKER_SRC=$(mktemp -d -t walker-XXXXXX)
    git clone --depth=1 https://github.com/abenz1267/walker "$WALKER_SRC"
    (cd "$WALKER_SRC" && cargo build --release)
    sudo cp "$WALKER_SRC/target/release/walker" /usr/local/bin/walker
    rm -rf "$WALKER_SRC"
    echo ":: Walker installed."
fi

# --------------------------------------------------------------
# Elephant (walker's provider daemon — Go)
# --------------------------------------------------------------

if ! command -v elephant &>/dev/null; then
    ELEPHANT_SRC=$(mktemp -d -t elephant-XXXXXX)
    git clone --depth=1 https://github.com/abenz1267/elephant "$ELEPHANT_SRC"

    mkdir -p "$HOME/go/bin"
    (cd "$ELEPHANT_SRC/cmd/elephant" && go build -o "$HOME/go/bin/elephant" .)
    sudo cp "$HOME/go/bin/elephant" /usr/local/bin/elephant

    mkdir -p "$HOME/.config/elephant/providers"
    for _pdir in "$ELEPHANT_SRC/internal/providers"/*/; do
        _provider=$(basename "$_pdir")
        (cd "$_pdir" && go build -buildmode=plugin \
            -o "$HOME/.config/elephant/providers/${_provider}.so" . 2>/dev/null) || true
    done

    elephant service enable 2>/dev/null || true
    rm -rf "$ELEPHANT_SRC"
    echo ":: Elephant and providers installed."
fi

# --------------------------------------------------------------
# Grimblast
# --------------------------------------------------------------

sudo cp $repo_path/setup/scripts/grimblast /usr/bin

# --------------------------------------------------------------
# Pip
# --------------------------------------------------------------

sudo apt-get install -y python3-pip
sudo apt-get install -y pipx || python3 -m pip install --user pipx
export PATH="$HOME/.local/bin:$PATH"

sudo apt-get install -y \
    libgirepository-2.0-dev \
    libcairo2-dev \
    python3-dev \
    pkg-config

pipx install pywalfox
pipx install waypaper
pipx ensurepath

# --------------------------------------------------------------
# Cursors
# --------------------------------------------------------------

source $repo_path/setup/_cursors.sh

# --------------------------------------------------------------
# Fonts
# --------------------------------------------------------------

source $repo_path/setup/_fonts.sh

FA_VER="${FONT_AWESOME_VERSION:-7.1.0}"
FA_DEST="/usr/share/fonts/font-awesome-7"
if [ ! -d "$FA_DEST" ]; then
    FA_TMP=$(mktemp -d)
    if curl -fsSL -o "$FA_TMP/fa.zip" \
        "https://github.com/FortAwesome/Font-Awesome/releases/download/${FA_VER}/fontawesome-free-${FA_VER}-desktop.zip"; then
        (cd "$FA_TMP" && unzip -q fa.zip)
        sudo mkdir -p "$FA_DEST"
        sudo cp "$FA_TMP/fontawesome-free-${FA_VER}-desktop/otfs/"*.otf "$FA_DEST/"
    else
        echo ":: WARNING: Failed to download Font Awesome ${FA_VER}; waybar icons may not render."
    fi
    rm -rf "$FA_TMP"
fi

# Remove hyprpaper — conflicts with awww under uwsm
sudo apt-get remove -y hyprpaper 2>/dev/null || true

sudo fc-cache -fv

# --------------------------------------------------------------
# Icons
# --------------------------------------------------------------

source $repo_path/setup/_icons.sh

# --------------------------------------------------------------
# Create XDG Directories
# --------------------------------------------------------------

xdg-user-dirs-update

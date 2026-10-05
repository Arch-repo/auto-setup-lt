#!/usr/bin/env bash
set -euo pipefail


# Variables
#----------------------------
# Color variables
GREEN="\e[32m"
WHITE="\e[0m"
YELLOW="\e[33m"
BLUE="\e[34m"
#----------------------------

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/Arch-repo/dotfiles.git}"
AUTO_SETUP_RAW_URL="${AUTO_SETUP_RAW_URL:-https://raw.githubusercontent.com/Arch-repo/auto-setup-lt/main}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P || pwd)"

install_neofetch_random() {
    local target="$HOME/neofetch-random.sh"
    local local_script="$SCRIPT_DIR/neofetch-random.sh"
    local logo_target="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/ascii-logo.txt"
    local local_logo="$SCRIPT_DIR/fastfetch/ascii-logo.txt"

    if [[ -f "$local_script" ]]; then
        install -m 755 "$local_script" "$target"
    else
        curl -fSL "$AUTO_SETUP_RAW_URL/neofetch-random.sh" -o "$target"
        chmod +x "$target"
    fi

    mkdir -p "$(dirname "$logo_target")"
    if [[ -f "$local_logo" ]]; then
        install -m 644 "$local_logo" "$logo_target"
    else
        curl -fSL "$AUTO_SETUP_RAW_URL/fastfetch/ascii-logo.txt" -o "$logo_target" || true
    fi

    clear_fastfetch_neofetch_cache
}

clear_fastfetch_neofetch_cache() {
    local source_dir="${ANTO426_NEOFETCH_DIR:-$HOME/Pictures/neofetch}"
    local cache_home cache_dir

    [[ "$source_dir" == /* && "$source_dir" != "/" ]] || return 0

    for cache_home in "$HOME/.cache" "${XDG_CACHE_HOME:-}"; do
        [[ -n "$cache_home" ]] || continue
        cache_dir="$cache_home/fastfetch/images$source_dir"
        [[ "$cache_dir" == "$cache_home/fastfetch/images/"* ]] || continue
        rm -rf "$cache_dir"
    done
}

clone_or_update() {
    local repo="$1"
    local target="$2"

    if [[ -d "$target/.git" ]]; then
        local current_remote
        current_remote="$(git -C "$target" remote get-url origin 2>/dev/null || true)"

        if [[ "$current_remote" == "$repo" ]]; then
            git -C "$target" pull --ff-only || true
        else
            local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
            mv "$target" "$backup"
            echo -e "${BLUE}[NOTE]${GREEN} ==> Existing $target remote differs, moved to $backup"
            git clone --depth=1 "$repo" "$target"
        fi
    elif [[ -e "$target" ]]; then
        local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
        mv "$target" "$backup"
        echo -e "${BLUE}[NOTE]${GREEN} ==> Existing $target moved to $backup"
        git clone --depth=1 "$repo" "$target"
    else
        git clone --depth=1 "$repo" "$target"
    fi
}

apt_install_available() {
    local available=()
    local package

    for package in "$@"; do
        if apt-cache show "$package" >/dev/null 2>&1; then
            available+=("$package")
        else
            echo -e "${BLUE}[NOTE]${GREEN} ==> APT package not available, skipping: $package"
        fi
    done

    ((${#available[@]} == 0)) || sudo apt install -y "${available[@]}"
}

install_pwndbg() {
    if [[ -d "$HOME/pwndbg/.git" ]]; then
        git -C "$HOME/pwndbg" pull --ff-only || true
    else
        clone_or_update https://github.com/pwndbg/pwndbg "$HOME/pwndbg"
    fi

    (
        cd "$HOME/pwndbg"
        ./setup.sh
    )
}


# Welcome message
echo -e "
                    ${GREEN}\e[1mWELCOME!${GREEN} 
    Now we will customize Debian-based Terminal
             Created by \e[1;4manto426
${WHITE}"

cd ~



# Updating system packages
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[1/7]${GREEN} ==> Updating system packages\n---------------------------------------------------------------------\n${WHITE}"

# Remove deadsnakes
sudo rm -f /etc/apt/sources.list.d/*deadsnakes*.list

sudo apt update && sudo apt upgrade -y

# Download some terminal tool
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[2/7]${GREEN} ==> Download some terminal tool\n---------------------------------------------------------------------\n${WHITE}"
sudo apt install -y build-essential git curl wget jq ca-certificates
pkgs=(
    # System monitoring and fun terminal visuals
    btop cmatrix cbonsai cowsay

    # Essential utilities
    make curl wget unzip jq fuse3 dpkg ripgrep fd-find
    fzf eza zoxide tmux stow command-not-found

    # CTF tools
    exiftool gdb ascii ltrace strace checksec patchelf upx-ucl binwalk

    # Programming languages
    python3 python3-pip nodejs npm ruby ruby-dev golang

    # Shell & customization
    zsh
)
apt_install_available "${pkgs[@]}"


# Install fastfetch
sudo wget https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb -O fastfetch.deb
sudo dpkg -i fastfetch.deb
rm -rf ~/fastfetch.deb


# Install fzf
git clone --depth=1 https://github.com/junegunn/fzf.git
cd fzf
./install --bin
sudo mv ~/fzf/bin/fzf /usr/local/bin
cd ~
rm -rf fzf


# Install bat
sudo wget $(curl -s https://api.github.com/repos/sharkdp/bat/releases/latest | jq -r '.assets[] | select(.name | test("bat_.*amd64.deb")) | .browser_download_url') -O bat.deb
sudo dpkg -i bat.deb
rm -rf bat.deb


# Install neovim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
chmod u+x nvim-linux-x86_64.appimage
sudo mv nvim-linux-x86_64.appimage /usr/local/bin/nvim


# Install pipes.sh
git clone --depth=1 https://github.com/pipeseroni/pipes.sh.git
cd pipes.sh
sudo make install
cd ..
rm -rf pipes.sh
cd ~


# Fastfetch random images are handled by ~/neofetch-random.sh.


# Install oh-my-posh
sudo wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O /usr/local/bin/oh-my-posh
sudo chmod +x /usr/local/bin/oh-my-posh


# Install pwninit
sudo wget https://github.com/io12/pwninit/releases/latest/download/pwninit -O /usr/bin/pwninit
sudo chmod +x /usr/bin/pwninit


# Download pwndbg and pwntools
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[4/7]${GREEN} ==> Download pwndbg and pwntools\n---------------------------------------------------------------------\n${WHITE}"
install_pwndbg
sudo gem install one_gadget


# Download file config
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[5/7]${GREEN} ==> Download file config\n---------------------------------------------------------------------\n${WHITE}"
clone_or_update "$DOTFILES_REPO" "$HOME/dotfiles"
clone_or_update https://github.com/tmux-plugins/tpm "$HOME/dotfiles/.tmux/plugins/tpm"
install_neofetch_random


# Stow
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[6/7]${GREEN} ==> Stow\n---------------------------------------------------------------------\n${WHITE}"
cd ~/dotfiles
chmod +x ./.config/anto426/*.sh ./.config/anto426/wallpaper_effects.d/*.sh 2>/dev/null || true
./.config/anto426/backup_config.sh
stow -t ~ .
cd ~
if [[ -x "$HOME/.config/anto426/remote_sync.sh" ]]; then
    ANTO426_SYNC_QUIET=1 "$HOME/.config/anto426/remote_sync.sh" init || true
fi


# Change terminam
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[7/7]${GREEN} ==> Change shell\n---------------------------------------------------------------------\n${WHITE}"
ZSH_PATH="$(which zsh)"
grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
chsh -s "$ZSH_PATH" "$USER" || echo -e "${BLUE}[NOTE]${GREEN} ==> Could not change shell automatically. Run: chsh -s $ZSH_PATH"


echo -e "\n ${GREEN}
 **************************************************
 *                    \e[1;4mDone\e[0m${GREEN}!!!                     *
 *       Please relogin to apply new config.      *
 **************************************************
 
"

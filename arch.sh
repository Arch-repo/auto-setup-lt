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
AUTO_SETUP_EMBEDDED="${AUTO_SETUP_EMBEDDED:-0}"
AUTO_SETUP_RUN_DOTFILES_INSTALLER="${AUTO_SETUP_RUN_DOTFILES_INSTALLER:-0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P || pwd)"

is_enabled() {
    case "${1,,}" in
        1 | true | yes | on) return 0 ;;
        *) return 1 ;;
    esac
}

is_embedded() {
    is_enabled "$AUTO_SETUP_EMBEDDED"
}

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

install_yay() {
    if command -v yay >/dev/null 2>&1; then
        return 0
    fi

    local build_dir
    build_dir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
    (
        cd "$build_dir/yay"
        makepkg -si --noconfirm
    )
    rm -rf "$build_dir"
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

install_dotfiles_dependencies() {
    local installer="$HOME/dotfiles/.config/anto426/install_archpkg.sh"

    if [[ "${AUTO_SETUP_SKIP_DOTFILES_INSTALLER:-0}" == "1" ]]; then
        echo -e "${BLUE}[NOTE]${GREEN} ==> Skipping full dotfiles package installer."
        return 0
    fi

    if [[ ! -f "$installer" ]]; then
        echo -e "${BLUE}[NOTE]${GREEN} ==> Dotfiles installer not found: $installer"
        return 0
    fi

    chmod +x "$installer"
    "$installer"
}

# Welcome message
echo -e "
                    ${GREEN}\e[1mWELCOME!${GREEN} 
    Now we will customize Arch-based Terminal
             Created by \e[1;4manto426
${WHITE}"

cd ~

# Updating the system
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[1/10]${GREEN} ==> Updating system packages\n---------------------------------------------------------------------\n${WHITE}"
if is_embedded; then
    echo -e "${BLUE}[NOTE]${GREEN} ==> Embedded mode: system update is handled by the parent installer."
else
    sudo pacman -Syu --noconfirm
fi


# Setting locale 
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[2/10]${GREEN} ==> Setting locale \n---------------------------------------------------------------------\n${WHITE}"
sudo sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
sudo locale-gen
sudo localectl set-locale LANG=en_US.UTF-8


# Download some terminal tool
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[3/10]${GREEN} ==> Download some terminal tool\n---------------------------------------------------------------------\n${WHITE}"
sudo pacman -S --noconfirm --needed base-devel git
install_yay


pacman_packages=(
    # System monitoring and fun terminal visuals
    btop cmatrix cowsay fastfetch

    # Essential utilities
    make curl wget unzip dpkg ripgrep fd man openssh openbsd-netcat
    fzf eza bat zoxide neovim tmux stow
    lazydocker lazygit

    # CTF tools
    perl-image-exiftool gdb ascii ltrace strace checksec patchelf upx binwalk

    # Programming languages
    python python-pip nodejs npm ruby go

    # Shell & customization
    zsh
)
aur_packages=(
    # System monitoring and fun terminal visuals
    cbonsai pipes.sh oh-my-posh

    # CTF tools
    pwninit
)


# Download pacman packages
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[4/10]${GREEN} ==> Download pacman packages\n---------------------------------------------------------------------\n${WHITE}"
sudo pacman -S --needed --noconfirm "${pacman_packages[@]}"


# Download yay packages
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[5/10]${GREEN} ==> Download yay packages\n---------------------------------------------------------------------\n${WHITE}"
yay -S --needed --noconfirm "${aur_packages[@]}"


# Download pwndbg and pwntools
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[6/10]${GREEN} ==> Download pwndbg and pwntools\n---------------------------------------------------------------------\n${WHITE}"
install_pwndbg
sudo gem install one_gadget


# Download file config
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[7/10]${GREEN} ==> Download file config\n---------------------------------------------------------------------\n${WHITE}"
install_neofetch_random
if is_embedded; then
    echo -e "${BLUE}[NOTE]${GREEN} ==> Embedded mode: dotfiles clone is handled by the parent installer."
else
    clone_or_update "$DOTFILES_REPO" "$HOME/dotfiles"
    clone_or_update https://github.com/tmux-plugins/tpm "$HOME/dotfiles/.tmux/plugins/tpm"
fi


# Install complete dotfiles package set
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[8/10]${GREEN} ==> Dotfiles package handoff\n---------------------------------------------------------------------\n${WHITE}"
if is_embedded; then
    echo -e "${BLUE}[NOTE]${GREEN} ==> Embedded mode: dotfiles packages are handled by the parent installer."
elif is_enabled "$AUTO_SETUP_RUN_DOTFILES_INSTALLER"; then
    install_dotfiles_dependencies
else
    echo -e "${BLUE}[NOTE]${GREEN} ==> Skipping full dotfiles package installer."
    echo -e "${BLUE}[NOTE]${GREEN} ==> Run ~/.config/anto426/install_archpkg.sh or use Arch-Hyprland for the full desktop flow."
fi
 

# Stow
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[9/10]${GREEN} ==> Stow\n---------------------------------------------------------------------\n${WHITE}"
if is_embedded; then
    echo -e "${BLUE}[NOTE]${GREEN} ==> Embedded mode: stow is handled by the parent installer."
else
    cd ~/dotfiles
    chmod +x ./.config/anto426/*.sh ./.config/anto426/wallpaper_effects.d/*.sh 2>/dev/null || true
    ./.config/anto426/backup_config.sh
    stow -t ~ .
    cd ~
    if [[ -x "$HOME/.config/anto426/remote_sync.sh" ]]; then
        ANTO426_SYNC_QUIET=1 "$HOME/.config/anto426/remote_sync.sh" init || true
    fi
fi


# Change shell
echo -e "${GREEN}\n---------------------------------------------------------------------\n${YELLOW}[10/10]${GREEN} ==> Change shell\n---------------------------------------------------------------------\n${WHITE}"
ZSH_PATH="$(which zsh)"
grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
chsh -s "$ZSH_PATH" "$USER" || echo -e "${BLUE}[NOTE]${GREEN} ==> Could not change shell automatically. Run: chsh -s $ZSH_PATH"


echo -e "\n ${GREEN}
 **************************************************
 *                    \e[1;4mDone\e[0m${GREEN}!!!                     *
 *       Please relogin to apply new config.      *
 **************************************************
 
"

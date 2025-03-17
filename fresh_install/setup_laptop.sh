#!/bin/bash
# Setup fresh Ubuntu laptop
# Install: sh -c "$(curl -fsSL setup.ricardochaves.pt)"

# TODO: Setup Waterfox extensions, bookmarks

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

c_red() {
    echo -e "${RED}$1${NC}"
}

c_green() {
    echo -e "${GREEN}$1${NC}"
}

c_yellow() {
    echo -e "${YELLOW}$1${NC}"
}

c_blue() {
    echo -e "${BLUE}$1${NC}"
}

VAULT_URL=""
SECRETS_DIR=""

init() {
    sudo apt update
    sudo apt upgrade
}

is_setup_done() {
    if which terminator >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

fix_vim() {
    c_yellow "Fixing vim"
    sudo apt -y remove vim vim-common
    sudo apt -y autoremove
    sudo apt clean
}

configure_gnome_dock() {
    gset() {
        schema="org.gnome.shell.extensions.dash-to-dock"
        key=$1
        val=$2

        gsettings set $schema $key $val
    }

    gset autohide true
    gset dock-fixed false
    gset dock-position 'BOTTOM'
    gset extend-height false
    gset multi-monitor true
    gset show-mounts false
    gset show-mounts-network false
    gset show-mounts-only-mounted true
    gset show-trash false
}

configure_gnome_general() {
    c_yellow "Configuring GNOME appearance"
    gsettings set org.gnome.desktop.interface clock-show-seconds true
    gsettings set org.gnome.shell favorite-apps "['slack_slack.desktop', 'spotify_spotify.desktop', 'code_code.desktop', 'waterfox.desktop', 'thunderbird.desktop']"
    gsettings set org.gnome.shell.extensions.ding show-home false
    gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
    xdg-settings set default-web-browser waterfox.desktop
}

setup_apt() {
    pkgs="curl vim git terminator meld jq bat lm-sensors htop moreutils cpufrequtils python3-pip picocom sshpass tree ffmpeg wireguard cmake xclip iw wireshark libfuse2 libportaudio2 pulseaudio-utils"
    to_install=""
    for pkg in $pkgs; do
        c_blue "Checking if $pkg is installed"
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            to_install="$to_install $pkg"
        fi
    done
    if [ -z "$to_install" ]; then
        c_green "All apt packages are already installed"
        return
    fi

    # Trim leading and trailing whitespaces using sed
    to_install=$(echo "$to_install" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    c_yellow "Installing missing apt packages [$to_install]"
    sudo apt install -y $to_install
    sudo apt -y autoremove
}

setup_code() {
    c_blue "Installing code"
    mkdir -p "$HOME/.vscode"
    cp -r "$SECRETS_DIR/vscode/*" "$HOME/.vscode"
    sudo snap install --classic code
}

setup_snap() {
    c_yellow "Installing snap packages"
    pkgs="slack spotify discord vlc"
    to_install=""
    check_whats_installed() {
        for pkg in $pkgs; do
            c_blue "Checking if $pkg is installed"
            if ! snap list | grep -q "^${pkg} "; then
                to_install="$to_install $pkg"
            fi
        done
        if ! snap list | grep -q "code"; then
            setup_code
        fi
    }

    check_whats_installed
    if [ -z "$to_install" ]; then
        c_green "All snap packages are already installed"
        return
    fi

    c_yellow "Installing missing snap packages [$to_install]"
    sudo snap install $to_install
}

setup_pip_packages() {
    pkgs="spyql matplotlib"
    pip install $pkgs
}

setup_docker() {
    if which docker >/dev/null 2>&1; then
        c_green "Docker is already installed"
        return
    fi
    c_yellow "Installing docker"
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -y -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose
    sudo usermod -aG docker $USER
    newgrp docker
}

setup_aws() {
    c_yellow "Installing AWS CLI"
    if ! which aws >/dev/null 2>&1; then
        pushd "$(mktemp -d)" || return
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install
        rm -rf aws awscliv2.zip
        popd || return
    fi
}

setup_zsh() {
    c_yellow "Installing oh-my-zsh"
    if which zsh >/dev/null 2>&1; then
        c_green "zsh is already installed"
        return
    fi
    sudo apt install -y zsh
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    c_yellow "Installing zsh plugins"

    pushd $HOME/.oh-my-zsh/custom/plugins || return
    cp -r "$SECRETS_DIR/oh-my-zsh/custom/plugins/*" .
    popd || return
}

setup_secrets() {
    c_yellow "Downloading secrets"
    read -p "Enter the vault URL [user@remote]: " VAULT_URL
    SECRETS_DIR=$(mktemp -d)
    pushd "$SECRETS_DIR" || return
    # Compress and download the secrets; faster than scp or rsync
    ssh -p 23 "$VAULT_URL" "tar czf - -C ~/.secrets_vault ." | tar xzf - -C .
    popd || return

    source "$SECRETS_DIR/config.sh"

    cp -r "$SECRETS_DIR/nexar" ~/.nexar
}

setup_ssh() {
    c_yellow "Setting up SSH keys"
    ssh_dir="$HOME/.ssh"
    mkdir -p "$ssh_dir"
    cp -r "$SECRETS_DIR/ssh/*" "$ssh_dir"
    find "$ssh_dir" -name "*.pub" | sed 's/\.pub//g' | while IFS= read -r key; do
        chmod 700 "$key"
        ssh-add "$key"
    done
}

setup_wireguard() {
    c_yellow "Setting up Wireguard"
    sudo cp "$SECRETS_DIR/wireguard/wg0.conf" /etc/wireguard/
}

configure_custom_app() {
    app_name=$1

    c_yellow "Configuring $app_name"
    config_dir="$HOME/.local/share/applications"
    remote_config="https://raw.githubusercontent.com/ricardocchaves/nursery/master/fresh_install/applications/$app_name.desktop"
    mkdir -p "$config_dir"
    wget "$remote_config" > "$config_dir/$app_name.desktop"
    chmod +x "$HOME/$app_name.desktop"
}

setup_waterfox() {
    if waterfox --version >/dev/null 2>&1; then
        c_green "Waterfox is already installed"
        return
    fi

    c_yellow "Installing Waterfox"
    pushd "$(mktemp -d)" || return
    wget https://cdn1.waterfox.net/waterfox/releases/G6.0.17/Linux_x86_64/waterfox-G6.0.17.tar.bz2
    tar -xvf waterfox-G6.0.17.tar.bz2
    sudo mv waterfox /opt
    sudo ln -s /opt/waterfox/waterfox /usr/bin/waterfox
    popd || return

    # TODO: Use native icon without downloading
    mkdir -p ~/.local/share/icons/
    curl https://www.waterfox.net/_astro/waterfox.aA4DFn78.svg > ~/.local/share/icons/waterfox.ico

    configure_custom_app waterfox
}

setup_thunderbird() {
    if thunderbird --version >/dev/null 2>&1; then
        c_green "Thunderbird is already installed"
        return
    fi

    c_yellow "Installing thunderbird"
    pushd "$(mktemp -d)" || return
    wget https://download-installer.cdn.mozilla.net/pub/thunderbird/releases/128.7.1esr/linux-x86_64/en-US/thunderbird-128.7.1esr.tar.bz2
    tar -xvf thunderbird*.tar.bz2
    sudo mv thunderbird /opt
    sudo ln -s /opt/thunderbird/thunderbird /usr/bin/thunderbird
    popd || return

    configure_custom_app thunderbird
}

setup_delta() {
    if which delta 2>&1; then
        c_green "Delta is already installed"
	return
    fi

    pushd "$(mktemp -d)" || return
    wget https://github.com/dandavison/delta/releases/download/0.17.0/git-delta_0.17.0_amd64.deb
    sudo dpkg -i git-delta_0.17.0_amd64.deb
    rm git-delta_0.17.0_amd64.deb
    popd || return
}

download_config() {
    config_path="$1"
    app_name=$(echo "$config_path" | cut -d'/' -f1)
    config_file=$(echo "$config_path" | cut -d'/' -f2)

    c_blue "Configuring $app_name"
    config_dir="$HOME/.config/$app_name"
    remote_config="https://raw.githubusercontent.com/ricardocchaves/nursery/master/fresh_install/config/$config_path"
    mkdir -p "$config_dir"
    wget "$remote_config" -O "$config_dir/$config_file"
}

setup_obsidian() {
    if obsidian --version >/dev/null 2>&1 || ls Applications | grep "Obsidian" ; then
        c_green "Obsidian is already installed"
        return
    fi

    c_yellow "Installing Obsidian"
    pushd "$(mktemp -d)" || return
    repo="obsidianmd/obsidian-releases"
    latest_release=$(curl --silent "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name)
    appimage="Obsidian-${latest_release//v/}.AppImage"
    wget "https://github.com/$repo/releases/download/$latest_release/$appimage"
    chmod +x "$appimage"
    ./"$appimage"
    popd || return

    download_config "obsidian/obsidian.json"
}

setup_audacity() {
    if which audacity >/dev/null 2>&1; then
        c_green "Audacity is already installed"
        return
    fi

    c_yellow "Installing Audacity"
    pushd "$(mktemp -d)" || return
    sudo add-apt-repository -y ppa:ubuntuhandbook1/audacity
    sudo apt install -y audacity
    popd || return
}

setup_appimagelauncher() {
    if which AppImageLauncher 2>&1; then
        c_green "AppImageLaunched is already installed"
	return
    fi

    c_yellow "Installing app-image-launcher"
    pushd "$(mktemp -d)" || return
    repo="TheAssassin/AppImageLauncher"
    wget "https://github.com/$repo/releases/download/v2.2.0/appimagelauncher_2.2.0-travis995.0f91801.bionic_amd64.deb"
    sudo dpkg -i appimage*.deb
    popd || return
}

setup_manual_apps() {
    c_yellow "Configuring manual apps"
    setup_appimagelauncher
    setup_waterfox
    setup_thunderbird
    setup_delta
    setup_obsidian
    setup_audacity
    sudo gtk-update-icon-cache /usr/share/icons/hicolor
    sudo update-desktop-database
}

download_home_scripts() {
    c_yellow "Downloading HOME scripts"

    # Get the list of files in the folder
    files=$(curl -s "https://api.github.com/repos/ricardocchaves/nursery/contents/script_dump" | jq -r '.[] | select(.type=="file") | .download_url')

    # Use wget to download each file
    for file in $files; do
	fname="$(basename "$file")"
	if ls $HOME | grep $fname -q; then
	    c_green "$fname already downloaded"
	    continue
	fi
        wget "$file" -P "$HOME"
        chmod +x "$HOME/$fname"
    done
}

install_custom_scripts() {
    c_yellow "Downloading custom scripts"

    # Get the list of files in the folder
    files=$(curl -s "https://api.github.com/repos/ricardocchaves/nursery/contents/script_global" | jq -r '.[] | select(.type=="file") | .download_url')

    dest_dir="$(mktemp -d)"
    # Use wget to download each file
    for file in $files; do
	    fname="$(basename "$file")"
        wget "$file" -P "$dest_dir"
        chmod +x "$dest_dir/$fname"
        sudo mv "$dest_dir/$fname" /usr/local/bin/
    done
}

setup_terminator() {
    c_yellow "Configuring Terminator"

    # Download fonts
    pushd "$(mktemp -d)" || return
    git clone https://github.com/powerline/fonts.git --depth=1
    pushd fonts || return
    ./install.sh
    popd || return
    rm -rf fonts
    popd || return

    download_config "terminator/config"
}

setup_git_repos() {
    c_yellow "Cloning git repositories"
    apply_personal_git_config() {
        repo=$1
        pushd $repo || return
        git config --local user.name "Ricardo Chaves"
        git config --local user.email "ricardochaves@ua.pt"
        git config --local core.sshCommand "ssh -i ~/.ssh/ricardochaves_ua"
        popd || return
    }
    clone_n1() {
        repo="nexar_n1"
        if [ -d "$repo" ]; then
            c_green "$repo is already cloned"
            return
        fi

        c_blue "Cloning $repo and derivatives"
        git clone git@github.com:getnexar/$repo.git

        cp -r $repo "$NX_REPO_1"
        git -C "$NX_REPO_1" checkout "$NX_REPO_1_BRANCH"

        cp -r $repo "$NX_REPO_2"
        git -C "$NX_REPO_2" checkout "$NX_REPO_2_BRANCH"

        git -C $repo submodule update --init nexar-client-sdk
        git -C $repo/nexar-client-sdk submodule update --init external

        cp -r $repo "$NX_REPO_3"
        git -C "$NX_REPO_3" checkout "$NX_REPO_3_BRANCH"
        git -C "$NX_REPO_3" submodule update --init nexar-client-sdk

        c_blue "Configuring podman"
        pushd "$NX_REPO_3" || return
        ./tools/PodmanInstaller.sh
        popd || return

        c_blue "Installing dev scripts"
        pushd $repo/nexar-client-sdk/tools/development || return
        ./install.sh
        popd || return
    }
    clone_nexar() {
        repos="$NX_REPO_4"
        for repo in $repos; do
            if [ -d "$repo" ]; then
                c_green "$repo is already cloned"
                continue
            fi

            git clone git@github.com:getnexar/$repo.git
        done
    }
    clone_others() {
        clone_urls="git@github.com:ricardocchaves/nursery.git rchaves-ua:ricardocchaves/notes.git rchaves-ua:ricardocchaves/home_configs.git"
        for url in $clone_urls; do
            repo=$(basename $url .git)
            # Custom named repos
            if [ "$repo" == "nursery" ]; then
                repo="nursery_personal"
            fi

            if [ -d "$repo" ]; then
                c_green "$repo is already cloned"
                continue
            fi

            git clone $url
            if [ "$repo" == "nursery_personal" ]; then
                mv nursery nursery_personal
            elif [ "$repo" == "home_configs" ]; then
                bash "$HOME/repos/home_configs/dotfiles/setup.sh"
            fi
            apply_personal_git_config $repo
        done
    }
    mkdir -p ~/repos
    pushd ~/repos || return
    clone_n1
    clone_nexar
    clone_others
    popd || return
}

setup_vpn() {
    vpn_dir="$HOME/vpn"
    mkdir -p $vpn_dir
    cp -r "$SECRETS_DIR/vpn/*" "$vpn_dir"
}

setup_obsidian_notes() {
    c_yellow "Setting up Obsidian notes"
    vault_repo="$HOME/repos/notes/obsidian"
    vault_dir="$HOME/Documents/ObsidianVault"
    if [ -d "$vault_dir" ]; then
        c_green "Obsidian notes are already setup"
        return
    fi

    ln -s "$vault_repo" "$vault_dir"
    c_blue "Configuring Obsidian sync"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ricardocchaves/nursery/master/services/create_obsidianSync.sh)"
}

setup_vdoodle() {
    c_yellow "Setting up vdoodle"
    if cloud-vehicle -h >/dev/null 2>&1; then
        c_green "vdoodle tools are already installed"
        return
    fi

    mkdir -p "$HOME/.veniam"

    cp -r "$SECRETS_DIR/veniam/*" "$HOME/$(dirname "$VNM_CRED")"
    if [ ! -f "$HOME/$VNM_CRED" ]; then
        c_red "Please create ~/$VNM_CRED"
        return
    fi

    vpn_pid=0
    if ! wget -q --spider --timeout=1 --tries=1 "$VNM_PYPI_URL"; then
        c_blue "Starting dev VPN in the background"
        sudo openvpn --config ~/vpn/dev_ricardochaves.ovpn &
        vpn_pid=$!
    fi

    sudo apt install -y liblzo2-dev
    if ! wget -q --spider --timeout=2 --tries=5 "$VNM_PYPI_URL"; then
        c_red "Enable dev VPN to access $VNM_PYPI"
        return
    fi

    pip config --user set global.index-url "$VNM_PYPI_URL"
    pip config --user set global.trusted-host "$VNM_PYPI"

    pip install wget
    pip install vdoodle

    if [ $vpn_pid -ne 0 ]; then
        c_blue "Stopping dev VPN"
        sudo killall openvpn
    fi
}

setup_ambausb() {	
    source /tmp/tmp.0upMPi4U2v/config.sh
    if which ambausb >/dev/null 2>&1; then
        c_green "AmbaUSB is already installed"
        return
    fi

    c_yellow "Setting up AmbaUSB"
    ambausb_repo="$HOME/repos/$NX_REPO_3"
    deb_path="$ambausb_repo/$NX_AMBAUSB_DEB"
    sudo apt install libqt5multimedia5 # Dependencies
    sudo dpkg -i "$deb_path"

    download_config "Ambarella/ambausb.conf"
}

setup_swap() {
    if zfs list | grep -q swap; then
        return
    fi
    c_yellow "Setting up swap"
    sudo zfs create -V 16G -o compression=zle \
      -o logbias=throughput -o sync=standard \
      -o primarycache=metadata -o secondarycache=none \
      -o com.sun:auto-snapshot=false rpool/swap
    sudo mkswap -f /dev/zvol/rpool/swap
    sudo bash -c "echo /dev/zvol/rpool/swap none swap defaults 0 0 >> /etc/fstab"
    sudo swapon -av
}

# In the Lenovo laptop, there are power-supply issues that freeze the system. So we need to set these flags.
setup_grub() {
    c_yellow "Setting up GRUB"
    sudo sed -i 's/GRUB_CMDLINE_LINUX_=""/GRUB_CMDLINE_LINUX="intel_idle.max_cstate=3 ahci.mobile_lpm_policy=1"/g' /etc/default/grub
    sudo update-grub
}

c_yellow "Starting laptop setup"
if ! is_setup_done; then
    init
    fix_vim
fi

setup_apt
setup_snap
setup_docker
setup_secrets
setup_aws
setup_zsh
setup_ssh
setup_wireguard
setup_manual_apps
download_home_scripts
install_custom_scripts
setup_terminator
configure_gnome_general
configure_gnome_dock
setup_git_repos
setup_obsidian_notes
setup_vdoodle
setup_ambausb
#setup_swap
#setup_grub

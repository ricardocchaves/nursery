#!/bin/bash
# Setup fresh Ubuntu laptop
# Install: sh -c "$(curl -fsSL setup.ricardochaves.pt)"

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
}

setup_apt() {
    pkgs="curl vim git terminator meld jq bat lm-sensors htop moreutils cpufrequtils"
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
    sudo apt install -y "$to_install"
    sudo apt -y autoremove
}

setup_snap() {
    c_yellow "Installing snap packages"
    pkgs="slack spotify"
    to_install=""
    check_whats_installed() {
        for pkg in $pkgs; do
            c_blue "Checking if $pkg is installed"
            if ! snap list | grep -q "^${pkg} "; then
                to_install="$to_install $pkg"
            fi
        done
        if ! snap list | grep -q "code"; then
            sudo snap install --classic code
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
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker $USER
    newgrp docker
    sudo docker run hello-world
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
}

setup_ssh() {
    c_yellow "Setting up existing SSH keys"
    keys="id_ed25519 id_rsa id_tuning nexar_ed25519 ricardochaves_ua"
    for key in $keys; do
        key_path="$HOME/.ssh/$key"
        if [ ! -f "$key_path" ]; then
            c_red "$key not found"
            continue
        fi
        chmod 700 "$key_path"
        ssh-add "$key_path"
    done
}

setup_waterfox() {
    if ! waterfox --version >/dev/null 2>&1; then
        c_yellow "Installing Waterfox"
        pushd "$(mktemp -d)" || return
        wget https://cdn1.waterfox.net/waterfox/releases/G6.0.17/Linux_x86_64/waterfox-G6.0.17.tar.bz2
        tar -xvf waterfox-G6.0.17.tar.bz2
        sudo mv waterfox /opt
        sudo ln -s /opt/waterfox/waterfox /usr/bin/waterfox
        popd || return

        mkdir -p ~/.local/share/icons/
        curl https://www.waterfox.net/_astro/waterfox.aA4DFn78.svg -O ~/.local/share/icons/waterfox.ico
        cat > ~/.local/share/applications/waterfox.desktop <<EOL
[Desktop Entry]
Name=Waterfox
GenericName=Web Browser
Comment=Browse the World Wide Web
Exec=waterfox
Terminal=false
Type=Application
Icon=~/.local/share/icons/waterfox.ico
Categories=Network;WebBrowser;
EOL
    chmod +x ~/.local/share/applications/waterfox.desktop
    fi
}

setup_thunderbird() {
    if ! thunderbird --version >/dev/null 2>&1; then
        c_red "Install thunderbird manually!"
        return
    fi

    c_yellow "Configuring Thunderbird"
    icon_path="/opt/thunderbird-115.3.3/thunderbird/chrome/icons/default/default256.png"
    cat > ~/.local/share/applications/thunderbird.desktop <<EOL
[Desktop Entry]
Name=Thunderbird
GenericName=Mail Client
Comment=Send and receive mail with Thunderbird
Exec=thunderbird
Terminal=false
Type=Application
Icon=$icon_path
Categories=Network;Email;
StartupWMClass=Thunderbird
EOL
    chmod +x ~/.local/share/applications/thunderbird.desktop
}

setup_delta() {
    pushd $(mktemp -d) || return
    wget https://github.com/dandavison/delta/releases/download/0.17.0/git-delta_0.17.0_amd64.deb
    sudo dpkg -i git-delta_0.17.0_amd64.deb
    rm git-delta_0.17.0_amd64.deb
    popd || return
}

setup_manual_apps() {
    c_yellow "Configuring manual apps"
    setup_waterfox
    setup_thunderbird
    setup_delta
    sudo gtk-update-icon-cache /usr/share/icons/hicolor
    sudo update-desktop-database
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

    # Configure Terminator
    config_dir="$HOME/.config/terminator"
    remote_config="https://raw.githubusercontent.com/ricardocchaves/nursery/master/fresh_install/config/terminator/config"
    mkdir -p "$config_dir"
    wget "$remote_config" -O "$config_dir/config"
}

setup_git_repos() {
    c_yellow "Cloning git repositories"
    clone_n1() {
        repo="nexar_n1"
        if [ -d "$repo" ]; then
            c_green "$repo is already cloned"
            return
        fi

        git clone git@github.com:getnexar/$repo.git
        cp -r $repo nexar_vanilla
        cp -r $repo nexar_fw0
        git -C $repo submodule update --init nexar-client-sdk
        git -C $repo/nexar-client-sdk submodule update --init external
        cp -r $repo nexar_b0
    }
    clone_nexar() {
        repos="veniam-nexar-os"
        for repo in $repos; do
            if [ -d "$repo" ]; then
                c_green "$repo is already cloned"
                continue
            fi

            git clone git@github.com:getnexar/$repo.git
        done
    }
    clone_others() {
        clone_urls="git@github.com:ricardocchaves/nursery.git"
        for url in $clone_urls; do
            repo=$(basename $url .git)
            if [ -d "$repo" ]; then
                c_green "$repo is already cloned"
                continue
            fi

            git clone $url
            if [ "$repo" == "nursery" ]; then
                mv $repo nursery_personal
                repo="nursery_personal"
                pushd $repo || return
                git config --local user.name "Ricardo Chaves"
                git config --local user.email "ricardochaves@ua.pt"
                git config --local core.sshCommand "ssh -i ~/.ssh/ricardochaves_ua"
                popd || return
            fi
        done
    }
    mkdir -p ~/repos
    pushd ~/repos || return
    clone_n1
    clone_nexar
    clone_others
    popd || return
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

c_yellow "Starting laptop setup"
if ! is_setup_done; then
    init
    fix_vim
fi

setup_apt
setup_snap
setup_docker
setup_aws
setup_zsh
setup_ssh
setup_manual_apps
setup_terminator
configure_gnome_general
configure_gnome_dock
setup_git_repos
setup_swap

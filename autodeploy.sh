#!/bin/bash

# ------------------------------
# Section 1: System Update & Cleanup
# ------------------------------

# Update package lists for upgrades
sudo apt update

# Upgrade all installed packages to the latest version, auto-confirming prompts
sudo apt upgrade -y

# Remove packages that are no longer needed
sudo apt autoremove -y

# ------------------------------
# Section 2: Remove telemetry and unwanted packages
# ------------------------------

# Remove Ubuntu's reporting/telemetry tool
sudo apt remove ubuntu-report -y

# Purge popularity contest, crash reporting, and error reporting tools
sudo apt purge popularity-contest apport whoopsie -y

# Remove Snap Store and Snap daemon
sudo snap remove snap-store -y
sudo apt purge snapd -y

# Clean up any leftover unused packages
sudo apt autoremove -y

# ------------------------------
# Section 3: Install and configure personal shell (Fish + Oh My Fish)
# ------------------------------

# Ensure package lists are up to date, then install Fish shell, Git, and curl
sudo apt update
sudo apt install fish git curl -y

# Install Oh My Fish (OMF) non-interactively
curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish -c 'source /dev/stdin --noninteractive'

# Install "chain" plugin for OMF and exit Fish shell
fish -c "omf install chain; exit"

# Remove the default "chain" theme to replace it
rm -rf ~/.local/share/omf/themes/chain

# Clone a custom Fish theme into the OMF themes directory
git clone https://github.com/KNG6/OhMyChainKNG ~/.local/share/omf/themes/chain

# Apply default configuration for the custom theme
fish -c "chain.defaults; exit"

# Disable default Fish greeting message
echo "set fish_greeting" >> ~/.config/fish/config.fish

# Change the default shell for the user to Fish
chsh -s /usr/bin/fish

# ------------------------------
# Section 4: Install Custom Sway Desktop Environment
# ------------------------------

# Update package lists
sudo apt update

# Install Sway (tiling window manager) and related tools:
# kitty (terminal), i3status (status bar), rofi (application launcher),
# swaylock (screen lock), mako-notifier (notifications)
sudo apt install sway kitty i3status rofi swaylock mako-notifier -y

# Create configuration directories for Sway, i3status, kitty, fonts, and wallpapers
mkdir -p ~/.config/sway
mkdir -p ~/.config/i3status
mkdir -p ~/.config/kitty
mkdir -p ~/.local/share/fonts/
mkdir -p ~/Images/wallpaper/

# Download custom config files for Sway, i3status, and kitty from GitHub
curl https://raw.githubusercontent.com/KNG6/sway-dotfile/refs/heads/main/sway/config > ~/.config/sway/config
curl https://raw.githubusercontent.com/KNG6/sway-dotfile/refs/heads/main/i3status/config > ~/.config/i3status/config
curl https://raw.githubusercontent.com/KNG6/sway-dotfile/refs/heads/main/kitty/kitty.conf > ~/.config/kitty/kitty.conf

# Download a Nerd Font (TerminessNerdFont-Bold.ttf) into local fonts
wget https://github.com/ryanoasis/nerd-fonts/raw/refs/heads/master/patched-fonts/Terminus/TerminessNerdFont-Bold.ttf -P ~/.local/share/fonts/

# Download a custom wallpaper
wget https://raw.githubusercontent.com/KNG6/sway-dotfile/refs/heads/main/08_Zoom_CP_Wallpapers_Template_1920x1080_56du2t8jbt4pleym.jpg -P ~/Images/wallpaper/

# Set the GNOME desktop background to the downloaded wallpaper (light and dark themes)
gsettings set org.gnome.desktop.background picture-uri ~/Images/wallpaper/08_Zoom_CP_Wallpapers_Template_1920x1080_56du2t8jbt4pleym.jpg
gsettings set org.gnome.desktop.background picture-uri-dark ~/Images/wallpaper/08_Zoom_CP_Wallpapers_Template_1920x1080_56du2t8jbt4pleym.jpg

# ------------------------------
# Section 5: Kali Linux Docker Integration
# ------------------------------

# Update packages and install Docker
sudo apt update
sudo apt install docker.io -y

# Create Docker group (if not exists) and add current user
sudo groupadd docker
sudo usermod -aG docker $USER

# Apply group change immediately
newgrp docker

# Enable Docker service to start automatically
sudo systemctl enable --now docker

# Pull the latest Kali Linux rolling image
sudo docker pull kalilinux/kali-rolling

# Run Kali container in detached mode:
# - Mount entire host filesystem to /mnt/host
# - Forward X11 socket for GUI apps
# - Use host networking (container shares the host IP and ports)
# - Auto-restart unless stopped manually
sudo docker run -d --name kali \
  -v /:/mnt/host \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  --network host \
  -e DISPLAY=$DISPLAY \
  --restart unless-stopped \
  kalilinux/kali-rolling tail -f /dev/null

# ------------------------------
# Section 6: Systemd user service for X11 access
# ------------------------------

# Ensure user systemd config directory exists
mkdir -p ~/.config/systemd/user/

# Create a systemd service to allow root access to the X server
echo '[Unit]
Description=Autoriser root à accéder au serveur X
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=oneshot
Environment=DISPLAY=:0
ExecStart=/usr/bin/xhost +si:localuser:root
RemainAfterExit=yes

[Install]
WantedBy=graphical-session.target' > ~/.config/systemd/user/xhost.service

# Reload user systemd daemon
systemctl --user daemon-reload

# Enable and start the X11 permission service
systemctl --user enable xhost.service
systemctl --user start xhost.service

# ------------------------------
# Section 7: Kali convenience script
# ------------------------------

# Create a script "/usr/local/bin/kali" to run commands in the Kali container
echo '#!/bin/bash

show_help() {
    cat <<EOF
Usage: kali [COMMAND] [ARGS...]

Wrapper for running commands inside the "kali" Docker container.

Options:
  -h, --help        Show this help message and exit

Behavior:
  If no arguments are provided:
    Launch an interactive Bash shell inside the container.

  If arguments are provided:
    Execute the given command inside the container with the current
    host working directory mounted as /mnt/host.

Examples:
  kali                        # Start an interactive shell in the container
  kali ls -la                 # Run 'ls -la' inside the container
  kali python3 script.py      # Run a Python script inside the container
EOF
}

if [ $# -gt 0 ]; then
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            docker exec -it -w "/mnt/host$(pwd)" kali "$@"
            ;;
    esac
else
    docker exec -it -w "/mnt/host$(pwd)" kali bash
fi' | sudo tee -a /usr/local/bin/kali

# Make the script executable
sudo chmod +x /usr/local/bin/kali

# ------------------------------
# Section 8: Setup Kali container environment
# ------------------------------

# Inside the Kali container:
# - Update and upgrade packages
# - Install top 10 Kali tools
# - Install X11 apps for GUI
sudo docker exec -i kali bash -c "apt update && apt upgrade -y && apt install kali-tools-top10 x11-apps -y"

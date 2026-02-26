```bash
# core
pacman -S --noconfirm --needed \
  mpv feh eog xclip maim rofi kitty nautilus dunst micro \
  network-manager-applet libnotify imagemagick bc \
  ttf-jetbrains-mono-nerd polkit polkit-gnome

# awesome/x11
pacman -S --noconfirm --needed \
  polybar pamixer pavucontrol dex \
  lua-lgi lua-filesystem

# hyprland
pacman -S --noconfirm --needed \
  hyprland hyprpaper hyprshot waybar pipewire pipewire-pulse wireplumber \
  brightnessctl playerctl xdg-desktop-portal-hyprland

# aur stuff
paru -S --noconfirm \
  kora-icon-theme picom-git awesome-git otf-commit-mono-nerd \
  opentabletdriver hyprshell snixembed
```

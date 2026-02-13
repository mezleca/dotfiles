```bash
# core
pacman -S --noconfirm --needed \
  mpv feh eog xclip maim rofi kitty nautilus dunst micro \
  network-manager-applet libnotify imagemagick bc \
  ttf-jetbrains-mono-nerd

# awesome/x11
pacman -S --noconfirm --needed \
  polybar pamixer pavucontrol dex xorg-xinput \
  lua-lgi lua-filesystem

# hypr/wayland
pacman -S --noconfirm --needed \
  hyprland hyprpaper waybar pipewire pipewire-pulse wireplumber \
  brightnessctl playerctl

# aur
paru -S --noconfirm \
  kora-icon-theme picom-git awesome-git otf-commit-mono-nerd \
  opentabletdriver hyprshell snixembed
```

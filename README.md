# dotfiles
minimal i3 / hyprland dotfiles

## i3
<p align="center">
    <img src="https://github.com/mezleca/dotfiles/blob/main/images/2.png" width="45%">
    <img src="https://github.com/mezleca/dotfiles/blob/main/images/1.png" width="45%">
</p>

## hyprland
work in progress

## installation

### needed: i3
```bash
pacman -S --noconfirm --needed i3 rofi picom kitty nemo dunst network-manager-applet ttf-jetbrains-mono-nerd
paru -S --noconfirm nitrogen otf-commit-mono-nerd
```

### needed: hyprland
```bash
pacman -S --noconfirm --needed hyprland hyprpaper rofi kitty nemo dunst network-manager-applet quickshell
paru -S --noconfirm otf-commit-mono-nerd
```

### copy dotfiles to $HOME
```bash
git clone https://github.com/mezleca/dotfiles && cd dotfiles && chmod +x ./install.sh && ./install.sh
```

## using
- **terminal**: kitty
- **launcher**: rofi
- **compositor**: picom (i3)
- **wallpaper tool**: nitrogen (i3) / hyprpaper (hyprland)
- **file manager**: nemo
- **notifications**: dunst
- **alt tab behaviour**: quickshell (hyprland)
- **fonts**: commit mono nerd, forgor

## dotfiles

dotfiles for labwc and mangowm

## preview

### labwc

<p align="center">
    <table>
        <tr>
            <td><img width="400" src="https://raw.githubusercontent.com/mezleca/dotfiles/refs/heads/main/preview/labwc1.png" /></td>
            <td><img width="400" src="https://raw.githubusercontent.com/mezleca/dotfiles/refs/heads/main/preview/labwc2.png" /></td>
        </tr>
    </table>
</p>

### mangowm

<p align="center">
    <table>
        <tr>
            <td><img width="400" src="https://raw.githubusercontent.com/mezleca/dotfiles/refs/heads/main/preview/mango2.png" /></td>
            <td><img width="400" src="https://raw.githubusercontent.com/mezleca/dotfiles/refs/heads/main/preview/mango1.png" /></td>
        </tr>
    </table>
</p>

## apps / tools used

- terminal text editor: micro
- file manager: nautilus
- screenshot: custom script x11 / wayland (grim, slurp, wl-copy, maim, xclip,
  mpv)
- screenlocker (labwc only): hyprlock
- launcher and shit: rofi / yad
- gtk theme: [rel-dark](https://github.com/mezleca/rel-gtk-theme) using "--theme dark --tweaks normal rimless"

## installation

```bash
# shared
pacman -S --noconfirm --needed \
  go mpv feh eog xclip maim rofi kitty nautilus dunst micro \
  libnotify imagemagick bc fzf bat brightnessctl \
  pipewire pipewire-pulse wireplumber playerctl pamixer pavucontrol \
  qt6-wayland dex \
  polkit polkit-gnome gnome-keyring wl-clipboard wl-clip-persist cliphist \
  grim slurp jq waybar \
  cjson xdg-desktop-portal xdg-desktop-portal-gtk

# labwc
pacman -S --noconfirm --needed hyprlock swayidle swaybg xorg-xwayland xdg-desktop-portal-wlr

# mango
pacman -S --noconfirm --needed yad awww

# aur stuff
paru -S --noconfirm \
  mangowm-wlonly-git labwc-git \
  kora-icon-theme otf-commit-mono-nerd \
  opentabletdriver ttf-segoe-ui-variable

# build dots helper
cd lib && go build -o ../dots && cd .. && chmod +x ./dots

# install
./dots install
```

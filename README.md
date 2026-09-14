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

- text editor: micro
- file manager: nautilus
- desktop shell: Noctalia
- screenshot: Noctalia
- screenlocker: Noctalia
- launcher/powermenu: Noctalia
- wallpaper selector: Noctalia
- gtk theme: [rel-dark](https://github.com/mezleca/rel-gtk-theme) using "--theme dark --tweaks normal rimless"

## installation

```bash
# shared
pacman -S --noconfirm --needed \
  go mpv feh eog kitty nautilus micro \
  libnotify imagemagick bc fzf bat \
  pipewire pipewire-pulse wireplumber pamixer pavucontrol \
  qt6-wayland dex \
  polkit gnome-keyring noctalia wayland-pipewire-idle-inhibit \
  xorg-xwayland xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr

# aur stuff
paru -S --noconfirm \
  mangowm-wlonly-git labwc-git \
  kora-icon-theme otf-commit-mono-nerd \
  opentabletdriver ttf-segoe-ui-variable

# build dots helper
cd src && go build -o ../dots && cd .. && chmod +x ./dots

# install
./dots install
```

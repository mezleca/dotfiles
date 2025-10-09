import fs from "fs";
import path from "path";

import { $ } from "bun";

// temp script to sync my dotfiles
// should be replaced with https://github.com/mezleca/sync-dotfiles/ soon

const HOME = process.env.HOME;
const ARG = process.argv[2];
const USER_PLACEHOLDER = "$USER$";

// repo target here
const TARGET_PATH = `${HOME}/stuff/personal/dotfiles`;

// files to be copied
const TARGET_FOLDERS = [
    `${HOME}/.config/alacritty`,
    `${HOME}/.config/hypr`,
    `${HOME}/.config/i3`,
    `${HOME}/.config/nvim`,
    `${HOME}/.config/polybar`,
    `${HOME}/.config/tofi`,
    `${HOME}/.config/waybar`,
    `${HOME}/.config/dunst`,
    `${HOME}/.config/compfy`,
    `${HOME}/.config/picom`,
    `${HOME}/.config/rofi`,
    `${HOME}/.config/kitty`,
    `${HOME}/.config/tmux`,
    `${HOME}/.config/zsh`,
    `${HOME}/.config/Kvantum`,
    `${HOME}/.config/starship`,
    `${HOME}/.config/git`,
    `${HOME}/.config/gtk-3.0`,
    `${HOME}/.config/gtk-2.0`,
    `${HOME}/.config/gtk-4.0`,
    `${HOME}/.config/sync.ts`,
    `${HOME}/.config/package.json`,
    `${HOME}/.config/mimeapps.list`,
    `${HOME}/.local/share/applications/mimeapps.list`,
    `${HOME}/.bashrc`,
    `${HOME}/.zshrc`,
    `${HOME}/.vimrc`,
    `${HOME}/.xinitrc`,
    `${HOME}/.xprofile`
];

const copy_files = async () => {
    for (const t of TARGET_FOLDERS) {
        if (!fs.existsSync(path.resolve(t))) {
            console.log(`skipping ${t} (doesnt exist)`);
            continue;
        }

        // convert path
        // ex: /home/rel/.bashrc -> /home/$USER$/.bashrc
        const relative_path = t.replace(HOME, `/home/${USER_PLACEHOLDER}`);
        const full_path = path.join(TARGET_PATH, relative_path);
        const dir_path = path.dirname(full_path);

        if (!fs.existsSync(dir_path)) {
            fs.mkdirSync(dir_path, { recursive: true });
        }

        console.log(`copying ${t} -> ${full_path}`);

        // use -r for dirs
        if (fs.statSync(t).isDirectory()) {
            await $`cp -r ${t} ${dir_path}`.quiet();
        } else {
            await $`cp ${t} ${full_path}`.quiet();
        }
    }

    console.log("done");
};

// @TODO: link instead of cp
const restore_files = async () => {
    if (!fs.existsSync(TARGET_PATH)) {
        console.log("target path doesnt exist");
        return;
    }

    const placeholder_home = `/home/${USER_PLACEHOLDER}`;

    for (const t of TARGET_FOLDERS) {
        const relative_path = t.replace(HOME, placeholder_home);
        const source_path = path.join(TARGET_PATH, relative_path);

        if (!fs.existsSync(source_path)) {
            console.log(`skipping ${source_path} (doesn't exist in backup)`);
            continue;
        }

        const target_dir = path.dirname(t);

        if (!fs.existsSync(target_dir)) {
            fs.mkdirSync(target_dir, { recursive: true });
        }

        console.log(`restoring ${source_path} -> ${t}`);

        if (fs.statSync(source_path).isDirectory()) {
            await $`cp -r ${source_path} ${target_dir}`.quiet();
        } else {
            await $`cp ${source_path} ${t}`.quiet();
        }
    }

    console.log("done");
};

(async () => {
    switch (ARG) {
        case "-r":
            await restore_files();
            break;
        case "-c":
            await copy_files();
            break;
        default:
            console.log("usage: bun sync.ts [-c|-r]");
            console.log("  -c: copy files to dotfiles repo");
            console.log("  -r: restore files from dotfiles repo");
    }
})();

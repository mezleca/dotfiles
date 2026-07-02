-- https://wiki.hypr.land/Configuring/Start/

-- TODO/TOFIX:
-- fullscreen keybinds should toggle
-- replace noctalia-shell with my own quickshell shit (wip)
-- use viscinae for launcher / power / etc...
-- floating instead of scrolling

--------------------
---- MONITORS ------
--------------------

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-----------------------
---- MY PROGRAMS ------
-----------------------

local terminal     = "kitty"
local file_manager = "nautilus"
local ipc          = "qs -c noctalia-shell ipc call"

--------------------
---- AUTOSTART -----
--------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("otd-daemon")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("/home/rel/.config/hypr/scripts/notifications.sh")
    hl.exec_cmd("qs -c noctalia-shell --no-duplicate")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE",   "24")
hl.env("HYPRCURSOR_SIZE","24")

-- nvidia
hl.env("LIBVA_DRIVER_NAME",        "nvidia")
hl.env("XDG_SESSION_TYPE",         "wayland")
hl.env("GBM_BACKEND",              "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME","nvidia")

-- electron
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

--------------------------
---- LOOK AND FEEL --------
--------------------------

hl.config({
    general = {
        gaps_in  = 0,
        gaps_out = 6,

        border_size = 2,

        col = {
            active_border   = "rgba(78b0ffaa)",
            inactive_border = "rgba(4f4f4faa)",
        },

        allow_tearing    = true,
        resize_on_border = true,
        layout           = "scrolling",
    },

    decoration = {
        rounding       = 2,
        rounding_power = 4,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = true,
        },

        blur = {
            enabled = false,
        },
    },

    animations = {
        enabled = true,
    },

    misc = {
        on_focus_under_fullscreen = 0,
        force_default_wallpaper   = 0,
        disable_hyprland_logo     = true,
        disable_splash_rendering  = true,
        vrr                       = true,
    },

    render = {
        direct_scanout = 1,
    },

    input = {
        kb_layout    = "us",
        kb_variant   = "",
        kb_model     = "",
        kb_options   = "",
        kb_rules     = "",

        follow_mouse  = 1,
        sensitivity   = 0,
        accel_profile = "flat",

        touchpad = {
            natural_scroll = false,
        },
    },

    cursor = {
        no_hardware_cursors = true,
        use_cpu_buffer      = true,
    },

    debug = {
        disable_logs = true,
    },
})

hl.config({
    scrolling = {
        column_width             = 1.0,
        explicit_column_widths   = "0.5, 0.67, 1.0",
        follow_focus             = false,
        focus_fit_method         = 1,
        follow_min_visible       = 0.0,
        direction                = "right",
        fullscreen_on_one_column = true,
    },
})

--------------------
---- ANIMATIONS ----
--------------------

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

-----------------------
---- KEYBINDINGS ------
-----------------------

local main_mod = "SUPER"

hl.bind(main_mod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(main_mod .. " + Q", hl.dsp.window.close())
hl.bind(main_mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(main_mod .. " + M",      hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
hl.bind(main_mod .. " + E",      hl.dsp.exec_cmd(file_manager))
hl.bind(main_mod .. " + V",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(main_mod .. " + P",      hl.dsp.exec_cmd(ipc .. " powermenu toggle"))

-- qs ipc
hl.bind(main_mod .. " + W",         hl.dsp.exec_cmd(ipc .. " wallpaper toggle"))
hl.bind(main_mod .. " + D",         hl.dsp.exec_cmd(ipc .. " launcher toggle"))
hl.bind(main_mod .. " + SHIFT + W", hl.dsp.exec_cmd(ipc .. " settings toggle"))

-- screenshots
hl.bind(main_mod .. " + S",         hl.dsp.exec_cmd("~/.local/bin/dot-screenshot.sh"))
hl.bind(main_mod .. " + SHIFT + S", hl.dsp.exec_cmd("~/.local/bin/dot-screenshot.sh --selection"))

-- scrolling layout
hl.bind(main_mod .. " + J",         hl.dsp.layout("focus l"))
hl.bind(main_mod .. " + K",         hl.dsp.layout("focus r"))
hl.bind(main_mod .. " + SHIFT + J", hl.dsp.layout("swapcol l"))
hl.bind(main_mod .. " + SHIFT + K", hl.dsp.layout("swapcol r"))
hl.bind(main_mod .. " + U",         hl.dsp.layout("promote"))
hl.bind(main_mod .. " + I",         hl.dsp.layout("move +col"))
hl.bind(main_mod .. " + SHIFT + I", hl.dsp.layout("move -col"))
hl.bind(main_mod .. " + O",         hl.dsp.layout("colresize +conf"))
hl.bind(main_mod .. " + SHIFT + O", hl.dsp.layout("colresize -conf"))

-- fullscreen
hl.bind(main_mod .. " + F",         hl.dsp.window.fullscreen_state({ internal = 1, client = 0 }))
hl.bind(main_mod .. " + SHIFT + F", hl.dsp.window.fullscreen_state({ internal = 2, client = 0 }))

-- alt+tab
hl.bind("ALT + TAB", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

hl.bind("ALT + SHIFT + TAB", function()
    hl.dispatch(hl.dsp.window.cycle_next({ prev = true }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- arrow focus
hl.bind(main_mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(main_mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(main_mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(main_mod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- workspaces 1-5
for i = 1, 5 do
    hl.bind(main_mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(main_mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- workspace scroll
hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(main_mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- drag/resize
hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- volume/brightness via qs ipc
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(ipc .. " volume increase"),    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(ipc .. " volume decrease"),    { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(ipc .. " volume muteOutput"),  { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(ipc .. " brightness increase"),{ locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. " brightness decrease"),{ locked = true, repeating = true })

-- playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

--------------------------
---- WINDOW RULES ---------
--------------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drag",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "float-dialogs",
    match = { title = "^(Open File|Save File|Save As|Select File|Choose File|File Upload)$" },
    float = true,
})

hl.window_rule({
    name  = "float-portals",
    match = { class = "^(xdg%-desktop%-portal%-gtk|xdg%-desktop%-portal%-kde|org%.kde%.polkit%-kde%-authentication%-agent%-1|polkit%-gnome%-authentication%-agent%-1|lxqt%-policykit%-agent)$" },
    float = true,
})

-- osu(stable)
hl.window_rule({
    name  = "osu",
    match = { class = "osu%.exe" },
    no_anim    = true,
    no_focus   = true,
    fullscreen = true,
    immediate  = true,
})

-- proton games
hl.window_rule({
    name  = "proton",
    match = { class = "steam_app_.*" },
    fullscreen  = true,
    no_max_size = true,
    immediate   = true,
    no_vrr      = false,
})

-- wine
hl.window_rule({
    name  = "wine",
    match = { title = ".*%.exe.*" },
    no_max_size = true,
    no_vrr      = false,
    immediate   = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

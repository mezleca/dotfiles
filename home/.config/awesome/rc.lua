local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")

-- custom widgets
local bar = require("widgets.bar")
local tab = require("widgets.tabs")

require("awful.autofocus")

local function sh(cmd)
    awful.spawn.with_shell(cmd)
end

-- modifier keys
MODKEY = "Mod4"
ALTKEY = "Mod1"

TERMINAL        = "kitty"
FILE_MANAGER    = "nautilus"
LAUNCHER        = os.getenv("HOME") .. "/.config/rofi/launch.sh launcher"
POWER_MENU      = os.getenv("HOME") .. "/.config/rofi/launch.sh powermenu"
WALLPAPER       = os.getenv("HOME") .. "/.config/rofi/launch.sh wallpaper"
SCREENSHOT      = os.getenv("HOME") .. "/.local/bin/dot-screenshot.sh"
SCREENSHOT_AREA = os.getenv("HOME") .. "/.local/bin/dot-screenshot.sh --selection"

-- load last wallpaper
sh(os.getenv("HOME") .. "/.config/rofi/scripts/set_wallpaper.sh --restore")

-- setup theme
beautiful.init(gears.filesystem.get_configuration_dir() .. "theme/dark.lua")
awful.layout.layouts = { awful.layout.suit.floating }

-- autostart stuff
sh("otd-daemon")
sh("dunst")
sh("picom")
sh("dex --autostart --environment awesome")
sh("nm-applet")
sh("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

awful.spawn.with_shell([[
for id in $(xinput list | grep "pointer" | cut -d '=' -f 2 | cut -f 1); do
  xinput --set-prop $id 'libinput Accel Profile Enabled' 0, 1
done
]])

naughty.connect_signal("request::display_error", function(message, startup)
    local title = "awesome error" .. (startup and " (startup)" or "")
    awful.spawn.with_shell(string.format(
        "notify-send -u critical '%s' '%s'",
        title:gsub("'", "'\\''"),
        message:gsub("'", "'\\''")
    ))
end)

-- apps that must always be fullscreen (forced once on startup)
local FORCE_FULLSCREEN = { "osu!%.exe", "steam_app_" }
local REDRAW_WORKAROUND_CLASSES = { "^unity$" }

local function class_matches(c, patterns)
    if not c or not c.class then return false end
    local cls = c.class:lower()
    for _, p in ipairs(patterns) do
        if cls:match(p) then return true end
    end
    return false
end

local function should_be_fullscreen(c)
    return class_matches(c, FORCE_FULLSCREEN)
end

local function has_redraw_workaround(c)
    return class_matches(c, REDRAW_WORKAROUND_CLASSES)
end

local redraw_refreshing_clients = {}
local REDRAW_FOCUS_DELAY_S = 0.09
local REDRAW_NUDGE_DELAY_S = 0.02
local REDRAW_MAXIMIZED_INSET_PX = 4

local function is_client_refreshable(c)
    return c and c.valid and has_redraw_workaround(c) and not c.fullscreen and not redraw_refreshing_clients[c]
end

local function build_temp_unmaximized_geo(c, fallback_geo)
    local workarea = c.screen and c.screen.workarea or fallback_geo
    return {
        x = workarea.x + REDRAW_MAXIMIZED_INSET_PX,
        y = workarea.y + REDRAW_MAXIMIZED_INSET_PX,
        width = math.max(workarea.width - (REDRAW_MAXIMIZED_INSET_PX * 2), 200),
        height = math.max(workarea.height - (REDRAW_MAXIMIZED_INSET_PX * 2), 200)
    }
end

local function restore_client_state(c, state)
    if not c.valid then return end

    c.minimized = false
    c:geometry(state.geo)
    c.fullscreen = state.fullscreen
    c.floating = state.floating
    c.maximized = state.maximized
    c:raise()
end

local function apply_refresh_nudge(c, state)
    if state.maximized then
        c.maximized = false
        c:geometry(build_temp_unmaximized_geo(c, state.geo))
        return
    end

    c:geometry({
        x = state.geo.x + 1,
        y = state.geo.y + 1,
        width = state.geo.width + 2,
        height = state.geo.height + 1
    })
end

local function refresh_window_redraw(c)
    if not is_client_refreshable(c) then return end

    redraw_refreshing_clients[c] = true
    local state = {
        maximized = c.maximized,
        fullscreen = c.fullscreen,
        floating = c.floating,
        geo = c:geometry()
    }

    gears.timer.start_new(REDRAW_FOCUS_DELAY_S, function()
        if not c.valid then
            redraw_refreshing_clients[c] = nil
            return false
        end

        c:emit_signal("request::activate", "redraw_refresh", { raise = true })
        c.minimized = false
        apply_refresh_nudge(c, state)

        gears.timer.start_new(REDRAW_NUDGE_DELAY_S, function()
            restore_client_state(c, state)
            redraw_refreshing_clients[c] = nil
            return false
        end)

        return false
    end)
end

-- mouse binds
local client_buttons = gears.table.join(
    awful.button({}, 1, function(c) c:activate({ context = "mouse_click", raise = true }) end),
    awful.button({ MODKEY }, 1, function(c)
        c:activate({ context = "mouse_click" })
        awful.mouse.client.move(c)
    end),
    awful.button({ MODKEY }, 3, function(c)
        c:activate({ context = "mouse_click" })
        awful.mouse.client.resize(c)
    end)
)

-- keybindings
local global_keys = gears.table.join(
    awful.key({ MODKEY }, "Return", function() sh(TERMINAL) end),
    awful.key({ MODKEY }, "e", function() sh(FILE_MANAGER) end),
    awful.key({ MODKEY }, "d", function() sh(LAUNCHER) end),
    awful.key({ MODKEY }, "p", function() sh(POWER_MENU) end),
    awful.key({ MODKEY, "Shift" }, "r", awesome.restart),

    -- screenshot
    awful.key({ MODKEY }, "s", function() sh(SCREENSHOT) end),

    -- screenshot area (selection)
    awful.key({ MODKEY, "Shift" }, "s", function() sh(SCREENSHOT_AREA) end),

    -- kill current window
    awful.key({ MODKEY }, "q", function()
        if client.focus then client.focus:kill() end
    end),

    -- maximize
    awful.key({ MODKEY }, "f", function()
        if client.focus then
            client.focus.maximized = not client.focus.maximized
            client.focus:raise()
        end
    end),

    -- wallpaper widget
    awful.key({ MODKEY, "Shift" }, "p", function()
        awful.spawn.with_shell(WALLPAPER)
    end),

    -- actual fullscreen
    awful.key({ MODKEY, "Shift" }, "f", function()
        if client.focus then
            client.focus.fullscreen = not client.focus.fullscreen
            client.focus:raise()
        end
    end),

    -- show tab switcher
    awful.key({ ALTKEY }, "Tab", function()
        tab:show(awful.screen.focused())
    end),

    -- audio keys
    awful.key({}, "XF86AudioRaiseVolume", function() sh("pactl set-sink-volume @DEFAULT_SINK@ +10%") end),
    awful.key({}, "XF86AudioLowerVolume", function() sh("pactl set-sink-volume @DEFAULT_SINK@ -10%") end),
    awful.key({}, "XF86AudioMute", function() sh("pactl set-sink-mute @DEFAULT_SINK@ toggle") end),
    awful.key({}, "XF86AudioMicMute", function() sh("pactl set-source-mute @DEFAULT_SOURCE@ toggle") end)
)

-- setup workspaces and bar
awful.screen.connect_for_each_screen(function(s)
    awful.tag({ "1","2","3","4","5" }, s, awful.layout.suit.floating)
    bar.create(s)
    tab:create(s)
end)

for i = 1, 5 do
    global_keys = gears.table.join(global_keys,
        awful.key({ MODKEY }, "#" .. i + 9, function()
            local tag = awful.screen.focused().tags[i]
            if tag then tag:view_only() end
        end),
        awful.key({ MODKEY, "Shift" }, "#" .. i + 9, function()
            if client.focus then
                local tag = client.focus.screen.tags[i]
                if tag then client.focus:move_to_tag(tag) end
            end
        end)
    )
end

root.keys(global_keys)

-- default rules
awful.rules.rules = {
    {
        rule = {},
        properties = {
            border_width = beautiful.border_width,
            border_color = beautiful.border_normal,
            focus = awful.client.focus.filter,
            placement = awful.placement.centered,
            raise = true,
            floating = true,
            maximized = false,
            fullscreen = false,
            buttons = client_buttons
        }
    },
}

-- signals
client.connect_signal("manage", function(c)
    if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
        awful.placement.no_offscreen(c)
    end

    -- apply initial state for force-fullscreen apps (only once)
    if should_be_fullscreen(c) then
        c.fullscreen = true
        c.floating = false
        return
    end

    -- auto maximize if client takes up more than 80% of screen width or height
    local screen_geo = c.screen.workarea
    local c_geo = c:geometry()
    local border = beautiful.border_width * 2

    local width_percent = (c_geo.width + border) / screen_geo.width
    local height_percent = (c_geo.height + border) / screen_geo.height

    if width_percent > 0.8 or height_percent > 0.8 then
        c.maximized = true
    end
end)

local clamping_clients = {}

-- dont allow windows to move / resize past workarea
client.connect_signal("property::geometry", function(c)
    if not c.floating or c.fullscreen or c.maximized then return end

    -- ignore if we're already clamping that client
    if clamping_clients[c] then return end

    local screen_geo = awful.screen.focused().workarea
    local c_geo = c:geometry()
    local border = beautiful.border_width * 2

    local clamped = false
    local new_geo = {
        x = c_geo.x,
        y = c_geo.y,
        width = c_geo.width,
        height = c_geo.height
    }

    -- clamp position
    if new_geo.x < screen_geo.x then
        new_geo.x = screen_geo.x
        clamped = true
    end
    if new_geo.y < screen_geo.y then
        new_geo.y = screen_geo.y
        clamped = true
    end

    -- clamp size
    if new_geo.width + border > screen_geo.width then
        new_geo.width = screen_geo.width - border
        clamped = true
    end
    if new_geo.height + border > screen_geo.height then
        new_geo.height = screen_geo.height - border
        clamped = true
    end

    -- prevent going offscreen right/bottom
    if new_geo.x + new_geo.width + border > screen_geo.x + screen_geo.width then
        new_geo.x = screen_geo.x + screen_geo.width - new_geo.width - border
        clamped = true
    end
    if new_geo.y + new_geo.height + border > screen_geo.y + screen_geo.height then
        new_geo.y = screen_geo.y + screen_geo.height - new_geo.height - border
        clamped = true
    end

    if clamped then
        clamping_clients[c] = true
        c:geometry(new_geo)

        -- clear after we clamp it
        gears.timer.delayed_call(function()
            clamping_clients[c] = nil
        end)
    end
end)

client.connect_signal("focus", function(c)
    c.border_color = beautiful.border_focus
    refresh_window_redraw(c)
end)

tag.connect_signal("property::selected", function(t)
    if not t.selected then
        return
    end

    gears.timer.delayed_call(function()
        for _, c in ipairs(t:clients()) do
            refresh_window_redraw(c)
        end
    end)
end)

client.connect_signal("unmanage", function(c)
    clamping_clients[c] = nil
    redraw_refreshing_clients[c] = nil
end)

client.connect_signal("unfocus", function(c)
    c.border_color = beautiful.border_normal
end)

client.connect_signal("property::fullscreen", function(c)
    c.border_width = c.fullscreen and 0 or beautiful.border_width
end)

client.connect_signal("property::maximized", function(c)
    c.border_width = c.maximized and 0 or beautiful.border_width
end)

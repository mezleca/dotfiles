local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")

-- custom widgets
local bar = require("widgets.bar")
local tab = require("widgets.tab_switcher")

require("awful.autofocus")

-- modifier keys
MODKEY = "Mod4"
ALTKEY = "Mod1"

TERMINAL        = "kitty"
FILE_MANAGER    = "nautilus"
LAUNCHER        = os.getenv("HOME") .. "/.config/rofi/scripts/launcher.sh"
POWER_MENU      = os.getenv("HOME") .. "/.config/rofi/scripts/power_menu.sh"
SCREENSHOT      = os.getenv("HOME") .. "/.local/bin/dot-screenshot.sh"
SCREENSHOT_AREA = os.getenv("HOME") .. "/.local/bin/dot-screenshot.sh --selection"

-- setup theme
beautiful.init(gears.filesystem.get_configuration_dir() .. "theme/dark.lua")
awful.layout.layouts = { awful.layout.suit.floating }

local function autostart(cmd)
    awful.spawn.with_shell(cmd)
end

-- autostart apps
autostart("otd-daemon")
autostart("dunst")
autostart("picom")
autostart("dex --autostart --environment awesome")
autostart("nm-applet")
autostart("feh --bg-fill ~/wallpapers/7.jpg")

awful.spawn.with_shell([[
for id in $(xinput list | grep "pointer" | cut -d '=' -f 2 | cut -f 1); do
  xinput --set-prop $id 'libinput Accel Profile Enabled' 0, 1
done
]])

-- simple error notifications
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
    awful.key({ MODKEY }, "Return", function() awful.spawn(TERMINAL) end),
    awful.key({ MODKEY }, "e", function() awful.spawn(FILE_MANAGER) end),
    awful.key({ MODKEY }, "d", function() awful.spawn.with_shell(LAUNCHER) end),
    awful.key({ MODKEY }, "p", function() awful.spawn.with_shell(POWER_MENU) end),
    awful.key({ MODKEY, "Shift" }, "r", awesome.restart),

	-- screenshot
	awful.key({ MODKEY }, "s", function() awful.spawn.with_shell(SCREENSHOT) end),

	-- screenshot area (selection)
	awful.key({ MODKEY, "Shift" }, "s", function() awful.spawn.with_shell(SCREENSHOT_AREA) end),

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
    awful.key({}, "XF86AudioRaiseVolume", function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ +10%") end),
    awful.key({}, "XF86AudioLowerVolume", function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ -10%") end),
    awful.key({}, "XF86AudioMute", function() awful.spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle") end),
    awful.key({}, "XF86AudioMicMute", function() awful.spawn("pactl set-source-mute @DEFAULT_SOURCE@ toggle") end)
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
end)

-- dont allow windows to move / resize past workarea
client.connect_signal("property::geometry", function(c)
    if not c.floating or c.fullscreen or c.maximized then return end

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
        c:geometry(new_geo)
    end
end)

client.connect_signal("focus", function(c)
    c.border_color = beautiful.border_focus
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

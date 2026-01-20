local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")

require("awful.autofocus")

local FULLSCREEN_THRESHOLD = 0.9
local SANE_SIZE_RATIO = 0.75

modkey = "Mod4"
altkey = "Mod1"

terminal     = "kitty"
file_manager = "nemo"
launcher     = os.getenv("HOME") .. "/.config/rofi/scripts/launcher.sh"
power_menu   = os.getenv("HOME") .. "/.config/rofi/scripts/power_menu.sh"

-- setup theme
beautiful.init(gears.filesystem.get_themes_dir() .. "default/theme.lua")
beautiful.border_width = 3
beautiful.border_focus = "#3d466b"
beautiful.border_normal = "#333333"

awful.layout.layouts = { awful.layout.suit.floating }

local function autostart(cmd) awful.spawn.with_shell(cmd) end

-- autostart apps
autostart("otd-daemon")
autostart("dunst")
autostart("picom")
autostart("dex --autostart --environment awesome")
autostart("nm-applet")
autostart("~/.config/polybar/launch.sh")
autostart("feh --bg-fill ~/wallpapers/7.jpg")

awful.spawn.with_shell([[
for id in $(xinput list | grep "pointer" | cut -d '=' -f 2 | cut -f 1); do
  xinput --set-prop $id 'libinput Accel Profile Enabled' 0, 1
done
]])

awful.spawn.with_shell([[
mkdir -p /tmp/awesome_errors
exec 2>/tmp/awesome_errors/log
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

local polybar_hidden = false

local function update_polybar()
    local tag = awful.screen.focused().selected_tag
    if not tag then return end

    local should_hide = false
    for _, c in ipairs(tag:clients()) do
        if c.fullscreen and c:isvisible() then
            should_hide = true
            break
        end
    end

    if should_hide and not polybar_hidden then
        awful.spawn.with_shell("polybar-msg cmd hide")
        polybar_hidden = true
    elseif not should_hide and polybar_hidden then
        awful.spawn.with_shell("polybar-msg cmd show")
        polybar_hidden = false
    end
end

-- apps that must always be fullscreen (forced once on startup)
local force_fullscreen = { "osu!%.exe", "steam_app_" }

-- browsers have weird EWMH bugs, let them manage their own state
local ignore_state_management = { "firefox", "chromium", "chrome", "brave" }

local function class_matches(c, patterns)
    if not c or not c.class then return false end
    local cls = c.class:lower()
    for _, p in ipairs(patterns) do
        if cls:match(p) then return true end
    end
    return false
end

local function should_be_fullscreen(c)
    return class_matches(c, force_fullscreen)
end

local function should_ignore_state(c)
    return class_matches(c, ignore_state_management)
end

local function should_maximize_by_size(c)
    if not c or not c.valid or not c.screen then return false end
    local wa = c.screen.workarea
    local g = c:geometry()
    return (g.width / wa.width >= FULLSCREEN_THRESHOLD) and
           (g.height / wa.height >= FULLSCREEN_THRESHOLD)
end

local function normalize_geometry(c)
    if not c or not c.valid or not c.screen then return end
    local wa = c.screen.workarea
    local w = math.floor(wa.width * SANE_SIZE_RATIO)
    local h = math.floor(wa.height * SANE_SIZE_RATIO)
    c:geometry({
        x = wa.x + math.floor((wa.width - w) / 2),
        y = wa.y + math.floor((wa.height - h) / 2),
        width = w, height = h
    })
end

-- mouse binds
local clientbuttons = gears.table.join(
    awful.button({}, 1, function(c) c:activate({ context = "mouse_click", raise = true }) end),
    awful.button({ modkey }, 1, function(c) c:activate({ context = "mouse_click" }); awful.mouse.client.move(c) end),
    awful.button({ modkey }, 3, function(c) c:activate({ context = "mouse_click" }); awful.mouse.client.resize(c) end)
)

-- keybindings
local globalkeys = gears.table.join(
    awful.key({ modkey }, "Return", function() awful.spawn(terminal) end),
    awful.key({ modkey }, "e", function() awful.spawn(file_manager) end),
    awful.key({ modkey }, "d", function() awful.spawn.with_shell(launcher) end),
    awful.key({ modkey }, "p", function() awful.spawn.with_shell(power_menu) end),
    awful.key({ modkey, "Shift" }, "r", awesome.restart),

    awful.key({ modkey }, "q", function() if client.focus then client.focus:kill() end end),

    awful.key({ modkey }, "f", function()
        if client.focus then client.focus.maximized = not client.focus.maximized; client.focus:raise() end
    end),

    awful.key({ modkey, "Shift" }, "f", function()
        if client.focus then client.focus.fullscreen = not client.focus.fullscreen; client.focus:raise() end
    end),

    awful.key({ altkey }, "Tab", function()
        awful.client.focus.byidx(1)
        if client.focus then client.focus:raise() end
    end),

    awful.key({ altkey, "Shift" }, "Tab", function()
        awful.client.focus.byidx(-1)
        if client.focus then client.focus:raise() end
    end),

    -- audio keys
    awful.key({}, "XF86AudioRaiseVolume", function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ +10%") end),
    awful.key({}, "XF86AudioLowerVolume", function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ -10%") end),
    awful.key({}, "XF86AudioMute", function() awful.spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle") end),
    awful.key({}, "XF86AudioMicMute", function() awful.spawn("pactl set-source-mute @DEFAULT_SOURCE@ toggle") end)
)

-- setup workspaces
awful.screen.connect_for_each_screen(function(s)
    awful.tag({ "1","2","3","4","5","6","7","8","9","10" }, s, awful.layout.suit.floating)
end)

for i = 1, 10 do
    globalkeys = gears.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9, function()
            local tag = awful.screen.focused().tags[i]
            if tag then tag:view_only() end
        end),
        awful.key({ modkey, "Shift" }, "#" .. i + 9, function()
            if client.focus then
                local tag = client.focus.screen.tags[i]
                if tag then client.focus:move_to_tag(tag) end
            end
        end)
    )
end

root.keys(globalkeys)

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
            buttons = clientbuttons
        }
    },
    {
        rule_any = { class = { "Polybar", "polybar" } },
        properties = { border_width = 0, focusable = false, skip_taskbar = true }
    }
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
        update_polybar()
        return
    end

    -- auto maximize oversized windows
    if should_maximize_by_size(c) and not should_ignore_state(c) then
        c.maximized = true
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
    update_polybar()
end)

client.connect_signal("property::maximized", function(c)
    c.border_width = c.maximized and 0 or beautiful.border_width
end)

tag.connect_signal("property::selected", update_polybar)
client.connect_signal("unmanage", update_polybar)

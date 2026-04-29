local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")
local ruled = require("ruled")

-- custom widgets
local bar = require("widgets.bar")
local tab = require("widgets.tabs")

require("awful.autofocus")

local function sh(cmd)
    awful.spawn.with_shell(cmd)
end

local function activate_and_raise(c)
    c:activate({ context = "mouse_click", raise = true })
end

local function toggle_maximized(c)
    if not c then
        return
    end

    c.maximized = not c.maximized
    c:raise()
end

local function toggle_fullscreen(c)
    if not c then
        return
    end

    c.fullscreen = not c.fullscreen
    c:raise()
end

local function move_client(c)
    c:activate({ context = "mouse_click" })
    awful.mouse.client.move(c)
end

local function resize_client(c)
    c:activate({ context = "mouse_click" })
    awful.mouse.client.resize(c)
end

-- modifier keys
MODKEY = "Mod4"
ALTKEY = "Mod1"

TERMINAL = "kitty"
FILE_MANAGER = "nautilus"

LAUNCHER = "vicinae vicinae://toggle"
POWER_MENU = "vicinae vicinae://launch/power"
WALLPAPER = os.getenv("HOME") .. "/.local/bin/vicinae-wallpaper.sh"
SCREENSHOT = os.getenv("HOME") .. "/.local/bin/dot-screenshot.sh"
SCREENSHOT_AREA = os.getenv("HOME") .. "/.local/bin/dot-screenshot.sh --selection"

local AUTOSTART_COMMANDS = {
    "otd-daemon",
    "dunst",
    "picom",
    "dex --autostart --environment awesome",
    "nm-applet",
    "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
}

local WORKSPACE_NAMES = { "1", "2", "3", "4", "5" }
local AUDIO_STEP = "10%"
local MAXIMIZE_THRESHOLD = 0.8
local UNITY_REPAINT_DELAY_SEC = 1 / 60

local CLIENT_RULES = {
    force_fullscreen = {
        { rule_any = { class = { "osu!%.exe", "steam_app_" } } }
    },
    borderless = {
        { rule_any = { name = { "Vicinae Launcher", "Vicinae Power", "Vicinae" } } },
        { rule_any = { class = {} } }
    }
}

local function setup_autostart()
    for _, cmd in ipairs(AUTOSTART_COMMANDS) do
        sh(cmd)
    end
end

local function client_matches_rules(c, rules)
    for _, rule in ipairs(rules) do
        if ruled.client.matches(c, rule) then
            return true
        end
    end

    return false
end

local function should_be_fullscreen(c)
    return client_matches_rules(c, CLIENT_RULES.force_fullscreen)
end

local function should_hide_border(c)
    if client_matches_rules(c, CLIENT_RULES.borderless) then
        return true
    end

    if c.fullscreen or c.maximized then
        return true
    end

    return false
end

local function get_border_width(c)
    if should_hide_border(c) then
        return 0
    end

    return beautiful.border_width
end

local function update_client_border(c)
    c.border_width = get_border_width(c)
end

local function apply_manage_rules(c)
    if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
        awful.placement.no_offscreen(c)
    end

    -- apply initial state for force-fullscreen apps (only once)
    if should_be_fullscreen(c) then
        c.fullscreen = true
        c.floating = false
        update_client_border(c)
        return
    end

    -- auto maximize if client takes up more than 80% of screen width or height
    local screen_geo = c.screen.workarea
    local c_geo = c:geometry()
    local border = get_border_width(c) * 2

    local width_percent = (c_geo.width + border) / screen_geo.width
    local height_percent = (c_geo.height + border) / screen_geo.height

    if width_percent > MAXIMIZE_THRESHOLD or height_percent > MAXIMIZE_THRESHOLD then
        c.maximized = true
    end

    update_client_border(c)
end

local clamping_clients = {}

local function clamp_client_to_workarea(c)
    if not c.floating or c.fullscreen or c.maximized then
        return
    end

    if clamping_clients[c] then
        return
    end

    local screen_geo = c.screen.workarea
    local c_geo = c:geometry()
    local border = c.border_width * 2

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

    if not clamped then
        return
    end

    clamping_clients[c] = true
    c:geometry(new_geo)

    -- clear after we clamp it
    gears.timer.delayed_call(function()
        clamping_clients[c] = nil
    end)
end

local last_focus = nil
local unity_force_repaint = true

local function handle_unity_focus(c)
    if not c then
        return
    end

    -- This is needed to have Unity on one screen and some utility panels on another
    -- without constantly repainting whenever the user switches back and forth
    if not unity_force_repaint
        and last_focus
        and last_focus.valid
        and last_focus.tag == c.tag
        and ruled.client.match(last_focus, { class = "Unity" })
    then
        last_focus = c
        return
    end

    last_focus = c
    unity_force_repaint = false

    if not ruled.client.match(c, { class = "Unity" }) then
        return
    end

    if ruled.client.matches(c, { rule_any = { type = { "dialog", "popup", "popup_menu" } } }) then
        return
    end

    if ruled.client.match(c, { name = "Select" }) then
        return
    end

    -- The workaround
    -- note: gears.timer.delayed_call doesn't not seem to work for this
    c.fullscreen = false
    gears.timer.start_new(UNITY_REPAINT_DELAY_SEC, function()
        c.fullscreen = true
        update_client_border(c)
        return false
    end)
end

local function focus_client(c)
    c.border_color = beautiful.border_focus
    update_client_border(c)
    handle_unity_focus(c)
end

local function unfocus_client(c)
    c.border_color = beautiful.border_normal
    update_client_border(c)
end

local function clear_client_state(c)
    clamping_clients[c] = nil
end

-- restore last selected wallpaper
sh(WALLPAPER .. " --restore")

-- setup theme
beautiful.init(gears.filesystem.get_configuration_dir() .. "theme/dark.lua")
awful.layout.layouts = { awful.layout.suit.floating }

-- autostart stuff
setup_autostart()

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

-- mouse binds
local client_buttons = gears.table.join(
    awful.button({}, 1, activate_and_raise),
    awful.button({ MODKEY }, 1, move_client),
    awful.button({ MODKEY }, 3, resize_client)
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
        if client.focus then
            client.focus:kill()
        end
    end),

    -- maximize
    awful.key({ MODKEY }, "f", function()
        toggle_maximized(client.focus)
    end),

    -- wallpaper widget
    awful.key({ MODKEY, "Shift" }, "p", function()
        awful.spawn.with_shell(WALLPAPER)
    end),

    -- actual fullscreen
    awful.key({ MODKEY, "Shift" }, "f", function()
        toggle_fullscreen(client.focus)
    end),

    -- show tab switcher
    awful.key({ ALTKEY }, "Tab", function()
        tab:show(awful.screen.focused())
    end),

    -- audio keys
    awful.key({}, "XF86AudioRaiseVolume", function() sh("pactl set-sink-volume @DEFAULT_SINK@ +" .. AUDIO_STEP) end),
    awful.key({}, "XF86AudioLowerVolume", function() sh("pactl set-sink-volume @DEFAULT_SINK@ -" .. AUDIO_STEP) end),
    awful.key({}, "XF86AudioMute", function() sh("pactl set-sink-mute @DEFAULT_SINK@ toggle") end),
    awful.key({}, "XF86AudioMicMute", function() sh("pactl set-source-mute @DEFAULT_SOURCE@ toggle") end)
)

-- setup workspaces and bar
awful.screen.connect_for_each_screen(function(s)
    awful.tag(WORKSPACE_NAMES, s, awful.layout.suit.floating)
    bar.create(s)
    tab:create(s)
end)

for i = 1, #WORKSPACE_NAMES do
    global_keys = gears.table.join(global_keys,
        awful.key({ MODKEY }, "#" .. i + 9, function()
            local tag = awful.screen.focused().tags[i]
            if tag then
                tag:view_only()
            end
        end),
        awful.key({ MODKEY, "Shift" }, "#" .. i + 9, function()
            if client.focus then
                local tag = client.focus.screen.tags[i]
                if tag then
                    client.focus:move_to_tag(tag)
                end
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
client.connect_signal("request::manage", apply_manage_rules)

-- dont allow windows to move / resize past workarea
client.connect_signal("property::geometry", clamp_client_to_workarea)

-- unity repaint "fix"
-- https://discussions.unity.com/t/editor-repaint-issue-when-using-i3-window-manager/738539/9
client.connect_signal("focus", focus_client)

tag.connect_signal("property::selected", function()
    unity_force_repaint = true
end)

client.connect_signal("request::unmanage", clear_client_state)
client.connect_signal("unfocus", unfocus_client)
client.connect_signal("property::fullscreen", update_client_border)
client.connect_signal("property::maximized", update_client_border)
client.connect_signal("property::name", update_client_border)
client.connect_signal("property::class", update_client_border)

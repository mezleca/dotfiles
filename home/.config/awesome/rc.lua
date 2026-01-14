local gears = require("gears")
local awful = require("awful")
local ruled = require("ruled")
local dbg = require("__debug")
local beautiful = require("beautiful")
local naughty = require("naughty")
local testbox = require("test")

require("awful.autofocus")

-- TODO
-- [x] if the window is big enough, make it fullscreen
-- [x] hack to fix osu! being hidden for no reason at all (after changing workspace)
-- [ ] alt tab like widget
-- [ ] ...

-- if window covers more than 90% of screen, auto fullscreen it
local FULLSCREEN_THRESHOLD = 0.9
local SANE_SIZE_RATIO = 0.5
local polybar_hidden = false

local ALWAYS_FULLSCREEN_APPS = {
    "osu",
    "steam_app_"
}

local function autostart(cmd)
    awful.spawn.with_shell(cmd)
end

-- catch errors and display them as notifications instead of crashing
naughty.connect_signal("request::display_error", function(message, startup)
    naughty.notification({
        urgency = "critical",
        title = "Error" .. (startup and " during startup" or ""),
        message = message
    })
end)

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

awful.layout.layouts = {
    awful.layout.suit.floating
}

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

awful.screen.connect_for_each_screen(function(s)
    awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }, s, awful.layout.suit.floating)
    testbox.load(s)
end)

clientbuttons = gears.table.join(
	-- raise window on click
    awful.button({}, 1, function(c)
        c:activate({ context = "mouse_click", raise = true })
    end),

    -- move window on mod + left click
    awful.button({ modkey }, 1, function(c)
        c:activate({ context = "mouse_click" })
        awful.mouse.client.move(c)
    end),

    -- resize window on mod + right click
    awful.button({ modkey }, 3, function(c)
        c:activate({ context = "mouse_click" })
        awful.mouse.client.resize(c)
    end)
)

globalkeys = gears.table.join(
    awful.key({ modkey }, "Return", function() awful.spawn(terminal) end),
    awful.key({ modkey }, "e", function() awful.spawn(file_manager) end),
    awful.key({ modkey }, "d", function() awful.spawn(launcher) end),
    awful.key({ modkey }, "p", function() awful.spawn(power_menu) end),
    awful.key({ modkey, "Shift" }, "r", awesome.restart),

    awful.key({ modkey }, "q", function()
        if client.focus then client.focus:kill() end
    end),

    awful.key({ modkey }, "f", function()
        if client.focus then
            client.focus.maximized = not client.focus.maximized
            client.focus:raise()
        end
    end),

    awful.key({ modkey, "Shift" }, "f", function()
        if client.focus then
            client.focus.fullscreen = not client.focus.fullscreen
            client.focus:raise()
        end
    end),

    awful.key({ altkey }, "Tab", function()
        awful.client.focus.byidx(1)

        if client.focus then client.focus:raise() end
        local t = awful.screen.focused().selected_tag

        clients = t:clients()
    end),

    awful.key({ altkey, "Shift" }, "Tab", function()
        awful.client.focus.byidx(-1)
        if client.focus then client.focus:raise() end
    end),

    awful.key({}, "XF86AudioRaiseVolume",
        function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ +10%") end),
    awful.key({}, "XF86AudioLowerVolume",
        function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ -10%") end),
    awful.key({}, "XF86AudioMute",
        function() awful.spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle") end),
    awful.key({}, "XF86AudioMicMute",
        function() awful.spawn("pactl set-source-mute @DEFAULT_SOURCE@ toggle") end)
)

-- set up keybindings for tags (workspaces)
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

-- connect signals
client.connect_signal("manage", function(c)
    if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
        awful.placement.no_offscreen(c)
    end

    -- check if window is large enough to auto-fullscreen (delayed to let geometry settle)
    gears.timer.delayed_call(function()
        if c.valid then
            check_window_size(c)
            force_instance_rules(c)
        end
    end)
end)

client.connect_signal("focus", function(c)
    c.border_color = beautiful.border_focus
end)

client.connect_signal("unfocus", function(c)
    c.border_color = beautiful.border_normal
end)

local function get_workarea(c)
    return c.screen.workarea
end

local function check_window_size(c)
    if c.fullscreen or c.maximized then return end

    local wa = get_workarea(c)
    local geo = c:geometry()

    local width_ratio = geo.width / wa.width
    local height_ratio = geo.height / wa.height

    -- if window is bigger than threshold, maximize it
    if width_ratio >= FULLSCREEN_THRESHOLD and height_ratio >= FULLSCREEN_THRESHOLD then
        c.maximized = true
    end
end

local function should_force_fullscreen(c)
    if not c or not c.valid then return false end
    local class = (c.class or ""):lower()
    local name = (c.name or ""):lower()

    for _, p in ipairs(ALWAYS_FULLSCREEN_APPS) do
        if class:match(p) or name:match(p) then
            return true
        end
    end
    return false
end

local function force_instance_rules(c)
    if not c or not c.valid then return end

    -- force the bastard to behave
    if should_force_fullscreen(c) then
        c.fullscreen = true
        c.floating = false
        c.minimized = false
        c.hidden = false
        c:raise()
    end
end

local function resize_to_sane_size(c)
    -- never resize apps that should be fullscreen
    if should_force_fullscreen(c) then return end

    local wa = get_workarea(c)
    local geo = c:geometry()

    local width_ratio = geo.width / wa.width
    local height_ratio = geo.height / wa.height

    -- only resize if the window is still too big
    if width_ratio >= FULLSCREEN_THRESHOLD or height_ratio >= FULLSCREEN_THRESHOLD then
        local new_width = math.floor(wa.width * SANE_SIZE_RATIO)
        local new_height = math.floor(wa.height * SANE_SIZE_RATIO)

        c:geometry({
            x = wa.x + math.floor((wa.width - new_width) / 2),
            y = wa.y + math.floor((wa.height - new_height) / 2),
            width = new_width,
            height = new_height
        })
    end
end

local function enforce_tag_rules(t)
    if not t then return end
    for _, c in ipairs(t:clients()) do
        force_instance_rules(c)
    end
end

-- hack to prevent polybar from showing up when a fullscreen window is open (works 50% of the time...)
local function update_polybar()
    local current_tag = awful.screen.focused().selected_tag
    if not current_tag then return end

    local should_hide = false
    for _, c in ipairs(current_tag:clients()) do
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

client.connect_signal("property::fullscreen", function(c)
    c.border_width = c.fullscreen and 0 or beautiful.border_width
    update_polybar()

    -- when exiting fullscreen, resize to avoid infinite loop
    if not c.fullscreen then
        resize_to_sane_size(c)
    end
end)

client.connect_signal("property::maximized", function(c)
    c.border_width = c.maximized and 0 or beautiful.border_width
end)

tag.connect_signal("property::selected", function(t)
    update_polybar()

    if t.selected then
        for _, c in ipairs(t:clients()) do
            check_window_size(c)
        end

        -- delay a bit so wine/games have time to process the workspace change
        gears.timer({
            timeout = 0.1,
            autostart = true,
            single_shot = true,
            callback = function()
                enforce_tag_rules(t)
            end
        })
    end
end)

client.connect_signal("unmanage", function()
    update_polybar()
end)

awful.rules.rules = {
    {
        rule = { },
        properties = {
            border_width = beautiful.border_width,
            border_color = beautiful.border_normal,
            focus        = awful.client.focus.filter,
            placement    = awful.placement.centered,
            raise        = true,
            floating     = true,
            maximized    = false,
            fullscreen   = false,
            buttons      = clientbuttons
        }
    },
    {
        rule_any = { class = { "Polybar", "polybar" } },
        properties = {
            border_width = 0,
            focusable = false,
            skip_taskbar = true,
        }
    },
    {
        rule_any = {
            class = {
                "steam_app_.*",
                "steam_proton",
                "Wine",
                "wine",
                "osu!.exe",
                "battle.net.exe",
                "epicgameslauncher"
            }
        },
        properties = {
            fullscreen = true,
            raise=true,
            floating   = false
        }
    }
}

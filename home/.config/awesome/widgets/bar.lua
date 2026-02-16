local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

local bar = {}

local REFRESH_INTERVAL_SEC = 2
local VOLUME_STEP = "10%"
local SYSTRAY_ICON_SIZE = 16
local SYSTRAY_MARGIN_PX = 8
local SYSTRAY_VERTICAL_MARGIN = 7
local ROUNDED_CORNER_RADIUS = 6
local TITLE_MAX_LENGTH = 50
local TITLE_REFRESH_DEBOUNCE_SEC = 0.08
local TAGLIST_MIN_WORKSPACES = 3

-- workspace icons
local WORKSPACE_ICONS = { "", "", "", "", "", "" }

local function create_separator()
    return wibox.widget {
        markup = "<span foreground='" .. beautiful.color_separator .. "'>|</span>",
        font = beautiful.font,
        widget = wibox.widget.textbox
    }
end

local function create_cpu_widget()
    local cpu_widget = wibox.widget {
        markup = "<span foreground='" .. beautiful.color_label .. "'>󰻠  0%</span>",
        font = beautiful.font,
        widget = wibox.widget.textbox
    }

    awful.widget.watch("sh -c \"top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1\"", REFRESH_INTERVAL_SEC, function(widget, stdout)
        local cpu = tonumber(stdout) or 0
        widget.markup = string.format("<span foreground='%s'>󰻠  %.0f%%</span>", beautiful.color_label, cpu)
    end, cpu_widget)

    return cpu_widget
end

local function create_memory_widget()
    local mem_widget = wibox.widget {
        markup = "<span foreground='" .. beautiful.color_label .. "'>󰍛  0%</span>",
        font = beautiful.font,
        widget = wibox.widget.textbox
    }

    awful.widget.watch("sh -c \"free | grep Mem | awk '{print ($3/$2) * 100.0}'\"", REFRESH_INTERVAL_SEC, function(widget, stdout)
        local mem = tonumber(stdout) or 0
        widget.markup = string.format("<span foreground='%s'>󰍛  %.0f%%</span>", beautiful.color_label, mem)
    end, mem_widget)

    return mem_widget
end

local function create_volume_widget()
    local vol_widget = wibox.widget {
        markup = "<span foreground='" .. beautiful.color_label .. "'>󰕾  0%</span>",
        font = beautiful.font,
        widget = wibox.widget.textbox
    }

    local function update_volume()
        awful.spawn.easy_async_with_shell("pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\\d+%' | head -1", function(stdout)
            local vol = stdout:match("(%d+)%%") or "0"

            awful.spawn.easy_async_with_shell("pactl get-sink-mute @DEFAULT_SINK@", function(mute_out)
                local is_muted = mute_out:match("yes") ~= nil
                local icon = is_muted and "󰖁" or "󰕾"
                vol_widget.markup = string.format("<span foreground='%s'>%s  %s%%</span>", beautiful.color_label, icon, vol)
            end)
        end)
    end

    update_volume()

    -- update volume every 500ms
    gears.timer {
        timeout = 0.5,
        autostart = true,
        callback = update_volume
    }

    vol_widget:buttons(gears.table.join(
        awful.button({}, 1, function()
            awful.spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle")
            gears.timer.start_new(0.1, function() update_volume() return false end)
        end),
        awful.button({}, 3, function()
            awful.spawn("pavucontrol")
        end),
        awful.button({}, 4, function()
            awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ +" .. VOLUME_STEP)
            gears.timer.start_new(0.1, function() update_volume() return false end)
        end),
        awful.button({}, 5, function()
            awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ -" .. VOLUME_STEP)
            gears.timer.start_new(0.1, function() update_volume() return false end)
        end)
    ))

    return vol_widget
end

local function create_date_widget()
    return wibox.widget {
        format = "<span foreground='" .. beautiful.color_label .. "'>󰥔  %H:%M</span>",
        font = beautiful.font,
        widget = wibox.widget.textclock
    }
end

function bar.create(s)
    -- custom filter to show min X workspaces, only occupied ones
    local function taglist_filter(t)
        local screen_tags = s.tags
        local last_occupied = 0

        for i, tag in ipairs(screen_tags) do
            if #tag:clients() > 0 or tag.selected then
                last_occupied = i
            end
        end

        local show_until = math.max(TAGLIST_MIN_WORKSPACES, last_occupied)
        return t.index <= show_until
    end

    -- taglist widget
    local taglist = awful.widget.taglist {
        screen = s,
        filter = taglist_filter,
        buttons = gears.table.join(
            awful.button({}, 1, function(t) t:view_only() end),
            awful.button({ MODKEY }, 1, function(t)
                if client.focus then
                    client.focus:move_to_tag(t)
                end
            end),
            awful.button({}, 4, function(t) awful.tag.viewnext(t.screen) end),
            awful.button({}, 5, function(t) awful.tag.viewprev(t.screen) end)
        ),
        widget_template = {
            {
                {
                    id = 'text_role',
                    widget = wibox.widget.textbox,
                },
                left = 8,
                right = 8,
                widget = wibox.container.margin
            },
            id = 'background_role',
            widget = wibox.container.background,
            create_callback = function(self, tag, index, objects)
                local icon_index = index <= #WORKSPACE_ICONS and index or #WORKSPACE_ICONS
                self:get_children_by_id('text_role')[1].markup =
                    "<span foreground='" .. beautiful.color_inactive .. "'>" .. WORKSPACE_ICONS[icon_index] .. "</span>"
                self:get_children_by_id('text_role')[1].font = beautiful.taglist_font
            end,
            update_callback = function(self, tag, index, objects)
                local icon_index = index <= #WORKSPACE_ICONS and index or #WORKSPACE_ICONS
                local color = beautiful.color_inactive

                if tag.selected then
                    color = beautiful.color_active
                elseif #tag:clients() > 0 then
                    color = beautiful.color_accent
                end

                self:get_children_by_id('text_role')[1].markup =
                    "<span foreground='" .. color .. "'>" .. WORKSPACE_ICONS[icon_index] .. "</span>"
            end
        }
    }

    -- window title widget
    local window_title = wibox.widget {
        markup = "<span foreground='" .. beautiful.color_label .. "'>Desktop</span>",
        font = beautiful.font,
        widget = wibox.widget.textbox
    }

    local function update_title(c)
        local title = (c and c.name) or "Desktop"
        if #title > TITLE_MAX_LENGTH then
            title = title:sub(1, TITLE_MAX_LENGTH - 3) .. "..."
        end
        window_title.markup = "<span foreground='" .. beautiful.color_label .. "'>" .. gears.string.xml_escape(title) .. "</span>"
    end

    local function refresh_title()
        update_title(client.focus)
    end

    local title_refresh_timer = gears.timer {
        timeout = TITLE_REFRESH_DEBOUNCE_SEC,
        autostart = false,
        single_shot = true,
        callback = refresh_title
    }

    local function queue_title_refresh()
        if title_refresh_timer.started then
            title_refresh_timer:again()
            return
        end

        title_refresh_timer:start()
    end

    client.connect_signal("focus", queue_title_refresh)
    client.connect_signal("unfocus", queue_title_refresh)
    client.connect_signal("property::active", queue_title_refresh)
    client.connect_signal("property::name", function(c)
        if c.active or client.focus == c then
            queue_title_refresh()
        end
    end)
    client.connect_signal("unmanage", queue_title_refresh)
    tag.connect_signal("property::selected", function(t)
        if t.screen == s then
            queue_title_refresh()
        end
    end)

    refresh_title()

    -- systray with rounded box
    local systray = wibox.widget.systray()
    systray:set_base_size(SYSTRAY_ICON_SIZE)

    local systray_container = wibox.widget {
        {
            {
                {
                    systray,
                    left = SYSTRAY_MARGIN_PX,
                    right = SYSTRAY_MARGIN_PX,
                    widget = wibox.container.margin
                },
                valign = "center",
                widget = wibox.container.place
            },
            bg = beautiful.bg_systray,
            shape = function(cr, width, height)
                gears.shape.rounded_rect(cr, width, height, ROUNDED_CORNER_RADIUS)
            end,
            widget = wibox.container.background
        },
        top = SYSTRAY_VERTICAL_MARGIN,
        bottom = SYSTRAY_VERTICAL_MARGIN,
        widget = wibox.container.margin
    }

    -- create the wibar
    s.mywibox = awful.wibar({
        position = "bottom",
        screen = s,
        height = beautiful.wibar_height,
        bg = beautiful.wibar_bg,
        fg = beautiful.wibar_fg,
        ontop = false,
        restrict_workarea = true
    })

    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        {
            layout = wibox.layout.fixed.horizontal,
            spacing = 10,
            {
                widget = wibox.container.margin,
                left = 5,
                taglist
            },
            create_separator(),
            window_title
        },
        nil,
        {
            layout = wibox.layout.fixed.horizontal,
            spacing = 10,
            systray_container,
            create_cpu_widget(),
            create_memory_widget(),
            create_volume_widget(),
            create_date_widget(),
            {
                widget = wibox.container.margin,
                right = 10
            }
        }
    }
end

return bar

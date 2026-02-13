local awful = require("awful")
local gears = require("gears")
local colors = require("helpers.colors")
local wibox = require("wibox")
local beautiful = require("beautiful")
local cairo = require("lgi").cairo

local MIN_CLIENT_AMT = 1
local CARD_WIDTH = 180
local CARD_HEIGHT = 100
local CARD_SPACING = 10
local BOX_MARGIN = 10
local HISTORY_SCAN_LIMIT = 200

local Tab = {}
Tab.__index = Tab

local function is_client_valid(c)
    -- client valid guard: https://awesomewm.org/apidoc/core_components/client.html
    if not c then
        return false
    end
    local ok, valid = pcall(function() return c.valid end)
    return ok and valid
end

function Tab.new()
    local self = setmetatable({}, Tab)
    self.visible = false
    self.box = nil
    self.selected_idx = 1
    self.keygrabber = nil
    self.history_tracking_paused = false
    self.in_stop_callback = false
    self.snapshot_clients = {}
    return self
end

function Tab:create(s)
    self.box = wibox({
        width = 1,
        height = 1,
        ontop = true,
        visible = false,
        screen = s,
        bg = beautiful.bg_normal,
        shape = function(cr, w, h)
            gears.shape.rounded_rect(cr, w, h, 8)
        end
    })

    self.keygrabber = awful.keygrabber {
        keybindings = {
            awful.key {
                modifiers = { "Mod1" },
                key = "Tab",
                on_press = function()
                    self:next()
                end
            },
            awful.key {
                modifiers = { "Mod1", "Shift" },
                key = "Tab",
                on_press = function()
                    self:prev()
                end
            },
            awful.key {
                modifiers = {},
                key = "Right",
                on_press = function()
                    self:next()
                end
            },
            awful.key {
                modifiers = {},
                key = "Left",
                on_press = function()
                    self:prev()
                end
            }
        },
        stop_key = { "Alt_L", "Alt_R" },
        stop_event = "release",
        start_callback = function()
            if not self.history_tracking_paused then
                awful.client.focus.history.disable_tracking()
                self.history_tracking_paused = true
            end
        end,
        stop_callback = function()
            if self.history_tracking_paused then
                pcall(awful.client.focus.history.enable_tracking)
                self.history_tracking_paused = false
            end
            self.in_stop_callback = true
            self:select()
            self.in_stop_callback = false
        end
    }
end

local function create_fallback_icon(c, size)
    local surface = cairo.ImageSurface(cairo.Format.ARGB32, size, size)
    local cr = cairo.Context(surface)

    local color = colors.hash_color(c.name or c.class)
    local r, g, b = gears.color.parse_color(color)

    cr:set_source_rgb(r, g, b)
    cr:paint()

    local text = ((c.name or c.class or ""):sub(1, 1)):upper()

    if text ~= "" then
        cr:select_font_face(beautiful.taglist_font, cairo.FontSlant.NORMAL, cairo.FontWeight.BOLD)
        cr:set_font_size(size * 0.5)

        local extents = cr:text_extents(text)
        local x = (size - extents.width) / 2 - extents.x_bearing
        local y = (size - extents.height) / 2 - extents.y_bearing

        cr:set_source_rgb(1, 1, 1)
        cr:move_to(x, y)
        cr:show_text(text)
    end

    return surface
end

local function get_client_icon_widget(c, size)
    if not is_client_valid(c) then
        local img = wibox.widget.imagebox()
        img:set_image(create_fallback_icon({}, size or 64))
        return img
    end

    local icon = c.icon

    if icon then
        local ok, widget = pcall(awful.widget.clienticon, c)
        if ok and widget then
            return widget
        end
    end

    local img = wibox.widget.imagebox()
    img:set_image(create_fallback_icon(c, size or 64))
    return img
end

function Tab:show(screen)
    local s = screen or awful.screen.focused()

    if not self.box then
        self:create(s)
    end

    if self.box.screen ~= s then
        self.box.screen = s
    end

    local tag = s.selected_tag
    if not tag then return end

    if not awful.client.focus.history.is_enabled() then
        pcall(awful.client.focus.history.enable_tracking)
        self.history_tracking_paused = false
    end

    local tag_clients = tag:clients()
    if #tag_clients < MIN_CLIENT_AMT then return end

    local by_tag = {}
    for _, tc in ipairs(tag_clients) do
        if is_client_valid(tc) then
            by_tag[tc] = true
        end
    end

    self.snapshot_clients = {}
    local seen = {}

    for idx = 0, HISTORY_SCAN_LIMIT do
        local c = awful.client.focus.history.get(s, idx)
        if not c then break end

        if is_client_valid(c) and by_tag[c] and not seen[c] then
            table.insert(self.snapshot_clients, c)
            seen[c] = true
        end
    end

    for _, c in ipairs(tag_clients) do
        if is_client_valid(c) and not seen[c] then
            table.insert(self.snapshot_clients, c)
            seen[c] = true
        end
    end

    if #self.snapshot_clients < MIN_CLIENT_AMT then return end

    self.selected_idx = 2
    if self.selected_idx > #self.snapshot_clients then
        self.selected_idx = 1
    end

    self:update()
    self.box.visible = true
    self.visible = true

    -- start keygrabber
    if self.keygrabber then
        self.keygrabber:start()
    end
end

function Tab:update()
    if not self.box then return end

    local valid_clients = {}
    for _, c in ipairs(self.snapshot_clients) do
        if is_client_valid(c) then
            table.insert(valid_clients, c)
        end
    end
    self.snapshot_clients = valid_clients

    if #self.snapshot_clients < MIN_CLIENT_AMT then
        self:hide()
        return
    end

    if self.selected_idx < 1 then
        self.selected_idx = 1
    elseif self.selected_idx > #self.snapshot_clients then
        self.selected_idx = #self.snapshot_clients
    end

    local layout = wibox.layout.flex.horizontal()
    layout.spacing = CARD_SPACING

    for i, c in ipairs(self.snapshot_clients) do
        local is_selected = (i == self.selected_idx)

        local client_widget = wibox.widget {
            {
                get_client_icon_widget(c, 64),
                forced_width = 64,
                forced_height = 64,
                widget = wibox.container.place
            },
            {
                {
                    text = c.name or c.class or "Unknown",
                    align = "center",
                    widget = wibox.widget.textbox
                },
                left = 6,
                right = 6,
                widget = wibox.container.margin
            },
            layout = wibox.layout.fixed.vertical,
            spacing = 6
        }

        layout:add(
            wibox.widget {
                client_widget,
                forced_width = CARD_WIDTH,
                forced_height = CARD_HEIGHT,
                bg = is_selected and beautiful.bg_focus or beautiful.bg_normal,
                border_width = is_selected and 2 or 0,
                border_color = beautiful.border_focus,
                shape = function(cr, w, h)
                    gears.shape.rounded_rect(cr, w, h, 6)
                end,
                widget = wibox.container.background
            }
        )
    end

    local count = #self.snapshot_clients

    local content_width =
        (count * CARD_WIDTH) +
        ((count - 1) * CARD_SPACING) +
        (BOX_MARGIN * 2)

    local content_height =
        CARD_HEIGHT + (BOX_MARGIN * 2)

    self.box.width = math.max(200, content_width)
    self.box.height = math.max(100, content_height)

    self.box:setup {
        {
            layout,
            halign = "center",
            valign = "center",
            widget = wibox.container.place
        },
        margins = 10,
        widget = wibox.container.margin
    }

    awful.placement.centered(self.box, { parent = self.box.screen })
end

function Tab:next()
    if not self.visible then return end
    if #self.snapshot_clients < MIN_CLIENT_AMT then
        self:hide()
        return
    end

    self.selected_idx = self.selected_idx + 1
    if self.selected_idx > #self.snapshot_clients then
        self.selected_idx = 1
    end

    self:update()
end

function Tab:prev()
    if not self.visible then return end
    if #self.snapshot_clients < MIN_CLIENT_AMT then
        self:hide()
        return
    end

    self.selected_idx = self.selected_idx - 1

    if self.selected_idx < 1 then
        self.selected_idx = #self.snapshot_clients
    end

    self:update()
end

function Tab:select()
    if not self.visible then return end
    if #self.snapshot_clients < MIN_CLIENT_AMT then
        self:hide()
        return
    end

    local c = self.snapshot_clients[self.selected_idx]

    if is_client_valid(c) then
        pcall(function()
            c:activate({ context = "tab-switcher", raise = true })
        end)
    end

    self:hide()
end

function Tab:hide()
    if not self.box then return end

    self.box.visible = false
    self.visible = false
    self.snapshot_clients = {}
    self.selected_idx = 1

    if self.history_tracking_paused then
        pcall(awful.client.focus.history.enable_tracking)
        self.history_tracking_paused = false
    end

    if self.keygrabber and not self.in_stop_callback then
        self.keygrabber:stop()
    end
end

return Tab.new()

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

local Tab = {}
Tab.__index = Tab

function Tab.new()
    local self = setmetatable({}, Tab)
    self.visible = false
    self.box = nil
    self.selected_idx = 1
    self.keygrabber = nil
    self.snapshot_clients = {}
    return self
end

function Tab:create(s)
    -- create popup box
    self.box = wibox({
        width = 1,  -- calculated on :update
        height = 1, -- calculated on :update
        ontop = true,
        visible = false,
        screen = s,
        bg = beautiful.bg_normal,
        shape = function(cr, w, h)
            gears.shape.rounded_rect(cr, w, h, 8)
        end
    })

    -- add keygrabber to handle navigation
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
        stop_key = "Mod1",
        stop_event = "release",
        keypressed_callback = function() end,
        keyreleased_callback = function() end,
        stop_callback = function()
            self:select()
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

    -- draw first letter if available
    local text = ""

    if c.name then
        text = c.name:sub(1, 1):upper()
    end

    if c.class and text == "" then
        text = c.class:sub(1, 1):upper()
    end

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
    local icon = c.icon

    if icon then
        return awful.widget.clienticon(c)
    else
        -- use fallback
        local img = wibox.widget.imagebox()
        img:set_image(create_fallback_icon(c, size or 64))
        return img
    end
end

function Tab:show(screen)
    if not self.box then
        self:create(screen)
    end

    -- get current tag
    local tag = awful.screen.focused().selected_tag
    if not tag then return end

    local tag_clients = tag:clients()
    if #tag_clients < MIN_CLIENT_AMT then return end

    -- snapshot focus.history for current tag
    -- index starts at 0 (current focus), 1 (previous), etc
    self.snapshot_clients = {}

    for idx = 0, 50 do
        local c = awful.client.focus.history.get(screen, idx)
        if not c then break end

        -- filter: must be on current tag
        local in_tag = false
        for _, tc in ipairs(tag_clients) do
            if tc == c then
                in_tag = true
                break
            end
        end

        if in_tag then
            table.insert(self.snapshot_clients, c)
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

    local layout = wibox.layout.flex.horizontal()
    layout.spacing = 10

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
                    text = c.name or "Unknown",
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

    self.selected_idx = self.selected_idx + 1
    if self.selected_idx > #self.snapshot_clients then
        self.selected_idx = 1
    end

    self:update()
end

function Tab:prev()
    if not self.visible then return end

    self.selected_idx = self.selected_idx - 1

    if self.selected_idx < 1 then
        self.selected_idx = #self.snapshot_clients
    end

    self:update()
end

function Tab:select()
    if not self.visible then return end

    local c = self.snapshot_clients[self.selected_idx]

    if c then
        c:activate({ context = "tab-switcher", raise = true })
    end

    self:hide()
end

function Tab:hide()
    if not self.box then return end

    self.box.visible = false
    self.visible = false
    self.snapshot_clients = {}
    self.selected_idx = 1

    -- stop keygrabber
    if self.keygrabber then
        self.keygrabber:stop()
    end
end

return Tab.new()

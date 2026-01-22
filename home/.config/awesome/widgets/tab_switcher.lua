local awful = require("awful")
local gears = require("gears")
local dbg = require("helpers.custom_debug")
local wibox = require("wibox")
local beautiful = require("beautiful")

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
    self.clients = {}
    self.selected_idx = 1
    self.keygrabber = nil
    return self
end

function Tab:create(s)
    -- create popup box
    self.box = wibox({
        width = 1, -- calculated on :update
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
                modifiers = {"Mod1"},
                key = "Tab",
                on_press = function()
                    self:next()
                end
            },
            awful.key {
                modifiers = {"Mod1", "Shift"},
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

function Tab:show(screen)
    if not self.box then
        self:create(screen)
    end

    -- get current tag clients
    local tag = awful.screen.focused().selected_tag
    if not tag then return end

    self.clients = tag:clients()

    -- if we dont have enough clients, ignore
    if #self.clients < 2 then return end

    -- default to first one
    self.selected_idx = 1

    local focused = client.focus

    if focused then
        for i, c in ipairs(self.clients) do
            if c == focused then
                -- get next client relative to focused
                self.selected_idx = i + 1
                if self.selected_idx > #self.clients then
                    self.selected_idx = 1
                end
                break
            end
        end
    end

    if #self.clients < 2 then
        self.selected_idx = 1
    end

    -- dbg.notify("tab: using idx " .. self.selected_idx, 10)

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

    for i, c in ipairs(self.clients) do
        local is_selected = (i == self.selected_idx)

        local client_widget = wibox.widget {
            {
                awful.widget.clienticon(c),
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

    local count = #self.clients

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
    if self.selected_idx > #self.clients then
        self.selected_idx = 1
    end

    self:update()
end

function Tab:prev()
    if not self.visible then return end

    self.selected_idx = self.selected_idx - 1
    if self.selected_idx < 1 then
        self.selected_idx = #self.clients
    end

    self:update()
end

function Tab:select()
    if not self.visible then return end

    local c = self.clients[self.selected_idx]
    if c then
        c:activate({ context = "tab-switcher", raise = true })
    end

    self:hide()
end

function Tab:hide()
    if not self.box then return end

    self.box.visible = false
    self.visible = false
    self.clients = {}
    self.selected_idx = 1

    -- stop keygrabber
    if self.keygrabber then
        self.keygrabber:stop()
    end
end

return Tab

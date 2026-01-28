local awful = require("awful")
local gears = require("gears")
local lfs = require("lfs")
local wibox = require("wibox")
local dbg = require("helpers.custom_debug")
local beautiful = require("beautiful")

DEFAULT_IMAGE_WIDTH = 256
DEFAULT_IMAGE_HEIGHT = 144
WALLPAPERS_DIR = os.getenv("HOME") .. "/wallpapers"

local Wallpapers = {}
Wallpapers.__index = Wallpapers

function Wallpapers.new()
    local self = setmetatable({}, Wallpapers)
    self.visible = false
    self.box = nil
    self.selected_idx = 1
    self.keygrabber = nil
    self.files = {}
    self.containers = {}
    self.title = nil
    self.layout = nil
    self.items_per_row = 0
    return self
end

function Wallpapers:scan_directory()
    self.files = {}

    if not gears.filesystem.dir_readable(WALLPAPERS_DIR) then
        return false
    end

    local allowed_exts = {
        ["jpg"] = true,
        ["jpeg"] = true,
        ["png"] = true
    }

    for file in lfs.dir(WALLPAPERS_DIR) do
        if file and file ~= "." and file ~= ".." then
            local path = WALLPAPERS_DIR .. "/" .. file
            local attrs = lfs.attributes(path)

            if type(attrs) == "table" and attrs.mode == "file" then
                local ext = file:match("%.([^%.]+)$")
                if ext and allowed_exts[ext:lower()] then
                    table.insert(self.files, path)
                end
            end
        end
    end

    return #self.files > 0
end

function Wallpapers:create(s)
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
                modifiers = {},
                key = "Right",
                on_press = function()
                    self:navigate(1)
                end
            },
            awful.key {
                modifiers = {},
                key = "Left",
                on_press = function()
                    self:navigate(-1)
                end
            },
            awful.key {
                modifiers = {},
                key = "Escape",
                on_press = function()
                    self:hide()
                end
            },
            awful.key {
                modifiers = {},
                key = "Return",
                on_press = function()
                    self:apply_wallpaper()
                end
            }
        }
    }
end

function Wallpapers:show(s)
    if not self.box then
        self:create(s)
    end

    if #self.files == 0 then
        dbg.notify("no wallpapers found in " .. WALLPAPERS_DIR, 5)
        return
    end

    self:build_ui()
    self.box.visible = true
    self.visible = true

    if self.keygrabber then
        self.keygrabber:start()
    end
end

function Wallpapers:update_visible_range()
    if not self.layout then return end

    -- calculate which wallpapers should be visible based on selected index
    local start_idx = math.floor((self.selected_idx - 1) / self.items_per_row) * self.items_per_row + 1
    local end_idx = math.min(start_idx + self.items_per_row - 1, #self.files)

    -- clear and rebuild
    self.layout:reset()
    self.containers = {}

    for i = start_idx, end_idx do
        local is_selected = (i == self.selected_idx)
        local container = self:create_image_container(self.files[i], is_selected)

        -- store with adjusted index for the visible window
        self.containers[i - start_idx + 1] = container
        self.layout:add(container)
    end
end

function Wallpapers:create_image_container(filepath, is_selected)
    local img_box = wibox.widget {
        image = filepath,
        resize = true,
        forced_width = DEFAULT_IMAGE_WIDTH,
        forced_height = DEFAULT_IMAGE_HEIGHT,
        widget = wibox.widget.imagebox
    }

    return wibox.widget {
        img_box,
        forced_width = DEFAULT_IMAGE_WIDTH,
        forced_height = DEFAULT_IMAGE_HEIGHT,
        bg = is_selected and beautiful.bg_focus or beautiful.bg_normal,
        border_width = is_selected and 2 or 0,
        border_color = beautiful.border_focus,
        shape = function(cr, w, h)
            gears.shape.rounded_rect(cr, w, h, 6)
        end,
        widget = wibox.container.background
    }
end

function Wallpapers:navigate(direction)
    if not self.visible then return end

    local old_idx = self.selected_idx
    self.selected_idx = self.selected_idx + direction

    -- wrap around
    if self.selected_idx > #self.files then
        self.selected_idx = 1
    elseif self.selected_idx < 1 then
        self.selected_idx = #self.files
    end

    -- check if we need to load new images (moved to different window)
    local old_window = math.floor((old_idx - 1) / self.items_per_row)
    local new_window = math.floor((self.selected_idx - 1) / self.items_per_row)

    if old_window ~= new_window then
        self:update_visible_range()
    else
        -- just update border/bg on existing widgets
        local old_container_idx = ((old_idx - 1) % self.items_per_row) + 1
        local new_container_idx = ((self.selected_idx - 1) % self.items_per_row) + 1

        if self.containers[old_container_idx] then
            self.containers[old_container_idx].bg = beautiful.bg_normal
            self.containers[old_container_idx].border_width = 0
        end

        if self.containers[new_container_idx] then
            self.containers[new_container_idx].bg = beautiful.bg_focus
            self.containers[new_container_idx].border_width = 2
        end
    end

    if self.title then
        self.title.markup = "<b>Select a wallpaper (" .. self.selected_idx .. "/" .. #self.files .. ")</b>"
    end
end

function Wallpapers:apply_wallpaper()
    if #self.files == 0 then return end

    local selected = self.files[self.selected_idx]
    if selected then
        awful.spawn.with_shell("feh --bg-fill '" .. selected .. "'")
        self:hide()
    end
end

function Wallpapers:build_ui()
    if not self.box or type(self.box) ~= "table" then
        return
    end

    local screen_geo = self.box.screen.workarea
    local max_width = math.floor(screen_geo.width * 0.8)
    local single_item_width = DEFAULT_IMAGE_WIDTH + 10
    self.items_per_row = math.max(1, math.floor((max_width - 20) / single_item_width))

    self.layout = wibox.layout.fixed.horizontal()
    self.layout.spacing = 10
    self.containers = {}

    -- only load first batch
    local display_count = math.min(self.items_per_row, #self.files)

    for i = 1, display_count do
        local is_selected = (i == self.selected_idx)
        local container = self:create_image_container(self.files[i], is_selected)
        self.containers[i] = container
        self.layout:add(container)
    end

    local content_width = (display_count * DEFAULT_IMAGE_WIDTH) + ((display_count - 1) * 10) + 20
    local content_height = DEFAULT_IMAGE_HEIGHT + 40

    self.box.width = content_width
    self.box.height = content_height

    self.title = wibox.widget {
        markup = "<b>Select a wallpaper (" .. self.selected_idx .. "/" .. #self.files .. ")</b>",
        align = "center",
        widget = wibox.widget.textbox
    }

    self.box:setup {
        {
            self.title,
            {
                self.layout,
                halign = "center",
                valign = "center",
                widget = wibox.container.place
            },
            spacing = 10,
            layout = wibox.layout.fixed.vertical
        },
        margins = 10,
        widget = wibox.container.margin
    }

    awful.placement.centered(self.box, { parent = self.box.screen })
end

function Wallpapers:hide()
    if not self.box then return end

    if self.keygrabber then
        self.keygrabber:stop()
    end

    self.box.visible = false
    self.visible = false
    self.containers = {}
end

return Wallpapers.new()

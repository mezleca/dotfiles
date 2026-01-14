local awful = require("awful")
local naughty = require("naughty")
local dbg = require("__debug")

local M = {}

-- create state table
local WindowState = { visible = false }

function WindowState.toggle_visibility(self)
	self.visible = not self.visible
end

local Windows = {}

function M.load(s)
    dbg.notify("load:", "screen " .. tostring(s.index), 10)

    -- create / setup a box for each screen
    -- local box = awful.wibox({
    --     height = 100,
    --     border_width = 0,
    --     border_color = "#000000",
    --     ontop = true,
    --     screen = s,
    --     fg = "#ffffff",
    --     bg = "#1e1e1e",
    --     x = 0,
    --     y = 0
    -- })

    -- Windows[s] = {
    --     state = WindowState,
    --     box = box
    -- }
end

return M

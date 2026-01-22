local naughty = require("naughty")
local M = {}

local function dump(o, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)

    if type(o) ~= "table" then
        return tostring(o)
    end

    local s = "{\n"

    for k, v in pairs(o) do
        s = s .. pad .. "  " .. tostring(k) .. " = " .. dump(v, indent + 1) .. ",\n"
    end

    return s .. pad .. "}"
end

function M.notify(text, timeout)
    naughty.notification({
        title = "debug",
        message = text or "",
        timeout = timeout or 5
    })
end

function M.t_from_obj(data)
    return dump(data)
end

return M

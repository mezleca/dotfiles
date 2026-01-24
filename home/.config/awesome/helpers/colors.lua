local M = {}

function M.hash_color(str)
    if not str then return "#888888" end

    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 16777216
    end

    local r = (hash % 256) / 255
    local g = ((hash // 256) % 256) / 255
    local b = ((hash // 65536) % 256) / 255

    -- boost saturation
    local max_val = math.max(r, g, b)
    local min_val = math.min(r, g, b)
    local delta = max_val - min_val

    if delta > 0 then
        local factor = 1.5
        r = min_val + (r - min_val) * factor
        g = min_val + (g - min_val) * factor
        b = min_val + (b - min_val) * factor
    end

    r = math.min(1, math.max(0.3, r))
    g = math.min(1, math.max(0.3, g))
    b = math.min(1, math.max(0.3, b))

    return string.format("#%02x%02x%02x",
        math.floor(r * 255),
        math.floor(g * 255),
        math.floor(b * 255)
    )
end

return M

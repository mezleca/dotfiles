local theme = {}

-- darker theme colors
theme.bg_normal = "#0A0C10"
theme.fg_normal = "#ffffff"
theme.fg_focus = "#ffffff"
theme.fg_urgent = "#ff5555"

theme.border_width = 3
theme.border_focus = "#3d466b"
theme.border_normal = "#333333"

-- custom colors for widgets
theme.color_separator = "#555555"
theme.color_active = "#ffffff"
theme.color_inactive = "#555555"
theme.color_label = "#dddddd"
theme.color_accent = "#888888"

-- fonts
theme.font = "Manrope ExtraBold 10"
theme.taglist_font = "Manrope ExtraBold 12"

-- taglist (remove squares/icons)
theme.taglist_squares_sel = nil
theme.taglist_squares_unsel = nil
theme.taglist_squares_sel_empty = nil
theme.taglist_squares_unsel_empty = nil
theme.taglist_disable_icon = true

-- taglist colors
theme.taglist_fg_focus = theme.color_active
theme.taglist_bg_focus = "transparent"
theme.taglist_fg_occupied = theme.color_accent
theme.taglist_bg_occupied = "transparent"
theme.taglist_fg_empty = theme.color_inactive
theme.taglist_bg_empty = "transparent"
theme.taglist_fg_urgent = theme.fg_urgent
theme.taglist_bg_urgent = "transparent"

-- wibar
theme.wibar_bg = theme.bg_normal
theme.wibar_fg = theme.fg_normal
theme.wibar_height = 38

-- systray
theme.systray_icon_spacing = 5
theme.bg_systray = "#1a1a1a"

return theme

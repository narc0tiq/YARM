data:extend({

    -- Startup settings
    {
        type = "bool-setting",
        name = "YARM-make-fake-ores",
        setting_type = "startup",
        default_value = false
    },

    -- Global settings
    {
        type = "int-setting",
        name = "YARM-ticks-between-checks",
        setting_type = "runtime-global",
        order = "a",
        default_value = 600,
        minimum_value = 20,
        maximum_value = 1200
    },
    {
        type = "int-setting",
        name = "YARM-entities-per-tick",
        setting_type = "runtime-global",
        order = "a",
        default_value = 100,
        minimum_value = 10,
        maximum_value = 1000,
    },
    {
        type = "bool-setting",
        name = "YARM-map-markers",
        setting_type = "runtime-global",
        order = "b",
        default_value = true,
    },
    {
        type = "int-setting",
        name = "YARM-overlay-step",
        setting_type = "runtime-global",
        order = "c",
        default_value = 1,
        minimum_value = 1,
        maximum_value = 5
    },
    {
        type = "bool-setting",
        name = "YARM-site-prefix-with-surface",
        setting_type = "runtime-global",
        order = "d",
        default_value = false
    },
    {
        type = "bool-setting",
        name = "YARM-debug-profiling",
        setting_type = "runtime-global",
        order = "zz[debug]",
        default_value = false,
    },

    {
        type = "bool-setting",
        name = "YARM-adjust-for-productivity",
        setting_type = "runtime-global",
        order = "c",
        default_value = false,
    },
    {
        type = "bool-setting",
        name = "YARM-productivity-show-raw-and-adjusted",
        setting_type = "runtime-global",
        order = "d",
        default_value = false,
    },
    {
        type = "string-setting",
        name = "YARM-productivity-parentheses-part-is",
        setting_type = "runtime-global",
        order = "e",
        default_value = "adjusted",
        allowed_values = { "adjusted", "raw" }
    },
    {
        type = "double-setting",
        name = "YARM-grow-limit",
        setting_type = "runtime-global",
        order = "f",
        default_value = -1,
        minimum_value = -1,
        maximum_value = 10000000
    },
    {
        type = "bool-setting",
        name = "YARM-adjust-over-percentage-sites",
        setting_type = "runtime-global",
        order = "g",
        default_value = false,
    },
    {
        type = "double-setting",
        name = "YARM-nominal-ups",
        setting_type = "runtime-global",
        order = "h",
        default_value = 60,
        minimum_value = 0,
        maximum_value = 10000000,
    },

    -- Per user settings
    {
        type = "double-setting",
        name = "YARM-warn-timeleft",
        setting_type = "runtime-per-user",
        order = "a",
        default_value = 24,
        minimum_value = 0,
        maximum_value = 10000000
    },
    {
        type = "double-setting",
        name = "YARM-warn-timeleft_totals",
        setting_type = "runtime-per-user",
        order = "b",
        default_value = 48,
        minimum_value = 0,
        maximum_value = 10000000
    },
    {
        type = "string-setting",
        name = "YARM-order-by",
        setting_type = "runtime-per-user",
        order = "c",
        default_value = "etd",
        allowed_values = { "alphabetical", "percent-remaining", "ore-type", "ore-count", "etd" }
        ---@alias order_by_enum "alphabetical"|"percent-remaining"|"ore-type"|"ore-count"|"etd"
    },
    {
        type = "bool-setting",
        name = "YARM-show-sites-summary",
        setting_type = "runtime-per-user",
        order = "d",
        default_value = true
    },
    {
        type = "int-setting",
        name = "YARM-hud-update-ticks",
        setting_type = "runtime-per-user",
        order = "e",
        default_value = 300,
        minimum_value = 30,
        maximum_value = 600,
    },
    {
        type = "string-setting",
        name = "YARM-color-scheme",
        setting_type = "runtime-per-user",
        order = "f1",
        default_value = "red-green",
        allowed_values = { "red-green", "red-blue", "custom" },
        ---@alias color_scheme_enum "red-green"|"red-blue"|"custom"
    },
    {
        type = "color-setting",
        name = "YARM-color-from",
        setting_type = "runtime-per-user",
        order="f2",
        default_value = {0.95, 0, 0},
    },
    {
        type = "color-setting",
        name = "YARM-color-to",
        setting_type = "runtime-per-user",
        order="f2",
        default_value = {0, 0.95, 0},
    },

})

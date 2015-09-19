data:extend(
{
    {
        type = "item",
        name = "resource-monitor",
        icon = "__{{MOD_NAME}}__/graphics/resource-monitor.png",
        flags = {"goes-to-quickbar"},
        damage_radius = 5,
        subgroup = "tool",
        order = "b[resource-monitor]",
        place_result = "resource-monitor",
        stack_size = 1
    },

    {
        type = "container",
        name = "resource-monitor",
        icon = "__{{MOD_NAME}}__/graphics/resource-monitor.png",
        flags = {"placeable-neutral", "player-creation"},
        minable = {mining_time = 1, result = "resource-monitor"},
        max_health = 100,
        corpse = "small-remnants",
        resistances ={{type = "fire",percent = 80}},
        collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
        collision_mask = {"floor-layer"},
        selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
        inventory_size = 1,
        picture =
        {
            filename = "__{{MOD_NAME}}__/graphics/resource-monitor.png",
            priority = "extra-high",
            width = 32,
            height = 32,
            shift = {0.0, 0.0}
        }
    },

    {
        type = "recipe",
        name = "resource-monitor",
        ingredients = {{"electronic-circuit",10},{"copper-cable",20}},
        result = "resource-monitor",
        result_count = 1,
        enabled = "false"
    },

    {
        type = "technology",
        name = "resource-monitoring",
        icon = "__{{MOD_NAME}}__/graphics/resource-monitor.png",
        effects = {
            {
                type = "unlock-recipe",
                recipe = "resource-monitor"
            }
        },
        prerequisites = {
            "logistics-2"
        },
        unit = {
            count = 100,
            ingredients = {
                {"science-pack-1", 1},
                {"science-pack-2", 1}
            },
            time = 30
        }
    },

    {
        type = "container",
        name = "rm_overlay",
        flags = {"placeable-neutral", "player-creation", "not-repairable"},
        icon = "__{{MOD_NAME}}__/graphics/rm_Overlay.png",

        max_health = 1,
        order = 'z[resource-monitor]',

        collision_mask = {"resource-layer"},
        collision_box = {{-0.35, -0.35}, {0.35, 0.35}},

        selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
        inventory_size = 1,
        picture =
        {
            filename = "__{{MOD_NAME}}__/graphics/rm_Overlay.png",
            priority = "extra-high",
            width = 32,
            height = 32,
            shift = {0.0, 0.0}
        }
    },
})


local red_label = {
    type = "label_style",
    parent = "label_style",
    font_color = {r=1, g=0.2, b=0.2}
}
data.raw["gui-style"].default.YARM_err_label = red_label


local function button_graphics(xpos, ypos)
    return {
        type = "monolith",

        top_monolith_border = 1,
        right_monolith_border = 1,
        bottom_monolith_border = 1,
        left_monolith_border = 1,

        monolith_image = {
            filename = "__{{MOD_NAME}}__/graphics/gui.png",
            priority = "extra-high-no-scale",
            width = 16,
            height = 16,
            x = xpos,
            y = ypos,
        },
    }
end

data.raw["gui-style"].default.YARM_button_with_icon = {
    type = "button_style",
    parent = "slot_button_style",

    scalable = true,

    top_padding = 1,
    right_padding = 1,
    bottom_padding = 1,
    left_padding = 1,

    width = 16,
    height = 16,

    default_graphical_set = button_graphics( 0,  0),
    hovered_graphical_set = button_graphics(16,  0),
    clicked_graphical_set = button_graphics(32,  0),
}


data.raw["gui-style"].default.YARM_expando_short = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 16),
    hovered_graphical_set = button_graphics(16, 16),
    clicked_graphical_set = button_graphics(32, 16),
}

data.raw["gui-style"].default.YARM_expando_long = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 32),
    hovered_graphical_set = button_graphics(16, 32),
    clicked_graphical_set = button_graphics(32, 32),
}

data.raw["gui-style"].default.YARM_settings = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 48),
    hovered_graphical_set = button_graphics(16, 48),
    clicked_graphical_set = button_graphics(32, 48),
}

data.raw["gui-style"].default.YARM_overlay_site = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 64),
    hovered_graphical_set = button_graphics(16, 64),
    clicked_graphical_set = button_graphics(32, 64),
}

data.raw["gui-style"].default.YARM_goto_site = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 80),
    hovered_graphical_set = button_graphics(16, 80),
    clicked_graphical_set = button_graphics(32, 80),
}

data.raw["gui-style"].default.YARM_delete_site = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 96),
    hovered_graphical_set = button_graphics(16, 96),
    clicked_graphical_set = button_graphics(32, 96),
}

data.raw["gui-style"].default.YARM_rename_site = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 112),
    hovered_graphical_set = button_graphics(16, 112),
    clicked_graphical_set = button_graphics(32, 112),
}

data.raw["gui-style"].default.YARM_site_table = {
    type = "table_style",
    horizontal_spacing = 3,
    vertical_spacing = 1,
}

data.raw["gui-style"].default.YARM_buttons = {
    type = "flow_style",
    parent = "description_flow_style",
    vertical_spacing = 5,
    top_padding = 4,
}

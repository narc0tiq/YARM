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
        icon = "__{{MOD_NAME}}__/graphics/yarm-tech.png",
        icon_size = 128,
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
    {
        type = "resource-category",
        name = "empty-resource-category",
    },
    {
        type = "recipe-category",
        name = "empty-recipe-category",
    },
})

local empty_animation = {
    filename = "__{{MOD_NAME}}__/graphics/nil.png",
    priority = "medium",
    width = 0,
    height = 0,
    direction_count = 18,
    frame_count = 1,
    animation_speed = 0,
    shift = {0,0},
    axially_symmetrical = false,
}

local empty_anim_level = {
    idle = empty_animation,
    idle_mask = empty_animation,
    idle_with_gun = empty_animation,
    idle_with_gun_mask = empty_animation,
    mining_with_hands = empty_animation,
    mining_with_hands_mask = empty_animation,
    mining_with_tool = empty_animation,
    mining_with_tool_mask = empty_animation,
    running_with_gun = empty_animation,
    running_with_gun_mask = empty_animation,
    running = empty_animation,
    running_mask = empty_animation,
}

local fake_player = table.deepcopy(data.raw.player.player)
fake_player.name = "yarm-remote-viewer"
fake_player.crafting_categories = {"empty-recipe-category"}
fake_player.mining_categories = {"empty-resource-category"}
fake_player.max_health = 0
fake_player.inventory_size = 0
fake_player.build_distance = 0
fake_player.drop_item_distance = 0
fake_player.reach_distance = 0
fake_player.reach_resource_distance = 0
fake_player.mining_speed = 0
fake_player.running_speed = 0
fake_player.distance_per_frame = 0
fake_player.animations = {
    level1 = empty_anim_level,
    level2addon = empty_anim_level,
    level3addon = empty_anim_level,
}
fake_player.light = {{ intensity=0, size=0 }}
fake_player.flags = {"placeable-off-grid", "not-on-map", "not-repairable"}
fake_player.collision_mask = {"ground-tile"}

data:extend({ fake_player })


local default_gui = data.raw["gui-style"].default

local red_label = {
    type = "label_style",
    parent = "label_style",
    font_color = {r=1, g=0.2, b=0.2}
}
default_gui.YARM_err_label = red_label


local function button_graphics(xpos, ypos)
    return {
        type = "monolith",

        top_monolith_border = 0,
        right_monolith_border = 0,
        bottom_monolith_border = 0,
        left_monolith_border = 0,

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

default_gui.YARM_button_with_icon = {
    type = "button_style",
    parent = "slot_button_style",

    scalable = true,

    top_padding = 1,
    right_padding = 1,
    bottom_padding = 1,
    left_padding = 1,

    width = 17,
    height = 17,

    default_graphical_set = button_graphics( 0,  0),
    hovered_graphical_set = button_graphics(16,  0),
    clicked_graphical_set = button_graphics(32,  0),
}


default_gui.YARM_expando_short = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 16),
    hovered_graphical_set = button_graphics(16, 16),
    clicked_graphical_set = button_graphics(32, 16),
}

default_gui.YARM_expando_long = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 32),
    hovered_graphical_set = button_graphics(16, 32),
    clicked_graphical_set = button_graphics(32, 32),
}

default_gui.YARM_settings = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 48),
    hovered_graphical_set = button_graphics(16, 48),
    clicked_graphical_set = button_graphics(32, 48),
}

default_gui.YARM_overlay_site = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 64),
    hovered_graphical_set = button_graphics(16, 64),
    clicked_graphical_set = button_graphics(32, 64),
}

default_gui.YARM_goto_site = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 80),
    hovered_graphical_set = button_graphics(16, 80),
    clicked_graphical_set = button_graphics(32, 80),
}

default_gui.YARM_delete_site = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 96),
    hovered_graphical_set = button_graphics(16, 96),
    clicked_graphical_set = button_graphics(32, 96),
}

default_gui.YARM_rename_site = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 112),
    hovered_graphical_set = button_graphics(16, 112),
    clicked_graphical_set = button_graphics(32, 112),
}

default_gui.YARM_delete_site_confirm = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 128),
    hovered_graphical_set = button_graphics(16, 128),
    clicked_graphical_set = button_graphics(32, 128),
}

default_gui.YARM_goto_site_cancel = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 144),
    hovered_graphical_set = button_graphics(16, 144),
    clicked_graphical_set = button_graphics(32, 144),
}

default_gui.YARM_rename_site_cancel = {
    type = "button_style",
    parent = "YARM_button_with_icon",

    default_graphical_set = button_graphics( 0, 160),
    hovered_graphical_set = button_graphics(16, 160),
    clicked_graphical_set = button_graphics(32, 160),
}

default_gui.YARM_site_table = {
    type = "table_style",
    horizontal_spacing = 3,
    vertical_spacing = 1,
}

default_gui.YARM_buttons = {
    type = "flow_style",
    parent = "description_flow_style",
    horizontal_spacing = 1,
    vertical_spacing = 5,
    top_padding = 4,
}



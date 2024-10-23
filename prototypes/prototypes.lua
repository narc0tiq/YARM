data:extend(
    {
        {
            type = 'custom-input',
            name = 'get-yarm-selector',
            key_sequence = 'ALT + Y',
            consuming = 'none'
        },

        {
            type = 'shortcut',
            name = 'yarm-selector',
            order = "a[yarm]",
            action = 'spawn-item',
            item_to_spawn = 'yarm-selector-tool',
            style = 'green',
            icon = '__YARM__/graphics/resource-monitor-x32-white.png',
            icon_size = 32,
            small_icon = '__YARM__/graphics/resource-monitor-x24.png',
            small_icon_size = 24,
        },

        {
            type = 'selection-tool',
            name = 'yarm-selector-tool',
            icon = '__YARM__/graphics/resource-monitor.png',
            icon_size = 32,
            flags = { 'only-in-cursor', 'spawnable' },
            stack_size = 1,
            stackable = false,
            entity_filter_mode = 'whitelist',
            entity_type_filters = { 'resource' },
            hidden = true,
            select = {
                border_color = { g = 1 },
                cursor_box_type = 'copy',
                mode = 'any-entity',
            },
            alt_select = {
                border_color = { g = 1, b = 1 },
                cursor_box_type = 'copy',
                mode = 'nothing',
            },
        },

        {
            type = 'container',
            name = 'rm_overlay',
            flags = { 'placeable-neutral', 'player-creation', 'not-repairable' },
            icon = '__YARM__/graphics/rm_Overlay.png',
            icon_size = 32,

            max_health = 1,
            order = 'z[resource-monitor]',

            collision_mask = { layers = { resource = true } },
            collision_box = { { -0.35, -0.35 }, { 0.35, 0.35 } },

            selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
            inventory_size = 1,
            picture =
            {
                filename = '__YARM__/graphics/rm_Overlay.png',
                priority = 'extra-high',
                width = 32,
                height = 32,
                shift = { 0.0, 0.0 }
            }
        },

        {
            type = 'font',
            name = 'yarm-gui-font',
            size = 14,
            from = 'default-bold',
            border = true,
            border_color = { 0, 0, 0 },
        },
    })

local default_gui = data.raw['gui-style'].default

local red_label = {
    type = 'label_style',
    parent = 'label',
    font_color = { r = 1, g = 0.2, b = 0.2 }
}
default_gui.YARM_err_label = red_label

local function arb_graphics(xpos, ypos, size)
    return {
        filename = '__YARM__/graphics/gui.png',
        priority = 'extra-high-no-scale',
        width = size,
        height = size,
        x = xpos,
        y = ypos,
    }
end

local function button_graphics(xpos, ypos)
    return arb_graphics(xpos, ypos, 16)
end

default_gui.YARM_outer_frame_no_border = {
    type = 'frame_style',
    parent = 'outer_frame',
    graphical_set = {}
}

default_gui.YARM_outer_frame_no_border_bg = {
    type = 'frame_style',
    parent = 'outer_frame',
    graphical_set = arb_graphics(1, 15, 1)
}
default_gui.YARM_outer_frame_no_border_bg.graphical_set.blend_mode = 'multiplicative-with-alpha'

default_gui.YARM_button_with_icon = {
    type = 'button_style',
    parent = 'slot_button',

    scalable = true,

    top_padding = 1,
    right_padding = 1,
    bottom_padding = 1,
    left_padding = 1,

    width = 16,
    height = 16,

    default_graphical_set = button_graphics(0, 0),
    hovered_graphical_set = button_graphics(16, 0),
    clicked_graphical_set = button_graphics(32, 0),
}

local function make_filter_buttons(base_name, tex_y)
    default_gui[base_name] = {
        type = 'button_style',
        parent = 'YARM_button_with_icon',

        default_graphical_set = button_graphics(0, tex_y),
        hovered_graphical_set = button_graphics(16, tex_y),
        clicked_graphical_set = button_graphics(32, tex_y),
    }

    default_gui[base_name .. '_on'] = {
        type = 'button_style',
        parent = 'YARM_button_with_icon',

        default_graphical_set = button_graphics(16, tex_y),
        hovered_graphical_set = button_graphics(0, tex_y),
        clicked_graphical_set = button_graphics(32, tex_y),
    }
end

make_filter_buttons('YARM_filter_none', 48)
make_filter_buttons('YARM_filter_warnings', 16)
make_filter_buttons('YARM_filter_all', 32)
make_filter_buttons('YARM_toggle_surfacesplit', 64)
make_filter_buttons('YARM_toggle_bg', 80)
make_filter_buttons('YARM_toggle_lite', 208)

default_gui.YARM_overlay_site = {
    type = 'button_style',
    parent = 'YARM_button_with_icon',

    default_graphical_set = button_graphics(0, 64),
    hovered_graphical_set = button_graphics(16, 64),
    clicked_graphical_set = button_graphics(32, 64),
}

default_gui.YARM_goto_site = {
    type = 'button_style',
    parent = 'YARM_button_with_icon',

    default_graphical_set = button_graphics(0, 80),
    hovered_graphical_set = button_graphics(16, 80),
    clicked_graphical_set = button_graphics(32, 80),
}

default_gui.YARM_delete_site = {
    type = 'button_style',
    parent = 'YARM_button_with_icon',

    default_graphical_set = button_graphics(0, 96),
    hovered_graphical_set = button_graphics(16, 96),
    clicked_graphical_set = button_graphics(32, 96),
}

default_gui.YARM_rename_site = {
    type = 'button_style',
    parent = 'YARM_button_with_icon',

    default_graphical_set = button_graphics(0, 112),
    hovered_graphical_set = button_graphics(16, 112),
    clicked_graphical_set = button_graphics(32, 112),
}

default_gui.YARM_delete_site_confirm = {
    type = 'button_style',
    parent = 'YARM_button_with_icon',

    default_graphical_set = button_graphics(0, 128),
    hovered_graphical_set = button_graphics(16, 128),
    clicked_graphical_set = button_graphics(32, 128),
}

default_gui.YARM_goto_site_cancel = {
    type = 'button_style',
    parent = 'YARM_button_with_icon',

    default_graphical_set = button_graphics(0, 144),
    hovered_graphical_set = button_graphics(16, 144),
    clicked_graphical_set = button_graphics(32, 144),
}

default_gui.YARM_rename_site_cancel = {
    type = 'button_style',
    parent = 'YARM_button_with_icon',

    default_graphical_set = button_graphics(0, 160),
    hovered_graphical_set = button_graphics(16, 160),
    clicked_graphical_set = button_graphics(32, 160),
}

default_gui.YARM_expand_site = {
    type = 'button_style',
    parent = 'YARM_button_with_icon',

    default_graphical_set = button_graphics(0, 176),
    hovered_graphical_set = button_graphics(16, 176),
    clicked_graphical_set = button_graphics(32, 176),
}

default_gui.YARM_expand_site_cancel = {
    type = 'button_style',
    parent = 'YARM_button_with_icon',

    default_graphical_set = button_graphics(0, 192),
    hovered_graphical_set = button_graphics(16, 192),
    clicked_graphical_set = button_graphics(32, 192),
}

default_gui.YARM_site_table = {
    type = 'table_style',
    horizontal_spacing = 3,
    vertical_spacing = 1,
}


default_gui.YARM_buttons_h = {
    type = 'horizontal_flow_style',
    parent = 'horizontal_flow',
    horizontal_spacing = 1,
    vertical_spacing = 5,
    top_padding = 4,
}

default_gui.YARM_buttons_v = {
    type = 'vertical_flow_style',
    parent = 'vertical_flow',
    horizontal_spacing = 1,
    vertical_spacing = 5,
    top_padding = 4,
}

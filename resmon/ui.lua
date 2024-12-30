local get_frame_flow = require("mod-gui").get_frame_flow

local hsv_lib = require("libs/hsv")

---@module "columns"

---@class ui_module
local ui_module = {
    -- NB: filter names should be single words with optional underscores (_)
    -- They will be used for naming GUI elements
    FILTER_NONE = "none",
    FILTER_WARNINGS = "warnings",
    FILTER_ALL = "all",

    -- Sanity: site names aren't allowed to be longer than this, to prevent them
    -- kicking the buttons off the right edge of the screen
    MAX_SITE_NAME_LENGTH = 64, -- I like square numbers
}

---Update the UI of all of a given force's members
---@param force LuaForce|string|integer
function ui_module.update_force_members(force)
    if not force.players then
        force = game.forces[force]
    end
    for _, p in pairs(force.players) do
        resmon.ui.update_player(p)
    end
end

---Update the given player's UI elements (buttons, sites, etc.). Should be called
---periodically (e.g., on_nth_tick) for each player in the game.
---@param player LuaPlayer Whose UI is being updated?
function ui_module.update_player(player)
    local player_data = storage.player_data[player.index]
    local force_data = storage.force_data[player.force.name]

    if not player_data or not force_data or not force_data.ore_sites then
        return -- early init, nothing ready yet
    end

    player_data.site_display_name_format = player.mod_settings["YARM-display-name-format"].value --[[@as string]]

    local root = ui_module.get_or_create_hud(player)
    root.style = player_data.ui.enable_hud_background and "YARM_outer_frame_no_border_bg" or "YARM_outer_frame_no_border"

    local table_data = resmon.sites.create_sites_yatable_data(player)
    resmon.yatable.render(root, table_data, player_data)
end

---Returns the player's HUD root, creating it if necessary
---@param player LuaPlayer Whose HUD is being fetched?
---@return LuaGuiElement The HUD root, including side buttons
function ui_module.get_or_create_hud(player)
    local frame_flow = get_frame_flow(player)
    local root = frame_flow.YARM_root
    if not root then
        root = frame_flow.add { type = "frame",
            name = "YARM_root",
            direction = "horizontal",
            style = "YARM_outer_frame_no_border" }

        local buttons = root.add { type = "flow",
            name = "buttons",
            direction = "vertical",
            style = "YARM_buttons_v" }

        -- TODO: Refactor the filter buttons (should be able to create them dynamically)
        buttons.add { type = "button", name = "YARM_filter_" .. ui_module.FILTER_NONE, style = "YARM_filter_none",
            tooltip = { "YARM-tooltips.filter-none" } }
        buttons.add { type = "button", name = "YARM_filter_" .. ui_module.FILTER_WARNINGS, style = "YARM_filter_warnings",
            tooltip = { "YARM-tooltips.filter-warnings" } }
        buttons.add { type = "button", name = "YARM_filter_" .. ui_module.FILTER_ALL, style = "YARM_filter_all",
            tooltip = { "YARM-tooltips.filter-all" } }
        -- TODO: Refactor how all these buttons are created: we should not need to change two places if the below change style or something
        buttons.add { type = "button", name = "YARM_toggle_bg", style = "YARM_toggle_bg",
            tooltip = { "YARM-tooltips.toggle-bg" } }
        buttons.add { type = "button", name = "YARM_toggle_surfacesplit", style = "YARM_toggle_surfacesplit",
            tooltip = { "YARM-tooltips.toggle-surfacesplit" } }
        buttons.add { type = "button", name = "YARM_toggle_lite", style = "YARM_toggle_lite",
            tooltip = { "YARM-tooltips.toggle-lite" } }

        ui_module.update_filter_buttons(player)
    end

    return root
end

---Set the button style to ON or OFF if necessary. Will not disturb the style if already correct.
---Relies on the fact that toggle button styles have predictable names: the "on" state's name is
---the same as the "off" state, but with "_on" appended.
---@param button LuaGuiElement The button being targeted
---@param should_be_active boolean Should the button be set to ON or OFF?
function ui_module.update_button_active_style(button, should_be_active)
    local style_name = button.style.name
    local is_active_style = style_name:ends_with("_on")

    if is_active_style and not should_be_active then
        button.style = string.sub(style_name, 1, string.len(style_name) - 3) -- trim "_on"
    elseif should_be_active and not is_active_style then
        button.style = style_name .. "_on"
    end
end

---Update the state of the given player's filter buttons: the active filter's button is
---set to active, the rest set to inactive
---@param player LuaPlayer Whose filters are we updating?
function ui_module.update_filter_buttons(player)
    local player_data = storage.player_data[player.index]
    -- In extreme cases, the `player_data.ui` might not have been initialized yet (e.g., scenario from an old version)
    if not player_data.ui then
        return -- We cannot proceed in this case
    end

    if not player_data.ui.active_filter then
        player_data.ui.active_filter = ui_module.FILTER_WARNINGS
    end

    local root = ui_module.get_or_create_hud(player)
    local active_filter = player_data.ui.active_filter
    for filter_name, _ in pairs(resmon.sites.filters) do
        local button = root.buttons["YARM_filter_" .. filter_name]
        if button and button.valid then
            ui_module.update_button_active_style(button, filter_name == active_filter)
        end
    end
end

---@type {[color_scheme_enum]:{from:rgb_color, to:rgb_color}}
local color_schemes = {
    ["red-green"] = { from = { r=0.94, g=0.4, b=0.4 }, to = { r=0, g=0.94, b=0 } },
    ["red-blue"] = { from = { r=0.94, g=0.4, b=0.4 }, to = { r=0.52, g=0.6, b=1 } },
    ["grayscale"] = { from = { r=0.62, g=0.62, b=0.62 }, to = { r=1, g=1, b=1 } },
}

local function get_player_color(player, factor)
    local scheme = player.mod_settings["YARM-color-scheme"].value or next(color_schemes)
    local from_rgb, to_rgb
    if color_schemes[scheme] then
        from_rgb = color_schemes[scheme].from
        to_rgb = color_schemes[scheme].to
    else
        from_rgb = player.mod_settings["YARM-color-from"].value or color_schemes["red-green"].from
        to_rgb = player.mod_settings["YARM-color-to"].value or color_schemes["red-green"].to
    end

    local from_hsv = hsv_lib.from_rgb(from_rgb)
    local to_hsv = hsv_lib.from_rgb(to_rgb)
    return hsv_lib.lerp(from_hsv, to_hsv, factor)
end

function ui_module.color_for_site(site, player)
    local threshold = player.mod_settings["YARM-warn-timeleft"].value * 60
    if site.is_summary then
        threshold = player.mod_settings["YARM-warn-timeleft_totals"].value * 60
    end
    local etd = site.etd_minutes == -1 and threshold or site.etd_minutes
    local fullness = threshold == 0 and 1 or (etd / threshold)
    if fullness > 1 then fullness = 1 end
    return hsv_lib.to_rgb(get_player_color(player, fullness))
end

---Update the given site's chart tag (map marker) with the current name and ore count
---@param site yarm_site
function ui_module.update_chart_tag(site)
    local is_chart_tag_enabled = settings.global["YARM-map-markers"].value

    if not is_chart_tag_enabled then
        if site.chart_tag and site.chart_tag.valid then
            -- chart tags were just disabled, so remove them from the world
            site.chart_tag.destroy()
            site.chart_tag = nil
        end
        return
    end

    if not site.chart_tag or not site.chart_tag.valid then
        if not site.force or not site.force.valid or not site.surface.valid then
            return
        end

        local chart_tag = {
            position = site.center,
            text = tostring(site.index) or '',
        }
        site.chart_tag = site.force.add_chart_tag(site.surface, chart_tag)
        if not site.chart_tag then
            return
        end -- may fail if chunk is not currently charted accd. to @Bilka
    end

    local display_value = resmon.locale.site_amount(site, resmon.locale.format_number_si)
    local ore_products = resmon.locale.get_rich_text_for_products(prototypes.entity[site.ore_type])
    local tag_base_text = site.name_tag and site.name_tag ~= "" and site.name_tag or tostring(site.index)
    site.chart_tag.text = string.format('%s - %s %s', tag_base_text, display_value, ore_products)
end

---Performs any migrations of UI-related player data for the given player. Should be
---called on_configuration_changed, but should also be safe to be called
---on_init/on_load (just that it's not likely to do anything).
---@param player LuaPlayer Whose data are we updating?
function ui_module.migrate_player_data(player)
    local player_data = storage.player_data[player.index]
    local root = ui_module.get_or_create_hud(player)
    local buttons = root.buttons

    -- v1.0.4: migrating from an old YARM, or old Factorio, may set some buttons to invisible; unhide them:
    for _, button in pairs(buttons.children) do
        button.visible = true
    end

    -- v1.0.4: migrating from an old YARM may not contain these buttons; create them:
    -- TODO: Refactor how these buttons are created: we should not need to change two places if these change style or something
    if not buttons.YARM_toggle_bg then
        buttons.add { type = "button", name = "YARM_toggle_bg", style = "YARM_toggle_bg",
            tooltip = { "YARM-tooltips.toggle-bg" } }
    end
    if not buttons.YARM_toggle_surfacesplit then
        buttons.add { type = "button", name = "YARM_toggle_surfacesplit", style = "YARM_toggle_surfacesplit",
            tooltip = { "YARM-tooltips.toggle-surfacesplit" } }
    end
    if not buttons.YARM_toggle_lite then
        buttons.add { type = "button", name = "YARM_toggle_lite", style = "YARM_toggle_lite",
            tooltip = { "YARM-tooltips.toggle-lite" } }
    end

    -- v1.0.0: player UI data moved into own namespace
    if not player_data.ui then
        ---@class player_data_ui
        player_data.ui = {
            active_filter = ui_module.FILTER_WARNINGS,
            enable_hud_background = root.style == "YARM_outer_frame_no_border_bg",
            split_by_surface = buttons.YARM_toggle_surfacesplit.style.name:ends_with("_on"),
            show_compact_columns = buttons.YARM_toggle_lite.style.name:ends_with("_on"),
        }
    end

    if player_data.active_filter then
        player_data.ui.active_filter = player_data.active_filter
        player_data.active_filter = nil ---@diagnostic disable-line: inject-field
    end

    if player_data.ui.site_colors then
        player_data.ui.site_colors = nil ---@diagnostic disable-line: inject-field
    end
end

---Update a GUI element's tags (they have to be rewritten fully every time)
---@param elem LuaGuiElement
---@param new_tags table
function ui_module.update_tags(elem, new_tags)
    local tags = elem.tags
    for k, v in pairs(new_tags) do
        tags[k] = v
    end
    elem.tags = tags
end

return ui_module

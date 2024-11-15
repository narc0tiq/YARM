local get_frame_flow = require("mod-gui").get_frame_flow

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

    local root = ui_module.get_or_create_hud(player)
    local show_sites_summary = player.mod_settings["YARM-show-sites-summary"].value or false

    if root.sites and root.sites.valid then
        root.sites.destroy()
    end

    -- TODO Refactor this large clump into something more reasonable
    local is_full = root.buttons.YARM_toggle_lite.style.name ~= "YARM_toggle_lite_on"
    local column_count = is_full and 12 or 5
    local sites_gui = root.add { type = "table", column_count = column_count, name = "sites", style = "YARM_site_table" }
    sites_gui.style.horizontal_spacing = 5
    local column_alignments = sites_gui.style.column_alignments
    if is_full then
        column_alignments[1] = 'left'    -- rename button
        column_alignments[2] = 'left'    -- surface name
        column_alignments[3] = 'left'    -- site name
        column_alignments[4] = 'right'   -- remaining percent
        column_alignments[5] = 'right'   -- site amount
        column_alignments[6] = 'left'    -- ore name
        column_alignments[7] = 'right'   -- ore per minute
        column_alignments[8] = 'left'    -- ETD
        column_alignments[9] = 'right'   -- ETD
        column_alignments[10] = 'left'   -- ETD
        column_alignments[11] = 'center' -- ETD
        column_alignments[12] = 'left'   -- buttons
    else
        column_alignments[1] = 'left'    -- surface name
        column_alignments[2] = 'left'    -- site name
        column_alignments[3] = 'left'    -- ore name
        column_alignments[4] = 'right'   -- ETD
        column_alignments[5] = 'left'    -- buttons
    end

    local site_filter = resmon.sites.filters[player_data.active_filter] or resmon.sites.filters[ui_module.FILTER_NONE]
    local surface_names = { false }
    local is_split_by_surface = root.buttons.YARM_toggle_surfacesplit.style.name == "YARM_toggle_surfacesplit_on"
    if is_split_by_surface then
        surface_names = resmon.surface_names()
    end
    local surface_num = 0
    local rendered_last = false

    for _, surface_name in pairs(surface_names) do
        local sites = resmon.sites.on_surface(player, surface_name)
        if next(sites) then
            local will_render_sites
            local will_render_totals
            local summary = show_sites_summary and resmon.sites.generate_summaries(player, sites) or {}
            for summary_site in resmon.sites.in_player_order(summary, player) do
                if site_filter(summary_site, player) then will_render_totals = true end
            end
            for _, site in pairs(sites) do
                if site_filter(site, player) then will_render_sites = true end
            end

            surface_num = surface_num + 1
            if surface_num > 1 and rendered_last and (will_render_totals or will_render_sites) then
                for _ = 1, column_count do sites_gui.add { type = "line" } end
                for _ = 1, column_count do sites_gui.add { type = "line" } end
                for _ = 1, column_count do sites_gui.add { type = "line" } end
            end
            rendered_last = rendered_last or will_render_totals or will_render_sites

            local row = 1
            for summary_site in resmon.sites.in_player_order(summary, player) do
                if resmon.ui.render_single_site(site_filter, summary_site, player, sites_gui, player_data, row, is_full, is_split_by_surface) then
                    row = row + 1
                end
            end
            if will_render_totals and will_render_sites then
                if is_full then
                    sites_gui.add { type = "label" }.style.maximal_height = 5
                end
                sites_gui.add { type = "label" }.style.maximal_height = 5
                local el = sites_gui.add { type = "label", caption = { "YARM-category-sites" } }
                el.style.font = "yarm-gui-font"
                local start = is_full and 4 or 3
                for _ = start, column_count do sites_gui.add { type = "label" }.style.maximal_height = 5 end
            end
            row = 1
            for _, site in pairs(sites) do
                if resmon.ui.render_single_site(site_filter, site, player, sites_gui, player_data, row, is_full, is_split_by_surface) then
                    row = row + 1
                end
            end
        end
    end
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

---Set the button style to ON or OFF if necessary. Will not disturb the style if already correct
---@param button LuaGuiElement The button being targeted
---@param should_be_active boolean Should the button be set to ON or OFF?
local function update_active_style_name(button, should_be_active)
    local style_name = button.style.name
    local is_active_style = style_name:ends_with("_on")

    if is_active_style and not should_be_active then
        button.style = string.sub(style_name, 1, string.len(style_name) - 3) -- trim "_on"
    elseif should_be_active and not is_active_style then
        button.style = style_name.."_on"
    end
end

---Update the state of the given player's filter buttons: the active filter's button is
---set to active, the rest set to inactive
---@param player LuaPlayer Whose filters are we updating?
function ui_module.update_filter_buttons(player)
    local player_data = storage.player_data[player.index]
    if not player_data.ui.active_filter then
        player_data.ui.active_filter = ui_module.FILTER_WARNINGS
    end

    local root = ui_module.get_or_create_hud(player)
    local active_filter = player_data.ui.active_filter
    for filter_name, _ in pairs(resmon.sites.filters) do
        local button = root.buttons["YARM_filter_"..filter_name]
        if button and button.valid then
            update_active_style_name(button, filter_name == active_filter)
        end
    end
end

---Render a single site onto the given `sites_gui`. Candidate for refactor: too many inputs, too many states
---@param site_filter function Returns true or false if the given site should be shown to the given player
---@param site yarm_site The site we're rendering
---@param player LuaPlayer The player to whom we are showing the site
---@param sites_gui LuaGuiElement The container we are rendering into
---@param player_data table The current player's stored data
---@param row integer The index of the row we're rendering; row 1 might be special
---@param is_full boolean Whether we're rendering the full width display (12 columns) or the compact view (5 columns)
---@param is_split_by_surface boolean Whether we're splitting the display by surface (which is when row 1 is special)
---@return boolean Whether we rendered anything or not
function ui_module.render_single_site(site_filter, site, player, sites_gui, player_data, row, is_full, is_split_by_surface)
    if not site_filter(site, player) then
        return false
    end

    -- TODO: This shouldn't be part of printing the site! It cancels the deletion
    -- process after 2 seconds pass.
    if site.deleting_since and site.deleting_since + 120 < game.tick then
        site.deleting_since = nil
    end

    local threshold_type = site.is_summary and "timeleft_totals" or "timeleft"
    local threshold = player.mod_settings["YARM-warn-" .. threshold_type].value * 60
    local color = ui_module.site_color(site.etd_minutes, threshold)
    local el = nil

    -- TODO: Major refactor of site printing, as shown below. We have two possible column states, we have
    -- different display orders, we have different filters, it's all one HUGE complication
    if not site.is_summary then
        if is_full then
            if player_data.renaming_site == site.name then
                sites_gui.add { type = "button",
                    name = "YARM_rename_site_" .. site.name,
                    tooltip = { "YARM-tooltips.rename-site-cancel" },
                    style = "YARM_rename_site_cancel" }
            else
                sites_gui.add { type = "button",
                    name = "YARM_rename_site_" .. site.name,
                    tooltip = { "YARM-tooltips.rename-site-named", site.name },
                    style = "YARM_rename_site" }
            end
        end

        local surf_name = is_split_by_surface and site.surface.name or ""
        el = sites_gui.add { type = "label", name = "YARM_label_surface_" .. site.name, caption = surf_name }
        el.style.font_color = color
        el.style.font = "yarm-gui-font"

        el = sites_gui.add { type = "label", name = "YARM_label_site_" .. site.name, caption = site.name }
        el.style.font_color = color
        el.style.font = "yarm-gui-font"
    else
        if is_full then
            sites_gui.add { type = "label" }
        end
        local surface = (is_split_by_surface and row == 1)
            and site.surface.name or ""
        sites_gui.add { type = "label", caption = surface }
        local totals = row == 1 and { "YARM-category-totals" } or ""
        el = sites_gui.add { type = "label", caption = totals }
        el.style.font = "yarm-gui-font"
    end

    if is_full then
        el = sites_gui.add { type = "label", name = "YARM_label_percent_" .. site.name,
            caption = string.format("%.1f%%", site.remaining_permille / 10) }
        el.style.font_color = color
        el.style.font = "yarm-gui-font"

        local display_amount = resmon.locale.site_amount(site, resmon.locale.format_number)
        el = sites_gui.add { type = "label", name = "YARM_label_amount_" .. site.name,
            caption = display_amount }
        el.style.font_color = color
        el.style.font = "yarm-gui-font"
    end

    local entity_prototype = prototypes.entity[site.ore_type]
    el = sites_gui.add { type = "label", name = "YARM_label_ore_name_" .. site.name,
        caption = is_full
            and { "", resmon.locale.get_rich_text_for_products(entity_prototype), " ", site.ore_name }
            or resmon.locale.get_rich_text_for_products(entity_prototype) }
    el.style.font_color = color
    el.style.font = "yarm-gui-font"

    if is_full then
        el = sites_gui.add {
            name = "YARM_label_ore_per_minute_" .. site.name,
            type = "label",
            caption = resmon.locale.site_depletion_rate(site)
        }
        el.style.font_color = color
        el.style.font = "yarm-gui-font"

        ui_module.render_arrow_for_percent_delta(sites_gui, -1 * site.ore_per_minute_delta, site.ore_per_minute)
    end

    el = sites_gui.add { type = "label", name = "YARM_label_etd_" .. site.name,
        caption = resmon.locale.time_to_deplete(site.etd_minutes, site.amount_left) }
    el.style.font_color = color
    el.style.font = "yarm-gui-font"

    if is_full then
        ui_module.render_arrow_for_percent_delta(sites_gui, site.etd_minutes_delta, site.etd_minutes)

        if not site.is_summary then
            local etd_icon = site.etd_is_lifetime == 1 and "[img=quantity-time]" or "[img=utility/played_green]"
            el = sites_gui.add { type = "label", name = "YARM_label_etd_header_" .. site.name,
                caption = { "YARM-time-to-deplete", etd_icon } }
            el.style.font_color = color
            el.style.font = "yarm-gui-font"
        else
            sites_gui.add { type = "label", caption = "" }
        end
    end

    local site_buttons = sites_gui.add { type = "flow", name = "YARM_site_buttons_" .. site.name,
        direction = "horizontal", style = "YARM_buttons_h" }

    if not site.is_summary then
        site_buttons.add { type = "button",
            name = "YARM_goto_site_" .. site.name,
            tooltip = { "YARM-tooltips.goto-site" },
            style = "YARM_goto_site" }

        if is_full then
            if site.deleting_since then
                site_buttons.add { type = "button",
                    name = "YARM_delete_site_" .. site.name,
                    tooltip = { "YARM-tooltips.delete-site-confirm" },
                    style = "YARM_delete_site_confirm" }
            else
                site_buttons.add { type = "button",
                    name = "YARM_delete_site_" .. site.name,
                    tooltip = { "YARM-tooltips.delete-site" },
                    style = "YARM_delete_site" }
            end

            if site.is_site_expanding then
                site_buttons.add { type = "button",
                    name = "YARM_expand_site_" .. site.name,
                    tooltip = { "YARM-tooltips.expand-site-cancel" },
                    style = "YARM_expand_site_cancel" }
            else
                site_buttons.add { type = "button",
                    name = "YARM_expand_site_" .. site.name,
                    tooltip = { "YARM-tooltips.expand-site" },
                    style = "YARM_expand_site" }
            end
        end
    end

    return true
end

---Generate the site color depending on the remaining minutes and player's warning threshold
---@param etd_minutes number Estimated time to depletion
---@param threshold number Player's warning threshold
---@return table RGB color
function ui_module.site_color(etd_minutes, threshold)
    if etd_minutes == -1 then
        etd_minutes = threshold
    end
    local factor = (threshold == 0 and 1) or (etd_minutes / threshold)
    if factor > 1 then
        factor = 1
    end
    local hue = factor / 3
    return ui_module.hsv2rgb(hue, 1, 0.9)
end

---Turn a HSV (hue, saturation, value) color to RGB
function ui_module.hsv2rgb(h, s, v)
    local r, g, b
    local i = math.floor(h * 6);
    local f = h * 6 - i;
    local p = v * (1 - s);
    local q = v * (1 - f * s);
    local t = v * (1 - (1 - f) * s);
    i = i % 6
    if i == 0 then
        r, g, b = v, t, p
    elseif i == 1 then
        r, g, b = q, v, p
    elseif i == 2 then
        r, g, b = p, v, t
    elseif i == 3 then
        r, g, b = p, q, v
    elseif i == 4 then
        r, g, b = t, p, v
    elseif i == 5 then
        r, g, b = v, p, q
    end
    return { r = r, g = g, b = b }
end

---Render an arrow going up, down, or nothing, depending on the given delta and amount. The ratio of
---the delta to the amount determines the color of the arrow.
---@param sites_gui LuaGuiElement The render target that we are placing the arrow onto
---@param delta number The last recorded change in amount
---@param amount number The last recorded amount
function ui_module.render_arrow_for_percent_delta(sites_gui, delta, amount)
    local percent_delta = (100 * (delta or 0) / (amount or 0)) / 5
    local hue = percent_delta >= 0 and (1 / 3) or 0
    local saturation = math.min(math.abs(percent_delta), 1)
    local value = math.min(0.5 + math.abs(percent_delta / 2), 1)
    local el = sites_gui.add({ type = "label", caption = (amount == 0 and "") or (delta or 0) >= 0 and "⬆" or "⬇" })
    el.style.font_color = ui_module.hsv2rgb(hue, saturation, value)
end

---Performs any migrations of UI-related player data for the given player. Should be
---called on_configuration_changed, but should also be safe to be called
---on_init/on_load (just that it's not likely to do anything).
---@param player LuaPlayer Whose data are we updating?
function ui_module.migrate_player_data(player)
    local player_data = storage.player_data[player.index]

    -- v0.12.0: player UI data moved into own namespace
    if not player_data.ui then
        player_data.ui = {
            active_filter = ui_module.FILTER_WARNINGS,
        }
    end

    if player_data.active_filter then
        player_data.ui.active_filter = player_data.active_filter
        player_data.active_filter = nil
    end
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
        if not site.force or not site.force.valid or not site.surface.valid then return end

        local chart_tag = {
            position = site.center,
            text = site.name,
        }
        site.chart_tag = site.force.add_chart_tag(site.surface, chart_tag)
        if not site.chart_tag then return end -- may fail if chunk is not currently charted accd. to @Bilka
    end

    local display_value = resmon.locale.site_amount(site, resmon.locale.format_number_si)
    local ore_prototype = prototypes.entity[site.ore_type]
    site.chart_tag.text =
        string.format('%s - %s %s', site.name, display_value, resmon.locale.get_rich_text_for_products(ore_prototype))
end


return ui_module
local columns_module = {}

---@alias render_function fun(sites_gui: LuaGuiElement, site: yarm_site, player_data: player_data): LuaGuiElement

---@class column_properties
---@field alignment "left"|"center"|"right"
---@field render render_function

local white = util.color("fff")

---Make a label and attach it to the given element
---@param target LuaGuiElement
---@param name string? Name of the label, if any
---@param caption LocalisedString? Content of the label
---@param color Color? Defaults to white
---@return LuaGuiElement el The new label
function columns_module.make_label(target, name, caption, color)
    el = target.add { type = "label", name = name, caption = caption }
    el.style.font = "yarm-gui-font"
    el.style.font_color = color or white
    return el
end

---Render an arrow going up, down, or nothing, depending on the given delta and amount. The ratio of
---the delta to the amount determines the color of the arrow.
---@param sites_gui LuaGuiElement The render target that we are placing the arrow onto
---@param delta number The last recorded change in amount
---@param amount number The last recorded amount
function columns_module.render_arrow_for_percent_delta(sites_gui, delta, amount)
    local percent_delta = (100 * (delta or 0) / (amount or 0)) / 5
    local hue = percent_delta >= 0 and (1 / 3) or 0
    local saturation = math.min(math.abs(percent_delta), 1)
    local value = math.min(0.5 + math.abs(percent_delta / 2), 1)
    local el = sites_gui.add({ type = "label", caption = (amount == 0 and "") or (delta or 0) >= 0 and "⬆" or "⬇" })
    el.style.font_color = resmon.ui.hsv2rgb(hue, saturation, value)
    return el
end

---@type column_properties
columns_module.rename_button = {
    alignment = "left",
    ---@type render_function
    render = function(sites_gui, site, player_data)
        if site.is_summary then
            return columns_module.make_label(sites_gui)
        end

        if player_data.renaming_site == site.name then
            return sites_gui.add {
                type = "button",
                name = "YARM_rename_site_" .. site.name,
                tooltip = { "YARM-tooltips.rename-site-cancel" },
                style = "YARM_rename_site_cancel",
                tags = { site = site.name } }
        else
            return sites_gui.add {
                type = "button",
                name = "YARM_rename_site_" .. site.name,
                tooltip = { "YARM-tooltips.rename-site-named", site.name },
                style = "YARM_rename_site",
                tags = { site = site.name } }
        end
    end
}

local function is_first_site(site, player_data)
    return player_data.ui.first_site == site.name
end

---@type column_properties
columns_module.surface_name = {
    alignment = "right",
    ---@type render_function
    render = function (sites_gui, site, player_data)
        local surface_name = resmon.locale.surface_name(site.surface)
        if not is_first_site(site, player_data) then
            surface_name = ""
        end

        return columns_module.make_label(
            sites_gui,
            "YARM_label_surface_"..site.name,
            player_data.ui.split_by_surface and surface_name or "",
            nil)
    end,
}

---@type column_properties
columns_module.site_name = {
    alignment = "left",
    ---@type render_function
    render = function (sites_gui, site, player_data)
        local site_name = site.name ---@type LocalisedString
        if site.is_summary then
            if is_first_site(site, player_data) then
                site_name = { "YARM-category-totals" }
            else
                site_name = ""
            end
        end
        return columns_module.make_label(sites_gui, "YARM_label_site_"..site.name, site_name)
    end
}

---@type column_properties
columns_module.remaining_percent = {
    alignment = "right",
    ---@type render_function
    render = function (sites_gui, site, player_data)
        return columns_module.make_label(
            sites_gui,
            "YARM_label_percent_"..site.name,
            string.format("%.1f%%", site.remaining_permille / 10),
            player_data.ui.site_colors[site.name])
    end
}

---@type column_properties
columns_module.site_amount = {
    alignment = "right",
    ---@type render_function
    render = function (sites_gui, site, player_data)
        local display_amount = resmon.locale.site_amount(site, resmon.locale.format_number)
        return columns_module.make_label(
            sites_gui,
            "YARM_label_amount_"..site.name,
            display_amount,
            player_data.ui.site_colors[site.name])
    end
}

---@type column_properties
columns_module.ore_name = {
    alignment = "left",
    ---@type render_function
    render = function (sites_gui, site, player_data)
        local entity_prototype = prototypes.entity[site.ore_type]
        local caption = {"", resmon.locale.get_rich_text_for_products(entity_prototype)}
        if not player_data.ui.show_compact_columns then
            table.insert(caption, " ")
            table.insert(caption, site.ore_name)
        end
        return columns_module.make_label(
            sites_gui,
            "YARM_label_ore_name_"..site.name,
            caption)
    end
}

---@type column_properties
columns_module.ore_per_minute = {
    alignment = "right",
    ---@type render_function
    render = function (sites_gui, site, player_data)
        return columns_module.make_label(
            sites_gui,
            "YARM_label_ore_per_minute_"..site.name,
            resmon.locale.site_depletion_rate(site),
            player_data.ui.site_colors[site.name])
    end
}

---@type column_properties
columns_module.ore_per_minute_arrow = {
    alignment = "left",
    ---@type render_function
    render = function (sites_gui, site, player_data)
        return columns_module.render_arrow_for_percent_delta(sites_gui, -1 * site.ore_per_minute_delta, site.ore_per_minute)
    end
}

---@type column_properties
columns_module.etd_timespan = {
    alignment = "right",
    ---@type render_function
    render = function (sites_gui, site, player_data)
        return columns_module.make_label(
            sites_gui,
            "YARM_label_etd_timespan_"..site.name,
            resmon.locale.site_time_to_deplete(site),
            player_data.ui.site_colors[site.name])
    end
}

---@type column_properties
columns_module.etd_arrow = {
    alignment = "left",
    ---@type render_function
    render = function (sites_gui, site, player_data)
        return columns_module.render_arrow_for_percent_delta(sites_gui, site.etd_minutes_delta, site.etd_minutes)
    end
}

---@type column_properties
columns_module.etd_is_lifetime = {
    alignment = "center",
    ---@type render_function
    render = function (sites_gui, site, player_data)
        if site.is_summary then
            return columns_module.make_label(sites_gui)
        end

        return columns_module.make_label(
            sites_gui,
            "YARM_label_etd_is_lifetime_"..site.name,
            site.etd_is_lifetime and "[img=quantity-time]" or "[img=utility/played_green]",
            player_data.ui.site_colors[site.name])
    end

}

---@type column_properties
columns_module.site_buttons = {
    alignment = "left",
    ---@type render_function
    render = function (sites_gui, site, player_data)
        local site_buttons = sites_gui.add { type = "flow", name = "YARM_site_buttons_" .. site.name,
            direction = "horizontal", style = "YARM_buttons_h" }

        if not site.is_summary then
            site_buttons.add { type = "button",
                name = "YARM_goto_site_" .. site.name,
                tooltip = { "YARM-tooltips.goto-site" },
                style = "YARM_goto_site",
                tags = { site = site.name } }
            if not player_data.ui.show_compact_columns then
                if site.deleting_since then
                    site_buttons.add { type = "button",
                        name = "YARM_delete_site_" .. site.name,
                        tooltip = { "YARM-tooltips.delete-site-confirm" },
                        style = "YARM_delete_site_confirm",
                        tags = { site = site.name } }
                else
                    site_buttons.add { type = "button",
                        name = "YARM_delete_site_" .. site.name,
                        tooltip = { "YARM-tooltips.delete-site" },
                        style = "YARM_delete_site",
                        tags = { site = site.name } }
                end

                if site.is_site_expanding then
                    site_buttons.add { type = "button",
                        name = "YARM_expand_site_" .. site.name,
                        tooltip = { "YARM-tooltips.expand-site-cancel" },
                        style = "YARM_expand_site_cancel",
                        tags = { site = site.name } }
                else
                    site_buttons.add { type = "button",
                        name = "YARM_expand_site_" .. site.name,
                        tooltip = { "YARM-tooltips.expand-site" },
                        style = "YARM_expand_site",
                        tags = { site = site.name } }
                end
            end
        end
        return site_buttons
    end
}

columns_module.layouts = {
    compact = {
        columns_module.surface_name,
        columns_module.site_name,
        columns_module.ore_name,
        columns_module.etd_timespan,
        columns_module.site_buttons,
    },
    full = {
        columns_module.rename_button,
        columns_module.surface_name,
        columns_module.site_name,
        columns_module.remaining_percent,
        columns_module.site_amount,
        columns_module.ore_name,
        columns_module.ore_per_minute,
        columns_module.ore_per_minute_arrow,
        columns_module.etd_timespan,
        columns_module.etd_arrow,
        columns_module.etd_is_lifetime,
        columns_module.site_buttons,
    }
}

return columns_module
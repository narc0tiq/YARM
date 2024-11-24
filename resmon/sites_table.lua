local sites_table_module = {}
local columns_module = require("resmon.columns")

function sites_table_module.new_compact_table(name)
    ---@class sites_table
    local t = {
        name = name,
        column_count = 5,
        column_alignments = {
            "right", -- surface_name
            "left", -- site_name
            "left", -- ore_name
            "right", -- etd_timespan
            "left", -- site_buttons
        },
        rows = {}, ---@type sites_table_row[]
    }
    return t
end

function sites_table_module.new_site_row(site)
    ---@class sites_table_row
    local row = {
        should_reset_row_count = false,
        ---@type sites_table_cell[]
        cells = {
            sites_table_module.new_surface_name_cell(site),
            sites_table_module.new_site_name_cell(site),
        }
    }
    return row
end

local cell_definitions = {
    surface_name = {
        alignment = "right",
        factory = sites_table_module.new_surface_name_cell,
    },
    site_name = {
        alignment = "left",
        factory = sites_table_module.new_site_name_cell,
    },
    ore_name_compact = {
        alignment = "left",
        factory = sites_table_module.new_ore_name_cell(true),
    },
    ore_name_full = {
        alignment = "left",
        factory = sites_table_module.new_ore_name_cell(false),
    },
    etd_timespan = {
        alignment = "right",
        factory = sites_table_module.new_etd_timespan_cell,
    },
}

local layouts = {
    compact = {
        cell_definitions.surface_name,
        cell_definitions.site_name,
        cell_definitions.ore_name_compact,
        cell_definitions.etd_timespan,
    }
}

---@param get_caption fun(integer):LocalisedString
function sites_table_module.new_label_cell(get_caption)
    ---@class sites_table_cell
    local cell = {}
    function cell.create(container, cell_name, row_num)
        columns_module.make_label(
            container,
            cell_name,
            get_caption(row_num))
    end
    function cell.update(cell_elem, row_num)
        cell_elem.caption = get_caption(row_num)
    end
    return cell
end

function sites_table_module.new_surface_name_cell(site)
    local function get_caption(row_num)
        return row_num ~= 1 and "" or resmon.locale.surface_name(site.surface)
    end
    return sites_table_module.new_label_cell(get_caption)
end

function sites_table_module.new_site_name_cell(site)
    local function get_caption(row_num)
        if not site.is_summary then
            return site.name
        end
        return row_num ~= 1 and "" or { "YARM-category-totals" }
    end
    return sites_table_module.new_label_cell(get_caption)
end

function sites_table_module.new_ore_name_cell(is_compact)
    return function (site)
        local function get_caption()
            local entity_prototype = prototypes.entity[site.ore_type]
            local caption = {"", resmon.locale.get_rich_text_for_products(entity_prototype)}
            if not is_compact then
                table.insert(caption, " ")
                table.insert(caption, site.ore_name)
            end
        end
        return sites_table_module.new_label_cell(get_caption)
    end
end

function sites_table_module.new_etd_timespan_cell(site)
    local function get_caption()
        return resmon.locale.site_time_to_deplete(site)
    end
    return sites_table_module.new_label_cell(get_caption)
end

---@param site yarm_site
---@param player_data player_data
---@return sites_table_cell
function sites_table_module.new_rename_button_cell(site, player_data)
    ---@class sites_table_cell
    local cell = {}
    local config = columns_module.cancelable_buttons.rename_site
    function cell.create(container, cell_name)
        if site.is_summary then
            return columns_module.make_label(container, cell_name)
        end

        container.add(sites_table_module.new_cancelable_button(
            cell_name, site, config,
            player_data.renaming_site == site.name))
    end
    function cell.update(cell_elem)
        if site.is_summary then
            return
        end
        sites_table_module.update_cancelable_button(
            cell_elem, site, config,
            player_data.renaming_site == site.name)
    end
    return cell
end

---@param site yarm_site
---@param player_data player_data
---@return sites_table_cell
function sites_table_module.new_site_buttons_cell(site, player_data)
    ---@class sites_table_cell
    local cell = {}
    function cell.create(container, cell_name)
        if site.is_summary then
            -- No buttons, just fill this space
            return columns_module.make_label(container, cell_name)
        end

        local site_buttons = container.add {
            type = "flow",
            name = cell_name,
            direction = "horizontal",
            style = "YARM_buttons_h" }
        local is_compact = player_data.ui.show_compact_columns

        site_buttons.add {
            type = "button",
            name = "YARM_goto_site",
            tooltip = { "YARM-tooltips.goto-site" },
            style = "YARM_goto_site",
            tags = { operation = "YARM_goto_site", site = site.name }}

        if not is_compact then
            local config = columns_module.cancelable_buttons.delete_site
            site_buttons.add(sites_table_module.new_cancelable_button(
                config.operation, site, config,
                site.deleting_since
            ))

            config = columns_module.cancelable_buttons.expand_site
            site_buttons.add(sites_table_module.new_cancelable_button(
                config.operation, site, config,
                site.is_site_expanding
            ))
        end
    end

    function cell.update(cell_elem)
        if site.is_summary then
            return
        end
        cell_elem.YARM_goto_site.tags = { operation = "YARM_goto_site", site = site.name }
        local config = columns_module.cancelable_buttons.delete_site
        if cell_elem[config.operation] then
            sites_table_module.update_cancelable_button(
                cell_elem[config.operation], site, config, site.deleting_since
            )
        end
        config = columns_module.cancelable_buttons.expand_site
        if cell_elem[config.operation] then
            sites_table_module.update_cancelable_button(
                cell_elem[config.operation], site, config, site.is_site_expanding
            )
        end
    end
    return cell
end

function sites_table_module.new_cancelable_button(name, site, config, is_active)
    local state = is_active and config.active or config.normal
    return {
        type = "button",
        name = name,
        tooltip = { state.tooltip_base, site.name },
        style = state.style,
        tags = { operation = config.operation, site = site.name },
    }
end

function sites_table_module.update_cancelable_button(button, site, config, is_active)
    local state = is_active and config.active or config.normal
    button.tags = { operation = config.operation, site = site.name }
    button.tooltip = { state.tooltip_base, site.name }
    button.style = state.style
end

return sites_table_module
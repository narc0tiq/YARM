local sites_table_module = {}
local columns_module = require("resmon.columns")


local cell_definitions = {
    surface_name = {
        alignment = "right",
        factory = function () return sites_table_module.new_surface_name_cell end,
    },
    site_name = {
        alignment = "left",
        factory = function () return sites_table_module.new_site_name_cell end,
    },
    ore_name_compact = {
        alignment = "left",
        factory = function () return sites_table_module.new_ore_name_cell(true) end,
    },
    ore_name_full = {
        alignment = "left",
        factory = function () return sites_table_module.new_ore_name_cell(false) end,
    },
    etd_timespan = {
        alignment = "right",
        factory = function () return sites_table_module.new_etd_timespan_cell end,
    },
    site_buttons_compact = {
        alignment = "left",
        factory = function () return sites_table_module.new_site_buttons_cell(true) end,
    },
    site_buttons_full = {
        alignment = "left",
        factory = function () return sites_table_module.new_site_buttons_cell(false) end,
    }
}

sites_table_module.layouts = {
    compact = {
        cell_definitions.surface_name,
        cell_definitions.site_name,
        cell_definitions.ore_name_compact,
        cell_definitions.etd_timespan,
        cell_definitions.site_buttons_compact,
    },
}

local function get_column_alignments_from_layout(layout)
    local alignments = {}
    for i, cell in pairs(layout) do
        alignments[i] = cell.alignment
    end
    return alignments
end

function sites_table_module.new_table(layout, name)
    ---@class sites_table
    local t = {
        ---@type string Will be the name of the table GUI element
        name = name,
        ---@type integer Number of columns in the current table layout
        column_count = #layout,
        ---@type TextAlign[] Horizontal alignment of text within each column
        column_alignments = get_column_alignments_from_layout(layout),
        ---@type sites_table_row[] The rows of the table
        rows = {}, ---@type sites_table_row[]
    }

    ---Add a row representing the given site, using the layout to generate cells
    ---@param site yarm_site
    ---@return sites_table_row
    function t.add_site_row(site)
        ---@class sites_table_row
        local row = {
            ---@type boolean If true, row_num will reset back to 1 after this row is rendered
            should_reset_row_count = false,
            ---@type sites_table_cell[] The cells of this row
            cells = {} }
        for i, cell in pairs(layout) do
            row.cells[i] = cell.factory()(site)
        end
        table.insert(t.rows, row)
        return row
    end

    ---Add a row dividing between groups of, e.g. surfaces
    ---@return sites_table_row
    function t.add_divider_row()
        ---@type sites_table_row
        local row = { should_reset_row_count = true, cells = {} }
        for i, _ in pairs(layout) do
            row.cells[i] = sites_table_module.new_divider_cell()
        end
        table.insert(t.rows, row)
        return row
    end

    return t
end

function sites_table_module.new_divider_cell()
    ---@type sites_table_cell
    return {
        create = function (container, cell_name)
            container.add { type = "line", name = cell_name }.style.minimal_height = 15
        end,
        update = function () end,
    }
end

---@param get_caption fun(integer):LocalisedString
---@param get_color nil|fun():Color
---@return sites_table_cell
function sites_table_module.new_label_cell(get_caption, get_color)
    ---@class sites_table_cell
    local cell = {
        ---Create a cell inside the given container, because it is not already present
        ---@param container LuaGuiElement The containing element (expected to be a table)
        ---@param cell_name string Name of the element to be created
        ---@param row_num integer Display row number (can be reset by dividers)
        create = function(container, cell_name, row_num)
            local color = get_color and get_color() or {1,1,1}
            columns_module.make_label(
                container,
                cell_name,
                get_caption(row_num),
                color)
        end,
        ---Update the cell, because it is already present
        ---@param cell_elem LuaGuiElement The cell element created by create
        ---@param row_num integer Display row number (can be reset by dividers)
        update = function(cell_elem, row_num)
            cell_elem.caption = get_caption(row_num)
            cell_elem.style.font_color = get_color and get_color() or {1,1,1}
        end
    }
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
            return caption
        end
        return sites_table_module.new_label_cell(get_caption)
    end
end

function sites_table_module.new_etd_timespan_cell(site)
    local function get_caption()
        return resmon.locale.site_time_to_deplete(site)
    end
    local function get_color()
        return resmon.ui.site_color(site.etd_minutes, 24*60)
    end
    return sites_table_module.new_label_cell(get_caption, get_color)
end

---@param site yarm_site
---@param player_data player_data
---@return sites_table_cell
function sites_table_module.new_rename_button_cell(site, player_data)
    local cell = {}
    local config = columns_module.cancelable_buttons.rename_site
    function cell.create(container, cell_name)
        if site.is_summary then
            columns_module.make_label(container, cell_name)
            return
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

function sites_table_module.new_site_buttons_cell(is_compact)
    ---@param site yarm_site
    ---@return sites_table_cell
    return function (site)
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

            site_buttons.add {
                type = "button",
                name = "YARM_goto_site",
                tooltip = { "YARM-tooltips.goto-site" },
                style = "YARM_goto_site",
                tags = { operation = "YARM_goto_site", site = site.name }}

                local config = columns_module.cancelable_buttons.delete_site
                site_buttons.add(sites_table_module.new_cancelable_button(
                    config.operation, site, config,
                    site.deleting_since
                ))

            if not is_compact then
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
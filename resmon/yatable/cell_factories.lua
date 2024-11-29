---@class cell_factories_module
local cell_factories_module = {}

local enum = require("resmon/yatable/enum")

cell_factories_module.divider = {
    ---@param table_elem LuaGuiElement
    ---@param cell_name string
    ---@param row_num integer
    ---@param insert_index integer?
    create = function (table_elem, cell_name, row_num, insert_index)
        table_elem.add {
            type = "line",
            name = cell_name,
            index = insert_index,
        }.style.minimal_height = 15
    end,
    update = function ()
        -- Divider does nothing when updated
    end
}

local function new_empty_cell()
    local cell = {
        create = function(container, cell_name, _, insert_index)
            container.add { type = "empty-widget", name = cell_name, index = insert_index }
        end,
        update = function() return end,
    }
    return cell
end

---@param get_caption fun(integer):LocalisedString
---@param get_color nil|fun():Color
local function new_label_cell(get_caption, get_color)
    ---@class yatable_cell
    local cell = {
        ---Create a cell inside the given container, because it is not already present
        ---@param container LuaGuiElement The containing element (expected to be a table)
        ---@param cell_name string Name of the element to be created
        ---@param row_num integer Display row number (can be reset by dividers)
        ---@param insert_index integer? Where in the container's children to add the control
        create = function(container, cell_name, row_num, insert_index)
            local color = get_color and get_color() or {1,1,1}
            local the_label = container.add {
                type = "label",
                name = cell_name,
                index = insert_index,
                caption = get_caption(row_num),
            }
            the_label.style.font = "yarm-gui-font"
            the_label.style.font_color = color
            return the_label
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

local function new_cancelable_button(name, site, config, is_active, insert_index)
    local state = is_active and config.active or config.normal
    return {
        type = "button",
        name = name,
        tooltip = { state.tooltip_base, site.name },
        style = state.style,
        tags = { operation = config.operation, site = site.name },
        index = insert_index,
    }
end

local function update_cancelable_button(button, site, config, is_active)
    local state = is_active and config.active or config.normal
    button.tags = { operation = config.operation, site = site.name }
    button.tooltip = { state.tooltip_base, site.name }
    button.style = state.style
end

---@param site yarm_site
---@param player_data player_data
local function new_rename_button_cell(site, player_data)
    local cell = {}
    local config = resmon.columns.cancelable_buttons.rename_site
    function cell.create(container, cell_name, _, insert_index)
        if site.is_summary then
            container.add { type = "empty-widget", name = cell_name, index = insert_index }
            return
        end

        container.add(new_cancelable_button(
            cell_name, site, config,
            player_data.renaming_site == site.name,
            insert_index))
    end
    function cell.update(cell_elem)
        if site.is_summary then
            return
        end
        update_cancelable_button(
            cell_elem, site, config,
            player_data.renaming_site == site.name)
    end
    return cell
end

local function new_surface_name_cell(site, player_data)
    local function get_caption(row_num)
        if not player_data.ui.split_by_surface or row_num ~= 1 then
            return ""
        end
        return resmon.locale.surface_name(site.surface)
    end
    return new_label_cell(get_caption)
end

local function new_site_name_cell(site)
    local function get_caption(row_num)
        if site.is_summary then
            return row_num ~= 1 and "" or { "YARM-category-totals" }
        end
        return site.name
    end
    return new_label_cell(get_caption)
end

local function ore_name_cell_factory(is_compact)
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
        return new_label_cell(get_caption)
    end
end

---@param site yarm_site
---@param player_data player_data
local function new_etd_timespan_cell(site, player_data)
    local function get_caption()
        return resmon.locale.site_time_to_deplete(site)
    end
    local function get_color()
        return player_data.ui.site_colors[site.name] or {0.7, 0.7, 0.7}
    end
    return new_label_cell(get_caption, get_color)
end

local function new_site_buttons_cell(is_compact)
    return function (site)
        local cell = {}
        function cell.create(container, cell_name, _, insert_index)
            if site.is_summary then
                -- No buttons, just fill this space
                return container.add { type="empty-widget", name = cell_name, index = insert_index }
            end

            local site_buttons = container.add {
                type = "flow",
                name = cell_name,
                direction = "horizontal",
                style = "YARM_buttons_h",
                index = insert_index,
            }

            site_buttons.add {
                type = "button",
                name = "YARM_goto_site",
                tooltip = { "YARM-tooltips.goto-site" },
                style = "YARM_goto_site",
                tags = { operation = "YARM_goto_site", site = site.name }}

            -- TODO Return delete_site to `if not is_compact`
                local config = resmon.columns.cancelable_buttons.delete_site
                site_buttons.add(new_cancelable_button(
                    config.operation, site, config,
                    site.deleting_since
                ))

            if not is_compact then
                config = resmon.columns.cancelable_buttons.expand_site
                site_buttons.add(new_cancelable_button(
                    config.operation, site, config,
                    site.is_site_expanding
                ))
            end
            return site_buttons
        end

        function cell.update(cell_elem)
            if site.is_summary then
                return
            end
            cell_elem.YARM_goto_site.tags = { operation = "YARM_goto_site", site = site.name }
            local config = resmon.columns.cancelable_buttons.delete_site
            if cell_elem[config.operation] then
                update_cancelable_button(
                    cell_elem[config.operation], site, config, site.deleting_since
                )
            end
            config = resmon.columns.cancelable_buttons.expand_site
            if cell_elem[config.operation] then
                update_cancelable_button(
                    cell_elem[config.operation], site, config, site.is_site_expanding
                )
            end
        end
        return cell
    end
end

---@type { [yatable_column_type]: fun(site:yarm_site, player_data:player_data) }
local factories = {
    [enum.column_type.rename_button] = new_rename_button_cell,
    [enum.column_type.surface_name] = new_surface_name_cell,
    [enum.column_type.site_name] = new_site_name_cell,
    [enum.column_type.ore_name_compact] = ore_name_cell_factory(true),
    [enum.column_type.etd_timespan] = new_etd_timespan_cell,
    [enum.column_type.site_buttons_compact] = new_site_buttons_cell(true),
}

---@param column_type yatable_column_type
---@param row_data yatable_row_data
---@param player_data player_data
function cell_factories_module.for_site(column_type, row_data, player_data)
    ---@type fun(site:yarm_site, player_data:player_data)
    local factory = factories[column_type]
    if not factory then
        error("Tried to generate a yatable cell with no factory for column type "..column_type)
    end
    return factory(row_data.site, player_data)
end

---@param column_type yatable_column_type
---@param row_data yatable_row_data
---@param player_data player_data
function cell_factories_module.for_header(column_type, row_data, player_data)
    if column_type == enum.column_type.surface_name then
        if not player_data.ui.split_by_surface then
            return new_empty_cell()
        end
        local function get_caption() return resmon.locale.surface_name(row_data.surface) end
        return new_label_cell(get_caption)
    elseif column_type == enum.column_type.site_name then
        local function get_caption() return { "YARM-category-sites" } end
        return new_label_cell(get_caption)
    else
        return new_empty_cell()
    end
end

return cell_factories_module
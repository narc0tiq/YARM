---@class cell_factories_module
local cell_factories_module = {}

local enum = require("resmon/yatable/enum")

---@alias yatable_cell_factory_create fun(container:LuaGuiElement, cell_name:string, row_num:integer, insert_index:integer?):LuaGuiElement
---@alias yatable_cell_factory_update fun(cell_elem:LuaGuiElement, row_num:integer)

---@class yatable_cell_factory
local unused_example_cell_factory = {
    ---Create a cell inside the given container, because it is not already present
    ---@param container LuaGuiElement The containing element (expected to be a table)
    ---@param cell_name string Name of the element to be created
    ---@param row_num integer Display row number (can be reset by dividers)
    ---@param insert_index integer? Where in the container's children to add the control
    ---@return LuaGuiElement # The rendered GUI element
    ---@type yatable_cell_factory_create
    create = function (container, cell_name, row_num, insert_index)
        -- Normally something like:
        --container.add { type = "some-widget-type", name = cell_name, index = insert_index, etc = "etc" }
        -- May also have special behavior, e.g., if row_num == 1
        return {} --[[ @as LuaGuiElement ]] ---@diagnostic disable-line missing-field
    end,

    ---Update the cell, because it is already present
    ---@param cell_elem LuaGuiElement The cell element created by create
    ---@param row_num integer Display row number (can be reset by dividers)
    ---@type yatable_cell_factory_update
    update = function (cell_elem, row_num)
        -- Normally something like:
        --cell_elem.caption = "some-new-value"
        -- May also have special behavior, e.g., if row_num == 1
    end
}

---@type yatable_cell_factory
cell_factories_module.divider_cell_factory = {
    ---@param table_elem LuaGuiElement
    ---@param cell_name string
    ---@param row_num integer
    ---@param insert_index integer?
    create = function (table_elem, cell_name, row_num, insert_index)
        local cell_elem = table_elem.add {
            type = "line",
            name = cell_name,
            index = insert_index,
        }
        cell_elem.style.minimal_height = 15
        return cell_elem
    end,
    update = function () --[[ Divider does nothing when updated ]] end
}

cell_factories_module.empty_cell_factory = {
    create = function(container, cell_name, _, insert_index)
        return container.add { type = "empty-widget", name = cell_name, index = insert_index }
    end,
    update = function() --[[ Empty cell does nothing when updated ]] end,
}

---@param get_caption fun(integer):LocalisedString
---@param get_color nil|fun():Color
---@param get_tooltip nil|fun():LocalisedString
local function new_label_cell(get_caption, get_color, get_tooltip)
    ---@type yatable_cell_factory
    local cell = {
        create = function(container, cell_name, row_num, insert_index)
            local the_label = container.add {
                type = "label",
                name = cell_name,
                index = insert_index,
                caption = get_caption(row_num),
                tooltip = get_tooltip and get_tooltip(),
            }
            the_label.style.font = "yarm-gui-font"
            the_label.style.font_color = get_color and get_color() or {1,1,1}
            return the_label
        end,
        update = function(cell_elem, row_num)
            cell_elem.caption = get_caption(row_num)
            cell_elem.tooltip = get_tooltip and get_tooltip()
            cell_elem.style.font_color = get_color and get_color() or {1,1,1}
        end
    }
    return cell
end

---Create a cancelable button LuaGuiElement.add_param
---@param name string Name of the button
---@param site yarm_site The site this button is associated with
---@param config cancelable_button_config
---@param is_active boolean Is the button currently active/cancelable
---@param insert_index integer? Insert index when replacing an existing cell
---@return LuaGuiElement.add_param
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

---Update a given cancelable button according to its config and current state
---@param button LuaGuiElement The existing cancelable button
---@param site yarm_site The site this button is associated with
---@param config cancelable_button_config
---@param is_active boolean Is the button currently active/cancelable?
local function update_cancelable_button(button, site, config, is_active)
    local state = is_active and config.active or config.normal
    button.tags = { operation = config.operation, site = site.name }
    button.tooltip = { state.tooltip_base, site.name }
    button.style = state.style
end

local function new_delta_arrow(amount, delta)
    local function get_caption()
        return (amount == 0 and "") or (delta or 0) >= 0 and "⬆" or "⬇"
    end
    local function get_color()
        local percent_delta = (100 * (delta or 0) / (amount or 0)) / 5
        local hue = percent_delta >= 0 and (1 / 3) or 0
        local saturation = math.min(math.abs(percent_delta), 1)
        local value = math.min(0.5 + math.abs(percent_delta / 2), 1)
        return resmon.ui.hsv2rgb(hue, saturation, value)
    end
    return get_caption, get_color
end

---@param row yatable_row_data
---@param player_data player_data
local function new_rename_button_cell(row, player_data)
    local site = row.site --[[@as yarm_site]]
    local cell = {}
    local config = enum.cancelable_buttons.rename_site
    ---@param container LuaGuiElement
    function cell.create(container, cell_name, _, insert_index)
        if site.is_summary then
            return container.add { type = "empty-widget", name = cell_name, index = insert_index }
        end

        return container.add(new_cancelable_button(
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

---@param row yatable_row_data
---@param player_data player_data
local function new_surface_name_cell(row, player_data)
    local site = row.site --[[@as yarm_site]]
    local function get_caption(row_num)
        if not player_data.ui.split_by_surface or row_num ~= 1 then
            return ""
        end
        return resmon.locale.surface_name(site.surface)
    end
    return new_label_cell(get_caption)
end

---@param row yatable_row_data
local function new_site_name_cell(row)
    local function get_caption(row_num)
        if row.site.is_summary then
            return row_num ~= 1 and "" or { "YARM-category-totals" }
        end
        return row.site.name
    end
    return new_label_cell(get_caption)
end

---@param row yatable_row_data
local function new_remaining_percent_cell(row)
    local function get_caption()
        return string.format("%.1f%%", row.site.remaining_permille / 10)
    end
    local function get_color()
        return row.color or {0.7, 0.7, 0.7}
    end
    return new_label_cell(get_caption, get_color)
end

---@param row yatable_row_data
local function new_site_amount_cell(row)
    local function get_caption()
        return resmon.locale.site_amount(row.site, resmon.locale.format_number)
    end
    local function get_color()
        return row.color or {0.7, 0.7, 0.7}
    end
    return new_label_cell(get_caption, get_color)
end

local function ore_name_cell_factory(is_compact)
    ---@param row yatable_row_data
    return function (row)
        local site = row.site --[[@as yarm_site]]
        local function get_caption()
            local entity_prototype = prototypes.entity[site.ore_type]
            local caption = {"",
                resmon.locale.get_rich_text_for_products(entity_prototype),
            }
            if not is_compact then
                table.insert(caption, " ")
                table.insert(caption, site.ore_name)
            end
            return caption
        end
        local function get_tooltip()
            if is_compact then
                local entity_prototype = prototypes.entity[site.ore_type]
                return {"",
                    resmon.locale.site_amount(site, resmon.locale.format_number),
                    " ",
                    resmon.locale.get_rich_text_for_products(entity_prototype),
                    site.ore_name,
                }
            end
        end
        return new_label_cell(get_caption, nil, get_tooltip)
    end
end

---@param row yatable_row_data
local function new_ore_per_minute_cell(row)
    local function get_caption()
        return resmon.locale.site_depletion_rate(row.site)
    end
    local function get_color()
        return row.color or {0.7, 0.7, 0.7}
    end
    return new_label_cell(get_caption, get_color)
end

---@param row yatable_row_data
local function new_ore_per_minute_arrow(row)
    local get_caption, get_color = new_delta_arrow(row.site.ore_per_minute, -1 * row.site.ore_per_minute_delta)
    return new_label_cell(get_caption, get_color)
end

---@param row yatable_row_data
local function new_etd_timespan_cell(row)
    local function get_caption()
        return resmon.locale.site_time_to_deplete(row.site)
    end
    local function get_color()
        return row.color or {0.7, 0.7, 0.7}
    end
    return new_label_cell(get_caption, get_color)
end

---@param row yatable_row_data
local function new_etd_arrow(row)
    local get_caption, get_color = new_delta_arrow(row.site.etd_minutes, row.site.etd_minutes_delta)
    return new_label_cell(get_caption, get_color)
end

---@param row yatable_row_data
local function new_site_status_cell(row)
    if row.site.is_summary then
        return cell_factories_module.empty_cell_factory
    end
    local function get_caption()
        return row.site.etd_is_lifetime and "[img=quantity-time]" or "[img=utility/played_green]"
    end
    local function get_tooltip()
        return { "",
            { "YARM-site-statuses.status-header", row.site.name },
            "\r\n",
            row.site.etd_is_lifetime and { "YARM-site-statuses.site-is-paused" } or { "YARM-site-statuses.site-is-mining" },
        }
    end
    return new_label_cell(get_caption, nil, get_tooltip)
end

local function new_site_buttons_cell(is_compact)
    ---@param row yatable_row_data
    return function (row)
        local site = row.site --[[@as yarm_site]]
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

            if not is_compact then
                local config = enum.cancelable_buttons.delete_site
                site_buttons.add(new_cancelable_button(
                    config.operation, site, config,
                    site.deleting_since
                ))

                config = enum.cancelable_buttons.expand_site
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
            local config = enum.cancelable_buttons.delete_site
            if cell_elem[config.operation] then
                update_cancelable_button(
                    cell_elem[config.operation], site, config, site.deleting_since
                )
            end
            config = enum.cancelable_buttons.expand_site
            if cell_elem[config.operation] then
                update_cancelable_button(
                    cell_elem[config.operation], site, config, site.is_site_expanding
                )
            end
        end
        return cell
    end
end

---@type { [yatable_column_type]: fun(row:yatable_row_data, player_data:player_data) }
local factories = {
    [enum.column_type.rename_button] = new_rename_button_cell,
    [enum.column_type.surface_name] = new_surface_name_cell,
    [enum.column_type.site_name] = new_site_name_cell,
    [enum.column_type.remaining_percent] = new_remaining_percent_cell,
    [enum.column_type.site_amount] = new_site_amount_cell,
    [enum.column_type.ore_name_compact] = ore_name_cell_factory(true),
    [enum.column_type.ore_name_full] = ore_name_cell_factory(false),
    [enum.column_type.ore_per_minute] = new_ore_per_minute_cell,
    [enum.column_type.ore_per_minute_arrow] = new_ore_per_minute_arrow,
    [enum.column_type.etd_timespan] = new_etd_timespan_cell,
    [enum.column_type.etd_arrow] = new_etd_arrow,
    [enum.column_type.site_status] = new_site_status_cell,
    [enum.column_type.site_buttons_compact] = new_site_buttons_cell(true),
    [enum.column_type.site_buttons_full] = new_site_buttons_cell(false),
}

---@param column_type yatable_column_type
---@param row_data yatable_row_data
---@param player_data player_data
function cell_factories_module.for_site(column_type, row_data, player_data)
    local factory = factories[column_type]
    if not factory then
        error("Tried to generate a yatable cell with no factory for column type "..column_type)
    end
    return factory(row_data, player_data)
end

---@param column_type yatable_column_type
---@param row_data yatable_row_data
---@param player_data player_data
function cell_factories_module.for_header(column_type, row_data, player_data)
    if column_type == enum.column_type.surface_name then
        if not player_data.ui.split_by_surface then
            return cell_factories_module.empty_cell_factory
        end
        local function get_caption() return resmon.locale.surface_name(row_data.surface) end
        return new_label_cell(get_caption)
    elseif column_type == enum.column_type.site_name then
        local function get_caption() return { "YARM-category-sites" } end
        return new_label_cell(get_caption)
    else
        return cell_factories_module.empty_cell_factory
    end
end

return cell_factories_module
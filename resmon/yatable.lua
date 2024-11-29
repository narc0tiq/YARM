local yatable_module = {}

local enum = require("resmon/yatable/enum")
local cell_factories = require("resmon/yatable/cell_factories")

yatable_module.row_type = enum.row_type

---@param root LuaGuiElement
---@param t table
---@return LuaGuiElement
local function get_or_create_table_element(root, t)
    local the_table = root[t.name]

    if the_table.column_count ~= #t.columns + 1 then
        the_table.destroy()
        the_table = nil
    end

    if not the_table then
        the_table = root.add {
            type = "table",
            style = "YARM_site_table",
            name = t.name,
            column_count = #t.columns + 1, -- Every row has an empty flow in whose tags we keep row-level data
        }
        local column_alignments = the_table.style.column_alignments
        for i, column in pairs(t.columns) do
            column_alignments[i+1] = column.alignment
        end
    end
    return the_table
end

local function row_name(row_index)
    return "row_"..row_index
end

local function cell_name(row_index, column_index)
    return row_name(row_index).."_col_"..column_index
end

---@param table_elem LuaGuiElement
---@param row_index integer
local function delete_rendered_row(table_elem, row_index)
    for i = 1, table_elem.column_count do
        local cell_name = cell_name(row_index, i)
        if table_elem[cell_name] then
            table_elem[cell_name].destroy()
        end
    end
    if table_elem[row_name(row_index)] then
        table_elem[row_name(row_index)].destroy()
    end
end

local function trim_extra_rows(table_elem, target_row_count)
    -- Trim extra rows (rendered by a previous run but no longer used)
    local row_count = math.ceil(#table_elem.children / table_elem.column_count)
    if row_count > target_row_count then
        for i = target_row_count + 1, row_count do
            delete_rendered_row(table_elem, i)
        end
    end
end

local function get_or_create_row_element(table_elem, row_index, row_data)
    local row_elem = table_elem[row_name(row_index)]
    if not row_elem or not row_elem.valid then
        row_elem = table_elem.add {
            name = row_name(row_index),
            type = "empty-widget",
            tags = { type = row_data.type }
        }
    end
    return row_elem
end

local function get_cell_factories(row_data, columns, player_data)
    local result = {}

    for i, column_data in ipairs(columns) do
        if row_data.type == enum.row_type.divider then
            result[i] = cell_factories.divider
        elseif row_data.type == enum.row_type.site or row_data.type == enum.row_type.summary then
            result[i] = cell_factories.for_site(column_data.type, row_data, player_data)
        elseif row_data.type == enum.row_type.header then
            result[i] = cell_factories.for_header(column_data.type, row_data, player_data)
        else
            error("Trying to render a row with unknown type "..row_data.type)
        end
    end

    return result
end

---@param table_elem LuaGuiElement Parent table
---@param row_index integer
---@param col_index integer
---@param cell_factory any
---@param row_num integer
---@param replace_existing boolean
---@return LuaGuiElement # The created-or-updated element
local function create_or_update_cell(table_elem, row_index, col_index, cell_factory, row_num, replace_existing)
    local cell_name = cell_name(row_index, col_index)
    local cell_elem = table_elem[cell_name]
    if not cell_elem then
        return cell_factory.create(table_elem, cell_name, row_num)
    end

    if replace_existing then
        local index = cell_elem.get_index_in_parent()
        cell_elem.destroy()
        return cell_factory.create(table_elem, cell_name, row_num, index)
    end

    cell_factory.update(cell_elem, row_num)
    return cell_elem
end

---@param root LuaGuiElement
---@param table_data yatable_table
---@param player_data player_data
function yatable_module.render(root, table_data, player_data)
    local the_table = get_or_create_table_element(root, table_data)
    trim_extra_rows(the_table, #table_data.rows)

    -- Create or update rows
    local row_num = 1
    for i, row in ipairs(table_data.rows) do
        local row_elem = get_or_create_row_element(the_table, i, row)
        local replacing_cells = row_elem.tags.type ~= row.type
        for j, cell_factory in ipairs(get_cell_factories(row, table_data.columns, player_data)) do
            create_or_update_cell(the_table, i, j, cell_factory, row_num, replacing_cells)
        end
        resmon.ui.update_tags(row_elem, { type = row.type })

        if row.type == enum.row_type.divider then
            row_num = 1
        else
            row_num = row_num + 1
        end
    end
end

yatable_module.layouts = {
    ---@type yatable_column_data[]
    compact = {
        {
            type = enum.column_type.surface_name,
            alignment = "right",
        },
        {
            type = enum.column_type.site_name,
            alignment = "left",
        },
        ---@class yatable_column_data
        {
            ---@type yatable_column_type
            type = enum.column_type.ore_name_compact,
            ---@type TextAlign
            alignment = "left",
            ---@type boolean?
            is_compact = true,
        },
        {
            type = enum.column_type.etd_timespan,
            alignment = "right",
        },
        {
            type = enum.column_type.site_buttons_compact,
            alignment = "left",
            is_compact = true,
        },
    },
}

local summary_sites = {
    ["nauvis.iron-ore"] = { name = "nauvis.iron-ore", amount = 1234567, --[[ etc.. ]]},
    ["nauvis.copper-ore"] = { name = "nauvis.copper-ore", amount = 1234567, --[[ etc.. ]]},
    ["nauvis.coal"] = { name = "nauvis.coal", amount = 1234567, --[[ etc.. ]]},
    ["nauvis.stone"] = { name = "nauvis.stone", amount = 1234567, --[[ etc.. ]]},
}

local sites = {
    ["NE 123"] = { name = "NE 123", ore_type = prototypes.entity["iron-ore"], amount = 1234567, --[[ etc.. ]]},
}

---@class yatable_table
local example_table = {
    ---@type string
    name = "sites",
    ---@type yatable_column_data[]
    columns = yatable_module.layouts.compact,
    ---@type yatable_row_data[]
    rows = {
        ---@class yatable_row_data
        {
            ---@type yatable_row_type
            type = enum.row_type.site,
            ---@type yarm_site?
            site = summary_sites["nauvis.iron-ore"],
        },
        {
            type = enum.row_type.site,
            site = summary_sites["nauvis.copper-ore"],
        },
        {
            type = enum.row_type.site,
            site = summary_sites["nauvis.coal"],
        },
        {
            type = enum.row_type.site,
            site = summary_sites["nauvis.stone"],
        },
        {
            type = enum.row_type.divider,
        },
        {
            type = enum.row_type.site,
            site = sites["NE 123"],
        },
        -- etc.
    }
}

--yatable_module.render_yatable({}, example_table, {})

return yatable_module

local yatable_module = {}

local enum = require("resmon/yatable/enum")
local cell_factories = require("resmon/yatable/cell_factories")

yatable_module.row_type = enum.row_type

---Create the table LuaGuiElement or retrieves it if it already exists
---@param root LuaGuiElement The container that should hold the table
---@param table_data yatable_table The yatable describing what to render
---@return LuaGuiElement # The created-or-retrieved table element
local function get_or_create_table_element(root, table_data)
    local the_table = root[table_data.name] --[[@as LuaGuiElement?]]

    if the_table and the_table.column_count ~= #table_data.columns + 1 then
        the_table.destroy()
        the_table = nil
    end

    if not the_table then
        the_table = root.add {
            type = "table",
            style = "YARM_site_table",
            name = table_data.name,
            column_count = #table_data.columns + 1, -- Every row has an empty widget in whose tags we keep row-level data
        }
        local column_alignments = the_table.style.column_alignments
        for i, column in pairs(table_data.columns) do
            column_alignments[i+1] = column.alignment
        end
    end
    return the_table
end

---Generate the name of a row (e.g., as a component in a cell name)
---@param row_index integer Index of the row within the yatable `rows` container
---@return string
local function get_row_name(row_index)
    return "row_"..row_index
end

---Generate the name of a cell (row + column position inside the rendered table)
---@param row_index integer Index of the row within the yatable `rows` container
---@param column_index integer Index of the column within the yatable `columns` container
---@return string
local function get_cell_name(row_index, column_index)
    return get_row_name(row_index).."_col_"..column_index
end

---Remove excess rendered rows (e.g., rows rendered by a previous run that are no longer used)
---@param table_elem LuaGuiElement The table element rendering the yatable
---@param target_row_count integer How many rows does the table actually need?
local function trim_extra_rows(table_elem, target_row_count)
    -- Row counting cheese: number of child elements divided by number of columns
    local row_count = math.ceil(#table_elem.children / table_elem.column_count)
    if row_count > target_row_count then
        for i = target_row_count + 1, row_count do
            for j = 1, table_elem.column_count do
                local cell_name = get_cell_name(i, j)
                if table_elem[cell_name] then
                    table_elem[cell_name].destroy()
                end
            end
            if table_elem[get_row_name(i)] then
                table_elem[get_row_name(i)].destroy()
            end
        end
    end
end

---Create or retrieve the GUI element representing a row. This is an empty widget whose
---tags hold row-level data, e.g., the yatable_row_type that was rendered in the current
---run.
---@param table_elem LuaGuiElement The rendered table root element
---@param row_index integer Index of the row being rendered
---@param row_data yatable_row_data Row-level data from the yatable being rendered
---@return LuaGuiElement # The element that was created or retrieved
local function get_or_create_row_element(table_elem, row_index, row_data)
    local row_elem = table_elem[get_row_name(row_index)]
    if not row_elem or not row_elem.valid then
        row_elem = table_elem.add {
            name = get_row_name(row_index),
            type = "empty-widget",
            tags = { type = row_data.type }
        }
    end
    return row_elem
end

---Retrieve the cell factories to produce the given columns for the given row, e.g., for
---a row_type.divider this is a series of `divider` cell factories that should fill a row.
---@param row_data yatable_row_data The row being rendered
---@param columns yatable_column_data[] The columns defined by the current yatable
---@param player_data player_data Given to cell factories to allow for player-specific behavior
---@return yatable_cell_factory[] # Contains one cell factory for each column given. The cell factories close on any necessary data (e.g., the site in the row_data)
local function get_cell_factories(row_data, columns, player_data)
    local result = {}

    for i, column_data in ipairs(columns) do
        if row_data.type == enum.row_type.divider then
            result[i] = cell_factories.divider_cell_factory
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

---Create or update a cell using the given cell factory.
---@param table_elem LuaGuiElement The render container table element
---@param cell_name string Name of the cell to be created/updated
---@param cell_factory yatable_cell_factory The cell factory that can create or update the rendering GUI element
---@param row_num integer The display row number (reset by dividers) to allow special behavior on, e.g., the 1st row
---@param replace_existing boolean If the cell already exists, discard it (e.g., when changing row types, the rendered cell would be of the wrong GUI element type)
---@return LuaGuiElement # The created/updated GUI element
local function create_or_update_cell(table_elem, cell_name, cell_factory, row_num, replace_existing)
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

---Render a given yatable into some kind of root (frame, flow, or otherwise). Creates a GUI
---element of type `table`, named from the value in `table_data.name`.
---@param root LuaGuiElement
---@param table_data yatable_table
---@param player_data player_data Passed to cell renderers, not used directly
function yatable_module.render(root, table_data, player_data)
    local the_table = get_or_create_table_element(root, table_data)
    trim_extra_rows(the_table, #table_data.rows)

    -- Create or update rows
    local row_num = 1
    for i, row in ipairs(table_data.rows) do
        local row_elem = get_or_create_row_element(the_table, i, row)
        local replacing_cells = row_elem.tags.type ~= row.type
        for j, cell_factory in ipairs(get_cell_factories(row, table_data.columns, player_data)) do
            local cell_name = get_cell_name(i, j)
            create_or_update_cell(the_table, cell_name, cell_factory, row_num, replacing_cells)
        end
        resmon.ui.update_tags(row_elem, { type = row.type })

        if row.type == enum.row_type.divider then
            row_num = 1
        else
            row_num = row_num + 1
        end
    end
end

---@class yatable_column_data
local ore_name_compact_column = {
    ---@type yatable_column_type
    type = enum.column_type.ore_name_compact,
    ---@type TextAlign
    alignment = "right",
}

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
        ore_name_compact_column,
        {
            type = enum.column_type.etd_timespan,
            alignment = "right",
        },
        {
            type = enum.column_type.site_buttons_compact,
            alignment = "left",
        },
    },
    full = {
        {
            type = enum.column_type.rename_button,
            alignment = "left",
        },
        {
            type = enum.column_type.surface_name,
            alignment = "right",
        },
        {
            type = enum.column_type.site_name,
            alignment = "left",
        },
        {
            type = enum.column_type.remaining_percent,
            alignment = "right",
        },
        {
            type = enum.column_type.site_amount,
            alignment = "right",
        },
        {
            type = enum.column_type.ore_name_full,
            alignment = "left",
        },
        {
            type = enum.column_type.ore_per_minute,
            alignment = "right",
        },
        {
            type = enum.column_type.ore_per_minute_arrow,
            alignment = "left",
        },
        {
            type = enum.column_type.etd_timespan,
            alignment = "right",
        },
        {
            type = enum.column_type.etd_arrow,
            alignment = "left",
        },
        {
            type = enum.column_type.site_status,
            alignment = "left",
        },
        {
            type = enum.column_type.site_buttons_full,
            alignment = "left",
        },
    }
}

function yatable_module.on_load()
    -- While developing with fmtk, add a debug column to the compact view
    if mods["debugadapter"] then
        table.insert(
            yatable_module.layouts.compact,
            {
                type = enum.column_type.debug,
                alignment = "left",
            })
    end
end

---Example of a working yatable, giving the opportunity to describe the data structures for LuaLS
---@diagnostic disable-next-line: unused-local, unused-function
local function unused_example()
    ---@type summary_site[]
    local summary_sites = {
        ["nauvis.iron-ore"] = { name = "nauvis.iron-ore", amount = 1234567, --[[ etc.. ]]},
        ["nauvis.copper-ore"] = { name = "nauvis.copper-ore", amount = 1234567, --[[ etc.. ]]},
        ["nauvis.coal"] = { name = "nauvis.coal", amount = 1234567, --[[ etc.. ]]},
        ["nauvis.stone"] = { name = "nauvis.stone", amount = 1234567, --[[ etc.. ]]},
    }

    ---@type yarm_site[]
    local sites = {
        ["NE 123"] = { name = "NE 123", ore_type = prototypes.entity["iron-ore"], amount = 1234567, --[[ etc.. ]]},
    }

    ---@class yatable_row_data
    local example_row = {
        ---@type yatable_row_type
        type = enum.row_type.site,
        ---@type yarm_site? When row type is site or summary, this contains the relevant site
        site = summary_sites["nauvis.iron-ore"],
        ---@type Color When row type is site or summary, this contains the site color
        color = { 1, 1, 1 },
        ---@type LuaSurface? When row type is header, this contains the relevant surface
        surface = game.surfaces.nauvis,
    }

    ---@class yatable_table
    local example_table = {
        ---@type string
        name = "sites",
        ---@type yatable_column_data[]
        columns = yatable_module.layouts.compact,
        ---@type yatable_row_data[]
        rows = {
            example_row,
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
end

return yatable_module

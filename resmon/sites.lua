local ui_module = require("resmon.ui")

---@module "settings"

---@class sites_module
local sites_module = {
    ---@type { [order_by_enum|"default"]: comparator_fun }
    comparators = {},
    filters = {
        [ui_module.FILTER_NONE] = function() return false end,
        [ui_module.FILTER_ALL] = function() return true end,
        [ui_module.FILTER_WARNINGS] = function(site, player)
            local remaining = site.etd_minutes
            local threshold_hours = site.is_summary and "timeleft_totals" or "timeleft"
            return remaining ~= -1 and remaining <= player.mod_settings["YARM-warn-" .. threshold_hours].value * 60
        end,
    },
}

---@alias comparator_fun fun(left: yarm_site, right: yarm_site): boolean

---Compare sites by remaining percentage, followed by when they were created (oldest first) and
---finally an index comparison. Is the fallback comparator for most others, as well as the normal
---default.
sites_module.comparators["default"] = function(left, right)
    if left.remaining_permille ~= right.remaining_permille then
        return left.remaining_permille < right.remaining_permille
    elseif left.added_at ~= right.added_at then
        return left.added_at < right.added_at
    else
        return (left.index or 0) < (right.index or 0)
    end
end

---Same as the default comparator: ORDERBY percentage ASC, added_at ASC, name ASC
sites_module.comparators["percent-remaining"] = sites_module.comparators.default

---Compare sites by ore resource prototype name, then default comparator if they're the same
sites_module.comparators["ore-type"] = function(left, right)
    if left.ore_type == right.ore_type then
        return sites_module.comparators.default(left, right)
    end

    return left.ore_type < right.ore_type
end

---Compare sites by amount of resource remaining, then default comparator if they're the same
sites_module.comparators["ore-count"] = function(left, right)
    if left.amount == right.amount then
        return sites_module.comparators.default(left, right)
    end

    return left.amount < right.amount
end

---Compare sites by estimated time remaining, with "never" sorted at the bottom. Sites with
---the same ETD as each other will sort by the default comparator.
sites_module.comparators["etd"] = function(left, right)
    if left.etd_minutes == right.etd_minutes then
        return sites_module.comparators.default(left, right)
    end
    -- infinite time to depletion is indicated when etd_minutes == -1
    -- we want sites with infinite depletion time at the end of the list
    if left.etd_minutes < 0 or right.etd_minutes < 0 then
        -- left and right are not equal AND one of them is -1
        -- (they are not both -1 because then they'd be equal)
        -- and we want -1 to be at the end of the list
        -- so reverse the sort order in this case
        return left.etd_minutes > right.etd_minutes
    end
    -- these are both real etd estimates so sort normally
    return left.etd_minutes < right.etd_minutes
end

---Sort numerically by index (generally in order of creation)
sites_module.comparators["numeric"] = function(left, right)
    return left.index < right.index
end

---Return an iterator providing the given sites in the given player's preferred (configured) order
---@param site_container { [any]:yarm_site }
---@param player LuaPlayer
---@return fun():yarm_site?
function sites_module.in_player_order(site_container, player)
    local order_by = player.mod_settings["YARM-order-by"].value --[[@as order_by_enum]]
    local comparator = sites_module.comparators[order_by] or sites_module.comparators.default
    return sites_module.in_order(site_container, comparator)
end

---Return an iterator providing the given sites in the order determined by the given comparator
---@param site_container { [any]:yarm_site }
---@param comparator function
---@return fun():yarm_site?
function sites_module.in_order(site_container, comparator)
    -- damn in-place table.sort makes us make a copy first...
    local ordered_sites = {}
    for _, site in pairs(site_container) do
        table.insert(ordered_sites, site)
    end

    table.sort(ordered_sites, comparator)

    local i = 0
    local n = #ordered_sites
    ---@return yarm_site?
    local iterator = function()
        i = i + 1
        if i <= n then return ordered_sites[i] end
    end
    return iterator
end

---Returns the player's force's ore sites on a given surface, in the player's preferred order
---@param player LuaPlayer
---@param surface_name string|boolean? Surface name, e.g. "nauvis" or "gleba"; if not given or a false is given, returns all sites
---@return yarm_site[]
function sites_module.on_surface(player, surface_name)
    local force_data = storage.force_data[player.force.name]
    local filtered_sites = {}
    for site in sites_module.in_player_order(force_data.ore_sites, player) do
        if not surface_name or site.surface.name == surface_name then
            table.insert(filtered_sites, site)
        end
    end
    return filtered_sites
end

---Generate summary sites from the sites given
---@param site_container yarm_site[]
---@param do_split_by_surface boolean If true, generates separate summaries per surface
---@return yarm_site[]
function sites_module.generate_summaries(site_container, do_split_by_surface)
    ---@type yarm_site[]
    local summaries = {}
    for _, site in pairs(site_container) do
        local entity_prototype = prototypes.entity[site.ore_type]
        local is_endless = entity_prototype.infinite_resource
        local summary_id = site.ore_type .. (do_split_by_surface and site.surface.name or "")
        if not summaries[summary_id] then
            summaries[summary_id] = resmon.types.new_summary_site_from(site, summary_id)
        end

        local summary_site = summaries[summary_id]
        summary_site.site_count = summary_site.site_count + 1
        summary_site.initial_amount = summary_site.initial_amount + site.initial_amount
        summary_site.amount = summary_site.amount + site.amount
        summary_site.ore_per_minute = summary_site.ore_per_minute + site.ore_per_minute
        summary_site.entity_count = summary_site.entity_count + site.entity_count
        summary_site.remaining_permille = resmon.calc_remaining_permille(summary_site)
        local minimum = is_endless and (summary_site.entity_count * entity_prototype.minimum_resource_amount) or 0
        local amount_left = summary_site.amount - minimum
        summary_site.etd_minutes =
            (summary_site.ore_per_minute ~= 0 and amount_left / (-summary_site.ore_per_minute))
            or (amount_left == 0 and 0)
            or -1
        summary_site.etd_minutes_delta = summary_site.etd_minutes_delta + (site.etd_minutes_delta or 0)
        summary_site.ore_per_minute_delta = summary_site.ore_per_minute_delta + (site.ore_per_minute_delta or 0)
    end
    return summaries
end

---@param container { [string]:summary_site }
---@param site yarm_site
local function add_to_summaries(container, site)
    local summary_id = site.ore_type.." on "..site.surface.name
    if not container[summary_id] then
        container[summary_id] = resmon.types.new_summary_site_from(site, summary_id)
    end

    local entity_prototype = prototypes.entity[site.ore_type]
    local is_endless = entity_prototype.infinite_resource
    local summary_site = container[summary_id]

    summary_site.site_count = summary_site.site_count + 1
    summary_site.initial_amount = summary_site.initial_amount + site.initial_amount
    summary_site.amount = summary_site.amount + site.amount
    summary_site.ore_per_minute = summary_site.ore_per_minute + site.ore_per_minute
    summary_site.entity_count = summary_site.entity_count + site.entity_count
    summary_site.etd_minutes_delta = summary_site.etd_minutes_delta + (site.etd_minutes_delta or 0)
    summary_site.ore_per_minute_delta = summary_site.ore_per_minute_delta + (site.ore_per_minute_delta or 0)

    local minimum = is_endless and (summary_site.entity_count * entity_prototype.minimum_resource_amount) or 0
    local amount_left = summary_site.amount - minimum
    local initial_amount = summary_site.initial_amount - minimum
    summary_site.remaining_permille = initial_amount <= 0 and 0 or math.floor(amount_left * 1000 / initial_amount)
    summary_site.etd_minutes =
        (summary_site.ore_per_minute ~= 0 and amount_left / (-summary_site.ore_per_minute))
        or (amount_left == 0 and 0)
        or -1
end

---In the name of efficiency, we want to iterate force_data.ore_sites exactly once, and pull the
---following out of it:
---  1. only sites that pass the player's current filter
---  2. separated by surface if the option is enabled
---  3. with summaries if the option is enabled
---  4. in the player's preferred (configured) order
---@param unsorted_sites { [any]:yarm_site }
---@param site_filter fun(site:yarm_site?, player:LuaPlayer?)
---@param split_by_surface boolean
---@param with_summary boolean
---@param player LuaPlayer
local function select_sites(unsorted_sites, site_filter, split_by_surface, with_summary, player)
    local result = {}
    for site in sites_module.in_player_order(unsorted_sites, player) do
        local surface_name = split_by_surface and site.surface.name or '*'
        if not result[surface_name] then
            result[surface_name] = { summaries_table = {}, sites = {} }
        end

        if with_summary then
            -- NB: Summaries need to include all sites, not just filtered ones;
            -- e.g., in warnings mode, a single site for iron ore with 25h remaining should
            -- cause the iron ore summary to show as a <48h warning (whereas the site should not)
            add_to_summaries(result[surface_name].summaries_table, site)
        end

        if site_filter(site, player) then
            table.insert(result[surface_name].sites, site)
        end
    end

    for _, surface_data in pairs(result) do
        -- The summaries need to be in player order too
        surface_data.summaries = {}
        for summary in sites_module.in_player_order(surface_data.summaries_table, player) do
            if site_filter(summary, player) then
                table.insert(surface_data.summaries, summary)
            end
        end
        surface_data.summaries_table = nil
    end
    return result
end

---comment
---@param rows yatable_row_data[]
---@param surface_data table
---@param player LuaPlayer
local function add_surface(rows, surface_data, player)
    if not surface_data then
        return -- nothing to add
    end

    for _, summary in ipairs(surface_data.summaries) do
        table.insert(rows, {
            type = resmon.yatable.row_type.summary,
            site = summary,
            color = resmon.ui.color_for_site(summary, player),
        })
    end

    if #surface_data.summaries > 0 and #surface_data.sites > 0 then
        table.insert(rows, {
            type = resmon.yatable.row_type.header,
            surface = surface_data.sites[1].surface,
         })
    end

    for _, site in ipairs(surface_data.sites) do
        table.insert(rows, {
            type = resmon.yatable.row_type.site,
            site = site,
            color = resmon.ui.color_for_site(site, player),
        })
    end
end

function sites_module.create_sites_yatable_data(player)
    local player_data = storage.player_data[player.index]
    local force_data = storage.force_data[player.force.name]

    local layout = player_data.ui.show_compact_columns
        and resmon.yatable.layouts.compact
        or resmon.yatable.layouts.full
    local sites_table = {
        name = "sites",
        columns = layout,
        rows = {},
    }

    local site_filter = resmon.sites.filters[player_data.ui.active_filter] or resmon.sites.filters[ui_module.FILTER_NONE]
    local split_by_surface = player_data.ui.split_by_surface
    local show_sites_summary = player.mod_settings["YARM-show-sites-summary"].value or false

    local sites_by_surface = select_sites(force_data.ore_sites, site_filter, split_by_surface, show_sites_summary, player)
    if not split_by_surface then
        add_surface(sites_table.rows, sites_by_surface['*'], player)
        return sites_table
    end

    for _, surface in pairs(game.surfaces) do
        if sites_by_surface[surface.name] then
            add_surface(sites_table.rows, sites_by_surface[surface.name], player)
            table.insert(sites_table.rows, { type = resmon.yatable.row_type.divider })
        end
    end
    sites_table.rows[#sites_table.rows] = nil -- trim the unnecessary last divider
    return sites_table
end

return sites_module

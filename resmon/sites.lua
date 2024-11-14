local sites_module = {
    comparators = {}
}


sites_module.comparators["default"] = function (left, right)
    if left.remaining_permille ~= right.remaining_permille then
        return left.remaining_permille < right.remaining_permille
    elseif left.added_at ~= right.added_at then
        return left.added_at < right.added_at
    else
        return left.name < right.name
    end
end

sites_module.comparators["percent-remaining"] = sites_module.comparators.default

sites_module.comparators["ore-type"] = function (left, right)
    if left.ore_type == right.ore_type then
        return sites_module.comparators.default(left, right)
    end

    return left.ore_type < right.ore_type
end

sites_module.comparators["ore-count"] = function (left, right)
    if left.amount == right.amount then
        return sites_module.comparators.default(left, right)
    end

    return left.amount < right.amount
end

sites_module.comparators["etd"] = function (left, right)
    if left.amount == right.amount then
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

sites_module.comparators["alphabetical"] = function (left, right)
    return left.name < right.name
end

function sites_module.in_player_order(site_container, player)
    ---@type order_by_enum
    local order_by = player.mod_settings["YARM-order-by"].value
    local comparator = sites_module.comparators[order_by] or sites_module.comparators.default
    return sites_module.in_order(site_container, comparator)
end

function sites_module.in_order(site_container, comparator)
    -- damn in-place table.sort makes us make a copy first...
    local ordered_sites = {}
    for _, site in pairs(site_container) do
        table.insert(ordered_sites, site)
    end

    table.sort(ordered_sites, comparator)

    local i = 0
    local n = #ordered_sites
    return function()
        i = i + 1
        if i <= n then return ordered_sites[i] end
    end
end

function sites_module.on_surface(player, target_surface)
    local force_data = storage.force_data[player.force.name]
    local filtered_sites = {}
    for site in sites_module.in_pr_order(force_data.ore_sites, player) do
        if not target_surface or site.surface.name == target_surface then
            table.insert(filtered_sites, site)
        end
    end
    return filtered_sites
end

local function create_summary_site_from(site, summary_id, is_endless)
    return {
        name = "Total " .. summary_id,
        ore_type = site.ore_type,
        ore_name = site.ore_name,
        initial_amount = 0,
        amount = 0,
        ore_per_minute = 0,
        etd_minutes = 0,
        is_summary = 1,
        entity_count = 0,
        remaining_permille = (is_endless and 0 or 1000),
        site_count = 0,
        etd_minutes_delta = 0,
        ore_per_minute_delta = 0,
        surface = site.surface,
    }
end

function sites_module.generate_summaries(site_container, do_split_by_surface)
    ---@type yarm_site[]
    local summaries = {}
    for _, site in pairs(site_container --[=[@as yarm_site[]]=]) do
        local entity_prototype = prototypes.entity[site.ore_type]
        local is_endless = entity_prototype.infinite_resource
        local summary_id = site.ore_type .. (do_split_by_surface and site.surface.name or "")
        if not summaries[summary_id] then
            summaries[summary_id] = create_summary_site_from(site, summary_id, is_endless)
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

return sites_module
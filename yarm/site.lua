require 'libs/yutil'

if yarm == nil then yarm = {} end

local P = {}
yarm.site = P

P.persisted_members = {}

table.insert(P.persisted_members, 'sites')
P.sites = {
    --[[
        [n] = {
            name: string, -- same as key, so we can pass the site around in one obj
            force: LuaForce,
            surface: LuaSurface,
            product_types: table, -- see REF_PRODUCT_TYPES in yarm/model.lua
            monitors: array = {
                [i] = yarm.monitor.monitors[...]
            }
        }
    ]]
}

-- NB: Not persisted, rebuilt by reindex_sites below
P.site_index = {
    --[[
        [force.name] = {
            [surface.name] = {
                [site.name] = P.sites.indexOf(site)
            }
        }
    ]]
}

--- Reset P.site_index
-- NB: site_index[force.name][surface.name][site.name] = index_in(P.sites)
local function reindex_sites()
    P.site_index = {}
    for idx, site in pairs(P.sites) do
        local container = yutil.table_scan(P.site_index, {site.force.name, site.surface.name})
        container[site.name] = idx
    end
end

function P.on_load()
    reindex_sites()
end

--- Create a site (but do not add it to tracking in P.sites)
function P.new_site(force, surface, site_name)
    return {
        name = site_name,
        force = force,
        surface = surface,
        product_types = {},
        monitors = {},
    }
end

function P.find_or_create(force, surface, site_name)
    -- Find...
    local container = yutil.table_scan(P.site_index, {force.name, surface.name})
    local index = container[site_name]
    if index ~= nil then
        return P.sites[index]
    end

    -- ...or create!
    table.insert(P.sites, P.new_site(force, surface, site_name))
    container[site_name] = #P.sites
    return P.sites[#P.sites]
end

local function collect_production_into_site(site_prod, monitor_prod)
    site_prod.amount = site_prod.amount + monitor_prod.amount
    site_prod.initial_amount = site_prod.initial_amount + monitor_prod.initial_amount
    site_prod.delta_per_minute = site_prod.delta_per_minute + monitor_prod.delta_per_minute

    if monitor_prod.minutes_to_deplete then
        local smtd = site_prod.minutes_to_deplete
        if not smtd.earliest or smtd.earliest > monitor_prod.minutes_to_deplete then
            smtd.earliest = monitor_prod.minutes_to_deplete
        end
        if not smtd.latest or smtd.latest < monitor_prod.minutes_to_deplete then
            smtd.latest = monitor_prod.minutes_to_deplete
        end
    end
end

function P.recount(site)
    site.product_types = {}

    local spt = site.product_types
    for _, monitor in pairs(site.monitors) do
        for key, mondata in pairs(monitor.product_types) do
            if spt[key] == nil then
                spt[key] = yarm.model.new_product_data(key, 0)
                spt[key].minutes_to_deplete = { average = false, first_depleted = false, last_depleted = false }
            end
            collect_production_into_site(spt[key], mondata)
        end
    end

    for _, site_prod in pairs(spt) do
        if site_prod.delta_per_minute == 0 then
            site_prod.minutes_to_deplete.average = false
        else
            site_prod.minutes_to_deplete.average = site_prod.amount / site_prod.delta_per_minute
        end
    end
end

function P.merge(site_to_delete, site_to_grow, player)
    if site_to_delete.surface ~= site_to_grow.surface then
        if player then
            player.print("Can't merge sites on different surfaces!")
        else
            site_to_delete.force.print({"", "Warning: attempted to merge sites ", site_to_delete.name, " and ", site_to_grow.name, ", but they are on different surfaces!"})
        end
        return
    end
    for _, mon_data in pairs(site_to_delete.monitors) do
        P.add_monitor_to(site_to_grow.name, mon_data)
    end
end

function P.delete(site)
    local container = yutil.table_scan(P.site_index, {site.force.name, site.surface.name})
    local index = container[site.name]
    if index == nil then error("Attempted to delete unindexed site -- this should not be possible!") end
    table.remove(P.sites, index)
    reindex_sites()
end

function P.new_from_monitor(mon_data)
    local our_sites = yutil.table_scan(P.site_index, {mon_data.force.name, mon_data.surface.name})
    local site_name = yutil.random_backer_name(our_sites)
    P.add_monitor_to(site_name, mon_data)
end

function P.add_monitor_to(site_name, mon_data)
    P.detach_monitor(mon_data)
    local site = P.find_or_create(mon_data.force, mon_data.surface, site_name)
    table.insert(site.monitors, mon_data)
    mon_data.site_name = site.name
    P.recount(site)
end

function P.detach_monitor(mon_data)
    if not mon_data.site_name then return end -- it does not belong to a site right now
    -- NB: The above should be a rare event; only monitors that were just created should ever trigger this

    local site = P.find_or_create(mon_data.force, mon_data.surface, mon_data.site_name)
    -- NB: mon_data should be literally present inside site.monitors
    local mon_index = yutil.index_of(site.monitors, function(candidate) return candidate == mon_data end)
    table.remove(site.monitors, mon_index)
    P.recount(site)
    if #site.monitors == 0 then P.delete(site) end
end

return P
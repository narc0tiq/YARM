require 'libs/yutil'

if yarm == nil then yarm = {} end

local P = {}
yarm.site = P

P.persisted_members = {}

table.insert(P.persisted_members, 'sites')
P.sites = {
    --[[
        [force.name] = {
            [surface.name] = {
                [site.name] = {
                    name: string, -- same as key, so we can pass the site around in one obj
                    force: LuaForce,
                    surface: LuaSurface,
                    product_types: table, -- see REF_PRODUCT_TYPES in yarm/model.lua
                    monitors: array = {
                        [i] = yarm.monitor.monitors[...]
                    }
                }
            }
        }
    ]]
}

--- Create a site (but do not add it to tracking in P.sites)
function P.create(force, surface, site_name)
    return {
        name = site_name,
        force = force,
        surface = surface,
        product_types = {},
        monitors = {},
    }
end

function P.find_or_create(force, surface, site_name)
    return yutil.table_scan_with_init(
        P.sites,
        {force.name, surface.name, site_name},
        function() return P.create(force, surface, site_name) end)
end

local function collect_into_site_data(site_prod, monitor_prod)
    site_prod.amount = site_prod.amount + monitor_prod.amount
    site_prod.initial_amount = site_prod.initial_amount + monitor_prod.initial_amount
    site_prod.delta_per_minute = site_prod.delta_per_minute + monitor_prod.delta_per_minute
    -- TODO site_prod.minutes_to_deplete.[earliest|latest]
end

function P.recount(site)
    local site_data = site.product_types
    for _, monitor in site.monitors do
        for key, mondata in monitor.product_types do
            if site_data[key] == nil then
                site_data[key] = yarm.model.new_product_data(key, 0)
                site_data[key].minutes_to_deplete = { average = false, first_depleted = false, last_depleted = false }
            end
            collect_into_site_data(site_data[key], mondata)
        end
    end
    -- TODO site_prod.minutes_to_deplete.average?
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
    local container = yutil.table_scan_with_init(P.sites, { site.force.name, site.surface.name })
    container[site.name] = nil
end

function P.new_from_monitor(mon_data)
    -- TODO create a site and then add_monitor_to it
end

function P.add_monitor_to(site_name, mon_data)
    P.detach_monitor(mon_data)
    local site = P.find_or_create(mon_data.force, mon_data.surface, site_name)
    -- TODO
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
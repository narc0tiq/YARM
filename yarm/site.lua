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

function P.add_monitor_to(site_name, mon_data)
    local force_name = mon_data.force.name
    local surf_name = mon_data.surface.name
    -- TODO ensure the initialization of the properties in P.sites along the way
    --local site = P.sites[force_name][surf_name][site_name]
end

function P.new_from_monitor(mon_data)
    -- TODO create a site and then add_monitor_to it
end

function P.merge_sites(deleted_site, accumulated_site, player)
    if deleted_site.surface ~= accumulated_site.surface then
        if player then
            player.print("Can't merge sites on different surfaces!")
        else
            deleted_site.force.print({"", "Warning: attempted to merge sites ", deleted_site.name, " and ", accumulated_site.name, ", but they are on different surfaces!"})
        end
        return
    end
    for _, mon_data in pairs(deleted_site.monitors) do
        P.add_monitor_to(accumulated_site.name, mon_data)
    end
end

return P
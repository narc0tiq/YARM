require 'libs/yutil'

if yarm == nil then yarm = {} end

local P = {}
yarm.model = P

P.persisted_members = {}

function P.iterate_modules()
    return yutil.where(yarm, function (module)
        return type(module) == 'table'
    end)
end

function P.ensure_persistence()
    for name, module in P.iterate_modules() do
        if module.persisted_members then
            for _, member in pairs(module.persisted_members) do
                global[name] = global[name] or {}
                global[name][member] = global[name][member] or module[member] or {}
                module[member] = global[name][member]
            end
        end
    end
end

function P.rebind_persisted()
    for name, module in P.iterate_modules() do
        if module.persisted_members then
            for _, member in pairs(module.persisted_members) do
                if global[name] then
                    module[member] = global[name][member] or module[member] or {}
                end
            end
        end
    end
end

function P.on_init()
    P.ensure_persistence()
end

function P.on_configuration_changed()
    P.ensure_persistence()
end

function P.on_load()
    P.rebind_persisted()
end

function P.create_site()
end

function P.merge_sites(target_name, to_merge_name)
end

function P.reassign_monitor(mon_data, site_name)
end

P.surveys = {
    --[[
        [force.name] = {
            [surface.name] = {
                [survey.name] = {
                    name: string,
                    force: LuaForce,
                    surface: LuaSurface,
                    ore_types: array = {
                        [ore.name] = {
                            ore_name: LocalizedString = { "item-name." .. ore.name } or { "fluid-name." .. ore.name },
                            amount: number, -- sum of `amount` of member monitors on `ore`
                            entity_count: number, -- sum of `entity_count` etc.
                        }
                    }
                }
            }
        }
    ]]
}
table.insert(P.persisted_members, 'surveys')

P.sites = {
    --[[
        [force.name] = {
            [surface.name] = {
                [site.name] = {
                    name: string, -- same as key, so we can pass the site around in one obj
                    force: LuaForce,
                    surface: LuaSurface,
                    ore_types: array = {
                        [ore.name] = {
                            is_active: boolean, -- active ores contribute to `ore_stats`
                            ore_name: LocalizedString = { "entity-name." .. ore.name },
                            amount: number, -- sum of `amount` of member monitors on `ore`
                            initial_amount: number, -- sum of `initial_amount` etc.
                            --...
                            entity_count: number, -- sum of `entity_count` etc.
                        }
                    }
                    monitors: array = {
                        [ent.unit_number] = P.monitors[ent.unit_number]
                    }
                }
            }
        }
    ]]
}
table.insert(P.persisted_members, 'sites')

P.ore_stats = {
    --[[
        [force.name] = { -- e.g., 'player' or 'red-team'
            [ore.name] = {
                amount: number, -- sum of `amount` of `ore` in all `force` sites
                initial_amount: number, -- sum of `initial_amount` of `ore` in all `force` sites
                delta_per_minute: number, -- sum of `delta_per_minute` from `force` `ore` sites
                --...
            }
        }
    ]]
}

-- P.surface_stats?

--function P.add_item()
return P
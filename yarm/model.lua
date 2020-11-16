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

table.insert(P.persisted_members, 'surveys')
P.surveys = {
    --[[
        [force.name] = {
            [surface.name] = {
                [survey.name] = {
                    name: string,
                    force: LuaForce,
                    surface: LuaSurface,
                    product_types: table, -- see REF_PRODUCT_TYPES
                }
            }
        }
    ]]
}

table.insert(P.persisted_members, 'sites')
P.sites = {
    --[[
        [force.name] = {
            [surface.name] = {
                [site.name] = {
                    name: string, -- same as key, so we can pass the site around in one obj
                    force: LuaForce,
                    surface: LuaSurface,
                    product_types: table, -- see REF_PRODUCT_TYPES
                    monitors: array = {
                        [i] = P.monitors[...]
                    }
                }
            }
        }
    ]]
}

P.ore_stats = {
    --[[
        [force.name] = { -- e.g., 'player' or 'red-team'
            product_types: table, -- see REF_PRODUCT_TYPES
            -- other?
        }
    ]]
}

-- P.surface_stats?

--[[ REF_PRODUCT_TYPES
    product_types: array = {
        [product.locale_type .. '.' .. product.name] = {
            -- NB: locale_type := 'fluid-name' | 'product-name' | 'virtual-signal-name'
            is_active: boolean, -- active ores contribute to `ore_stats`
            product_name: LocalizedString = { "item-name." .. product.name } || { 'fluid-name.' .. product.name },
            amount: number, -- monitor amount || sum of member monitors' amounts
            initial_amount: number, -- initially seen amount || sum of member monitors' initial_amounts
            last_update: number, -- tick number of last amount update; allows us to calculate delta_per_minute
            delta_per_minute: number, -- see REF_DELTA_CALC for details
            minutes_to_deplete: number, -- amount / delta_per_minute OR false if delta_per_minute is 0
                -- OR:
            minutes_to_deplete: table = { -- for sites/stats/other monitor containers
                optimistic: number, -- biggest minutes_to_deplete with nonzero delta_per_minute
                pessimistic: number, -- smallest minutes_to_deplete
                average: number, -- site amount / site delta_per_minute
            }
            entity_count: number, -- only if sourced from infinite resource entity
        }
    }
]]

--[[ REF_DELTA_CALC
    When calculating the delta_per_minute:
    - delta_amount = difference between the current_amount and the recorded amount
    - delta_ticks = difference between the current_tick and the last_update tick
    - delta_update_percent = configuration read [0.1-1]
    - momentary_delta_per_minute = delta_amount * 3600 / delta_ticks
    - delta_per_minute = yutil.linear_ease(delta_per_minute, momentary_delta_per_minute, delta_update_percent)
    - amount = current_amount
    - last_update = current_tick
]]

return P
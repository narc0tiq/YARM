require 'libs/yutil'

if yarm == nil then yarm = {} end

local P = {}
yarm.monitor = P

P.persisted_members = {}

--- The authoritative list of all the monitors we ever care about
-- NB: Never remove values from `P.monitors`, it'll mess up the monitor_index!
-- ...or if you do, rebuild the index, but it'd need a full table scan...
table.insert(P.persisted_members, 'monitors')
P.monitors = {
    --[[
        [#P.monitors + 1] = {
            monitor: LuaEntity,
            pole: LuaEntity, -- the invisible pole that forces circuit connection
            tick_added: number,
            force: LuaForce,
            surface: LuaSurface,
            position: LuaPosition,
            site_name: string,
            product_types: table, -- see REF_PRODUCT_TYPES in model.lua
        }
    ]]
}

--- An index of unit_number to index in `P.monitors`
-- NB: Not persisted; recreated on_load, maintained by add_monitor
P.monitor_index = {
    --[[
        [mon.unit_number] = P.monitors.indexOf(mon)
    ]]
}

P.monitor_index_force = {
    --[[
        [mon.force.name] = {
            P.monitors.indexOf(mon1),
            P.monitors.indexOf(mon2),
            --etc.
        }
    ]]
}

--- Allows monitor updates to be spread across multiple ticks by saving
-- necessary data to pause/resume the updates.
table.insert(P.persisted_members, 'monitor_read_state')
P.monitor_read_state = {
    --- These will all be iterated next tick regardless of the regular schedule.
    -- Used for monitors that were just added, or which must be refreshed for
    -- some other reason.
    -- NB: This has full monitor data objects, same as values in `P.monitors`
    priority_items = {},

    --- Last iterated index; every time the regular tick wants to refresh a
    -- monitor, it continues from here (looping automatically, thanks to
    -- next(P.monitors, last_index))
    last_index = nil,
}

--- Reset P.monitor_index
-- NB: monitor_index[unit_number] = index_in(P.monitors)
local function reindex_monitors()
    P.monitor_index = {}
    P.monitor_index_force = {}
    for idx, mon_data in pairs(P.monitors) do
        if mon_data.monitor and mon_data.monitor.valid then
            P.monitor_index[mon_data.monitor.unit_number] = idx
            local force_container = yutil.table_scan(P.monitor_index_force, {mon_data.force.name})
            table.insert(force_container, idx)
        end
    end
end

function P.on_load()
    reindex_monitors()
end

local function make_mon_data(monitor, pole)
    return {
        monitor = monitor,
        pole = pole,
        tick_added = game.tick,
        force = monitor.force,
        surface = monitor.surface,
        position = monitor.position,
        site_name = false, -- not added to a site yet
        product_types = {},
    }
end

--- Add a monitor (and its pole) to the tracker
function P.add(monitor, pole)
    local mon_data = make_mon_data(monitor, pole)

    table.insert(P.monitors, mon_data)
    P.monitor_index[monitor.unit_number] = #P.monitors
    table.insert(P.monitor_read_state.priority_items, mon_data)

    local behavior = monitor.get_or_create_control_behavior()
    behavior.circuit_read_resources = true
    if monitor.name == yarm.entity.BASIC_MONITOR_NAME then
        behavior.resource_read_mode = defines.control_behavior.mining_drill.resource_read_mode.entire_patch
    else
        behavior.resource_read_mode = defines.control_behavior.mining_drill.resource_read_mode.this_miner
    end

    return mon_data
end

function P.remove(mon_data)
    mon_data.monitor = false
end

function P.get_by_unit_number(unit_number)
    if not P.monitor_index[unit_number] then return nil end
    return P.monitors[P.monitor_index[unit_number]]
end

function P.get_all_by_force(force)
    local result = {}
    for _, idx in pairs(P.monitors_by_force[force.name]) do
        table.insert(result, P.monitors[idx])
    end
    return result
end

local TICK_FREQ = 20 -- Must be a divisor of 300
local PERIODS_IN_5S = 300 / TICK_FREQ

function P.on_update_period(e)
    local state = P.monitor_read_state
    for _, mon_data in pairs(state.priority_items) do
        P.update_monitor(mon_data)
    end
    state.priority_items = {}

    local periodMod = (game.tick / TICK_FREQ) % PERIODS_IN_5S
    if periodMod == 0 then
        state.last_index = nil -- should already be the case, but defensive programming
    elseif state.last_index == nil then
        return -- in period 1..N, no more monitors to update
    end

    local updatesThisPeriod = math.ceil(#P.monitors / PERIODS_IN_5S)
    if periodMod == PERIODS_IN_5S - 1 then
        updatesThisPeriod = #P.monitors -- last period before a reset, must update all remaining
    end

    for i = 1, updatesThisPeriod do
        local key, mon_data = next(P.monitors, state.last_index)
        state.last_index = key
        if key == nil then
            return -- no more monitors to update
        end

        P.update_monitor(mon_data)
    end
end
yarm.on_nth_tick(TICK_FREQ, P.on_update_period)

--- Update the given mon_data table with the monitor's current state.
-- If monitor is no longer valid, it is removed from future updates.
-- @return true if an update was done, false otherwise
function P.update_monitor(mon_data)
    if not mon_data or not mon_data.monitor then return false end
    if not mon_data.monitor.valid then
        mon_data.monitor = false
        return false
    end

    -- NB: Signals are **always** of finite resources only. Infinite resources
    -- always come up as 0 because the monitor has a mining_speed of 0.
    local signals = mon_data.monitor.get_merged_signals() or {}

    -- NB: signals of 0 are not present in the get_merged_signals, but may
    -- still be present in mon_data.product_types... therefore:
    -- 1. create a composite keyed on mon_data.product_types' keys, value = { sigdata = sigdata }
    local composite = {}
    for key, sigdata in pairs(mon_data.product_types) do
        composite[key] = { sigdata = sigdata }
    end
    -- 2. add signals to composite: generate the key and table_merge { sigval = sigval }
    for _, sigval in pairs(signals) do
        local key = yutil.locale_group_from_signal_type(sigval.signal.type) .. '.' .. sigval.signal.name
        composite[key] = yutil.table_merge(composite[key], { sigval = sigval })
    end
    -- TODO: Wireless monitor - add to composite
    -- ¿What if an infinite resource is outputting the same product as a finite one?
    -- Maybe we should have a separate infinite_product_types?

    for key, comp in pairs(composite) do
        mon_data.product_types[key] = P.update_signal(key, comp.sigdata, comp.sigval)
    end
end

function P.update_signal(key, sigdata, sigval)
    -- Updating has three possible states:
    -- a. sigdata missing, sigval present -> return new sigdata table
    -- b. sigdata present, sigval missing -> sigval.count = 0, then fall through to
    -- c. both present -> update amount and calculate deltas
    if not sigdata then
        return yarm.model.new_product_data(key, sigval.count)
    elseif not sigval then
        sigval = { count = 0 }
    end

    local delta_ticks = game.tick - sigdata.last_update
    if delta_ticks <= 0 then
        return sigdata -- No time passed since last count, can't calculate anything
    end

    local delta_update_percent = 0.25 -- TODO read from configuration
    local delta_amount = sigdata.amount - sigval.count
    local momentary_delta_per_minute = delta_amount * 3600 / delta_ticks

    sigdata.amount = sigval.count
    sigdata.delta_per_minute = yutil.linear_ease(sigdata.delta_per_minute, momentary_delta_per_minute, delta_update_percent)
    if sigdata.delta_per_minute <= 0 then -- count either grew or didn't change, therefore no ETD
        sigdata.minutes_to_deplete = false
    else
        sigdata.minutes_to_deplete = sigdata.amount / sigdata.delta_per_minute
    end

    return sigdata
end

function P.on_player_setup_blueprint(e)
    log("on_player_setup_blueprint", serpent.block(e))
end
yarm.on_event(defines.events.on_player_setup_blueprint, P.on_player_setup_blueprint)

function P.on_player_configured_blueprint(e)
    log("on_player_configured_blueprint", serpent.block(e))
end
yarm.on_event(defines.events.on_player_configured_blueprint, P.on_player_configured_blueprint)

return P
require 'model'
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

    --- Tick number when last_index was last reset; used to pause to avoid
    -- iterating more often than once every 300 ticks (which is useless --
    -- miners won't update values any more often than that)
    iteration_start_tick = 0,
}

--- Reset P.monitor_index
-- NB: monitor_index[unit_number] = index_in(P.monitors)
local function reindex_monitors()
    P.monitor_index = {}
    for idx, mon_data in pairs(P.monitors) do
        if mon_data.monitor.valid then
            P.monitor_index[mon_data.monitor.unit_number] = idx
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
        site_name = '',
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
end

function P.remove(mon_data)
    mon_data.monitor = false
end

function P.get_by_unit_number(unit_number)
    if not P.monitor_index[unit_number] then return nil end
    return P.monitors[P.monitor_index[unit_number]]
end

function P.on_tick(e)
    -- TODOs
    -- update monitors in priority queue
    -- if < 299 ticks since starting and next monitor is nil, do nothing
    -- figure out number of monitors to update per 300 ticks
    -- update N monitors
    -- if 299 ticks since starting and next monitor is not nil, update as many monitors as needed to get to nil
end

--- Update the given mon_data table with the monitor's current state.
-- If monitor is no longer valid, it is removed from future updates.
-- @return true if an update was done, false otherwise
function P.update_monitor(mon_data)
    if not mon_data or not mon_data.monitor then return false end
    if not mon_data.monitor.valid then
        mon_data.monitor = false
        return false
    end

    local signals = mon_data.monitor.get_merged_signals()
    -- NB: Signals are **always** of finite resources only. Infinite resources
    -- always come up as 0 because the monitor has a mining_speed of 0.
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
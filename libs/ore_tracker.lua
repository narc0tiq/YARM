--[[

    The Ore Tracker -- a cache for resource entities that are being tracked by YARM.

    Provides two major helpers:
    - add_entity(), which will store an entity's particulars and provide a
    cache key to allow retrieving its data quickly, and
    - get_entity_cache(), which will retrieve a table indexed by the
    previously-mentioned cache key, containing data about the stored entity
    (position, resource_amount, and a reference to the entity itself).

    Internally, the ore tracker also continually iterates its entities and
    updates the cache with their resource_amount, to allow callers to avoid
    having to query the entity directly (thus, not crossing the Lua/C++
    boundary unnecessarily).

    Requires an `on_load` and `on_tick`, and relies on the setting
    'YARM-entities-per-tick' to control the rate of updates.
]]
--

ore_tracker = {
    -- Used for the entity updates spread over multiple ticks
    iterator_state = nil,
    --iterator_key = nil, -- maintained in `global.ore_tracker`!
    iterator_func = nil,

    -- Used to quickly check if an entity is already present.
    -- Built in `on_load` and maintained by `add_entity`, based on
    -- `global.ore_tracker` data.
    position_cache = {},
}

---Turn a position into a string usable as a table key. NB: Duplicate
---also present in resmon.lua
---@param position MapPosition
---@return string
local function position_to_string(position)
    -- scale it up so (hopefully) any floating point component disappears,
    -- then force it to be an integer with %d.  not using util.positiontostr
    -- as it uses %g and keeps the floating point component.
    return string.format("%d,%d", position.x * 100, position.y * 100)
end

---Check if the ore tracker already knows the given entity.
---@param entity LuaEntity Must be a resource entity
---@return boolean
function ore_tracker.has_entity(entity)
    if not entity or not entity.valid or entity.type ~= "resource" then
        return false
    end

    local position_key = position_to_string(entity.position)
    if ore_tracker.position_cache[position_key] then
        return true
    end

    return false
end

---Add an entity to the ore tracker if not already present. The entity must
---be valid and be a resource type.
---@param entity LuaEntity Must be a resource entity
---@return number? index The index of the entity within the ore tracker cache, or nil if the entity could not be added
function ore_tracker.add_entity(entity)
    if not entity or not entity.valid or entity.type ~= "resource" then
        return nil
    end

    if not storage.ore_tracker or not storage.ore_tracker.entities then
        storage.ore_tracker = {
            entities = {},
        }
    end

    local position_key = position_to_string(entity.position)
    if ore_tracker.has_entity(entity) then
        local its_index = ore_tracker.position_cache[position_key]

        -- We're accessing the entity.position anyway, let's also use this
        -- opportunity to update the tracker values (and be 1000% certain
        -- that it's tracking the right entity).
        local tracking_data = storage.ore_tracker.entities[its_index]
        tracking_data.entity = entity
        tracking_data.valid = entity.valid
        tracking_data.position = entity.position
        tracking_data.resource_amount = entity.amount

        return its_index
    end

    -- Otherwise, create the tracking data and store it, including position_cache
    local entities = storage.ore_tracker.entities
    local next_index = #entities + 1
    ---@class ore_tracker_entity
    entities[next_index] = {
        entity = entity,
        valid = entity.valid,
        position = entity.position,
        resource_amount = entity.amount
    }
    ore_tracker.position_cache[position_key] = next_index

    return next_index
end

---Return a view of the ore tracker entity cache.
---@return ore_tracker_entity[]?
---NB: Current implementation actually returns the cache itself; altering it would be a
---bad idea.
function ore_tracker.get_entity_cache()
    if not storage.ore_tracker then
        return nil
    end

    return storage.ore_tracker.entities
end

---Set up the position cache that allows fast lookup from a position to the entity that
---occupies it. This must be done on_load every time, as the cache is not in `storage`
function ore_tracker.on_load()
    -- ...why isn't the cache in storage?
    if not storage.ore_tracker or not storage.ore_tracker.entities then
        return
    end

    for tracker_index, tracking_data in pairs(storage.ore_tracker.entities) do
        local key = position_to_string(tracking_data.position)
        ore_tracker.position_cache[key] = tracker_index
    end
end

---Iterate one tick's worth of entities (configurable), updating their tracking data
---to allow consumers to query a table instead of the entity itself
local function update_entities_this_tick()
    -- ...but why not just query the entity itself?
    if not storage.ore_tracker or not storage.ore_tracker.entities then
        return
    end
    local entities_per_tick = settings.global['YARM-entities-per-tick'].value

    if not ore_tracker.iterator_func then
        local possible_key = nil
        ore_tracker.iterator_func, ore_tracker.iterator_state, possible_key =
            pairs(storage.ore_tracker.entities)

        -- NB: A client joining the server will find iterator_key already set,
        -- and we super-want it to resume from that synchronized key.
        if not storage.ore_tracker.iterator_key then
            storage.ore_tracker.iterator_key = possible_key
        end
    end

    local key = storage.ore_tracker.iterator_key
    local state = ore_tracker.iterator_state
    local iterator = ore_tracker.iterator_func --[[@as function]]
    local tracking_data = nil
    for i = 1, entities_per_tick do
        key, tracking_data = iterator(state, key)
        if key == nil then
            storage.ore_tracker.iterator_key = nil
            ore_tracker.iterator_state = nil
            ore_tracker.iterator_func = nil
            return
        end

        if not tracking_data.entity or not tracking_data.entity.valid then
            tracking_data.resource_amount = 0
            tracking_data.entity = nil
            tracking_data.valid = false
        else
            tracking_data.resource_amount = tracking_data.entity.amount
        end
    end

    storage.ore_tracker.iterator_key = key
    ore_tracker.iterator_state = state
    ore_tracker.iterator_func = iterator
end

---@param event EventData.on_tick
function ore_tracker.on_tick(event)
    update_entities_this_tick()
end

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
    Some testing in Factorio 2.0.20 on 2024-11-21 shows that reading from
    a Lua table is approximately 4x faster than reading the same data from
    an entity, therefore only the ore tracker should be reading from
    entities.

    Requires an `on_load` and `on_tick`, and relies on the setting
    'YARM-entities-per-tick' to control the rate of updates.
]]

---@module "../resmon/types"

---@class ore_tracker_module
local ore_tracker_module = {
    -- Used to quickly check if an entity is already present. Built in `on_load`
    -- and maintained by `add_entity`, based on `global.ore_tracker` data.<br>
    -- E.g.: `local index = position_cache[entity_position(entity)]`
    ---@type {[string]: int}
    position_cache = {},

    ---@type ore_tracker_module.internal
    internal = {},
}

---@class ore_tracker_module.internal
local internal = ore_tracker_module.internal

---Should be called around initialization time (e.g., on_init or on_configuration_changed)
---to allow us to set up our internals correctly.
function ore_tracker_module.init_globals()
    if not storage.ore_tracker then
        storage.ore_tracker = internal.new_ore_tracker_storage()
    end
end

---Perform a one-tick update of the ore tracker; this involves querying a (configurable)
---number of entities about their amounts and updating the internal data store accordingly.
---@param event EventData.on_tick
function ore_tracker_module.on_tick(event)
    internal.update_entities_this_tick()
end

---Add an entity to the ore tracker if not already present. The entity must
---be valid and be a resource type.
---@param entity LuaEntity Must be a resource entity
---@return number? index The index of the entity within the ore tracker cache, or nil if the entity could not be added
function ore_tracker_module.add_entity(entity)
    if not entity or not entity.valid or entity.type ~= "resource" then
        return nil
    end

    -- If it's already in the cache, we just return its index
    local index = ore_tracker_module.index_of(entity)
    if index then
        return index
    end

    -- Otherwise, create the tracking data and store it, and put it in the position_cache
    local tracking_data = internal.new_resource_tracking_data(entity)

    local entities = storage.ore_tracker.entities
    local next_index = #entities + 1
    entities[next_index] = tracking_data

    local position_key = internal.entity_position_to_string(entity)
    ore_tracker_module.position_cache[position_key] = next_index

    return next_index
end

---Get an entity's tracking index (if it's in the cache)
---@param entity LuaEntity Must be a valid resource entity
---@return integer? # The tracker index of the given entity
function ore_tracker_module.index_of(entity)
    local position_key = internal.entity_position_to_string(entity)
    local its_index = ore_tracker_module.position_cache[position_key]

    if its_index then
        -- We're accessing the entity anyway, let's also use this opportunity to
        -- update the tracker values (and be 1000% certain that it's tracking
        -- the right entity).
        internal.update_tracking_data(entity, its_index)
    end

    return its_index
end

---Return a view of the ore tracker entity cache.
---NB: Current implementation actually returns the cache itself; altering it would be a
---bad idea.
---@return resource_tracking_data[]
function ore_tracker_module.get_entity_cache()
    if not storage.ore_tracker then
        return {}
    end
    return storage.ore_tracker.entities
end

---Set up the position cache that allows fast lookup from a position to the entity that
---occupies it. This must be done on_load every time, as the cache is not in `storage`
function ore_tracker_module.on_load()
    if not storage.ore_tracker or not storage.ore_tracker.entities then
        return
    end

    -- Q: Why isn't the cache in storage?
    -- A: For consistency; essentially, we rebuild the cache every time we load so that
    -- if somehow the cached indexes don't make sense anymore, we don't perpetuate the
    -- nonsense. We can _easily_ rebuild it without querying the entities themselves:
    for tracker_index, tracking_data in pairs(storage.ore_tracker.entities) do
        if tracking_data.valid and tracking_data.entity and tracking_data.entity.valid then
            local position_key = internal.entity_position_to_string(tracking_data.entity)
            ore_tracker_module.position_cache[position_key] = tracker_index
        end
    end
end

---Create a new resource_tracking_data from the given entity.
---@param entity LuaEntity Must be valid and a resource type
---@return resource_tracking_data
function internal.new_resource_tracking_data(entity)
    if not entity or not entity.valid or entity.type ~= "resource" then
        error("Cannot add entity to ore tracker that is not a valid resource type")
    end

    ---@class resource_tracking_data
    local resource_tracking_data = {
        entity = entity, ---@type LuaEntity?
        resource_amount = entity.amount,
        valid = entity.valid,
    }
    return resource_tracking_data
end

---@param entity LuaEntity?
---@param its_index integer The target index in the ore tracker
function internal.update_tracking_data(entity, its_index)
    local tracking_data = storage.ore_tracker.entities[its_index]
    if not entity or not entity.valid then
        tracking_data.entity = nil
        tracking_data.valid = false
        tracking_data.resource_amount = 0
        table.insert(storage.ore_tracker.to_be_deleted, its_index)
    else
        tracking_data.entity = entity
        tracking_data.valid = entity.valid
        tracking_data.resource_amount = entity.amount
    end
end

function internal.new_ore_tracker_storage()
    ---@class ore_tracker_storage
    local ore_tracker_storage = {
        ---Keep track of how far along we are when iterating the `entities` for updates
        iterator_key = nil, ---@type integer?
        ---Keep the actual entities, as well as tracking data that is faster to access than entity properties
        entities = {}, ---@type resource_tracking_data[]
        ---Entities that will be deleted after the current iteration run
        to_be_deleted = {}, ---@type resource_tracking_data[]
    }
    return ore_tracker_storage
end

---Convert an entity's location into a string usable as table key. Like `position_to_string`, but
---taking the surface into account as well.
---@param entity LuaEntity
---@return string # A string like "nauvis@12345,12345" where the coordinates are upscaled 100x
function internal.entity_position_to_string(entity)
    -- Scale up x/y so (hopefully) any floating point component disappears, then
    -- force them to be integer with %d. Not using util.positiontostr as it uses %g
    -- and keeps the floating point component.
    return string.format("%s@%d,%d", entity.surface.name, entity.position.x * 100, entity.position.y * 100)
end

---Iterate one tick's worth of entities (configurable), updating their tracking data
---to allow consumers to query a table instead of the entity itself
function internal.update_entities_this_tick()
    if not storage.ore_tracker or not storage.ore_tracker.entities then
        return
    end

    local entities_per_tick = settings.global['YARM-entities-per-tick'].value or 300
    local index = storage.ore_tracker.iterator_key
    for _ = 1, entities_per_tick do
        local tracking_data = nil
        index, tracking_data = next(storage.ore_tracker.entities, index)
        if index == nil then
            -- We finished iterating the table once, bail out now and we'll start again next tick
            storage.ore_tracker.iterator_key = nil
            internal.clear_finished_entities()
            return
        end

        internal.update_tracking_data(tracking_data.entity, index)
    end

    storage.ore_tracker.iterator_key = index
end

---Clear the storage.entities entries registered to be deleted
function internal.clear_finished_entities()
    for _, key in pairs(storage.ore_tracker.to_be_deleted) do
        storage.ore_tracker.entities[key] = nil
    end
    storage.ore_tracker.to_be_deleted = {}
end

return ore_tracker_module
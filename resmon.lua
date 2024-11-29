require "util"
require "libs/array_pair"

local ore_tracker = require "libs/ore_tracker"

---@class resmon_base
resmon = {
    on_click = {},

    -- updated `on_tick` to contain `ore_tracker.get_entity_cache()`
    entity_cache = {},

    click = require("resmon.click"),
    columns = require("resmon.columns"),
    locale = require("resmon.locale"),
    sites = require("resmon.sites"),
    migrations = require("resmon.migrations"),
    types = require("resmon.types"),
    ui = require("resmon.ui"),
    yatable = require("resmon.yatable"),
}

---Check if `haystack` exactly starts with `needle`; case-sensitive
---@param haystack string
---@param needle string
---@return boolean result True if the first `len(needle)` characters in `haystack` are exactly `needle`
function string.starts_with(haystack, needle)
    return string.sub(haystack, 1, string.len(needle)) == needle
end

---Check if `haystack` exactly ends with `needle`; case-sensitive
---@param haystack string
---@param needle string
---@return boolean result True if the last `len(needle)` characters in `haystack` are exactly `needle`
function string.ends_with(haystack, needle)
    return string.sub(haystack, -string.len(needle)) == needle
end

---Initialize/upgrade the storage data (for players and forces)
function resmon.init_globals()
    resmon.init_storage()
    resmon.migrations.perform_migrations()
    for _, player in pairs(game.players) do
        resmon.init_player(player)
    end
end

---Initialize/upgrade the given player
---@param event EventData.on_player_created
function resmon.on_player_created(event)
    local player = game.players[event.player_index]
    resmon.init_player(player)
end

---YARM v0.11.2: Keeping iter_fn in the site means trying to keep a function in `storage`, which
---blocks saving in Factorio 2.0 and would have possibly also led to some mysterious desyncs in
---previous Factorio versions.
---YARM v1.0: iter_fn is just `next(t, k)`
---@param force_data force_data
local function migrate_remove_iter_fn(force_data)
    for _, site in pairs(force_data.ore_sites) do
        if site.iter_fn then
            site.iter_fn = nil ---@diagnostic disable-line: inject-field
        end
    end
    if resmon.site_iterators then
        resmon.site_iterators = nil ---@diagnostic disable-line: inject-field
    end
end

---Initialize the player-level persistent data, e.g. overlays.
---Will also trigger force-level initialization
---@param player LuaPlayer
function resmon.init_player(player)
    resmon.init_force(player.force --[[@as LuaForce]])

    if not storage.player_data then
        storage.player_data = {} ---@type player_data[]
    end

    local player_data = storage.player_data[player.index]
    if not player_data then
        player_data = resmon.types.new_player_data()
    end

    storage.player_data[player.index] = player_data

    resmon.ui.migrate_player_data(player)
end

---Initialize the force-level stored data, e.g. ore sites
---@param force LuaForce
function resmon.init_force(force)
    if not storage.force_data then
        storage.force_data = {} ---@type force_data[]
    end

    local force_data = storage.force_data[force.name]
    if not force_data then
        force_data = resmon.types.new_force_data()
    end

    storage.force_data[force.name] = force_data

    migrate_remove_iter_fn(force_data)
    resmon.sanity_check_sites(force, force_data)
end

---Check if the given table contains the given value as a value
local function table_contains(haystack, needle)
    for _, candidate in pairs(haystack) do
        if candidate == needle then
            return true
        end
    end

    return false
end

---Clean up sites whose resource entities no longer exist, e.g. because of mod removal.
---If any sites were cleaned up, the players on the force owning the site are warned about
---their removal.
---@param force LuaForce
---@param force_data force_data
function resmon.sanity_check_sites(force, force_data)
    local discarded_sites = {}
    local missing_ores = {}

    for name, site in pairs(force_data.ore_sites) do
        local entity_prototype = prototypes.entity[site.ore_type]
        if not entity_prototype or not entity_prototype.valid then
            discarded_sites[#discarded_sites + 1] = name
            if not table_contains(missing_ores, site.ore_type) then
                missing_ores[#missing_ores + 1] = site.ore_type
            end

            if site.chart_tag and site.chart_tag.valid then
                site.chart_tag.destroy()
            end
            force_data.ore_sites[name] = nil
        end
    end

    if #discarded_sites == 0 then
        return
    end

    ---@type LocalisedString
    local message_locale = {
        "YARM-warnings.discard-missing-ore-type",
        table.concat(discarded_sites, ', '),
        table.concat(missing_ores, ', '),
        #discarded_sites,
        #missing_ores,
    }
    force.print(message_locale)
    log({ "", force.name, " received warning: ", message_locale})
end

resmon.entity_position_to_string = ore_tracker.internal.entity_position_to_string

---Turn a position into a string usable as a table key
---@param pos MapPosition
---@return string
local function position_to_string(pos)
    -- scale it up so (hopefully) any floating point component disappears,
    -- then force it to be an integer with %d.  not using util.positiontostr
    -- as it uses %g and keeps the floating point component.
    return string.format("%d,%d", pos.x * 100, pos.y * 100)
end

local function find_resource_at(surface, position)
    -- The position we get is centered in its tile (e.g., {8.5, 17.5}).
    -- Sometimes, the resource does not cover the center, so search the full tile.
    local top_left = { x = position.x - 0.5, y = position.y - 0.5 }
    local bottom_right = { x = position.x + 0.5, y = position.y + 0.5 }

    local stuff = surface.find_entities_filtered { area = { top_left, bottom_right }, type = 'resource' }
    if #stuff < 1 then
        return nil
    end

    return stuff[1] -- there should never be another resource at the exact same coordinates
end

local function find_center(area)
    local xpos = (area.left + area.right) / 2
    local ypos = (area.top + area.bottom) / 2
    return { x = xpos, y = ypos }
end

local function find_center_tile(area)
    local center = find_center(area)
    return { x = math.floor(center.x), y = math.floor(center.y) }
end

---@param event EventData.on_player_selected_area
function resmon.on_player_selected_area(event)
    if event.item ~= 'yarm-selector-tool' then
        return
    end

    local player = game.players[event.player_index]
    local player_data = storage.player_data[player.index]
    local entities = event.entities

    if #entities < 1 then
        entities = { find_resource_at(event.surface, {
            x = 0.5 + math.floor((event.area.left_top.x + event.area.right_bottom.x) / 2),
            y = 0.5 + math.floor((event.area.left_top.y + event.area.right_bottom.y) / 2)
        }) }
    end

    if #entities < 1 then
        -- if we have an expanding site, submit it. else, just drop the current site
        if player_data.current_site and player_data.current_site.is_site_expanding then
            resmon.submit_site(player)
        else
            resmon.clear_current_site(player)
        end
        return
    end

    local entities_by_type = {}
    for _, entity in pairs(entities) do
        if entity.prototype.type == 'resource' then
            entities_by_type[entity.name] = entities_by_type[entity.name] or {}
            table.insert(entities_by_type[entity.name], entity)
        end
    end

    player_data.todo = player_data.todo or {}
    for _, group in pairs(entities_by_type) do table.insert(player_data.todo, group) end
    -- note: resmon.update_players() (via on_tick) will continue the operation from here
end

---@param player LuaPlayer
function resmon.clear_current_site(player)
    local player_data = storage.player_data[player.index]

    player_data.current_site = nil

    while #player_data.overlays > 0 do
        table.remove(player_data.overlays).destroy()
    end
end

---Add a resource to tracking, either creating a new site or expanding the current one
---@param player LuaPlayer
---@param entity LuaEntity
function resmon.add_resource(player, entity)
    if not entity.valid then
        return
    end
    local player_data = storage.player_data[player.index]

    if player_data.current_site and player_data.current_site.ore_type ~= entity.name then
        if player_data.current_site.finalizing then
            resmon.submit_site(player)
        else
            resmon.clear_current_site(player)
        end
    end

    if not player_data.current_site then
        player_data.current_site = resmon.types.new_site(player, entity)
    end


    if player_data.current_site.is_site_expanding then
        player_data.current_site.has_expanded = true -- relevant for the console output
        if not player_data.current_site.original_amount then
            player_data.current_site.original_amount = player_data.current_site.amount
        end
    end

    resmon.add_single_entity(player, entity)
    -- note: resmon.scan_current_site() (via on_tick) will continue the operation from here
end

---Add the given entity to the given player's current site
---@param player LuaPlayer
---@param entity LuaEntity
function resmon.add_single_entity(player, entity)
    local player_data = storage.player_data[player.index]
    local site = player_data.current_site
    if not site then
        return
    end

    local tracker_index = ore_tracker.add_entity(entity)

    if not tracker_index then
        return -- The ore tracker didn't like that entity
    end

    if site.tracker_indices[tracker_index] then
        return -- Don't re-add the same entity (it would mess with the counts)
    end

    -- Reset the finalizing timer
    if site.finalizing then
        site.finalizing = false
    end

    -- Memorize this entity
    site.tracker_indices[tracker_index] = true
    site.entity_count = site.entity_count + 1
    table.insert(site.next_to_scan, entity)
    site.amount = site.amount + entity.amount

    -- Resize the site bounds if necessary
    if entity.position.x < site.extents.left then
        site.extents.left = entity.position.x
    elseif entity.position.x > site.extents.right then
        site.extents.right = entity.position.x
    end
    if entity.position.y < site.extents.top then
        site.extents.top = entity.position.y
    elseif entity.position.y > site.extents.bottom then
        site.extents.bottom = entity.position.y
    end

    -- Give visible feedback, too
    resmon.put_marker_at(entity.surface, entity.position, player, player_data)
end

---Draw a marker (blue highlight) on top of the given position to signify that
---YARM has seen it (either when scanning for a site creation, or when
---re-displaying an expanding site's known resources). Only the player who
---is creating/expanding the site can see the marker
---@param surface LuaSurface
---@param pos MapPosition
---@param player LuaPlayer Who are we rendering this for
---@param player_data player_data
function resmon.put_marker_at(surface, pos, player, player_data)
    if math.floor(pos.x) % settings.global["YARM-overlay-step"].value ~= 0 or
        math.floor(pos.y) % settings.global["YARM-overlay-step"].value ~= 0 then
        return
    end

    local overlay = rendering.draw_rectangle {
        left_top = { math.floor(pos.x), math.floor(pos.y) },
        right_bottom = { math.floor(pos.x + 1), math.floor(pos.y + 1) },
        filled = true,
        color = { 0, 0, 0.5, 0.4 },
        surface = surface,
        players = { player },
        draw_on_ground = true,
    }
    table.insert(player_data.overlays, overlay)
end

---Adjust the given coordinates by 1 tile in the given direction
---@param position MapPosition
---@param direction defines.direction
---@return MapPosition position ±1 tile in x, y, or both
local function shift_position(position, direction)
    if direction == defines.direction.north then
        return { x = position.x, y = position.y - 1 }
    elseif direction == defines.direction.northeast then
        return { x = position.x + 1, y = position.y - 1 }
    elseif direction == defines.direction.east then
        return { x = position.x + 1, y = position.y }
    elseif direction == defines.direction.southeast then
        return { x = position.x + 1, y = position.y + 1 }
    elseif direction == defines.direction.south then
        return { x = position.x, y = position.y + 1 }
    elseif direction == defines.direction.southwest then
        return { x = position.x - 1, y = position.y + 1 }
    elseif direction == defines.direction.west then
        return { x = position.x - 1, y = position.y }
    elseif direction == defines.direction.northwest then
        return { x = position.x - 1, y = position.y - 1 }
    else
        return position
    end
end

---Continue expanding the current site by scanning near known ores to find new one
---@param player LuaPlayer
function resmon.scan_current_site(player)
    local site = storage.player_data[player.index].current_site
    if not site then
        return
    end

    local to_scan = math.min(30, #site.next_to_scan)
    local max_dist = settings.global["YARM-grow-limit"].value
    for i = 1, to_scan do
        local entity = table.remove(site.next_to_scan, 1)
        if entity and entity.valid then
            local entity_position = entity.position
            local surface = entity.surface
            site.first_center = site.first_center or find_center(site.extents)

            -- Look in every direction around this entity...
            for _, dir in pairs(defines.direction) do
                -- ...and if there's a resource, add it
                local search_pos = shift_position(entity_position, dir)
                if max_dist < 0 or util.distance(search_pos, site.first_center) < max_dist then
                    local found = find_resource_at(surface, search_pos)
                    if found and found.name == site.ore_type then
                        resmon.add_single_entity(player, found)
                    end
                end
            end
        end
    end
end

---@enum octant_names
local octant_names = {
    [0] = "E",
    [1] = "SE",
    [2] = "S",
    [3] = "SW",
    [4] = "W",
    [5] = "NW",
    [6] = "N",
    [7] = "NE",
}

---Turn a vector (actually assumed to originate at 0,0, therefore just a world coordinate)
---into an octant (8-way compass heading, e.g. "NW" or "S")
---@param vector MapPosition
---@return octant_names
local function get_octant_name(vector)
    local radians = math.atan2(vector.y, vector.x)
    local octant = math.floor(8 * radians / (2 * math.pi) + 8.5) % 8

    return octant_names[octant]
end

---Mark the player's current site as having finished scanning/expanding. This starts the timer
---that will eventually submit the site
---@param player LuaPlayer
function resmon.finalize_site(player)
    local player_data = storage.player_data[player.index]

    ---@type yarm_site
    local site = player_data.current_site
    site.finalizing = true
    site.finalizing_since = game.tick
    site.initial_amount = site.amount
    site.ore_per_minute = 0
    site.remaining_permille = 1000

    site.center = find_center_tile(site.extents)

    --[[ don't rename a site we've expanded! (if the site name changes it'll create a new site
         instead of replacing the existing one) ]]
    if not site.is_site_expanding then
        site.name = string.format("%s %d", get_octant_name(site.center), util.distance({ x = 0, y = 0 }, site.center))
        if settings.global["YARM-site-prefix-with-surface"].value then
            site.name = string.format("%s %s", site.surface.name, site.name)
        end
    end

    resmon.count_deposits(site, site.added_at % settings.global["YARM-ticks-between-checks"].value)
end

---Submit the player's current site, either adding it to their force's sites or completing
---the site expansion
---@param player LuaPlayer
function resmon.submit_site(player)
    local player_data = storage.player_data[player.index]
    local force_data = storage.force_data[player.force.name]
    local site = player_data.current_site

    if not site then
        return
    end

    force_data.ore_sites[site.name] = site
    resmon.clear_current_site(player)
    if (site.is_site_expanding) then
        if (site.has_expanded) then
            -- reset statistics, the site didn't actually just grow a bunch of ore in existing tiles
            site.last_ore_check = nil
            site.last_modified_amount = nil

            local amount_added = site.amount - site.original_amount
            local sign = amount_added < 0 and '' or '+' -- format_number will handle the negative sign for us (if needed)
            player.print { "YARM-site-expanded", site.name, resmon.locale.format_number(site.amount), site.ore_name,
                sign .. resmon.locale.format_number(amount_added) }
        end
        --[[ NB: deliberately not outputting anything in the case where the player cancelled (or
             timed out) a site expansion without expanding anything (to avoid console spam) ]]

        if site.chart_tag and site.chart_tag.valid then
            site.chart_tag.destroy()
        end
    else
        player.print { "YARM-site-submitted", site.name, resmon.locale.format_number(site.amount), site.ore_name }
    end
    resmon.ui.update_chart_tag(site)

    -- clear site expanding state so we can re-expand the same site again (and get sensible numbers!)
    if (site.is_site_expanding) then
        site.is_site_expanding = nil
        site.has_expanded = nil
        site.original_amount = nil
    end
    resmon.ui.update_force_members(player.force)
end

---Sets up or continues counting the resource amounts within the given site. A count will only start
---if the `site.added_at` matches the current update_cycle (to spread site counting across the range
---of `settings.global["YARM-ticks-between-checks"]`). Each tick of counting will only take up to
---1000 resource entities at a time (counting a large site may take multiple ticks).
---@param site yarm_site
---@param update_cycle integer The current tick modulo ticks-between-checks
function resmon.count_deposits(site, update_cycle)
    -- the site is already being iterated so just continue iterating
    if site.iter_key then
        resmon.tick_deposit_count(site)
        return
    end

    -- the site is not being iterated; is it time to do so?
    local site_update_cycle = site.added_at % settings.global["YARM-ticks-between-checks"].value
    if site_update_cycle ~= update_cycle then
        return
    end

    -- yes, it's time to iterate it; set up the state and get it going!
    site.iter_key = nil
    site.update_amount = 0
    resmon.tick_deposit_count(site)
end

---Count up to 1000 resources in the given site, adding them to the update_amount. If this tick
---finished all the resources in the site, continues with `resmon.finish_deposit_count`
---@param site yarm_site
function resmon.tick_deposit_count(site)
    local index = site.iter_key

    for _ = 1, 1000 do
        index = next(site.tracker_indices, index)
        if index == nil then
            resmon.finish_deposit_count(site)
            return
        end

        local tracking_data = resmon.entity_cache[index]
        if tracking_data and tracking_data.valid then
            site.update_amount = site.update_amount + tracking_data.resource_amount
        else
            site.tracker_indices[index] = nil -- It's permitted to delete from a table being iterated
            site.entity_count = site.entity_count - 1
        end
    end
    site.iter_key = index
end

---As a default case, takes a diff between two values and returns a smoothed
---easing step. However, to force convergence it does *not* smooth diffs below 1
---and clamps smoothed diffs below 10 to be at least 1.
function resmon.smooth_clamp_diff(diff)
    if math.abs(diff) < 1 then
        return diff
    elseif math.abs(diff) < 10 then
        return math.abs(diff) / diff
    end

    return 0.1 * diff
end

---Update the site ore counts and depletion rate/time
---@param site yarm_site
function resmon.finish_deposit_count(site)
    site.iter_key = nil

    if site.last_ore_check then
        if not site.last_modified_amount then
            -- make sure those two values have a default
            site.last_modified_amount = site.amount       --
            site.last_modified_tick = site.last_ore_check --
        end
        local delta_ore_since_last_update = site.last_modified_amount - site.amount
        if delta_ore_since_last_update ~= 0 then
            -- only store the amount and tick from last update if it actually changed
            site.last_modified_tick = site.last_ore_check                                            --
            site.last_modified_amount = site.amount                                                  --
        end
        local delta_ore_since_last_change = (site.update_amount - site.last_modified_amount)         -- use final amount and tick to calculate
        local delta_ticks = game.tick - site.last_modified_tick                                      --
        local new_ore_per_minute = (delta_ore_since_last_change * 3600 / delta_ticks)                -- ease the per minute value over time
        local diff_step = resmon.smooth_clamp_diff(new_ore_per_minute - site.scanned_ore_per_minute) --
        site.scanned_ore_per_minute = site.scanned_ore_per_minute + diff_step                        --
    end

    local entity_prototype = prototypes.entity[site.ore_type]
    local is_endless = entity_prototype.infinite_resource
    local minimum = is_endless and (site.entity_count * entity_prototype.minimum_resource_amount) or 0
    local amount_left = site.amount - minimum

    site.scanned_etd_minutes =
        (site.scanned_ore_per_minute ~= 0 and amount_left / (-site.scanned_ore_per_minute))
        or (amount_left == 0 and 0)
        or -1

    site.amount = site.update_amount
    amount_left = site.amount - minimum
    site.amount_left = amount_left
    if settings.global["YARM-adjust-over-percentage-sites"].value then
        site.initial_amount = math.max(site.initial_amount, site.amount)
    end
    site.last_ore_check = game.tick

    site.remaining_permille = resmon.calc_remaining_permille(site)

    local age_minutes = (game.tick - site.added_at) / 3600
    local depleted = site.initial_amount - site.amount
    site.lifetime_ore_per_minute = -depleted / age_minutes
    site.lifetime_etd_minutes =
        (site.lifetime_ore_per_minute ~= 0 and amount_left / (-site.lifetime_ore_per_minute))
        or (amount_left == 0 and 0)
        or -1

    local old_etd_minutes = site.etd_minutes
    local old_ore_per_minute = site.ore_per_minute
    if site.scanned_etd_minutes == -1 or site.lifetime_etd_minutes <= site.scanned_etd_minutes then
        site.ore_per_minute = site.lifetime_ore_per_minute
        site.etd_minutes = site.lifetime_etd_minutes
        site.etd_is_lifetime = true
    else
        site.ore_per_minute = site.scanned_ore_per_minute
        site.etd_minutes = site.scanned_etd_minutes
        site.etd_is_lifetime = false
    end
    site.etd_minutes_delta = site.etd_minutes - old_etd_minutes
    site.ore_per_minute_delta = site.ore_per_minute - old_ore_per_minute

    -- these are just to prevent errant NaNs
    site.etd_minutes_delta = (site.etd_minutes_delta ~= site.etd_minutes_delta) and 0 or site.etd_minutes_delta
    site.ore_per_minute_delta =
        (site.ore_per_minute_delta ~= site.ore_per_minute_delta) and 0 or site.ore_per_minute_delta

    resmon.ui.update_chart_tag(site)

    script.raise_event(on_site_updated, {
        force_name         = site.force.name,
        site_name          = site.name,
        amount             = site.amount,
        ore_per_minute     = site.ore_per_minute,
        remaining_permille = site.remaining_permille,
        ore_type           = site.ore_type,
        etd_minutes        = site.etd_minutes,
    })
end

---Determine a site's remaining permille based on its current and initial amount. Infinite
---resources count down to their minimum_resource_amount rather than 0
---@param site yarm_site
---@return number # 0-1000 describing how full the site is compared to its initial amount
function resmon.calc_remaining_permille(site)
    local entity_prototype = prototypes.entity[site.ore_type]
    local minimum = entity_prototype.infinite_resource
        and (site.entity_count * entity_prototype.minimum_resource_amount) or 0
    local amount_left = site.amount - minimum
    local initial_amount_available = site.initial_amount - minimum
    return initial_amount_available <= 0 and 0 or math.floor(amount_left * 1000 / initial_amount_available)
end

function resmon.surface_names()
    local names = {}
    for _, surface in pairs(game.surfaces) do
        table.insert(names, surface.name)
    end
    return names
end

---@param event EventData.on_gui_confirmed
function resmon.on_gui_confirmed(event)
    if not event.element or not event.element.valid then
        return
    end
    if event.element.name ~= "new_name" or event.element.parent.name ~= "YARM_site_rename" then
        return
    end

    resmon.click.handlers.YARM_rename_confirm(event)
end

---@param event EventData.on_gui_closed
function resmon.on_gui_closed(event)
    if event.gui_type ~= defines.gui_type.custom then
        return
    end
    if not event.element or not event.element.valid then
        return
    end
    if event.element.name ~= "YARM_site_rename" then
        return
    end

    resmon.click.handlers.YARM_rename_cancel(event)
end

---@param event EventData.CustomInputEvent
function resmon.on_get_selection_tool(event)
    local player = game.players[event.player_index]
    resmon.give_selection_tool(player)
end

---Give the player the YARM selector tool
---@param player LuaPlayer
function resmon.give_selection_tool(player)
    if player.cursor_stack.valid_for_read then
        -- already have something?
        if player.cursor_stack.name == "yarm-selector-tool" then
            return
        end

        player.clear_cursor() -- and it's not a selector tool, so Q it away
    end

    player.cursor_stack.set_stack { name = "yarm-selector-tool" }
end

---Set up the current site to have its entities highlighted (for a site expansion)
---@param player LuaPlayer
function resmon.start_recreate_overlay_existing_site(player)
    local site = storage.player_data[player.index].current_site
    if not site then
        return
    end

    site.is_overlay_being_created = true

    -- forcible cleanup in case we got interrupted during a previous background overlay attempt
    site.entities_to_be_overlaid = {}
    site.entities_to_be_overlaid_count = 0
    site.next_to_overlay = {}
    site.next_to_overlay_count = 0

    for index in pairs(site.tracker_indices) do
        local tracking_data = resmon.entity_cache[index]
        if tracking_data then
            local ent = tracking_data.entity
            if ent and ent.valid then
                local key = position_to_string(ent.position)
                site.entities_to_be_overlaid[key] = ent.position
                site.entities_to_be_overlaid_count = site.entities_to_be_overlaid_count + 1
            end
        end
    end
end

---Intermediate step in highlighting existing entities for the current site
---@param player LuaPlayer
function resmon.process_overlay_for_existing_site(player)
    local player_data = storage.player_data[player.index]
    local site = player_data.current_site
    if not site then
        return
    end

    if site.next_to_overlay_count == 0 then
        if site.entities_to_be_overlaid_count == 0 then
            resmon.end_overlay_creation_for_existing_site(player)
            return
        else
            local ent_key, ent_pos = next(site.entities_to_be_overlaid)
            site.next_to_overlay[ent_key] = ent_pos
        site.next_to_overlay_count = site.next_to_overlay_count + 1
        end
    end

    local to_scan = math.min(30, site.next_to_overlay_count)
    for _ = 1, to_scan do
        resmon.overlay_next_entity_in_existing_site(site, player, player_data)
    end
end

---Overlay the next entity in the given site and scan around it for more
---@param site yarm_site
---@param player LuaPlayer
---@param player_data player_data
function resmon.overlay_next_entity_in_existing_site(site, player, player_data)
    local ent_key, ent_pos = next(site.next_to_overlay)
    local entity = site.surface.find_entity(site.ore_type, ent_pos)
    if not entity or not entity.valid then
        return
    end

    -- put marker down
    resmon.put_marker_at(site.surface, entity.position, player, player_data)

    -- remove it from our to-do lists
    site.entities_to_be_overlaid[ent_key] = nil
    site.entities_to_be_overlaid_count = site.entities_to_be_overlaid_count - 1
    site.next_to_overlay[ent_key] = nil
    site.next_to_overlay_count = site.next_to_overlay_count - 1

    -- Look in every direction around this entity...
    for _, dir in pairs(defines.direction) do
        -- ...and if there's a resource that's not already overlaid, add it
        local found = find_resource_at(site.surface, shift_position(entity.position, dir))
        if found and found.name == site.ore_type then
            local offsetkey = position_to_string(found.position)
            if site.entities_to_be_overlaid[offsetkey] ~= nil and site.next_to_overlay[offsetkey] == nil then
                site.next_to_overlay[offsetkey] = found.position
                site.next_to_overlay_count = site.next_to_overlay_count + 1
            end
        end
    end
end

---Final step in creating overlay for existing site, set it back to the finalizing stage
---@param player LuaPlayer
function resmon.end_overlay_creation_for_existing_site(player)
    local site = storage.player_data[player.index].current_site
    if not site then
        return
    end

    site.is_overlay_being_created = false
    site.finalizing = true
    site.finalizing_since = game.tick
end

---@param event EventData.on_tick
function resmon.update_players(event)
    -- At tick 0 on an MP server initial join, on_init may not have run
    if not storage.player_data then
        return
    end

    for _, player in pairs(game.players) do
        local player_data = storage.player_data[player.index]

        if not player_data then
            resmon.init_player(player)
        elseif not player.connected and player_data.current_site then
            resmon.clear_current_site(player)
        end

        if player_data.current_site then
            local site = player_data.current_site --[[@as yarm_site]]

            if #site.next_to_scan > 0 then
                resmon.scan_current_site(player)
            elseif not site.finalizing then
                resmon.finalize_site(player)
            elseif site.finalizing_since + 120 == event.tick then
                resmon.submit_site(player)
            end

            if site.is_overlay_being_created then
                resmon.process_overlay_for_existing_site(player)
            end
        else
            local todo = player_data.todo or {}
            if #todo > 0 then
                for _, entity in pairs(table.remove(todo)) do
                    resmon.add_resource(player, entity)
                end
            end
        end

        if event.tick % player_data.gui_update_ticks == 15 + player.index then
            resmon.ui.update_player(player)
        end
    end
end

---@param event EventData.on_tick
function resmon.update_forces(event)
    -- At tick 0 on an MP server initial join, on_init may not have run
    if not storage.force_data then
        return
    end

    local update_cycle = event.tick % settings.global["YARM-ticks-between-checks"].value
    for _, force in pairs(game.forces) do
        local force_data = storage.force_data[force.name]

        if not force_data then
            resmon.init_force(force)
        elseif force_data and force_data.ore_sites then
            for _, site in pairs(force_data.ore_sites) do
                if site.deleting_since and site.deleting_since + 120 < game.tick then
                    site.deleting_since = nil
                end
                resmon.count_deposits(site, update_cycle)
            end
        end
    end
end

local function profiler_output(message, stopwatch)
    local output = { "", message, " - ", stopwatch }

    log(output)
    for _, player in pairs(game.players) do
        player.print(output)
    end
end


---@param event EventData.on_tick
local function on_tick_internal(event)
    ore_tracker.on_tick(event)
    resmon.entity_cache = ore_tracker.get_entity_cache()

    resmon.update_players(event)
    resmon.update_forces(event)
end


---@param event EventData.on_tick
local function on_tick_internal_with_profiling(event)
    local big_stopwatch = game.create_profiler()
    local stopwatch = game.create_profiler()
    ore_tracker.on_tick(event)
    stopwatch.stop()
    profiler_output("ore_tracker", stopwatch)

    resmon.entity_cache = ore_tracker.get_entity_cache()

    stopwatch.reset()
    resmon.update_players(event)
    stopwatch.stop()
    profiler_output("update_players", stopwatch)

    stopwatch.reset()
    resmon.update_forces(event)
    stopwatch.stop()
    profiler_output("update_forces", stopwatch)

    big_stopwatch.stop()
    profiler_output("total on_tick", big_stopwatch)
end

---@param event EventData.on_tick
function resmon.on_tick(event)
    local wants_profiling = settings.global["YARM-debug-profiling"].value or false
    if wants_profiling then
        on_tick_internal_with_profiling(event)
    else
        on_tick_internal(event)
    end
end

function resmon.on_load()
    ore_tracker.on_load()
end

function resmon.init_storage()
    -- NB: storage.player_data and storage.force_data are carefully chosen:
    -- - if upgrading from YARM < v1.0, it already exists so we must not initialize storage.versions
    -- - if it's a completely new game, it doesn't exist and we can initialize storage.versions
    -- - if it's not a completely new game and YARM >= 1.0, it exists and so does storage.versions
    if not storage.player_data or not storage.force_data then
        storage = {
            versions = resmon.migrations.default_versions(),
            force_data = {}, ---@type force_data[]
            player_data = {}, ---@type player_data[]
        }
    end
    ore_tracker.init_globals()
end
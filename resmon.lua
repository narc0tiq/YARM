require "util"
require "libs/array_pair"
require "libs/ore_tracker"
local mod_gui = require("mod-gui")
local v = require "semver"

local mod_version = "0.11.2"

---@class resmon_base
resmon = {
    on_click = {},
    site_iterators = {},

    -- updated `on_tick` to contain `ore_tracker.get_entity_cache()`
    entity_cache = nil,

    ui = require("resmon.ui"),
    click = require("resmon.click"),
    sites = require("resmon.sites"),
    locale = require("resmon.locale"),
}

function string.starts_with(haystack, needle)
    return string.sub(haystack, 1, string.len(needle)) == needle
end

function string.ends_with(haystack, needle)
    return string.sub(haystack, -string.len(needle)) == needle
end

function resmon.init_globals()
    for index, _ in pairs(game.players) do
        resmon.init_player(index)
    end
end

function resmon.on_player_created(event)
    resmon.init_player(event.player_index)
end

-- migration v0.8.0: remove remote viewers and put players back into the right entity if available
local function migrate_remove_remote_viewer(player, player_data)
    local real_char = player_data.real_character
    if not real_char or not real_char.valid then
        player.print { "YARM-warn-no-return-possible" }
        return
    end

    player.character = real_char
    if player_data.remote_viewer and player_data.remote_viewer.valid then
        player_data.remote_viewer.destroy()
    end

    player_data.real_character = nil
    player_data.remote_viewer = nil
    player_data.viewing_site = nil
end

local function migrate_remove_minimum_resource_amount(force_data)
    for _, site in pairs(force_data.ore_sites) do
        if site.minimum_resource_amount then site.minimum_resource_amount = nil end
    end
end

local function migrate_remove_iter_fn(force_data)
    for _, site in pairs(force_data.ore_sites) do
        if site.iter_fn then
            resmon.site_iterators[site.name] = site.iter_fn
            site.iter_fn = nil
        end
    end
end

function resmon.init_player(player_index)
    local player = game.players[player_index]
    resmon.init_force(player.force)

    -- migration v0.7.402: YARM_root now in mod_gui, destroy the old one
    local old_root = player.gui.left.YARM_root
    if old_root and old_root.valid then old_root.destroy() end

    local root = mod_gui.get_frame_flow(player).YARM_root
    if root and root.buttons and (
        -- migration v0.8.0: expando now a set of filter buttons, destroy the root and recreate later
            root.buttons.YARM_expando
            -- migration v0.TBD: add toggle bg button
            or not root.buttons.YARM_toggle_bg
            or not root.buttons.YARM_toggle_surfacesplit
            or not root.buttons.YARM_toggle_lite)
    then
        root.destroy()
    end

    if not storage.player_data then storage.player_data = {} end

    local player_data = storage.player_data[player_index]
    if not player_data then player_data = {} end

    if not player_data.gui_update_ticks or player_data.gui_update_ticks == 60 then player_data.gui_update_ticks = 300 end

    if not player_data.overlays then player_data.overlays = {} end

    if player_data.viewing_site then migrate_remove_remote_viewer(player, player_data) end

    storage.player_data[player_index] = player_data

    resmon.ui.migrate_player_data(player)
end

function resmon.init_force(force)
    if not storage.force_data then storage.force_data = {} end

    local force_data = storage.force_data[force.name]
    if not force_data then force_data = {} end

    if not force_data.ore_sites then
        force_data.ore_sites = {} ---@type yarm_site[]
    else
        resmon.migrate_ore_sites(force_data)
        resmon.migrate_ore_entities(force_data)

        resmon.sanity_check_sites(force, force_data)
    end

    migrate_remove_minimum_resource_amount(force_data)
    migrate_remove_iter_fn(force_data)

    storage.force_data[force.name] = force_data
end

local function table_contains(haystack, needle)
    for _, candidate in pairs(haystack) do
        if candidate == needle then
            return true
        end
    end

    return false
end

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

    if #discarded_sites == 0 then return end

    local discard_message = "YARM-warnings.discard-multi-missing-ore-type-multi"
    if #missing_ores == 1 then
        discard_message = "YARM-warnings.discard-multi-missing-ore-type-single"
        if #discarded_sites == 1 then
            discard_message = "YARM-warnings.discard-single-missing-ore-type-single"
        end
    end

    force.print { discard_message, table.concat(discarded_sites, ', '), table.concat(missing_ores, ', ') }
    log { "", force.name, ' was warned: ', { discard_message, table.concat(discarded_sites, ', '),
        table.concat(missing_ores, ', ') } }
end

local function position_to_string(entity)
    -- scale it up so (hopefully) any floating point component disappears,
    -- then force it to be an integer with %d.  not using util.positiontostr
    -- as it uses %g and keeps the floating point component.
    return string.format("%d,%d", entity.x * 100, entity.y * 100)
end

function resmon.migrate_ore_entities(force_data)
    for name, site in pairs(force_data.ore_sites) do
        -- v0.7.15: instead of tracking entities, track their positions and
        -- re-find the entity when needed.
        if site.known_positions then
            site.known_positions = nil
        end
        if site.entities then
            site.entity_positions = array_pair.new()
            for _, ent in pairs(site.entities) do
                if ent.valid then
                    array_pair.insert(site.entity_positions, ent.position)
                end
            end
            site.entities = nil
        end

        -- v0.7.107: change to using the site position as a table key, to
        -- allow faster searching for already-added entities.
        if site.entity_positions then
            site.entity_table = {}
            site.entity_count = 0
            local iter = array_pair.iterator(site.entity_positions)
            while iter.has_next() do
                pos = iter.next()
                local key = position_to_string(pos)
                site.entity_table[key] = pos
                site.entity_count = site.entity_count + 1
            end
            site.entity_positions = nil
        end

        -- v0.8.6: The entities are now tracked by the ore_tracker, and
        -- sites need only maintain ore tracker indices.
        if site.entity_table then
            site.tracker_indices = {}
            site.entity_count = 0

            for _, pos in pairs(site.entity_table) do
                local ent = site.surface.find_entity(site.ore_type, pos)

                if ent and ent.valid then
                    local index = ore_tracker.add_entity(ent)
                    if index then
                        site.tracker_indices[index] = true
                        site.entity_count = site.entity_count + 1
                    end
                end
            end

            site.entity_table = nil
        end
    end
end

function resmon.migrate_ore_sites(force_data)
    for name, site in pairs(force_data.ore_sites) do
        if not site.remaining_permille then
            site.remaining_permille = math.floor(site.amount * 1000 / site.initial_amount)
        end
        if not site.ore_per_minute then site.ore_per_minute = 0 end
        if not site.scanned_ore_per_minute then site.scanned_ore_per_minute = 0 end
        if not site.lifetime_ore_per_minute then site.lifetime_ore_per_minute = 0 end
        if not site.etd_minutes then site.etd_minutes = 1 / 0 end
        if not site.scanned_etd_minutes then site.scanned_etd_minutes = -1 end
        if not site.lifetime_etd_minutes then site.lifetime_etd_minutes = 1 / 0 end
        if not site.etd_is_lifetime then site.etd_is_lifetime = 1 end
        if not site.etd_minutes_delta then site.etd_minutes_delta = 0 end
        if not site.ore_per_minute_delta then site.ore_per_minute_delta = 0 end
    end
end

local function find_resource_at(surface, position)
    -- The position we get is centered in its tile (e.g., {8.5, 17.5}).
    -- Sometimes, the resource does not cover the center, so search the full tile.
    local top_left = { x = position.x - 0.5, y = position.y - 0.5 }
    local bottom_right = { x = position.x + 0.5, y = position.y + 0.5 }

    local stuff = surface.find_entities_filtered { area = { top_left, bottom_right }, type = 'resource' }
    if #stuff < 1 then return nil end

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

function resmon.on_player_selected_area(event)
    if event.item ~= 'yarm-selector-tool' then return end

    local player_data = storage.player_data[event.player_index]
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
            resmon.submit_site(event.player_index)
        else
            resmon.clear_current_site(event.player_index)
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

function resmon.clear_current_site(player_index)
    local player = game.players[player_index]
    local player_data = storage.player_data[player_index]

    player_data.current_site = nil

    while #player_data.overlays > 0 do
        table.remove(player_data.overlays).destroy()
    end
end

function resmon.add_resource(player_index, entity)
    if not entity.valid then return end
    local player = game.players[player_index]
    local player_data = storage.player_data[player_index]

    if player_data.current_site and player_data.current_site.ore_type ~= entity.name then
        if player_data.current_site.finalizing then
            resmon.submit_site(player_index)
        else
            resmon.clear_current_site(player_index)
        end
    end

    if not player_data.current_site then
        ---@class yarm_site
        player_data.current_site = {
            is_summary = false, -- true for summary sites generated by resmon.sites.generate_summaries
            site_count = 0,     -- nonzero only for summaries (see above), where it contains the number of sites being summarized
            name = "New site for " .. player.name,
            added_at = game.tick,
            surface = entity.surface,
            force = player.force,
            center = { x = 0, y = 0 },
            ore_type = entity.name, ---@type string Resource entity prototype name
            ore_name = entity.prototype.localised_name,
            tracker_indices = {},
            entity_count = 0,
            initial_amount = 0,
            amount = 0,
            amount_left = 0,   -- like amount, but for infinite resources it excludes that minimum that the resource will always contain
            update_amount = 0, -- intermediate value while updating a site amount
            extents = {
                left = entity.position.x,
                right = entity.position.x,
                top = entity.position.y,
                bottom = entity.position.y,
            },
            next_to_scan = {},
            entities_to_be_overlaid = {},
            next_to_overlay = {},
            etd_minutes = -1,
            scanned_etd_minutes = -1,
            lifetime_etd_minutes = -1,
            ore_per_minute = 0, ---@type integer The current ore depletion rate, as of the last time the site was updated
            scanned_ore_per_minute = 0,
            lifetime_ore_per_minute = 0,
            etd_is_lifetime = 1,
            last_ore_check = nil,       -- used for ETD easing; initialized when needed,
            last_modified_amount = nil, -- but I wanted to _show_ that they can exist.
            last_modified_tick = nil,   -- essentially the same as last_ore_check
            etd_minutes_delta = 0,
            ore_per_minute_delta = 0, ---@type integer The change in ore-per-minute since the last time we updated the site
            finalizing = false,        -- true after finishing on-tick scans while waiting for player confirmation/cancellation
            finalizing_since = nil,    -- tick number when finalizing turned true
            is_site_expanding = false, -- true when expanding an existing site
            remaining_permille = 1000,
            deleting_since = nil,      -- tick number when player presses "delete" for the first time; if not pressed for the second time within 120 ticks, deletion is cancelled
            chart_tag = nil, ---@type LuaCustomChartTag? the associated chart tag (aka map marker) with the site name and amount
            iter_key = nil,            -- used when iterating the site contents, along with iter_state
            iter_state = nil,          -- also used when iterating the site contents, along with iter_key
        }
    end


    if player_data.current_site.is_site_expanding then
        player_data.current_site.has_expanded = true -- relevant for the console output
        if not player_data.current_site.original_amount then
            player_data.current_site.original_amount = player_data.current_site.amount
        end
    end

    resmon.add_single_entity(player_index, entity)
    -- note: resmon.scan_current_site() (via on_tick) will continue the operation from here
end

function resmon.add_single_entity(player_index, entity)
    local player_data = storage.player_data[player_index]
    local site = player_data.current_site
    local tracker_index = ore_tracker.add_entity(entity)

    if not tracker_index then
        return -- The ore tracker didn't like that entity
    end

    if site.tracker_indices[tracker_index] then
        return -- Don't re-add the same entity (it would mess with the counts)
    end

    -- Reset the finalizing timer
    if site.finalizing then site.finalizing = false end

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
    resmon.put_marker_at(entity.surface, entity.position, player_data)
end

function resmon.put_marker_at(surface, pos, player_data)
    if math.floor(pos.x) % settings.global["YARM-overlay-step"].value ~= 0 or
        math.floor(pos.y) % settings.global["YARM-overlay-step"].value ~= 0 then
        return
    end

    local overlay = surface.create_entity { name = "rm_overlay",
        force = game.forces.neutral,
        position = pos }
    overlay.minable = false
    overlay.destructible = false
    overlay.operable = false
    table.insert(player_data.overlays, overlay)
end

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

function resmon.scan_current_site(player_index)
    local site = storage.player_data[player_index].current_site

    local to_scan = math.min(30, #site.next_to_scan)
    local max_dist = settings.global["YARM-grow-limit"].value
    for i = 1, to_scan do
        local entity = table.remove(site.next_to_scan, 1)
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
                    resmon.add_single_entity(player_index, found)
                end
            end
        end
    end
end

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

local function get_octant_name(vector)
    local radians = math.atan2(vector.y, vector.x)
    local octant = math.floor(8 * radians / (2 * math.pi) + 8.5) % 8

    return octant_names[octant]
end

function resmon.finalize_site(player_index)
    local player_data = storage.player_data[player_index]

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

function resmon.submit_site(player_index)
    local player = game.players[player_index]
    local player_data = storage.player_data[player_index]
    local force_data = storage.force_data[player.force.name]
    local site = player_data.current_site

    force_data.ore_sites[site.name] = site
    resmon.clear_current_site(player_index)
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

function resmon.count_deposits(site, update_cycle)
    if not resmon.site_iterators[site.name] then
        resmon.site_iterators[site.name] = pairs(site.tracker_indices)
    end

    -- the site is currently being iterated so just continue iterating
    if site.iter_key or site.iter_state then
        resmon.tick_deposit_count(site)
        return
    end

    -- the site is not being iterated; is it time to do so?
    local site_update_cycle = site.added_at % settings.global["YARM-ticks-between-checks"].value
    if site_update_cycle ~= update_cycle then
        return
    end

    -- yes, it's time to iterate it; set up the state and get it going!
    _, site.iter_state, site.iter_key = pairs(site.tracker_indices)
    site.update_amount = 0
end

function resmon.tick_deposit_count(site)
    local index = site.iter_key

    for _ = 1, 1000 do
        local iterator = resmon.site_iterators[site.name]
        index = iterator(site.iter_state, index)
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

-- as a default case, takes a diff between two values and returns a smoothed
-- easing step. however to force convergence, it does *not* smooth diffs below 1
-- and clamps smoothed diffs below 10 to be at least 1.
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
    site.iter_state = nil

    if site.last_ore_check then
        if not site.last_modified_amount then             -- make sure those two values have a default
            site.last_modified_amount = site.amount       --
            site.last_modified_tick = site.last_ore_check --
        end
        local delta_ore_since_last_update = site.last_modified_amount - site.amount
        if delta_ore_since_last_update ~= 0 then                                                     -- only store the amount and tick from last update if it actually changed
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
        site.etd_is_lifetime = 1
    else
        site.ore_per_minute = site.scanned_ore_per_minute
        site.etd_minutes = site.scanned_etd_minutes
        site.etd_is_lifetime = 0
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

function resmon.on_gui_confirmed(event)
    if not event.element or not event.element.valid then return end
    if event.element.name ~= "new_name" or event.element.parent.name ~= "YARM_site_rename" then return end

    resmon.click.handlers.YARM_rename_confirm(event)
end

function resmon.on_gui_closed(event)
    if event.gui_type ~= defines.gui_type.custom then return end
    if not event.element or not event.element.valid then return end
    if event.element.name ~= "YARM_site_rename" then return end

    resmon.click.handlers.YARM_rename_cancel(event)
end

function resmon.on_get_selection_tool(event)
    local player = game.players[event.player_index]
    if player.cursor_stack.valid_for_read then -- already have something?
        if player.cursor_stack.name == "yarm-selector-tool" then return end

        player.clear_cursor() -- and it's not a selector tool, so Q it away
    end

    player.cursor_stack.set_stack { name = "yarm-selector-tool" }
end

function resmon.start_recreate_overlay_existing_site(player_index)
    local site = storage.player_data[player_index].current_site
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

function resmon.process_overlay_for_existing_site(player_index)
    local player_data = storage.player_data[player_index]
    local site = player_data.current_site

    if site.next_to_overlay_count == 0 then
        if site.entities_to_be_overlaid_count == 0 then
            resmon.end_overlay_creation_for_existing_site(player_index)
            return
        else
            local ent_key, ent_pos = next(site.entities_to_be_overlaid)
            site.next_to_overlay[ent_key] = ent_pos
            site.next_to_overlay_count = site.next_to_overlay_count + 1
        end
    end

    local to_scan = math.min(30, site.next_to_overlay_count)
    for i = 1, to_scan do
        local ent_key, ent_pos = next(site.next_to_overlay)

        local entity = site.surface.find_entity(site.ore_type, ent_pos)
        local entity_position = entity.position
        local surface = entity.surface
        local key = position_to_string(entity_position)

        -- put marker down
        resmon.put_marker_at(surface, entity_position, player_data)
        -- remove it from our to-do lists
        site.entities_to_be_overlaid[key] = nil
        site.entities_to_be_overlaid_count = site.entities_to_be_overlaid_count - 1
        site.next_to_overlay[key] = nil
        site.next_to_overlay_count = site.next_to_overlay_count - 1

        -- Look in every direction around this entity...
        for _, dir in pairs(defines.direction) do
            -- ...and if there's a resource that's not already overlaid, add it
            local found = find_resource_at(surface, shift_position(entity_position, dir))
            if found and found.name == site.ore_type then
                local offsetkey = position_to_string(found.position)
                if site.entities_to_be_overlaid[offsetkey] ~= nil and site.next_to_overlay[offsetkey] == nil then
                    site.next_to_overlay[offsetkey] = found.position
                    site.next_to_overlay_count = site.next_to_overlay_count + 1
                end
            end
        end
    end
end

function resmon.end_overlay_creation_for_existing_site(player_index)
    local site = storage.player_data[player_index].current_site
    site.is_overlay_being_created = false
    site.finalizing = true
    site.finalizing_since = game.tick
end

function resmon.update_players(event)
    -- At tick 0 on an MP server initial join, on_init may not have run
    if not storage.player_data then return end

    for index, player in pairs(game.players) do
        local player_data = storage.player_data[index]

        if not player_data then
            resmon.init_player(index)
        elseif not player.connected and player_data.current_site then
            resmon.clear_current_site(index)
        end

        if player_data.current_site then
            local site = player_data.current_site

            if #site.next_to_scan > 0 then
                resmon.scan_current_site(index)
            elseif not site.finalizing then
                resmon.finalize_site(index)
            elseif site.finalizing_since + 120 == event.tick then
                resmon.submit_site(index)
            end

            if site.is_overlay_being_created then
                resmon.process_overlay_for_existing_site(index)
            end
        else
            local todo = player_data.todo or {}
            if #todo > 0 then
                for _, entity in pairs(table.remove(todo)) do
                    resmon.add_resource(index, entity)
                end
            end
        end

        if event.tick % player_data.gui_update_ticks == 15 + index then
            resmon.ui.update_player(player)
        end
    end
end

function resmon.update_forces(event)
    -- At tick 0 on an MP server initial join, on_init may not have run
    if not storage.force_data then return end

    local update_cycle = event.tick % settings.global["YARM-ticks-between-checks"].value
    for _, force in pairs(game.forces) do
        local force_data = storage.force_data[force.name]

        if not force_data then
            resmon.init_force(force)
        elseif force_data and force_data.ore_sites then
            for _, site in pairs(force_data.ore_sites) do
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


local function on_tick_internal(event)
    ore_tracker.on_tick(event)
    resmon.entity_cache = ore_tracker.get_entity_cache()

    resmon.update_players(event)
    resmon.update_forces(event)
end


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

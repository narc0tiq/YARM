require "util"
require "libs/array_pair"
require "libs/ore_tracker"
local mod_gui = require("mod-gui")

-- Sanity: site names aren't allowed to be longer than this, to prevent them
-- kicking the buttons off the right edge of the screen
local MAX_SITE_NAME_LENGTH = 50

resmon = {
    on_click = {},
    endless_resources = {},
    filters = {},

    -- updated `on_tick` to contain `ore_tracker.get_entity_cache()`
    entity_cache = nil,
}

function string.starts_with(haystack, needle)
    return string.sub(haystack, 1, string.len(needle)) == needle
end


function string.ends_with(haystack, needle)
    return string.sub(haystack, -string.len(needle)) == needle
end


function resmon.init_globals()
    for index,_ in pairs(game.players) do
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
        player.print{"YARM-warn-no-return-possible"}
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


function resmon.init_player(player_index)
    local player = game.players[player_index]
    resmon.init_force(player.force)

    -- migration v0.7.402: YARM_root now in mod_gui, destroy the old one
    local old_root = player.gui.left.YARM_root
    if old_root and old_root.valid then old_root.destroy() end

    -- migration v0.8.0: expando now a set of filter buttons, destroy the root and recreate later
    local root = mod_gui.get_frame_flow(player).YARM_root
    if root and root.buttons.YARM_expando then root.destroy() end

    if not global.player_data then global.player_data = {} end

    local player_data = global.player_data[player_index]
    if not player_data then player_data = {} end

    if not player_data.gui_update_ticks or player_data.gui_update_ticks == 60 then player_data.gui_update_ticks = 300 end

    if not player_data.overlays then player_data.overlays = {} end

    if player_data.viewing_site then migrate_remove_remote_viewer(player, player_data) end

    global.player_data[player_index] = player_data
end


function resmon.init_force(force)
    if not global.force_data then global.force_data = {} end

    local force_data = global.force_data[force.name]
    if not force_data then force_data = {} end

    if not force_data.ore_sites then
        force_data.ore_sites = {}
    else
        resmon.migrate_ore_sites(force_data)
        resmon.migrate_ore_entities(force_data)

        resmon.sanity_check_sites(force, force_data)
    end

    migrate_remove_minimum_resource_amount(force_data)

    global.force_data[force.name] = force_data
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
        local entity_prototype = game.entity_prototypes[site.ore_type]
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

    force.print{discard_message, table.concat(discarded_sites, ', '), table.concat(missing_ores, ', ')}
    log{"", force.name, ' was warned: ', {discard_message, table.concat(discarded_sites, ', '), table.concat(missing_ores, ', ')}}
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
                    site.tracker_indices[index] = true
                    site.entity_count = site.entity_count + 1
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
        if not site.etd_minutes then site.etd_minutes = -1 end
    end
end


local function find_resource_at(surface, position)
    -- The position we get is centered in its tile (e.g., {8.5, 17.5}).
    -- Sometimes, the resource does not cover the center, so search the full tile.
    local top_left = {x = position.x - 0.5, y = position.y - 0.5}
    local bottom_right = {x = position.x + 0.5, y = position.y + 0.5}

    local stuff = surface.find_entities_filtered{area={top_left, bottom_right}, type='resource'}
    if #stuff < 1 then return nil end

    return stuff[1] -- there should never be another resource at the exact same coordinates
end


function resmon.on_player_selected_area(event)
    if event.item ~= 'yarm-selector-tool' then return end

    local player_data = global.player_data[event.player_index]

    if #event.entities < 1 then
        -- if we have an expanding site, submit it. else, just drop the current site
        if player_data.current_site and player_data.current_site.is_site_expanding then
            resmon.submit_site(event.player_index)
        else
            resmon.clear_current_site(event.player_index)
        end
        return
    end

    for _, entity in pairs(event.entities) do
        if entity.prototype.type == 'resource' then
            resmon.add_resource(event.player_index, entity)
        end
    end
end


function resmon.clear_current_site(player_index)
    local player = game.players[player_index]
    local player_data = global.player_data[player_index]

    player_data.current_site = nil

    while #player_data.overlays > 0 do
        table.remove(player_data.overlays).destroy()
    end
end


function resmon.add_resource(player_index, entity)
    local player = game.players[player_index]
    local player_data = global.player_data[player_index]

    if player_data.current_site and player_data.current_site.ore_type ~= entity.name then
        if player_data.current_site.finalizing then
            resmon.submit_site(player_index)
        else
            resmon.clear_current_site(player_index)
        end
    end

    if not player_data.current_site then
        player_data.current_site = {
            added_at = game.tick,
            surface = entity.surface,
            force = player.force,
            ore_type = entity.name,
            ore_name = entity.prototype.localised_name,
            tracker_indices = {},
            entity_count = 0,
            initial_amount = 0,
            amount = 0,
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
            last_ore_check = nil,       -- used for ETD easing; initialized when needed,
            last_modified_amount = nil, -- but I wanted to _show_ that they can exist.

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
    local player_data = global.player_data[player_index]
    local site = player_data.current_site
    local tracker_index = ore_tracker.add_entity(entity)

    -- Don't re-add the same entity multiple times
    if site.tracker_indices[tracker_index] then return end

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

    local overlay = surface.create_entity{name="rm_overlay",
                                          force=game.forces.neutral,
                                          position=pos}
    overlay.minable = false
    overlay.destructible = false
    overlay.operable = false
    table.insert(player_data.overlays, overlay)
end


local function shift_position(position, direction)
    if direction == defines.direction.north then
        return {x = position.x, y = position.y - 1}
    elseif direction == defines.direction.northeast then
        return {x = position.x + 1, y = position.y - 1}
    elseif direction == defines.direction.east then
        return {x = position.x + 1, y = position.y}
    elseif direction == defines.direction.southeast then
        return {x = position.x + 1, y = position.y + 1}
    elseif direction == defines.direction.south then
        return {x = position.x, y = position.y + 1}
    elseif direction == defines.direction.southwest then
        return {x = position.x - 1, y = position.y + 1}
    elseif direction == defines.direction.west then
        return {x = position.x - 1, y = position.y}
    elseif direction == defines.direction.northwest then
        return {x = position.x - 1, y = position.y - 1}
    else
        return position
    end
end


function resmon.scan_current_site(player_index)
    local site = global.player_data[player_index].current_site

    local to_scan = math.min(30, #site.next_to_scan)
    for i = 1, to_scan do
        local entity = table.remove(site.next_to_scan, 1)
        local entity_position = entity.position
        local surface = entity.surface

        -- Look in every direction around this entity...
        for _, dir in pairs(defines.direction) do
            -- ...and if there's a resource, add it
            local found = find_resource_at(surface, shift_position(entity_position, dir))
            if found and found.name == site.ore_type then
                resmon.add_single_entity(player_index, found)
            end
        end
    end
end


local function find_center(area)
    local xpos = (area.left + area.right) / 2
    local ypos = (area.top + area.bottom) / 2

    return {x = math.floor(xpos),
            y = math.floor(ypos)}
end


local function format_number(n) -- credit http://richard.warburton.it
    local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end


local si_prefixes = { '', ' k', ' M', ' G' }

local function format_number_si(n)
    for i = 1, #si_prefixes do
        if n < 1000 then
            return string.format('%d%s', n, si_prefixes[i])
        end
        n = math.floor(n / 1000)
    end

    -- 1,234 T resources? I guess we should support it...
    return string.format('%s T', format_number(n))
end


local octant_names = {
    [0] = "E", [1] = "SE", [2] = "S", [3] = "SW",
    [4] = "W", [5] = "NW", [6] = "N", [7] = "NE",
}

local function get_octant_name(vector)
    local radians = math.atan2(vector.y, vector.x)
    local octant = math.floor( 8 * radians / (2*math.pi) + 8.5 ) % 8

    return octant_names[octant]
end


function resmon.finalize_site(player_index)
    local player = game.players[player_index]
    local player_data = global.player_data[player_index]

    local site = player_data.current_site
    site.finalizing = true
    site.finalizing_since = game.tick
    site.initial_amount = site.amount
    site.ore_per_minute = 0
    site.remaining_permille = 1000

    site.center = find_center(site.extents)

    --[[ don't rename a site we've expanded! (if the site name changes it'll create a new site
         instead of replacing the existing one) ]]
    if not site.is_site_expanding then
        site.name = string.format("%s %d", get_octant_name(site.center), util.distance({x=0, y=0}, site.center))
    end

    resmon.count_deposits(site, site.added_at % settings.global["YARM-ticks-between-checks"].value)
end


function resmon.update_chart_tag(site)
    local is_chart_tag_enabled = settings.global["YARM-map-markers"].value

    if not is_chart_tag_enabled then
        if site.chart_tag and site.chart_tag.valid then
            -- chart tags were just disabled, so remove them from the world
            site.chart_tag.destroy()
            site.chart_tag = nil
        end
        return
    end

    if not site.chart_tag or not site.chart_tag.valid then
        if not site.force or not site.force.valid then return end

        local chart_tag = {
            position = site.center,
            text = site.name,
        }
        site.chart_tag = site.force.add_chart_tag(site.surface, chart_tag)
        if not site.chart_tag then return end -- may fail if chunk is not currently charted accd. to @Bilka
    end

    local display_value = format_number_si(site.amount)
    local entity_prototype = game.entity_prototypes[site.ore_type]
    if resmon.is_endless_resource(site.ore_type, entity_prototype) then
        display_value = string.format("%.1f%%", site.remaining_permille / 10)
    end

    site.chart_tag.text = string.format('%s - %s %s', site.name, display_value,
        resmon.get_rich_text_for_products(entity_prototype))
end


function resmon.get_rich_text_for_products(proto)
    if not proto or not proto.mineable_properties or not proto.mineable_properties.products then
        return '' -- only supporting resource entities...
    end

    local result = ''
    for _, product in pairs(proto.mineable_properties.products) do
        result = result..string.format('[%s=%s]', product.type, product.name)
    end

    return result
end


function resmon.submit_site(player_index)
    local player = game.players[player_index]
    local player_data = global.player_data[player_index]
    local force_data = global.force_data[player.force.name]
    local site = player_data.current_site

    force_data.ore_sites[site.name] = site
    resmon.clear_current_site(player_index)
    if (site.is_site_expanding) then
        if(site.has_expanded) then
            -- reset statistics, the site didn't actually just grow a bunch of ore in existing tiles
            site.last_ore_check = nil
            site.last_modified_amount = nil

            local amount_added = site.amount - site.original_amount
            local sign = amount_added < 0 and '' or '+' -- format_number will handle the negative sign for us (if needed)
            player.print{"YARM-site-expanded", site.name, format_number(site.amount), site.ore_name,
                            sign..format_number(amount_added)}
        end
        --[[ NB: deliberately not outputting anything in the case where the player cancelled (or
             timed out) a site expansion without expanding anything (to avoid console spam) ]]

        if site.chart_tag and site.chart_tag.valid then
            site.chart_tag.destroy()
        end
    else
        player.print{"YARM-site-submitted", site.name, format_number(site.amount), site.ore_name}
    end
    resmon.update_chart_tag(site)

    -- clear site expanding state so we can re-expand the same site again (and get sensible numbers!)
    if(site.is_site_expanding) then
        site.is_site_expanding = nil
        site.has_expanded = nil
        site.original_amount = nil
    end
    resmon.update_force_members_ui(player)
end


function resmon.is_endless_resource(ent_name, proto)
    if resmon.endless_resources[ent_name] ~= nil then
        return resmon.endless_resources[ent_name]
    end

    if not proto then return false end

    if proto.infinite_resource then
        resmon.endless_resources[ent_name] = true
    else
        resmon.endless_resources[ent_name] = false
    end

    return resmon.endless_resources[ent_name]
end

function resmon.count_deposits(site, update_cycle)
    if site.iter_fn then
        resmon.tick_deposit_count(site)
        return
    end

    local site_update_cycle = site.added_at % settings.global["YARM-ticks-between-checks"].value
    if site_update_cycle ~= update_cycle then
        return
    end

    site.iter_fn, site.iter_state, site.iter_key = pairs(site.tracker_indices)
    site.update_amount = 0
end

function resmon.tick_deposit_count(site)
    local index = site.iter_key

    for _ = 1, 1000 do
        index = site.iter_fn(site.iter_state, index)
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


function resmon.finish_deposit_count(site)
    site.iter_key = nil
    site.iter_fn = nil
    site.iter_state = nil

    if site.last_ore_check then
        local delta_ore_since_last_update = site.update_amount - site.amount
        if delta_ore_since_last_update > 0 then           -- only store the amount and tick from last update if it actually changed
            site.last_modified_tick = site.last_ore_check --
            site.last_modified_amount = site.amount       --
        end
        if not site.last_modified_amount then             -- make sure those two values have a default
            site.last_modified_amount = site.amount       --
            site.last_modified_tick = site.last_ore_check --
        end
        local delta_ore_since_last_change = site.update_amount - site.last_modified_amount -- use final amount and tick to calculate
        local delta_ticks = game.tick - site.last_modified_tick                            --
        local new_ore_per_minute = math.floor(delta_ore_since_last_change * 3600 / delta_ticks)        -- ease the per minute value over time
        site.ore_per_minute = site.ore_per_minute + (0.1 * (new_ore_per_minute - site.ore_per_minute)) --
    end

    site.amount = site.update_amount
    site.last_ore_check = game.tick

    site.remaining_permille = math.floor(site.amount * 1000 / site.initial_amount)

    if site.ore_per_minute == 0 then
        if site.amount == 0 then
            site.etd_minutes = 0       -- already depleted
        else
            site.etd_minutes = -1      -- will never deplete
        end
    else
        site.etd_minutes = math.floor(site.amount / (-site.ore_per_minute))
    end

    local entity_prototype = game.entity_prototypes[site.ore_type]
    if resmon.is_endless_resource(site.ore_type, entity_prototype) then
        local normal_resource_amount = entity_prototype.normal_resource_amount

        local site_normal = site.entity_count * normal_resource_amount
        local average_yield_permille = site.amount * 1000 / site_normal

        site.remaining_permille = math.floor(site.entity_count * average_yield_permille)
    end
    resmon.update_chart_tag(site)

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

local function site_comparator_default(left, right)
    if left.remaining_permille ~= right.remaining_permille then
        return left.remaining_permille < right.remaining_permille
    elseif left.added_at ~= right.added_at then
        return left.added_at < right.added_at
    else
        return left.name < right.name
    end
end


local function site_comparator_by_ore_type(left, right)
    if left.ore_type ~= right.ore_type then
        return left.ore_type < right.ore_type
    else
        return site_comparator_default(left, right)
    end
end


local function site_comparator_by_ore_count(left, right)
    if left.amount ~= right.amount then
        return left.amount < right.amount
    else
        return site_comparator_default(left, right)
    end
end


local function site_comparator_by_etd(left, right)
    -- infinite time to depletion is indicated when etd_minutes == -1
    -- we want sites with infinite depletion time at the end of the list
    if left.etd_minutes ~= right.etd_minutes then
        if left.etd_minutes >= 0 and right.etd_minutes >= 0 then
            -- these are both real etd estimates so sort normally
            return left.etd_minutes < right.etd_minutes
        else
            -- left and right are not equal AND one of them is -1
            -- (they are not both -1 because then they'd be equal)
            -- and we want -1 to be at the end of the list
            -- so reverse the sort order in this case
            return left.etd_minutes > right.etd_minutes
        end
    else
        return site_comparator_default(left, right)
    end
end


local function site_comparator_by_alpha(left, right)
    return left.name < right.name
end


local function sites_in_order(sites, comparator)
    -- damn in-place table.sort makes us make a copy first...
    local ordered_sites = {}
    for _, site in pairs(sites) do
        table.insert(ordered_sites, site)
    end

    table.sort(ordered_sites, comparator)

    local i = 0
    local n = #ordered_sites
    return function()
        i = i + 1
        if i <= n then return ordered_sites[i] end
    end
end


local function sites_in_player_order(sites, player)
    local order_by = player.mod_settings["YARM-order-by"].value

    local comparator = site_comparator_default
    if order_by == 'ore-type' then
        comparator = site_comparator_by_ore_type
    elseif order_by == 'ore-count' then
        comparator = site_comparator_by_ore_count
    elseif order_by == 'etd' then
        comparator = site_comparator_by_etd
    elseif order_by == 'alphabetical' then
        comparator = site_comparator_by_alpha
    end

    return sites_in_order(sites, comparator)
end

-- NB: filter names should be single words with optional underscores (_)
-- They will be used for naming GUI elements
local FILTER_NONE = "none"
local FILTER_WARNINGS = "warnings"
local FILTER_ALL = "all"

resmon.filters[FILTER_NONE] = function() return false end
resmon.filters[FILTER_ALL] = function() return true end
resmon.filters[FILTER_WARNINGS] = function(site, player)
    local remaining = site.remaining_permille
    local threshold = player.mod_settings["YARM-warn-percent"].value * 10
    return remaining <= threshold
end


function resmon.update_ui(player)
    local player_data = global.player_data[player.index]
    local force_data = global.force_data[player.force.name]

    local frame_flow = mod_gui.get_frame_flow(player)
    local root = frame_flow.YARM_root
    if not root then
        root = frame_flow.add{type="frame",
                              name="YARM_root",
                              direction="horizontal",
                              style="YARM_outer_frame_no_border"}

        local buttons = root.add{type="flow",
                                 name="buttons",
                                 direction="vertical",
                                 style="YARM_buttons_v"}

        buttons.add{type="button", name="YARM_filter_"..FILTER_NONE, style="YARM_filter_none",
            tooltip={"YARM-tooltips.filter-none"}}
        buttons.add{type="button", name="YARM_filter_"..FILTER_WARNINGS, style="YARM_filter_warnings",
            tooltip={"YARM-tooltips.filter-warnings"}}
        buttons.add{type="button", name="YARM_filter_"..FILTER_ALL, style="YARM_filter_all",
            tooltip={"YARM-tooltips.filter-all"}}

        if not player_data.active_filter then player_data.active_filter = FILTER_WARNINGS end
        resmon.update_ui_filter_buttons(player, player_data.active_filter)
    end

    if root.sites and root.sites.valid then
        root.sites.destroy()
    end
    local sites_gui = root.add{type="table", column_count=8, name="sites", style="YARM_site_table"}
    sites_gui.style.horizontal_spacing = 5
    local column_alignments = sites_gui.style.column_alignments
    column_alignments[1] = 'left' -- rename button
    column_alignments[2] = 'left' -- site name
    column_alignments[3] = 'right' -- remaining percent
    column_alignments[4] = 'right' -- site amount
    column_alignments[5] = 'left' -- ore name
    column_alignments[6] = 'right' -- ore per minute
    column_alignments[7] = 'left' -- ETD
    column_alignments[8] = 'left' -- buttons

    local site_filter = resmon.filters[player_data.active_filter] or resmon.filters[FILTER_NONE]
    if force_data and force_data.ore_sites then
        for site in sites_in_player_order(force_data.ore_sites, player) do
            if site_filter(site, player) then
                resmon.print_single_site(site, player, sites_gui, player_data)
            end
        end
    end
end


function resmon.on_click.set_filter(event)
    local new_filter = string.sub(event.element.name, 1 + string.len("YARM_filter_"))
    local player = game.players[event.player_index]
    local player_data = global.player_data[event.player_index]

    player_data.active_filter = new_filter

    resmon.update_ui_filter_buttons(player, new_filter)

    resmon.update_ui(player)
end


function resmon.update_ui_filter_buttons(player, active_filter)
    -- rarely, it might be possible to arrive here before the YARM GUI gets created
    local root = mod_gui.get_frame_flow(player).YARM_root
    -- in that case, leave it for a later update_ui call.
    if not root or not root.valid then return end

    local buttons_container = root.buttons
    for filter_name, _ in pairs(resmon.filters) do
        local is_active_filter = filter_name == active_filter

        local button = buttons_container["YARM_filter_"..filter_name]
        if button and button.valid then
            local style_name = button.style.name
            local is_active_style = style_name:ends_with("_on")

            if is_active_style and not is_active_filter then
                button.style = string.sub(style_name, 1, string.len(style_name) - 3)
            elseif is_active_filter and not is_active_style then
                button.style = style_name .. "_on"
            end
        end
    end
end


function resmon.print_single_site(site, player, sites_gui, player_data)
    -- TODO: This shouldn't be part of printing the site! It cancels the deletion
    -- process after 2 seconds pass.
    if site.deleting_since and site.deleting_since + 120 < game.tick then
        site.deleting_since = nil
    end

    local color = resmon.site_color(site, player)
    local el = nil


    if player_data.renaming_site == site.name then
        sites_gui.add{type="button",
                        name="YARM_rename_site_"..site.name,
                        tooltip={"YARM-tooltips.rename-site-cancel"},
                        style="YARM_rename_site_cancel"}
    else
        sites_gui.add{type="button",
                        name="YARM_rename_site_"..site.name,
                        tooltip={"YARM-tooltips.rename-site-named", site.name},
                        style="YARM_rename_site"}
    end

    el = sites_gui.add{type="label", name="YARM_label_site_"..site.name, caption=site.name}
    el.style.font_color = color

    el = sites_gui.add{type="label", name="YARM_label_percent_"..site.name,
        caption=string.format("%.1f%%", site.remaining_permille / 10)}
    el.style.font_color = color

    local display_amount = format_number(site.amount)
    local entity_prototype = game.entity_prototypes[site.ore_type]
    if resmon.is_endless_resource(site.ore_type, entity_prototype) then
        display_amount = {"YARM-infinite-entity-count", format_number(site.entity_count)}
    end
    el = sites_gui.add{type="label", name="YARM_label_amount_"..site.name,
        caption=display_amount}
    el.style.font_color = color

    el = sites_gui.add{type="label", name="YARM_label_ore_name_"..site.name,
        caption={"", resmon.get_rich_text_for_products(entity_prototype), " ", site.ore_name}}
    el.style.font_color = color

    el = sites_gui.add{type="label", name="YARM_label_ore_per_minute_"..site.name,
        caption={"YARM-ore-per-minute", string.format("%.1f", site.ore_per_minute)}}
    el.style.font_color = color

    el = sites_gui.add{type="label", name="YARM_label_etd_"..site.name,
        caption={"YARM-time-to-deplete", resmon.time_to_deplete(site)}}
    el.style.font_color = color


    local site_buttons = sites_gui.add{type="flow", name="YARM_site_buttons_"..site.name,
        direction="horizontal", style="YARM_buttons_h"}

    site_buttons.add{type="button",
        name="YARM_goto_site_"..site.name,
        tooltip={"YARM-tooltips.goto-site"},
        style="YARM_goto_site"}

    if site.deleting_since then
        site_buttons.add{type="button",
            name="YARM_delete_site_"..site.name,
            tooltip={"YARM-tooltips.delete-site-confirm"},
            style="YARM_delete_site_confirm"}
    else
        site_buttons.add{type="button",
            name="YARM_delete_site_"..site.name,
            tooltip={"YARM-tooltips.delete-site"},
            style="YARM_delete_site"}
    end

    if site.is_site_expanding then
        site_buttons.add{type="button",
            name="YARM_expand_site_"..site.name,
            tooltip={"YARM-tooltips.expand-site-cancel"},
            style="YARM_expand_site_cancel"}
    else
        site_buttons.add{type="button",
            name="YARM_expand_site_"..site.name,
            tooltip={"YARM-tooltips.expand-site"},
            style="YARM_expand_site"}
    end
end


function resmon.time_to_deplete(site)
    local minutes = site.etd_minutes or -1

    if minutes == -1 then return {"YARM-etd-never"} end

    local hours = math.floor(minutes / 60)

    if hours > 0 then
        return {"", {"YARM-etd-hour-fragment", hours}, " ", {"YARM-etd-minute-fragment", minutes % 60}}
    elseif minutes > 0 then
        return {"", {"YARM-etd-minute-fragment", minutes}}
    elseif site.amount == 0 then
        return {"YARM-etd-now"}
    else
        return {"YARM-etd-under-1m"}
    end
end


function resmon.site_color(site, player)
    local warn_permille = 100

    local color = {
        r=math.floor(warn_permille * 255 / site.remaining_permille),
        g=math.floor(site.remaining_permille * 255 / warn_permille),
        b=0
    }
    if color.r > 255 then color.r = 255
    elseif color.r < 2 then color.r = 2 end

    if color.g > 255 then color.g = 255
    elseif color.g < 2 then color.g = 2 end

    return color
end


function resmon.on_click.YARM_rename_confirm(event)
    local player = game.players[event.player_index]
    local player_data = global.player_data[event.player_index]
    local force_data = global.force_data[player.force.name]

    local old_name = player_data.renaming_site
    local new_name = player.gui.center.YARM_site_rename.new_name.text

    if string.len(new_name) > MAX_SITE_NAME_LENGTH then
        player.print{'YARM-err-site-name-too-long', MAX_SITE_NAME_LENGTH}
        return
    end

    local site = force_data.ore_sites[old_name]
    force_data.ore_sites[old_name] = nil
    force_data.ore_sites[new_name] = site
    site.name = new_name

    resmon.update_chart_tag(site)

    player_data.renaming_site = nil
    player.gui.center.YARM_site_rename.destroy()

    resmon.update_force_members_ui(player)
end


function resmon.on_click.YARM_rename_cancel(event)
    local player = game.players[event.player_index]
    local player_data = global.player_data[event.player_index]

    player_data.renaming_site = nil
    player.gui.center.YARM_site_rename.destroy()

    resmon.update_force_members_ui(player)
end


function resmon.on_click.rename_site(event)
    local site_name = string.sub(event.element.name, 1 + string.len("YARM_rename_site_"))

    local player = game.players[event.player_index]
    local player_data = global.player_data[event.player_index]

    if player.gui.center.YARM_site_rename then
        resmon.on_click.YARM_rename_cancel(event)
        return
    end

    player_data.renaming_site = site_name
    local root = player.gui.center.add{type="frame",
                                       name="YARM_site_rename",
                                       caption={"YARM-site-rename-title", site_name},
                                       direction="horizontal"}

    root.add{type="textfield", name="new_name"}.text = site_name
    root.add{type="button", name="YARM_rename_confirm", caption={"YARM-site-rename-confirm"}}
    root.add{type="button", name="YARM_rename_cancel", caption={"YARM-site-rename-cancel"}}

    player.opened = root

    resmon.update_force_members_ui(player)
end


function resmon.on_gui_closed(event)
    if event.gui_type ~= defines.gui_type.custom then return end
    if not event.element or not event.element.valid then return end
    if event.element.name ~= "YARM_site_rename" then return end

    resmon.on_click.YARM_rename_cancel(event)
end


function resmon.on_click.remove_site(event)
    local site_name = string.sub(event.element.name, 1 + string.len("YARM_delete_site_"))

    local player = game.players[event.player_index]
    local force_data = global.force_data[player.force.name]
    local site = force_data.ore_sites[site_name]

    if site.deleting_since then
        force_data.ore_sites[site_name] = nil

        if site.chart_tag and site.chart_tag.valid then
            site.chart_tag.destroy()
        end
    else
        site.deleting_since = event.tick
    end

    resmon.update_force_members_ui(player)
end


function resmon.on_click.goto_site(event)
    local site_name = string.sub(event.element.name, 1 + string.len("YARM_goto_site_"))

    local player = game.players[event.player_index]
    local force_data = global.force_data[player.force.name]
    local site = force_data.ore_sites[site_name]

    player.open_map(site.center)

    resmon.update_force_members_ui(player)
end


-- one button handler for both the expand_site and expand_site_cancel buttons
function resmon.on_click.expand_site(event)
    local site_name = string.sub(event.element.name, 1 + string.len("YARM_expand_site_"))

    local player = game.players[event.player_index]
    local player_data = global.player_data[event.player_index]
    local force_data = global.force_data[player.force.name]
    local site = force_data.ore_sites[site_name]
    local are_we_cancelling_expand = site.is_site_expanding

    --[[ we want to submit the site if we're cancelling the expansion (mostly because submitting the
         site cleans up the expansion-related variables on the site) or if we were adding a new site
         and decide to expand an existing one
    --]]
    if are_we_cancelling_expand or player_data.current_site then
        resmon.submit_site(event.player_index)
    end

    --[[ this is to handle cancelling an expansion (by clicking the red button) - submitting the site is
         all we need to do in this case ]]
    if are_we_cancelling_expand then
        resmon.update_force_members_ui(player)
        return
    end

    resmon.pull_YARM_item_to_cursor_if_possible(event.player_index)
    if player.cursor_stack.valid_for_read and player.cursor_stack.name == "yarm-selector-tool" then
        site.is_site_expanding = true
        player_data.current_site = site

        resmon.update_force_members_ui(player)
        resmon.start_recreate_overlay_existing_site(event.player_index)
    end
end


function resmon.pull_YARM_item_to_cursor_if_possible(player_index)
    local player = game.players[player_index]
    if player.cursor_stack.valid_for_read then -- already have something?
        if player.cursor_stack.name == "yarm-selector-tool" then return end

        player.clean_cursor() -- and it's not a selector tool, so Q it away
    end

    player.cursor_stack.set_stack{name="yarm-selector-tool"}
end


function resmon.on_get_selection_tool(event)
    resmon.pull_YARM_item_to_cursor_if_possible(event.player_index)
end


function resmon.start_recreate_overlay_existing_site(player_index)
    local site = global.player_data[player_index].current_site
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
    local player_data = global.player_data[player_index]
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
    local site = global.player_data[player_index].current_site
    site.is_overlay_being_created = false
    site.finalizing = true
    site.finalizing_since = game.tick

end

function resmon.update_force_members_ui(player)
    for _, p in pairs(player.force.players) do
        resmon.update_ui(p)
    end
end

function resmon.on_gui_click(event)
    if resmon.on_click[event.element.name] then
        resmon.on_click[event.element.name](event)
    elseif string.starts_with(event.element.name, "YARM_filter_") then
        resmon.on_click.set_filter(event)
    elseif string.starts_with(event.element.name, "YARM_delete_site_") then
        resmon.on_click.remove_site(event)
    elseif string.starts_with(event.element.name, "YARM_rename_site_") then
        resmon.on_click.rename_site(event)
    elseif string.starts_with(event.element.name, "YARM_goto_site_") then
        resmon.on_click.goto_site(event)
    elseif string.starts_with(event.element.name, "YARM_expand_site_") then
        resmon.on_click.expand_site(event)
    end
end


function resmon.update_players(event)
    -- At tick 0 on an MP server initial join, on_init may not have run
    if not global.player_data then return end

    for index, player in pairs(game.players) do
        local player_data = global.player_data[index]

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
        end

        if event.tick % player_data.gui_update_ticks == 15 + index then
            resmon.update_ui(player)
        end
    end
end


function resmon.update_forces(event)
    -- At tick 0 on an MP server initial join, on_init may not have run
    if not global.force_data then return end

    local update_cycle = event.tick % settings.global["YARM-ticks-between-checks"].value
    for _, force in pairs(game.forces) do
        local force_data = global.force_data[force.name]

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
    local output = {"", message, " - ", stopwatch}

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

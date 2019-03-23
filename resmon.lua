require "util"
require "libs/array_pair"
require "mod-gui"

-- Sanity: site names aren't allowed to be longer than this, to prevent them
-- kicking the buttons off the right edge of the screen
local MAX_SITE_NAME_LENGTH = 50

resmon = {
    on_click = {},
    endless_resources = {},
    filters = {},
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
    end

    global.force_data[force.name] = force_data
end


local function position_to_string(entity)
    -- scale it up so (hopefully) any floating point component disappears,
    -- then force it to be an integer with %d.  not using util.positiontostr
    -- as it uses %g and keeps the floating point component.
    return string.format("%d,%d", entity.x * 100, entity.y * 100)
end


function resmon.migrate_ore_entities(force_data)
    for name, site in pairs(force_data.ore_sites) do
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
    end
end


function resmon.migrate_ore_sites(force_data)
    for name, site in pairs(force_data.ore_sites) do
        if not site.remaining_permille then
            site.remaining_permille = math.floor(site.amount * 1000 / site.initial_amount)
        end
        if not site.ore_per_minute then site.ore_per_minute = 0 end
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
            entity_table = {},
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

        }

        if resmon.is_endless_resource(entity.name, entity.prototype) then
            player_data.current_site.minimum_resource_amount = entity.prototype.minimum_resource_amount
        end
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
    local entity_pos = entity.position

    -- Don't re-add the same entity multiple times
    local key = position_to_string(entity_pos)
    if site.entity_table[key] then
        return
    end

    if site.finalizing then site.finalizing = false end

    -- Memorize this entity
    site.entity_table[key] = entity_pos
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
    resmon.put_marker_at(entity.surface, entity_pos, player_data)
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


function resmon.submit_site(player_index)
    local player = game.players[player_index]
    local player_data = global.player_data[player_index]
    local force_data = global.force_data[player.force.name]
    local site = player_data.current_site

    force_data.ore_sites[site.name] = site
    resmon.clear_current_site(player_index)
    if (site.is_site_expanding) then
        if(site.has_expanded) then
            local amount_added = site.amount - site.original_amount
            local sign = amount_added < 0 and '' or '+' -- format_number will handle the negative sign for us (if needed)
            player.print{"YARM-site-expanded", site.name, format_number(site.amount), site.ore_name,
                            sign..format_number(amount_added)}
        end
        --[[ NB: deliberately not outputting anything in the case where the player cancelled (or
             timed out) a site expansion without expanding anything (to avoid console spam) ]]
    else
        player.print{"YARM-site-submitted", site.name, format_number(site.amount), site.ore_name}
    end

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

    site.iter_fn, site.iter_state, site.iter_key = pairs(site.entity_table)
    site.update_amount = 0
end


function resmon.tick_deposit_count(site)
    local key, pos
    key = site.iter_key
    for _ = 1, 100 do
        key, pos = site.iter_fn(site.iter_state, key)
        if key == nil then
            resmon.finish_deposit_count(site)
            return
        end
        local ent = site.surface.find_entity(site.ore_type, pos)
        if ent and ent.valid then
            site.update_amount = site.update_amount + ent.amount
        else
            site.entity_table[key] = nil  -- It's permitted to delete from a table being iterated
            site.entity_count = site.entity_count - 1
        end
    end
    site.iter_key = key

end


function resmon.finish_deposit_count(site)
    site.iter_key = nil
    site.iter_fn = nil
    site.iter_state = nil

    if site.last_ore_check then
        local delta_ticks = game.tick - site.last_ore_check
        local delta_ore = site.update_amount - site.amount

        site.ore_per_minute = math.floor(delta_ore * 3600 / delta_ticks)
    end

    site.amount = site.update_amount
    site.last_ore_check = game.tick

    site.remaining_permille = math.floor(site.amount * 1000 / site.initial_amount)

    local entity_prototype = game.entity_prototypes[site.ore_type]
    if resmon.is_endless_resource(site.ore_type, entity_prototype) then
        -- calculate remaining permille as:
        -- how much of the minimum amount does the site have in excess to the site minimum amount?
        local site_minimum = site.entity_count * site.minimum_resource_amount
        site.remaining_permille = math.floor(site.amount * 1000 / site_minimum) - 1000 + (settings.global["YARM-endless-resource-base"].value * 10)
    end

    script.raise_event(on_site_updated, {
      force_name         = site.force.name,
      site_name          = site.name,
      amount             = site.amount,
      ore_per_minute     = site.ore_per_minute,
      remaining_permille = site.remaining_permille,
      ore_type           = site.ore_type,
    })
end

local function site_comparator(left, right)
    if left.remaining_permille ~= right.remaining_permille then
        return left.remaining_permille < right.remaining_permille
    elseif left.added_at ~= right.added_at then
        return left.added_at < right.added_at
    else
        return left.name < right.name
    end
end


local function ascending_by_ratio(sites)
    local ordered_sites = {}
    for _, site in pairs(sites) do
        table.insert(ordered_sites, site)
    end
    table.sort(ordered_sites, site_comparator)

    local i = 0
    local n = #ordered_sites
    return function()
        i = i + 1
        if i <= n then return ordered_sites[i] end
    end
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

    local site_filter = resmon.filters[player_data.active_filter] or resmon.filters[FILTER_NONE]
    if force_data and force_data.ore_sites then
        for site in ascending_by_ratio(force_data.ore_sites) do
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
    local buttons_container = mod_gui.get_frame_flow(player).YARM_root.buttons
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

    el = sites_gui.add{type="label", name="YARM_label_amount_"..site.name,
        caption=format_number(site.amount)}
    el.style.font_color = color

    el = sites_gui.add{type="label", name="YARM_label_ore_name_"..site.name,
        caption=site.ore_name}
    el.style.font_color = color

    el = sites_gui.add{type="label", name="YARM_label_ore_per_minute_"..site.name,
        caption={"YARM-ore-per-minute", site.ore_per_minute}}
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
    if site.ore_per_minute == 0 then return {"YARM-etd-never"} end

    local minutes = math.floor(site.amount / (-site.ore_per_minute))
    local hours = math.floor(minutes / 60)

    if hours > 0 then
        return {"", {"YARM-etd-hour-fragment", hours}, " ", {"YARM-etd-minute-fragment", minutes % 60}}
    elseif minutes > 0 then
        return {"", {"YARM-etd-minute-fragment", minutes}}
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

    player.zoom_to_world(site.center)

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

    for key,pos in pairs(site.entity_table) do
        local ent = site.surface.find_entity(site.ore_type, pos)
        if ent and ent.valid then
            site.entities_to_be_overlaid[key] = pos
            site.entities_to_be_overlaid_count = site.entities_to_be_overlaid_count + 1
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

function resmon.on_tick(event)
    resmon.update_players(event)
    resmon.update_forces(event)
end

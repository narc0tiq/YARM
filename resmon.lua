require "defines"
require "util"
require "libs/array_pair"

resmon = {
    on_click = {},
    endless_resources = {},
}

require "config"


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


function resmon.init_player(player_index)
    local player = game.get_player(player_index)
    resmon.init_force(player.force)

    if not global.player_data then global.player_data = {} end

    local player_data = global.player_data[player_index]
    if not player_data then player_data = {} end

    if player_data.expandoed == nil then player_data.expandoed = false end
    if not player_data.warn_percent then player_data.warn_percent = 10 end
    if not player_data.gui_update_ticks or player_data.gui_update_ticks == 60 then player_data.gui_update_ticks = 300 end

    if not player_data.overlays then player_data.overlays = {} end

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


function resmon.on_built_entity(event)
    if event.created_entity.name ~= 'resource-monitor' then return end

    local player = game.get_player(event.player_index)
    local player_data = global.player_data[event.player_index]
    local pos = event.created_entity.position
    local surface = event.created_entity.surface

    -- Don't actually place the resource monitor entity
    if not player.cursor_stack.valid_for_read then
        player.cursor_stack.set_stack{name="resource-monitor", count=1}
    elseif player.cursor_stack.name == "resource-monitor" then
        player.cursor_stack.count = player.cursor_stack.count + 1
    end
    event.created_entity.destroy()

    local resource = find_resource_at(surface, pos)
    if not resource then
        resmon.clear_current_site(event.player_index)
        return
    end

    local rescat = resource.prototype.resource_category
    if rescat == 'basic-solid' or rescat == 'basic-fluid' then
        resmon.add_resource(event.player_index, resource)
    else
        player.print{"YARM-unknown-resource-category", rescat}
    end
end


function resmon.clear_current_site(player_index)
    local player = game.get_player(player_index)
    local player_data = global.player_data[player_index]

    player_data.current_site = nil

    while #player_data.overlays > 0 do
        table.remove(player_data.overlays).destroy()
    end
end


function resmon.add_resource(player_index, entity)
    local player = game.get_player(player_index)
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
            entity_positions = array_pair.new(),
            initial_amount = 0,
            amount = 0,
            extents = {
                left = entity.position.x,
                right = entity.position.x,
                top = entity.position.y,
                bottom = entity.position.y,
            },
            next_to_scan = {},
        }

        if resmon.is_endless_resource(entity.name, entity.prototype) then
            player_data.current_site.minimum_resource_amount = entity.prototype.minimum_resource_amount
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
    local iter = array_pair.iterator(site.entity_positions)
    while(iter.has_next()) do
        local pos = iter.next()
        if dist_squared(entity_pos, pos) < 0.5 then
            return
        end
    end

    if site.finalizing then site.finalizing = false end

    -- Memorize this entity
    array_pair.insert(site.entity_positions, entity_pos)
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

function dist_squared(pos_a, pos_b)
    local axbx = pos_a.x - pos_b.x
    local ayby = pos_a.y - pos_b.y
    return axbx * axbx + ayby * ayby
end

function resmon.put_marker_at(surface, pos, player_data)
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

    local to_scan = math.min(3, #site.next_to_scan)
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
    local player = game.get_player(player_index)
    local player_data = global.player_data[player_index]

    local site = player_data.current_site
    site.finalizing = true
    site.finalizing_since = game.tick
    site.initial_amount = site.amount
    site.ore_per_minute = 0
    site.remaining_permille = 1000

    site.center = find_center(site.extents)

    site.name = string.format("%s %d", get_octant_name(site.center), util.distance({x=0, y=0}, site.center))

    resmon.count_deposits(site, site.added_at % resmon.ticks_between_checks)
end


function resmon.submit_site(player_index)
    local player = game.get_player(player_index)
    local player_data = global.player_data[player_index]
    local force_data = global.force_data[player.force.name]

    local site = player_data.current_site

    force_data.ore_sites[site.name] = site
    resmon.clear_current_site(player_index)


    player.print{"YARM-site-submitted", site.name, format_number(site.amount), site.ore_name}
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
    local to_be_forgotten = {}
    local new_amount = 0

    local site_update_cycle = site.added_at % resmon.ticks_between_checks
    if site_update_cycle ~= update_cycle then
        return
    end

    local entity_prototype = game.entity_prototypes[site.ore_type]
    local iter = array_pair.iterator(site.entity_positions)
    while(iter.has_next()) do
        local pos = iter.next()
        local ent = site.surface.find_entity(site.ore_type, pos)
        if ent and ent.valid then
            new_amount = new_amount + ent.amount
        else
            iter.remove()
        end
    end

    if site.last_ore_check then
        local delta_ticks = game.tick - site.last_ore_check
        local delta_ore = new_amount - site.amount

        site.ore_per_minute = math.floor(delta_ore * 3600 / delta_ticks)
    end

    site.amount = new_amount
    site.last_ore_check = game.tick

    site.remaining_permille = math.floor(site.amount * 1000 / site.initial_amount)
    if resmon.is_endless_resource(site.ore_type, entity_prototype) then
        -- calculate remaining permille as:
        -- how much of the minimum amount does the site have in excess to the site minimum amount?
        local site_minimum = array_pair.size(site.entity_positions) * site.minimum_resource_amount
        site.remaining_permille = math.floor(site.amount * 1000 / site_minimum) - 1000 + resmon.endless_resource_base
    end
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


function resmon.update_ui(player)
    local player_data = global.player_data[player.index]
    local force_data = global.force_data[player.force.name]

    local root = player.gui.left.YARM_root
    if not root then
        root = player.gui.left.add{type="frame",
                                   name="YARM_root",
                                   direction="horizontal",
                                   style="outer_frame_style"}

        local buttons = root.add{type="flow",
                                 name="buttons",
                                 direction="vertical",
                                 style="YARM_buttons"}

        buttons.add{type="button", name="YARM_expando", style="YARM_expando_short"}
    end

    if root.sites and root.sites.valid then
        root.sites.destroy()
    end
    local sites_gui = root.add{type="table", colspan=7, name="sites", style="YARM_site_table"}

    if force_data and force_data.ore_sites then
        for site in ascending_by_ratio(force_data.ore_sites) do
            if not player_data.expandoed and (site.remaining_permille / 10) > player_data.warn_percent then
                break
            end

            if site.deleting_since and site.deleting_since + 600 < game.tick then
                site.deleting_since = nil
            end

            local color = resmon.site_color(site, player)
            local el = nil

            el = sites_gui.add{type="label", name="YARM_label_site_"..site.name,
                               caption=site.name}
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
                                               direction="horizontal", style="YARM_buttons"}

            if site.deleting_since then
                site_buttons.add{type="button",
                                 name="YARM_delete_site_"..site.name,
                                 style="YARM_delete_site_confirm"}
            elseif player_data.viewing_site == site.name then
                site_buttons.add{type="button",
                                 name="YARM_goto_site_"..site.name,
                                 style="YARM_goto_site_cancel"}
                if player_data.renaming_site == site.name then
                    site_buttons.add{type="button",
                                    name="YARM_rename_site_"..site.name,
                                    style="YARM_rename_site_cancel"}
                else
                    site_buttons.add{type="button",
                                    name="YARM_rename_site_"..site.name,
                                    style="YARM_rename_site"}
                end
            else
                site_buttons.add{type="button",
                                 name="YARM_goto_site_"..site.name,
                                 style="YARM_goto_site"}
                site_buttons.add{type="button",
                                 name="YARM_delete_site_"..site.name,
                                 style="YARM_delete_site"}
            end
        end
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
    local warn_permille = global.player_data[player.index].warn_percent  * 10

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
    local player = game.get_player(event.player_index)
    local player_data = global.player_data[event.player_index]
    local force_data = global.force_data[player.force.name]

    local old_name = player_data.renaming_site
    local new_name = player.gui.center.YARM_site_rename.new_name.text

    local site = force_data.ore_sites[old_name]
    force_data.ore_sites[old_name] = nil
    force_data.ore_sites[new_name] = site
    site.name = new_name

    player_data.viewing_site = new_name
    player_data.renaming_site = nil
    player.gui.center.YARM_site_rename.destroy()

    for _, p in pairs(player.force.players) do
        resmon.update_ui(p)
    end
end


function resmon.on_click.YARM_rename_cancel(event)
    local player = game.get_player(event.player_index)
    local player_data = global.player_data[event.player_index]

    player_data.renaming_site = nil
    player.gui.center.YARM_site_rename.destroy()
end


function resmon.on_click.rename_site(event)
    local site_name = string.sub(event.element.name, 1 + string.len("YARM_rename_site_"))

    local player = game.get_player(event.player_index)
    local player_data = global.player_data[event.player_index]

    if player.gui.center.YARM_site_rename then
        resmon.on_click.YARM_rename_cancel(event)
        return
    end

    player_data.renaming_site = site_name
    local root = player.gui.center.add{type="frame",
                                       name="YARM_site_rename",
                                       caption={"YARM-site-rename-title"},
                                       direction="horizontal"}

    root.add{type="textfield", name="new_name"}.text = site_name
    root.add{type="button", name="YARM_rename_confirm", caption={"YARM-site-rename-confirm"}}
    root.add{type="button", name="YARM_rename_cancel", caption={"YARM-site-rename-cancel"}}

    for _, p in pairs(player.force.players) do
        resmon.update_ui(p)
    end
end


function resmon.on_click.remove_site(event)
    local site_name = string.sub(event.element.name, 1 + string.len("YARM_delete_site_"))

    local player = game.get_player(event.player_index)
    local force_data = global.force_data[player.force.name]
    local site = force_data.ore_sites[site_name]

    if site.deleting_since then
        force_data.ore_sites[site_name] = nil
    else
        site.deleting_since = event.tick
    end

    for _, p in pairs(player.force.players) do
        resmon.update_ui(p)
    end
end


function resmon.on_click.goto_site(event)
    local site_name = string.sub(event.element.name, 1 + string.len("YARM_goto_site_"))

    local player = game.get_player(event.player_index)
    local player_data = global.player_data[event.player_index]
    local force_data = global.force_data[player.force.name]
    local site = force_data.ore_sites[site_name]

    -- Don't bodyswap too often, Factorio hates it when you do that.
    if player_data.last_bodyswap and player_data.last_bodyswap + 10 > event.tick then return end
    player_data.last_bodyswap = event.tick

    if player_data.viewing_site == site_name then
        -- returning to our home body
        if player_data.real_character == nil or not player_data.real_character.valid then
            player.print({"YARM-warn-no-return-possible"})
            return
        end

        player.character = player_data.real_character
        player_data.remote_viewer.destroy()

        player_data.real_character = nil
        player_data.remote_viewer = nil
        player_data.viewing_site = nil
    else
        -- stepping out to a remote viewer: first, be sure you remember your old body
        if not player_data.real_character or not player_data.real_character.valid then
            -- Abort if the "real" character isn't a player!
            -- NB: this might happen if you use something like The Fat Controller or Command Control
            -- and you do NOT want to get stuck not being able to return from those
            if player.character.name ~= "player" then
                player.print({"YARM-warn-not-in-real-body"})
                return
            end

            player_data.real_character = player.character
        end
        player_data.viewing_site = site_name

        -- make us a viewer and put us in it
        local viewer = player.surface.create_entity{name="yarm-remote-viewer", position=site.center, force=player.force}
        player.character = viewer

        -- don't leave an old one behind
        if player_data.remote_viewer then
            player_data.remote_viewer.destroy()
        end
        player_data.remote_viewer = viewer
    end

    for _, p in pairs(player.force.players) do
        resmon.update_ui(p)
    end
end


function resmon.on_gui_click(event)
    if resmon.on_click[event.element.name] then
        resmon.on_click[event.element.name](event)
    elseif string.starts_with(event.element.name, "YARM_delete_site_") then
        resmon.on_click.remove_site(event)
    elseif string.starts_with(event.element.name, "YARM_rename_site_") then
        resmon.on_click.rename_site(event)
    elseif string.starts_with(event.element.name, "YARM_goto_site_") then
        resmon.on_click.goto_site(event)
    end
end


function resmon.on_click.YARM_expando(event)
    local player = game.get_player(event.player_index)
    local player_data = global.player_data[event.player_index]

    player_data.expandoed = not player_data.expandoed

    if player_data.expandoed then
        player.gui.left.YARM_root.buttons.YARM_expando.style = "YARM_expando_long"
    else
        player.gui.left.YARM_root.buttons.YARM_expando.style = "YARM_expando_short"
    end

    resmon.update_ui(player)
end


function resmon.update_players(event)
    for index, player in ipairs(game.players) do
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
            elseif site.finalizing_since + 600 == event.tick then
                resmon.submit_site(index)
            end
        end

        if event.tick % player_data.gui_update_ticks == 15 + index then
            resmon.update_ui(player)
        end
    end
end


function resmon.update_forces(event)
    local update_cycle = event.tick % resmon.ticks_between_checks
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

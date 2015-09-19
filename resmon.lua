require "defines"
require "util"

resmon = {
    on_click = {},
}

require "config"


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

    local settings = player_data.settings
    if not settings then settings = {} end

    if settings.warn_depleted == nil then settings.warn_depleted = true end
    if settings.warn_ten_percent == nil then settings.warn_ten_percent = true end

    if not settings.gui_update_ticks then settings.gui_update_ticks = 60 end
    player_data.settings = settings

    if not player_data.overlays then player_data.overlays = {} end

    global.player_data[player_index] = player_data
end


function resmon.init_force(force)
    if not global.force_data then global.force_data = {} end

    local force_data = global.force_data[force.name]
    if not force_data then force_data = {} end

    if not force_data.ore_sites then force_data.ore_sites = {} end
    if not force_data.oil_sites then force_data.oil_sites = {} end

    global.force_data[force.name] = force_data
end


local function find_resource_at(surface, position)
    local stuff = surface.find_entities_filtered{area={position, position}, type='resource'}
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

    --if player_data.settings.MonitorVisible == 0 then
        --resmon.show_monitor_gui(player)
    --end

    local resource = find_resource_at(surface, pos)
    if not resource then
        resmon.clear_current_site(event.player_index)
        return
    end

    if resource.prototype.resource_category == 'basic-solid' then
        resmon.add_solid(event.player_index, resource)
    elseif resource.prototype.resource_category == 'basic-fluid' then
        resmon.add_fluid(event.player_index, resource)
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


function resmon.add_solid(player_index, entity)
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
            ore_name = game.get_localised_entity_name(entity.name),
            entities = {},
            initial_amount = 0,
            amount = 0,
            extents = {
                left = entity.position.x,
                right = entity.position.x,
                top = entity.position.y,
                bottom = entity.position.y,
            },
            known_positions = {},
            next_to_scan = {},
            scanning = false,
        }
    end

    resmon.add_single_entity(player_index, entity)
    -- note: resmon.on_tick_find_more_solids() will continue the operation from here and
    -- launch the adding GUI when it finishes.
end


function resmon.add_single_entity(player_index, entity)
    local player_data = global.player_data[player_index]
    local site = player_data.current_site

    -- Don't re-add the same entity multiple times
    local where = util.positiontostr(entity.position)
    if site.known_positions[where] then return end

    -- There must be at least one more scanning step (around the entity
    -- we're adding right now).
    site.scanning = true
    if site.finalizing then site.finalizing = false end

    -- Memorize this entity
    site.known_positions[where] = true
    table.insert(site.entities, entity)
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
    local overlay = surface.create_entity{name="rm_overlay",
                                          force=game.forces.neutral,
                                          position=pos}
    overlay.minable = false
    overlay.destructible = false
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

    local scan_this_tick = site.next_to_scan
    site.next_to_scan = {}

    site.scanning = false -- if we add an entity, this will get set back to true

    while #scan_this_tick > 0 do
        local entity = table.remove(scan_this_tick)
        -- Look in every direction around this entity...
        for _, dir in pairs(defines.direction) do
            -- ...and if there's a resource, add it
            local found = find_resource_at(entity.surface, shift_position(entity.position, dir))
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

    site.center = find_center(site.extents)

    site.name = string.format("%s %d", get_octant_name(site.center), util.distance({x=0, y=0}, site.center))
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


function resmon.count_deposits(site, update_cycle)
    local to_be_forgotten = {}
    local new_amount = 0

    local site_update_cycle = site.added_at % resmon.ticks_between_checks
    if site_update_cycle ~= update_cycle then
        return
    end

    for index, ent in pairs(site.entities) do
        if ent.valid then
            new_amount = new_amount + ent.amount
        else
            to_be_forgotten[index] = true
        end
    end

    site.amount = new_amount

    for i = #site.entities, 1, -1 do
        if to_be_forgotten[i] then
            table.remove(site.entities, i)
        end
    end
end


function resmon.update_ui(player)
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
        buttons.add{type="button", name="YARM_settings", style="YARM_settings"}
    end

    if root.sites and root.sites.valid then
        root.sites.destroy()
    end
    local sites_gui = root.add{type="table", colspan=7, name="sites", style="YARM_site_table"}

    if force_data and force_data.ore_sites then
        for index, site in pairs(force_data.ore_sites) do
            sites_gui.add{type="label", name="YARM_label_site_"..tostring(index),
                          caption={"", site.name, "  "}}
            sites_gui.add{type="label", name="YARM_label_amount_"..tostring(index),
                          caption=format_number(site.amount)}
            sites_gui.add{type="label", name="YARM_label_ore_name_"..tostring(index),
                          caption={"", "  ", site.ore_name, "  "}}
            sites_gui.add{type="button", name="YARM_rename_site_"..tostring(index), style="YARM_rename_site"}
            sites_gui.add{type="button", name="YARM_overlay_site_"..tostring(index), style="YARM_overlay_site"}
            sites_gui.add{type="button", name="YARM_goto_site_"..tostring(index), style="YARM_goto_site"}
            sites_gui.add{type="button", name="YARM_delete_site_"..tostring(index), style="YARM_delete_site"}
        end
    end
end


function resmon.on_click.remove_site(event)
    local site_name = string.sub(event.element.name, 1 + string.len("YARM_delete_site_"))

    local player = game.get_player(event.player_index)
    global.force_data[player.force.name].ore_sites[site_name] = nil

    for _, p in pairs(player.force.players) do
        resmon.update_ui(p)
    end
end


function string.starts_with(haystack, needle)
    return string.sub(haystack, 1, string.len(needle)) == needle
end


function string.ends_with(haystack, needle)
    return string.sub(haystack, -string.len(needle)) == needle
end


function resmon.on_gui_click(event)
    if resmon.on_click[event.element.name] then
        resmon.on_click[event.element.name](event)
    elseif string.starts_with(event.element.name, "YARM_delete_site_") then
        resmon.on_click.remove_site(event)
    end
end


function resmon.on_click.YARM_expando(event)
    local player = game.get_player(event.player_index)

    player.gui.left.YARM_root.buttons.YARM_expando.style = "YARM_expando_long"
end


function resmon.update_players(event)
    for index, player in ipairs(game.players) do
        local player_data = global.player_data[index]
        if not player.connected and player_data.current_site then
            resmon.clear_current_site(index)
        end

        if player_data.current_site then
            local site = player_data.current_site

            if site.scanning then
                resmon.scan_current_site(index)
            elseif not site.finalizing then
                resmon.finalize_site(index)
            elseif site.finalizing_since + 600 == event.tick then
                resmon.submit_site(index)
            end
        end

        if event.tick % player_data.settings.gui_update_ticks == 15 + index then
            resmon.update_ui(player)
        end
    end
end


function resmon.update_forces(event)
    local update_cycle = event.tick % resmon.ticks_between_checks
    for _, force in pairs(game.forces) do
        local force_data = global.force_data[force.name]
        if force_data and force_data.ore_sites then
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

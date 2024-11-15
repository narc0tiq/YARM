require "resmon"
local mod_gui = require("mod-gui")

local interface = {}

function interface.how_many_entities_tracked(player_name_or_index)
    local player = game.players[player_name_or_index]
    player.print({ "", "Tracking ", #storage.ore_tracker.entities, " entities" })
end

function interface.reset_ui(player_name_or_index)
    local player = game.players[player_name_or_index]
    local frame_flow = mod_gui.get_frame_flow(player)
    local root = frame_flow.YARM_root
    if root and root.valid then root.destroy() end
end

function interface.reset_player(player_name_or_index)
    local player = game.players[player_name_or_index]
    local player_data = storage.player_data[player.index]

    player.character = player.selected
    player_data.viewing_site = nil
    player_data.real_character = nil
    player_data.remote_viewer = nil
end

function interface.get_current_filter(player_name_or_index)
    local player = game.players[player_name_or_index]
    local player_data = storage.player_data[player.index]

    return player_data.active_filter or 'none'
end

function interface.set_filter(player_name_or_index, new_filter)
    local player = game.players[player_name_or_index]
    local player_data = storage.player_data[player.index]
    local old_filter = player_data.active_filter

    if not resmon.sites.filters[new_filter] then
        log(string.format("Warning: YARM does not have a filter named '%s'", new_filter))
        return old_filter
    end

    player_data.active_filter = new_filter
    resmon.ui.update_filter_buttons(player)
    resmon.ui.update_player(player)

    return old_filter
end

function interface.hide_expando(player_name_or_index)
    log("hide_expando is no longer supported. Try set_filter(player_name_or_index, 'none' or 'warnings' or 'all')")
    return false
end

function interface.show_expando(player_name_or_index)
    log("show_expando is no longer supported. Try set_filter(player_name_or_index, 'none' or 'warnings' or 'all')")
    return false
end

function interface.get_on_site_updated_event_id()
    return on_site_updated
end

function interface.get_global_data()
    return storage
end

remote.add_interface("YARM", interface)

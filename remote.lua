require "resmon"

local interface = {}

function interface.reset_player(player_name_or_index)
    local player = game.get_player(player_name_or_index)
    local player_data = global.player_data[player.index]

    player.character = player.selected
    player_data.viewing_site = nil
    player_data.real_character = nil
    player_data.remote_viewer = nil
end

function interface.hide_expando(player_name_or_index)
    local player = game.get_player(player_name_or_index)
    if global.player_data[player.index].expandoed then
        resmon.on_click.YARM_expando({player_index=player.index})
        return true
    end
    
    return false
end

function interface.show_expando(player_name_or_index)
    local player = game.get_player(player_name_or_index)
    if not global.player_data[player.index].expandoed then
        resmon.on_click.YARM_expando({player_index=player.index})
        return false
    end
    
    return true
end

remote.add_interface("YARM", interface)

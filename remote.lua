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


remote.add_interface("YARM", interface)

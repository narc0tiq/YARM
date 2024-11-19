require "resmon"
local mod_gui = require("mod-gui")

local interface = {}

---Allow the remote to query how many entities the ore tracker knows. Prints the results
---to the given player's message log.
---@param player_name_or_index string|number
function interface.how_many_entities_tracked(player_name_or_index)
    local player = game.players[player_name_or_index]
    player.print({ "", "Tracking ", #storage.ore_tracker.entities, " entities" })
end

---Allow the remote to reset the given player's UI by destroying the HUD root. This usually
---results in the HUD being recreated correctly. Mostly useful in UI development to clean up
---experiments.
---@param player_name_or_index string|number
function interface.reset_ui(player_name_or_index)
    local player = game.players[player_name_or_index]
    local frame_flow = mod_gui.get_frame_flow(player)
    local root = frame_flow.YARM_root
    if root and root.valid then root.destroy() end
end

---Allows the remote to learn which filter the given player is using right now. A mod could
---have special handling to change its UI based on YARM being in 'all' versus 'none' mode.
---@param player_name_or_index string|number
---@return string # The name of the filter (@see sites_module.filters)
function interface.get_current_filter(player_name_or_index)
    local player = game.players[player_name_or_index]
    local player_data = storage.player_data[player.index]

    return player_data.ui.active_filter or 'none'
end

---Allows the remote to change the given player's filter. A mod could set a player's YARM
---to "none" mode temporarily to give itself more space to display a temporary UI in YARM's
---space.
---@param player_name_or_index string|number
---@param new_filter string Name of the new filter
---@return string old_filter Name of the old filter
function interface.set_filter(player_name_or_index, new_filter)
    local player = game.players[player_name_or_index]
    local player_data = storage.player_data[player.index]
    local old_filter = player_data.ui.active_filter

    if not resmon.sites.filters[new_filter] then
        log(string.format("Warning: YARM does not have a filter named '%s'", new_filter))
        return old_filter
    end

    player_data.ui.active_filter = new_filter
    resmon.ui.update_filter_buttons(player)
    resmon.ui.update_player(player)

    return old_filter
end

---Allow a remote to find out the event ID for `on_site_updated`, which is raised on every site
---recount to update consumers about the site contents.
function interface.get_on_site_updated_event_id()
    return on_site_updated
end

---Allow a remote to read all of YARM's `storage`, mostly for debugging purposes.
function interface.get_global_data()
    return storage
end

remote.add_interface("YARM", interface)

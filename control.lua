require 'resmon'
require 'remote'
require 'yarm.all'
require 'libs/yutil'

script.on_init(yarm.on_init)
script.on_load(yarm.on_load)
script.on_configuration_changed(yarm.on_configuration_changed)

yarm.event.bind_events()

-- if this ever happens, I'll be enormously surprised
if not resmon then error("YARM has become badly corrupted: the variable resmon should've been set!") end


local function on_gui_opened(e)
    log("on_gui_opened" .. serpent.block(e))
    if e.entity and e.entity.name == 'yarm-monitor-basic' then
        local player = game.get_player(e.player_index)
        player.opened = nil
        log('gotcha!')
    end
end
script.on_event(defines.events.on_gui_opened, on_gui_opened)

local function on_yarm_command(e)
    if e.parameter == 'reinit' then
        yarm.on_init()
    end
end

commands.add_command('yarm', {'command.yarm-help'}, on_yarm_command)

-- script.on_init(resmon.init_globals)
-- script.on_configuration_changed(resmon.init_globals)

-- script.on_load(resmon.on_load)

-- script.on_event(defines.events.on_player_created, resmon.on_player_created)
-- script.on_event(defines.events.on_tick, resmon.on_tick)
-- script.on_event(defines.events.on_gui_click, resmon.on_gui_click)
-- script.on_event(defines.events.on_gui_closed, resmon.on_gui_closed)
script.on_event("get-yarm-selector", resmon.on_get_selection_tool)
-- script.on_event(defines.events.on_player_selected_area, resmon.on_player_selected_area)

on_site_updated = script.generate_event_name()


require "resmon"
require "remote"


-- if this ever happens, I'll be enormously surprised
if not resmon then error("{{MOD_NAME}} has become badly corrupted: the variable resmon should've been set!") end

script.on_init(resmon.init_globals)
script.on_configuration_changed(resmon.init_globals)

script.on_load(resmon.on_load)

script.on_event(defines.events.on_player_created, resmon.on_player_created)
script.on_event(defines.events.on_tick, resmon.on_tick)
script.on_event(defines.events.on_gui_click, resmon.on_gui_click)
script.on_event(defines.events.on_gui_closed, resmon.on_gui_closed)
script.on_event("get-yarm-selector", resmon.on_get_selection_tool)
script.on_event(defines.events.on_player_selected_area, resmon.on_player_selected_area)

on_site_updated = script.generate_event_name()

require "defines"
require "resmon"
require "remote"


-- if this ever happens, I'll be enormously surprised
if not resmon then error("{{MOD_NAME}} has become badly corrupted: the variable resmon should've been set!") end


function msg_all(message)
    for _,p in pairs(game.players) do
        p.print(message)
    end
end


script.on_init(function()
    local _, err = pcall(resmon.init_globals)
    if err then msg_all({"YARM-err-generic", err}) end
end)


script.on_configuration_changed(function()
    local _, err = pcall(resmon.init_globals)
    if err then msg_all({"YARM-err-generic", err}) end
end)


script.on_event(defines.events.on_player_created, function(event)
    local _, err = pcall(resmon.on_player_created, event)
    if err then msg_all({"YARM-err-specific", "on_player_created", err}) end
end)


script.on_event(defines.events.on_built_entity, function(event)
    local _, err = pcall(resmon.on_built_entity, event)
    if err then msg_all({"YARM-err-specific", "on_built_entity", err}) end
end)


script.on_event(defines.events.on_tick, function(event)
    local _, err = pcall(resmon.on_tick, event)
    if err then msg_all({"YARM-err-specific", "on_tick", err}) end
end)


script.on_event(defines.events.on_gui_click, function(event)
    local _, err = pcall(resmon.on_gui_click, event)
    if err then msg_all({"YARM-err-specific", "on_gui_click", err}) end
end)

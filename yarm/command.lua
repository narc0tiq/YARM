require 'util'
require 'libs/yutil'

if yarm == nil then yarm = {} end

local P = {
    commands = {}
}
yarm.command = P

function P.on_yarm(e)
    e.argv = yutil.split_ws(e.parameter or '')
    local command = string.lower(e.argv[1])
    if P.commands[command] then
        P.commands[command](e)
    else
        P.respond(e, '[YARM][Err] Unknown command "/yarm '..command..'"!')
    end
end

function P.respond(e, msg)
    if e.player_index then
        local player = game.get_player(e.player_index)
        player.print(msg)
    end
    log(msg)
end

function P.commands.reinit()
    yarm.on_init()
end

function P.commands.show(e)
    local show_what = string.lower(e.argv[2] or '')
    if show_what == 'monitors' then
        P.commands.show_monitors(e)
    elseif show_what == 'sites' then
        P.commands.show_sites(e)
    else
        P.respond(e, '[YARM][Err] Don\'t know how to show "'..show_what..'"!')
    end
end

function P.commands.show_monitors(e)
    local result = {}
    for i, mondata in pairs(yarm.monitor.monitors) do
        local monitor_line = {i, ': at '}
        table.insert(monitor_line, util.positiontostr(mondata.position))
        table.insert(monitor_line, ', in site "')
        table.insert(monitor_line, mondata.site_name)
        table.insert(monitor_line, '", sees:\r\n')
        for name, prod in pairs(mondata.product_types) do
            table.insert(monitor_line, '\t- ')
            table.insert(monitor_line, name)
            table.insert(monitor_line, ': ')
            table.insert(monitor_line, util.format_number(prod.amount))
            table.insert(monitor_line, '/')
            table.insert(monitor_line, util.format_number(prod.initial_amount))
            table.insert(monitor_line, string.format(' (%.2f%%)', prod.amount * 100 / prod.initial_amount))
            table.insert(monitor_line, string.format(' delta %s', util.format_number(prod.delta_per_minute)))
            table.insert(monitor_line, ' ETD ')
            table.insert(monitor_line, tostring(prod.minutes_to_deplete))
            table.insert(monitor_line, ' minutes\r\n')
        end
        table.insert(result, table.concat(monitor_line))
    end
    P.respond(e, table.concat(result))
end

function P.commands.show_sites(e)
    P.respond(e, 'Not yet implemented, sorry')
end

commands.add_command('yarm', {'command.yarm-help'}, P.on_yarm)
return P
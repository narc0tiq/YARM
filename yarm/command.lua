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

local LINES_PER_PAGE = 10

function P.respond_paginated(e, lines)
    if not e.player_index then
        log(table.concat(lines, "\r\n"))
        return
    end

    local page_num = tonumber(e.argv[#e.argv])
    if page_num == nil then
        page_num = 1
        table.insert(e.argv, "1")
    end
    page_num = math.floor(page_num)
    local page_count = math.max(1, math.ceil(#lines / LINES_PER_PAGE))
    local command = table.concat(e.argv, ' ', 1, #e.argv - 1)
    local warning = nil
    if page_num < 1 or page_num > page_count then
        warning = string.format("WARNING: Invalid page %s requested! There are %d pages.", page_num, page_count)
        page_num = 1
    end
    

    local first_line = (page_num - 1) * LINES_PER_PAGE + 1
    local last_line = math.min(first_line + LINES_PER_PAGE, #lines)

    local output = {
        table.concat(lines, "\r\n", first_line, last_line),
        string.format('Page %d of %d. Use "/yarm %s N" to view page N.', page_num, page_count, command),
        warning
    }
    P.respond(e, table.concat(output, "\r\n"))
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
    if #yarm.monitor.monitors == 0 then
        P.respond(e, 'There are no monitors yet! Try placing one!')
        return
    end

    local lines = {}
    for i, mondata in pairs(yarm.monitor.monitors) do
        local monitor_line = {i, ': at '}
        table.insert(monitor_line, util.positiontostr(mondata.position))
        table.insert(monitor_line, ', in site "')
        table.insert(monitor_line, mondata.site_name)
        table.insert(monitor_line, '", sees:')
        table.insert(lines, table.concat(monitor_line))
        for name, prod in pairs(mondata.product_types) do
            local product_line = { ' - ', name, ': '}
            table.insert(product_line, util.format_number(prod.amount))
            table.insert(product_line, '/')
            table.insert(product_line, util.format_number(prod.initial_amount))
            table.insert(product_line, string.format(' (%.2f%%)', prod.amount * 100 / prod.initial_amount))
            table.insert(product_line, string.format(' delta %s', util.format_number(prod.delta_per_minute)))
            table.insert(product_line, ' ETD ')
            table.insert(product_line, tostring(prod.minutes_to_deplete))
            table.insert(product_line, ' minutes')
            table.insert(lines, table.concat(product_line))
        end
    end
    P.respond_paginated(e, lines)
end

function P.commands.show_sites(e)
    if table_size(yarm.site.sites) == 0 then
        P.respond(e, 'There are no sites yet! Try placing a monitor.')
        return
    end
    P.respond(e, 'Not yet implemented, sorry')
end

function P.commands.give(e)
    local player = nil
    if e.argv[2] then
        player = game.get_player(e.argv[2])
    end
    if not player then
        if not e.player_index then
            P.respond(e, '[YARM][Err] Must specify a target player (either by name or game.players index)!')
        end
        player = game.get_player(e.player_index)
    end

    player.insert{name = yarm.entity.BASIC_MONITOR_NAME, count = 20}
    player.insert{name = yarm.entity.WIRELESS_MONITOR_NAME, count = 20}
    P.respond(e, 'Gave '..player.name..' 20 of each monitor')
end

commands.add_command('yarm', {'command.yarm-help'}, P.on_yarm)
return P
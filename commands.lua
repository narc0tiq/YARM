local cmds = {}


local function split_args(arg_str)
    local parsed = {}
    for s in string.gmatch(arg_str, '%S+') do
        parsed[#parsed + 1] = s
    end
    return parsed
end

--[[
--
-- Apply a transforming function `func` onto every entry in the table `target`.
--   `func` must match `function(key, value)` and may return a new value
--
-- Returns a table with the same keys as `target` where the values are the returns
-- from calling `func(k,v)` on each entry in `target`.
--
--]]
local function mapk(func, target)
    local result = {}
    for key, value in pairs(target) do
        result[key] = func(key, value)
    end
    return result
end

function cmds.help(player, args)
    player.print{"YARM-command.help-details"}
end

function cmds.list(player)
    local force_data = global.force_data[player.force.name]
    if not force_data then return end -- nothing to list

    local function describe_site(name, site)
        return {"YARM-command.list-site-description", name, site.entity_count, site.amount, site.ore_name}
    end

    local site_descriptions = mapk(describe_site, force_data.ore_sites)
    log(serpent.block(site_descriptions))
    player.print{"", unpack(site_descriptions)}
end

commands.add_command("yarm", {"YARM-command.help"}, function(e)
    local player = game.get_player(e.player_index)
    if not e.parameter then
        player.print{"YARM-command-err.need-command"}
        return
    end

    local argv = split_args(e.parameter)

    if cmds[argv[1]] then
        cmds[argv[1]](player, argv)
        log(serpent.block(e))
    else
        player.print{"YARM-command-err.no-such-command", argv[1]}
    end
end)

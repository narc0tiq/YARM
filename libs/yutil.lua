local P = {}
yutil = P

--- Linearly interpolate between two values.
-- Calculates the "current" value between `left` and `right` given a `pos` that
-- represents the current position (e.g., 0.25) between them.
-- @param left The leftmost (0.0) value of the interpolation.
-- @param right The rightmost (1.0) value of the interpolation.
-- @param pos The current position within the interpolation. Nominally
--      expected to be 0..1, but can calculate proportionally outside
--      that range.
function P.lerp(left, right, pos)
    local delta = right - left
    local offset = pos * delta
    return left + offset
end

--- Linearly interpolate between two colors.
-- Calculates the "current" color between `left` and `right` given a `pos` that
-- represents the current position (e.g., 0.25) between them. Each channel
-- (rgba) is lerped independently, there is no colorspace cleverness here.
function P.lerp_color(left, right, pos)
    return {
        r = P.lerp(left.r, right.r, pos),
        g = P.lerp(left.g, right.g, pos),
        b = P.lerp(left.b, right.b, pos),
        a = P.lerp(left.a, right.a, pos),
    }
end

--- Linearly ease a new value onto an old one.
-- Calculates an intermediary value between `old` and `new` at `ratio`, unless
-- the values are less than `jump_delta` apart. In the latter case, immediately
-- returns `new`.
-- @param old The value that we are easing _from_.
-- @param new The value that we are easing _to_.
-- @param ratio (0..1) The current position along the easing function.
-- @param jump_delta The maximum range between `old` and `new` whereby the method
--      will just return `new` immediately.
function P.linear_ease(old, new, ratio, jump_delta)
    jump_delta = jump_delta or 5
    if math.abs(new - old) <= jump_delta then
        return new
    end
    return P.lerp(old, new, ratio)
end

--- Merge two tables, creating a third table with keys from both.
-- Values from the `right` table will override those from the `left`.
-- Neither table is modified (a new table is created with `table.deepcopy`)
function P.table_merge(left, right)
    local result = table.deepcopy(left or {})
    if type(right) ~= 'table' then
        return result -- nothing given, nothing changed
    end

    for k, v in pairs(right) do
        result[k] = v
    end
    return result
end

--- Iterator that filters the given `tab`le according to a `predicate`
-- @param tab The table being filtered.
-- @param predicate A method that will be given each value in `tab`, expected
--     to return something truthy when the value should be present in the result.
function P.where(tab, predicate)
    local k, v = nil
    return function ()
        repeat
            k, v = next(tab, k)
            if k ~= nil and predicate(v) then
                return k, v
            end
        until k == nil
    end
end

--- Iterator that transforms the given `tab`le according to a `transform`ation
function P.select(table, transform)
    local k, v = nil
    return function ()
        repeat
            k, v = next(table, k)
            if k ~= nil then
                return k, transform(v)
            end
        until k == nil
    end
end

--- Materialize an iterator into a real table, Pinnochio
-- NB: No checks are given for cases where `iterator` is infinite.
-- Handle with care.
function P.materialize(iterator)
    local tab = {}
    for k, v in iterator do
        tab[k] = v
    end
    return tab
end

--- Looks for a specific `element` inside a `tab`le
function P.contains(table, element)
    for _, v in pairs(table) do
        if v == element then
            return true
        end
    end
    return false
end

function P.locale_group_from_signal_type(sigtype)
    if sigtype == 'item' then
        return 'item-name'
    elseif sigtype == 'fluid' then
        return 'fluid-name'
    elseif sigtype == 'virtual' then
        return 'virtual-signal-name'
    else
        error("Cannot tell locale group from signal type '"..sigtype.."'!")
    end
end

--- Scan into a deep table across a variable depth, initializing the sub-tables if necessary
-- Useful for things like P.site_index[force_name][surface_name][site_name]
-- @param table is the table that will have its sub-tables scanned or initialized
-- @param properties is an array of the sub-tables that must exist within the table (e.g., { force_name, surface_name, site_name })
-- @return the leaf that was either created or found
function P.table_scan(table, properties)
    if type(table) ~= 'table' then error("Can't table-scan a non-table!") end

    -- NB: Here is one of those rare cases where we really care about _only_
    -- iterating the numeric keys and _only_ in order (though Factorio would
    -- guarantee the latter even for pairs()). Thus, ipairs() to the rescue!

    local current = table
    for _, prop in ipairs(properties) do
        if current[prop] == nil then
            current[prop] = {}
        end
        current = current[prop]
    end
    return current
end

--- Find the first index within `table` that matches `predicate`
function P.index_of(table, predicate)
    for i, val in pairs(table) do
        if predicate(val) then
            return i
        end
    end
    return -1
end

--- Generate a random backer name; optionally try to ensure the random name is
-- not present as a key in a given table.
-- NB: If a table is not given, will return the first pick immediately
-- NB: If not found in 5 picks, will return a crappy key based on table_size(unless_in)
function P.random_backer_name(unless_in)
    for i = 1, 5 do
        local index = math.random(#game.backer_names)
        local candidate = game.backer_names[index]
        if type(unless_in) ~= 'table' then
            return candidate
        end
        if unless_in[candidate] == nil then
            return candidate
        end
    end
    -- Crappy name is better than no name, I guess...
    return string.format('%04d', table_size(unless_in))
    -- TODO Consider a uniqueness check on this, as well.
end

--- Split a string by whitespace
function P.split_ws(str)
    result = {}
    for match in (str..' '):gmatch("(.-)%s+") do
        table.insert(result, match)
    end
    return result
end

return P
array_pair = {}
array_pair.__index = array_pair

function array_pair.new()
    return {table_a = {}, table_b = {}}
end

function array_pair.reset(list)
    list.table_a = {}
    list.table_b = {}
end

function array_pair.insert(list, tuple)
    table.insert(list.table_a, tuple.x)
    table.insert(list.table_b, tuple.y)
end

function array_pair.remove(list)
    if #list.table_a > 0 then
        local a = table.remove(list.table_a)
        local b = table.remove(list.table_b)
        return {x = a, y = b}
    end
    return nil
end

function array_pair.size(list)
    return #list.table_a
end

function array_pair.iterator(list)
    local iterator = {list = list, current_index = #list.table_a}
    function iterator.next()
        if iterator.has_next() then
            local idx = iterator.current_index
            iterator.current_index = iterator.current_index - 1
            return {x = iterator.list.table_a[idx], y = iterator.list.table_b[idx]}
        end
        return nil
    end

    function iterator.remove()
        local idx = iterator.current_index + 1
        return {x = table.remove(iterator.list.table_a, idx), y = table.remove(iterator.list.table_b, idx)}
    end

    function iterator.has_next()
        return iterator.current_index >= 1
    end
    return iterator
end

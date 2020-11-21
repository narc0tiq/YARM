if yarm == nil then yarm = {} end

local P = {}
yarm.event = P

P.handlers = {
    --[[
        [event.name] = {
            actions = { some_func, some_other_func },
            filters = { some_filters, some_other_filters },
            unfiltered: boolean -- whether any of the bound actions wants to run with no filter
        }
    ]]
}

local function compose_filters(filters)
    local ret = {}
    for _, filterset in pairs(filters) do
        for __, filter in pairs(filterset) do
            table.insert(ret, filter)
        end
    end
    return ret
end

local function compose_handlers(handlers)
    return function (e)
        for _, handler in pairs(handlers) do
            handler(e)
        end
    end
end

function P.on_event(event, action, filters)
    local hs = P.handlers
    if P.handlers[event] == nil then
        P.handlers[event] = {
            actions = { action },
            filters = { filters },
            unfiltered = filters == nil
        }
        return
    end

    local handler = hs[event]
    table.insert(handler.actions, action)
    table.insert(handler.filters, filters)
    handler.unfiltered = handler.unfiltered or filters == nil
end

function P.bind_events()
    for evname, details in pairs(P.handlers) do
        if details.unfiltered then
            -- at least one filterless handler, all must be unfiltered
            script.on_event(evname, compose_handlers(details.actions))
        else
            -- all handlers filtered, actual filter will be a composite
            script.on_event(evname, compose_handlers(details.actions), compose_filters(details.filters))
        end
    end
end

function P.delegate_to_modules(handler_name)
    return function (...)
        for _, module in yarm.model.iterate_modules() do
            if module[handler_name] then
                module[handler_name](table.unpack(arg or {}))
            end
        end
    end
end

yarm.on_init = P.delegate_to_modules('on_init')
yarm.on_load = P.delegate_to_modules('on_load')
yarm.on_configuration_changed = P.delegate_to_modules('on_configuration_changed')

yarm.on_event = P.on_event

return P
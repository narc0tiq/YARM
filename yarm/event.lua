if yarm == nil then yarm = {} end

local P = {}
yarm.event = P

P.handlers = {
    --[[
        [unused_index] = {
            event = event.name,
            action = function(e) blah end,
            filters = {} or nil
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
    table.insert(P.handlers, { event = event, action = action, filters = filters })
end

function P.bind_events()
    local composite = {}

    for _, evdata in pairs(P.handlers) do
        if composite[evdata.event] == nil then
            composite[evdata.event] = { actions = {}, filters = {}, unfiltered = false }
        end
        local evcomposite = composite[evdata.event]

        table.insert(evcomposite.actions, evdata.action)
        if evdata.filters ~= nil then
            table.insert(evcomposite.filters, evdata.filters)
        else
            evcomposite.unfiltered = true
        end
    end

    for evname, details in pairs(composite) do
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
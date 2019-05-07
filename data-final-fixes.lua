
local ore_items = {}

for name, proto in pairs(data.raw.resource) do
    ore_items[#ore_items + 1] = {
        type = 'item',
        stack_size = 1,
        flags = { 'hidden' },

        name = 'YARM-fake-' .. proto.name,
        icon = proto.icon or nil,
        icons = proto.icons or nil,
        icon_size = proto.icon_size or nil,

        place_result = proto.name,
    }
end

data:extend(ore_items)

--[[

This file is for legacy prototypes: we keep them becausethey're necessary to
allow migrating from old versions up to the current one.

]]


-- BEGIN: 0.8.0 removed remote viewing; remote viewers need to keep existing
-- to prevent uncontrolled reset of player data.

data:extend(
{
    {
        type = "resource-category",
        name = "empty-resource-category",
    },
    {
        type = "recipe-category",
        name = "empty-recipe-category",
    },
})

local empty_animation = {
    filename = "__{{MOD_NAME}}__/graphics/nil.png",
    priority = "medium",
    width = 1,
    height = 1,
    direction_count = 18,
    frame_count = 1,
    animation_speed = 1,
    shift = {0,0},
    axially_symmetrical = false,
}

local empty_anim_level = {
    idle = empty_animation,
    idle_mask = empty_animation,
    idle_with_gun = empty_animation,
    idle_with_gun_mask = empty_animation,
    mining_with_hands = empty_animation,
    mining_with_hands_mask = empty_animation,
    mining_with_tool = empty_animation,
    mining_with_tool_mask = empty_animation,
    running_with_gun = empty_animation,
    running_with_gun_mask = empty_animation,
    running = empty_animation,
    running_mask = empty_animation,
}

local fake_player = table.deepcopy(data.raw.character.character)
fake_player.name = "yarm-remote-viewer"
fake_player.crafting_categories = {"empty-recipe-category"}
fake_player.mining_categories = {"empty-resource-category"}
fake_player.max_health = 100
fake_player.inventory_size = 0
fake_player.build_distance = 0
fake_player.drop_item_distance = 0
fake_player.reach_distance = 0
fake_player.reach_resource_distance = 0
fake_player.mining_speed = 0
fake_player.running_speed = 0
fake_player.distance_per_frame = 0
fake_player.animations = {
    level1 = empty_anim_level,
    level2addon = empty_anim_level,
    level3addon = empty_anim_level,
}
fake_player.light = {{ intensity=0, size=0 }}
fake_player.flags = {"placeable-off-grid", "not-on-map", "not-repairable"}
fake_player.collision_mask = {"ground-tile"}

data:extend({ fake_player })

-- END: 0.8.0 removed remote viewing

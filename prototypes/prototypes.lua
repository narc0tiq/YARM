data:extend(
{
	{
		type = "item",
		name = "resource-monitor",
		icon = "__Resource-Monitor-Mod__/graphics/resource-monitor.png",
		flags = {"goes-to-quickbar"},
		damage_radius = 5,
		subgroup = "tool",
		order = "b[resource-monitor]",
		place_result = "resource-monitor",
		stack_size = 1
	},

	{
		type = "container",
		name = "resource-monitor",
		icon = "__Resource-Monitor-Mod__/graphics/resource-monitor.png",
		flags = {"placeable-neutral", "player-creation"},
		minable = {mining_time = 1, result = "resource-monitor"},
		max_health = 100,
		corpse = "small-remnants",
		resistances ={{type = "fire",percent = 80}},
		collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
		selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
		fast_replaceable_group = "container",
		inventory_size = 1,
		picture =
		{
			filename = "__Resource-Monitor-Mod__/graphics/resource-monitor.png",
			priority = "extra-high",
			width = 32,
			height = 32,
			shift = {0.0, 0.0}
		}
	},

	{
		type = "recipe",
		name = "resource-monitor",
		ingredients = {{"electronic-circuit",10},{"copper-cable",20}},
		result = "resource-monitor",
		result_count = 1,
		enabled = "false"
	},

	{
		type = "technology",
		name = "resource-monitoring",
		icon = "__Resource-Monitor-Mod__/graphics/resource-monitor.png",
		effects = {
			{
				type = "unlock-recipe",
				recipe = "resource-monitor"
			}
		},
		prerequisites = {
			"logistics-2"
		},
		unit = {
			count = 100,
			ingredients = {
				{"science-pack-1", 1},
				{"science-pack-2", 1}
			},
			time = 30
		}
	},

	{
		type = "container",
		name = "rm_overlay",
		icon = "__Resource-Monitor-Mod__/graphics/rm_Overlay.png",
		flags = {"placeable-neutral", "player-creation"},
		minable = {mining_time = 1, result = "resource-monitor"},
		order = "b[rm_overlay]",
		collision_mask = {"resource-layer"},
		max_health = 100,
		corpse = "small-remnants",
		resistances ={{type = "fire",percent = 80}},
		collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
		selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
		inventory_size = 1,
		picture =
		{
			filename = "__Resource-Monitor-Mod__/graphics/rm_Overlay.png",
			priority = "extra-high",
			width = 32,
			height = 32,
			shift = {0.0, 0.0}
		}
	},
  
}
)

local smallerButtonFont =
{
	type = "button_style",
	parent = "button_style",
	font = "default"
}
data.raw["gui-style"].default["smallerButtonFont"] = smallerButtonFont
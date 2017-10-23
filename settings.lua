data:extend({

	-- Global settings
	{
		type = "int-setting",
		name = "YARM-ticks-between-checks",
		setting_type = "runtime-global",
		order = "a",
		default_value = 600,
		minimum_value = 20,
		maximum_value = 1200
	},
	{
		type = "int-setting",
		name = "YARM-endless-resource-base",
		setting_type = "runtime-global",
		order = "b",
		default_value = 0,
		minimum_value = 0,
		maximum_value = 100
	},
	{
		type = "int-setting",
		name = "YARM-overlay-step",
		setting_type = "runtime-global",
		order = "c",
		default_value = 1,
		minimum_value = 1,
		maximum_value = 5
	},
	
	-- Per user settings
	{
		type = "int-setting",
		name = "YARM-warn-percent",
		setting_type = "runtime-per-user",
		order = "a",
		default_value = 10,
		minimum_value = 0,
		maximum_value = 100
	}
})

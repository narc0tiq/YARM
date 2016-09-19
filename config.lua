if not resmon then resmon = {} end

-- When a resource site is being monitored, the amount of resources in it is
-- only updated once every N game ticks (60 ticks == 1 second), based on this
-- value:
resmon.ticks_between_checks = 600

-- An endless resource site (such as oil patches) will eventually reach some
-- base production level. By default, this will be shown as 0% "full". Change this
-- to 1000 for that base level of production to be shown as 100% "full".
resmon.endless_resource_base = 0

-- Adding huge resource patches can cause FPS drop with large overlays.  Changing
-- the sparseness of the overlay will reduce the FPS drop by having less entities.
-- Set to 1 for full coverage, 2 for 1/4, 3 for 1/9, etc
resmon.overlay_step = 1

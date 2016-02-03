if not resmon then resmon = {} end

-- When a resource site is being monitored, the amount of resources in it is
-- only updated once every N game ticks (60 ticks == 1 second), based on this
-- value:
resmon.ticks_between_checks = 600

-- An endless resource site (such as oil patches) will eventually reach some
-- base production level. By default, this will be shown as 0% "full". Change this
-- to 1000 for that base level of production to be shown as 100% "full".
resmon.endless_resource_base = 0


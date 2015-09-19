if not resmon then resmon = {} end

-- When a resource site is being monitored, the amount of resources in it is
-- only updated once every N game ticks (60 ticks == 1 second), based on this
-- value:
resmon.ticks_between_checks = 600



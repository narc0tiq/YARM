--[[
    The migrations module
    =====================

    Centralizes the migrations of `storage` (formerly `global`) from one structure
    to another.

    Controlled by `storage.versions`, each key in `storage` should have its current
    version recorded, e.g. `storage.versions.force_data = 1`.

    As part of handling on_init and on_configuration_changed, the migrations module will
    check:
    - What is the current version of each key registered in storage.versions?
        - Set to 1 if missing
    - Is there a migration for this key for this version?
        - If yes, execute the migration and repeat with the new version
        - After there are no more migrations, record the last new version in storage.versions

    Migrations must be members of the `local migrations` table below, and must be named
    migrations[storage_key]['v'..version] (e.g., `migrations.force_data.v1`).

    Migrations must return the version number that they output (i.e., if you write a
    migration from 1 to 3, it should return `3`).

    `default_versions` should return the versions expected to be created in a new game,
    which should be the highest version returned by a migration for that key, so that
    they do not execute twice.
    If there are no migrations yet, there is no need to specify version 1.
    Special case: YARM v1.0 will start with version 1 in all cases, as the migrations done
    during 1.0 must be executed even though `storage.versions` is not expected to exist yet.

]]

---@class migrations_module
local migrations_module = {}
local migrations = {
    ore_tracker = {},
    force_data = {},
}

---Generate default storage.versions for a newly started game. Should contain the version
---of the respective datas that will be generated by YARM, i.e. 1 version after the highest
---migration available.
---Used by resmon.init_storage to initialize empty data structures.
---@return { [string]: number } # key-value pair for each storage.blah = its expected version
function migrations_module.default_versions()
    ---@type {[string]: number}
    local default_versions = {
        ore_tracker = 2,
        force_data = 2,
    }
    return default_versions
end

---Perform any migrations that might be necessary.
---Should be called on_init or on_configuration_changed.
function migrations_module.perform_migrations()
    if not storage.versions then
        -- As a special case, if we get here then player_data, etc., already exist but
        -- storage.versions does not, i.e., we are upgrading from a YARM before migrations.
        -- In this case _only_, we must initialize with version 1 (no migrations run) and
        -- then let the migrations be executed to bring the storage up to date.
        storage.versions = {}
        for k, _ in pairs(storage) do
            storage.versions[k] = 1
        end
    end

    for key, version in pairs(storage.versions) do
        if migrations[key] then
            while migrations[key]['v'..version] do
                version = migrations[key]['v'..version]()
            end
            storage.versions[key] = version
        end
    end
end

---YARM 1.0.0:<br>
--- - ore tracker cache keys now include the surface<br>
--- - tracking data can be deleted when entity is lost (e.g., mined out)<br>
--- - tracking data stores the actual cache key rather than only the position
function migrations.ore_tracker.v1()
    if not storage.ore_tracker then
        return 2 -- not created yet so it does not need migration (how did we get here?)
    end

    storage.ore_tracker.to_be_deleted = {}

    for key, tracking_data in pairs(storage.ore_tracker.entities) do
        if not tracking_data.entity or not tracking_data.entity.valid then
            storage.ore_tracker.entities[key] = nil
        else
            tracking_data.position = nil ---@diagnostic disable-line: inject-field
        end
    end
    return 2
end

---2024-12-02, YARM v1.0:<br>
--- - Add index to all sites
--- - Add name_tag to all sites (copy from site.name)
--- - Delete site.name
--- - Switch force_data to be {[site_index]:yarm_site}
function migrations.force_data.v1()
    if not storage.force_data then
        return 2 -- not created yet so it does not need migration (how did we get here?)
    end

    for _, force_data in pairs(storage.force_data) do
        if force_data.ore_sites then
            local new_ore_sites = {}
            for _, site in pairs(force_data.ore_sites) do
                if not site.index then
                    site.index = #new_ore_sites + 1
                    site.name_tag = site.name
                    site.name = nil ---@diagnostic disable-line inject-field
                end
                new_ore_sites[site.index] = site
            end
            force_data.ore_sites = new_ore_sites
        end
    end
    return 2
end

return migrations_module
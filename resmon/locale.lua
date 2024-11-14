local locale_module = {}

---Return a localized string with the estimated time until amount reaches 0
---@param etd_minutes number Estimated minutes until depletion (could be a very large number, or -1 for 'never')
---@param amount_left integer Number of items (resource amount) remaining
---@return LocalisedString A human-readable string describing the time remaining, e.g., rendering to "2d 03:45h"
function locale_module.time_to_deplete(etd_minutes, amount_left)
    if amount_left < 1 then
        return { "YARM-etd-now" }
    end

    local ups_adjust = settings.global["YARM-nominal-ups"].value / 60
    local minutes = (etd_minutes and (etd_minutes / ups_adjust)) or -1

    if minutes == -1 or minutes == math.huge then return { "YARM-etd-never" } end

    local hours = math.floor(minutes / 60)
    local days = math.floor(hours / 24)
    hours = hours % 24
    minutes = minutes % 60
    local time_frag = { "YARM-etd-hour-fragment",
        { "", string.format("%02d", hours), ":", string.format("%02d", math.floor(minutes)) } }

    if days > 0 then
        return { "", { "YARM-etd-day-fragment", days }, " ", time_frag }
    elseif minutes > 0 then
        return time_frag
    else
        return { "YARM-etd-under-1m" }
    end
end

---Return a localized string describing the depletion rate of the given site. Candidate for refactoring
---@param site yarm_site
---@return LocalisedString
function locale_module.site_depletion_rate(site)
    -- TODO Refactor this so the locale module doesn't need to know what a site is
    local ups_adjust = settings.global["YARM-nominal-ups"].value / 60
    local speed = ups_adjust * site.ore_per_minute

    local entity_prototype = prototypes.entity[site.ore_type]
    if entity_prototype.infinite_resource then
        local normal_site_amount = entity_prototype.normal_resource_amount * site.entity_count
        local speed_display = (normal_site_amount == 0 and 0) or (100 * speed) / normal_site_amount
        return locale_module.depletion_rate_to_human(speed_display, true)
    end

    local speed_display = locale_module.depletion_rate_to_human(speed, false)

    if not settings.global["YARM-adjust-for-productivity"].value then
        return speed_display
    end

    local speed_prod = speed * (1 + site.force.mining_drill_productivity_bonus)
    local speed_prod_display = locale_module.depletion_rate_to_human(speed_prod, false)

    if not settings.global["YARM-productivity-show-raw-and-adjusted"].value then
        return speed_prod_display
    elseif settings.global["YARM-productivity-parentheses-part-is"].value == "adjusted" then
        return { "", speed_display, " (", speed_prod_display, ")" }
    else
        return { "", speed_prod_display, " (", speed_display, ")" }
    end
end

---Turn a numeric depletion rate (e.g., -5 -- representing 5 items per minute) to a localized string
---@param rate number How quickly the resource is depleting (if negative) or increasing (if positive, which never happens)
---@param is_infinite boolean Whether the resource is infinite (which are displayed with greater precision)
---@return LocalisedString A human-readable version, e.g., rendering to "-45.5/m"
function locale_module.depletion_rate_to_human(rate, is_infinite)
    local limit = is_infinite and -0.001 or -0.1
    local format = is_infinite and "%.3f%%" or "%.1f"

    if rate < limit then
        return { "YARM-ore-per-minute", locale_module.format_number(string.format(format, rate)) }
    elseif rate < 0 then
        return { "YARM-ore-per-minute", { "", "<", string.format(format, -0.1) } }
    end
    -- rate > 0? This should never happen, right? ...Right?
    return { "YARM-ore-per-minute", locale_module.format_number(string.format(format, rate)) }
end

---Add thousands separators to a number given as a string
---@param n string The number to be formatted (may be integer or decimal)
---@return string The prettily-formatted number (e.g., "123,456.7")
-- Note: I am aware of util.format_number, but that expects a _number_, whereas here I am working with strings
function locale_module.format_number(n) -- credit http://richard.warburton.it
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

local si_prefixes = { '', ' k', ' M', ' G' }

function locale_module.format_number_si(n)
    for i = 1, #si_prefixes do
        if n < 1000 then
            return string.format('%.1f%s', n, si_prefixes[i])
        end
        n = math.floor(n / 100)/10 -- keep 1 significant decimal
    end

    -- 1,234.5 T resources? I guess we should support it...
    return string.format('%s T', locale_module.format_number(string.format('%.1f', n)))
end

return locale_module
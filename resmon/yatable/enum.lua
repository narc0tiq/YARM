return {
    ---@enum yatable_row_type
    row_type = {
        site = 'site_row',
        divider = 'divider_row',
        summary = 'summary_row',
        header = 'header_row',
    },

    ---@enum yatable_column_type
    column_type = {
        rename_button = 'rename_button',
        surface_name = 'surface_name',
        site_name = 'site_name',
        remaining_percent = 'remaining_percent',
        site_amount = 'site_amount',
        ore_name_compact = 'ore_name_compact',
        ore_name_full = 'ore_name_full',
        ore_per_minute = 'ore_per_minute',
        ore_per_minute_arrow = 'ore_per_minute_arrow',
        etd_timespan = 'etd_timespan',
        etd_arrow = 'etd_arrow',
        site_status = 'site_status',
        site_buttons_compact = 'site_buttons_compact',
        site_buttons_full = 'site_buttons_full',
    },

    cancelable_buttons = {
        rename_site = {
            operation = "YARM_rename_site",
            normal = {
                tooltip_base = "YARM-tooltips.rename-site-named",
                style = "YARM_rename_site",
            },
            active = {
                tooltip_base = "YARM-tooltips.rename-site-cancel",
                style = "YARM_rename_site_cancel",
            }
        },
        delete_site = {
            operation = "YARM_delete_site",
            normal = {
                tooltip_base = "YARM-tooltips.delete-site",
                style = "YARM_delete_site",
            },
            active = {
                tooltip_base = "YARM-tooltips.delete-site-confirm",
                style = "YARM_delete_site_confirm",
            }
        },
        expand_site = {
            operation = "YARM_expand_site",
            normal = {
                tooltip_base = "YARM-tooltips.expand-site",
                style = "YARM_expand_site",
            },
            active = {
                tooltip_base = "YARM-tooltips.expand-site-cancel",
                style = "YARM_expand_site_cancel",
            }
        }
    }

}

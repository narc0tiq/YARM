---@class click_module
local click_module = {
    handlers = {}
}

function click_module.on_gui_click(event)
    -- Automatic binding: if you add handlers.some_button_name, then a click on a GUI element
    -- named `some_button_name` will automatically be routed to the handler
    if click_module.handlers[event.element.name] then
        click_module.handlers[event.element.name](event)
    -- Remaining bindings are for dynamically-named elements:
    elseif string.starts_with(event.element.name, "YARM_filter_") then
        click_module.set_filter(event)
    elseif string.starts_with(event.element.name, "YARM_delete_site_") then
        click_module.delete_site(event)
    elseif string.starts_with(event.element.name, "YARM_rename_site_") then
        click_module.rename_site(event)
    elseif string.starts_with(event.element.name, "YARM_goto_site_") then
        click_module.goto_site(event)
    elseif string.starts_with(event.element.name, "YARM_expand_site_") then
        click_module.expand_site(event)
    end
end

function click_module.set_filter(event)
    local new_filter = string.sub(event.element.name, 1 + string.len("YARM_filter_"))
    local player = game.players[event.player_index]
    local player_data = storage.player_data[event.player_index]

    player_data.active_filter = new_filter

    resmon.ui.update_filter_buttons(player)
    resmon.ui.update_player(player)
end

function click_module.delete_site(event)
    local site_name = string.sub(event.element.name, 1 + string.len("YARM_delete_site_"))

    local player = game.players[event.player_index]
    local force_data = storage.force_data[player.force.name]
    local site = force_data.ore_sites[site_name]

    if site.deleting_since then
        force_data.ore_sites[site_name] = nil

        if site.chart_tag and site.chart_tag.valid then
            site.chart_tag.destroy()
        end
    else
        site.deleting_since = event.tick
    end

    resmon.ui.update_force_members(player.force)
end

function click_module.rename_site(event)
    local site_name = string.sub(event.element.name, 1 + string.len("YARM_rename_site_"))

    local player = game.players[event.player_index]
    local player_data = storage.player_data[event.player_index]

    if player.gui.center.YARM_site_rename then
        click_module.handlers.YARM_rename_cancel(event)
        return
    end

    player_data.renaming_site = site_name
    local root = player.gui.center.add { type = "frame",
        name = "YARM_site_rename",
        caption = { "YARM-site-rename-title", site_name },
        direction = "horizontal" }

    root.add { type = "textfield", name = "new_name" }.text = site_name
    root.add { type = "button", name = "YARM_rename_cancel", caption = { "YARM-site-rename-cancel" }, style = "back-button" }
    root.add { type = "button", name = "YARM_rename_confirm", caption = { "YARM-site-rename-confirm" }, style = "confirm-button" }

    player.opened = root

    resmon.ui.update_force_members(player.force)
end

function click_module.goto_site(event)
    local site_name = string.sub(event.element.name, 1 + string.len("YARM_goto_site_"))

    local player = game.players[event.player_index]
    local force_data = storage.force_data[player.force.name]
    local site = force_data.ore_sites[site_name]

    player.set_controller({type = defines.controllers.remote, position = site.center, surface = site.surface})

    resmon.ui.update_force_members(player.force)
end

-- one button handler for both the expand_site and expand_site_cancel buttons
function click_module.expand_site(event)
    local site_name = string.sub(event.element.name, 1 + string.len("YARM_expand_site_"))

    local player = game.players[event.player_index]
    local player_data = storage.player_data[event.player_index]
    local force_data = storage.force_data[player.force.name]
    local site = force_data.ore_sites[site_name]
    local are_we_cancelling_expand = site.is_site_expanding

    --[[ we want to submit the site if we're cancelling the expansion (mostly because submitting the
         site cleans up the expansion-related variables on the site) or if we were adding a new site
         and decide to expand an existing one
    --]]
    if are_we_cancelling_expand and player_data.current_site then
        resmon.submit_site(event.player_index)
    end

    --[[ this is to handle cancelling an expansion (by clicking the red button) - submitting the site is
         all we need to do in this case ]]
    if are_we_cancelling_expand then
        resmon.ui.update_force_members(player.force)
        return
    end

    resmon.on_get_selection_tool(event)
    if player.cursor_stack.valid_for_read and player.cursor_stack.name == "yarm-selector-tool" then
        site.is_site_expanding = true
        player_data.current_site = site

        resmon.ui.update_force_members(player.force)
        resmon.start_recreate_overlay_existing_site(event.player_index)
    end
end

-----------------------------------------------------------------------------------------------
-- HANDLERS just need to have the same name as the UI element whose click events they handle --
-----------------------------------------------------------------------------------------------
-- Please put only handlers below this line.

-- Just a local alias to make it easier to read
local handlers = click_module.handlers

function handlers.YARM_rename_confirm(event)
    local player = game.players[event.player_index]
    local player_data = storage.player_data[event.player_index]
    local force_data = storage.force_data[player.force.name]

    local old_name = player_data.renaming_site
    local new_name = player.gui.center.YARM_site_rename.new_name.text
    local new_name_length_without_tags =
        string.len(string.gsub(new_name, "%[[^=%]]+=[^=%]]+%]", "123"))
    -- NB: We replace [rich-text=tags] before checking the name length to allow for the tags
    -- to be part of a site name without quickly bumping up against the MAX_SITE_NAME_LENGTH,
    -- which is otherwise quite restrictive.
    -- Pattern explanation:
    -- * one literal `[`: "%["
    -- * 1+ characters that are not `=` or `]`: "[^=%]]+"
    -- * one literal `=`: "="
    -- * 1+ characters that are not `=` or `]`: "[^=%]]+"
    -- * one literal `]`: "%]"

    if new_name_length_without_tags > resmon.ui.MAX_SITE_NAME_LENGTH then
        player.print { 'YARM-err-site-name-too-long', resmon.ui.MAX_SITE_NAME_LENGTH }
        return
    end

    local site = force_data.ore_sites[old_name]
    force_data.ore_sites[old_name] = nil
    force_data.ore_sites[new_name] = site
    site.name = new_name

    resmon.ui.update_chart_tag(site)

    player_data.renaming_site = nil
    player.gui.center.YARM_site_rename.destroy()

    resmon.ui.update_force_members(player.force)
end

function handlers.YARM_rename_cancel(event)
    local player = game.players[event.player_index]
    local player_data = storage.player_data[event.player_index]

    player_data.renaming_site = nil
    player.gui.center.YARM_site_rename.destroy()

    resmon.ui.update_force_members(player.force)
end

function handlers.YARM_toggle_bg(event)
    local player = game.players[event.player_index]
    local root = resmon.ui.get_or_create_hud(player)
    if not root then
        return
    end

    local has_bg = root.style.name == "YARM_outer_frame_no_border_bg"

    root.style = has_bg and "YARM_outer_frame_no_border" or "YARM_outer_frame_no_border_bg"
    local button = root.buttons.YARM_toggle_bg
    button.style = has_bg and "YARM_toggle_bg_on" or "YARM_toggle_bg"

    resmon.ui.update_player(player)
end

function handlers.YARM_toggle_surfacesplit(event)
    local player = game.players[event.player_index]
    local root = resmon.ui.get_or_create_hud(player)
    if not root then
        return
    end

    local button = root.buttons.YARM_toggle_surfacesplit
    button.style = button.style.name == "YARM_toggle_surfacesplit" and "YARM_toggle_surfacesplit_on" or "YARM_toggle_surfacesplit"
    resmon.ui.update_player(player)
end

function handlers.YARM_toggle_lite(event)
    local player = game.players[event.player_index]
    local root = resmon.ui.get_or_create_hud(player)
    if not root then
        return
    end

    local button = root.buttons.YARM_toggle_lite
    button.style = button.style.name == "YARM_toggle_lite" and "YARM_toggle_lite_on" or "YARM_toggle_lite"
    resmon.ui.update_player(player)
end

return click_module
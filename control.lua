require "defines"

game.on_init(function()
	--startingItems()
	initTables()
	for k,player in pairs(game.players) do
		initPlayer(player)
	end
end)


game.on_load(function()
	initTables()
	for k,player in pairs(game.players) do
		initPlayer(player)
	end
end)


game.on_event(defines.events.on_player_created, function(event)
	local player = game.get_player(event.player_index)
	initPlayer(player)
end)


game.on_event(defines.events.on_entity_died, function(event)
end)


game.on_event(defines.events.on_player_mined_item, function(event)
end)


game.on_event(defines.events.on_built_entity, function(event)
	if event.created_entity.name == "resource-monitor" then
		local pos ={x = event.created_entity.position.x, y = event.created_entity.position.y}
		local ent = event.created_entity.surface.find_entities_filtered{area = {{pos.x - 0.01, pos.y - 0.01}, {pos.x + 0.01, pos.y + 0.01}}, type="resource"}
		local player = game.get_player(event.player_index)
		if (#ent > 0) and ((ent[1].prototype.resource_category == "basic-solid") or (isInSolidList(ent[1].prototype.resource_category,player))) then
			if player.gui.left.monitorFrame ~= nil then player.gui.left.monitorFrame.destroy() end
			if player.gui.left.resourceMonitorMinimized ~= nil then player.gui.left.resourceMonitorMinimized.destroy() end
			global.resourceMonitor[player.index].flags.MonitorVisible = 0
			addMonitor(pos, ent[1],player)
		elseif (#ent > 0) and ((ent[1].prototype.resource_category == "basic-fluid") or (isInLiquidList(ent[1].prototype.resource_category))) then
			if player.gui.left.monitorFrame ~= nil then player.gui.left.monitorFrame.destroy() end
			if player.gui.left.resourceMonitorMinimized ~= nil then player.gui.left.resourceMonitorMinimized.destroy() end
			global.resourceMonitor[player.index].flags.MonitorVisible = 0
			oilAdder(ent[1],player)
		else
			if global.resourceMonitor[player.index].flags.AdderVisible ~= 1 then
				global.resourceMonitor[player.index].flags.MonitorVisible = 1
				showMonitorGUI(player)
			end
		end
		player.insert{name = "resource-monitor", count = 1}
		event.created_entity.destroy()
	end
end)


game.on_event(defines.events.on_tick, function(event)
	for _,player in ipairs(game.players) do
		if global.resourceMonitor[player.index] ~= nil and game.tick % global.resourceMonitor[player.index].flags.updateFreq == 11 then
			updateMonitorValues(player)
			showMonitorGUI(player)
		end
	end
end)


game.on_event(defines.events.on_gui_click, function(event)
	local player = game.get_player(event.player_index)
	if event.element.name == "addButton" then
		global.resourceMonitor[player.index].sites[#global.resourceMonitor[player.index].sites + 1] = {}
		global.resourceMonitor[player.index].sites[#global.resourceMonitor[player.index].sites].name = player.gui.left.resourceMonitorAddingFrame.infoTable.siteNameText.text
		global.resourceMonitor[player.index].sites[#global.resourceMonitor[player.index].sites].initialAmount = global.resourceMonitor[player.index].tmpSite.amount
		global.resourceMonitor[player.index].sites[#global.resourceMonitor[player.index].sites].amount = global.resourceMonitor[player.index].tmpSite.amount
		global.resourceMonitor[player.index].sites[#global.resourceMonitor[player.index].sites].resourceType = global.resourceMonitor[player.index].tmpSite.resourceType
		global.resourceMonitor[player.index].sites[#global.resourceMonitor[player.index].sites].surface = global.resourceMonitor[player.index].tmpSite.surface

		global.resourceMonitor[player.index].sites[#global.resourceMonitor[player.index].sites].oreDeposits = {}
		for i,k in ipairs(global.resourceMonitor[player.index].tmpSite.oreDeposits) do
			global.resourceMonitor[player.index].sites[#global.resourceMonitor[player.index].sites].oreDeposits[i]= {x = k.x, y = k.y}
		end
		for _,overlay in ipairs(global.resourceMonitor[player.index].overlayStack) do
			if overlay.valid then
				overlay.destroy()
			end
		end
		global.resourceMonitor[player.index].overlayStack = {}
		global.resourceMonitor[player.index].tmpSite.oreDeposits = {}
		player.gui.left.resourceMonitorAddingFrame.destroy()
		global.resourceMonitor[player.index].flags.AdderVisible = 0
		global.resourceMonitor[player.index].flags.MonitorVisible = 1
		showMonitorGUI(player)
	elseif event.element.name == "cancelAddButton" then
		for _,overlay in ipairs(global.resourceMonitor[player.index].overlayStack) do
			if overlay.valid then
				overlay.destroy()
			end
		end
		global.resourceMonitor[player.index].overlayStack = {}
		player.gui.left.resourceMonitorAddingFrame.destroy()
		global.resourceMonitor[player.index].flags.AdderVisible = 0
		global.resourceMonitor[player.index].flags.MonitorVisible = 1
		showMonitorGUI(player)
	elseif event.element.name == "minButton" then
		player.gui.left.monitorFrame.destroy()
		global.resourceMonitor[player.index].flags.MonitorVisible = 2
		showMonitorGUI(player)
	elseif event.element.name == "resourceMonitorMinimized" then
		player.gui.left.resourceMonitorMinimized.destroy()
		global.resourceMonitor[player.index].flags.MonitorVisible = 1
		showMonitorGUI(player)
	elseif event.element.name == "monitorClose" then
		player.gui.left.monitorFrame.destroy()
		global.resourceMonitor[player.index].flags.MonitorVisible = 0
	elseif event.element.name == "settingsButton" then
		player.gui.left.monitorFrame.destroy()
		global.resourceMonitor[player.index].flags.MonitorVisible = 0
		global.resourceMonitor[player.index].flags.SettingsVisible = 1
		showSettingsGUI(player)
	elseif event.element.name == "settingsYesButton" then
		if player.gui.left.settingsFrame.settingsTable.showTypeBox.state == true then
			global.resourceMonitor[player.index].flags.ShowType = 1
		else
			global.resourceMonitor[player.index].flags.ShowType = 0
		end
		if player.gui.left.settingsFrame.settingsTable.showAmountBox.state == true then
			global.resourceMonitor[player.index].flags.ShowAmount = 1
		else
			global.resourceMonitor[player.index].flags.ShowAmount = 0
		end
		if player.gui.left.settingsFrame.settingsTable.showRemoveBox.state == true then
			global.resourceMonitor[player.index].flags.ShowRemove = 1
		else
			global.resourceMonitor[player.index].flags.ShowRemove = 0
		end
		if player.gui.left.settingsFrame.settingsTable.showDeltaBox.state == true then
			global.resourceMonitor[player.index].flags.ShowDelta = 1
		else
			global.resourceMonitor[player.index].flags.ShowDelta = 0
		end
		if player.gui.left.settingsFrame.settingsTable.showNotificationBox.state == true then
			global.resourceMonitor[player.index].flags.ShowNotification = 1
		else
			global.resourceMonitor[player.index].flags.ShowNotification = 0
		end
		if player.gui.left.settingsFrame.settingsTable.showNotificationBox2.state == true then
			global.resourceMonitor[player.index].flags.ShowNotification2 = 1
		else
			global.resourceMonitor[player.index].flags.ShowNotification2 = 0
		end
		if player.gui.left.settingsFrame.settingsUpdateFrame.settingsUpdateTable.updateBox1.state == true then
			if global.resourceMonitor[player.index].flags.updateFreq ~= 600 then
				global.resourceMonitor[player.index].flags.updateFreq = 600
			end
		elseif player.gui.left.settingsFrame.settingsUpdateFrame.settingsUpdateTable.updateBox2.state == true then
			if global.resourceMonitor[player.index].flags.updateFreq ~= 1800 then
				global.resourceMonitor[player.index].flags.updateFreq = 1800
			end
		elseif player.gui.left.settingsFrame.settingsUpdateFrame.settingsUpdateTable.updateBox3.state == true then
			if global.resourceMonitor[player.index].flags.updateFreq ~= 3600 then
				global.resourceMonitor[player.index].flags.updateFreq = 3600
			end
		end
		player.gui.left.settingsFrame.destroy()
		global.resourceMonitor[player.index].flags.MonitorVisible = 1
		global.resourceMonitor[player.index].flags.SettingsVisible = 0
		showMonitorGUI(player)
	elseif event.element.name == "settingsCancelButton" then
		player.gui.left.settingsFrame.destroy()
		global.resourceMonitor[player.index].flags.MonitorVisible = 1
		global.resourceMonitor[player.index].flags.SettingsVisible = 0
		showMonitorGUI(player)
	elseif string.find (event.element.name, "monitorRemoveButton") ~= nil then
		local txt, cnt = string.gsub (event.element.name, "monitorRemoveButton" , "")
		table.remove(global.resourceMonitor[player.index].sites, txt)
		showMonitorGUI(player)
	elseif event.element.name == "updateBox1" then
		player.gui.left.settingsFrame.settingsUpdateFrame.settingsUpdateTable.updateBox2.state = not event.element.state
		player.gui.left.settingsFrame.settingsUpdateFrame.settingsUpdateTable.updateBox3.state = not event.element.state
	elseif event.element.name == "updateBox2" then
		player.gui.left.settingsFrame.settingsUpdateFrame.settingsUpdateTable.updateBox1.state = not event.element.state
		player.gui.left.settingsFrame.settingsUpdateFrame.settingsUpdateTable.updateBox3.state = not event.element.state
	elseif event.element.name == "updateBox3" then
		player.gui.left.settingsFrame.settingsUpdateFrame.settingsUpdateTable.updateBox1.state = not event.element.state
		player.gui.left.settingsFrame.settingsUpdateFrame.settingsUpdateTable.updateBox2.state = not event.element.state
	elseif event.element.name == "newOilAddButton" then
		global.resourceMonitor[player.index].oil[#global.resourceMonitor[player.index].oil + 1] = {}
		global.resourceMonitor[player.index].oil[#global.resourceMonitor[player.index].oil].name = player.gui.left.oilMonitorAddingFrame.infoTable.siteNameText.text
		global.resourceMonitor[player.index].oil[#global.resourceMonitor[player.index].oil].type = global.resourceMonitor[player.index].tmpOil.name
		global.resourceMonitor[player.index].oil[#global.resourceMonitor[player.index].oil].surface = global.resourceMonitor[player.index].tmpOil.surface
		global.resourceMonitor[player.index].oil[#global.resourceMonitor[player.index].oil].entity = {}
		global.resourceMonitor[player.index].oil[#global.resourceMonitor[player.index].oil].entity[1] = global.resourceMonitor[player.index].tmpOil
		player.gui.left.oilMonitorAddingFrame.destroy()
		global.resourceMonitor[player.index].flags.AdderVisible = 0
		global.resourceMonitor[player.index].flags.MonitorVisible = 1
		showMonitorGUI(player)
	elseif event.element.name == "newOilExistButton" then
		if #global.resourceMonitor[player.index].oil > 0 then
			oilAdderExpansion(player)
		else
			player.print({"noOilLabel"})
		end
	elseif event.element.name == "newOreExistButton" then
		if #global.resourceMonitor[player.index].sites > 0 then
			oreAdderExpansion(player)
		else
			player.print({"noOreLabel"})
		end
	elseif string.find (event.element.name, "oilAddExistButton") ~= nil then
		local txt, cnt = string.gsub (event.element.name, "oilAddExistButton" , "")
		txt = tonumber(txt)
		local tmpFlag = false
		for i,_ in ipairs(global.resourceMonitor[player.index].oil[txt].entity) do
			if global.resourceMonitor[player.index].oil[txt].entity[i] == global.resourceMonitor[player.index].tmpOil then
				tmpFlag = true
			end
		end
		if tmpFlag == false then
			table.insert(global.resourceMonitor[player.index].oil[txt].entity, global.resourceMonitor[player.index].tmpOil)
			player.gui.left.oilMonitorAddingFrame.destroy()
			global.resourceMonitor[player.index].flags.AdderVisible = 0
			global.resourceMonitor[player.index].flags.MonitorVisible = 1
			showMonitorGUI(player)
		else
			player.print({"oilwellalreadypresent"})
		end
	elseif string.find (event.element.name, "oreAddExistButton") ~= nil then
		local txt, cnt = string.gsub (event.element.name, "oreAddExistButton" , "")
		txt = tonumber(txt)
		local deposits = {}
		for _,newDeposit in ipairs(global.resourceMonitor[player.index].tmpSite.oreDeposits) do
			local tmpFlag = false
			for _,existingDeposit in ipairs(global.resourceMonitor[player.index].sites[txt].oreDeposits) do
				if (newDeposit.x == existingDeposit.x) and (newDeposit.y == existingDeposit.y) then
					tmpFlag = true
				end
			end
			if tmpFlag == false then table.insert(deposits, newDeposit) end
		end
		if #deposits > 0 then
			for i,_ in ipairs(deposits) do
				table.insert(global.resourceMonitor[player.index].sites[txt].oreDeposits, deposits[i])
			end
		else
			player.print({"oreDepositalreadypresent"})
		end
		for _,overlay in ipairs(global.resourceMonitor[player.index].overlayStack) do
			if overlay.valid then
				overlay.destroy()
			end
		end
		global.resourceMonitor[player.index].tmpSite.oreDeposits = {}
		player.gui.left.resourceMonitorAddingFrame.destroy()
		global.resourceMonitor[player.index].flags.AdderVisible = 0
		global.resourceMonitor[player.index].flags.MonitorVisible = 1
		updateMonitorValues(player)
		showMonitorGUI(player)
		
	elseif event.element.name == "oilCancelAddButton" then
		player.gui.left.oilMonitorAddingFrame.destroy()
		global.resourceMonitor[player.index].flags.AdderVisible = 0
		global.resourceMonitor[player.index].flags.MonitorVisible = 1
		showMonitorGUI(player)
	elseif string.find (event.element.name, "oilMonitorRemoveButton") ~= nil then
		local txt, cnt = string.gsub (event.element.name, "oilMonitorRemoveButton" , "")
		table.remove(global.resourceMonitor[player.index].oil, txt)
		showMonitorGUI(player)
	elseif event.element.name == "switchMode" then
			local elementCaption = tostring(event.element.caption[1])
			local testCaption = "modeButtonResource"
		if elementCaption == testCaption then
			global.resourceMonitor[player.index].flags.ShowResource = 0
			global.resourceMonitor[player.index].flags.ShowOil = 1
		else
			global.resourceMonitor[player.index].flags.ShowResource = 1
			global.resourceMonitor[player.index].flags.ShowOil = 0
		end
		showMonitorGUI(player)
	end
end)


function updateMonitorValues(player)
	for _, monitor in ipairs(global.resourceMonitor[player.index].sites) do
		if type(monitor.amount) ~= type(42) then
			if global.resourceMonitor[player.index].flags.ShowNotification == 1 then
				player.print({"depletedNotification"})
			end
		else
			local amount = 0
			for _, pos in ipairs(monitor.oreDeposits) do
				local tmpDeposit = monitor.surface.find_entities_filtered{area = {{pos.x - 0.01, pos.y - 0.01}, {pos.x + 0.01, pos.y + 0.01}}, name = monitor.resourceType}
				if tmpDeposit[1] ~= nil then
					amount = amount + tmpDeposit[1].amount
				end
			end

			if monitor.oldAmount == nil then
				monitor.oldAmount = amount
				monitor.deltaAmount = {0,0,0,0,0,0,0}
			end

			if amount == 0 then
				monitor.amount = {"depleted"}
				if global.resourceMonitor[player.index].flags.ShowNotification == 1 then
					player.print({"depletedNotification"})
				end
			else
				monitor.amount = amount
			end

			if type(monitor.amount) == type(42) then
				local newDelta = (monitor.oldAmount - monitor.amount) * (3600 / global.resourceMonitor[player.index].flags.updateFreq)
				if newDelta >= 0 then
					table.remove(monitor.deltaAmount,2)
					table.insert(monitor.deltaAmount, newDelta)
				end
				local deltaSum = 0
				for k, value in ipairs(monitor.deltaAmount) do
					if k ~= 1 then
						deltaSum = deltaSum + value
					end
				end
				monitor.deltaAmount[1] = math.floor(deltaSum / 6)
				if (monitor.maxdelta == nil) then
					monitor.maxdelta = 0
				end 
				if (monitor.deltaAmount[1] ~= nil) and (type(monitor.deltaAmount[1]) == type(42)) then
					if monitor.deltaAmount[1] > monitor.maxdelta then
						monitor.maxdelta = monitor.deltaAmount[1]
					end
				end
				if global.resourceMonitor[player.index].flags.ShowNotification2 == 1 then
					if monitor.amount <= monitor.initialAmount / 10 then
						player.print({"nearlyDepletedNotification"})
					end
				end
			else
				monitor.deltaAmount[1] = {"na"}
			end

			monitor.oldAmount = monitor.amount
		end
	end
end


function initTables()
	if global.resourceMonitor == nil then
		global.resourceMonitor = {}
	end
	global.resourceMonitor.version = "0.5.5"
end


function initPlayer(player)
		
		if global.resourceMonitor[player.index] == nil then
			global.resourceMonitor[player.index] = {}
		
		
			if global.resourceMonitor[player.index].flags == nil then
				global.resourceMonitor[player.index].flags = {}
			end

				if global.resourceMonitor[player.index].flags.MonitorVisible == nil then
					global.resourceMonitor[player.index].flags.MonitorVisible = 0	-- 0 = not visible
																											-- 1 = GUI visible
																											-- 2 = GUI minimized
				end
				
				if global.resourceMonitor[player.index].flags.AdderVisible == nil then	
					global.resourceMonitor[player.index].flags.AdderVisible = 0		-- 0 = not visible
																												-- 1 = GUI visible
				end

				if global.resourceMonitor[player.index].flags.SettingsVisible == nil then
					global.resourceMonitor[player.index].flags.SettingsVisible = 0	-- 0 = not visible
																												-- 1 = GUI visible
				end

				if global.resourceMonitor[player.index].flags.ShowType == nil then
					global.resourceMonitor[player.index].flags.ShowType = 1			-- 0 = not visible
																												-- 1 = element visible
				end

				if global.resourceMonitor[player.index].flags.ShowAmount == nil then
					global.resourceMonitor[player.index].flags.ShowAmount = 1		-- 0 = not visible
																												-- 1 = element visible
				end

				if global.resourceMonitor[player.index].flags.ShowRemove == nil then
					global.resourceMonitor[player.index].flags.ShowRemove = 1		-- 0 = not visible
																												-- 1 = element visible
				end

				if global.resourceMonitor[player.index].flags.ShowDelta == nil then
					global.resourceMonitor[player.index].flags.ShowDelta = 1		-- 0 = not visible
																											-- 1 = element visible
				end

				if global.resourceMonitor[player.index].flags.ShowNotification == nil then
					global.resourceMonitor[player.index].flags.ShowNotification = 1 -- 0 = no messages
																												-- 1 = show messages
				end

				if global.resourceMonitor[player.index].flags.ShowNotification2 == nil then
					global.resourceMonitor[player.index].flags.ShowNotification2 = 1   -- 0 = no 10% messages
																													-- 1 = show 10% messages
				end

				if global.resourceMonitor[player.index].flags.ShowResource == nil then
					global.resourceMonitor[player.index].flags.ShowResource = 1 	-- 0 = no visible
																												-- 1 = visible
				end

				if global.resourceMonitor[player.index].flags.ShowOil == nil then
					global.resourceMonitor[player.index].flags.ShowOil = 0 			-- 0 = not visible
																												-- 1 = visible
				end

				if global.resourceMonitor[player.index].flags.updateFreq == nil then
					global.resourceMonitor[player.index].flags.updateFreq = 600		-- in ticks
				end

			if global.resourceMonitor[player.index].sites == nil then
				global.resourceMonitor[player.index].sites = {}
			else
				for _, deposit in ipairs(global.resourceMonitor[player.index].sites) do
					if deposit.initialAmount == nil then
						deposit.initialAmount = deposit.amount
					end
				end
			end

			if global.resourceMonitor[player.index].tmpSite == nil then
				global.resourceMonitor[player.index].tmpSite = {amount, resourceType, oreDeposits = {}}
			end

			if global.resourceMonitor[player.index].overlayStack == nil then
				global.resourceMonitor[player.index].overlayStack = {}
			end

			if global.resourceMonitor[player.index].oil == nil then
				global.resourceMonitor[player.index].oil = {}
				global.resourceMonitor[player.index].flags.ShowResource = 1 
				global.resourceMonitor[player.index].flags.ShowOil = 1
			else
				if #global.resourceMonitor[player.index].oil > 0 then
					for _,oilMonitor in ipairs(global.resourceMonitor[player.index].oil) do
						if oilMonitor.type == nil then
							oilMonitor.type = oilMonitor.entity[1].name
						end
					end
				end
			end

			if global.resourceMonitor[player.index].tmpOil == nil then
				global.resourceMonitor[player.index].tmpOil = {}
			end

			if global.resourceMonitor[player.index].resourceSolidList == nil then
				global.resourceMonitor[player.index].resourceSolidList = {}
			end

			if global.resourceMonitor[player.index].resourceLiquidList == nil then
				global.resourceMonitor[player.index].resourceLiquidList = {}
			end

		end
		
end


function showMonitorGUI(player)
	if global.resourceMonitor[player.index].flags.MonitorVisible == 1 then
		if player.gui.left.monitorFrame ~= nil then player.gui.left.monitorFrame.destroy() end
		local rootFrame = player.gui.left.add{type = "frame", name = "monitorFrame", caption = {"monitorCaption"}, direction = "vertical"}
		rootFrame.add{type = "flow", name = "monitorFlow", direction = "horizontal"}
		rootFrame.monitorFlow.add{type = "button", name = "minButton", caption = {"minButtonCaption"}, style = "smallerButtonFont"}
		local modeButtonCaption = 0
		if global.resourceMonitor[player.index].flags.ShowResource == 1 then
			global.resourceMonitor[player.index].flags.ShowOil = 0
			modeButtonCaption = {"modeButtonResource"}
		else
			global.resourceMonitor[player.index].flags.ShowResource = 0
			global.resourceMonitor[player.index].flags.ShowOil = 1
			modeButtonCaption = {"modeButtonOil"}
		end
		rootFrame.monitorFlow.add{type = "button", name = "switchMode", caption = modeButtonCaption, style = "smallerButtonFont"}
		rootFrame.monitorFlow.add{type = "button", name = "settingsButton", caption = {"settingsButtonCaption"}, style = "smallerButtonFont"}
		rootFrame.monitorFlow.add{type = "button", name = "monitorClose", caption = {"monitorClose"}, style = "smallerButtonFont"}

		local opt = global.resourceMonitor[player.index].flags
		if (#global.resourceMonitor[player.index].sites > 0) and (opt.ShowResource == 1) then
			local sum = 1 + opt.ShowType + opt.ShowAmount + opt.ShowRemove + opt.ShowDelta
			local resFrame = rootFrame.add{type ="frame", name = "resMonitorTable", caption = {"ores"}}
			resFrame.add{type ="table", name = "monitorTable", colspan = sum}
				resFrame.monitorTable.add{type = "label", name = "siteNameLabelHead", caption = {"siteNameLabel"}}
				if opt.ShowType == 1 then
					resFrame.monitorTable.add{type = "label", name = "siteTypeLabelHead", caption = {"resTypeLabel"}}
				end
				if opt.ShowAmount == 1 then
					resFrame.monitorTable.add{type = "label", name = "siteAmountLabelHead", caption = {"resAmountLabel"}}
				end
				if opt.ShowDelta == 1 then
					resFrame.monitorTable.add{type = "label", name = "siteDeltaLabelHead", caption = {"siteDeltaLabelHead"}}
				end
				if opt.ShowRemove == 1 then
					resFrame.monitorTable.add{type = "label", name = "monitorDummy", caption = " "}
				end
				for i,k in ipairs(global.resourceMonitor[player.index].sites) do
					resFrame.monitorTable.add{type = "label", name = "siteNameLabel"..i, caption = k.name}
					if opt.ShowType == 1 then
						resFrame.monitorTable.add{type = "label", name = "siteTypeLabel"..i, caption = game.get_localised_entity_name(k.resourceType)}
					end
					if opt.ShowAmount == 1 then
						resFrame.monitorTable.add{type = "label", name = "siteAmountLabel"..i, caption = "  "}
						if type(k.amount) ~= type(42) then
							resFrame.monitorTable["siteAmountLabel"..i].caption = k.amount
							resFrame.monitorTable["siteAmountLabel"..i].style.font_color = {r = 1, g = 0, b = 0}
						else
							local formattedAmount = formatAmount(k.amount)
							local color = {r = 1, g = 1, b = 0}
							if k.amount >= k.initialAmount / 2 then
								color.r = (1 - (k.amount / k.initialAmount)) 
								if color.r > 1 then
									color.r = 1
								elseif color.r < 0 then
									color.r = 0
								end
							else
								color.g = 2 * (k.amount / k.initialAmount)
								if color.g > 1 then
									color.g = 1
								elseif color.g < 0 then
									color.g = 0
								end
							end
							resFrame.monitorTable["siteAmountLabel"..i].style.font_color = color
							resFrame.monitorTable["siteAmountLabel"..i].caption = "  " ..formattedAmount
						end
					end
					if opt.ShowDelta == 1 then
						local delta = 0
						if k.deltaAmount ~= nil then
							delta = k.deltaAmount[1]
						end
						local mdelta = 0
						if k.maxdelta ~= nil then
							mdelta = k.maxdelta
						end
						resFrame.monitorTable.add{type = "label", name = "siteDeltaLabel"..i, caption = " "}
						if (type(delta) ~= type(42)) or (delta == 0) then
							resFrame.monitorTable["siteDeltaLabel"..i].caption = delta
							resFrame.monitorTable["siteDeltaLabel"..i].style.font_color = {r = 1, g = 0, b = 0}
						elseif mdelta ~= 0 then
							local color = {r = 1, g = 1, b = 0}
							if delta >= mdelta / 2 then
								color.g = 1
								color.r = (1 - (delta / mdelta)) * 2
							else
								color.r = 1
								color.g = 2 * (delta / mdelta)
							end
							resFrame.monitorTable["siteDeltaLabel"..i].style.font_color = color
							resFrame.monitorTable["siteDeltaLabel"..i].caption = formatAmount(delta)
						end
					end
					if opt.ShowRemove == 1 then
						resFrame.monitorTable.add{type = "button", name = "monitorRemoveButton"..i, caption = {"monitorRemoveButtonCaption"}, style = "smallerButtonFont"}
					end
				end
		elseif (opt.ShowResource == 1) then
			rootFrame.add{type = "label", name = "noSiteLabel", caption = {"noSiteLabel"}}
		end

		if (#global.resourceMonitor[player.index].oil > 0) and (opt.ShowOil == 1) then
			local span = 3 + opt.ShowRemove + opt.ShowType
			local oilFrame = rootFrame.add{type ="frame", name = "oilMonitorTable", caption = {"oil"}}
			oilFrame.add{type ="table", name = "oilMonitorTable", colspan = span}
				oilFrame.oilMonitorTable.add{type = "label", name = "oilSiteNameLabelHead", caption = {"siteNameLabel"}}
				if opt.ShowType == 1 then
					oilFrame.oilMonitorTable.add{type = "label", name = "oilSiteTypeLabelHead", caption = {"oilTypeLabel"}}
				end
				oilFrame.oilMonitorTable.add{type = "label", name = "oilSiteYieldLabelHead", caption = {"oilSiteYieldLabelHead"}}
				local oilSiteNumberLabelHeadCaption = 
				oilFrame.oilMonitorTable.add{type = "label", name = "oilSiteNumberLabelHead", caption = {"noOilWells"}}
				if opt.ShowRemove == 1 then
					oilFrame.oilMonitorTable.add{type = "label", name = "monitorDummy", caption = "  "}
				end
			for i,oilMonitor in ipairs(global.resourceMonitor[player.index].oil) do
				oilFrame.oilMonitorTable.add{type = "label", name = "oilSiteNameLabel"..i, caption = oilMonitor.name}
				if opt.ShowType == 1 then
					oilFrame.oilMonitorTable.add{type = "label", name = "oilSiteTypeLabel"..i, caption = game.get_localised_entity_name(oilMonitor.type)}
				end
				local tmpYield = 0
				for _,oilEnt in ipairs(oilMonitor.entity) do
					tmpYield = tmpYield + (oilEnt.amount / 750*10)
				end
				tmpYield = formatAmount(math.floor(tmpYield)) .."%"
				oilFrame.oilMonitorTable.add{type = "label", name = "oilSiteYieldLabel"..i, caption = "  " ..tmpYield}
				oilFrame.oilMonitorTable.add{type = "label", name = "oilSiteNumberLabel"..i, caption = "     " ..#oilMonitor.entity}
				if opt.ShowRemove == 1 then
					oilFrame.oilMonitorTable.add{type = "button", name = "oilMonitorRemoveButton"..i, caption = {"monitorRemoveButtonCaption"}, style = "smallerButtonFont"}
				end

			end
		elseif (opt.ShowOil == 1) then
			rootFrame.add{type = "label", name = "noOilLabel", caption = {"noOilLabel"}}
		end
		
	elseif global.resourceMonitor[player.index].flags.MonitorVisible == 2 then
		if player.gui.left.monitorFrame ~= nil then player.gui.left.monitorFrame.destroy() end
		if player.gui.left.resourceMonitorMinimized ~= nil then player.gui.left.resourceMonitorMinimized.destroy() end
		player.gui.left.add{type="button", name="resourceMonitorMinimized", caption="R"}
		player.gui.left.resourceMonitorMinimized.style.font_color = {r = 0, b = 0, g = 1}
	elseif global.resourceMonitor[player.index].flags.MonitorVisible == 0 then
		-- do nothing
	end
end


function addMonitor(startingPosition,resType,player)
	if global.resourceMonitor[player.index].flags.AdderVisible == 1 then
		player.print({"addingFrameIsAlreadyOpen"})
		return
	end
	if global.resourceMonitor[player.index].flags.SettingsVisible == 1 then
		player.print({"settingsFrameIsOpen"})
		return
	end

	local tmpResType = resType.name
	local tmpSurface = resType.surface
	local oreDeposit = getInitialResources(startingPosition, resType)
	local tmpAmount = 0 

	for _, tmpPos in ipairs(oreDeposit) do
		local tmpTile = tmpSurface.find_entities_filtered{area = {{tmpPos.x - 0.01, tmpPos.y - 0.01}, {tmpPos.x + 0.01, tmpPos.y + 0.01}}, name = resType.name}
		tmpAmount = tmpAmount + tmpTile[1].amount
		local overlay = tmpSurface.create_entity{name="rm_overlay", position = tmpPos}
			overlay.minable = false
			overlay.destructible = false
		if global.resourceMonitor[player.index].overlayStack == nil then global.resourceMonitor[player.index].overlayStack = {} end
		table.insert(global.resourceMonitor[player.index].overlayStack, overlay)
	end

	local tmpName = "Monitor" ..(#global.resourceMonitor[player.index].sites + 1)

	local rootAddingFrame = player.gui.left.add{type = "frame", name = "resourceMonitorAddingFrame", caption = {"addingFrameCaption"}, direction = "vertical"}
		rootAddingFrame.add{type ="table", name = "infoTable", colspan = 2}
			rootAddingFrame.infoTable.add{type = "label", name = "siteNameLabel", caption = {"siteNameLabel"}}
			rootAddingFrame.infoTable.add{type = "textfield", name = "siteNameText"}
				rootAddingFrame.infoTable.siteNameText.text = tmpName
				rootAddingFrame.infoTable.siteNameText.caption = tmpName
			rootAddingFrame.infoTable.add{type = "label", name = "resTypeLabel", caption = {"resTypeLabel"}}
			rootAddingFrame.infoTable.add{type = "label", name = "resTypeLabel2", caption = game.get_localised_entity_name(tmpResType)}
			rootAddingFrame.infoTable.add{type = "label", name = "resAmountLabel", caption = {"resAmountLabel"}}
			rootAddingFrame.infoTable.add{type = "label", name = "resAmountLabel2", caption = formatAmount(tmpAmount)}
		rootAddingFrame.add{type = "flow", name = "yesNoFlow", direction = "horizontal"}
			rootAddingFrame.yesNoFlow.add{type = "button", name = "addButton", caption = {"addButtonCaption"}}
			rootAddingFrame.yesNoFlow.add{type = "button", name = "cancelAddButton", caption = {"cancelButtonCaption"}}
		rootAddingFrame.add{type = "button", name = "newOreExistButton", caption = {"newExistButton"}}

	global.resourceMonitor[player.index].tmpSite.amount = tmpAmount
	global.resourceMonitor[player.index].tmpSite.resourceType = tmpResType
	global.resourceMonitor[player.index].tmpSite.surface = tmpSurface
	for _,k in ipairs(oreDeposit) do
		global.resourceMonitor[player.index].tmpSite.oreDeposits[#global.resourceMonitor[player.index].tmpSite.oreDeposits + 1]= {x = k.x, y = k.y}
	end
	global.resourceMonitor[player.index].flags.AdderVisible = 1
end


function oreAdderExpansion(player)
	if player.gui.left.resourceMonitorAddingFrame.addExistTable ~= nil then
		return
	end
	
	local existTable = player.gui.left.resourceMonitorAddingFrame.add{type = "table", name = "addExistTable", colspan = 3}
		existTable.add{type = "label", name = "oreSiteDummy1", caption = {"siteNameLabel"}}
		existTable.add{type = "label", name = "oreSiteDummy2", caption = {"resAmountLabel"}}
		existTable.add{type = "label", name = "oreSiteDummy3", caption = " "}
	for i,oreMonitor in ipairs(global.resourceMonitor[player.index].sites) do
		if oreMonitor.resourceType == global.resourceMonitor[player.index].tmpSite.resourceType then
			existTable.add{type = "label", name = "oreSiteNameLabel1"..i, caption = oreMonitor.name}
			if type(oreMonitor.amount) == type(42) then
				existTable.add{type = "label", name = "oreSiteNameLabel2"..i, caption = formatAmount(oreMonitor.amount)}
			else
				existTable.add{type = "label", name = "oreSiteNameLabel2"..i, caption = oreMonitor.amount}
			end
			existTable.add{type = "button", name = "oreAddExistButton"..i, caption = {"addButtonCaption"}, style = "smallerButtonFont"}
		end
	end
end


function oilAdder(oilEntity,player)
	if global.resourceMonitor[player.index].flags.AdderVisible == 1 then
		player.print({"addingFrameIsAlreadyOpen"})
		return
	end
	if global.resourceMonitor[player.index].flags.SettingsVisible == 1 then
		player.print({"settingsFrameIsOpen"})
		return
	end

	local tmpAmount = oilEntity.amount
	local tmpName = 0
	local tmpSurface = oilEntity.surface
	if global.resourceMonitor[player.index].oil == nil then
		tmpName = "Liquid-Monitor1"
	else
		tmpName = "Liquid-Monitor" ..(#global.resourceMonitor[player.index].oil + 1)
	end

	local rootOilAddingFrame = player.gui.left.add{type = "frame", name = "oilMonitorAddingFrame", caption = {"addingFrameCaption"}, direction = "vertical"}
		rootOilAddingFrame.add{type ="table", name = "infoTable", colspan = 2}
			rootOilAddingFrame.infoTable.add{type = "label", name = "siteNameLabel", caption = {"siteNameLabel"}}
			rootOilAddingFrame.infoTable.add{type = "textfield", name = "siteNameText"}
				rootOilAddingFrame.infoTable.siteNameText.text = tmpName
				rootOilAddingFrame.infoTable.siteNameText.caption = tmpName
			rootOilAddingFrame.infoTable.add{type = "label", name = "oilTypeLabel", caption = {"oilTypeLabel"}}
			rootOilAddingFrame.infoTable.add{type = "label", name = "oilTypeLabel2", caption = game.get_localised_entity_name(oilEntity.name)}
			rootOilAddingFrame.infoTable.add{type = "label", name = "oilYieldLabel", caption = {"oilYieldLabel"}}
			rootOilAddingFrame.infoTable.add{type = "label", name = "oilYieldLabel2", caption = formatAmount(math.floor(tmpAmount / 750*10)).."%"} -- 750 == min amount
			rootOilAddingFrame.infoTable.add{type = "label", name = "oilAmountLabel", caption = {"oilAmountLabel"}}
			rootOilAddingFrame.infoTable.add{type = "label", name = "oilAmountLabel2", caption = formatAmount(tmpAmount)}
		rootOilAddingFrame.add{type = "table", name = "yesNoFlow", colspan = 2}
			rootOilAddingFrame.yesNoFlow.add{type = "button", name = "newOilAddButton", caption = {"addNewOilButtonCaption"}}
			rootOilAddingFrame.yesNoFlow.add{type = "button", name = "oilCancelAddButton", caption = {"cancelButtonCaption"}}
		rootOilAddingFrame.add{type = "button", name = "newOilExistButton", caption = {"newExistButton"}}

	global.resourceMonitor[player.index].tmpOil = oilEntity
	global.resourceMonitor[player.index].flags.AdderVisible = 1
end


function oilAdderExpansion(player)
	local existTable = player.gui.left.oilMonitorAddingFrame.add{type = "table", name = "addExistTable", colspan = 3}
		existTable.add{type = "label", name = "oilSiteDummy1", caption = {"siteNameLabel"}}
		existTable.add{type = "label", name = "oilSiteDummy2", caption = {"noOilWells"}}
		existTable.add{type = "label", name = "oilSiteDummy3", caption = " "}
	for i,oilMonitor in ipairs(global.resourceMonitor[player.index].oil) do
		if oilMonitor.type == global.resourceMonitor[player.index].tmpOil.name then
			existTable.add{type = "label", name = "oilSiteNameLabel1"..i, caption = oilMonitor.name}
			existTable.add{type = "label", name = "oilSiteNameLabel2"..i, caption = "      "..#oilMonitor.entity}
			existTable.add{type = "button", name = "oilAddExistButton"..i, caption = {"addButtonCaption"}, style = "smallerButtonFont"}
		end
	end
end


function showSettingsGUI(player)
	local rootSettingsFrame = player.gui.left.add{type = "frame", name = "settingsFrame", caption = {"settingsCaption"}, direction = "vertical"}
			rootSettingsFrame.add{type ="table", name = "settingsTable", colspan = 2}
				rootSettingsFrame.settingsTable.add{type = "label", name = "showTypeLabel", caption = {"showTypeLabel"}}
				rootSettingsFrame.settingsTable.add{type = "checkbox", name = "showTypeBox", state = global.resourceMonitor[player.index].flags.ShowType}
				rootSettingsFrame.settingsTable.add{type = "label", name = "showAmountLabel", caption = {"showAmountLabel"}}
				rootSettingsFrame.settingsTable.add{type = "checkbox", name = "showAmountBox", state = global.resourceMonitor[player.index].flags.ShowAmount}
				rootSettingsFrame.settingsTable.add{type = "label", name = "showRemoveLabel", caption = {"showRemoveLabel"}}
				rootSettingsFrame.settingsTable.add{type = "checkbox", name = "showRemoveBox", state = global.resourceMonitor[player.index].flags.ShowRemove}
				rootSettingsFrame.settingsTable.add{type = "label", name = "showDeltaLabel", caption = {"showDeltaLabel"}}
				rootSettingsFrame.settingsTable.add{type = "checkbox", name = "showDeltaBox", state = global.resourceMonitor[player.index].flags.ShowDelta}
				rootSettingsFrame.settingsTable.add{type = "label", name = "showNotificationLabel2", caption = {"showNotificationLabel2"}}
				rootSettingsFrame.settingsTable.add{type = "checkbox", name = "showNotificationBox2", state = global.resourceMonitor[player.index].flags.ShowNotification2}
				rootSettingsFrame.settingsTable.add{type = "label", name = "showNotificationLabel", caption = {"showNotificationLabel"}}
				rootSettingsFrame.settingsTable.add{type = "checkbox", name = "showNotificationBox", state = global.resourceMonitor[player.index].flags.ShowNotification}

			rootSettingsFrame.add{type = "frame", name = "settingsUpdateFrame", direction = "horizontal", caption = {"settingsUpdateTableCaption"}}
				rootSettingsFrame.settingsUpdateFrame.add{type ="table", name = "settingsUpdateTable", colspan = 2}
					rootSettingsFrame.settingsUpdateFrame.settingsUpdateTable.add{type = "label", name = "updateLabel1", caption = {"updateLabel1"}}
					rootSettingsFrame.settingsUpdateFrame.settingsUpdateTable.add{type = "checkbox", name = "updateBox1", state = (global.resourceMonitor[player.index].flags.updateFreq == 600)}
					rootSettingsFrame.settingsUpdateFrame.settingsUpdateTable.add{type = "label", name = "updateLabel2", caption = {"updateLabel2"}}
					rootSettingsFrame.settingsUpdateFrame.settingsUpdateTable.add{type = "checkbox", name = "updateBox2", state = (global.resourceMonitor[player.index].flags.updateFreq == 1800)}
					rootSettingsFrame.settingsUpdateFrame.settingsUpdateTable.add{type = "label", name = "updateLabel3", caption = {"updateLabel3"}}
					rootSettingsFrame.settingsUpdateFrame.settingsUpdateTable.add{type = "checkbox", name = "updateBox3", state = (global.resourceMonitor[player.index].flags.updateFreq == 3600)}

			rootSettingsFrame.add{type = "flow", name = "settingsFlow", direction = "horizontal"}
				rootSettingsFrame.settingsFlow.add{type = "button", name = "settingsYesButton", caption = {"settingsYesButton"}}
				rootSettingsFrame.settingsFlow.add{type = "button", name = "settingsCancelButton", caption = {"settingsCancelButton"}}
end


function getInitialResources(startPos, resType)
	local listA = {}
	local listB = {}
	local tmpPos = {x = math.floor(startPos.x) + 0.5, y = math.floor(startPos.y) + 0.5}
	local completeAmount = 0
	local tmpEntry = {}
	
	table.insert(listA, {x =tmpPos.x, y = tmpPos.y})

	while (#listA > 0) do
		tmpEntry = {x = listA[#listA].x, y = listA[#listA].y}
		table.remove(listA)
		table.insert(listB, tmpEntry)
		if checkTile({x = tmpEntry.x, y = tmpEntry.y - 1}, resType, listA, listB) == true then
			table.insert(listA, {x = tmpEntry.x, y = tmpEntry.y - 1})
		end
		if checkTile({x = tmpEntry.x, y = tmpEntry.y + 1}, resType, listA, listB) == true then
			table.insert(listA, {x = tmpEntry.x, y = tmpEntry.y + 1})
		end
		if checkTile({x = tmpEntry.x - 1, y = tmpEntry.y}, resType, listA, listB) == true then
			table.insert(listA, {x = tmpEntry.x - 1, y = tmpEntry.y})
		end
		if checkTile({x = tmpEntry.x + 1, y = tmpEntry.y}, resType, listA, listB) == true then
			table.insert(listA, {x = tmpEntry.x + 1, y = tmpEntry.y})
		end
		if checkTile({x = tmpEntry.x + 1, y = tmpEntry.y + 1}, resType, listA, listB) == true then
			table.insert(listA, {x = tmpEntry.x + 1, y = tmpEntry.y + 1})
		end
		if checkTile({x = tmpEntry.x - 1, y = tmpEntry.y - 1}, resType, listA, listB) == true then
			table.insert(listA, {x = tmpEntry.x - 1, y = tmpEntry.y - 1})
		end
		if checkTile({x = tmpEntry.x + 1, y = tmpEntry.y - 1}, resType, listA, listB) == true then
			table.insert(listA, {x = tmpEntry.x + 1, y = tmpEntry.y - 1})
		end
		if checkTile({x = tmpEntry.x - 1, y = tmpEntry.y + 1}, resType, listA, listB) == true then
			table.insert(listA, {x = tmpEntry.x - 1, y = tmpEntry.y + 1})
		end
	end

	return listB
end


function checkTile(pos, resType , listA, listB)
	local tmpTile = resType.surface.find_entities_filtered{area = {{pos.x - 0.01, pos.y - 0.01}, {pos.x + 0.01, pos.y + 0.01}}, name = resType.name}
	if tmpTile[1] ~= nil then
		if not inList(pos, listA) and not inList(pos, listB) then
			return true
		else
			return false
		end
	else
		return false
	end
end


function inList(pos, list)
	for _, listTile in ipairs(list) do
		if (listTile.x == pos.x) and (listTile.y == pos.y) then
			return true
		end
	end
	return false
end


function isInSolidList(resourcecategory,player)
	for _, category in ipairs (global.resourceMonitor[player.index].resourceSolidList) do
		if resourcecategory == category then
			return true
		end
	end
	return false
end

function isInLiquidList(resourcecategory)
	for _, category in ipairs (global.resourceMonitor[player.index].resourceLiquidList) do
		if resourcecategory == category then
			return true
		end
	end
	return false
end

function formatAmount(amount)
	local tmp = amount
	local result = ""
	while (string.len(tmp) > 3) do
		result = "." ..string.sub(tmp, -3) .. result
		tmp = math.floor(tmp / 1000)
	end

	if tmp ~= 0 then
		result = tmp .. result
	end
	return result
end


function startingItems(player)
	player.insert{name="iron-plate", count=8}
	player.insert{name="basic-bullet-magazine", count=100}
	player.insert{name="wooden-chest", count=64}
	player.insert{name="small-electric-pole", count=32}
	player.insert{name="basic-inserter", count=64}
	player.insert{name="solar-panel", count=54}
	player.insert{name="basic-transport-belt", count=128}
	player.insert{name="steam-engine", count=16}
	player.insert{name="boiler", count=32}
	player.insert{name="pipe", count=64}
	player.insert{name="basic-mining-drill", count=32}
	player.insert{name="basic-transport-belt-to-ground", count=32}
	player.insert{name="pipe-to-ground", count=32}
	player.insert{name="basic-splitter", count=32}
	player.insert{name="straight-rail", count=32}
	player.insert{name="curved-rail", count=32}
	player.insert{name="raw-wood", count=128}
	player.insert{name="car", count=1}
	player.insert{name="stone", count=256}
	player.insert{name="offshore-pump", count=8}
	player.insert{name="poison-capsule", count=8}
	player.insert{name="resource-monitor", count=2}

	player.force.technologies["resource-monitoring"].researched = true
end

remote.add_interface("resource-monitor-mod",
{
	addResource = function(newCategory, type)
		if type == "solid" then
			for _, category in ipairs (global.resourceMonitor[player.index].resourceSolidList) do
				if category == newCategory then
					return false
				end
			end
			table.insert(global.resourceMonitor[player.index].resourceSolidList, newCategory)
			return true
		elseif type == "liquid" then
			for _, category in ipairs (global.resourceMonitor[player.index].resourceLiquidList) do
				if category == newCategory then
					return false
				end
			end
			table.insert(global.resourceMonitor[player.index].resourceLiquidList, newCategory)
			return true
		else
			return false
		end
	end,

	resetGUI = function(playername)
		if playername == nil then
			for _,player in ipairs(game.players) do
				global.resourceMonitor[player.index].flags.MonitorVisible = 0
				global.resourceMonitor[player.index].flags.AdderVisible = 0
				global.resourceMonitor[player.index].flags.SettingsVisible = 0

				if player.gui.left.monitorFrame ~= nil then
					player.gui.left.monitorFrame.destroy()
				end

				if player.gui.left.rootAddingFrame ~= nil then
					player.gui.left.rootAddingFrame.destroy()
				end

				if player.gui.left.rootOilAddingFrame ~= nil then
					player.gui.left.rootOilAddingFrame.destroy()
				end

				if player.gui.left.rootSettingsFrame ~= nil then
					player.gui.left.rootSettingsFrame.destroy()
				end
			end
		else
		local player = game.get_player_by_name(name)
			if player ~= nil then
				global.resourceMonitor[player.index].flags.MonitorVisible = 0
				global.resourceMonitor[player.index].flags.AdderVisible = 0
				global.resourceMonitor[player.index].flags.SettingsVisible = 0

				if player.gui.left.monitorFrame ~= nil then
					player.gui.left.monitorFrame.destroy()
				end

				if player.gui.left.rootAddingFrame ~= nil then
					player.gui.left.rootAddingFrame.destroy()
				end

				if player.gui.left.rootOilAddingFrame ~= nil then
					player.gui.left.rootOilAddingFrame.destroy()
				end

				if player.gui.left.rootSettingsFrame ~= nil then
					player.gui.left.rootSettingsFrame.destroy()
				end
			end
		end
	end
})
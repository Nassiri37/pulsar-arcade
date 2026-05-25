local ox_inventory = exports.ox_inventory

local function getSid(source)
	local char = exports["pulsar-characters"]:FetchCharacterSource(source)
	if not char then
		return nil
	end
	return char:GetData("SID")
end

function ArcadeStripInventory(source)
	if Player(source).state.arcadeInvStripped then
		return true
	end
	ox_inventory:ConfiscateInventory(source)
	Player(source).state:set("arcadeInvStripped", true, true)
	return true
end



local function clearArcadeLoadout(source)
	for _, entry in ipairs(ARCADE_LOADOUT) do
		local count = ox_inventory:GetItemCount(source, entry.name) or 0
		if count > 0 then
			ox_inventory:RemoveItem(source, entry.name, count)
		end
	end
end



local function equipArcadeWeapon(source, itemName, metadata)
	local slot = ox_inventory:GetSlotWithItem(source, itemName)
	if not slot then
		return false
	end

	local sid = getSid(source)

	TriggerClientEvent("Weapons:Client:Use", source, {
		Name = itemName,
		Slot = slot.slot,
		Count = slot.count or 1,
		MetaData = slot.metadata or metadata or {},
		Owner = sid and tostring(sid) or tostring(source),
		invType = 1,
	})
	return true
end

function ArcadeRestoreInventory(source)
	if not Player(source).state.arcadeInvStripped then
		return true
	end
	clearArcadeLoadout(source)
	ox_inventory:ReturnInventory(source)
	Player(source).state:set("arcadeInvStripped", false, true)
	return true
end



function ArcadeGiveLoadout(source)
	for _, entry in ipairs(ARCADE_LOADOUT) do
		local metadata = entry.metadata or {}
		if not equipArcadeWeapon(source, entry.name, metadata) then
			local added = ox_inventory:AddItem(source, entry.name, entry.count or 1, metadata)
			if not added then
				return false
			end
			SetTimeout(150, function()
				equipArcadeWeapon(source, entry.name, metadata)
			end)
		end
	end
	return true
end



function ArcadeInventoryHas(source, itemName, count)
	count = count or 1
	return (ox_inventory:GetItemCount(source, itemName) or 0) >= count
end



function ArcadeInventoryGrantLoot(source, lootTable)
	local sid = getSid(source)
	if not sid or type(lootTable) ~= "table" then
		return false
	end
	return ox_inventory:LootCustomSetWithCount(lootTable, sid, 1) == true
end



exports("StripInventory", ArcadeStripInventory)
exports("RestoreInventory", ArcadeRestoreInventory)
exports("GiveLoadout", ArcadeGiveLoadout)
exports("InventoryHas", ArcadeInventoryHas)
exports("InventoryGrantLoot", ArcadeInventoryGrantLoot)



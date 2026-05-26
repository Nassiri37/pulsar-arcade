local ox_inventory = exports.ox_inventory

local STRIP_STATE_KEY = "arcadeInvStrippedSid"

local function getSid(source)
	local char = exports["pulsar-characters"]:FetchCharacterSource(source)
	if not char then
		return nil
	end
	return tostring(char:GetData("SID"))
end

local function getStrippedSid(source)
	local sid = Player(source).state[STRIP_STATE_KEY]
	if sid == nil or sid == false or sid == "" then
		return nil
	end
	return tostring(sid)
end

local function setStrippedSid(source, sid)
	Player(source).state:set(STRIP_STATE_KEY, sid and tostring(sid) or nil, true)
end

local function tryReturnConfiscated(source)
	ox_inventory:ReturnInventory(source)
	return true
end

function ArcadeStripInventory(source)
	local sid = getSid(source)
	if not sid then
		return false
	end

	local strippedSid = getStrippedSid(source)
	if strippedSid == sid then
		return true
	end

	if strippedSid and strippedSid ~= sid then
		exports["pulsar-core"]:LoggerWarn(
			"Arcade",
			("Replacing arcade strip flag %s -> %s for source %s"):format(strippedSid, sid, source),
			{ console = true }
		)
	end

	ox_inventory:ConfiscateInventory(source)
	setStrippedSid(source, sid)
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
		Owner = sid or tostring(source),
		invType = 1,
	})
	return true
end

function ArcadeRestoreInventory(source)
	local sid = getSid(source)
	if not sid then
		return false
	end

	local strippedSid = getStrippedSid(source)
	if strippedSid and strippedSid ~= sid then
		exports["pulsar-core"]:LoggerWarn(
			"Arcade",
			("Skip restore for SID %s — strip flag is for SID %s (source %s)"):format(sid, strippedSid, source),
			{ console = true }
		)
		setStrippedSid(source, nil)
		return false
	end

	clearArcadeLoadout(source)

	if strippedSid == sid then
		tryReturnConfiscated(source)
		setStrippedSid(source, nil)
		return true
	end

	-- No flag (crash / disconnect): still attempt return; ox no-ops if no stash exists.
	tryReturnConfiscated(source)
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
				if GetPlayerPing(source) > 0 then
					equipArcadeWeapon(source, entry.name, metadata)
				end
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

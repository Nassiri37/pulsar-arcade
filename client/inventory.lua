
function ArcadeClientHasItem(itemName, count)
	count = count or 1
	local ok, result = pcall(function()
		return exports.ox_inventory:ItemsHas(itemName, count)
	end)

	return ok and result == true
end

exports("HasItem", ArcadeClientHasItem)

--!strict
-- ShopItems.luau
-- Catalogue of trail cosmetics purchasable with coins. Shared so the server
-- (ShopService validates purchases, builds trails) and the client (shop UI)
-- render exactly the same items and prices.

export type Item = {
	id: string,
	name: string,
	price: number,
	-- Trail colour, start -> end. Single-colour trails repeat the same colour.
	colors: { Color3 },
}

local ShopItems: { Item } = {
	{
		id = "crimson",
		name = "Crimson Streak",
		price = 50,
		colors = { Color3.fromRGB(230, 40, 40), Color3.fromRGB(120, 10, 10) },
	},
	{
		id = "ocean",
		name = "Ocean Wave",
		price = 75,
		colors = { Color3.fromRGB(50, 130, 255), Color3.fromRGB(160, 230, 255) },
	},
	{
		id = "emerald",
		name = "Emerald Rush",
		price = 100,
		colors = { Color3.fromRGB(50, 220, 100), Color3.fromRGB(10, 100, 40) },
	},
	{
		id = "sunburst",
		name = "Sunburst",
		price = 150,
		colors = { Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 100, 20) },
	},
	{
		id = "violet",
		name = "Violet Storm",
		price = 250,
		colors = { Color3.fromRGB(170, 60, 255), Color3.fromRGB(60, 20, 120) },
	},
	{
		id = "rainbow",
		name = "Rainbow Blaze",
		price = 500,
		colors = {
			Color3.fromRGB(255, 60, 60),
			Color3.fromRGB(255, 200, 40),
			Color3.fromRGB(60, 220, 90),
			Color3.fromRGB(60, 130, 255),
			Color3.fromRGB(170, 60, 255),
		},
	},
}

-- id -> item lookup.
local byId: { [string]: Item } = {}
for _, item in ShopItems do
	byId[item.id] = item
end

return {
	list = ShopItems,
	byId = byId,
}

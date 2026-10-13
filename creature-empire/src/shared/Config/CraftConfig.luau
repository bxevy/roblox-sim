--!strict
-- Crafting recipes (at the Trading Post).

export type Craft = {
	Id: string,
	Name: string,
	Inputs: { [string]: number },
	Output: string,
	Amount: number,
	Phase: number,
}

local CraftConfig: { [string]: Craft } = {
	EmberLure = {
		Id = "EmberLure",
		Name = "Ember Lure",
		Inputs = { Emberstone = 5, Moonpetal = 10 },
		Output = "EmberLure",
		Amount = 1,
		Phase = 3,
	},
}

return CraftConfig

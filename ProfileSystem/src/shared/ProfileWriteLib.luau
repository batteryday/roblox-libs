--!strict
--[[
	ProfileWriteLib — Replica WriteLib for player profile mutations.

	Lives under ReplicatedStorage.Shared so both server and client can reference it.
	Functions receive (replica, ...) and ONLY use replica methods to mutate data.
	The replica's .Data IS the same table as profile.Data on the server, so
	mutations through replica:Set() etc. update both sides automatically.

	SETUP: Add your game-specific mutation functions below. Example:

		function WriteLib.AddGold(replica: Replica, amount: number): ()
			replica:Set({ "Gold" }, replica.Data.Gold + amount)
		end

	Functions are sorted alphabetically by Replica internally — the order here
	doesn't matter, but we keep them alphabetical for readability.
--]]

type Replica = any -- Replica library doesn't export types

local WriteLib = {}

-- Add your game-specific mutations here.

return WriteLib

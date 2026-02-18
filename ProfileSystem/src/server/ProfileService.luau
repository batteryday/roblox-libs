--!strict
--[[
	ProfileService — server-only player data management.

	Loads player profiles via ProfileStore, creates a Replica per player so the
	client can read profile data, and exposes a clean API for other server modules.

	API:
		ProfileService.GetProfile(player)         → ProfileWrapper?
		ProfileService.WaitForProfile(player)     → ProfileWrapper?  (yields)
		ProfileService.GetProfileByUserId(userId) → ProfileWrapper?

	ProfileWrapper shape:
		.Data     — the saved player data
		.temp     — transient per-session state
		.replica  — the Replica object for this profile
		.profile  — the raw ProfileStore profile (for advanced use)

	SETUP:
		1. Create a ProfileTemplate.luau in ReplicatedStorage.Shared that returns your data schema table.
		2. Create a ProfileWriteLib.luau in ReplicatedStorage.Shared with your mutations.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ProfileStore)
local Replica = require(ServerScriptService.Replica)
local Signal = require(ReplicatedStorage.Packages.signal)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WriteLibModule = Shared:WaitForChild("ProfileWriteLib")

---------------------------------------------------------------------------
-- Profile template — provided by the project via Shared.ProfileTemplate.
-- New players get this data. Reconcile fills missing keys for existing players.
---------------------------------------------------------------------------
local PROFILE_TEMPLATE = require(Shared:WaitForChild("ProfileTemplate"))

---------------------------------------------------------------------------
-- Types
---------------------------------------------------------------------------
export type ProfileWrapper = {
	Data: typeof(PROFILE_TEMPLATE),
	temp: { [string]: any },
	replica: any, -- Replica object
	profile: any, -- Raw ProfileStore profile
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local PlayerStore = ProfileStore.New("PlayerStore", PROFILE_TEMPLATE)
local ProfileToken = Replica.Token("PlayerProfile")

local Profiles: { [Player]: ProfileWrapper } = {}
local ProfilesByUserId: { [number]: ProfileWrapper } = {}
local ProfileReadySignals: { [Player]: any } = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function getOrCreateReadySignal(player: Player): any
	local sig = ProfileReadySignals[player]
	if not sig then
		sig = Signal.new()
		ProfileReadySignals[player] = sig
	end
	return sig
end

local function cleanupPlayer(player: Player)
	local sig = ProfileReadySignals[player]
	if sig then
		sig:Destroy()
		ProfileReadySignals[player] = nil
	end
end

---------------------------------------------------------------------------
-- Player lifecycle
---------------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		player:Kick("Profile load failed — please rejoin.")
		cleanupPlayer(player)
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	-- If the player left while we were loading, release immediately
	if player.Parent ~= Players then
		profile:EndSession()
		cleanupPlayer(player)
		return
	end

	-- Create Replica — its .Data IS the same table as profile.Data
	local replica = Replica.New({
		Token = ProfileToken,
		Tags = { UserId = player.UserId },
		Data = profile.Data,
		WriteLib = WriteLibModule,
	})

	-- Wait for the player to be "ready" in Replica (client calls RequestData first)
	if not Replica.ReadyPlayers[player] then
		while player.Parent == Players and not Replica.ReadyPlayers[player] do
			Replica.NewReadyPlayer:Wait()
		end
		if player.Parent ~= Players then
			replica:Destroy()
			profile:EndSession()
			cleanupPlayer(player)
			return
		end
	end

	replica:Subscribe(player)

	-- Build the wrapper that other systems use
	local wrapper: ProfileWrapper = {
		Data = profile.Data,
		temp = {},
		replica = replica,
		profile = profile,
	}

	Profiles[player] = wrapper
	ProfilesByUserId[player.UserId] = wrapper

	-- Handle unexpected session end (e.g. another server stealing the lock)
	profile.OnSessionEnd:Connect(function()
		local w = Profiles[player]
		if w then
			Profiles[player] = nil
			ProfilesByUserId[player.UserId] = nil
			if w.replica then
				w.replica:Destroy()
			end
		end
		player:Kick("Profile session ended — please rejoin.")
	end)

	-- Fire the ready signal for anyone waiting via WaitForProfile
	local sig = ProfileReadySignals[player]
	if sig then
		sig:Fire(wrapper)
		sig:Destroy()
		ProfileReadySignals[player] = nil
	end
end

local function onPlayerRemoving(player: Player)
	local wrapper = Profiles[player]
	if wrapper then
		Profiles[player] = nil
		ProfilesByUserId[player.UserId] = nil

		if wrapper.replica then
			wrapper.replica:Destroy()
			wrapper.replica = nil
		end

		wrapper.profile:EndSession()
	end

	cleanupPlayer(player)
end

---------------------------------------------------------------------------
-- Bootstrap
---------------------------------------------------------------------------
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------
local ProfileService = {}

function ProfileService.GetProfile(player: Player): ProfileWrapper?
	return Profiles[player]
end

function ProfileService.WaitForProfile(player: Player): ProfileWrapper?
	if player.Parent ~= Players then
		return nil
	end

	local existing = Profiles[player]
	if existing then
		return existing
	end

	-- Wait for the ready signal
	return getOrCreateReadySignal(player):Wait()
end

function ProfileService.GetProfileByUserId(userId: number): ProfileWrapper?
	return ProfilesByUserId[userId]
end

return ProfileService

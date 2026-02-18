--!strict
--[[
	PlayerProfiles — shared bridge for profile access.

	Works on both server and client via RunService:IsServer() branching.

	Server API:
		PlayerProfiles.GetProfile(player: Player): ProfileWrapper?
		PlayerProfiles.WaitForProfile(player: Player): ProfileWrapper?  (yields)
		PlayerProfiles.GetProfileByUserId(userId: number): ProfileWrapper?

	Client API:
		PlayerProfiles.GetLocalProfile(): Replica?
		PlayerProfiles.WaitForLocalProfile(): Replica  (yields)

	On the client, the "profile" is the raw Replica object. It has:
		.Data      — read-only view of the player's saved data
		.Tags      — { UserId = number }
		:OnSet()   — listen for specific field changes
		:OnWrite() — listen for WriteLib function calls
		:OnChange()— listen for any data change
		:Write()   — invoke a WriteLib function (client → server)
--]]

local RunService = game:GetService("RunService")

local PlayerProfiles: { [string]: any } = {}

if RunService:IsServer() then
	---------------------------------------------------------------------------
	-- SERVER
	---------------------------------------------------------------------------
	local ServerScriptService = game:GetService("ServerScriptService")
	local ProfileService = require(ServerScriptService.ProfileService)

	function PlayerProfiles.GetProfile(player: Player): any?
		return ProfileService.GetProfile(player)
	end

	function PlayerProfiles.WaitForProfile(player: Player): any?
		return ProfileService.WaitForProfile(player)
	end

	function PlayerProfiles.GetProfileByUserId(userId: number): any?
		return ProfileService.GetProfileByUserId(userId)
	end
else
	---------------------------------------------------------------------------
	-- CLIENT
	---------------------------------------------------------------------------
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local Signal = require(ReplicatedStorage.Packages.signal)
	local ReplicaClient = require(ReplicatedStorage.ReplicaClient)

	local LocalPlayer = Players.LocalPlayer
	local localReplica: any = nil
	local replicaReadySignal = Signal.new()
	local isReady = false

	-- Request data from the server and listen for our profile replica
	ReplicaClient.RequestData()
	ReplicaClient.OnNew("PlayerProfile", function(replica: any)
		if replica.Tags.UserId == LocalPlayer.UserId then
			localReplica = replica
			isReady = true
			replicaReadySignal:Fire(replica)
		end
	end)

	function PlayerProfiles.GetLocalProfile(): any?
		return localReplica
	end

	function PlayerProfiles.WaitForLocalProfile(): any
		if localReplica then
			return localReplica
		end
		return replicaReadySignal:Wait()
	end
end

return PlayerProfiles

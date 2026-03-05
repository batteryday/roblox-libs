--!strict

--[[
	ServiceLoader — Lightweight two-phase module initialization.

	Each module may export an optional Init() and Start() method:
	  - Init(): Set up internal state, create Net events, register tags.
	            No dependencies on other modules being ready.
	  - Start(): Connect to player lifecycle, begin game logic, access
	             other modules. All modules have been Init'd by this point.

	Modules that return `true` (legacy) are silently skipped.
]]

export type Module = {
	Init: ((loaded: { [string]: any }) -> ())?,
	Start: ((loaded: { [string]: any }) -> ())?,
	[string]: any,
}

local ServiceLoader = {}

function ServiceLoader.loadAll(modules: { [string]: ModuleScript }): { [string]: Module }
	local loaded: { [string]: Module } = {}

	-- Phase 1: Require all modules
	for name: string, moduleScript: ModuleScript in modules do
		local result: any = require(moduleScript)
		if typeof(result) == "table" then
			loaded[name] = result
		end
	end

	-- Phase 2: Init all (set up state, no cross-module deps)
	for _name: string, mod: Module in loaded do
		if mod.Init then
			mod.Init(loaded)
		end
	end

	-- Phase 3: Start all (begin game logic, cross-module access safe)
	for _name: string, mod: Module in loaded do
		if mod.Start then
			mod.Start(loaded)
		end
	end

	return loaded
end

return ServiceLoader

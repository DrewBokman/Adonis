return function(Vargs)
	local Server = Vargs.Server
	local Service = Vargs.Service

	local Variables = Server.Variables
	local Commands = Server.Commands

	local Settings = Server.Settings
	local Anti = Server.Anti
	local Functions = Server.Functions
	local Logs = Server.Logs
	local Remote = Server.Remote
	local Admin = Server.Admin
	local Core = Server.Core

	local ReflectionService = Service.ReflectionService
	local APIDump = nil
	local ServerNewDex = {}

	local newDex_main = script:WaitForChild("Dex_Client", 120)
	local Event = ServerNewDex.Event

	if not newDex_main then
		warn("New Dex unable to be located?")
	else
		newDex_main = newDex_main:Clone()
		for _, BaseScript in ipairs(newDex_main:GetDescendants()) do
			if BaseScript.ClassName == "LocalScript" then
				BaseScript.Disabled = false
			end
		end
	end

	-- Generate API data from ReflectionService
	local function GenerateAPIDataFromReflection()
		print("[SERVER] Starting API data generation from ReflectionService...")

		-- Get all classes (no security filter needed on server)
		local classesData = ReflectionService:GetClasses()

		-- Build API structure with class data and properties
		local apiData = {
			Classes = {},
			ClassProperties = {}, -- Store properties separately for efficiency
		}

		-- Build a map of parent class properties to filter out inherited ones
		local classPropertyMap = {}

		-- Process classes
		for _, classInfo in ipairs(classesData) do
			local className = classInfo.Name

			-- Store class metadata (convert tags to plain table)
			local tags = {}
			if classInfo.Tags then
				for _, tag in ipairs(classInfo.Tags) do
					table.insert(tags, tostring(tag))
				end
			end

			-- Get icon index if available (for Explorer tree icons)
			local iconIndex = 0
			if classInfo.Display and classInfo.Display.Icon then
				iconIndex = classInfo.Display.Icon
			end

			-- Debug first class
			if className == "Accessory" or className == "Part" then
				print("[SERVER DEBUG]", className, "has Display:", classInfo.Display ~= nil)
				if classInfo.Display then
					print("[SERVER DEBUG]", className, "Icon:", classInfo.Display.Icon)
				end
			end

			table.insert(apiData.Classes, {
				Name = className,
				Superclass = classInfo.Superclass,
				Tags = tags,
				ExplorerImageIndex = iconIndex,
			})

			-- Get and store properties for this class
			local propertiesData = ReflectionService:GetPropertiesOfClass(className)
			local serializedProps = {}

			local totalProps = #propertiesData
			local includedProps = 0

			for i, prop in ipairs(propertiesData) do
				-- Only include properties defined directly on this class (not inherited)
				-- This prevents duplicates when traversing the class hierarchy
				local definingClass = prop.DefiningClass

				-- Debug for Part class
				if className == "Part" and i <= 3 then
					print("[SERVER DEBUG] Part property:", prop.Name, "DefiningClass:", definingClass)
				end

				if definingClass == className then
					includedProps = includedProps + 1
					-- Convert property userdata to plain table
					local serializedProp = {
						Name = prop.Name,
						Category = (prop.Display and prop.Display.Category) or "Data",
						ReadSecurity = (prop.Permits and tostring(prop.Permits.Read)) or "None",
						WriteSecurity = (prop.Permits and tostring(prop.Permits.Write)) or "None",
						Serialization = {
							CanSave = prop.Serialized or false,
							CanLoad = prop.Serialized or false,
						},
						Tags = {},
					}

					-- Convert tags
					if prop.Tags then
						for _, tag in ipairs(prop.Tags) do
							table.insert(serializedProp.Tags, tostring(tag))
						end
					end

					-- Convert ValueType
					if prop.Type then
						local valueTypeName = prop.Type.ScriptType or prop.Type.EngineType
						local valueTypeCategory = "Primitive"

						-- Create ValueType table
						if valueTypeName then
							serializedProp.ValueType = {
								Name = valueTypeName,
								Category = valueTypeCategory,
							}
						end
					end

					table.insert(serializedProps, serializedProp)
				end
			end

			-- Debug property filtering for Part
			if className == "Part" then
				print("[SERVER DEBUG] Part: included", includedProps, "out of", totalProps, "total properties")
			end

			apiData.ClassProperties[className] = serializedProps
		end

		print("[SERVER] API data generation complete. Classes:", #apiData.Classes)
		return apiData
	end

	task.delay(0.25, function() -- Load Dex instance data asynchronously
		-- Use ReflectionService to generate API data
		local reflectionSuccess, errorMsg = pcall(function()
			APIDump = GenerateAPIDataFromReflection()
		end)

		if reflectionSuccess and APIDump then
			print("[SERVER] Successfully generated API data:", #APIDump.Classes, "classes")

			-- Debug: Check first class with properties
			if APIDump.Classes[1] then
				local firstClass = APIDump.Classes[1]
				local props = APIDump.ClassProperties[firstClass.Name]
				print("[SERVER] First class:", firstClass.Name, "with", props and #props or 0, "properties")

				if props and #props > 0 then
					local firstProp = props[1]
					print(
						"[SERVER] First property:",
						tostring(firstProp.Name),
						"ValueType:",
						tostring(firstProp.ValueType and firstProp.ValueType.Name or "nil")
					)
				end
			end
		else
			print("[SERVER ERROR] ReflectionService failed:", tostring(errorMsg))
			Logs:AddLog("Errors", "Failed to generate API data from ReflectionService")
		end
	end)

	ServerNewDex.newDex_main = newDex_main
	ServerNewDex.Event = nil
	ServerNewDex.LogEvent = nil -- RemoteEvent for pushing logs to clients
	ServerNewDex.RemoteSpy_LogEvent = nil -- RemoteEvent for RemoteSpy logs
	ServerNewDex.Authorized = {} --// Users who have been given Dex and are authorized to use the remote event
	ServerNewDex.RemoteSpyMonitoring = {} -- Players actively monitoring remotes

	-- Server-side log capturing
	local LogService = Service.LogService
	local ServerLogHistory = {} -- Shared log history
	local MAX_LOG_HISTORY = 500

	-- Capture server logs and broadcast to all authorized Dex clients
	LogService.MessageOut:Connect(function(message, messageType)
		local logEntry = {
			message = message,
			messageType = messageType,
			timestamp = os.time(),
		}
		table.insert(ServerLogHistory, logEntry)

		-- Keep log history under limit
		if #ServerLogHistory > MAX_LOG_HISTORY then
			table.remove(ServerLogHistory, 1)
		end

		-- Broadcast to all authorized Dex clients (not just those viewing server console)
		if ServerNewDex.LogEvent then
			for player, _ in pairs(ServerNewDex.Authorized) do
				if player and player.Parent then
					ServerNewDex.LogEvent:FireClient(player, logEntry)
				end
			end
		end
	end)

	local Actions = {
		destroy = function(p: Player, args, realPlr: Player)
			if args[1]:IsA("Player") then
				if Admin.GetLevel(args[1]) < Admin.GetLevel(realPlr) then
					args[1]:Destroy()
				else
					Remote.MakeGui(realPlr, "Output", {
						Title = "Missing Permissions",
						Message = `You do not have the permission to delete player {args[1].DisplayName} (@{args[1].Name})`,
					})
				end
			else
				args[1]:Destroy()
			end
			return true
		end,
		clearclipboard = function(Player: Player, args)
			Player.Clipboard = {}
			return true
		end,
		duplicate = function(Player: Player, args)
			local obj = args[1]
			local par = args[2]

			local new = obj:Clone()
			new.Parent = par

			return new
		end,
		copy = function(Player: Player, args)
			local obj = args[1]
			local new = obj:Clone()
			table.insert(Player.Clipboard, new)

			return new -- It seems like this returns nil to the client, if the parent is nil.
		end,
		paste = function(Player: Player, args)
			local parent = args[1]
			local pastedObjects = {}

			for _, v in pairs(Player.Clipboard) do
				local cloned = v:Clone()
				cloned.Parent = parent
				table.insert(pastedObjects, cloned)
			end

			return pastedObjects
		end,
		setproperty = function(Player: Player, args)
			local obj = args[1]
			local prop = args[2]
			local value = args[3]

			if value ~= nil then
				-- Auto-add rbxassetid:// prefix for asset ID properties if user just entered a number
				if type(value) == "string" then
					local propLower = prop:lower()
					-- Check if this is an asset ID property
					local isAssetIdProp = propLower:match("id$")
						or propLower:match("texture")
						or propLower:match("image")
						or propLower:match("sound")
						or propLower:match("mesh")
						or propLower:match("skybox")
						or propLower:match("decal")

					-- If it's an asset property and the value is just digits, add the prefix
					if isAssetIdProp and value:match("^%d+$") then
						value = "rbxassetid://" .. value
					end
				end

				obj[prop] = value
				return true
			end
		end,
		setpropertyattribute = function(Player: Player, args)
			local obj = args[1]
			local attributeName = args[2]
			local value = args[3]

			if value ~= nil then
				obj:SetAttribute(attributeName, value)
				return true
			end
		end,
		instancenew = function(Player: Player, args)
			return Service.New(args[1], args[2])
		end,
		callfunction = function(Player: Player, args)
			local rets = { pcall(function()
				return (args[1][args[2]](args[1]))
			end) }
			table.remove(rets, 1)
			return rets
		end,
		callremote = function(Player: Player, args)
			if args[1]:IsA("RemoteFunction") then
				return args[1]:InvokeClient(table.unpack(args[2]))
			elseif args[1]:IsA("RemoteEvent") then
				args[1]:FireClient(table.unpack(args[2]))
			elseif args[1]:IsA("BindableFunction") then
				return args[1]:Invoke(table.unpack(args[2]))
			elseif args[1]:IsA("BindableEvent") then
				args[1]:Fire(table.unpack(args[2]))
			end
		end,
		fetchapi = function(Player: Player)
			print("[SERVER] fetchapi called, APIDump exists:", APIDump ~= nil)
			if APIDump then
				print("[SERVER] Returning APIDump with", #APIDump.Classes, "classes")

				-- Debug: Check what's actually in the first property
				local firstClass = APIDump.Classes[1]
				if firstClass then
					local props = APIDump.ClassProperties[firstClass.Name]
					if props and props[1] then
						local firstProp = props[1]
						print("[SERVER] First prop in APIDump:", firstProp.Name)
						print("[SERVER] First prop ValueType field exists:", firstProp.ValueType ~= nil)
						if firstProp.ValueType then
							print("[SERVER] ValueType content:", firstProp.ValueType)
							print("[SERVER] ValueType.Name:", firstProp.ValueType.Name)
							print("[SERVER] ValueType.Category:", firstProp.ValueType.Category)
							print("[SERVER] ValueType type:", type(firstProp.ValueType))
							print("[SERVER] ValueType.Name type:", type(firstProp.ValueType.Name))
						end
					end
				end
			end
			return APIDump or false
		end,
		addtag = function(Player: Player, args)
			local obj = args[1]
			local tag = args[2]

			if typeof(obj) ~= "Instance" then
				return "Invalid target."
			end

			if type(tag) ~= "string" or tag == "" then
				return "Invalid tag."
			end

			local CollectionService = game:GetService("CollectionService")
			CollectionService:AddTag(obj, tag)

			return true
		end,

		removetag = function(Player: Player, args)
			local obj = args[1]
			local tag = args[2]

			if typeof(obj) ~= "Instance" then
				return "Invalid target."
			end

			local CollectionService = game:GetService("CollectionService")
			CollectionService:RemoveTag(obj, tag)

			return true
		end,

		loadstring = function(Player: Player, args, realPlr: Player)
			assert(Settings.CodeExecution, "CodeExecution must be enabled for this to work.")
			-- Compile to bytecode and validate
			local bytecode = Core.Bytecode(assert(args[1], "Missing Script code (argument #1)"))
			assert(
				string.find(bytecode, "\27Lua"),
				`Script unable to be created: {string.gsub(bytecode, "Loadstring%.LuaX:%d+:", "")}`
			)

			-- Create and run the script
			local cl = Core.NewScript("Script", args[1], true)
			cl.Name = "[Adonis] Script"
			cl.Disabled = false
			cl.Parent = Service.ServerScriptService

			return true
		end,

		loadstringclient = function(Player: Player, args, realPlr: Player)
			assert(Settings.CodeExecution, "CodeExecution must be enabled for this to work.")
			-- Use Adonis's Remote.LoadCode to execute on client
			-- This handles bytecode compilation and client execution automatically
			Remote.LoadCode(realPlr, args[1], false)
			return true
		end,

		getserverloghistory = function(_Player: Player, _args, realPlr: Player)
			-- Send complete server log history to client
			return ServerLogHistory
		end,

		startremotespy = function(_Player: Player, _args, realPlr: Player)
			-- Start monitoring remotes for this player
			if not ServerNewDex.RemoteSpyMonitoring[realPlr] then
				ServerNewDex.RemoteSpyMonitoring[realPlr] = true
				return true
			end
			return false
		end,

		stopremotespy = function(_Player: Player, _args, realPlr: Player)
			-- Stop monitoring remotes for this player
			if ServerNewDex.RemoteSpyMonitoring[realPlr] then
				ServerNewDex.RemoteSpyMonitoring[realPlr] = nil
				return true
			end
			return false
		end,
	}

	function ServerNewDex.MakeEvent()
		if not Event then
			Event = Service.New("RemoteFunction", {
				Name = "NewDex_Event",
				Parent = game:GetService("ReplicatedStorage"),
			}, true, true)

			Event.OnServerInvoke = function(Plr: Player, Action, ...)
				local pData = ServerNewDex.Authorized[Plr]

				if not pData then
					return Anti.Detected(Plr, "kick", "Unauthorized to use the dex event")
				end

				local args = { ... }
				local Suppliments = args[1]

				local Action = string.lower(assert(Action, "Method argument missing!"))
				local MethodFunction =
					assert(Actions[Action], `{Plr.Name} attempted to use an action that wasn't defined: {Action}`)

				return MethodFunction(pData, args, Plr)
			end
		end

		-- Create LogEvent RemoteEvent for pushing server logs to clients
		if not ServerNewDex.LogEvent then
			ServerNewDex.LogEvent = Service.New("RemoteEvent", {
				Name = "NewDex_LogEvent",
				Parent = game:GetService("ReplicatedStorage"),
			}, true, true)
		end

		-- Create RemoteSpy_LogEvent for pushing remote spy logs to clients
		if not ServerNewDex.RemoteSpy_LogEvent then
			ServerNewDex.RemoteSpy_LogEvent = Service.New("RemoteEvent", {
				Name = "RemoteSpy_LogEvent",
				Parent = game:GetService("ReplicatedStorage"),
			}, true, true)
		end
	end

	-- Remote monitoring system (Lazy Loading)
	local MonitoredRemotes = {}
	local MonitoringActive = false
	local DescendantAddedConnection = nil

	local function setupRemoteMonitoring(remote)
		if MonitoredRemotes[remote] then
			return -- Already monitoring
		end

		local remoteName = remote:GetFullName()
		local remoteType = remote.ClassName

		if remoteType == "RemoteEvent" then
			-- Hook OnServerEvent
			local originalEvent = remote.OnServerEvent
			MonitoredRemotes[remote] = originalEvent:Connect(function(player, ...)
				-- Broadcast to all monitoring clients
				for monitoringPlayer, _ in pairs(ServerNewDex.RemoteSpyMonitoring) do
					if monitoringPlayer and monitoringPlayer.Parent and ServerNewDex.RemoteSpy_LogEvent then
						local args = { ... }

						local logData = {
							remoteType = "FireServer",
							remoteName = remoteName,
							caller = player.Name,
							args = args, -- Send raw args to client for detailed inspection
							timestamp = os.time(),
						}

						ServerNewDex.RemoteSpy_LogEvent:FireClient(monitoringPlayer, logData)
					end
				end
			end)
		elseif remoteType == "RemoteFunction" then
			-- RemoteFunctions can't be hooked because OnServerInvoke is write-only
			-- and we can't override the metatable on Roblox instances
			-- For now, just mark as seen but don't actually hook
			MonitoredRemotes[remote] = true
		end
	end

	-- Start monitoring all existing and new remotes
	local function startMonitoring()
		if MonitoringActive then
			return -- Already monitoring
		end
		MonitoringActive = true

		-- Monitor existing remotes (only RemoteEvents will actually be hooked)
		for _, descendant in ipairs(game:GetDescendants()) do
			if descendant:IsA("RemoteEvent") then
				setupRemoteMonitoring(descendant)
			end
		end

		-- Monitor new remotes going forward
		if not DescendantAddedConnection then
			DescendantAddedConnection = game.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("RemoteEvent") then
					task.wait(0.1) -- Small delay to let it initialize
					setupRemoteMonitoring(descendant)
				end
			end)
		end
	end

	-- Stop monitoring remotes when no one is using RemoteSpy
	local function stopMonitoring()
		if not MonitoringActive then
			return
		end
		MonitoringActive = false

		-- Disconnect existing connections
		for remote, connection in pairs(MonitoredRemotes) do
			if typeof(connection) == "RBXScriptConnection" then
				connection:Disconnect()
			end
		end
		MonitoredRemotes = {}

		-- Disconnect the DescendantAdded connection
		if DescendantAddedConnection then
			DescendantAddedConnection:Disconnect()
			DescendantAddedConnection = nil
		end
	end

	-- Monitor when players start/stop monitoring
	local OriginalStartRemoteSpy = Actions.startremotespy
	local OriginalStopRemoteSpy = Actions.stopremotespy

	Actions.startremotespy = function(...)
		local result = OriginalStartRemoteSpy(...)
		-- Start monitoring only when first player enables it
		local activeMonitors = 0
		for _, _ in pairs(ServerNewDex.RemoteSpyMonitoring) do
			activeMonitors = activeMonitors + 1
		end
		if activeMonitors > 0 then
			startMonitoring()
		end
		return result
	end

	Actions.stopremotespy = function(...)
		local result = OriginalStopRemoteSpy(...)
		-- Stop monitoring if no one is actively monitoring
		local activeMonitors = 0
		for _, _ in pairs(ServerNewDex.RemoteSpyMonitoring) do
			activeMonitors = activeMonitors + 1
		end
		if activeMonitors == 0 then
			stopMonitoring()
		end
		return result
	end

	-- Clean up monitoring when a player leaves
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		if ServerNewDex.RemoteSpyMonitoring[player] then
			ServerNewDex.RemoteSpyMonitoring[player] = nil
			-- Check if anyone else is monitoring
			local activeMonitors = 0
			for _, _ in pairs(ServerNewDex.RemoteSpyMonitoring) do
				activeMonitors = activeMonitors + 1
			end
			if activeMonitors == 0 then
				stopMonitoring()
			end
		end
	end)

	function ServerNewDex.MakeLocalDexForPlayer(ply, dexGui, destination)
		if ply then
			if dexGui and destination then
				dexGui.Parent = destination
			end
		end
	end

	-- Function used to give Dex to a player.
	function ServerNewDex.GiveDexToPlayer(ply)
		if ply then
			ServerNewDex.Authorized[ply] = {
				Clipboard = {},
			} --// double as per-player explorer-related data

			if not ServerNewDex.Event then
				ServerNewDex.MakeEvent()
			end
			ServerNewDex.MakeLocalDexForPlayer(ply, ServerNewDex.newDex_main:Clone(), ply:FindFirstChild("PlayerGui"))
		end
	end

	Commands.DexExplorerNew = {
		Prefix = Settings.Prefix,
		Commands = { "dexnew", "dexnewexplorer", "newdex", "dex", "dexexplorer" },
		Args = {}, --// kept for backwards compatibility
		Description = "Lets you explore the game using new Dex [Credits to LorekeeperZinnia]",
		AdminLevel = 300,
		Function = function(plr, args)
			ServerNewDex.Authorized[plr] = {
				Clipboard = {},
			} --// double as per-player explorer-related data

			if not ServerNewDex.Event then
				ServerNewDex.MakeEvent()
			end
			Remote.MakeLocal(plr, newDex_main:Clone(), "PlayerGui")
		end,
	}
	Logs:AddLog("Script", "NewDex Module Loaded")
end

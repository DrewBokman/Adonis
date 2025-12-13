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
	local RMDData = nil -- Reflection Metadata from ReflectionService
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

	-- Generate API and RMD data from ReflectionService asynchronously
	task.delay(0.25, function()
		print("[SERVER] Starting API and RMD data generation from ReflectionService...")

		local reflectionSuccess, apiResult, rmdResult = pcall(function()
			local classesData = ReflectionService:GetClasses()

			-- Build API structure from ReflectionService
			local apiData = {
				Classes = {},
				Enums = {},
			}

			-- Build minimal RMD structure - ONLY ReflectionService-unavailable data
			local rmdData = {
				Classes = {},
			}

			-- Property importance order heuristic (properties near start are more important)
			local propertyPriority = {
				-- Core properties
				Name = 1, Parent = 2, Archivable = 3,
				-- Appearance
				Visible = 10, Transparency = 11, Color = 12, BackgroundColor3 = 12, TextColor3 = 13,
				-- Position/Size
				Position = 20, Size = 21, Rotation = 22, CFrame = 23, AbsolutePosition = 24, AbsoluteSize = 25,
				-- Physics
				CanCollide = 30, Friction = 31, Elasticity = 32, Density = 33, Velocity = 34, RotVelocity = 35,
				-- Behavior
				Anchored = 40, CanTouch = 41, TopSurface = 42, BottomSurface = 43,
				-- Text properties
				Text = 50, Font = 51, TextSize = 52, TextWrapped = 53, TextScaled = 54,
				-- Audio
				Volume = 60, Pitch = 61, TimePosition = 62,
			}

			-- Class icon mapping and display orders from original RMD
			local classIconMap = {
				-- Remotes/Events
				RemoteEvent = 54, RemoteFunction = 55, BindableEvent = 67, BindableFunction = 66,
				-- Services
				Workspace = 19, Players = 20, Lighting = 18, ReplicatedStorage = 17, ReplicatedFirst = 17,
				ServerScriptService = 16, ServerStorage = 17, UserInputService = 10, RunService = 10,
				CollectionService = 10, HttpService = 10, MarketplaceService = 10, TeleportService = 10,
				GamepadService = 10, NetworkServer = 10, NetworkClient = 10,
				-- GUI
				ScreenGui = 15, StarterGui = 15, Frame = 15, TextLabel = 15, TextButton = 15,
				ImageLabel = 15, ImageButton = 15, ScrollingFrame = 15, UICorner = 15,
				UIAspectRatioConstraint = 15, UIPadding = 15, UIGridLayout = 15, UIListLayout = 15,
				UITableLayout = 15, UIScale = 15, SurfaceGui = 15, BillboardGui = 15, ContextActionService = 10,
				-- Scripts
				LocalScript = 10, Script = 12, ModuleScript = 11,
				-- Parts
				Part = 2, Model = 3, Terrain = 4, MeshPart = 2, UnionOperation = 2, NegateOperation = 2,
				-- Humanoid
				Humanoid = 9, Torso = 2, Head = 2, LeftArm = 2, RightArm = 2, LeftLeg = 2, RightLeg = 2,
				-- Effects
				ParticleEmitter = 6, Fire = 6, Smoke = 6, Explosion = 6, Sound = 5,
				Weld = 7, WeldConstraint = 7, Motor = 7, Motor6D = 7, BodyVelocity = 7, BodyPosition = 7, BodyGyro = 7,
				-- Rendering
				Decal = 1, Texture = 1, Camera = 8, Light = 6, PointLight = 6, SurfaceLight = 6, Attachment = 81,
				-- Values
				Instance = 0, Configuration = 0, Folder = 0, IntValue = 0, StringValue = 0, BoolValue = 0,
				Color3Value = 0, Vector3Value = 0, NumberValue = 0, ObjectValue = 0, RayValue = 0, CFrameValue = 0,
				-- Misc
				StarterPlayer = 14, StarterPack = 13, Actor = 113,
			}

			-- Class sort/display order (from original RMD - these are critical for proper sorting)
			local classExplorerOrder = {
				Workspace = 0, Players = 1, Lighting = 2, ReplicatedStorage = 3, ReplicatedFirst = 4,
				ServerScriptService = 5, ServerStorage = 6, StarterPlayer = 7, StarterGui = 8, StarterPack = 9,
				DataStoreService = 100, InsertService = 100, RunService = 100, HttpService = 100,
			}

			-- Get property importance score
			local function getPropertyScore(propName)
				return propertyPriority[propName] or 100 + string.len(propName)
			end

			-- Categorize class based on tags
			local function getClassCategory(tags)
				if tags.Service then return "Service" end
				if tags.Creatable then return "Instance" end
				if tags.Deprecated then return "Deprecated" end
				return "Other"
			end

			-- Get icon index for a class
			local function getClassIcon(className, tags)
				if classIconMap[className] then
					return classIconMap[className]
				end
				if tags.Service then return 10 end
				if tags.Creatable then
					if className:match("Gui$") or className:match("Label$") or className:match("Button$") or className:match("Frame$") then
						return 40
					elseif className:match("Script$") then return 30 end
				end
				return 0
			end

			-- Process classes
			for _, classInfo in ipairs(classesData) do
				local className = classInfo.Name

				-- Convert tags to dictionary format
				local tags = {}
				if classInfo.Tags then
					for _, tag in ipairs(classInfo.Tags) do
						tags[tostring(tag)] = true
					end
				end

				-- Build API class entry with ReflectionService data
				local classEntry = {
					Name = className,
					Superclass = classInfo.Superclass,
					Tags = tags,
					Members = {},
				}

				-- Get properties
				local propertiesData = ReflectionService:GetPropertiesOfClass(className)
				local sortedProps = {}

				for _, prop in ipairs(propertiesData) do
					table.insert(sortedProps, prop)
				end

				-- Sort by importance
				table.sort(sortedProps, function(a, b)
					local scoreA = getPropertyScore(a.Name)
					local scoreB = getPropertyScore(b.Name)
					return scoreA < scoreB
				end)

				-- Build API members from ReflectionService
				local propertyOrder = 0
				for _, prop in ipairs(sortedProps) do
					local propTags = {}
					if prop.Tags then
						for _, tag in ipairs(prop.Tags) do
							propTags[tostring(tag)] = true
						end
					end

					local memberEntry = {
						Name = prop.Name,
						MemberType = "Property",
						Category = (prop.Display and prop.Display.Category) or "Data",
						Security = {
							Read = (prop.Permits and tostring(prop.Permits.Read)) or "None",
							Write = (prop.Permits and tostring(prop.Permits.Write)) or "None",
						},
						Serialization = {
							CanSave = prop.Serialized or false,
							CanLoad = prop.Serialized or false,
						},
						Tags = propTags,
					}

					if prop.Type then
						local valueTypeName = prop.Type.ScriptType or prop.Type.EngineType
						if valueTypeName then
							memberEntry.ValueType = {
								Name = valueTypeName,
								Category = "Primitive",
							}
						end
					end

					table.insert(classEntry.Members, memberEntry)
					propertyOrder = propertyOrder + 1
				end

				apiData.Classes[className] = classEntry

				-- Build MINIMAL RMD entry - ONLY data that ReflectionService cannot provide
				local rmdClassEntry = {
					Name = className,
					ClassCategory = getClassCategory(tags),
					ExplorerImageIndex = getClassIcon(className, tags),
					ExplorerOrder = classExplorerOrder[className] or 9999,
				}

				-- Only include PropertyOrder if we have it (important for property display order)
				if propertyOrder > 0 then
					rmdClassEntry.PropertyOrders = {}
					local order = 0
					for _, prop in ipairs(sortedProps) do
						rmdClassEntry.PropertyOrders[prop.Name] = order
						order = order + 1
					end
				end

				rmdData.Classes[className] = rmdClassEntry
			end

			print("[SERVER] API data generation complete. Classes:", table.maxn(apiData.Classes))
			print("[SERVER] RMD data generation complete. Classes:", table.maxn(rmdData.Classes))

			-- JSON encode for transmission to client
			local apiJson = game:GetService("HttpService"):JSONEncode(apiData)
			local rmdJson = game:GetService("HttpService"):JSONEncode(rmdData)

			return apiJson, rmdJson
		end)

		if reflectionSuccess then
			APIDump = apiResult
			RMDData = rmdResult
			print("[SERVER] Successfully generated API and RMD data from ReflectionService")
			Logs:AddLog("Script", "Successfully generated API and RMD data from ReflectionService")
		else
			print("[SERVER ERROR] ReflectionService failed:", tostring(apiResult))
			Logs:AddLog("Errors", "Failed to generate API and RMD data from ReflectionService: " .. tostring(apiResult))
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
			return APIDump or false
		end,
		fetchrmd = function(Player: Player)
			-- Generate RMD data from ReflectionService for client use
			if RMDData then
				return RMDData
			end
			return false
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

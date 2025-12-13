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

			-- Class icon mapping from original RMD (all 277 classes)
			local classIconMap = {
				Accessory = 32, Accoutrement = 32, Actor = 113, AdGui = 145, AdPortal = 146,
				AlignOrientation = 100, AlignPosition = 99, AngularVelocity = 103, Animation = 60, AnimationController = 60,
				AnimationTrack = 60, Animator = 60, ArcHandles = 56, Atmosphere = 28, Attachment = 81,
				AudioAnalyzer = 84, AudioChannelMixer = 84, AudioChannelSplitter = 84, AudioChorus = 84, AudioCompressor = 84,
				AudioDeviceInput = 11, AudioDeviceOutput = 11, AudioDistortion = 84, AudioEcho = 84, AudioEmitter = 11,
				AudioEqualizer = 84, AudioFader = 84, AudioFilter = 84, AudioFlanger = 84, AudioGate = 84,
				AudioLimiter = 84, AudioListener = 11, AudioPitchShifter = 84, AudioPlayer = 11, AudioReverb = 84,
				AudioTextToSpeech = 84, AudioTremolo = 84, Backpack = 20, BallSocketConstraint = 86, Beam = 96,
				BillboardGui = 64, BindableEvent = 67, BindableFunction = 66, BlockMesh = 8, BloomEffect = 83,
				BlurEffect = 83, BodyAngularVelocity = 14, BodyForce = 14, BodyGyro = 14, BodyPosition = 14,
				BodyThrust = 14, BodyVelocity = 14, Bone = 114, BoolValue = 4, BoxHandleAdornment = 111,
				BrickColorValue = 4, CFrameValue = 4, Camera = 5, CanvasGroup = 48, ChannelSelectorSoundEffect = 84,
				CharacterMesh = 60, Chat = 33, ChatInputBarConfiguration = 142, ChatService = 33, ChatWindowConfiguration = 141,
				ChorusSoundEffect = 84, ClickDetector = 41, Clouds = 28, Color3Value = 4, ColorCorrectionEffect = 83,
				CompressorSoundEffect = 84, ConeHandleAdornment = 110, Configuration = 58, Constraint = 86, CoreGui = 46,
				CorePackages = 20, CornerWedgePart = 1, CustomEvent = 4, CustomEventReceiver = 4, CylinderHandleAdornment = 109,
				CylinderMesh = 8, CylindricalConstraint = 95, Debris = 30, Decal = 7, DepthOfFieldEffect = 83,
				Dialog = 62, DialogChoice = 63, DistortionSoundEffect = 84, DoubleConstrainedValue = 4, DragDetector = 41,
				EchoSoundEffect = 84, EqualizerSoundEffect = 84, Explosion = 36, FaceControls = 129, Fire = 61,
				Flag = 38, FlagStand = 39, FlangeSoundEffect = 84, FloorWire = 4, Folder = 77,
				ForceField = 37, Frame = 48, GuiButton = 52, GuiMain = 47, Handles = 53,
				Hat = 45, Highlight = 133, HingeConstraint = 87, Hint = 33, HopperBin = 22,
				Humanoid = 9, HumanoidDescription = 104, IKControl = 53, ImageButton = 52, ImageHandleAdornment = 108,
				ImageLabel = 49, IntConstrainedValue = 4, IntValue = 4, JointInstance = 34, Keyframe = 60,
				KeyframeMarker = 60, Light = 13, Lighting = 13, LineForce = 101, LineHandleAdornment = 107,
				LinearVelocity = 132, LocalScript = 18, LocalizationService = 92, LocalizationTable = 97, MarketplaceService = 46,
				MaterialService = 131, MaterialVariant = 130, MeshPart = 73, Message = 33, Model = 2,
				ModuleScript = 76, Motor6D = 106, NegateOperation = 72, NetworkClient = 16, NetworkReplicator = 29,
				NetworkServer = 15, NoCollisionConstraint = 105, NumberPose = 60, NumberValue = 4, ObjectValue = 4,
				PackageLink = 98, Pants = 44, ParallelRampPart = 1, Part = 1, PartPairLasso = 57,
				ParticleEmitter = 80, PathfindingLink = 137, PathfindingModifier = 128, PitchShiftSoundEffect = 84, Plane = 134,
				PlaneConstraint = 134, Platform = 35, Player = 12, PlayerGui = 46, PlayerScripts = 78,
				Players = 21, Plugin = 86, PluginDebugService = 46, PluginGuiService = 46, PointLight = 13,
				Pose = 60, PoseBase = 60, PrismPart = 1, PrismaticConstraint = 88, ProximityPrompt = 124,
				PyramidPart = 1, RayValue = 4, RemoteEvent = 75, RemoteFunction = 74, RenderingTest = 5,
				ReplicatedFirst = 70, ReplicatedStorage = 70, ReverbSoundEffect = 84, RightAngleRampPart = 1, RigidConstraint = 135,
				RobloxPluginGuiService = 46, RocketPropulsion = 14, RodConstraint = 90, RopeConstraint = 89, ScreenGui = 47,
				Script = 6, ScrollingFrame = 48, Seat = 35, SelectionBox = 54, SelectionPartLasso = 57,
				SelectionPointLasso = 57, SelectionSphere = 54, ServerScriptService = 71, ServerStorage = 69, Shirt = 43,
				ShirtGraphic = 40, SkateboardPlatform = 35, Sky = 28, SlidingBallConstraint = 88, Smoke = 59,
				Snap = 34, Sound = 11, SoundGroup = 85, SoundService = 31, Sparkles = 42,
				SpawnLocation = 25, Speaker = 11, SpecialMesh = 8, SphereHandleAdornment = 112, SpotLight = 13,
				SpringConstraint = 91, StandalonePluginScripts = 78, StarterCharacterScripts = 78, StarterGear = 20, StarterGui = 46,
				StarterPack = 20, StarterPlayer = 79, StarterPlayerScripts = 78, Status = 2, StringValue = 4,
				SunRaysEffect = 83, SurfaceAppearance = 10, SurfaceGui = 64, SurfaceLight = 13, SurfaceSelection = 55,
				Team = 24, Teams = 23, Terrain = 65, TerrainDetail = 144, TerrainRegion = 65,
				TestService = 68, TextBox = 51, TextButton = 51, TextChannel = 140, TextChatCommand = 138,
				TextChatService = 143, TextLabel = 50, TextSource = 139, Texture = 10, Tool = 17,
				Torque = 103, TorsionSpringConstraint = 125, TouchTransmitter = 37, Trail = 93, TremoloSoundEffect = 84,
				TrussPart = 1, UIAspectRatioConstraint = 26, UICorner = 26, UIGradient = 26, UIGridLayout = 26,
				UIListLayout = 26, UIPadding = 26, UIPageLayout = 26, UIScale = 26, UISizeConstraint = 26,
				UIStroke = 26, UITableLayout = 26, UITextSizeConstraint = 26, UnionOperation = 73, UniversalConstraint = 123,
				ValueBase = 4, Vector3Value = 4, VectorForce = 102, VehicleSeat = 35, VideoFrame = 120,
				ViewportFrame = 52, VoiceChatService = 136, VoiceSource = 11, WedgePart = 1, Weld = 34,
				WeldConstraint = 94, Wire = 17, WireframeHandleAdornment = 113, Workspace = 19, WorldModel = 19,
				WrapLayer = 126, WrapTarget = 127,
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

			-- Categorize class based on tags (expects dictionary)
			local function getClassCategory(tagsDict)
				if tagsDict.Service then return "Service" end
				if tagsDict.Creatable then return "Instance" end
				if tagsDict.Deprecated then return "Deprecated" end
				return "Other"
			end

			-- Get icon index for a class (expects dictionary)
			local function getClassIcon(className, tagsDict)
				if classIconMap[className] then
					return classIconMap[className]
				end
				if tagsDict.Service then return 10 end
				if tagsDict.Creatable then
					if className:match("Gui$") or className:match("Label$") or className:match("Button$") or className:match("Frame$") then
						return 40
					elseif className:match("Script$") then return 30 end
				end
				return 0
			end

			-- Build class lookup by name for superclass resolution
			local classLookup = {}
			for _, classInfo in ipairs(classesData) do
				classLookup[classInfo.Name] = classInfo
			end

			-- First pass: collect all class properties
			local allClassProps = {}
			for _, classInfo in ipairs(classesData) do
				local propsData = ReflectionService:GetPropertiesOfClass(classInfo.Name)
				local propSet = {}
				for _, prop in ipairs(propsData) do
					propSet[prop.Name] = prop
				end
				allClassProps[classInfo.Name] = propSet
			end

			-- Helper: get all inherited property names by walking superclass chain
			local function getInheritedProps(className)
				local inherited = {}
				local classInfo = classLookup[className]
				if classInfo and classInfo.Superclass then
					local superName = classInfo.Superclass
					-- Get direct superclass properties
					if allClassProps[superName] then
						for propName, _ in pairs(allClassProps[superName]) do
							inherited[propName] = true
						end
					end
				end
				return inherited
			end

			-- Process classes
			for _, classInfo in ipairs(classesData) do
				local className = classInfo.Name

				-- Tags can be nil, handle that
				local tagsDict = {}
				local tags = {}
				if classInfo.Tags then
					for _, tag in ipairs(classInfo.Tags) do
						local tagStr = tostring(tag)
						tagsDict[tagStr] = true
						table.insert(tags, tagStr)
					end
				end

				-- Build API class entry with ReflectionService data
				local classEntry = {
					Name = className,
					Superclass = classInfo.Superclass,
					Tags = tags,
					Members = {},
				}

				-- Get properties for this class
				local thisClassProps = allClassProps[className] or {}

				-- Get inherited properties to exclude
				local inheritedProps = getInheritedProps(className)

				-- Collect only properties that are NOT inherited (directly defined on this class)
				local sortedProps = {}
				for propName, prop in pairs(thisClassProps) do
					-- Skip inherited props
					if not inheritedProps[propName] then
						-- Skip lowercase/deprecated variants (className, archivable, etc.)
						-- Only include if the property name starts with uppercase
						local firstChar = string.sub(propName, 1, 1)
						if firstChar == string.upper(firstChar) then
							table.insert(sortedProps, prop)
						end
					end
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
					-- Tags can be nil
					local propTags = {}
					if prop.Tags then
						for _, tag in ipairs(prop.Tags) do
							table.insert(propTags, tostring(tag))
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
						-- Determine category based on type name
						local category = "Primitive"

						-- Detect enum types: check if ScriptType is "EnumItem" and EnumType exists
						if (prop.Type.ScriptType == "EnumItem" or prop.Type.EngineType == "Enum") and prop.Type.EnumType then
							-- Use the EnumType as the value type name (e.g., "Material", "PartType")
							valueTypeName = prop.Type.EnumType
							category = "Enum"
						-- Detect class types
						elseif valueTypeName == "Instance" or valueTypeName:match("^Class%.") then
							category = "Class"
						-- Map "boolean" to "bool" for client compatibility
						elseif valueTypeName == "boolean" then
							valueTypeName = "bool"
						end

						memberEntry.ValueType = {
							Name = valueTypeName,
							Category = category,
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
					ClassCategory = getClassCategory(tagsDict),
					ExplorerImageIndex = getClassIcon(className, tagsDict),
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

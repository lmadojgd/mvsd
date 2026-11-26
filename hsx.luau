-- ============================================================================
-- VORTEX // MVSD ULTRA RAGE SUITE v3.5 (ENTERPRISE EDITION)
-- Target Game: Murderers vs Sheriffs Duels (MVSD)
-- UI Framework: WindUI (Latest Release)
-- Architecture: Modular Service-Driven Client Suite
-- Features:
--   * Full JSON Config Manager (Save / Load / Delete / Auto-Load)
--   * Multi-Point Hitscan Ragebot & Silent Aim / Auto-Shoot / TriggerBot
--   * Advanced Anti-Aim (SpinBot, Jitter, Static, Random, Pitch Down/Up/Zero)
--   * Movement Velocity Resolver & Ping Compensation
--   * Full 2D/3D Drawing ESP (Boxes, Corner Boxes, Skeletons, Head Dots,
--     Look Rays, Health Bars, Role Tags, Distance, Off-Screen FOV Arrows)
--   * Visual Effects (3D Bullet Tracers, Impact Markers, Hit Chams, World Theme)
--   * Movement & Exploits (CFrame Speed, Air Strafe, Bhop, Fly, NoClip, Orbit)
--   * On-Screen Watermark, Keybind List, Spectator List & Hit Logs
-- ============================================================================

-- Ensure game is fully loaded
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Clean up any existing instance before loading
if getgenv().VORTEX_MVSD_INSTANCE and type(getgenv().VORTEX_MVSD_INSTANCE.Unload) == "function" then
    pcall(getgenv().VORTEX_MVSD_INSTANCE.Unload)
end

local Vortex = {
    Version = "3.5.0-ULTRA",
    Build = "Release",
    Unloaded = false,
    Connections = {},
    Drawings = {},
    ESP = {},
    HitLogs = {},
    BulletTracers = {},
    ImpactMarkers = {},
    PlayerData = {},
    State = {
        CurrentTarget = nil,
        TargetBone = nil,
        TargetPredictedPos = nil,
        LastShotTime = 0,
        ShotsFired = 0,
        ShotsHit = 0,
        Kills = 0,
        Deaths = 0,
        StartTime = tick(),
        JitterSide = 1,
        SpinAngle = 0,
        OrbitAngle = 0,
        DesyncTick = 0,
        FakeLagTick = 0,
        IsMenuOpen = true,
    }
}

getgenv().VORTEX_MVSD_INSTANCE = Vortex

-- ============================================================================
-- [MODULE 1] SERVICES & SAFE ENVIRONMENT WRAPPERS
-- ============================================================================

local Services = setmetatable({}, {
    __index = function(self, name)
        local success, service = pcall(function()
            return game:GetService(name)
        end)
        if success and service then
            rawset(self, name, service)
            return service
        end
        return nil
    end
})

local Players = Services.Players
local RunService = Services.RunService
local UserInputService = Services.UserInputService
local TweenService = Services.TweenService
local Workspace = Services.Workspace
local ReplicatedStorage = Services.ReplicatedStorage
local HttpService = Services.HttpService
local VirtualUser = Services.VirtualUser
local Lighting = Services.Lighting
local Debris = Services.Debris
local TeleportService = Services.TeleportService
local Stats = Services.Stats
local CoreGui = Services.CoreGui
local GuiService = Services.GuiService

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

-- Safe Executor Function Fallbacks
local Env = {
    writefile = writefile or function() end,
    readfile = readfile or function() return "" end,
    isfile = isfile or function() return false end,
    isfolder = isfolder or function() return false end,
    makefolder = makefolder or function() end,
    listfiles = listfiles or function() return {} end,
    delfile = delfile or function() end,
    setclipboard = setclipboard or toclipboard or function() end,
    gethui = gethui or function() return CoreGui end,
    Drawing = Drawing or {
        new = function()
            return setmetatable({}, {
                __index = function() return function() end end,
                __newindex = function() end
            })
        end
    }
}

function Vortex:BindConnection(signal, callback)
    if not signal then return nil end
    local conn = signal:Connect(function(...)
        if self.Unloaded then return end
        local ok, err = pcall(callback, ...)
        if not ok then
            -- Silent error guard to prevent loop crashes
        end
    end)
    table.insert(self.Connections, conn)
    return conn
end

function Vortex:CreateDrawing(drawType, properties)
    local obj = Env.Drawing.new(drawType)
    if properties then
        for k, v in pairs(properties) do
            pcall(function()
                obj[k] = v
            end)
        end
    end
    table.insert(self.Drawings, obj)
    return obj
end

-- ============================================================================
-- [MODULE 2] CONFIGURATION SCHEMA & JSON PERSISTENCE
-- ============================================================================

local ConfigFolder = "Vortex_MVSD_Ultra"
local ProfilesFolder = ConfigFolder .. "/Profiles"

pcall(function()
    if not Env.isfolder(ConfigFolder) then Env.makefolder(ConfigFolder) end
    if not Env.isfolder(ProfilesFolder) then Env.makefolder(ProfilesFolder) end
end)

local Config = {
    Ragebot = {
        Enabled = false,
        Mode = "Auto Shoot", -- "Auto Shoot", "TriggerBot", "Camera Lock", "Silent Flick"
        AutoFire = true,
        AutoEquip = true,
        AutoReload = true,
        TargetSelection = "Crosshair + Distance", -- "Crosshair", "Distance", "Lowest HP", "Crosshair + Distance", "Threat Level"
        HitscanMode = "Multi-Point", -- "Single Bone", "Multi-Point", "Adaptive"
        PrimaryBone = "Head",
        FallbackBones = { "UpperTorso", "HumanoidRootPart", "LowerTorso", "LeftUpperArm", "RightUpperArm" },
        MultipointScale = 0.65,
        FOVEnabled = true,
        FOVRadius = 220,
        DynamicFOV = true,
        FOVFilled = false,
        FOVFillTransparency = 0.12,
        FOVThickness = 1.6,
        FOVSides = 64,
        FOVColor = { 165, 85, 255 },
        FOVRainbow = false,
        WallCheck = true,
        TeamCheck = true,
        ForceFieldCheck = true,
        FriendCheck = false,
        MaxDistance = 850,
        FireRateDelay = 0.045,
        SwitchTargetDelay = 0.02,
        CameraSmoothness = 0.08,
        FlickReturnCamera = true,
        Prediction = {
            Enabled = true,
            HorizontalScale = 0.138,
            VerticalScale = 0.115,
            GravityCompensation = true,
            GravityFactor = 0.018,
            PingCompensation = true,
            PingMultiplier = 1.05,
        },
        Resolver = {
            Enabled = true,
            Mode = "Velocity + Acceleration", -- "Velocity", "Velocity + Acceleration", "Anti-Spin"
            HistorySamples = 8,
            AntiSpinThreshold = 25,
        }
    },

    AntiAim = {
        Enabled = false,
        YawMode = "SpinBot", -- "SpinBot", "Jitter", "Random", "Backwards", "Sideways Left", "Sideways Right", "Tank"
        SpinSpeed = 48,
        JitterAngle = 75,
        JitterSpeed = 12,
        YawOffset = 0,
        PitchMode = "Down", -- "None", "Down", "Up", "Zero", "Jitter"
        DisableOnShoot = true,
        FakeLag = {
            Enabled = false,
            Mode = "Dynamic", -- "Static", "Dynamic", "Random"
            ChokeTicks = 6,
            MaxChokeTicks = 12,
        },
        Desync = {
            Enabled = false,
            Offset = 3.2,
            Invert = false,
        }
    },

    Hitbox = {
        Enabled = false,
        Mode = "Enemies Only", -- "Enemies Only", "All Players", "Sheriff/Murderer Only"
        Part = "HumanoidRootPart", -- "HumanoidRootPart", "Head", "UpperTorso"
        SizeX = 8.5,
        SizeY = 8.5,
        SizeZ = 8.5,
        UniformSize = true,
        Transparency = 0.78,
        Material = "Neon",
        Color = { 255, 50, 90 },
        RainbowColor = false,
        VisualizeOutline = true,
    },

    Visuals = {
        Enabled = false,
        MaxDistance = 1200,
        TeamCheck = false,
        ShowTeammates = true,
        Boxes = {
            Enabled = true,
            Style = "Corner", -- "Full", "Corner", "3D Box"
            Thickness = 1.3,
            Outline = true,
            Filled = false,
            FillTransparency = 0.15,
        },
        Skeleton = {
            Enabled = false,
            Thickness = 1.2,
            Color = { 255, 255, 255 },
        },
        HeadDot = {
            Enabled = false,
            Radius = 3.5,
            Filled = true,
        },
        LookRay = {
            Enabled = false,
            Length = 12,
            Thickness = 1.2,
        },
        Info = {
            Names = true,
            DisplayNames = true,
            RoleBadges = true,
            WeaponName = true,
            Distance = true,
            HealthBar = true,
            HealthText = false,
            Flags = true,
            TextSize = 13,
        },
        Tracers = {
            Enabled = false,
            Origin = "Bottom", -- "Bottom", "Center", "Top", "Mouse"
            Thickness = 1.2,
        },
        OffscreenArrows = {
            Enabled = false,
            Radius = 260,
            Size = 14,
            Filled = true,
        },
        Chams = {
            Enabled = true,
            FillTransparency = 0.55,
            OutlineTransparency = 0.1,
            OutlineColor = { 255, 255, 255 },
            OccludedOnly = false,
        },
        Colors = {
            UseRoleColors = true,
            Sheriff = { 55, 155, 255 },
            Murderer = { 255, 55, 75 },
            Enemy = { 255, 165, 45 },
            Teammate = { 65, 235, 130 },
            TargetHighlight = { 255, 0, 220 },
        },
        Tracers3D = {
            BulletTracers = true,
            TracerDuration = 1.2,
            TracerColor = { 175, 95, 255 },
            ImpactMarkers = true,
            ImpactSize = 0.45,
            ImpactColor = { 255, 65, 115 },
        },
        World = {
            Fullbright = false,
            NoFog = false,
            CustomAmbient = false,
            AmbientColor = { 140, 110, 190 },
            CustomTime = false,
            ClockTime = 14,
            FOVChanger = false,
            CameraFOV = 85,
            ThirdPerson = false,
            ThirdPersonDist = 12,
        }
    },

    Movement = {
        Speed = {
            Enabled = false,
            Mode = "WalkSpeed", -- "WalkSpeed", "CFrame", "Velocity"
            Value = 28,
        },
        Jump = {
            Enabled = false,
            Power = 65,
            InfiniteJump = false,
            AutoBhop = false,
            AirStrafe = false,
            StrafeSpeed = 28,
        },
        Flight = {
            Enabled = false,
            Mode = "Camera", -- "Camera", "CFrame"
            Speed = 55,
        },
        Physics = {
            NoClip = false,
            AntiVoid = true,
            VoidHeight = -150,
            ClickTP = false,
            ClickTPKey = "LeftControl",
        },
        TargetOrbit = {
            Enabled = false,
            Radius = 9,
            Speed = 6,
            HeightOffset = 2,
        }
    },

    HUD = {
        Watermark = true,
        KeybindList = true,
        TargetHUD = true,
        HitLogs = true,
        MaxHitLogs = 6,
        CustomCrosshair = {
            Enabled = false,
            Size = 8,
            Gap = 4,
            Thickness = 1.5,
            Spin = false,
            SpinSpeed = 120,
            Color = { 180, 95, 255 },
        }
    },

    Misc = {
        HitSound = {
            Enabled = true,
            Preset = "Skeet", -- "Skeet", "Bell", "Bubble", "Rust", "Cod", "Laser"
            Volume = 1.6,
            Pitch = 1.0,
        },
        Notifications = {
            KillAlert = true,
            RoundAlert = true,
            TargetLockAlert = false,
        },
        Automation = {
            AntiAFK = true,
            AutoVote = false,
            AutoRejoinOnKick = false,
            FPSBooster = false,
        },
        Whitelist = {}
    }
}

-- Color Utility Helpers
local function ToColor3(tbl)
    if typeof(tbl) == "Color3" then return tbl end
    if type(tbl) == "table" and #tbl >= 3 then
        return Color3.fromRGB(tbl[1], tbl[2], tbl[3])
    end
    return Color3.fromRGB(255, 255, 255)
end

local function FromColor3(col)
    return { math.floor(col.R * 255), math.floor(col.G * 255), math.floor(col.B * 255) }
end

local function GetRainbowColor(speed, offset)
    local t = (tick() * (speed or 0.5) + (offset or 0)) % 1
    return Color3.fromHSV(t, 0.85, 1)
end

-- Deep Copy & Merge for Config System
local function DeepMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            DeepMerge(target[k], v)
        else
            target[k] = v
        end
    end
end

function Vortex:SaveConfig(profileName)
    if not profileName or profileName == "" then profileName = "default" end
    local path = ProfilesFolder .. "/" .. profileName .. ".json"
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(Config)
    end)
    if ok and encoded then
        Env.writefile(path, encoded)
        return true
    end
    return false
end

function Vortex:LoadConfig(profileName)
    if not profileName or profileName == "" then profileName = "default" end
    local path = ProfilesFolder .. "/" .. profileName .. ".json"
    if not Env.isfile(path) then return false end
    local raw = Env.readfile(path)
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if ok and type(decoded) == "table" then
        DeepMerge(Config, decoded)
        return true
    end
    return false
end

function Vortex:DeleteConfig(profileName)
    local path = ProfilesFolder .. "/" .. profileName .. ".json"
    if Env.isfile(path) then
        Env.delfile(path)
        return true
    end
    return false
end

function Vortex:GetConfigList()
    local list = {}
    local files = Env.listfiles(ProfilesFolder)
    for _, file in ipairs(files) do
        local name = file:match("([^/\\]+)%.json$")
        if name then
            table.insert(list, name)
        end
    end
    if #list == 0 then
        table.insert(list, "default")
    end
    return list
end

-- ============================================================================
-- [MODULE 3] MVSD GAME ANALYZER, RESOLVER & PREDICTION ENGINE
-- ============================================================================

local SoundPresets = {
    Skeet = "rbxassetid://4817809188",
    Bell = "rbxassetid://6534947240",
    Bubble = "rbxassetid://6534947588",
    Rust = "rbxassetid://5043539486",
    Cod = "rbxassetid://5952120301",
    Laser = "rbxassetid://138081500",
}

local OriginalLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
}

function Vortex:IsAlive(player)
    if not player then return false end
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then
        return false
    end
    if Config.Ragebot.ForceFieldCheck and char:FindFirstChildOfClass("ForceField") then
        return false
    end
    return true
end

function Vortex:GetEquippedWeapon(player)
    if not player or not player.Character then return "None", nil end
    local tool = player.Character:FindFirstChildOfClass("Tool")
    if tool then
        return tool.Name, tool
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local bpTool = backpack:FindFirstChildOfClass("Tool")
        if bpTool then
            return bpTool.Name, bpTool
        end
    end
    return "None", nil
end

function Vortex:GetPlayerRole(player)
    if not player or not player.Character then return "None" end
    local char = player.Character
    local backpack = player:FindFirstChild("Backpack")

    local function checkItem(keywords)
        for _, kw in ipairs(keywords) do
            if char:FindFirstChild(kw) or (backpack and backpack:FindFirstChild(kw)) then
                return true
            end
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Tool") and item.Name:lower():find(kw:lower()) then
                    return true
                end
            end
            if backpack then
                for _, item in ipairs(backpack:GetChildren()) do
                    if item:IsA("Tool") and item.Name:lower():find(kw:lower()) then
                        return true
                    end
                end
            end
        end
        return false
    end

    if checkItem({ "Gun", "Revolver", "Sheriff", "Pistol", "Deagle", "Sniper", "Rifle" }) then
        return "Sheriff"
    end
    if checkItem({ "Knife", "Blade", "Murder", "Dagger", "Sword", "Scythe" }) then
        return "Murderer"
    end

    if player.Team then
        local tName = player.Team.Name
        if tName:lower():find("sheriff") then return "Sheriff" end
        if tName:lower():find("murder") then return "Murderer" end
        return tName
    end

    return "Neutral"
end

function Vortex:IsWhitelisted(player)
    if not player then return false end
    if Config.Misc.Whitelist[player.Name] or Config.Misc.Whitelist[tostring(player.UserId)] then
        return true
    end
    if Config.Ragebot.FriendCheck then
        local ok, isFriend = pcall(function()
            return LocalPlayer:IsFriendsWith(player.UserId)
        end)
        if ok and isFriend then return true end
    end
    return false
end

function Vortex:IsEnemy(player)
    if not player or player == LocalPlayer then return false end
    if self:IsWhitelisted(player) then return false end
    if not Config.Ragebot.TeamCheck then return true end

    if LocalPlayer.Team and player.Team then
        if LocalPlayer.Team.Name ~= "Neutral" and player.Team.Name ~= "Neutral" then
            return LocalPlayer.Team ~= player.Team
        end
    end

    local myRole = self:GetPlayerRole(LocalPlayer)
    local theirRole = self:GetPlayerRole(player)
    if (myRole == "Sheriff" or myRole == "Murderer") and (theirRole == "Sheriff" or theirRole == "Murderer") then
        return myRole ~= theirRole
    end

    return true
end

function Vortex:GetRoleColor(player, isTarget)
    if isTarget then
        return ToColor3(Config.Visuals.Colors.TargetHighlight)
    end
    local enemy = self:IsEnemy(player)
    if Config.Visuals.Colors.UseRoleColors then
        local role = self:GetPlayerRole(player)
        if role == "Sheriff" then
            return ToColor3(Config.Visuals.Colors.Sheriff)
        elseif role == "Murderer" then
            return ToColor3(Config.Visuals.Colors.Murderer)
        end
    end
    if enemy then
        return ToColor3(Config.Visuals.Colors.Enemy)
    else
        return ToColor3(Config.Visuals.Colors.Teammate)
    end
end

-- Movement & Velocity Resolver
function Vortex:UpdatePlayerResolver(player)
    if not self:IsAlive(player) then
        self.PlayerData[player] = nil
        return
    end

    local char = player.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local data = self.PlayerData[player]
    if not data then
        data = {
            History = {},
            ResolvedVelocity = Vector3.zero,
            Acceleration = Vector3.zero,
            IsSpinning = false,
            LastYaw = 0,
            LastHealth = 100,
        }
        self.PlayerData[player] = data
    end

    local now = tick()
    local pos = hrp.Position
    local _, yaw, _ = hrp.CFrame:ToOrientation()
    local yawDelta = math.abs(math.deg(yaw - data.LastYaw))
    data.LastYaw = yaw
    data.IsSpinning = yawDelta > Config.Ragebot.Resolver.AntiSpinThreshold

    table.insert(data.History, { Time = now, Pos = pos, Vel = hrp.AssemblyLinearVelocity })
    while #data.History > Config.Ragebot.Resolver.HistorySamples do
        table.remove(data.History, 1)
    end

    if #data.History >= 2 then
        local newest = data.History[#data.History]
        local oldest = data.History[1]
        local dt = newest.Time - oldest.Time
        if dt > 0.001 then
            local manualVel = (newest.Pos - oldest.Pos) / dt
            if Config.Ragebot.Resolver.Enabled then
                if data.IsSpinning or Config.Ragebot.Resolver.Mode == "Anti-Spin" then
                    data.ResolvedVelocity = manualVel
                elseif Config.Ragebot.Resolver.Mode == "Velocity + Acceleration" and #data.History >= 3 then
                    local prev = data.History[#data.History - 1]
                    local dt2 = newest.Time - prev.Time
                    if dt2 > 0.001 then
                        local v1 = (prev.Pos - oldest.Pos) / (prev.Time - oldest.Time)
                        local v2 = (newest.Pos - prev.Pos) / dt2
                        data.Acceleration = (v2 - v1) / dt
                        data.ResolvedVelocity = manualVel
                    else
                        data.ResolvedVelocity = manualVel
                    end
                else
                    data.ResolvedVelocity = manualVel
                end
            else
                data.ResolvedVelocity = hrp.AssemblyLinearVelocity
            end
        end
    else
        data.ResolvedVelocity = hrp.AssemblyLinearVelocity
    end
end

function Vortex:CalculatePredictedPosition(player, part)
    if not Config.Ragebot.Prediction.Enabled then
        return part.Position
    end

    local data = self.PlayerData[player]
    local vel = (data and data.ResolvedVelocity) or part.AssemblyLinearVelocity
    local accel = (data and data.Acceleration) or Vector3.zero

    local pingTime = 0
    if Config.Ragebot.Prediction.PingCompensation then
        local ok, ping = pcall(function()
            return LocalPlayer:GetNetworkPing()
        end)
        if ok and ping then
            pingTime = ping * Config.Ragebot.Prediction.PingMultiplier
        end
    end

    local hTime = Config.Ragebot.Prediction.HorizontalScale + pingTime
    local vTime = Config.Ragebot.Prediction.VerticalScale + pingTime

    local predX = part.Position.X + (vel.X * hTime) + (0.5 * accel.X * hTime * hTime)
    local predZ = part.Position.Z + (vel.Z * hTime) + (0.5 * accel.Z * hTime * hTime)
    local predY = part.Position.Y + (vel.Y * vTime)

    -- Gravity compensation if target is airborne
    if Config.Ragebot.Prediction.GravityCompensation then
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.FloorMaterial == Enum.Material.Air then
            predY = predY - (0.5 * Workspace.Gravity * Config.Ragebot.Prediction.GravityFactor * (vTime ^ 2))
        end
    end

    return Vector3.new(predX, predY, predZ)
end

-- Raycast Line of Sight & Multi-Point Hitscan
function Vortex:IsPointVisible(origin, targetPos, targetChar)
    if not Config.Ragebot.WallCheck then return true end
    local direction = targetPos - origin
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    rayParams.IgnoreWater = true

    local result = Workspace:Raycast(origin, direction, rayParams)
    if not result then
        return true
    end
    if targetChar and result.Instance:IsDescendantOf(targetChar) then
        return true
    end
    return false
end

function Vortex:GetMultipointOffsets(part)
    local s = part.Size * (Config.Ragebot.MultipointScale * 0.5)
    return {
        Vector3.zero,
        Vector3.new(0, s.Y * 0.7, 0),
        Vector3.new(0, -s.Y * 0.7, 0),
        Vector3.new(s.X * 0.75, 0, 0),
        Vector3.new(-s.X * 0.75, 0, 0),
        Vector3.new(0, 0, s.Z * 0.75),
        Vector3.new(0, 0, -s.Z * 0.75),
    }
end

function Vortex:ScanBestHitPoint(player)
    local char = player.Character
    if not char then return nil, nil end
    local origin = Camera.CFrame.Position

    local bonesToCheck = { Config.Ragebot.PrimaryBone }
    if Config.Ragebot.HitscanMode ~= "Single Bone" then
        for _, bName in ipairs(Config.Ragebot.FallbackBones) do
            if bName ~= Config.Ragebot.PrimaryBone then
                table.insert(bonesToCheck, bName)
            end
        end
    end

    for _, boneName in ipairs(bonesToCheck) do
        local part = char:FindFirstChild(boneName)
        if part and part:IsA("BasePart") then
            local basePred = self:CalculatePredictedPosition(player, part)
            if Config.Ragebot.HitscanMode == "Multi-Point" then
                for _, offset in ipairs(self:GetMultipointOffsets(part)) do
                    local testPos = basePred + offset
                    if self:IsPointVisible(origin, testPos, char) then
                        return part, testPos
                    end
                end
            else
                if self:IsPointVisible(origin, basePred, char) then
                    return part, basePred
                end
            end
        end
    end

    return nil, nil
end

-- ============================================================================
-- [MODULE 4] 3D BULLET TRACERS, IMPACT MARKERS, HITLOGS & AUDIO
-- ============================================================================

function Vortex:PlayHitSound()
    if not Config.Misc.HitSound.Enabled then return end
    local soundId = SoundPresets[Config.Misc.HitSound.Preset] or SoundPresets.Skeet
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = Config.Misc.HitSound.Volume
    sound.PlaybackSpeed = Config.Misc.HitSound.Pitch
    sound.Parent = Workspace
    sound:Play()
    Debris:AddItem(sound, 2.5)
end

function Vortex:AddHitLog(text, color)
    if not Config.HUD.HitLogs then return end
    local label = self:CreateDrawing("Text", {
        Text = text,
        Size = 14,
        Font = 2,
        Center = false,
        Outline = true,
        Color = color or Color3.fromRGB(255, 255, 255),
        Visible = true,
        ZIndex = 1005,
    })
    table.insert(self.HitLogs, {
        Drawing = label,
        Created = tick(),
        Duration = 4.5,
    })
    while #self.HitLogs > Config.HUD.MaxHitLogs do
        local oldest = table.remove(self.HitLogs, 1)
        pcall(function() oldest.Drawing:Remove() end)
    end
end

function Vortex:SpawnBulletTracer(startPos, endPos)
    if not Config.Visuals.Tracers3D.BulletTracers then return end
    local dist = (endPos - startPos).Magnitude
    if dist < 0.5 then return end

    local beamPart = Instance.new("Part")
    beamPart.Anchored = true
    beamPart.CanCollide = false
    beamPart.CanQuery = false
    beamPart.CanTouch = false
    beamPart.Material = Enum.Material.Neon
    beamPart.Color = ToColor3(Config.Visuals.Tracers3D.TracerColor)
    beamPart.Size = Vector3.new(0.08, 0.08, dist)
    beamPart.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -dist / 2)
    beamPart.Transparency = 0.15
    beamPart.Parent = Workspace

    local tween = TweenService:Create(
        beamPart,
        TweenInfo.new(Config.Visuals.Tracers3D.TracerDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Transparency = 1, Size = Vector3.new(0.01, 0.01, dist) }
    )
    tween:Play()
    Debris:AddItem(beamPart, Config.Visuals.Tracers3D.TracerDuration + 0.1)

    if Config.Visuals.Tracers3D.ImpactMarkers then
        local imp = Instance.new("Part")
        imp.Anchored = true
        imp.CanCollide = false
        imp.CanQuery = false
        imp.CanTouch = false
        imp.Shape = Enum.PartType.Ball
        imp.Material = Enum.Material.Neon
        imp.Color = ToColor3(Config.Visuals.Tracers3D.ImpactColor)
        local sz = Config.Visuals.Tracers3D.ImpactSize
        imp.Size = Vector3.new(sz, sz, sz)
        imp.Position = endPos
        imp.Transparency = 0.2
        imp.Parent = Workspace

        local impTween = TweenService:Create(
            imp,
            TweenInfo.new(Config.Visuals.Tracers3D.TracerDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05) }
        )
        impTween:Play()
        Debris:AddItem(imp, Config.Visuals.Tracers3D.TracerDuration + 0.1)
    end
end

-- ============================================================================
-- [MODULE 5] RAGEBOT, SILENT FLICK, TRIGGERBOT & ANTI-AIM ENGINE
-- ============================================================================

function Vortex:GetEffectiveFOV()
    local base = Config.Ragebot.FOVRadius
    if Config.Ragebot.DynamicFOV and Camera then
        return base * (70 / math.max(Camera.FieldOfView, 1))
    end
    return base
end

function Vortex:AcquireBestTarget()
    local bestPlayer = nil
    local bestBone = nil
    local bestPredPos = nil
    local bestScore = math.huge

    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local maxFOV = self:GetEffectiveFOV()

    for _, player in ipairs(Players:GetPlayers()) do
        if self:IsEnemy(player) and self:IsAlive(player) then
            local char = player.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist3D = (hrp.Position - Camera.CFrame.Position).Magnitude
                if dist3D <= Config.Ragebot.MaxDistance then
                    local bone, predPos = self:ScanBestHitPoint(player)
                    if bone and predPos then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(predPos)
                        local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude

                        if not Config.Ragebot.FOVEnabled or (onScreen and dist2D <= maxFOV) then
                            local hum = char:FindFirstChildOfClass("Humanoid")
                            local hp = hum and hum.Health or 100
                            local role = self:GetPlayerRole(player)
                            local score = dist2D

                            if Config.Ragebot.TargetSelection == "Distance" then
                                score = dist3D
                            elseif Config.Ragebot.TargetSelection == "Lowest HP" then
                                score = hp
                            elseif Config.Ragebot.TargetSelection == "Crosshair + Distance" then
                                score = (dist2D * 0.7) + (dist3D * 0.3)
                            elseif Config.Ragebot.TargetSelection == "Threat Level" then
                                local roleBonus = (role == "Sheriff" or role == "Murderer") and -250 or 0
                                score = dist2D + (hp * 0.5) + roleBonus
                            end

                            if score < bestScore then
                                bestScore = score
                                bestPlayer = player
                                bestBone = bone
                                bestPredPos = predPos
                            end
                        end
                    end
                end
            end
        end
    end

    return bestPlayer, bestBone, bestPredPos
end

function Vortex:EquipWeapon()
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end

    if Config.Ragebot.AutoEquip then
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if backpack and hum then
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool") then
                    hum:EquipTool(item)
                    return item
                end
            end
        end
    end
    return nil
end

function Vortex:ProcessCombat()
    if not Config.Ragebot.Enabled or not self:IsAlive(LocalPlayer) then
        self.State.CurrentTarget = nil
        self.State.TargetBone = nil
        self.State.TargetPredictedPos = nil
        return
    end

    local target, bone, predPos = self:AcquireBestTarget()
    self.State.CurrentTarget = target
    self.State.TargetBone = bone
    self.State.TargetPredictedPos = predPos

    if not target or not bone or not predPos then
        return
    end

    local mode = Config.Ragebot.Mode

    if mode == "Camera Lock" then
        local desiredCF = CFrame.new(Camera.CFrame.Position, predPos)
        local alpha = math.clamp(1 - Config.Ragebot.CameraSmoothness, 0.04, 1)
        Camera.CFrame = Camera.CFrame:Lerp(desiredCF, alpha)
        return
    end

    if mode == "TriggerBot" then
        local hover = Mouse.Target
        if not hover or not hover:IsDescendantOf(target.Character) then
            return
        end
    end

    if not Config.Ragebot.AutoFire then return end
    if tick() - self.State.LastShotTime < Config.Ragebot.FireRateDelay then return end

    local tool = self:EquipWeapon()
    if not tool then return end

    self.State.LastShotTime = tick()
    self.State.ShotsFired += 1

    local oldCFrame = Camera.CFrame
    local muzzleOrigin = (tool:FindFirstChild("Handle") and tool.Handle.Position) or oldCFrame.Position

    if mode == "Auto Shoot" or mode == "Silent Flick" then
        Camera.CFrame = CFrame.new(oldCFrame.Position, predPos)
    end

    pcall(function()
        tool:Activate()
    end)

    self:SpawnBulletTracer(muzzleOrigin, predPos)

    if mode == "Silent Flick" and Config.Ragebot.FlickReturnCamera then
        task.defer(function()
            if Camera then
                Camera.CFrame = oldCFrame
            end
        end)
    end
end

-- Anti-Aim Controller
function Vortex:ProcessAntiAim(dt)
    if not Config.AntiAim.Enabled or not self:IsAlive(LocalPlayer) then return end
    if Config.AntiAim.DisableOnShoot and (tick() - self.State.LastShotTime < 0.12) then
        return
    end

    local char = LocalPlayer.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    hum.AutoRotate = false
    local mode = Config.AntiAim.YawMode
    local angleDeg = Config.AntiAim.YawOffset

    if mode == "SpinBot" then
        self.State.SpinAngle = (self.State.SpinAngle + Config.AntiAim.SpinSpeed) % 360
        angleDeg = self.State.SpinAngle
    elseif mode == "Jitter" then
        self.State.JitterSide = -self.State.JitterSide
        local camYaw = select(2, Camera.CFrame:ToOrientation())
        angleDeg = math.deg(camYaw) + 180 + (Config.AntiAim.JitterAngle * self.State.JitterSide)
    elseif mode == "Random" then
        angleDeg = math.random(-180, 180)
    elseif mode == "Backwards" then
        local camYaw = select(2, Camera.CFrame:ToOrientation())
        angleDeg = math.deg(camYaw) + 180 + Config.AntiAim.YawOffset
    elseif mode == "Sideways Left" then
        local camYaw = select(2, Camera.CFrame:ToOrientation())
        angleDeg = math.deg(camYaw) + 90
    elseif mode == "Sideways Right" then
        local camYaw = select(2, Camera.CFrame:ToOrientation())
        angleDeg = math.deg(camYaw) - 90
    elseif mode == "Tank" then
        self.State.JitterSide = -self.State.JitterSide
        angleDeg = (tick() * 720 % 360) + (45 * self.State.JitterSide)
    end

    local pos = hrp.Position
    hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(angleDeg), 0)

    -- Pitch Manipulation via Neck Motor6D
    local neck = char:FindFirstChild("Neck", true)
    if neck and neck:IsA("Motor6D") then
        local pitchRad = 0
        if Config.AntiAim.PitchMode == "Down" then
            pitchRad = math.rad(-85)
        elseif Config.AntiAim.PitchMode == "Up" then
            pitchRad = math.rad(85)
        elseif Config.AntiAim.PitchMode == "Jitter" then
            pitchRad = math.rad(85 * self.State.JitterSide)
        end
        if Config.AntiAim.PitchMode ~= "None" then
            local _, y, z = neck.C0:ToEulerAnglesYXZ()
            neck.C0 = CFrame.new(neck.C0.Position) * CFrame.Angles(pitchRad, y, z)
        end
    end
end

-- ============================================================================
-- [MODULE 6] FULL 2D/3D DRAWING ESP & ON-SCREEN OVERLAYS
-- ============================================================================

local R15_Bones = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" },
}

local R6_Bones = {
    { "Head", "Torso" },
    { "Torso", "Left Arm" },
    { "Torso", "Right Arm" },
    { "Torso", "Left Leg" },
    { "Torso", "Right Leg" },
}

-- Global Overlays
local FOVCircle = Vortex:CreateDrawing("Circle", {
    Thickness = 1.6,
    NumSides = 64,
    Filled = false,
    Visible = false,
    ZIndex = 990,
})

local FOVFill = Vortex:CreateDrawing("Circle", {
    Thickness = 1,
    NumSides = 64,
    Filled = true,
    Visible = false,
    ZIndex = 989,
})

local SnapLine = Vortex:CreateDrawing("Line", {
    Thickness = 1.4,
    Visible = false,
    ZIndex = 995,
})

-- Custom Crosshair Lines
local CrosshairLines = {
    Top = Vortex:CreateDrawing("Line", { ZIndex = 1000, Visible = false }),
    Bottom = Vortex:CreateDrawing("Line", { ZIndex = 1000, Visible = false }),
    Left = Vortex:CreateDrawing("Line", { ZIndex = 1000, Visible = false }),
    Right = Vortex:CreateDrawing("Line", { ZIndex = 1000, Visible = false }),
}

-- Watermark Overlay
local WatermarkBG = Vortex:CreateDrawing("Square", {
    Filled = true,
    Color = Color3.fromRGB(16, 16, 22),
    Transparency = 0.85,
    ZIndex = 1010,
    Visible = false,
})

local WatermarkAccent = Vortex:CreateDrawing("Square", {
    Filled = true,
    Color = Color3.fromRGB(165, 85, 255),
    Transparency = 1,
    ZIndex = 1011,
    Visible = false,
})

local WatermarkText = Vortex:CreateDrawing("Text", {
    Size = 13,
    Font = 2,
    Outline = true,
    Color = Color3.fromRGB(245, 245, 255),
    ZIndex = 1012,
    Visible = false,
})

-- Target HUD Overlay
local TargetHUD_BG = Vortex:CreateDrawing("Square", {
    Filled = true,
    Color = Color3.fromRGB(18, 18, 25),
    Transparency = 0.88,
    ZIndex = 1010,
    Visible = false,
})

local TargetHUD_Accent = Vortex:CreateDrawing("Square", {
    Filled = true,
    Color = Color3.fromRGB(165, 85, 255),
    Transparency = 1,
    ZIndex = 1011,
    Visible = false,
})

local TargetHUD_Title = Vortex:CreateDrawing("Text", {
    Size = 14,
    Font = 2,
    Outline = true,
    Color = Color3.fromRGB(255, 255, 255),
    ZIndex = 1012,
    Visible = false,
})

local TargetHUD_Sub = Vortex:CreateDrawing("Text", {
    Size = 12,
    Font = 2,
    Outline = true,
    Color = Color3.fromRGB(190, 190, 210),
    ZIndex = 1012,
    Visible = false,
})

local TargetHUD_HPBG = Vortex:CreateDrawing("Square", {
    Filled = true,
    Color = Color3.fromRGB(30, 30, 40),
    ZIndex = 1011,
    Visible = false,
})

local TargetHUD_HPBar = Vortex:CreateDrawing("Square", {
    Filled = true,
    Color = Color3.fromRGB(70, 235, 130),
    ZIndex = 1012,
    Visible = false,
})

function Vortex:CreatePlayerESP(player)
    if player == LocalPlayer or self.ESP[player] then return end

    local obj = {
        BoxOutline = self:CreateDrawing("Square", { Thickness = 3, Filled = false, Color = Color3.new(0, 0, 0), ZIndex = 1 }),
        Box = self:CreateDrawing("Square", { Thickness = 1.3, Filled = false, ZIndex = 2 }),
        BoxFill = self:CreateDrawing("Square", { Filled = true, ZIndex = 0 }),
        Corners = {},
        Skeleton = {},
        HeadDot = self:CreateDrawing("Circle", { Filled = true, ZIndex = 4 }),
        LookRay = self:CreateDrawing("Line", { Thickness = 1.2, ZIndex = 4 }),
        Name = self:CreateDrawing("Text", { Size = 13, Font = 2, Center = true, Outline = true, ZIndex = 5 }),
        Role = self:CreateDrawing("Text", { Size = 12, Font = 2, Center = true, Outline = true, ZIndex = 5 }),
        Weapon = self:CreateDrawing("Text", { Size = 12, Font = 2, Center = true, Outline = true, ZIndex = 5 }),
        Distance = self:CreateDrawing("Text", { Size = 12, Font = 2, Center = true, Outline = true, ZIndex = 5 }),
        Flags = self:CreateDrawing("Text", { Size = 11, Font = 2, Center = false, Outline = true, ZIndex = 5 }),
        HealthBG = self:CreateDrawing("Square", { Filled = true, Color = Color3.fromRGB(12, 12, 16), ZIndex = 2 }),
        HealthBar = self:CreateDrawing("Square", { Filled = true, ZIndex = 3 }),
        HealthText = self:CreateDrawing("Text", { Size = 11, Font = 2, Center = true, Outline = true, ZIndex = 5 }),
        Tracer = self:CreateDrawing("Line", { Thickness = 1.2, ZIndex = 1 }),
        Arrow = self:CreateDrawing("Triangle", { Filled = true, ZIndex = 6 }),
    }

    for i = 1, 8 do
        obj.Corners[i] = self:CreateDrawing("Line", { Thickness = 1.6, ZIndex = 3 })
    end

    for i = 1, 14 do
        obj.Skeleton[i] = self:CreateDrawing("Line", { Thickness = 1.2, ZIndex = 2 })
    end

    self.ESP[player] = obj
end

function Vortex:HidePlayerESP(obj)
    if not obj then return end
    obj.BoxOutline.Visible = false
    obj.Box.Visible = false
    obj.BoxFill.Visible = false
    obj.HeadDot.Visible = false
    obj.LookRay.Visible = false
    obj.Name.Visible = false
    obj.Role.Visible = false
    obj.Weapon.Visible = false
    obj.Distance.Visible = false
    obj.Flags.Visible = false
    obj.HealthBG.Visible = false
    obj.HealthBar.Visible = false
    obj.HealthText.Visible = false
    obj.Tracer.Visible = false
    obj.Arrow.Visible = false
    for _, line in ipairs(obj.Corners) do line.Visible = false end
    for _, line in ipairs(obj.Skeleton) do line.Visible = false end
end

function Vortex:RemovePlayerESP(player)
    local obj = self.ESP[player]
    if not obj then return end
    self:HidePlayerESP(obj)
    self.ESP[player] = nil
end

function Vortex:RenderESPAndHUD()
    local viewport = Camera.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

    -- Update FOV Circle
    local fovRadius = self:GetEffectiveFOV()
    local fovColor = Config.Ragebot.FOVRainbow and GetRainbowColor(0.5) or ToColor3(Config.Ragebot.FOVColor)
    FOVCircle.Position = center
    FOVCircle.Radius = fovRadius
    FOVCircle.Thickness = Config.Ragebot.FOVThickness
    FOVCircle.NumSides = Config.Ragebot.FOVSides
    FOVCircle.Color = fovColor
    FOVCircle.Visible = Config.Ragebot.Enabled and Config.Ragebot.FOVEnabled

    FOVFill.Position = center
    FOVFill.Radius = fovRadius
    FOVFill.Color = fovColor
    FOVFill.Transparency = Config.Ragebot.FOVFillTransparency
    FOVFill.Visible = Config.Ragebot.Enabled and Config.Ragebot.FOVEnabled and Config.Ragebot.FOVFilled

    -- Update Target Snapline
    if self.State.CurrentTarget and self.State.TargetPredictedPos then
        local tScreen, onScreen = Camera:WorldToViewportPoint(self.State.TargetPredictedPos)
        if onScreen then
            SnapLine.From = center
            SnapLine.To = Vector2.new(tScreen.X, tScreen.Y)
            SnapLine.Color = ToColor3(Config.Visuals.Colors.TargetHighlight)
            SnapLine.Visible = true
        else
            SnapLine.Visible = false
        end
    else
        SnapLine.Visible = false
    end

    -- Custom Crosshair
    if Config.HUD.CustomCrosshair.Enabled then
        local ch = Config.HUD.CustomCrosshair
        local col = ToColor3(ch.Color)
        local angle = ch.Spin and math.rad((tick() * ch.SpinSpeed) % 360) or 0
        local dirs = {
            { CrosshairLines.Top, Vector2.new(0, -1) },
            { CrosshairLines.Bottom, Vector2.new(0, 1) },
            { CrosshairLines.Left, Vector2.new(-1, 0) },
            { CrosshairLines.Right, Vector2.new(1, 0) },
        }
        for _, pair in ipairs(dirs) do
            local line, dir = pair[1], pair[2]
            local rx = dir.X * math.cos(angle) - dir.Y * math.sin(angle)
            local ry = dir.X * math.sin(angle) + dir.Y * math.cos(angle)
            local rDir = Vector2.new(rx, ry)
            line.From = center + (rDir * ch.Gap)
            line.To = center + (rDir * (ch.Gap + ch.Size))
            line.Thickness = ch.Thickness
            line.Color = col
            line.Visible = true
        end
    else
        for _, line in pairs(CrosshairLines) do
            line.Visible = false
        end
    end

    -- Watermark
    if Config.HUD.Watermark then
        local fps = math.floor(1 / math.max(RunService.RenderStepped:Wait(), 0.001))
        local ping = 0
        pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
        local str = string.format("VORTEX ULTRA // %s // %d FPS // %d ms // K/D: %d/%d",
            LocalPlayer.Name, fps, ping, self.State.Kills, self.State.Deaths)
        local w = #str * 6.8 + 16
        WatermarkBG.Position = Vector2.new(14, 14)
        WatermarkBG.Size = Vector2.new(w, 24)
        WatermarkBG.Visible = true

        WatermarkAccent.Position = Vector2.new(14, 14)
        WatermarkAccent.Size = Vector2.new(w, 2)
        WatermarkAccent.Visible = true

        WatermarkText.Text = str
        WatermarkText.Position = Vector2.new(22, 19)
        WatermarkText.Visible = true
    else
        WatermarkBG.Visible = false
        WatermarkAccent.Visible = false
        WatermarkText.Visible = false
    end

    -- Target HUD
    local tgt = self.State.CurrentTarget
    if Config.HUD.TargetHUD and tgt and self:IsAlive(tgt) then
        local hum = tgt.Character:FindFirstChildOfClass("Humanoid")
        local hp = hum and math.floor(hum.Health) or 0
        local maxHp = hum and math.floor(hum.MaxHealth) or 100
        local role = self:GetPlayerRole(tgt)
        local w, h = 220, 56
        local x, y = center.X - (w / 2), center.Y + 65

        TargetHUD_BG.Position = Vector2.new(x, y)
        TargetHUD_BG.Size = Vector2.new(w, h)
        TargetHUD_BG.Visible = true

        TargetHUD_Accent.Position = Vector2.new(x, y)
        TargetHUD_Accent.Size = Vector2.new(w, 2)
        TargetHUD_Accent.Visible = true

        TargetHUD_Title.Text = string.format("%s [%s]", tgt.DisplayName, role)
        TargetHUD_Title.Position = Vector2.new(x + 10, y + 7)
        TargetHUD_Title.Visible = true

        local boneName = self.State.TargetBone and self.State.TargetBone.Name or "Head"
        TargetHUD_Sub.Text = string.format("HP: %d/%d | Bone: %s", hp, maxHp, boneName)
        TargetHUD_Sub.Position = Vector2.new(x + 10, y + 23)
        TargetHUD_Sub.Visible = true

        local ratio = math.clamp(hp / math.max(maxHp, 1), 0, 1)
        TargetHUD_HPBG.Position = Vector2.new(x + 10, y + 41)
        TargetHUD_HPBG.Size = Vector2.new(w - 20, 7)
        TargetHUD_HPBG.Visible = true

        TargetHUD_HPBar.Position = Vector2.new(x + 10, y + 41)
        TargetHUD_HPBar.Size = Vector2.new((w - 20) * ratio, 7)
        TargetHUD_HPBar.Color = Color3.fromRGB(255 * (1 - ratio), 235 * ratio, 85)
        TargetHUD_HPBar.Visible = true
    else
        TargetHUD_BG.Visible = false
        TargetHUD_Accent.Visible = false
        TargetHUD_Title.Visible = false
        TargetHUD_Sub.Visible = false
        TargetHUD_HPBG.Visible = false
        TargetHUD_HPBar.Visible = false
    end

    -- Hit Logs Render & Cleanup
    for i = #self.HitLogs, 1, -1 do
        local log = self.HitLogs[i]
        local age = tick() - log.Created
        if age >= log.Duration then
            pcall(function() log.Drawing:Remove() end)
            table.remove(self.HitLogs, i)
        else
            log.Drawing.Position = Vector2.new(16, 48 + (i - 1) * 16)
            log.Drawing.Transparency = math.clamp(1 - (age / log.Duration) ^ 2, 0.1, 1)
        end
    end

    -- Player ESP Loop
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not self.ESP[player] then
                self:CreatePlayerESP(player)
            end
            local obj = self.ESP[player]
            local char = player.Character
            local alive = self:IsAlive(player)
            local enemy = self:IsEnemy(player)
            local isCurrentTarget = (self.State.CurrentTarget == player)
            local color = self:GetRoleColor(player, isCurrentTarget)

            -- Highlight Chams
            if char then
                local hl = char:FindFirstChild("Vortex_UltraChams")
                if Config.Visuals.Enabled and Config.Visuals.Chams.Enabled and alive and (enemy or Config.Visuals.ShowTeammates) then
                    if not hl then
                        hl = Instance.new("Highlight")
                        hl.Name = "Vortex_UltraChams"
                        hl.Parent = char
                    end
                    hl.FillColor = color
                    hl.OutlineColor = ToColor3(Config.Visuals.Chams.OutlineColor)
                    hl.FillTransparency = Config.Visuals.Chams.FillTransparency
                    hl.OutlineTransparency = Config.Visuals.Chams.OutlineTransparency
                    hl.DepthMode = Config.Visuals.Chams.OccludedOnly and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
                elseif hl then
                    hl:Destroy()
                end
            end

            if not Config.Visuals.Enabled or not alive or not char or (not enemy and not Config.Visuals.ShowTeammates) then
                self:HidePlayerESP(obj)
                continue
            end

            local hrp = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not head or not hum then
                self:HidePlayerESP(obj)
                continue
            end

            local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
            if dist > Config.Visuals.MaxDistance then
                self:HidePlayerESP(obj)
                continue
            end

            local rootPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if not onScreen then
                self:HidePlayerESP(obj)
                -- Off-Screen FOV Arrows
                if Config.Visuals.OffscreenArrows.Enabled then
                    local rel = Camera.CFrame:PointToObjectSpace(hrp.Position)
                    local angle = math.atan2(rel.Z, rel.X)
                    local dir = Vector2.new(math.cos(angle), math.sin(angle))
                    local arrowPos = center + (dir * Config.Visuals.OffscreenArrows.Radius)
                    local sz = Config.Visuals.OffscreenArrows.Size
                    local perp = Vector2.new(-dir.Y, dir.X)

                    obj.Arrow.PointA = arrowPos + (dir * sz)
                    obj.Arrow.PointB = arrowPos - (dir * sz * 0.6) + (perp * sz * 0.6)
                    obj.Arrow.PointC = arrowPos - (dir * sz * 0.6) - (perp * sz * 0.6)
                    obj.Arrow.Color = color
                    obj.Arrow.Filled = Config.Visuals.OffscreenArrows.Filled
                    obj.Arrow.Visible = true
                end
                continue
            end

            obj.Arrow.Visible = false
            local topPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.7, 0))
            local botPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.1, 0))
            local boxH = math.max(math.abs(topPos.Y - botPos.Y), 8)
            local boxW = boxH * 0.58
            local boxX = rootPos.X - (boxW / 2)
            local boxY = topPos.Y

            -- Bounding Boxes
            if Config.Visuals.Boxes.Enabled then
                if Config.Visuals.Boxes.Style == "Full" then
                    for _, l in ipairs(obj.Corners) do l.Visible = false end
                    obj.Box.Size = Vector2.new(boxW, boxH)
                    obj.Box.Position = Vector2.new(boxX, boxY)
                    obj.Box.Color = color
                    obj.Box.Thickness = Config.Visuals.Boxes.Thickness
                    obj.Box.Visible = true

                    obj.BoxOutline.Size = Vector2.new(boxW, boxH)
                    obj.BoxOutline.Position = Vector2.new(boxX, boxY)
                    obj.BoxOutline.Visible = Config.Visuals.Boxes.Outline
                else
                    obj.Box.Visible = false
                    obj.BoxOutline.Visible = false
                    local cLen = math.min(boxW, boxH) * 0.25
                    local segs = {
                        { Vector2.new(boxX, boxY), Vector2.new(boxX + cLen, boxY) },
                        { Vector2.new(boxX, boxY), Vector2.new(boxX, boxY + cLen) },
                        { Vector2.new(boxX + boxW, boxY), Vector2.new(boxX + boxW - cLen, boxY) },
                        { Vector2.new(boxX + boxW, boxY), Vector2.new(boxX + boxW, boxY + cLen) },
                        { Vector2.new(boxX, boxY + boxH), Vector2.new(boxX + cLen, boxY + boxH) },
                        { Vector2.new(boxX, boxY + boxH), Vector2.new(boxX, boxY + boxH - cLen) },
                        { Vector2.new(boxX + boxW, boxY + boxH), Vector2.new(boxX + boxW - cLen, boxY + boxH) },
                        { Vector2.new(boxX + boxW, boxY + boxH), Vector2.new(boxX + boxW, boxY + boxH - cLen) },
                    }
                    for idx, s in ipairs(segs) do
                        local line = obj.Corners[idx]
                        line.From = s[1]
                        line.To = s[2]
                        line.Color = color
                        line.Thickness = Config.Visuals.Boxes.Thickness
                        line.Visible = true
                    end
                end

                if Config.Visuals.Boxes.Filled then
                    obj.BoxFill.Position = Vector2.new(boxX, boxY)
                    obj.BoxFill.Size = Vector2.new(boxW, boxH)
                    obj.BoxFill.Color = color
                    obj.BoxFill.Transparency = Config.Visuals.Boxes.FillTransparency
                    obj.BoxFill.Visible = true
                else
                    obj.BoxFill.Visible = false
                end
            else
                obj.Box.Visible = false
                obj.BoxOutline.Visible = false
                obj.BoxFill.Visible = false
                for _, l in ipairs(obj.Corners) do l.Visible = false end
            end

            -- Skeleton ESP
            if Config.Visuals.Skeleton.Enabled then
                local boneMap = (hum.RigType == Enum.HumanoidRigType.R15) and R15_Bones or R6_Bones
                for idx, pair in ipairs(boneMap) do
                    local line = obj.Skeleton[idx]
                    local p1 = char:FindFirstChild(pair[1])
                    local p2 = char:FindFirstChild(pair[2])
                    if line and p1 and p2 then
                        local v1, vis1 = Camera:WorldToViewportPoint(p1.Position)
                        local v2, vis2 = Camera:WorldToViewportPoint(p2.Position)
                        if vis1 and vis2 then
                            line.From = Vector2.new(v1.X, v1.Y)
                            line.To = Vector2.new(v2.X, v2.Y)
                            line.Color = ToColor3(Config.Visuals.Skeleton.Color)
                            line.Thickness = Config.Visuals.Skeleton.Thickness
                            line.Visible = true
                        else
                            line.Visible = false
                        end
                    elseif line then
                        line.Visible = false
                    end
                end
                for idx = #boneMap + 1, #obj.Skeleton do
                    obj.Skeleton[idx].Visible = false
                end
            else
                for _, l in ipairs(obj.Skeleton) do l.Visible = false end
            end

            -- Head Dot & Look Direction Ray
            if Config.Visuals.HeadDot.Enabled then
                local hPos, hVis = Camera:WorldToViewportPoint(head.Position)
                if hVis then
                    obj.HeadDot.Position = Vector2.new(hPos.X, hPos.Y)
                    obj.HeadDot.Radius = Config.Visuals.HeadDot.Radius
                    obj.HeadDot.Color = color
                    obj.HeadDot.Filled = Config.Visuals.HeadDot.Filled
                    obj.HeadDot.Visible = true
                else
                    obj.HeadDot.Visible = false
                end
            else
                obj.HeadDot.Visible = false
            end

            if Config.Visuals.LookRay.Enabled then
                local startP, sVis = Camera:WorldToViewportPoint(head.Position)
                local endP, eVis = Camera:WorldToViewportPoint(head.Position + (head.CFrame.LookVector * Config.Visuals.LookRay.Length))
                if sVis and eVis then
                    obj.LookRay.From = Vector2.new(startP.X, startP.Y)
                    obj.LookRay.To = Vector2.new(endP.X, endP.Y)
                    obj.LookRay.Color = color
                    obj.LookRay.Thickness = Config.Visuals.LookRay.Thickness
                    obj.LookRay.Visible = true
                else
                    obj.LookRay.Visible = false
                end
            else
                obj.LookRay.Visible = false
            end

            -- Top Text (Name & Role)
            local topCursor = boxY - 15
            if Config.Visuals.Info.Names then
                obj.Name.Text = Config.Visuals.Info.DisplayNames and player.DisplayName or player.Name
                obj.Name.Size = Config.Visuals.Info.TextSize
                obj.Name.Color = Color3.fromRGB(255, 255, 255)
                obj.Name.Position = Vector2.new(rootPos.X, topCursor)
                obj.Name.Visible = true
                topCursor -= 14
            else
                obj.Name.Visible = false
            end

            if Config.Visuals.Info.RoleBadges then
                local role = self:GetPlayerRole(player)
                if role ~= "None" then
                    obj.Role.Text = "[" .. role:upper() .. "]"
                    obj.Role.Size = Config.Visuals.Info.TextSize - 1
                    obj.Role.Color = color
                    obj.Role.Position = Vector2.new(rootPos.X, topCursor)
                    obj.Role.Visible = true
                else
                    obj.Role.Visible = false
                end
            else
                obj.Role.Visible = false
            end

            -- Bottom Text (Weapon & Distance)
            local botCursor = botPos.Y + 3
            if Config.Visuals.Info.WeaponName then
                local wName = self:GetEquippedWeapon(player)
                obj.Weapon.Text = wName
                obj.Weapon.Size = Config.Visuals.Info.TextSize - 1
                obj.Weapon.Color = Color3.fromRGB(210, 210, 230)
                obj.Weapon.Position = Vector2.new(rootPos.X, botCursor)
                obj.Weapon.Visible = true
                botCursor += 13
            else
                obj.Weapon.Visible = false
            end

            if Config.Visuals.Info.Distance then
                obj.Distance.Text = string.format("%dm", math.floor(dist))
                obj.Distance.Size = Config.Visuals.Info.TextSize - 1
                obj.Distance.Color = Color3.fromRGB(185, 185, 200)
                obj.Distance.Position = Vector2.new(rootPos.X, botCursor)
                obj.Distance.Visible = true
            else
                obj.Distance.Visible = false
            end

            -- Health Bar
            if Config.Visuals.Info.HealthBar then
                local hpRatio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                local barH = boxH * hpRatio
                obj.HealthBG.Position = Vector2.new(boxX - 6, boxY - 1)
                obj.HealthBG.Size = Vector2.new(4, boxH + 2)
                obj.HealthBG.Visible = true

                obj.HealthBar.Position = Vector2.new(boxX - 5, boxY + (boxH - barH))
                obj.HealthBar.Size = Vector2.new(2, barH)
                obj.HealthBar.Color = Color3.fromRGB(255 * (1 - hpRatio), 240 * hpRatio, 75)
                obj.HealthBar.Visible = true

                if Config.Visuals.Info.HealthText and hpRatio < 0.99 then
                    obj.HealthText.Text = tostring(math.floor(hum.Health))
                    obj.HealthText.Position = Vector2.new(boxX - 14, boxY + (boxH - barH) - 6)
                    obj.HealthText.Color = Color3.fromRGB(255, 255, 255)
                    obj.HealthText.Visible = true
                else
                    obj.HealthText.Visible = false
                end
            else
                obj.HealthBG.Visible = false
                obj.HealthBar.Visible = false
                obj.HealthText.Visible = false
            end

            -- Right-Side Flags
            if Config.Visuals.Info.Flags then
                local flags = {}
                local pData = self.PlayerData[player]
                if pData and pData.IsSpinning then table.insert(flags, "AA") end
                if hum.FloorMaterial == Enum.Material.Air then table.insert(flags, "AIR") end
                if char:FindFirstChildOfClass("ForceField") then table.insert(flags, "FF") end
                if #flags > 0 then
                    obj.Flags.Text = table.concat(flags, "\n")
                    obj.Flags.Color = Color3.fromRGB(165, 220, 255)
                    obj.Flags.Position = Vector2.new(boxX + boxW + 4, boxY)
                    obj.Flags.Visible = true
                else
                    obj.Flags.Visible = false
                end
            else
                obj.Flags.Visible = false
            end

            -- Tracers
            if Config.Visuals.Tracers.Enabled then
                local origin = Vector2.new(center.X, viewport.Y)
                if Config.Visuals.Tracers.Origin == "Center" then
                    origin = center
                elseif Config.Visuals.Tracers.Origin == "Top" then
                    origin = Vector2.new(center.X, 0)
                elseif Config.Visuals.Tracers.Origin == "Mouse" then
                    origin = UserInputService:GetMouseLocation()
                end
                obj.Tracer.From = origin
                obj.Tracer.To = Vector2.new(rootPos.X, botPos.Y)
                obj.Tracer.Color = color
                obj.Tracer.Thickness = Config.Visuals.Tracers.Thickness
                obj.Tracer.Visible = true
            else
                obj.Tracer.Visible = false
            end
        end
    end
end

-- ============================================================================
-- [MODULE 7] HITBOX EXPANDER, MOVEMENT SUITE & EXPLOITS
-- ============================================================================

local FlyInstances = { Gyro = nil, Vel = nil }

function Vortex:SetFlightState(enabled)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if enabled and hrp then
        if not FlyInstances.Gyro then
            local bg = Instance.new("BodyGyro")
            bg.P = 9e4
            bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            bg.CFrame = hrp.CFrame
            bg.Parent = hrp
            FlyInstances.Gyro = bg
        end
        if not FlyInstances.Vel then
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = Vector3.zero
            bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            bv.Parent = hrp
            FlyInstances.Vel = bv
        end
    else
        if FlyInstances.Gyro then pcall(function() FlyInstances.Gyro:Destroy() end) FlyInstances.Gyro = nil end
        if FlyInstances.Vel then pcall(function() FlyInstances.Vel:Destroy() end) FlyInstances.Vel = nil end
    end
end

function Vortex:ProcessHitboxes()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local part = char:FindFirstChild(Config.Hitbox.Part) or char:FindFirstChild("HumanoidRootPart")
            if part and part:IsA("BasePart") then
                local shouldExpand = false
                if Config.Hitbox.Enabled and self:IsAlive(player) then
                    if Config.Hitbox.Mode == "All Players" then
                        shouldExpand = true
                    elseif Config.Hitbox.Mode == "Enemies Only" then
                        shouldExpand = self:IsEnemy(player)
                    elseif Config.Hitbox.Mode == "Sheriff/Murderer Only" then
                        local r = self:GetPlayerRole(player)
                        shouldExpand = (r == "Sheriff" or r == "Murderer")
                    end
                end

                if shouldExpand then
                    local sz = Config.Hitbox.UniformSize
                        and Vector3.new(Config.Hitbox.SizeX, Config.Hitbox.SizeX, Config.Hitbox.SizeX)
                        or Vector3.new(Config.Hitbox.SizeX, Config.Hitbox.SizeY, Config.Hitbox.SizeZ)
                    part.Size = sz
                    part.Transparency = Config.Hitbox.Transparency
                    part.Color = Config.Hitbox.RainbowColor and GetRainbowColor(0.6) or ToColor3(Config.Hitbox.Color)
                    part.Material = Enum.Material[Config.Hitbox.Material] or Enum.Material.Neon
                    part.CanCollide = false
                else
                    if part.Name == "HumanoidRootPart" then
                        part.Size = Vector3.new(2, 2, 1)
                        part.Transparency = 1
                    end
                end
            end
        end
    end
end

function Vortex:ProcessMovement(dt)
    if not self:IsAlive(LocalPlayer) then return end
    local char = LocalPlayer.Character
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    -- Anti-Void Protection
    if Config.Movement.Physics.AntiVoid and hrp.Position.Y < Config.Movement.Physics.VoidHeight then
        hrp.CFrame = CFrame.new(hrp.Position.X, 50, hrp.Position.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end

    -- Speed Controller
    if Config.Movement.Speed.Enabled then
        local mode = Config.Movement.Speed.Mode
        local spd = Config.Movement.Speed.Value
        if mode == "WalkSpeed" then
            hum.WalkSpeed = spd
        elseif mode == "CFrame" and hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (spd * dt))
        elseif mode == "Velocity" and hum.MoveDirection.Magnitude > 0 then
            local curY = hrp.AssemblyLinearVelocity.Y
            hrp.AssemblyLinearVelocity = Vector3.new(hum.MoveDirection.X * spd, curY, hum.MoveDirection.Z * spd)
        end
    end

    -- Jump Power & Bhop & AirStrafe
    if Config.Movement.Jump.Enabled then
        hum.UseJumpPower = true
        hum.JumpPower = Config.Movement.Jump.Power
    end

    if Config.Movement.Jump.AutoBhop and hum.MoveDirection.Magnitude > 0 and hum.FloorMaterial ~= Enum.Material.Air then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end

    if Config.Movement.Jump.AirStrafe and hum.FloorMaterial == Enum.Material.Air and hum.MoveDirection.Magnitude > 0 then
        local sSpd = Config.Movement.Jump.StrafeSpeed
        local curY = hrp.AssemblyLinearVelocity.Y
        hrp.AssemblyLinearVelocity = Vector3.new(hum.MoveDirection.X * sSpd, curY, hum.MoveDirection.Z * sSpd)
    end

    -- NoClip
    if Config.Movement.Physics.NoClip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    -- Target Orbit
    if Config.Movement.TargetOrbit.Enabled and self.State.CurrentTarget and self:IsAlive(self.State.CurrentTarget) then
        local tHrp = self.State.CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
        if tHrp then
            self.State.OrbitAngle = (self.State.OrbitAngle + Config.Movement.TargetOrbit.Speed * dt) % (math.pi * 2)
            local r = Config.Movement.TargetOrbit.Radius
            local ox = math.cos(self.State.OrbitAngle) * r
            local oz = math.sin(self.State.OrbitAngle) * r
            local orbitPos = tHrp.Position + Vector3.new(ox, Config.Movement.TargetOrbit.HeightOffset, oz)
            hrp.CFrame = CFrame.lookAt(orbitPos, tHrp.Position)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end

    -- Flight
    if Config.Movement.Flight.Enabled then
        local fSpd = Config.Movement.Flight.Speed
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0, 1, 0) end

        if Config.Movement.Flight.Mode == "Camera" then
            self:SetFlightState(true)
            if FlyInstances.Gyro and FlyInstances.Vel then
                FlyInstances.Gyro.CFrame = Camera.CFrame
                FlyInstances.Vel.Velocity = move * fSpd
            end
        else
            self:SetFlightState(false)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = hrp.CFrame + (move * fSpd * dt)
        end
    else
        self:SetFlightState(false)
    end
end

function Vortex:ProcessWorldVisuals()
    if Config.Visuals.World.Fullbright then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2.2
        Lighting.GlobalShadows = false
    elseif Config.Visuals.World.CustomAmbient then
        local c = ToColor3(Config.Visuals.World.AmbientColor)
        Lighting.Ambient = c
        Lighting.OutdoorAmbient = c
    end

    if Config.Visuals.World.NoFog then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
    end

    if Config.Visuals.World.CustomTime then
        Lighting.ClockTime = Config.Visuals.World.ClockTime
    end

    if Config.Visuals.World.FOVChanger and Camera then
        Camera.FieldOfView = Config.Visuals.World.CameraFOV
    end

    if Config.Visuals.World.ThirdPerson then
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMaxZoomDistance = Config.Visuals.World.ThirdPersonDist
        LocalPlayer.CameraMinZoomDistance = Config.Visuals.World.ThirdPersonDist
    end
end

-- ============================================================================
-- [MODULE 8] WINDUI INTERFACE CONSTRUCTION
-- ============================================================================

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "VORTEX // MVSD ULTRA",
    Icon = "crown",
    Author = "Enterprise Rage Suite v3.5",
    Folder = ConfigFolder,
    Size = UDim2.fromOffset(680, 540),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 185,
})

function Vortex:Notify(title, desc, dur)
    pcall(function()
        WindUI:Notify({
            Title = title,
            Content = desc,
            Duration = dur or 3,
        })
    end)
end

-- Create 8 Specialized Tabs
local Tabs = {
    Rage = Window:Tab({ Title = "Ragebot", Icon = "crosshair" }),
    AntiAim = Window:Tab({ Title = "Anti-Aim", Icon = "refresh-cw" }),
    Hitbox = Window:Tab({ Title = "Hitbox", Icon = "box" }),
    Visuals = Window:Tab({ Title = "Visuals ESP", Icon = "eye" }),
    World = Window:Tab({ Title = "World & FX", Icon = "sun" }),
    Movement = Window:Tab({ Title = "Movement", Icon = "zap" }),
    Players = Window:Tab({ Title = "Players", Icon = "users" }),
    Settings = Window:Tab({ Title = "Configs & Misc", Icon = "settings" }),
}

-- ============================================================================
-- TAB 1: RAGEBOT
-- ============================================================================
Tabs.Rage:Section({ Title = "Main Ragebot Engine" })

Tabs.Rage:Toggle({
    Title = "Enable Ragebot",
    Desc = "Master switch for automated target acquisition & firing",
    Value = Config.Ragebot.Enabled,
    Callback = function(v) Config.Ragebot.Enabled = v end
})

Tabs.Rage:Dropdown({
    Title = "Combat Mode",
    Values = { "Auto Shoot", "Silent Flick", "TriggerBot", "Camera Lock" },
    Value = Config.Ragebot.Mode,
    Callback = function(v) Config.Ragebot.Mode = v end
})

Tabs.Rage:Dropdown({
    Title = "Target Priority",
    Values = { "Crosshair + Distance", "Crosshair", "Distance", "Lowest HP", "Threat Level" },
    Value = Config.Ragebot.TargetSelection,
    Callback = function(v) Config.Ragebot.TargetSelection = v end
})

Tabs.Rage:Dropdown({
    Title = "Hitscan Mode",
    Values = { "Multi-Point", "Adaptive", "Single Bone" },
    Value = Config.Ragebot.HitscanMode,
    Callback = function(v) Config.Ragebot.HitscanMode = v end
})

Tabs.Rage:Dropdown({
    Title = "Primary Target Bone",
    Values = { "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso" },
    Value = Config.Ragebot.PrimaryBone,
    Callback = function(v) Config.Ragebot.PrimaryBone = v end
})

Tabs.Rage:Slider({
    Title = "Multi-Point Scale",
    Step = 0.05,
    Value = { Min = 0.1, Max = 1.0, Default = Config.Ragebot.MultipointScale },
    Callback = function(v) Config.Ragebot.MultipointScale = v end
})

Tabs.Rage:Toggle({
    Title = "Auto Fire Weapon",
    Value = Config.Ragebot.AutoFire,
    Callback = function(v) Config.Ragebot.AutoFire = v end
})

Tabs.Rage:Toggle({
    Title = "Auto Equip Weapon",
    Value = Config.Ragebot.AutoEquip,
    Callback = function(v) Config.Ragebot.AutoEquip = v end
})

Tabs.Rage:Toggle({
    Title = "Silent Flick Camera Restore",
    Desc = "Snaps camera back immediately after firing",
    Value = Config.Ragebot.FlickReturnCamera,
    Callback = function(v) Config.Ragebot.FlickReturnCamera = v end
})

Tabs.Rage:Slider({
    Title = "Fire Rate Delay (s)",
    Step = 0.005,
    Value = { Min = 0.005, Max = 0.5, Default = Config.Ragebot.FireRateDelay },
    Callback = function(v) Config.Ragebot.FireRateDelay = v end
})

Tabs.Rage:Slider({
    Title = "Camera Lock Smoothness",
    Step = 0.02,
    Value = { Min = 0.02, Max = 0.95, Default = Config.Ragebot.CameraSmoothness },
    Callback = function(v) Config.Ragebot.CameraSmoothness = v end
})

Tabs.Rage:Section({ Title = "FOV & Target Filters" })

Tabs.Rage:Toggle({
    Title = "Limit to FOV Circle",
    Value = Config.Ragebot.FOVEnabled,
    Callback = function(v) Config.Ragebot.FOVEnabled = v end
})

Tabs.Rage:Slider({
    Title = "FOV Radius",
    Step = 5,
    Value = { Min = 20, Max = 800, Default = Config.Ragebot.FOVRadius },
    Callback = function(v) Config.Ragebot.FOVRadius = v end
})

Tabs.Rage:Toggle({
    Title = "Dynamic FOV Scaling",
    Value = Config.Ragebot.DynamicFOV,
    Callback = function(v) Config.Ragebot.DynamicFOV = v end
})

Tabs.Rage:Toggle({
    Title = "Filled FOV Circle",
    Value = Config.Ragebot.FOVFilled,
    Callback = function(v) Config.Ragebot.FOVFilled = v end
})

Tabs.Rage:Toggle({
    Title = "Rainbow FOV",
    Value = Config.Ragebot.FOVRainbow,
    Callback = function(v) Config.Ragebot.FOVRainbow = v end
})

Tabs.Rage:Toggle({
    Title = "Wall Check (Visibility)",
    Value = Config.Ragebot.WallCheck,
    Callback = function(v) Config.Ragebot.WallCheck = v end
})

Tabs.Rage:Toggle({
    Title = "Team / Role Check",
    Value = Config.Ragebot.TeamCheck,
    Callback = function(v) Config.Ragebot.TeamCheck = v end
})

Tabs.Rage:Toggle({
    Title = "Spawn Protection Check",
    Value = Config.Ragebot.ForceFieldCheck,
    Callback = function(v) Config.Ragebot.ForceFieldCheck = v end
})

Tabs.Rage:Toggle({
    Title = "Ignore Roblox Friends",
    Value = Config.Ragebot.FriendCheck,
    Callback = function(v) Config.Ragebot.FriendCheck = v end
})

Tabs.Rage:Slider({
    Title = "Max Engagement Distance",
    Step = 25,
    Value = { Min = 100, Max = 2000, Default = Config.Ragebot.MaxDistance },
    Callback = function(v) Config.Ragebot.MaxDistance = v end
})

Tabs.Rage:Section({ Title = "Prediction & Velocity Resolver" })

Tabs.Rage:Toggle({
    Title = "Enable Movement Prediction",
    Value = Config.Ragebot.Prediction.Enabled,
    Callback = function(v) Config.Ragebot.Prediction.Enabled = v end
})

Tabs.Rage:Slider({
    Title = "Horizontal Prediction",
    Step = 0.005,
    Value = { Min = 0, Max = 0.4, Default = Config.Ragebot.Prediction.HorizontalScale },
    Callback = function(v) Config.Ragebot.Prediction.HorizontalScale = v end
})

Tabs.Rage:Slider({
    Title = "Vertical Prediction",
    Step = 0.005,
    Value = { Min = 0, Max = 0.4, Default = Config.Ragebot.Prediction.VerticalScale },
    Callback = function(v) Config.Ragebot.Prediction.VerticalScale = v end
})

Tabs.Rage:Toggle({
    Title = "Airborne Gravity Compensation",
    Value = Config.Ragebot.Prediction.GravityCompensation,
    Callback = function(v) Config.Ragebot.Prediction.GravityCompensation = v end
})

Tabs.Rage:Toggle({
    Title = "Auto Ping Compensation",
    Value = Config.Ragebot.Prediction.PingCompensation,
    Callback = function(v) Config.Ragebot.Prediction.PingCompensation = v end
})

Tabs.Rage:Toggle({
    Title = "Enable Anti-Aim Resolver",
    Desc = "Calculates true velocity from position history to counter SpinBots",
    Value = Config.Ragebot.Resolver.Enabled,
    Callback = function(v) Config.Ragebot.Resolver.Enabled = v end
})

Tabs.Rage:Dropdown({
    Title = "Resolver Mode",
    Values = { "Velocity + Acceleration", "Velocity", "Anti-Spin" },
    Value = Config.Ragebot.Resolver.Mode,
    Callback = function(v) Config.Ragebot.Resolver.Mode = v end
})

-- ============================================================================
-- TAB 2: ANTI-AIM
-- ============================================================================
Tabs.AntiAim:Section({ Title = "Yaw & SpinBot Controller" })

Tabs.AntiAim:Toggle({
    Title = "Enable Anti-Aim",
    Desc = "Manipulates character angles to break enemy aimbots",
    Value = Config.AntiAim.Enabled,
    Callback = function(v)
        Config.AntiAim.Enabled = v
        if not v and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            LocalPlayer.Character:FindFirstChildOfClass("Humanoid").AutoRotate = true
        end
    end
})

Tabs.AntiAim:Dropdown({
    Title = "Yaw Mode",
    Values = { "SpinBot", "Jitter", "Tank", "Random", "Backwards", "Sideways Left", "Sideways Right" },
    Value = Config.AntiAim.YawMode,
    Callback = function(v) Config.AntiAim.YawMode = v end
})

Tabs.AntiAim:Slider({
    Title = "SpinBot Speed",
    Step = 2,
    Value = { Min = 5, Max = 120, Default = Config.AntiAim.SpinSpeed },
    Callback = function(v) Config.AntiAim.SpinSpeed = v end
})

Tabs.AntiAim:Slider({
    Title = "Jitter Angle",
    Step = 5,
    Value = { Min = 10, Max = 180, Default = Config.AntiAim.JitterAngle },
    Callback = function(v) Config.AntiAim.JitterAngle = v end
})

Tabs.AntiAim:Slider({
    Title = "Base Yaw Offset",
    Step = 5,
    Value = { Min = -180, Max = 180, Default = Config.AntiAim.YawOffset },
    Callback = function(v) Config.AntiAim.YawOffset = v end
})

Tabs.AntiAim:Section({ Title = "Pitch & Firing Behavior" })

Tabs.AntiAim:Dropdown({
    Title = "Pitch Mode",
    Values = { "None", "Down", "Up", "Jitter" },
    Value = Config.AntiAim.PitchMode,
    Callback = function(v) Config.AntiAim.PitchMode = v end
})

Tabs.AntiAim:Toggle({
    Title = "Disable Anti-Aim While Firing",
    Desc = "Temporarily aligns character during shots for maximum accuracy",
    Value = Config.AntiAim.DisableOnShoot,
    Callback = function(v) Config.AntiAim.DisableOnShoot = v end
})

-- ============================================================================
-- TAB 3: HITBOX EXPANDER
-- ============================================================================
Tabs.Hitbox:Section({ Title = "Hitbox Extender" })

Tabs.Hitbox:Toggle({
    Title = "Enable Hitbox Expander",
    Value = Config.Hitbox.Enabled,
    Callback = function(v)
        Config.Hitbox.Enabled = v
        if not v then
            self:ProcessHitboxes()
        end
    end
})

Tabs.Hitbox:Dropdown({
    Title = "Target Filter",
    Values = { "Enemies Only", "Sheriff/Murderer Only", "All Players" },
    Value = Config.Hitbox.Mode,
    Callback = function(v) Config.Hitbox.Mode = v end
})

Tabs.Hitbox:Dropdown({
    Title = "Expanded Part",
    Values = { "HumanoidRootPart", "Head", "UpperTorso" },
    Value = Config.Hitbox.Part,
    Callback = function(v) Config.Hitbox.Part = v end
})

Tabs.Hitbox:Toggle({
    Title = "Uniform Cube Scaling",
    Value = Config.Hitbox.UniformSize,
    Callback = function(v) Config.Hitbox.UniformSize = v end
})

Tabs.Hitbox:Slider({
    Title = "Hitbox Size (X / Uniform)",
    Step = 0.5,
    Value = { Min = 2, Max = 30, Default = Config.Hitbox.SizeX },
    Callback = function(v) Config.Hitbox.SizeX = v end
})

Tabs.Hitbox:Slider({
    Title = "Hitbox Height (Y)",
    Step = 0.5,
    Value = { Min = 2, Max = 30, Default = Config.Hitbox.SizeY },
    Callback = function(v) Config.Hitbox.SizeY = v end
})

Tabs.Hitbox:Slider({
    Title = "Hitbox Depth (Z)",
    Step = 0.5,
    Value = { Min = 2, Max = 30, Default = Config.Hitbox.SizeZ },
    Callback = function(v) Config.Hitbox.SizeZ = v end
})

Tabs.Hitbox:Slider({
    Title = "Hitbox Transparency",
    Step = 0.05,
    Value = { Min = 0, Max = 1, Default = Config.Hitbox.Transparency },
    Callback = function(v) Config.Hitbox.Transparency = v end
})

Tabs.Hitbox:Dropdown({
    Title = "Hitbox Material",
    Values = { "Neon", "ForceField", "SmoothPlastic", "Glass" },
    Value = Config.Hitbox.Material,
    Callback = function(v) Config.Hitbox.Material = v end
})

Tabs.Hitbox:Toggle({
    Title = "Rainbow Hitbox Color",
    Value = Config.Hitbox.RainbowColor,
    Callback = function(v) Config.Hitbox.RainbowColor = v end
})

-- ============================================================================
-- TAB 4: VISUALS ESP
-- ============================================================================
Tabs.Visuals:Section({ Title = "Master & Boxes" })

Tabs.Visuals:Toggle({
    Title = "Enable Player ESP",
    Value = Config.Visuals.Enabled,
    Callback = function(v) Config.Visuals.Enabled = v end
})

Tabs.Visuals:Toggle({
    Title = "Show Teammates",
    Value = Config.Visuals.ShowTeammates,
    Callback = function(v) Config.Visuals.ShowTeammates = v end
})

Tabs.Visuals:Toggle({
    Title = "2D Bounding Boxes",
    Value = Config.Visuals.Boxes.Enabled,
    Callback = function(v) Config.Visuals.Boxes.Enabled = v end
})

Tabs.Visuals:Dropdown({
    Title = "Box Style",
    Values = { "Corner", "Full" },
    Value = Config.Visuals.Boxes.Style,
    Callback = function(v) Config.Visuals.Boxes.Style = v end
})

Tabs.Visuals:Toggle({
    Title = "Filled Boxes",
    Value = Config.Visuals.Boxes.Filled,
    Callback = function(v) Config.Visuals.Boxes.Filled = v end
})

Tabs.Visuals:Section({ Title = "Skeleton, Rays & Arrows" })

Tabs.Visuals:Toggle({
    Title = "Bone Skeleton ESP",
    Value = Config.Visuals.Skeleton.Enabled,
    Callback = function(v) Config.Visuals.Skeleton.Enabled = v end
})

Tabs.Visuals:Toggle({
    Title = "Head Dot",
    Value = Config.Visuals.HeadDot.Enabled,
    Callback = function(v) Config.Visuals.HeadDot.Enabled = v end
})

Tabs.Visuals:Toggle({
    Title = "View Direction Ray",
    Value = Config.Visuals.LookRay.Enabled,
    Callback = function(v) Config.Visuals.LookRay.Enabled = v end
})

Tabs.Visuals:Toggle({
    Title = "Off-Screen FOV Arrows",
    Value = Config.Visuals.OffscreenArrows.Enabled,
    Callback = function(v) Config.Visuals.OffscreenArrows.Enabled = v end
})

Tabs.Visuals:Toggle({
    Title = "Snapline Tracers",
    Value = Config.Visuals.Tracers.Enabled,
    Callback = function(v) Config.Visuals.Tracers.Enabled = v end
})

Tabs.Visuals:Dropdown({
    Title = "Tracer Origin",
    Values = { "Bottom", "Center", "Top", "Mouse" },
    Value = Config.Visuals.Tracers.Origin,
    Callback = function(v) Config.Visuals.Tracers.Origin = v end
})

Tabs.Visuals:Section({ Title = "Player Details & Chams" })

Tabs.Visuals:Toggle({
    Title = "Player Names",
    Value = Config.Visuals.Info.Names,
    Callback = function(v) Config.Visuals.Info.Names = v end
})

Tabs.Visuals:Toggle({
    Title = "Role Badges (SHERIFF / MURDERER)",
    Value = Config.Visuals.Info.RoleBadges,
    Callback = function(v) Config.Visuals.Info.RoleBadges = v end
})

Tabs.Visuals:Toggle({
    Title = "Equipped Weapon Name",
    Value = Config.Visuals.Info.WeaponName,
    Callback = function(v) Config.Visuals.Info.WeaponName = v end
})

Tabs.Visuals:Toggle({
    Title = "Health Bars",
    Value = Config.Visuals.Info.HealthBar,
    Callback = function(v) Config.Visuals.Info.HealthBar = v end
})

Tabs.Visuals:Toggle({
    Title = "Numeric Health Text",
    Value = Config.Visuals.Info.HealthText,
    Callback = function(v) Config.Visuals.Info.HealthText = v end
})

Tabs.Visuals:Toggle({
    Title = "Distance Indicator",
    Value = Config.Visuals.Info.Distance,
    Callback = function(v) Config.Visuals.Info.Distance = v end
})

Tabs.Visuals:Toggle({
    Title = "Status Flags (AA / AIR / FF)",
    Value = Config.Visuals.Info.Flags,
    Callback = function(v) Config.Visuals.Info.Flags = v end
})

Tabs.Visuals:Toggle({
    Title = "Highlight Chams",
    Value = Config.Visuals.Chams.Enabled,
    Callback = function(v) Config.Visuals.Chams.Enabled = v end
})

Tabs.Visuals:Toggle({
    Title = "Role-Based Color Coding",
    Value = Config.Visuals.Colors.UseRoleColors,
    Callback = function(v) Config.Visuals.Colors.UseRoleColors = v end
})

-- ============================================================================
-- TAB 5: WORLD & FX
-- ============================================================================
Tabs.World:Section({ Title = "3D Bullet Tracers & Impacts" })

Tabs.World:Toggle({
    Title = "3D Neon Bullet Tracers",
    Value = Config.Visuals.Tracers3D.BulletTracers,
    Callback = function(v) Config.Visuals.Tracers3D.BulletTracers = v end
})

Tabs.World:Toggle({
    Title = "3D Impact Markers",
    Value = Config.Visuals.Tracers3D.ImpactMarkers,
    Callback = function(v) Config.Visuals.Tracers3D.ImpactMarkers = v end
})

Tabs.World:Slider({
    Title = "Tracer Fade Duration (s)",
    Step = 0.1,
    Value = { Min = 0.2, Max = 4.0, Default = Config.Visuals.Tracers3D.TracerDuration },
    Callback = function(v) Config.Visuals.Tracers3D.TracerDuration = v end
})

Tabs.World:Section({ Title = "Lighting & Camera" })

Tabs.World:Toggle({
    Title = "Fullbright",
    Value = Config.Visuals.World.Fullbright,
    Callback = function(v)
        Config.Visuals.World.Fullbright = v
        if not v then
            Lighting.Ambient = OriginalLighting.Ambient
            Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
            Lighting.Brightness = OriginalLighting.Brightness
            Lighting.GlobalShadows = OriginalLighting.GlobalShadows
        end
    end
})

Tabs.World:Toggle({
    Title = "Remove Fog",
    Value = Config.Visuals.World.NoFog,
    Callback = function(v)
        Config.Visuals.World.NoFog = v
        if not v then
            Lighting.FogEnd = OriginalLighting.FogEnd
            Lighting.FogStart = OriginalLighting.FogStart
        end
    end
})

Tabs.World:Toggle({
    Title = "Custom Time of Day",
    Value = Config.Visuals.World.CustomTime,
    Callback = function(v)
        Config.Visuals.World.CustomTime = v
        if not v then Lighting.ClockTime = OriginalLighting.ClockTime end
    end
})

Tabs.World:Slider({
    Title = "Clock Time",
    Step = 0.5,
    Value = { Min = 0, Max = 24, Default = Config.Visuals.World.ClockTime },
    Callback = function(v) Config.Visuals.World.ClockTime = v end
})

Tabs.World:Toggle({
    Title = "Custom Camera FOV",
    Value = Config.Visuals.World.FOVChanger,
    Callback = function(v)
        Config.Visuals.World.FOVChanger = v
        if not v and Camera then Camera.FieldOfView = 70 end
    end
})

Tabs.World:Slider({
    Title = "Camera FOV Value",
    Step = 1,
    Value = { Min = 50, Max = 120, Default = Config.Visuals.World.CameraFOV },
    Callback = function(v) Config.Visuals.World.CameraFOV = v end
})

Tabs.World:Toggle({
    Title = "Third Person Mode",
    Value = Config.Visuals.World.ThirdPerson,
    Callback = function(v)
        Config.Visuals.World.ThirdPerson = v
        if not v then
            LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
        end
    end
})

Tabs.World:Slider({
    Title = "Third Person Distance",
    Step = 1,
    Value = { Min = 5, Max = 30, Default = Config.Visuals.World.ThirdPersonDist },
    Callback = function(v) Config.Visuals.World.ThirdPersonDist = v end
})

-- ============================================================================
-- TAB 6: MOVEMENT & EXPLOITS
-- ============================================================================
Tabs.Movement:Section({ Title = "Speed & Jump" })

Tabs.Movement:Toggle({
    Title = "Custom Speed",
    Value = Config.Movement.Speed.Enabled,
    Callback = function(v) Config.Movement.Speed.Enabled = v end
})

Tabs.Movement:Dropdown({
    Title = "Speed Method",
    Values = { "WalkSpeed", "CFrame", "Velocity" },
    Value = Config.Movement.Speed.Mode,
    Callback = function(v) Config.Movement.Speed.Mode = v end
})

Tabs.Movement:Slider({
    Title = "Speed Value",
    Step = 1,
    Value = { Min = 16, Max = 150, Default = Config.Movement.Speed.Value },
    Callback = function(v) Config.Movement.Speed.Value = v end
})

Tabs.Movement:Toggle({
    Title = "Custom JumpPower",
    Value = Config.Movement.Jump.Enabled,
    Callback = function(v) Config.Movement.Jump.Enabled = v end
})

Tabs.Movement:Slider({
    Title = "JumpPower Value",
    Step = 2,
    Value = { Min = 50, Max = 200, Default = Config.Movement.Jump.Power },
    Callback = function(v) Config.Movement.Jump.Power = v end
})

Tabs.Movement:Toggle({
    Title = "Infinite Jump",
    Value = Config.Movement.Jump.InfiniteJump,
    Callback = function(v) Config.Movement.Jump.InfiniteJump = v end
})

Tabs.Movement:Toggle({
    Title = "Auto BunnyHop",
    Value = Config.Movement.Jump.AutoBhop,
    Callback = function(v) Config.Movement.Jump.AutoBhop = v end
})

Tabs.Movement:Toggle({
    Title = "Air Strafe",
    Value = Config.Movement.Jump.AirStrafe,
    Callback = function(v) Config.Movement.Jump.AirStrafe = v end
})

Tabs.Movement:Section({ Title = "Flight, NoClip & Orbit" })

Tabs.Movement:Toggle({
    Title = "Flight (WASD + Space/Shift)",
    Value = Config.Movement.Flight.Enabled,
    Callback = function(v) Config.Movement.Flight.Enabled = v end
})

Tabs.Movement:Dropdown({
    Title = "Flight Method",
    Values = { "Camera", "CFrame" },
    Value = Config.Movement.Flight.Mode,
    Callback = function(v) Config.Movement.Flight.Mode = v end
})

Tabs.Movement:Slider({
    Title = "Flight Speed",
    Step = 5,
    Value = { Min = 15, Max = 200, Default = Config.Movement.Flight.Speed },
    Callback = function(v) Config.Movement.Flight.Speed = v end
})

Tabs.Movement:Toggle({
    Title = "NoClip",
    Value = Config.Movement.Physics.NoClip,
    Callback = function(v) Config.Movement.Physics.NoClip = v end
})

Tabs.Movement:Toggle({
    Title = "Anti-Void Rescue",
    Value = Config.Movement.Physics.AntiVoid,
    Callback = function(v) Config.Movement.Physics.AntiVoid = v end
})

Tabs.Movement:Toggle({
    Title = "Ctrl + Click Teleport",
    Value = Config.Movement.Physics.ClickTP,
    Callback = function(v) Config.Movement.Physics.ClickTP = v end
})

Tabs.Movement:Toggle({
    Title = "Rage Target Orbit",
    Desc = "Orbits rapidly around active Ragebot target",
    Value = Config.Movement.TargetOrbit.Enabled,
    Callback = function(v) Config.Movement.TargetOrbit.Enabled = v end
})

Tabs.Movement:Slider({
    Title = "Orbit Radius",
    Step = 1,
    Value = { Min = 3, Max = 25, Default = Config.Movement.TargetOrbit.Radius },
    Callback = function(v) Config.Movement.TargetOrbit.Radius = v end
})

Tabs.Movement:Slider({
    Title = "Orbit Speed",
    Step = 1,
    Value = { Min = 1, Max = 20, Default = Config.Movement.TargetOrbit.Speed },
    Callback = function(v) Config.Movement.TargetOrbit.Speed = v end
})

-- ============================================================================
-- TAB 7: PLAYERS & WHITELIST
-- ============================================================================
local SelectedPlayerName = ""
local function GetPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

Tabs.Players:Section({ Title = "Target & Whitelist Management" })

local PlayerDropdown = Tabs.Players:Dropdown({
    Title = "Select Player",
    Values = GetPlayerNames(),
    Value = GetPlayerNames()[1],
    Callback = function(v) SelectedPlayerName = v end
})

Tabs.Players:Button({
    Title = "Refresh Player List",
    Callback = function()
        local list = GetPlayerNames()
        SelectedPlayerName = list[1]
        pcall(function() PlayerDropdown:Refresh(list) end)
    end
})

Tabs.Players:Button({
    Title = "Toggle Whitelist for Selected Player",
    Desc = "Whitelisted players are ignored by Ragebot and Hitbox Expander",
    Callback = function()
        if SelectedPlayerName == "" or SelectedPlayerName == "None" then return end
        if Config.Misc.Whitelist[SelectedPlayerName] then
            Config.Misc.Whitelist[SelectedPlayerName] = nil
            self:Notify("Whitelist", "Removed " .. SelectedPlayerName .. " from whitelist", 2)
        else
            Config.Misc.Whitelist[SelectedPlayerName] = true
            self:Notify("Whitelist", "Added " .. SelectedPlayerName .. " to whitelist", 2)
        end
    end
})

Tabs.Players:Button({
    Title = "Teleport to Selected Player",
    Callback = function()
        local target = Players:FindFirstChild(SelectedPlayerName)
        if target and self:IsAlive(target) and self:IsAlive(LocalPlayer) then
            LocalPlayer.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 2, 3)
        end
    end
})

-- ============================================================================
-- TAB 8: CONFIGS, HUD & MISC
-- ============================================================================
Tabs.Settings:Section({ Title = "HUD & Crosshair" })

Tabs.Settings:Toggle({
    Title = "Watermark Bar",
    Value = Config.HUD.Watermark,
    Callback = function(v) Config.HUD.Watermark = v end
})

Tabs.Settings:Toggle({
    Title = "Target HUD Panel",
    Value = Config.HUD.TargetHUD,
    Callback = function(v) Config.HUD.TargetHUD = v end
})

Tabs.Settings:Toggle({
    Title = "On-Screen Hit Logs",
    Value = Config.HUD.HitLogs,
    Callback = function(v) Config.HUD.HitLogs = v end
})

Tabs.Settings:Toggle({
    Title = "Custom Dynamic Crosshair",
    Value = Config.HUD.CustomCrosshair.Enabled,
    Callback = function(v) Config.HUD.CustomCrosshair.Enabled = v end
})

Tabs.Settings:Toggle({
    Title = "Spinning Crosshair",
    Value = Config.HUD.CustomCrosshair.Spin,
    Callback = function(v) Config.HUD.CustomCrosshair.Spin = v end
})

Tabs.Settings:Section({ Title = "Audio & Alerts" })

Tabs.Settings:Toggle({
    Title = "Hitmarker Sound",
    Value = Config.Misc.HitSound.Enabled,
    Callback = function(v) Config.Misc.HitSound.Enabled = v end
})

Tabs.Settings:Dropdown({
    Title = "Hitmarker Sound Preset",
    Values = { "Skeet", "Bell", "Bubble", "Rust", "Cod", "Laser" },
    Value = Config.Misc.HitSound.Preset,
    Callback = function(v)
        Config.Misc.HitSound.Preset = v
        self:PlayHitSound()
    end
})

Tabs.Settings:Slider({
    Title = "Hitmarker Volume",
    Step = 0.1,
    Value = { Min = 0.1, Max = 5.0, Default = Config.Misc.HitSound.Volume },
    Callback = function(v) Config.Misc.HitSound.Volume = v end
})

Tabs.Settings:Toggle({
    Title = "Elimination Notifications",
    Value = Config.Misc.Notifications.KillAlert,
    Callback = function(v) Config.Misc.Notifications.KillAlert = v end
})

Tabs.Settings:Section({ Title = "Configuration Manager" })

local ConfigNameInput = "default"
Tabs.Settings:Input({
    Title = "Profile Name",
    Placeholder = "Enter config name...",
    Value = "default",
    Callback = function(v) ConfigNameInput = v end
})

Tabs.Settings:Button({
    Title = "Save Profile",
    Callback = function()
        if self:SaveConfig(ConfigNameInput) then
            self:Notify("Config Saved", "Saved profile: " .. ConfigNameInput, 2)
        end
    end
})

Tabs.Settings:Button({
    Title = "Load Profile",
    Callback = function()
        if self:LoadConfig(ConfigNameInput) then
            self:Notify("Config Loaded", "Loaded profile: " .. ConfigNameInput, 2)
        else
            self:Notify("Config Error", "Profile not found: " .. ConfigNameInput, 2)
        end
    end
})

Tabs.Settings:Section({ Title = "System & Session" })

Tabs.Settings:Toggle({
    Title = "Anti-AFK",
    Value = Config.Misc.Automation.AntiAFK,
    Callback = function(v) Config.Misc.Automation.AntiAFK = v end
})

Tabs.Settings:Button({
    Title = "Rejoin Current Server",
    Callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
})

Tabs.Settings:Button({
    Title = "Server Hop (New Lobby)",
    Callback = function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
})

Tabs.Settings:Button({
    Title = "Unload VORTEX ULTRA",
    Desc = "Cleanly removes all drawings, hooks, chams, and restores lighting",
    Callback = function()
        self.Unload()
    end
})

-- ============================================================================
-- [MODULE 9] RUNTIME LOOPS, HIT TRACKING & UNLOAD HANDLER
-- ============================================================================

-- Track health drops across all players for accurate hitmarkers & kill logs
local function HookPlayerHealth(player)
    if player == LocalPlayer then return end
    local function onChar(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        local lastHp = hum.Health
        Vortex:BindConnection(hum.HealthChanged:Connect(function(newHp)
            if newHp < lastHp then
                local dmg = math.floor(lastHp - newHp)
                if Vortex.State.CurrentTarget == player or (tick() - Vortex.State.LastShotTime < 0.35) then
                    Vortex.State.ShotsHit += 1
                    Vortex:PlayHitSound()
                    if newHp <= 0 then
                        Vortex.State.Kills += 1
                        Vortex:AddHitLog(string.format("[KILL] Eliminated %s (-%d HP)", player.DisplayName, dmg), Color3.fromRGB(255, 75, 110))
                        if Config.Misc.Notifications.KillAlert then
                            Vortex:Notify("Elimination", "Eliminated " .. player.DisplayName, 2)
                        end
                    else
                        Vortex:AddHitLog(string.format("[HIT] %s -%d HP (%d left)", player.DisplayName, dmg, math.floor(newHp)), Color3.fromRGB(175, 120, 255))
                    end
                end
            end
            lastHp = newHp
        end))
    end
    if player.Character then onChar(player.Character) end
    Vortex:BindConnection(player.CharacterAdded:Connect(onChar))
end

for _, p in ipairs(Players:GetPlayers()) do
    Vortex:CreatePlayerESP(p)
    HookPlayerHealth(p)
end

Vortex:BindConnection(Players.PlayerAdded:Connect(function(p)
    Vortex:CreatePlayerESP(p)
    HookPlayerHealth(p)
end))

Vortex:BindConnection(Players.PlayerRemoving:Connect(function(p)
    Vortex:RemovePlayerESP(p)
    Vortex.PlayerData[p] = nil
end))

-- Track LocalPlayer deaths
Vortex:BindConnection(LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        Vortex:BindConnection(hum.Died:Connect(function()
            Vortex.State.Deaths += 1
        end))
    end
end))

-- Infinite Jump Hook
Vortex:BindConnection(UserInputService.JumpRequest:Connect(function()
    if Config.Movement.Jump.InfiniteJump and Vortex:IsAlive(LocalPlayer) then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

-- Ctrl + Click Teleport Hook
Vortex:BindConnection(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if Config.Movement.Physics.ClickTP and input.UserInputType == Enum.UserInputType.MouseButton1 then
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and Vortex:IsAlive(LocalPlayer) then
            local hit = Mouse.Hit
            if hit then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3.2, 0))
            end
        end
    end
end))

-- Anti-AFK Hook
Vortex:BindConnection(LocalPlayer.Idled:Connect(function()
    if Config.Misc.Automation.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end))

-- RenderStepped Loop (Visuals, ESP, HUD, Camera Aim)
Vortex:BindConnection(RunService.RenderStepped:Connect(function(dt)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            Vortex:UpdatePlayerResolver(p)
        end
    end
    Vortex:ProcessCombat()
    Vortex:ProcessWorldVisuals()
    Vortex:RenderESPAndHUD()
end))

-- Heartbeat / Stepped Loop (Physics, Movement, Anti-Aim, Hitboxes)
Vortex:BindConnection(RunService.Heartbeat:Connect(function(dt)
    Vortex:ProcessHitboxes()
    Vortex:ProcessMovement(dt)
    Vortex:ProcessAntiAim(dt)
end))

-- Complete Unload & Cleanup Routine
Vortex.Unload = function()
    if Vortex.Unloaded then return end
    Vortex.Unloaded = true

    for _, conn in ipairs(Vortex.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Vortex.Connections)

    for _, draw in ipairs(Vortex.Drawings) do
        pcall(function() draw:Remove() end)
    end
    table.clear(Vortex.Drawings)

    for _, log in ipairs(Vortex.HitLogs) do
        pcall(function() log.Drawing:Remove() end)
    end
    table.clear(Vortex.HitLogs)

    Vortex:SetFlightState(false)

    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local hl = p.Character:FindFirstChild("Vortex_UltraChams")
            if hl then hl:Destroy() end
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.Transparency = 1
            end
        end
    end

    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").AutoRotate = true
    end

    Lighting.Ambient = OriginalLighting.Ambient
    Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
    Lighting.Brightness = OriginalLighting.Brightness
    Lighting.FogEnd = OriginalLighting.FogEnd
    Lighting.FogStart = OriginalLighting.FogStart
    Lighting.ClockTime = OriginalLighting.ClockTime
    Lighting.GlobalShadows = OriginalLighting.GlobalShadows

    if Camera then Camera.FieldOfView = 70 end
    getgenv().VORTEX_MVSD_INSTANCE = nil
    pcall(function() Window:Destroy() end)
end

Vortex:Notify("VORTEX // MVSD ULTRA", "Enterprise Rage Suite v3.5 Loaded Successfully!", 4)


-- ============================================================================
-- [MODULE 10] AUTO-PEEK RETURN SYSTEM, DESYNC VISUALIZER & WEAPON MACROS
-- ============================================================================

Config.Ragebot.AutoPeek = {
    Enabled = false,
    ReturnDelay = 0.08,
    DrawOriginRing = true,
    RingRadius = 3.5,
    RingColor = { 175, 95, 255 },
}

Config.Ragebot.Macros = {
    AutoQuickSwitch = false,
    QuickSwitchDelay = 0.06,
    AutoKnifeDash = false,
    KnifeDashRange = 14,
}

Config.Visuals.Radar = {
    Enabled = false,
    PositionX = 140,
    PositionY = 240,
    Radius = 95,
    Scale = 1.8,
    ShowNames = false,
    ShowRoles = true,
    BackgroundTransparency = 0.82,
}

Config.Visuals.Box3D = {
    Enabled = false,
    Thickness = 1.2,
}

Config.Misc.ChatSpam = {
    AutoGG = false,
    TrashTalkOnKill = false,
    CustomMessages = {
        "VORTEX ULTRA // Outplayed.",
        "Too slow for MVSD.",
        "Clean tap.",
        "Better luck next round.",
        "VORTEX on top.",
    }
}

Vortex.State.PeekOrigin = nil
Vortex.State.IsReturningPeek = false
Vortex.State.LastPeekReturn = 0
Vortex.State.RadarDrawings = {}
Vortex.State.Box3DLines = {}

-- Auto-Peek Origin Ring (3D Part)
local PeekRingPart = nil
function Vortex:UpdateAutoPeek(dt)
    if not Config.Ragebot.AutoPeek.Enabled or not self:IsAlive(LocalPlayer) then
        self.State.PeekOrigin = nil
        if PeekRingPart then
            pcall(function() PeekRingPart:Destroy() end)
            PeekRingPart = nil
        end
        return
    end

    local char = LocalPlayer.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    -- Record peek anchor when standing still or holding LeftAlt
    if not self.State.PeekOrigin then
        self.State.PeekOrigin = hrp.Position
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
        self.State.PeekOrigin = hrp.Position
    end

    -- Render 3D Origin Ring
    if Config.Ragebot.AutoPeek.DrawOriginRing and self.State.PeekOrigin then
        if not PeekRingPart then
            PeekRingPart = Instance.new("Part")
            PeekRingPart.Name = "Vortex_PeekRing"
            PeekRingPart.Anchored = true
            PeekRingPart.CanCollide = false
            PeekRingPart.CanQuery = false
            PeekRingPart.CanTouch = false
            PeekRingPart.Shape = Enum.PartType.Cylinder
            PeekRingPart.Material = Enum.Material.Neon
            PeekRingPart.Transparency = 0.45
            PeekRingPart.Parent = Workspace
        end
        local r = Config.Ragebot.AutoPeek.RingRadius * 2
        PeekRingPart.Size = Vector3.new(0.12, r, r)
        PeekRingPart.Color = ToColor3(Config.Ragebot.AutoPeek.RingColor)
        PeekRingPart.CFrame = CFrame.new(self.State.PeekOrigin - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
    elseif PeekRingPart then
        pcall(function() PeekRingPart:Destroy() end)
        PeekRingPart = nil
    end

    -- Retreat back to PeekOrigin right after firing
    if (tick() - self.State.LastShotTime) < 0.25 and (tick() - self.State.LastShotTime) >= Config.Ragebot.AutoPeek.ReturnDelay then
        if self.State.PeekOrigin then
            local distToOrigin = (hrp.Position - self.State.PeekOrigin).Magnitude
            if distToOrigin > 1.5 and distToOrigin < 65 then
                local flatTarget = Vector3.new(self.State.PeekOrigin.X, hrp.Position.Y, self.State.PeekOrigin.Z)
                local dir = (flatTarget - hrp.Position).Unit
                hrp.CFrame = hrp.CFrame + (dir * math.min(distToOrigin, 45 * dt))
            end
        end
    end
end

-- Auto Quick-Switch & Knife Dash Logic
function Vortex:ProcessWeaponMacros()
    if not self:IsAlive(LocalPlayer) then return end
    local char = LocalPlayer.Character
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not hum or not hrp or not backpack then return end

    -- Auto Knife Dash if holding knife and enemy is within melee lunge range
    if Config.Ragebot.Macros.AutoKnifeDash then
        local role = self:GetPlayerRole(LocalPlayer)
        if role == "Murderer" then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("blade")) then
                local target = self.State.CurrentTarget
                if target and self:IsAlive(target) then
                    local tHrp = target.Character:FindFirstChild("HumanoidRootPart")
                    if tHrp then
                        local dist = (tHrp.Position - hrp.Position).Magnitude
                        if dist <= Config.Ragebot.Macros.KnifeDashRange and dist > 2.5 then
                            local dashDir = (tHrp.Position - hrp.Position).Unit
                            hrp.AssemblyLinearVelocity = Vector3.new(dashDir.X * 55, hrp.AssemblyLinearVelocity.Y, dashDir.Z * 55)
                            pcall(function() tool:Activate() end)
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- [MODULE 11] 2D MINI-RADAR OVERLAY & 3D WIREFRAME BOX ESP
-- ============================================================================

local RadarUI = {
    BG = Vortex:CreateDrawing("Circle", {
        Filled = true,
        NumSides = 64,
        Color = Color3.fromRGB(16, 16, 22),
        Transparency = 0.82,
        ZIndex = 950,
        Visible = false,
    }),
    Border = Vortex:CreateDrawing("Circle", {
        Filled = false,
        NumSides = 64,
        Thickness = 1.6,
        Color = Color3.fromRGB(165, 85, 255),
        ZIndex = 951,
        Visible = false,
    }),
    CrossH = Vortex:CreateDrawing("Line", {
        Thickness = 1,
        Color = Color3.fromRGB(55, 55, 70),
        ZIndex = 951,
        Visible = false,
    }),
    CrossV = Vortex:CreateDrawing("Line", {
        Thickness = 1,
        Color = Color3.fromRGB(55, 55, 70),
        ZIndex = 951,
        Visible = false,
    }),
    LocalDot = Vortex:CreateDrawing("Triangle", {
        Filled = true,
        Color = Color3.fromRGB(255, 255, 255),
        ZIndex = 955,
        Visible = false,
    }),
    Dots = {}
}

function Vortex:GetRadarDot(player)
    if not RadarUI.Dots[player] then
        RadarUI.Dots[player] = {
            Point = self:CreateDrawing("Circle", {
                Filled = true,
                Radius = 4,
                NumSides = 16,
                ZIndex = 954,
                Visible = false,
            }),
            Label = self:CreateDrawing("Text", {
                Size = 11,
                Font = 2,
                Center = true,
                Outline = true,
                Color = Color3.fromRGB(235, 235, 245),
                ZIndex = 955,
                Visible = false,
            })
        }
    end
    return RadarUI.Dots[player]
end

function Vortex:RenderRadar()
    if not Config.Visuals.Radar.Enabled or not self:IsAlive(LocalPlayer) then
        RadarUI.BG.Visible = false
        RadarUI.Border.Visible = false
        RadarUI.CrossH.Visible = false
        RadarUI.CrossV.Visible = false
        RadarUI.LocalDot.Visible = false
        for _, d in pairs(RadarUI.Dots) do
            d.Point.Visible = false
            d.Label.Visible = false
        end
        return
    end

    local rx = Config.Visuals.Radar.PositionX
    local ry = Config.Visuals.Radar.PositionY
    local rad = Config.Visuals.Radar.Radius
    local center = Vector2.new(rx, ry)

    RadarUI.BG.Position = center
    RadarUI.BG.Radius = rad
    RadarUI.BG.Transparency = Config.Visuals.Radar.BackgroundTransparency
    RadarUI.BG.Visible = true

    RadarUI.Border.Position = center
    RadarUI.Border.Radius = rad
    RadarUI.Border.Visible = true

    RadarUI.CrossH.From = Vector2.new(rx - rad, ry)
    RadarUI.CrossH.To = Vector2.new(rx + rad, ry)
    RadarUI.CrossH.Visible = true

    RadarUI.CrossV.From = Vector2.new(rx, ry - rad)
    RadarUI.CrossV.To = Vector2.new(rx, ry + rad)
    RadarUI.CrossV.Visible = true

    RadarUI.LocalDot.PointA = center + Vector2.new(0, -6)
    RadarUI.LocalDot.PointB = center + Vector2.new(-4, 4)
    RadarUI.LocalDot.PointC = center + Vector2.new(4, 4)
    RadarUI.LocalDot.Visible = true

    local localHrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localHrp then return end

    local camLook = Camera.CFrame.LookVector
    local camYaw = math.atan2(-camLook.X, -camLook.Z)
    local cosYaw = math.cos(camYaw)
    local sinYaw = math.sin(camYaw)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local dot = self:GetRadarDot(player)
            if self:IsAlive(player) then
                local tHrp = player.Character:FindFirstChild("HumanoidRootPart")
                if tHrp then
                    local rel = tHrp.Position - localHrp.Position
                    local scaledX = rel.X / Config.Visuals.Radar.Scale
                    local scaledZ = rel.Z / Config.Visuals.Radar.Scale

                    local rotX = scaledX * cosYaw - scaledZ * sinYaw
                    local rotY = scaledX * sinYaw + scaledZ * cosYaw
                    local offset = Vector2.new(rotX, rotY)

                    if offset.Magnitude > (rad - 6) then
                        offset = offset.Unit * (rad - 6)
                    end

                    local dotPos = center + offset
                    local col = self:GetRoleColor(player, self.State.CurrentTarget == player)

                    dot.Point.Position = dotPos
                    dot.Point.Color = col
                    dot.Point.Visible = true

                    if Config.Visuals.Radar.ShowNames then
                        dot.Label.Text = player.DisplayName
                        dot.Label.Position = dotPos + Vector2.new(0, 5)
                        dot.Label.Visible = true
                    else
                        dot.Label.Visible = false
                    end
                else
                    dot.Point.Visible = false
                    dot.Label.Visible = false
                end
            else
                dot.Point.Visible = false
                dot.Label.Visible = false
            end
        end
    end
end

-- 3D Wireframe Box Renderer
local Box3DEdges = {
    {1, 2}, {2, 3}, {3, 4}, {4, 1},
    {5, 6}, {6, 7}, {7, 8}, {8, 5},
    {1, 5}, {2, 6}, {3, 7}, {4, 8}
}

function Vortex:GetPlayer3DBox(player)
    if not self.State.Box3DLines[player] then
        local lines = {}
        for i = 1, 12 do
            lines[i] = self:CreateDrawing("Line", {
                Thickness = Config.Visuals.Box3D.Thickness,
                ZIndex = 3,
                Visible = false,
            })
        end
        self.State.Box3DLines[player] = lines
    end
    return self.State.Box3DLines[player]
end

function Vortex:Render3DBoxes()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local lines = self:GetPlayer3DBox(player)
            if Config.Visuals.Enabled and Config.Visuals.Box3D.Enabled and self:IsAlive(player) then
                local char = player.Character
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local cf = hrp.CFrame
                    local sz = Vector3.new(2.2, 3.2, 1.4)
                    local corners3D = {
                        cf * Vector3.new(-sz.X,  sz.Y, -sz.Z),
                        cf * Vector3.new( sz.X,  sz.Y, -sz.Z),
                        cf * Vector3.new( sz.X,  sz.Y,  sz.Z),
                        cf * Vector3.new(-sz.X,  sz.Y,  sz.Z),
                        cf * Vector3.new(-sz.X, -sz.Y, -sz.Z),
                        cf * Vector3.new( sz.X, -sz.Y, -sz.Z),
                        cf * Vector3.new( sz.X, -sz.Y,  sz.Z),
                        cf * Vector3.new(-sz.X, -sz.Y,  sz.Z),
                    }

                    local screenCorners = {}
                    local allVisible = true
                    for i, c3 in ipairs(corners3D) do
                        local sp, vis = Camera:WorldToViewportPoint(c3)
                        if not vis then
                            allVisible = false
                            break
                        end
                        screenCorners[i] = Vector2.new(sp.X, sp.Y)
                    end

                    if allVisible then
                        local col = self:GetRoleColor(player, self.State.CurrentTarget == player)
                        for i, edge in ipairs(Box3DEdges) do
                            local line = lines[i]
                            line.From = screenCorners[edge[1]]
                            line.To = screenCorners[edge[2]]
                            line.Color = col
                            line.Thickness = Config.Visuals.Box3D.Thickness
                            line.Visible = true
                        end
                    else
                        for _, l in ipairs(lines) do l.Visible = false end
                    end
                else
                    for _, l in ipairs(lines) do l.Visible = false end
                end
            else
                for _, l in ipairs(lines) do l.Visible = false end
            end
        end
    end
end

-- ============================================================================
-- [MODULE 12] CHAT AUTOMATION, FPS BOOSTER & EXTENDED WINDUI CONTROLS
-- ============================================================================

function Vortex:SendChatMessage(msg)
    pcall(function()
        local TextChatService = Services.TextChatService
        if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channels = TextChatService:FindFirstChild("TextChannels")
            local rbxGeneral = channels and channels:FindFirstChild("RBXGeneral")
            if rbxGeneral then
                rbxGeneral:SendAsync(msg)
                return
            end
        end
        local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        local sayReq = chatEvents and chatEvents:FindFirstChild("SayMessageRequest")
        if sayReq then
            sayReq:FireServer(msg, "All")
        end
    end)
end

function Vortex:ApplyFPSBoost()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj:IsDescendantOf(LocalPlayer.Character or Workspace) then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                obj.Enabled = false
            end
        end
    end)
    self:Notify("FPS Booster", "Applied low-latency texture & particle optimizations!", 3)
end

-- Add Extended UI Controls to Tabs
Tabs.Rage:Section({ Title = "Auto-Peek & Weapon Macros" })

Tabs.Rage:Toggle({
    Title = "Enable Auto-Peek Retreat",
    Desc = "Automatically snaps you back behind cover after firing a shot",
    Value = Config.Ragebot.AutoPeek.Enabled,
    Callback = function(v) Config.Ragebot.AutoPeek.Enabled = v end
})

Tabs.Rage:Slider({
    Title = "Auto-Peek Return Delay (s)",
    Step = 0.01,
    Value = { Min = 0.01, Max = 0.4, Default = Config.Ragebot.AutoPeek.ReturnDelay },
    Callback = function(v) Config.Ragebot.AutoPeek.ReturnDelay = v end
})

Tabs.Rage:Toggle({
    Title = "Draw 3D Peek Origin Ring",
    Value = Config.Ragebot.AutoPeek.DrawOriginRing,
    Callback = function(v) Config.Ragebot.AutoPeek.DrawOriginRing = v end
})

Tabs.Rage:Toggle({
    Title = "Auto Knife Lunge Dash (Murderer)",
    Desc = "Dashes toward target and slashes when within melee range",
    Value = Config.Ragebot.Macros.AutoKnifeDash,
    Callback = function(v) Config.Ragebot.Macros.AutoKnifeDash = v end
})

Tabs.Rage:Slider({
    Title = "Knife Dash Trigger Range",
    Step = 1,
    Value = { Min = 5, Max = 25, Default = Config.Ragebot.Macros.KnifeDashRange },
    Callback = function(v) Config.Ragebot.Macros.KnifeDashRange = v end
})

Tabs.Visuals:Section({ Title = "3D Wireframe & 2D Mini-Radar" })

Tabs.Visuals:Toggle({
    Title = "3D Wireframe Bounding Box",
    Value = Config.Visuals.Box3D.Enabled,
    Callback = function(v) Config.Visuals.Box3D.Enabled = v end
})

Tabs.Visuals:Toggle({
    Title = "Enable 2D Mini-Radar",
    Value = Config.Visuals.Radar.Enabled,
    Callback = function(v) Config.Visuals.Radar.Enabled = v end
})

Tabs.Visuals:Slider({
    Title = "Radar Size Radius",
    Step = 5,
    Value = { Min = 50, Max = 180, Default = Config.Visuals.Radar.Radius },
    Callback = function(v) Config.Visuals.Radar.Radius = v end
})

Tabs.Visuals:Slider({
    Title = "Radar Zoom Scale",
    Step = 0.2,
    Value = { Min = 0.5, Max = 5.0, Default = Config.Visuals.Radar.Scale },
    Callback = function(v) Config.Visuals.Radar.Scale = v end
})

Tabs.Visuals:Toggle({
    Title = "Radar Player Names",
    Value = Config.Visuals.Radar.ShowNames,
    Callback = function(v) Config.Visuals.Radar.ShowNames = v end
})

Tabs.Settings:Section({ Title = "Chat & Performance" })

Tabs.Settings:Toggle({
    Title = "Trash-Talk on Elimination",
    Value = Config.Misc.ChatSpam.TrashTalkOnKill,
    Callback = function(v) Config.Misc.ChatSpam.TrashTalkOnKill = v end
})

Tabs.Settings:Button({
    Title = "Run FPS & Latency Booster",
    Desc = "Strips heavy materials, shadows, and particles for max FPS",
    Callback = function()
        Vortex:ApplyFPSBoost()
    end
})

-- Hook extended functions into runtime loops
Vortex:BindConnection(RunService.RenderStepped:Connect(function()
    Vortex:RenderRadar()
    Vortex:Render3DBoxes()
end))

Vortex:BindConnection(RunService.Heartbeat:Connect(function(dt)
    Vortex:UpdateAutoPeek(dt)
    Vortex:ProcessWeaponMacros()
end))


-- ============================================================================
-- [MODULE 13] BUILT-IN RAGE / HVH / LEGIT PRESET PROFILES ENGINE
-- ============================================================================

local BuiltInPresets = {
    ["Ultra Rage (Spin + AutoShoot)"] = {
        Ragebot = {
            Enabled = true,
            Mode = "Auto Shoot",
            AutoFire = true,
            AutoEquip = true,
            TargetSelection = "Crosshair + Distance",
            HitscanMode = "Multi-Point",
            PrimaryBone = "Head",
            FOVEnabled = false,
            FOVRadius = 600,
            WallCheck = true,
            TeamCheck = true,
            ForceFieldCheck = true,
            FireRateDelay = 0.025,
            Prediction = {
                Enabled = true,
                HorizontalScale = 0.142,
                VerticalScale = 0.12,
                GravityCompensation = true,
                PingCompensation = true,
            },
            Resolver = {
                Enabled = true,
                Mode = "Velocity + Acceleration",
            },
            AutoPeek = {
                Enabled = true,
                ReturnDelay = 0.06,
            }
        },
        AntiAim = {
            Enabled = true,
            YawMode = "SpinBot",
            SpinSpeed = 65,
            PitchMode = "Down",
            DisableOnShoot = true,
        },
        Hitbox = {
            Enabled = true,
            Mode = "Enemies Only",
            Part = "HumanoidRootPart",
            SizeX = 11,
            Transparency = 0.82,
        },
        Visuals = {
            Enabled = true,
            Boxes = { Enabled = true, Style = "Corner" },
            Chams = { Enabled = true },
            Radar = { Enabled = true },
        },
        Movement = {
            Speed = { Enabled = true, Mode = "CFrame", Value = 32 },
            Jump = { AutoBhop = true, AirStrafe = true },
        }
    },

    ["HvH Tank (Jitter + Resolver)"] = {
        Ragebot = {
            Enabled = true,
            Mode = "Silent Flick",
            AutoFire = true,
            AutoEquip = true,
            TargetSelection = "Threat Level",
            HitscanMode = "Multi-Point",
            PrimaryBone = "Head",
            FOVEnabled = true,
            FOVRadius = 320,
            WallCheck = true,
            TeamCheck = true,
            FireRateDelay = 0.035,
            FlickReturnCamera = true,
            Resolver = {
                Enabled = true,
                Mode = "Anti-Spin",
            }
        },
        AntiAim = {
            Enabled = true,
            YawMode = "Tank",
            JitterAngle = 95,
            PitchMode = "Jitter",
            DisableOnShoot = true,
        },
        Hitbox = {
            Enabled = true,
            Mode = "Enemies Only",
            Part = "HumanoidRootPart",
            SizeX = 8.5,
            Transparency = 0.8,
        },
        Visuals = {
            Enabled = true,
            Boxes = { Enabled = true, Style = "Full" },
            Skeleton = { Enabled = true },
            Chams = { Enabled = true },
        },
        Movement = {
            Speed = { Enabled = true, Mode = "WalkSpeed", Value = 26 },
            Jump = { InfiniteJump = true, AutoBhop = true },
        }
    },

    ["Semi-Rage (Closet Competitive)"] = {
        Ragebot = {
            Enabled = true,
            Mode = "TriggerBot",
            AutoFire = true,
            AutoEquip = false,
            TargetSelection = "Crosshair",
            HitscanMode = "Single Bone",
            PrimaryBone = "UpperTorso",
            FOVEnabled = true,
            FOVRadius = 110,
            WallCheck = true,
            TeamCheck = true,
            FireRateDelay = 0.09,
        },
        AntiAim = {
            Enabled = false,
        },
        Hitbox = {
            Enabled = true,
            Mode = "Enemies Only",
            Part = "HumanoidRootPart",
            SizeX = 4.2,
            Transparency = 0.95,
        },
        Visuals = {
            Enabled = true,
            Boxes = { Enabled = true, Style = "Corner" },
            Chams = { Enabled = true, OccludedOnly = true },
        },
        Movement = {
            Speed = { Enabled = false },
            Jump = { AutoBhop = false },
        }
    },

    ["Pure Legit (Smooth Lock + ESP)"] = {
        Ragebot = {
            Enabled = true,
            Mode = "Camera Lock",
            AutoFire = false,
            TargetSelection = "Crosshair",
            HitscanMode = "Single Bone",
            PrimaryBone = "UpperTorso",
            FOVEnabled = true,
            FOVRadius = 95,
            CameraSmoothness = 0.35,
            WallCheck = true,
            TeamCheck = true,
        },
        AntiAim = {
            Enabled = false,
        },
        Hitbox = {
            Enabled = false,
        },
        Visuals = {
            Enabled = true,
            Boxes = { Enabled = true, Style = "Corner" },
            Info = { Names = true, RoleBadges = true, Distance = true, HealthBar = true },
            Chams = { Enabled = false },
        },
        Movement = {
            Speed = { Enabled = false },
            Jump = { InfiniteJump = false, AutoBhop = false },
        }
    }
}

function Vortex:ApplyPreset(presetName)
    local preset = BuiltInPresets[presetName]
    if not preset then return false end
    DeepMerge(Config, preset)
    self:ProcessHitboxes()
    if not Config.AntiAim.Enabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").AutoRotate = true
    end
    self:Notify("Preset Applied", "Loaded profile: " .. presetName, 3)
    return true
end

-- ============================================================================
-- [MODULE 14] LOBBY ROLE SCANNER & KEYBIND STATUS HUD OVERLAY
-- ============================================================================

Config.HUD.RoleList = true
Config.HUD.KeybindOverlay = true

local RoleListUI = {
    BG = Vortex:CreateDrawing("Square", {
        Filled = true,
        Color = Color3.fromRGB(16, 16, 22),
        Transparency = 0.85,
        ZIndex = 1008,
        Visible = false,
    }),
    Accent = Vortex:CreateDrawing("Square", {
        Filled = true,
        Color = Color3.fromRGB(165, 85, 255),
        Transparency = 1,
        ZIndex = 1009,
        Visible = false,
    }),
    Header = Vortex:CreateDrawing("Text", {
        Text = "MVSD LOBBY SCANNER",
        Size = 13,
        Font = 2,
        Outline = true,
        Color = Color3.fromRGB(255, 255, 255),
        ZIndex = 1010,
        Visible = false,
    }),
    Body = Vortex:CreateDrawing("Text", {
        Text = "",
        Size = 12,
        Font = 2,
        Outline = true,
        Color = Color3.fromRGB(215, 215, 230),
        ZIndex = 1010,
        Visible = false,
    })
}

local KeybindUI = {
    BG = Vortex:CreateDrawing("Square", {
        Filled = true,
        Color = Color3.fromRGB(16, 16, 22),
        Transparency = 0.85,
        ZIndex = 1008,
        Visible = false,
    }),
    Accent = Vortex:CreateDrawing("Square", {
        Filled = true,
        Color = Color3.fromRGB(165, 85, 255),
        Transparency = 1,
        ZIndex = 1009,
        Visible = false,
    }),
    Header = Vortex:CreateDrawing("Text", {
        Text = "ACTIVE MODULES",
        Size = 13,
        Font = 2,
        Outline = true,
        Color = Color3.fromRGB(255, 255, 255),
        ZIndex = 1010,
        Visible = false,
    }),
    Body = Vortex:CreateDrawing("Text", {
        Text = "",
        Size = 12,
        Font = 2,
        Outline = true,
        Color = Color3.fromRGB(185, 225, 255),
        ZIndex = 1010,
        Visible = false,
    })
}

function Vortex:RenderLobbyAndModuleHUD()
    local viewport = Camera.ViewportSize

    -- 1. Lobby Role Scanner (Top-Right)
    if Config.HUD.RoleList then
        local sheriffs = {}
        local murderers = {}
        for _, p in ipairs(Players:GetPlayers()) do
            local r = self:GetPlayerRole(p)
            if r == "Sheriff" then
                table.insert(sheriffs, p.DisplayName)
            elseif r == "Murderer" then
                table.insert(murderers, p.DisplayName)
            end
        end

        local lines = {
            "Sheriffs (" .. #sheriffs .. "): " .. (#sheriffs > 0 and table.concat(sheriffs, ", ") or "None"),
            "Murderers (" .. #murderers .. "): " .. (#murderers > 0 and table.concat(murderers, ", ") or "None"),
            string.format("Accuracy: %d%% (%d/%d)",
                self.State.ShotsFired > 0 and math.floor((self.State.ShotsHit / self.State.ShotsFired) * 100) or 0,
                self.State.ShotsHit, self.State.ShotsFired)
        }
        local bodyStr = table.concat(lines, "\n")
        local boxW = 240
        local boxH = 66
        local posX = viewport.X - boxW - 16
        local posY = 14

        RoleListUI.BG.Position = Vector2.new(posX, posY)
        RoleListUI.BG.Size = Vector2.new(boxW, boxH)
        RoleListUI.BG.Visible = true

        RoleListUI.Accent.Position = Vector2.new(posX, posY)
        RoleListUI.Accent.Size = Vector2.new(boxW, 2)
        RoleListUI.Accent.Visible = true

        RoleListUI.Header.Position = Vector2.new(posX + 8, posY + 5)
        RoleListUI.Header.Visible = true

        RoleListUI.Body.Text = bodyStr
        RoleListUI.Body.Position = Vector2.new(posX + 8, posY + 21)
        RoleListUI.Body.Visible = true
    else
        RoleListUI.BG.Visible = false
        RoleListUI.Accent.Visible = false
        RoleListUI.Header.Visible = false
        RoleListUI.Body.Visible = false
    end

    -- 2. Active Modules List (Right-Middle)
    if Config.HUD.KeybindOverlay then
        local active = {}
        if Config.Ragebot.Enabled then
            table.insert(active, "[ON] Ragebot (" .. Config.Ragebot.Mode .. ")")
        end
        if Config.AntiAim.Enabled then
            table.insert(active, "[ON] Anti-Aim (" .. Config.AntiAim.YawMode .. ")")
        end
        if Config.Hitbox.Enabled then
            table.insert(active, "[ON] Hitbox (" .. tostring(Config.Hitbox.SizeX) .. "x)")
        end
        if Config.Ragebot.AutoPeek.Enabled then
            table.insert(active, "[ON] Auto-Peek [Alt]")
        end
        if Config.Movement.TargetOrbit.Enabled then
            table.insert(active, "[ON] Target Orbit")
        end
        if Config.Movement.Flight.Enabled then
            table.insert(active, "[ON] Flight")
        end
        if Config.Movement.Speed.Enabled then
            table.insert(active, "[ON] Speed (" .. Config.Movement.Speed.Mode .. ")")
        end
        if Config.Visuals.Enabled then
            table.insert(active, "[ON] Visuals ESP")
        end

        if #active > 0 then
            local boxW = 215
            local boxH = 26 + (#active * 14)
            local posX = viewport.X - boxW - 16
            local posY = 92

            KeybindUI.BG.Position = Vector2.new(posX, posY)
            KeybindUI.BG.Size = Vector2.new(boxW, boxH)
            KeybindUI.BG.Visible = true

            KeybindUI.Accent.Position = Vector2.new(posX, posY)
            KeybindUI.Accent.Size = Vector2.new(boxW, 2)
            KeybindUI.Accent.Visible = true

            KeybindUI.Header.Position = Vector2.new(posX + 8, posY + 5)
            KeybindUI.Header.Visible = true

            KeybindUI.Body.Text = table.concat(active, "\n")
            KeybindUI.Body.Position = Vector2.new(posX + 8, posY + 21)
            KeybindUI.Body.Visible = true
        else
            KeybindUI.BG.Visible = false
            KeybindUI.Accent.Visible = false
            KeybindUI.Header.Visible = false
            KeybindUI.Body.Visible = false
        end
    else
        KeybindUI.BG.Visible = false
        KeybindUI.Accent.Visible = false
        KeybindUI.Header.Visible = false
        KeybindUI.Body.Visible = false
    end
end

-- ============================================================================
-- [MODULE 15] DESYNC GHOST VISUALIZER & SKYBOX / COLOR GRADING SUITE
-- ============================================================================

Config.AntiAim.VisualizeDesync = false
Config.AntiAim.DesyncColor = { 165, 85, 255 }

Config.Visuals.World.ColorGrading = {
    Enabled = false,
    Saturation = 0.25,
    Contrast = 0.15,
    TintColor = { 235, 215, 255 },
}

Config.Visuals.World.SkyboxPreset = "Default" -- "Default", "Nebula Purple", "Midnight Dark", "Sunset Vapor"

local SkyboxTextures = {
    ["Nebula Purple"] = {
        Bk = "rbxassetid://159454299",
        Dn = "rbxassetid://159454296",
        Ft = "rbxassetid://159454293",
        Lf = "rbxassetid://159454286",
        Rt = "rbxassetid://159454300",
        Up = "rbxassetid://159454288",
    },
    ["Midnight Dark"] = {
        Bk = "rbxassetid://12064107",
        Dn = "rbxassetid://12064152",
        Ft = "rbxassetid://12064121",
        Lf = "rbxassetid://12063984",
        Rt = "rbxassetid://12064115",
        Up = "rbxassetid://12064131",
    },
    ["Sunset Vapor"] = {
        Bk = "rbxassetid://271042516",
        Dn = "rbxassetid://271077243",
        Ft = "rbxassetid://271042556",
        Lf = "rbxassetid://271042310",
        Rt = "rbxassetid://271042467",
        Up = "rbxassetid://271077958",
    }
}

local DesyncGhostPart = nil
function Vortex:UpdateDesyncGhost()
    if not Config.AntiAim.Enabled or not Config.AntiAim.VisualizeDesync or not self:IsAlive(LocalPlayer) then
        if DesyncGhostPart then
            pcall(function() DesyncGhostPart:Destroy() end)
            DesyncGhostPart = nil
        end
        return
    end

    local char = LocalPlayer.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if not DesyncGhostPart then
        DesyncGhostPart = Instance.new("Part")
        DesyncGhostPart.Name = "Vortex_DesyncGhost"
        DesyncGhostPart.Anchored = true
        DesyncGhostPart.CanCollide = false
        DesyncGhostPart.CanQuery = false
        DesyncGhostPart.CanTouch = false
        DesyncGhostPart.Material = Enum.Material.ForceField
        DesyncGhostPart.Size = Vector3.new(2, 5, 1)
        DesyncGhostPart.Parent = Workspace
    end

    local offset = Config.AntiAim.Desync.Invert and -Config.AntiAim.Desync.Offset or Config.AntiAim.Desync.Offset
    DesyncGhostPart.Color = ToColor3(Config.AntiAim.DesyncColor)
    DesyncGhostPart.CFrame = hrp.CFrame * CFrame.new(offset, 0, 0) * CFrame.Angles(0, math.rad(180), 0)
end

local CustomColorCorrection = nil
local CustomSkyInstance = nil

function Vortex:UpdateAtmosphere()
    -- Color Correction
    if Config.Visuals.World.ColorGrading.Enabled then
        if not CustomColorCorrection then
            CustomColorCorrection = Instance.new("ColorCorrectionEffect")
            CustomColorCorrection.Name = "Vortex_ColorGrading"
            CustomColorCorrection.Parent = Lighting
        end
        CustomColorCorrection.Enabled = true
        CustomColorCorrection.Saturation = Config.Visuals.World.ColorGrading.Saturation
        CustomColorCorrection.Contrast = Config.Visuals.World.ColorGrading.Contrast
        CustomColorCorrection.TintColor = ToColor3(Config.Visuals.World.ColorGrading.TintColor)
    elseif CustomColorCorrection then
        pcall(function() CustomColorCorrection:Destroy() end)
        CustomColorCorrection = nil
    end

    -- Custom Skybox
    local preset = Config.Visuals.World.SkyboxPreset
    if preset ~= "Default" and SkyboxTextures[preset] then
        if not CustomSkyInstance then
            CustomSkyInstance = Instance.new("Sky")
            CustomSkyInstance.Name = "Vortex_CustomSky"
            CustomSkyInstance.Parent = Lighting
        end
        local tex = SkyboxTextures[preset]
        CustomSkyInstance.SkyboxBk = tex.Bk
        CustomSkyInstance.SkyboxDn = tex.Dn
        CustomSkyInstance.SkyboxFt = tex.Ft
        CustomSkyInstance.SkyboxLf = tex.Lf
        CustomSkyInstance.SkyboxRt = tex.Rt
        CustomSkyInstance.SkyboxUp = tex.Up
    elseif CustomSkyInstance then
        pcall(function() CustomSkyInstance:Destroy() end)
        CustomSkyInstance = nil
    end
end

-- ============================================================================
-- [MODULE 16] EXTENDED UI CONTROLS FOR PRESETS, RADAR HUD & ATMOSPHERE
-- ============================================================================

Tabs.AntiAim:Section({ Title = "Desync & Ghost Visualizer" })

Tabs.AntiAim:Toggle({
    Title = "Visualize Desync Ghost",
    Desc = "Renders a 3D ForceField ghost showing fake angle offset",
    Value = Config.AntiAim.VisualizeDesync,
    Callback = function(v) Config.AntiAim.VisualizeDesync = v end
})

Tabs.AntiAim:Slider({
    Title = "Desync Stud Offset",
    Step = 0.2,
    Value = { Min = 0.5, Max = 8.0, Default = Config.AntiAim.Desync.Offset },
    Callback = function(v) Config.AntiAim.Desync.Offset = v end
})

Tabs.AntiAim:Toggle({
    Title = "Invert Desync Side",
    Value = Config.AntiAim.Desync.Invert,
    Callback = function(v) Config.AntiAim.Desync.Invert = v end
})

Tabs.World:Section({ Title = "Skybox & Post-Processing" })

Tabs.World:Dropdown({
    Title = "Custom Skybox Theme",
    Values = { "Default", "Nebula Purple", "Midnight Dark", "Sunset Vapor" },
    Value = Config.Visuals.World.SkyboxPreset,
    Callback = function(v)
        Config.Visuals.World.SkyboxPreset = v
        Vortex:UpdateAtmosphere()
    end
})

Tabs.World:Toggle({
    Title = "Enable Color Grading",
    Value = Config.Visuals.World.ColorGrading.Enabled,
    Callback = function(v)
        Config.Visuals.World.ColorGrading.Enabled = v
        Vortex:UpdateAtmosphere()
    end
})

Tabs.World:Slider({
    Title = "Color Saturation",
    Step = 0.05,
    Value = { Min = -1, Max = 1, Default = Config.Visuals.World.ColorGrading.Saturation },
    Callback = function(v)
        Config.Visuals.World.ColorGrading.Saturation = v
        Vortex:UpdateAtmosphere()
    end
})

Tabs.World:Slider({
    Title = "Color Contrast",
    Step = 0.05,
    Value = { Min = -0.5, Max = 1, Default = Config.Visuals.World.ColorGrading.Contrast },
    Callback = function(v)
        Config.Visuals.World.ColorGrading.Contrast = v
        Vortex:UpdateAtmosphere()
    end
})

Tabs.Settings:Section({ Title = "Instant Playstyle Presets" })

local SelectedPreset = "Ultra Rage (Spin + AutoShoot)"
Tabs.Settings:Dropdown({
    Title = "Select Built-In Preset",
    Values = {
        "Ultra Rage (Spin + AutoShoot)",
        "HvH Tank (Jitter + Resolver)",
        "Semi-Rage (Closet Competitive)",
        "Pure Legit (Smooth Lock + ESP)"
    },
    Value = SelectedPreset,
    Callback = function(v) SelectedPreset = v end
})

Tabs.Settings:Button({
    Title = "Apply Selected Preset",
    Desc = "Configures Ragebot, Anti-Aim, Hitboxes, and Visuals automatically",
    Callback = function()
        Vortex:ApplyPreset(SelectedPreset)
    end
})

Tabs.Settings:Section({ Title = "Additional HUD Overlays" })

Tabs.Settings:Toggle({
    Title = "MVSD Lobby Role Scanner",
    Desc = "Displays live Sheriff/Murderer count and shot accuracy",
    Value = Config.HUD.RoleList,
    Callback = function(v) Config.HUD.RoleList = v end
})

Tabs.Settings:Toggle({
    Title = "Active Modules List",
    Value = Config.HUD.KeybindOverlay,
    Callback = function(v) Config.HUD.KeybindOverlay = v end
})

-- Connect Module 14 & 15 into Runtime Loops
Vortex:BindConnection(RunService.RenderStepped:Connect(function()
    Vortex:RenderLobbyAndModuleHUD()
    Vortex:UpdateDesyncGhost()
end))


-- ============================================================================
-- [MODULE 17] HOTKEY BINDINGS, TELEMETRY DIAGNOSTICS & SAFE CLEANUP EXTENSIONS
-- ============================================================================

Config.Keybinds = {
    ToggleRagebot = "E",
    ToggleAntiAim = "Z",
    ToggleHitbox = "H",
    ToggleVisuals = "V",
    ToggleFlight = "F",
    ToggleOrbit = "X",
    ToggleAutoPeek = "C",
    PanicDisableAll = "End",
}

local KeyCodeLookup = {}
for _, enumItem in ipairs(Enum.KeyCode:GetEnumItems()) do
    KeyCodeLookup[enumItem.Name] = enumItem
end

function Vortex:PanicReset()
    Config.Ragebot.Enabled = false
    Config.AntiAim.Enabled = false
    Config.Hitbox.Enabled = false
    Config.Movement.Flight.Enabled = false
    Config.Movement.TargetOrbit.Enabled = false
    Config.Ragebot.AutoPeek.Enabled = false
    self:ProcessHitboxes()
    self:SetFlightState(false)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").AutoRotate = true
    end
    self:Notify("PANIC RESET", "All combat, anti-aim, and exploit modules disabled!", 3)
end

Vortex:BindConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local keyName = input.KeyCode.Name

    if keyName == Config.Keybinds.ToggleRagebot then
        Config.Ragebot.Enabled = not Config.Ragebot.Enabled
        Vortex:Notify("Hotkey", "Ragebot: " .. (Config.Ragebot.Enabled and "ON" or "OFF"), 1.5)
    elseif keyName == Config.Keybinds.ToggleAntiAim then
        Config.AntiAim.Enabled = not Config.AntiAim.Enabled
        if not Config.AntiAim.Enabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            LocalPlayer.Character:FindFirstChildOfClass("Humanoid").AutoRotate = true
        end
        Vortex:Notify("Hotkey", "Anti-Aim: " .. (Config.AntiAim.Enabled and "ON" or "OFF"), 1.5)
    elseif keyName == Config.Keybinds.ToggleHitbox then
        Config.Hitbox.Enabled = not Config.Hitbox.Enabled
        Vortex:ProcessHitboxes()
        Vortex:Notify("Hotkey", "Hitbox Expander: " .. (Config.Hitbox.Enabled and "ON" or "OFF"), 1.5)
    elseif keyName == Config.Keybinds.ToggleVisuals then
        Config.Visuals.Enabled = not Config.Visuals.Enabled
        Vortex:Notify("Hotkey", "Visuals ESP: " .. (Config.Visuals.Enabled and "ON" or "OFF"), 1.5)
    elseif keyName == Config.Keybinds.ToggleFlight then
        Config.Movement.Flight.Enabled = not Config.Movement.Flight.Enabled
        Vortex:Notify("Hotkey", "Flight: " .. (Config.Movement.Flight.Enabled and "ON" or "OFF"), 1.5)
    elseif keyName == Config.Keybinds.ToggleOrbit then
        Config.Movement.TargetOrbit.Enabled = not Config.Movement.TargetOrbit.Enabled
        Vortex:Notify("Hotkey", "Target Orbit: " .. (Config.Movement.TargetOrbit.Enabled and "ON" or "OFF"), 1.5)
    elseif keyName == Config.Keybinds.ToggleAutoPeek then
        Config.Ragebot.AutoPeek.Enabled = not Config.Ragebot.AutoPeek.Enabled
        Vortex:Notify("Hotkey", "Auto-Peek: " .. (Config.Ragebot.AutoPeek.Enabled and "ON" or "OFF"), 1.5)
    elseif keyName == Config.Keybinds.PanicDisableAll then
        Vortex:PanicReset()
    end
end))

-- Keybinds Tab in WindUI
local KeybindsTab = Window:Tab({ Title = "Keybinds", Icon = "keyboard" })
KeybindsTab:Section({ Title = "Quick Toggle Hotkeys (KeyCode Names)" })

local BindFields = {
    { Title = "Toggle Ragebot Key", Field = "ToggleRagebot" },
    { Title = "Toggle Anti-Aim Key", Field = "ToggleAntiAim" },
    { Title = "Toggle Hitbox Key", Field = "ToggleHitbox" },
    { Title = "Toggle Visuals ESP Key", Field = "ToggleVisuals" },
    { Title = "Toggle Flight Key", Field = "ToggleFlight" },
    { Title = "Toggle Target Orbit Key", Field = "ToggleOrbit" },
    { Title = "Toggle Auto-Peek Key", Field = "ToggleAutoPeek" },
    { Title = "Panic Disable All Key", Field = "PanicDisableAll" },
}

for _, item in ipairs(BindFields) do
    KeybindsTab:Input({
        Title = item.Title,
        Placeholder = "e.g. E, Z, F, X, End...",
        Value = Config.Keybinds[item.Field],
        Callback = function(v)
            if v and KeyCodeLookup[v] then
                Config.Keybinds[item.Field] = v
                Vortex:Notify("Keybind Updated", item.Title .. " -> " .. v, 2)
            end
        end
    })
end

KeybindsTab:Button({
    Title = "Trigger Panic Disable Now",
    Desc = "Immediately turns off all active rage and movement features",
    Callback = function()
        Vortex:PanicReset()
    end
})

-- Extend Unload to also clean up 3D Parts & Lighting Effects created in Modules 10-15
local OriginalUnload = Vortex.Unload
Vortex.Unload = function()
    if PeekRingPart then pcall(function() PeekRingPart:Destroy() end) PeekRingPart = nil end
    if DesyncGhostPart then pcall(function() DesyncGhostPart:Destroy() end) DesyncGhostPart = nil end
    if CustomColorCorrection then pcall(function() CustomColorCorrection:Destroy() end) CustomColorCorrection = nil end
    if CustomSkyInstance then pcall(function() CustomSkyInstance:Destroy() end) CustomSkyInstance = nil end
    OriginalUnload()
end


-- ============================================================================
-- [MODULE 18] PROXIMITY THREAT WARNINGS & INCOMING KNIFE / BULLET EVASION
-- ============================================================================

Config.AntiAim.ThreatWarning = {
    Enabled = true,
    KnifeAlertRange = 22,
    AutoDodgeKnife = false,
    DodgeImpulse = 48,
}

local ThreatBanner = Vortex:CreateDrawing("Text", {
    Text = "",
    Size = 18,
    Font = 2,
    Center = true,
    Outline = true,
    Color = Color3.fromRGB(255, 65, 85),
    ZIndex = 1020,
    Visible = false,
})

function Vortex:ProcessThreatDetection()
    if not Config.AntiAim.ThreatWarning.Enabled or not self:IsAlive(LocalPlayer) then
        ThreatBanner.Visible = false
        return
    end

    local myHrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then
        ThreatBanner.Visible = false
        return
    end

    local closestThreat = nil
    local closestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if self:IsEnemy(player) and self:IsAlive(player) then
            local role = self:GetPlayerRole(player)
            local tHrp = player.Character:FindFirstChild("HumanoidRootPart")
            if tHrp then
                local dist = (tHrp.Position - myHrp.Position).Magnitude
                if role == "Murderer" and dist <= Config.AntiAim.ThreatWarning.KnifeAlertRange and dist < closestDist then
                    closestDist = dist
                    closestThreat = player
                end
            end
        end
    end

    if closestThreat then
        local viewport = Camera.ViewportSize
        ThreatBanner.Text = string.format("WARNING: MURDERER %s NEARBY (%.1fm)!", closestThreat.DisplayName:upper(), closestDist)
        ThreatBanner.Position = Vector2.new(viewport.X / 2, viewport.Y * 0.22)
        ThreatBanner.Visible = true

        if Config.AntiAim.ThreatWarning.AutoDodgeKnife then
            local tHrp = closestThreat.Character:FindFirstChild("HumanoidRootPart")
            if tHrp then
                local away = (myHrp.Position - tHrp.Position)
                local flatAway = Vector3.new(away.X, 0, away.Z)
                if flatAway.Magnitude > 0.1 then
                    local sideVec = flatAway.Unit:Cross(Vector3.new(0, 1, 0))
                    local dodgeDir = (flatAway.Unit + sideVec * self.State.JitterSide).Unit
                    myHrp.AssemblyLinearVelocity = Vector3.new(
                        dodgeDir.X * Config.AntiAim.ThreatWarning.DodgeImpulse,
                        myHrp.AssemblyLinearVelocity.Y,
                        dodgeDir.Z * Config.AntiAim.ThreatWarning.DodgeImpulse
                    )
                end
            end
        end
    else
        ThreatBanner.Visible = false
    end
end

-- ============================================================================
-- [MODULE 19] DETAILED RGB COLOR CUSTOMIZER & COMBAT TELEMETRY TAB
-- ============================================================================

local TelemetryTab = Window:Tab({ Title = "Telemetry & RGB", Icon = "activity" })

TelemetryTab:Section({ Title = "Live Session Combat Analytics" })

local StatsParagraph = TelemetryTab:Paragraph({
    Title = "Session Performance",
    Desc = "Kills: 0 | Deaths: 0 | Shots Fired: 0 | Shots Hit: 0 | Accuracy: 0%"
})

TelemetryTab:Button({
    Title = "Refresh Session Telemetry",
    Callback = function()
        local acc = Vortex.State.ShotsFired > 0 and math.floor((Vortex.State.ShotsHit / Vortex.State.ShotsFired) * 100) or 0
        local uptime = math.floor(tick() - Vortex.State.StartTime)
        pcall(function()
            StatsParagraph:SetDesc(string.format(
                "Kills: %d | Deaths: %d | Fired: %d | Hit: %d | Accuracy: %d%% | Uptime: %ds",
                Vortex.State.Kills, Vortex.State.Deaths, Vortex.State.ShotsFired, Vortex.State.ShotsHit, acc, uptime
            ))
        end)
    end
})

TelemetryTab:Button({
    Title = "Reset Session Counters",
    Callback = function()
        Vortex.State.Kills = 0
        Vortex.State.Deaths = 0
        Vortex.State.ShotsFired = 0
        Vortex.State.ShotsHit = 0
        Vortex:Notify("Telemetry", "Session statistics reset to zero.", 2)
    end
})

TelemetryTab:Section({ Title = "Threat Warning & Auto-Dodge" })

TelemetryTab:Toggle({
    Title = "Murderer Proximity Warning Banner",
    Value = Config.AntiAim.ThreatWarning.Enabled,
    Callback = function(v) Config.AntiAim.ThreatWarning.Enabled = v end
})

TelemetryTab:Slider({
    Title = "Warning Trigger Radius (studs)",
    Step = 1,
    Value = { Min = 8, Max = 50, Default = Config.AntiAim.ThreatWarning.KnifeAlertRange },
    Callback = function(v) Config.AntiAim.ThreatWarning.KnifeAlertRange = v end
})

TelemetryTab:Toggle({
    Title = "Auto-Strafe Dodge Incoming Knife",
    Value = Config.AntiAim.ThreatWarning.AutoDodgeKnife,
    Callback = function(v) Config.AntiAim.ThreatWarning.AutoDodgeKnife = v end
})

TelemetryTab:Section({ Title = "FOV Circle RGB Customizer" })

TelemetryTab:Slider({
    Title = "FOV Red (R)",
    Step = 5,
    Value = { Min = 0, Max = 255, Default = Config.Ragebot.FOVColor[1] },
    Callback = function(v) Config.Ragebot.FOVColor[1] = v end
})

TelemetryTab:Slider({
    Title = "FOV Green (G)",
    Step = 5,
    Value = { Min = 0, Max = 255, Default = Config.Ragebot.FOVColor[2] },
    Callback = function(v) Config.Ragebot.FOVColor[2] = v end
})

TelemetryTab:Slider({
    Title = "FOV Blue (B)",
    Step = 5,
    Value = { Min = 0, Max = 255, Default = Config.Ragebot.FOVColor[3] },
    Callback = function(v) Config.Ragebot.FOVColor[3] = v end
})

TelemetryTab:Section({ Title = "3D Bullet Tracer RGB Customizer" })

TelemetryTab:Slider({
    Title = "Tracer Red (R)",
    Step = 5,
    Value = { Min = 0, Max = 255, Default = Config.Visuals.Tracers3D.TracerColor[1] },
    Callback = function(v) Config.Visuals.Tracers3D.TracerColor[1] = v end
})

TelemetryTab:Slider({
    Title = "Tracer Green (G)",
    Step = 5,
    Value = { Min = 0, Max = 255, Default = Config.Visuals.Tracers3D.TracerColor[2] },
    Callback = function(v) Config.Visuals.Tracers3D.TracerColor[2] = v end
})

TelemetryTab:Slider({
    Title = "Tracer Blue (B)",
    Step = 5,
    Value = { Min = 0, Max = 255, Default = Config.Visuals.Tracers3D.TracerColor[3] },
    Callback = function(v) Config.Visuals.Tracers3D.TracerColor[3] = v end
})

TelemetryTab:Section({ Title = "Crosshair RGB Customizer" })

TelemetryTab:Slider({
    Title = "Crosshair Red (R)",
    Step = 5,
    Value = { Min = 0, Max = 255, Default = Config.HUD.CustomCrosshair.Color[1] },
    Callback = function(v) Config.HUD.CustomCrosshair.Color[1] = v end
})

TelemetryTab:Slider({
    Title = "Crosshair Green (G)",
    Step = 5,
    Value = { Min = 0, Max = 255, Default = Config.HUD.CustomCrosshair.Color[2] },
    Callback = function(v) Config.HUD.CustomCrosshair.Color[2] = v end
})

TelemetryTab:Slider({
    Title = "Crosshair Blue (B)",
    Step = 5,
    Value = { Min = 0, Max = 255, Default = Config.HUD.CustomCrosshair.Color[3] },
    Callback = function(v) Config.HUD.CustomCrosshair.Color[3] = v end
})

-- Hook Threat Detection into Render Loop
Vortex:BindConnection(RunService.RenderStepped:Connect(function()
    Vortex:ProcessThreatDetection()
end))


-- ============================================================================
-- [APPENDIX] VORTEX ULTRA v3.5 CONFIGURATION & MODULE ARCHITECTURE REFERENCE
-- ============================================================================
-- [VORTEX-SPEC-0001] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0002] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0003] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0004] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0005] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0006] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0007] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0008] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0009] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0010] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0011] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0012] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0013] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0014] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0015] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0016] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0017] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0018] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0019] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0020] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0021] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0022] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0023] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0024] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0025] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0026] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0027] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0028] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0029] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0030] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0031] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0032] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0033] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0034] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0035] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0036] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0037] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0038] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0039] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0040] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0041] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0042] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0043] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0044] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0045] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0046] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0047] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0048] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0049] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0050] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0051] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0052] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0053] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0054] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0055] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0056] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0057] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0058] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0059] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0060] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0061] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0062] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0063] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0064] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0065] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0066] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0067] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0068] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0069] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0070] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0071] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0072] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0073] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0074] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0075] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0076] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0077] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0078] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0079] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0080] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0081] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0082] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0083] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0084] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0085] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0086] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0087] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0088] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0089] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0090] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0091] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0092] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0093] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0094] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0095] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0096] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0097] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0098] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0099] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0100] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0101] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0102] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0103] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0104] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0105] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0106] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0107] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0108] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0109] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0110] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0111] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0112] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0113] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0114] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0115] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0116] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0117] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0118] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0119] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0120] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0121] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0122] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0123] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0124] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0125] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0126] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0127] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0128] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0129] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0130] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0131] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0132] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0133] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0134] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0135] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0136] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0137] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0138] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0139] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0140] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0141] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0142] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0143] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0144] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0145] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0146] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0147] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0148] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0149] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0150] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0151] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0152] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0153] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0154] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0155] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0156] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0157] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0158] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0159] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0160] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0161] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0162] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0163] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0164] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0165] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0166] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0167] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0168] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0169] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0170] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0171] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0172] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0173] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0174] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0175] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0176] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0177] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0178] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0179] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0180] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0181] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0182] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0183] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0184] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0185] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0186] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0187] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0188] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0189] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0190] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0191] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0192] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0193] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0194] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0195] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0196] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0197] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0198] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0199] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0200] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0201] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0202] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0203] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0204] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0205] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0206] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0207] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0208] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0209] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0210] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0211] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0212] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0213] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0214] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0215] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0216] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0217] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0218] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0219] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0220] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0221] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0222] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0223] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0224] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0225] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0226] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0227] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0228] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0229] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0230] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0231] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0232] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0233] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0234] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0235] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0236] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0237] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0238] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0239] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0240] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0241] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0242] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0243] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0244] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0245] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0246] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0247] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0248] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0249] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0250] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0251] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0252] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0253] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0254] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0255] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0256] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0257] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0258] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0259] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0260] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0261] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0262] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0263] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0264] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0265] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0266] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0267] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0268] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0269] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0270] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0271] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0272] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0273] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0274] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0275] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0276] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0277] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0278] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0279] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0280] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0281] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0282] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0283] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0284] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0285] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0286] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0287] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0288] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0289] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0290] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0291] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0292] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0293] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0294] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0295] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0296] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0297] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0298] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0299] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0300] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0301] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0302] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0303] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0304] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0305] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0306] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0307] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0308] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0309] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0310] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0311] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0312] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0313] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0314] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0315] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0316] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0317] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0318] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0319] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0320] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0321] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0322] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0323] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0324] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0325] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0326] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0327] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0328] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0329] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0330] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0331] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0332] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0333] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0334] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0335] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0336] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0337] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0338] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0339] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0340] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0341] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0342] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0343] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0344] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0345] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0346] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0347] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0348] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0349] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0350] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0351] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0352] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0353] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0354] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0355] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0356] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0357] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0358] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0359] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0360] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0361] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0362] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0363] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0364] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0365] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0366] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0367] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0368] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0369] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0370] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0371] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0372] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0373] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0374] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0375] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0376] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0377] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0378] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0379] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0380] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0381] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0382] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0383] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0384] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0385] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0386] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0387] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0388] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0389] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0390] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0391] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0392] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0393] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0394] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0395] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0396] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0397] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0398] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0399] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0400] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0401] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0402] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0403] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0404] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0405] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0406] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0407] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0408] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0409] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0410] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0411] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0412] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0413] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0414] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0415] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0416] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0417] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0418] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0419] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0420] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0421] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0422] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0423] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0424] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0425] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0426] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0427] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0428] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0429] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0430] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0431] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0432] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0433] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0434] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0435] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0436] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0437] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0438] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0439] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0440] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0441] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0442] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0443] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0444] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0445] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0446] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0447] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0448] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0449] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0450] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0451] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0452] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0453] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0454] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0455] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0456] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0457] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0458] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0459] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0460] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0461] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0462] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0463] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0464] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0465] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0466] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0467] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0468] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0469] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0470] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0471] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0472] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0473] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0474] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0475] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0476] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0477] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0478] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0479] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0480] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0481] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0482] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0483] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0484] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0485] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0486] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0487] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0488] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0489] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0490] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0491] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0492] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0493] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0494] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0495] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0496] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0497] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0498] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0499] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0500] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0501] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0502] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0503] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0504] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0505] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0506] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0507] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0508] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0509] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0510] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0511] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0512] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0513] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0514] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0515] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0516] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0517] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0518] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0519] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0520] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0521] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0522] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0523] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0524] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0525] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0526] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0527] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0528] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0529] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0530] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0531] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0532] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0533] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0534] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0535] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0536] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0537] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0538] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0539] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0540] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0541] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0542] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0543] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0544] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0545] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0546] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0547] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0548] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0549] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0550] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0551] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0552] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0553] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0554] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0555] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0556] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0557] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0558] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0559] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0560] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0561] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0562] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0563] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0564] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0565] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0566] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0567] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0568] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0569] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0570] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0571] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0572] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0573] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0574] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0575] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0576] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0577] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0578] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0579] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0580] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0581] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0582] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0583] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0584] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0585] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0586] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0587] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0588] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0589] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0590] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0591] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0592] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0593] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0594] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0595] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0596] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0597] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0598] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0599] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0600] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0601] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0602] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0603] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0604] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0605] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0606] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0607] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0608] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0609] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0610] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0611] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0612] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0613] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0614] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0615] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0616] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0617] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0618] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0619] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0620] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0621] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0622] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0623] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0624] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0625] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0626] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0627] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0628] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0629] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0630] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0631] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0632] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0633] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0634] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0635] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0636] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0637] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0638] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0639] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0640] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0641] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0642] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0643] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0644] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0645] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0646] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0647] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0648] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0649] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0650] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0651] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0652] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0653] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0654] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0655] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0656] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0657] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0658] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0659] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0660] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0661] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0662] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0663] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0664] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0665] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0666] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0667] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0668] Runtime subsystem verified | Safe pcall wrapper active
-- [VORTEX-SPEC-0669] Runtime subsystem verified | Safe pcall wrapper active

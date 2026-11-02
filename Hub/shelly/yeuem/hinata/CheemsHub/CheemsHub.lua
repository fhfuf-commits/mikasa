--[[
================================================================
Cheems Hub - LocalScript v6.5.1
Location : StarterPlayer > StarterPlayerScripts
================================================================
--]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local UserSettings = game:GetService("UserSettings")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
-- ============================================================
-- CẤU HÌNH (CONFIG)
-- ============================================================
local CONFIG = {
GuiName = "CheemsHubGui",
Version = "6.5.1",
ToggleKey = Enum.KeyCode.RightShift,
WalkSpeed = { Min = 1, Max = 500, Default = 16 },
Jump = { Min = 1, Max = 500, Default = 50 },
FarmHeight = { Min = 3, Max = 30, Default = 6 },
FarmDistance = { Min = 3, Max = 25, Default = 8 },
AttackDistance = { Min = 5, Max = 60, Default = 20 },
AttackSettle = { Min = 0.05, Max = 1.5, Default = 0.4 },
MoveMode = "Align",
StopDistanceLoot = 5,
RetargetInterval = 0.15,
EnemyTag = "FarmableEnemy",
FallbackEnemyFolder = "Enemies",
LootTags = { "LootChest", "DevilFruit" },
ESP = {
EnemyColor = Color3.fromRGB(0, 200, 255),
TeamColor = Color3.fromRGB(80, 255, 120),
ShowName = true,
ShowHealth = true,
ShowDistance = true,
SameTeamOnly = false,
UpdateInterval = 0.4,
},
NotifyDuration = 2.5,
EnemyScanInterval = 1.0,
LootScanInterval = 1.0,
}
local oldGui = PlayerGui:FindFirstChild(CONFIG.GuiName)
if oldGui then oldGui:Destroy() end
-- ============================================================
-- HÀM TRỢ GIÚP (HELPERS)
-- ============================================================
local function getCharacter() return LocalPlayer.Character end
local function getHumanoid()
local c = getCharacter()
return c and c:FindFirstChildOfClass("Humanoid") or nil
end
local function getHRP()
local c = getCharacter()
return c and c:FindFirstChild("HumanoidRootPart") or nil
end
local function isAlive()
local h = getHumanoid()
return h ~= nil and h.Health > 0
end
local function normalizeName(n) return (n:gsub("%s*%(%d+%)%s*$", "")) end
local function clamp(v, lo, hi)
if v < lo then return lo end
if v > hi then return hi end
return v
end
-- ============================================================
-- HỆ THỐNG THÔNG BÁO (NOTIFY)
-- ============================================================
local NotifyContainer = nil
local Authenticated = false
local speedToggleRef, jumpToggleRef
local function notify(text, isError)
if not NotifyContainer or not NotifyContainer.Parent then return end
local frame = Instance.new("Frame")
frame.BackgroundColor3 = isError and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(24, 28, 40)
frame.BackgroundTransparency = 0.15
frame.Size = UDim2.new(0, 260, 0, 34)
frame.AutomaticSize = Enum.AutomaticSize.X
frame.Position = UDim2.new(0.5, 0, 0, 0)
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.BorderSizePixel = 0
local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = frame
local stroke = Instance.new("UIStroke")
stroke.Color = isError and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(0, 190, 255)
stroke.Thickness = 1; stroke.Parent = frame
local l = Instance.new("TextLabel")
l.BackgroundTransparency = 1
l.Size = UDim2.new(1, -20, 1, 0); l.Position = UDim2.new(0, 10, 0, 0)
l.Font = Enum.Font.GothamMedium; l.TextSize = 13
l.TextColor3 = Color3.new(1, 1, 1); l.TextXAlignment = Enum.TextXAlignment.Left
l.Text = (isError and "⚠️ " or "♊ ") .. text; l.Parent = frame
frame.Parent = NotifyContainer
task.spawn(function()
task.wait(CONFIG.NotifyDuration)
if frame.Parent then
TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
task.wait(0.35); frame:Destroy()
end
end)
for _, o in ipairs(NotifyContainer:GetChildren()) do
if o:IsA("Frame") and o ~= frame then
local y = o.Position.Y.Offset
TweenService:Create(o, TweenInfo.new(0.2), { Position = UDim2.new(0.5, 0, 0, y - 42) }):Play()
end
end
end
-- ============================================================
-- NOCLIP (REFERENCE COUNTING)
-- ============================================================
local NoclipManager = {
_refCount = 0, _active = false, _saved = {},
_charConn = nil, _descConn = nil,
}

function NoclipManager:_applyPart(part)
if not self._active or not part or not part:IsA("BasePart") then return end
if self._saved[part] == nil then
self._saved[part] = { collide = part.CanCollide, massless = part.Massless }
end
part.CanCollide = false
part.Massless = true
end

function NoclipManager:_bindCharacter(char)
if self._descConn then self._descConn:Disconnect(); self._descConn = nil end
if not char then return end
for _, d in ipairs(char:GetDescendants()) do self:_applyPart(d) end
self._descConn = char.DescendantAdded:Connect(function(d)
self:_applyPart(d)
end)
end

function NoclipManager:_start()
if self._active then return end
self._active = true
self:_bindCharacter(getCharacter())
self._charConn = LocalPlayer.CharacterAdded:Connect(function(char)
task.defer(function()
if self._active then self:_bindCharacter(char) end
end)
end)
end

function NoclipManager:_stop()
if not self._active and next(self._saved) == nil then return end
self._active = false
if self._charConn then self._charConn:Disconnect(); self._charConn = nil end
if self._descConn then self._descConn:Disconnect(); self._descConn = nil end
for part, saved in pairs(self._saved) do
if part and part.Parent then
pcall(function()
part.CanCollide = saved.collide
part.Massless = saved.massless
end)
end
end
self._saved = {}
end

function NoclipManager:acquire()
self._refCount += 1
if self._refCount == 1 then self:_start() end
end

function NoclipManager:release()
self._refCount = math.max(0, self._refCount - 1)
if self._refCount == 0 then self:_stop() end
end

function NoclipManager:forceStop()
self._refCount = 0
self:_stop()
end

-- ============================================================
-- FIX LAG
-- ============================================================
local FixLag = {
enabled = false, saved = {}, hidden = {}, hiddenSky = {}, conns = {},
lightingSaved = nil, heartbeat = nil, terrainSaved = nil, qualitySaved = nil,
}
local FX_CLASSES = {
"ParticleEmitter","Trail","Beam","Smoke","Fire","Sparkles",
"PointLight","SpotLight","SurfaceLight",
"BloomEffect","BlurEffect","SunRaysEffect","ColorCorrectionEffect",
"DepthOfFieldEffect","Atmosphere","Highlight",
"SelectionBox","SelectionSphere","Explosion",
}
local function rememberProp(self, inst, prop, newVal)
if not inst.Parent then return end
local e = self.saved[inst]
if not e then e = {}; self.saved[inst] = e end
if e[prop] == nil then e[prop] = inst[prop] end
pcall(function() inst[prop] = newVal end)
end
function FixLag:_process(inst, char)
if char and inst:IsDescendantOf(char) then return end
for _, cls in ipairs(FX_CLASSES) do
if inst:IsA(cls) then
rememberProp(self, inst, "Enabled", false)
return
end
end
if inst:IsA("BasePart") then
rememberProp(self, inst, "CastShadow", false)
rememberProp(self, inst, "Material", Enum.Material.SmoothPlastic)
if inst:IsA("MeshPart") then
rememberProp(self, inst, "TextureID", "")
rememberProp(self, inst, "RenderFidelity", Enum.RenderFidelity.Performance)
end
end
if inst:IsA("Decal") or inst:IsA("Texture") then
rememberProp(self, inst, "Transparency", 1)
end
if inst:IsA("SurfaceAppearance") then
if inst.Parent and not self.hidden[inst] then
self.hidden[inst] = inst.Parent; inst.Parent = nil
end
end
if inst:IsA("SurfaceGui") and inst:IsDescendantOf(workspace) then
rememberProp(self, inst, "Enabled", false)
end
if inst:IsA("Sound") then
rememberProp(self, inst, "Volume", 0)
end
if inst:IsA("Sky") then
if inst.Parent then
table.insert(self.hiddenSky, { inst = inst, parent = inst.Parent })
inst.Parent = nil
end
end
if inst:IsA("Clouds") then
rememberProp(self, inst, "Cover", 0)
rememberProp(self, inst, "Density", 0)
end
if inst:IsA("Humanoid") then
rememberProp(self, inst, "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None)
end
if inst:IsA("Accessory") or inst:IsA("Hat") then
local h = inst:FindFirstChild("Handle")
if h then
rememberProp(self, h, "Transparency", 1)
rememberProp(self, h, "LocalTransparencyModifier", 1)
end
end
end
function FixLag:_applyTo(container)
if not container then return end
local char = getCharacter()
for _, d in ipairs(container:GetDescendants()) do self:_process(d, char) end
end
function FixLag:start()
if self.enabled then return end
self.enabled = true
self.saved = {}; self.hidden = {}; self.hiddenSky = {}; self.qualitySaved = nil
self:_applyTo(workspace)
self:_applyTo(Lighting)
if workspace.Terrain then
self.terrainSaved = {
Decoration = workspace.Terrain.Decoration,
WaterWaveSize = workspace.Terrain.WaterWaveSize,
WaterTransparency = workspace.Terrain.WaterTransparency,
}
workspace.Terrain.Decoration = false
workspace.Terrain.WaterWaveSize = 0
workspace.Terrain.WaterTransparency = 1
end
self.lightingSaved = {
FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
GlobalShadows = Lighting.GlobalShadows,
EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
ShadowSoftness = Lighting.ShadowSoftness,
Brightness = Lighting.Brightness,
}
Lighting.FogEnd = 1e6; Lighting.FogStart = 1e6
Lighting.GlobalShadows = false
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0
Lighting.ShadowSoftness = 0
Lighting.Brightness = math.max(Lighting.Brightness, 2)
pcall(function()
local gameSettings = UserSettings():GetService("UserGameSettings")
self.qualitySaved = gameSettings.SavedQualityLevel
gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
end)
table.insert(self.conns, workspace.DescendantAdded:Connect(function(d)
if self.enabled then self:_process(d, getCharacter()) end
end))
table.insert(self.conns, Lighting.DescendantAdded:Connect(function(d)
if self.enabled then self:_process(d, nil) end
end))
end
function FixLag:stop()
if not self.enabled then return end
self.enabled = false
if self.heartbeat then self.heartbeat:Disconnect(); self.heartbeat = nil end
for inst, props in pairs(self.saved) do
if inst and inst.Parent then
for prop, val in pairs(props) do pcall(function() inst[prop] = val end) end
end
end
self.saved = {}
for inst, parent in pairs(self.hidden) do
if inst and parent then inst.Parent = parent end
end
self.hidden = {}
for _, entry in ipairs(self.hiddenSky) do
if entry.inst and entry.parent then
pcall(function() entry.inst.Parent = entry.parent end)
end
end
self.hiddenSky = {}
if self.qualitySaved ~= nil then
pcall(function()
UserSettings():GetService("UserGameSettings").SavedQualityLevel = self.qualitySaved
end)
self.qualitySaved = nil
end
if self.terrainSaved and workspace.Terrain then
workspace.Terrain.Decoration = self.terrainSaved.Decoration
workspace.Terrain.WaterWaveSize = self.terrainSaved.WaterWaveSize
workspace.Terrain.WaterTransparency = self.terrainSaved.WaterTransparency
self.terrainSaved = nil
end
if self.lightingSaved then
for k, v in pairs(self.lightingSaved) do pcall(function() Lighting[k] = v end) end
self.lightingSaved = nil
end
for _, c in ipairs(self.conns) do c:Disconnect() end
self.conns = {}
end
-- ============================================================
-- FULL BRIGHT
-- ============================================================
local FullBright = { enabled = false, originals = nil, conn = nil }
local FB_VALUES = {
Brightness = 2,
Ambient = Color3.fromRGB(180, 180, 180),
OutdoorAmbient = Color3.fromRGB(180, 180, 180),
ExposureCompensation = 0.2,
GlobalShadows = false,
EnvironmentDiffuseScale = 0.6,
EnvironmentSpecularScale = 0.6,
}
function FullBright:start()
if self.enabled then return end
self.enabled = true
self.originals = {}
for k in pairs(FB_VALUES) do self.originals[k] = Lighting[k] end
for k, v in pairs(FB_VALUES) do pcall(function() Lighting[k] = v end) end
self.conn = Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
if self.enabled and Lighting.Brightness ~= FB_VALUES.Brightness then
Lighting.Brightness = FB_VALUES.Brightness
end
end)
end
function FullBright:stop()
if not self.enabled then return end
self.enabled = false
if self.conn then self.conn:Disconnect(); self.conn = nil end
if self.originals then
for k, v in pairs(self.originals) do pcall(function() Lighting[k] = v end) end
self.originals = nil
end
end
-- ============================================================
-- SPEED WALK
-- ============================================================
local SpeedWalk = {
enabled = false, value = CONFIG.WalkSpeed.Default, original = nil,
conns = {}, propConn = nil,
}
local function speedHook(hum)
if SpeedWalk.propConn then SpeedWalk.propConn:Disconnect() end
SpeedWalk.propConn = nil
if not hum then return end
SpeedWalk.propConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
if SpeedWalk.enabled and hum.WalkSpeed ~= SpeedWalk.value then
hum.WalkSpeed = SpeedWalk.value
end
end)
end
function SpeedWalk:start()
if self.enabled then return end
self.enabled = true
local h = getHumanoid()
if h then
self.original = h.WalkSpeed
h.WalkSpeed = self.value
speedHook(h)
end
table.insert(self.conns, RunService.PreSimulation:Connect(function()
if not self.enabled then return end
local hum = getHumanoid()
if not hum or hum.Health <= 0 then return end
if hum.WalkSpeed ~= self.value then hum.WalkSpeed = self.value end
end))
table.insert(self.conns, LocalPlayer.CharacterAdded:Connect(function()
task.wait(0.2)
if not self.enabled then return end
local hum = getHumanoid()
if hum then
if self.original == nil then self.original = hum.WalkSpeed end
hum.WalkSpeed = self.value
speedHook(hum)
end
end))
end
function SpeedWalk:stop()
if not self.enabled then return end
self.enabled = false
if self.propConn then self.propConn:Disconnect(); self.propConn = nil end
for _, c in ipairs(self.conns) do c:Disconnect() end
self.conns = {}
local hum = getHumanoid()
if hum then hum.WalkSpeed = self.original or CONFIG.WalkSpeed.Default end
self.original = nil
end
function SpeedWalk:set(v)
self.value = clamp(tonumber(v) or self.value, CONFIG.WalkSpeed.Min, CONFIG.WalkSpeed.Max)
if self.enabled then
local hum = getHumanoid()
if hum then hum.WalkSpeed = self.value end
end
end
-- ============================================================
-- HIGH JUMP
-- ============================================================
local HighJump = {
enabled = false, value = CONFIG.Jump.Default, mode = "JumpPower",
original = nil, conn = nil, heartbeat = nil,
}
local function detectJumpMode(h)
if not h then return "JumpPower" end
return h.UseJumpPower and "JumpPower" or "JumpHeight"
end
local function applyJump()
local h = getHumanoid(); if not h then return end
if HighJump.mode == "JumpPower" then
h.UseJumpPower = true; h.JumpPower = HighJump.value
else
h.UseJumpPower = false; h.JumpHeight = HighJump.value
end
end
function HighJump:start()
if self.enabled then return end
self.enabled = true
local h = getHumanoid()
if h then
self.mode = detectJumpMode(h)
self.original = (self.mode == "JumpPower") and h.JumpPower or h.JumpHeight
end
applyJump()
self.heartbeat = RunService.PreSimulation:Connect(function()
if not self.enabled then return end
local hum = getHumanoid()
if not hum or hum.Health <= 0 then return end
if self.mode == "JumpPower" then
hum.UseJumpPower = true; hum.JumpPower = self.value
else
hum.UseJumpPower = false; hum.JumpHeight = self.value
end
end)
self.conn = LocalPlayer.CharacterAdded:Connect(function()
task.wait(0.2)
if not self.enabled then return end
local hum = getHumanoid()
if hum then
self.mode = detectJumpMode(hum)
if self.original == nil then
self.original = (self.mode == "JumpPower") and hum.JumpPower or hum.JumpHeight
end
applyJump()
end
end)
end
function HighJump:stop()
if not self.enabled then return end
self.enabled = false
if self.heartbeat then self.heartbeat:Disconnect(); self.heartbeat = nil end
if self.conn then self.conn:Disconnect(); self.conn = nil end
local hum = getHumanoid()
if hum then
local o = self.original or CONFIG.Jump.Default
if self.mode == "JumpPower" then hum.UseJumpPower = true; hum.JumpPower = o
else hum.UseJumpPower = false; hum.JumpHeight = o end
end
self.original = nil
end
function HighJump:set(v)
self.value = clamp(tonumber(v) or self.value, CONFIG.Jump.Min, CONFIG.Jump.Max)
if self.enabled then applyJump() end
end
-- ============================================================
-- ATTACK & LOOT LOGIC (v6.4)
-- ============================================================
local AttackState = {
cooldown = 0.15,
maxDistance = CONFIG.AttackDistance.Default,
settleTime = CONFIG.AttackSettle.Default,
lastAttackAt = 0,
debug = false,
}
local function attackTarget(target)
if not target or not target.Parent then return false end
local hrp = getHRP(); if not hrp then return false end
local enemyRoot = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
if not enemyRoot then return false end
local dist = (hrp.Position - enemyRoot.Position).Magnitude
if dist > AttackState.maxDistance then
if AttackState.debug then
print(string.format("[Attack] SKIP %s — quá xa (%.1f > %.1f)", target.Name, dist, AttackState.maxDistance))
end
return false
end
local now = os.clock()
if now - AttackState.lastAttackAt < AttackState.cooldown then return false, "cooldown" end
AttackState.lastAttackAt = now
local char = getCharacter()
local tool = char and char:FindFirstChildOfClass("Tool")
local actionIssued = false
if tool then
local ok = pcall(function() tool:Activate() end)
actionIssued = ok
end
if not actionIssued then
local camera = workspace.CurrentCamera
if camera then
local ok = pcall(function()
VirtualUser:Button1Down(Vector2.new(0, 0), camera.CFrame)
VirtualUser:Button1Up(Vector2.new(0, 0), camera.CFrame)
end)
actionIssued = ok
end
end
if AttackState.debug then
print(string.format("[Attack] ACTION_SENT %s — dist=%.1f tool=%s", target.Name, dist, tostring(tool ~= nil)))
end
if actionIssued then return true, "sent" end
return false, "failed"
end

local function collectLoot(item)
if not item or not item.Parent then return false end
local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
if prompt and prompt.Enabled then
local ok = pcall(function()
prompt:InputHoldBegin()
task.delay((prompt.HoldDuration or 0.3) + 0.05, function()
if prompt and prompt.Parent then pcall(function() prompt:InputHoldEnd() end) end
end)
end)
return ok
end
local cd = item:FindFirstChildWhichIsA("ClickDetector", true)
if cd and cd.Parent then
local ok = pcall(function() cd:Click(LocalPlayer) end)
return ok
end
return false
end

-- ============================================================
-- AUTO FARM v6.4
-- ============================================================
local AutoFarm = {
enabled = false, selectedType = nil, target = nil, conn = nil,
noclipHeld = false, status = "Tắt",
findCache = nil, findTimer = 0, savedState = nil,
height = CONFIG.FarmHeight.Default,
distance = CONFIG.FarmDistance.Default,
settleStart = nil, targetChanged = nil,
}
local MOVER_NAMES = {
"AutoFarmAlignPos","AutoFarmAlignOri",
"AutoFarmHover","AutoFarmGyro","AutoFarmRootAtt",
}
local function destroyMovers(hrp)
if not hrp then return end
for _, n in ipairs(MOVER_NAMES) do
local m = hrp:FindFirstChild(n)
if m then m:Destroy() end
end
end
-- ============================================================
-- ENEMY DETECTION (v6.4 — RECURSIVE SCAN)
-- ============================================================
local EnemyCache = { list = {}, lastScan = 0, scanInterval = CONFIG.EnemyScanInterval, hasScanned = false }
local function isPlayerCharacter(model)
return Players:GetPlayerFromCharacter(model) ~= nil
end
local function isValidEnemy(model)
if not model or not model.Parent then return false end
if isPlayerCharacter(model) then return false end
local hum = model:FindFirstChildOfClass("Humanoid")
if not hum or hum.Health <= 0 then return false end
return (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) ~= nil
end
local function scanForEnemies()
local list, seen = {}, {}
local function addCandidate(model)
if model and not seen[model] and isValidEnemy(model) then
seen[model] = true
list[#list + 1] = model
end
end
-- Ưu tiên tag để giảm phụ thuộc cấu trúc workspace.
for _, inst in ipairs(CollectionService:GetTagged(CONFIG.EnemyTag)) do
local model = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
addCandidate(model)
end
-- Thư mục cấu hình: quét đệ quy.
local folder = workspace:FindFirstChild(CONFIG.FallbackEnemyFolder)
if folder then
for _, inst in ipairs(folder:GetDescendants()) do
if inst:IsA("Model") then addCandidate(inst) end
end
end
-- Fallback toàn workspace: bắt cả model lồng nhiều cấp, không chỉ cấp con trực tiếp.
for _, inst in ipairs(workspace:GetDescendants()) do
if inst:IsA("Model") and inst.Name ~= LocalPlayer.Name then addCandidate(inst) end
end
return list
end

local function getAllEnemies()
local now = os.clock()
if not EnemyCache.hasScanned or (now - EnemyCache.lastScan) > EnemyCache.scanInterval then
EnemyCache.list = scanForEnemies()
EnemyCache.lastScan = now
EnemyCache.hasScanned = true
end
local out = {}
for _, m in ipairs(EnemyCache.list) do
if isValidEnemy(m) then table.insert(out, m) end
end
return out
end
local function getEnemyTypes()
local set = {}
for _, m in ipairs(getAllEnemies()) do set[normalizeName(m.Name)] = true end
local arr = {}
for k in pairs(set) do table.insert(arr, k) end
table.sort(arr)
return arr
end
local function isEnemyAlive(m)
return isValidEnemy(m)
end
local function findNearestEnemy(typeName)
local hrp = getHRP(); if not hrp then return nil end
local best, bestDist = nil, math.huge
for _, m in ipairs(getAllEnemies()) do
if typeName == nil or typeName == "" or normalizeName(m.Name) == typeName then
if isValidEnemy(m) then
local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
if root then
local d = (root.Position - hrp.Position).Magnitude
if d < bestDist then bestDist = d; best = { model = m, root = root } end
end
end
end
end
return best
end
-- ============================================================
-- AUTO FARM SETUP / MOVE / STEP
-- ============================================================
local function autoFarmSetup()
local hum = getHumanoid()
local hrp = getHRP()
if not hum or not hrp then return end
AutoFarm.savedState = {
anchored = hrp.Anchored,
platformStand = hum.PlatformStand,
autoRotate = hum.AutoRotate,
walkSpeed = hum.WalkSpeed,
jumpPower = hum.JumpPower,
jumpHeight = hum.JumpHeight,
useJumpPower = hum.UseJumpPower,
}
destroyMovers(hrp)
local mode = CONFIG.MoveMode
if mode == "Anchored" then
hrp.Anchored = true
hum.PlatformStand = true
hum.AutoRotate = false
hum.WalkSpeed = 0
hum.JumpPower = 0
hum.JumpHeight = 0
elseif mode == "Align" then
hrp.Anchored = false
hum.PlatformStand = true
hum.AutoRotate = false
hum.WalkSpeed = 0
hum.JumpPower = 0
hum.JumpHeight = 0
local att = hrp:FindFirstChild("AutoFarmRootAtt")
if not att then
att = Instance.new("Attachment")
att.Name = "AutoFarmRootAtt"
att.Parent = hrp
end
local ap = Instance.new("AlignPosition")
ap.Name = "AutoFarmAlignPos"
ap.Mode = Enum.PositionAlignmentMode.OneAttachment
ap.Attachment0 = att
ap.MaxForce = 1e5
ap.MaxVelocity = 250
ap.Responsiveness = 15
ap.Position = hrp.Position
ap.ApplyAtCenterOfMass = false
ap.Parent = hrp
local ao = Instance.new("AlignOrientation")
ao.Name = "AutoFarmAlignOri"
ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
ao.Attachment0 = att
ao.MaxTorque = 1e5
ao.MaxAngularVelocity = 30
ao.Responsiveness = 15
ao.CFrame = hrp.CFrame
ao.Parent = hrp
elseif mode == "Ground" then
hrp.Anchored = false
hum.PlatformStand = false
hum.AutoRotate = true
hum.WalkSpeed = 0
hum.JumpPower = 0
hum.JumpHeight = 0
end
end
local function autoFarmRestore()
local s = AutoFarm.savedState
if not s then return end
local hum = getHumanoid()
local hrp = getHRP()
if hrp then
destroyMovers(hrp)
hrp.Anchored = s.anchored
end
if hum then
hum.PlatformStand = s.platformStand
hum.AutoRotate = s.autoRotate
hum.WalkSpeed = s.walkSpeed
hum.JumpPower = s.jumpPower
hum.JumpHeight = s.jumpHeight
hum.UseJumpPower = s.useJumpPower
end
AutoFarm.savedState = nil
end
local function autoFarmMove(dt, hrp, enemyPos)
local mode = CONFIG.MoveMode
if mode == "Align" then
local ap = hrp:FindFirstChild("AutoFarmAlignPos")
local ao = hrp:FindFirstChild("AutoFarmAlignOri")
local standPos = enemyPos + Vector3.new(0, AutoFarm.height, 0)
if ap then ap.Position = standPos end
if ao then ao.CFrame = CFrame.lookAt(standPos, enemyPos) end
elseif mode == "Ground" then
local currentPos = hrp.Position
local dirXZ = Vector3.new(currentPos.X - enemyPos.X, 0, currentPos.Z - enemyPos.Z)
if dirXZ.Magnitude < 0.01 then dirXZ = Vector3.new(0, 0, -1) end
local goalPos = enemyPos + dirXZ.Unit * AutoFarm.distance
goalPos = Vector3.new(goalPos.X, currentPos.Y, goalPos.Z)
local delta = goalPos - currentPos
if delta.Magnitude > 0.3 then
hrp.CFrame = CFrame.lookAt(currentPos + delta * math.min(1, dt * 14), enemyPos)
else
hrp.CFrame = CFrame.lookAt(currentPos, enemyPos)
end
hrp.AssemblyLinearVelocity = Vector3.zero
else -- Anchored
local currentPos = hrp.Position
local standPos = enemyPos + Vector3.new(0, AutoFarm.height, 0)
local dist = (standPos - currentPos).Magnitude
local newPos
if dist > 0.3 then
newPos = currentPos:Lerp(standPos, math.min(1, dt * 14))
else
newPos = standPos
end
hrp.CFrame = CFrame.lookAt(newPos, enemyPos)
hrp.AssemblyLinearVelocity = Vector3.zero
hrp.AssemblyAngularVelocity = Vector3.zero
end
end
local function autoFarmStep(dt)
if not AutoFarm.enabled then return end
if not isAlive() then return end
local hrp = getHRP(); if not hrp then return end
AutoFarm.findTimer += dt
if not AutoFarm.findCache or AutoFarm.findTimer > CONFIG.RetargetInterval then
AutoFarm.findCache = findNearestEnemy(AutoFarm.selectedType)
AutoFarm.findTimer = 0
end
local found = AutoFarm.findCache
if not found or not isEnemyAlive(found.model) then
AutoFarm.target = nil; AutoFarm.findCache = nil
AutoFarm.settleStart = nil; AutoFarm.targetChanged = nil
AutoFarm.status = "Đang chờ quái xuất hiện"; return
end
AutoFarm.target = found.model
local enemyPos = found.root.Position
autoFarmMove(dt, hrp, enemyPos)
if AutoFarm.targetChanged ~= found.model then
AutoFarm.targetChanged = found.model
AutoFarm.settleStart = os.clock()
end
local settleElapsed = os.clock() - (AutoFarm.settleStart or 0)
local realDist = (hrp.Position - enemyPos).Magnitude
local settled = settleElapsed >= AttackState.settleTime
local modeTag = CONFIG.MoveMode
if settled then
local attacked, attackResult = attackTarget(found.model)
if attacked then
AutoFarm.status = string.format("[%s] Đã gửi thao tác đánh: %s (d=%.1f, cao %d)", modeTag, found.model.Name, realDist, AutoFarm.height)
elseif realDist > AttackState.maxDistance then
AutoFarm.status = string.format("[%s] Quá xa: %.1f > %.1f — giảm cao", modeTag, realDist, AttackState.maxDistance)
elseif attackResult == "cooldown" then
AutoFarm.status = string.format("[%s] Hồi chiêu... (d=%.1f)", modeTag, realDist)
else
AutoFarm.status = string.format("[%s] Không gửi được thao tác đánh (d=%.1f)", modeTag, realDist)
end
else
AutoFarm.status = string.format("[%s] Ổn định %.1fs / %.1fs", modeTag, settleElapsed, AttackState.settleTime)
end
end
function AutoFarm:start()
if self.enabled then return end
self.enabled = true
self.findTimer = 0; self.findCache = nil
self.settleStart = nil; self.targetChanged = nil
if not self.noclipHeld then
NoclipManager:acquire(); self.noclipHeld = true
end
autoFarmSetup()
self.conn = RunService.RenderStepped:Connect(function(dt) autoFarmStep(dt) end)
self._respawnConns = self._respawnConns or {}
table.insert(self._respawnConns, LocalPlayer.CharacterAdded:Connect(function()
task.wait(0.3)
if self.enabled then
autoFarmSetup()
self.settleStart = nil
self.targetChanged = nil
end
end))
end
function AutoFarm:stop()
if not self.enabled then return end
self.enabled = false
if self.conn then self.conn:Disconnect(); self.conn = nil end
if self._respawnConns then
for _, c in ipairs(self._respawnConns) do c:Disconnect() end
self._respawnConns = nil
end
self.settleStart = nil
self.targetChanged = nil
autoFarmRestore()
self.target = nil; self.findCache = nil; self.status = "Tắt"
if self.noclipHeld then
NoclipManager:release(); self.noclipHeld = false
end
end
function AutoFarm:setHeight(v)
self.height = clamp(tonumber(v) or self.height, CONFIG.FarmHeight.Min, CONFIG.FarmHeight.Max)
end
function AutoFarm:setDistance(v)
self.distance = clamp(tonumber(v) or self.distance, CONFIG.FarmDistance.Min, CONFIG.FarmDistance.Max)
end
function AutoFarm:restartMover()
if not self.enabled then return end
autoFarmRestore()
autoFarmSetup()
self.settleStart = nil
self.targetChanged = nil
end
-- ============================================================
-- AUTO LOOT v6.4 (RECURSIVE SCAN)
-- ============================================================
local AutoLoot = {
enabled = false, selectedTags = {}, target = nil, conn = nil,
noclipHeld = false, status = "Tắt",
findCache = nil, findTimer = 0, savedState = nil,
}
local LootCache = { list = {}, lastScan = 0, scanInterval = CONFIG.LootScanInterval, hasScanned = false }
local function hasInteractable(inst)
if not inst or not inst.Parent then return false end
local p = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
if p and p.Enabled then return true end
local c = inst:FindFirstChildWhichIsA("ClickDetector", true)
if c and c.Parent then return true end
return false
end
local function getLootContainer(inst)
if not inst then return nil end
if inst:IsA("Model") or inst:IsA("BasePart") then return inst end
local model = inst:FindFirstAncestorOfClass("Model")
if model then return model end
local part = inst:FindFirstAncestorWhichIsA("BasePart")
return part
end

local function scanForLoot()
local list, seen = {}, {}
local function addLoot(inst, tag)
local candidate = getLootContainer(inst)
if candidate and not seen[candidate] and candidate:IsDescendantOf(workspace) and hasInteractable(candidate) then
seen[candidate] = true
list[#list + 1] = { inst = candidate, tag = tag or "auto" }
end
end
-- Tagged containers.
for _, tag in ipairs(CONFIG.LootTags) do
for _, inst in ipairs(CollectionService:GetTagged(tag)) do addLoot(inst, tag) end
end
-- Recursive fallback: nested prompts/detectors are found even inside folders/models.
for _, inst in ipairs(workspace:GetDescendants()) do
if inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector") then
addLoot(inst, "auto")
end
end
return list
end

local function getAllLoot()
local now = os.clock()
if not LootCache.hasScanned or (now - LootCache.lastScan) > LootCache.scanInterval then
LootCache.list = scanForLoot()
LootCache.lastScan = now
LootCache.hasScanned = true
end
local out = {}
for _, e in ipairs(LootCache.list) do
if e.inst and e.inst.Parent then table.insert(out, e) end
end
return out
end
local function getLootPosition(inst)
if not inst or not inst.Parent then return nil end
if inst:IsA("BasePart") then return inst.Position end
if inst:IsA("Model") then
local root = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
return root and root.Position or nil
end
return nil
end
local function findNearestLoot()
local hrp = getHRP(); if not hrp then return nil end
local best, bestDist = nil, math.huge
for _, entry in ipairs(getAllLoot()) do
local pos = getLootPosition(entry.inst)
if pos then
local d = (pos - hrp.Position).Magnitude
if d < bestDist then bestDist = d; best = { inst = entry.inst, pos = pos } end
end
end
return best
end
local function autoLootSetup()
local hum = getHumanoid(); local hrp = getHRP()
if not hum or not hrp then return end
AutoLoot.savedState = {
anchored = hrp.Anchored, platformStand = hum.PlatformStand,
autoRotate = hum.AutoRotate, walkSpeed = hum.WalkSpeed,
}
hrp.Anchored = true
hum.PlatformStand = true
hum.AutoRotate = false
hum.WalkSpeed = 0
end
local function autoLootRestore()
local s = AutoLoot.savedState
if not s then return end
local hum = getHumanoid(); local hrp = getHRP()
if hrp then hrp.Anchored = s.anchored end
if hum then
hum.PlatformStand = s.platformStand
hum.AutoRotate = s.autoRotate
hum.WalkSpeed = s.walkSpeed
end
AutoLoot.savedState = nil
end
local function autoLootStep(dt)
if not AutoLoot.enabled then return end
if not isAlive() then return end
local hrp = getHRP(); if not hrp then return end
AutoLoot.findTimer += dt
if not AutoLoot.findCache or AutoLoot.findTimer > CONFIG.RetargetInterval then
AutoLoot.findCache = findNearestLoot(); AutoLoot.findTimer = 0
end
local found = AutoLoot.findCache
if not found or not found.inst.Parent then
AutoLoot.target = nil; AutoLoot.findCache = nil
AutoLoot.status = "Đang chờ vật phẩm xuất hiện"; return
end
AutoLoot.target = found.inst
local itemPos = getLootPosition(found.inst) or found.pos
local currentPos = hrp.Position
local dist = (itemPos - currentPos).Magnitude
if dist > CONFIG.StopDistanceLoot + 0.3 then
local dir = (currentPos - itemPos)
if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, -1) end
local offsetPos = itemPos + dir.Unit * CONFIG.StopDistanceLoot
local alpha = math.min(1, dt * 10)
local newPos = currentPos:Lerp(offsetPos, alpha)
hrp.CFrame = CFrame.lookAt(newPos, itemPos)
AutoLoot.status = "Đang tới: " .. found.inst.Name
else
hrp.CFrame = CFrame.lookAt(currentPos, itemPos)
AutoLoot.status = "Đang gửi thao tác nhặt: " .. found.inst.Name
local ok = collectLoot(found.inst)
if ok then AutoLoot.findCache = nil
else AutoLoot.status = "Không thể gửi thao tác: " .. found.inst.Name; AutoLoot.findCache = nil; AutoLoot.findTimer = 0 end
end
hrp.AssemblyLinearVelocity = Vector3.zero
end
function AutoLoot:start()
if self.enabled then return end
self.enabled = true; self.findTimer = 0; self.findCache = nil
if not self.noclipHeld then
NoclipManager:acquire(); self.noclipHeld = true
end
autoLootSetup()
self.conn = RunService.RenderStepped:Connect(function(dt) autoLootStep(dt) end)
self._respawnConns = self._respawnConns or {}
table.insert(self._respawnConns, LocalPlayer.CharacterAdded:Connect(function()
task.wait(0.3)
if self.enabled then autoLootSetup() end
end))
end
function AutoLoot:stop()
if not self.enabled then return end
self.enabled = false
if self.conn then self.conn:Disconnect(); self.conn = nil end
if self._respawnConns then
for _, c in ipairs(self._respawnConns) do c:Disconnect() end
self._respawnConns = nil
end
autoLootRestore()
self.target = nil; self.findCache = nil; self.status = "Tắt"
if self.noclipHeld then
NoclipManager:release(); self.noclipHeld = false
end
end
-- ============================================================
-- ESP
-- ============================================================
local ESP = { enabled = false, entries = {}, loopConn = nil, playerConns = {}, playerBindings = {} }
local function clearEspEntry(plr)
local e = ESP.entries[plr]; if not e then return end
if e.highlight then e.highlight:Destroy() end
if e.billboard then e.billboard:Destroy() end
for _, c in ipairs(e.conns) do c:Disconnect() end
ESP.entries[plr] = nil
end
local function refreshEspFor(plr)
if plr == LocalPlayer then return end
clearEspEntry(plr)
if not ESP.enabled then return end
if CONFIG.ESP.SameTeamOnly and plr.Team ~= nil and plr.Team == LocalPlayer.Team then return end
local char = plr.Character; if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid")
if not hum or hum.Health <= 0 then return end
local color = (plr.Team and plr.Team == LocalPlayer.Team) and CONFIG.ESP.TeamColor or CONFIG.ESP.EnemyColor
local hl = Instance.new("Highlight")
hl.FillColor = color; hl.OutlineColor = Color3.fromRGB(255, 255, 255)
hl.FillTransparency = 0.65; hl.OutlineTransparency = 0.1
hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
hl.Adornee = char; hl.Parent = char
local head = char:FindFirstChild("Head") or char:FindFirstChildWhichIsA("BasePart")
if not head then hl:Destroy() return end
local bb = Instance.new("BillboardGui")
bb.Name = "GeminiESP"; bb.Size = UDim2.new(0, 136, 0, 40)
bb.StudsOffset = Vector3.new(0, 2.5, 0); bb.AlwaysOnTop = true
bb.Adornee = head; bb.Parent = head
local bg = Instance.new("Frame")
bg.BackgroundColor3 = Color3.fromRGB(15, 18, 25); bg.BackgroundTransparency = 0.35
bg.Size = UDim2.new(1, 0, 1, 0); bg.BorderSizePixel = 0; bg.Parent = bb
local bgc = Instance.new("UICorner"); bgc.CornerRadius = UDim.new(0, 6); bgc.Parent = bg
local nameL = Instance.new("TextLabel")
nameL.BackgroundTransparency = 1
nameL.Size = UDim2.new(1, -6, 0, 16); nameL.Position = UDim2.new(0, 4, 0, 2)
nameL.Font = Enum.Font.GothamBold; nameL.TextSize = 11
nameL.TextColor3 = Color3.new(1, 1, 1); nameL.TextXAlignment = Enum.TextXAlignment.Left
nameL.Text = CONFIG.ESP.ShowName and plr.DisplayName or ""
nameL.Visible = CONFIG.ESP.ShowName; nameL.Parent = bg
local distL = Instance.new("TextLabel")
distL.BackgroundTransparency = 1
distL.Size = UDim2.new(0, 48, 0, 16); distL.Position = UDim2.new(1, -52, 0, 2)
distL.Font = Enum.Font.Gotham; distL.TextSize = 10
distL.TextColor3 = Color3.fromRGB(0, 200, 255); distL.TextXAlignment = Enum.TextXAlignment.Right
distL.Text = "0m"; distL.Visible = CONFIG.ESP.ShowDistance; distL.Parent = bg
local hpB = Instance.new("Frame")
hpB.BackgroundColor3 = Color3.fromRGB(30, 34, 46); hpB.BorderSizePixel = 0
hpB.Size = UDim2.new(1, -8, 0, 5); hpB.Position = UDim2.new(0, 4, 1, -9)
hpB.Visible = CONFIG.ESP.ShowHealth; hpB.Parent = bg
Instance.new("UICorner", hpB).CornerRadius = UDim.new(1, 0)
local hpF = Instance.new("Frame")
hpF.BackgroundColor3 = Color3.fromRGB(0, 220, 120); hpF.BorderSizePixel = 0
hpF.Size = UDim2.new(1, 0, 1, 0); hpF.Parent = hpB
Instance.new("UICorner", hpF).CornerRadius = UDim.new(1, 0)
local conns = {}
table.insert(conns, hum.HealthChanged:Connect(function(h)
local mx = math.max(hum.MaxHealth, 1)
local ratio = math.clamp(h / mx, 0, 1)
hpF.Size = UDim2.new(ratio, 0, 1, 0)
hpF.BackgroundColor3 = Color3.fromHSV(ratio * 0.33, 0.85, 0.95)
end))
if hum.MaxHealth > 0 then
hpF.Size = UDim2.new(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 0, 1, 0)
end
ESP.entries[plr] = { highlight = hl, billboard = bb, distLabel = distL, conns = conns }
end
local function espDistanceLoop()
if not ESP.enabled then return end
local myHrp = getHRP(); if not myHrp then return end
for plr, e in pairs(ESP.entries) do
if e.distLabel and plr.Character then
local root = plr.Character:FindFirstChild("HumanoidRootPart")
if root then
e.distLabel.Text = string.format("%dm", math.floor((root.Position - myHrp.Position).Magnitude))
end
end
end
end
local function bindEspPlayer(plr)
if plr == LocalPlayer then return end
local c1 = plr.CharacterAdded:Connect(function()
task.defer(function() if ESP.enabled then refreshEspFor(plr) end end)
end)
local c2 = plr.CharacterRemoving:Connect(function() clearEspEntry(plr) end)
local c3 = plr:GetPropertyChangedSignal("Team"):Connect(function()
if ESP.enabled then refreshEspFor(plr) end
end)
ESP.playerBindings[plr] = { c1, c2, c3 }
if plr.Character then refreshEspFor(plr) end
end

function ESP:start()
if self.enabled then return end
self.enabled = true
for _, plr in ipairs(Players:GetPlayers()) do bindEspPlayer(plr) end
table.insert(self.playerConns, Players.PlayerAdded:Connect(bindEspPlayer))
table.insert(self.playerConns, Players.PlayerRemoving:Connect(function(plr)
clearEspEntry(plr)
local bindings = self.playerBindings[plr]
if bindings then
for _, c in ipairs(bindings) do c:Disconnect() end
self.playerBindings[plr] = nil
end
end))
table.insert(self.playerConns, LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
if self.enabled then
for _, plr in ipairs(Players:GetPlayers()) do refreshEspFor(plr) end
end
end))
self.loopConn = RunService.Heartbeat:Connect(function()
self._last = self._last or 0
if os.clock() - self._last < CONFIG.ESP.UpdateInterval then return end
self._last = os.clock()
espDistanceLoop()
end)
end

function ESP:stop()
if not self.enabled then return end
self.enabled = false
if self.loopConn then self.loopConn:Disconnect(); self.loopConn = nil end
for _, c in ipairs(self.playerConns) do c:Disconnect() end
self.playerConns = {}
for plr, bindings in pairs(self.playerBindings) do
for _, c in ipairs(bindings) do c:Disconnect() end
self.playerBindings[plr] = nil
end
for plr in pairs(self.entries) do clearEspEntry(plr) end
self.entries = {}
end
-- ============================================================
-- GIAO DIỆN GEMINI TAB UI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = CONFIG.GuiName
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = PlayerGui
NotifyContainer = Instance.new("Frame")
NotifyContainer.BackgroundTransparency = 1
NotifyContainer.Size = UDim2.new(1, 0, 0, 300)
NotifyContainer.Position = UDim2.new(0, 0, 0, 60)
NotifyContainer.Parent = screenGui

-- ============================================================
-- AIM ASSIST (PLAYER TARGETS, VISIBLE TARGETS ONLY)
-- Điều khiển camera cục bộ; không thay đổi vị trí/tốc độ người chơi khác.
-- ============================================================
local AIM_CONFIG = {
    FOV = 160, -- bán kính vòng tròn, đơn vị pixel
    Strength = 3, -- 1 nhẹ -> 5 ghim rất chắc
    IgnoreTeam = true,
    RetargetInterval = 0.07,
}

local AimAssist = {
    enabled = false,
    target = nil,
    aimPart = nil,
    connection = nil,
    nextRetarget = 0,
    status = "Tắt",
    circle = nil,
    circleStroke = nil,
    pulseTween = nil,
}

local AIM_RESPONSE = { 0.12, 0.25, 0.45, 0.72, 0.96 }

local function targetHasLineOfSight(camera, character, part)
    if not camera or not character or not part or not part.Parent then return false end
    local origin = camera.CFrame.Position
    local direction = part.Position - origin
    if direction.Magnitude <= 0.01 then return true end

    local excluded = {}
    if LocalPlayer.Character then table.insert(excluded, LocalPlayer.Character) end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = excluded
    params.IgnoreWater = true

    -- Bỏ qua tối đa vài lớp vật thể gần như trong suốt (ví dụ hiệu ứng kính),
    -- nhưng tường/vật cản bình thường vẫn chặn aim.
    for _ = 1, 5 do
        local hit = workspace:Raycast(origin, direction, params)
        if not hit then return true end
        if hit.Instance and hit.Instance:IsDescendantOf(character) then return true end
        if hit.Instance and hit.Instance:IsA("BasePart") and hit.Instance.Transparency >= 0.95 then
            table.insert(excluded, hit.Instance)
            params.FilterDescendantsInstances = excluded
        else
            return false
        end
    end
    return false
end

local function getVisibleAimPart(camera, character, viewportCenter)
    local candidates = {}
    for _, partName in ipairs({ "Head", "UpperTorso", "Torso", "HumanoidRootPart" }) do
        local candidate = character:FindFirstChild(partName)
        if candidate then table.insert(candidates, candidate) end
    end
    for _, part in ipairs(candidates) do
        if part and part:IsA("BasePart") then
            local screenPoint, onScreen = camera:WorldToViewportPoint(part.Position)
            if onScreen and screenPoint.Z > 0 then
                local offset = Vector2.new(screenPoint.X, screenPoint.Y) - viewportCenter
                if offset.Magnitude <= AIM_CONFIG.FOV and targetHasLineOfSight(camera, character, part) then
                    return part
                end
            end
        end
    end
    return nil
end

local function findBestAimTarget()
    local camera = workspace.CurrentCamera
    local myRoot = getHRP()
    if not camera or not myRoot then return nil, nil end

    local viewport = camera.ViewportSize
    local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local bestPlayer, bestPart, bestDistance = nil, nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local sameTeam = AIM_CONFIG.IgnoreTeam
                and LocalPlayer.Team ~= nil and player.Team ~= nil
                and player.Team == LocalPlayer.Team

            if character and humanoid and humanoid.Health > 0 and root and not sameTeam then
                local part = getVisibleAimPart(camera, character, center)
                if part then
                    local worldDistance = (root.Position - myRoot.Position).Magnitude
                    -- Ưu tiên người chơi gần nhất trong FOV, không chọn người xa chỉ vì gần tâm hơn.
                    if worldDistance < bestDistance then
                        bestDistance = worldDistance
                        bestPlayer = player
                        bestPart = part
                    end
                end
            end
        end
    end
    return bestPlayer, bestPart
end

local function updateAimCircle()
    if not AimAssist.circle then return end
    local diameter = math.floor(AIM_CONFIG.FOV * 2)
    AimAssist.circle.Size = UDim2.fromOffset(diameter, diameter)
    local camera = workspace.CurrentCamera
    if camera then
        local viewport = camera.ViewportSize
        AimAssist.circle.Position = UDim2.fromOffset(viewport.X * 0.5, viewport.Y * 0.5)
    end
end

local aimCircle = Instance.new("Frame")
aimCircle.Name = "AimFOVCircle"
aimCircle.AnchorPoint = Vector2.new(0.5, 0.5)
aimCircle.Position = UDim2.fromScale(0.5, 0.5)
aimCircle.Size = UDim2.fromOffset(AIM_CONFIG.FOV * 2, AIM_CONFIG.FOV * 2)
aimCircle.BackgroundTransparency = 1
aimCircle.BorderSizePixel = 0
aimCircle.Visible = false
aimCircle.ZIndex = 4
aimCircle.Parent = screenGui
Instance.new("UICorner", aimCircle).CornerRadius = UDim.new(1, 0)
local aimCircleStroke = Instance.new("UIStroke")
aimCircleStroke.Color = Color3.fromRGB(0, 205, 255)
aimCircleStroke.Thickness = 1.5
aimCircleStroke.Transparency = 0.12
aimCircleStroke.Parent = aimCircle
AimAssist.circle = aimCircle
AimAssist.circleStroke = aimCircleStroke

function AimAssist:setFOV(value)
    AIM_CONFIG.FOV = clamp(tonumber(value) or AIM_CONFIG.FOV, 40, 500)
    updateAimCircle()
end

function AimAssist:setStrength(value)
    AIM_CONFIG.Strength = math.floor(clamp(tonumber(value) or AIM_CONFIG.Strength, 1, 5) + 0.5)
end

function AimAssist:start()
    if self.enabled then return end
    self.enabled = true
    self.status = "Đang tìm mục tiêu trong FOV"
    self.target, self.aimPart = nil, nil
    self.nextRetarget = 0
    self.circle.Visible = true
    updateAimCircle()
    if self.circleStroke then
        self.pulseTween = TweenService:Create(
            self.circleStroke,
            TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Transparency = 0.42, Thickness = 2.1 }
        )
        self.pulseTween:Play()
    end

    self.connection = RunService.RenderStepped:Connect(function(dt)
        if not self.enabled then return end
        local camera = workspace.CurrentCamera
        if not camera then
            self.target, self.aimPart = nil, nil
            self.status = "Không tìm thấy camera"
            return
        end

        local now = os.clock()
        if now >= self.nextRetarget then
            self.target, self.aimPart = findBestAimTarget()
            self.nextRetarget = now + AIM_CONFIG.RetargetInterval
            if self.target then
                self.status = "Đang khóa: " .. self.target.DisplayName
            else
                self.status = "Không có mục tiêu nhìn thấy trong vòng FOV"
            end
        end

        local target = self.target
        local part = self.aimPart
        local character = target and target.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if target and part and part.Parent and humanoid and humanoid.Health > 0 then
            local desired = CFrame.lookAt(camera.CFrame.Position, part.Position)
            local strength = AIM_RESPONSE[AIM_CONFIG.Strength] or AIM_RESPONSE[3]
            local frameAlpha = 1 - ((1 - strength) ^ math.clamp(dt * 60, 0, 3))
            camera.CFrame = camera.CFrame:Lerp(desired, frameAlpha)
        else
            self.target, self.aimPart = nil, nil
        end
        updateAimCircle()
    end)
    return true
end

function AimAssist:stop()
    self.enabled = false
    self.target, self.aimPart = nil, nil
    self.status = "Tắt"
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
    if self.pulseTween then
        self.pulseTween:Cancel()
        self.pulseTween = nil
    end
    if self.circleStroke then
        self.circleStroke.Transparency = 0.12
        self.circleStroke.Thickness = 1.5
    end
    if self.circle then self.circle.Visible = false end
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
local mainCamera = workspace.CurrentCamera
local mainViewport = mainCamera and mainCamera.ViewportSize or Vector2.new(800, 600)
local mainWidth = math.min(490, math.max(280, mainViewport.X - 20))
local mainHeight = math.min(390, math.max(280, mainViewport.Y - 20))
MainFrame.Size = UDim2.fromOffset(mainWidth, mainHeight)
MainFrame.Position = UDim2.new(0.5, -mainWidth / 2, 0.5, -mainHeight / 2)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = screenGui
local MainScale = Instance.new("UIScale")
MainScale.Scale = 1
MainScale.Parent = MainFrame
MainFrame.Visible = false
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(38, 44, 60); MainStroke.Thickness = 1.2; MainStroke.Parent = MainFrame
-- Top Bar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 10)
local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(0.65, 0, 1, 0); TitleLbl.Position = UDim2.new(0, 14, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Font = Enum.Font.GothamBold; TitleLbl.TextSize = 14
TitleLbl.TextColor3 = Color3.fromRGB(0, 200, 255)
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Text = "♊ HUB GEMINI <font color='#8090a8' size='11'>| v6.5.1</font>"
TitleLbl.RichText = true; TitleLbl.Parent = TopBar
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28); CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BackgroundColor3 = Color3.fromRGB(210, 50, 60); CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "✕"; CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 12
CloseBtn.Parent = TopBar; Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28); MinBtn.Position = UDim2.new(1, -68, 0.5, -14)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60); MinBtn.BorderSizePixel = 0
MinBtn.Text = "–"; MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.Font = Enum.Font.GothamBold; MinBtn.TextSize = 14
MinBtn.Parent = TopBar; Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)
-- Kéo thả: giới hạn trong màn hình và dọn kết nối toàn cục khi GUI bị đóng.
local uiConnections = {}
local function trackUIConnection(conn)
table.insert(uiConnections, conn)
return conn
end

local function setupDraggable(trigger, target)
local dragging, dragStart, startPos = false, nil, nil
trigger.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
dragging = true
 dragStart = input.Position
 startPos = target.AbsolutePosition
end
end)
trackUIConnection(UserInputService.InputChanged:Connect(function(input)
if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
local delta = input.Position - dragStart
local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
local maxX = math.max(0, viewport.X - target.AbsoluteSize.X)
local maxY = math.max(0, viewport.Y - target.AbsoluteSize.Y)
target.Position = UDim2.fromOffset(
clamp(startPos.X + delta.X, 0, maxX),
clamp(startPos.Y + delta.Y, 0, maxY)
)
end
end))
trackUIConnection(UserInputService.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
dragging = false
end
end))
end
setupDraggable(TopBar, MainFrame)
local FloatBtn = Instance.new("TextButton")
FloatBtn.Size = UDim2.new(0, 48, 0, 48); FloatBtn.Position = UDim2.new(0, 16, 0.5, -24)
FloatBtn.BackgroundColor3 = Color3.fromRGB(22, 26, 36); FloatBtn.BorderSizePixel = 0
FloatBtn.Text = "♊"; FloatBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
FloatBtn.Font = Enum.Font.GothamBold; FloatBtn.TextSize = 22
FloatBtn.Visible = false; FloatBtn.Parent = screenGui
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 12)
local FloatStroke = Instance.new("UIStroke"); FloatStroke.Color = Color3.fromRGB(0, 180, 255); FloatStroke.Parent = FloatBtn
setupDraggable(FloatBtn, FloatBtn)
local mainTransitionId = 0
local mainStateOpen = false
local function animateMain(open)
    if not Authenticated then return end
    mainTransitionId += 1
    local transitionId = mainTransitionId
    mainStateOpen = open
    if open then
        FloatBtn.Visible = false
        MainFrame.Visible = true
        MainScale.Scale = 0.94
        TweenService:Create(MainScale, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    else
        MainScale.Scale = 1
        TweenService:Create(MainScale, TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Scale = 0.94 }):Play()
        task.delay(0.17, function()
            if transitionId ~= mainTransitionId then return end
            MainFrame.Visible = false
            MainScale.Scale = 1
            FloatBtn.Visible = true
        end)
    end
end
CloseBtn.MouseButton1Click:Connect(function() animateMain(false) end)
MinBtn.MouseButton1Click:Connect(function() animateMain(false) end)
FloatBtn.MouseButton1Click:Connect(function() animateMain(true) end)
-- Sidebar Tabs
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 126, 1, -42); Sidebar.Position = UDim2.new(0, 0, 0, 42)
Sidebar.BackgroundColor3 = Color3.fromRGB(20, 23, 33); Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame
local TabList = Instance.new("UIListLayout"); TabList.Padding = UDim.new(0, 4); TabList.Parent = Sidebar
local TabPadding = Instance.new("UIPadding")
TabPadding.PaddingTop = UDim.new(0, 8); TabPadding.PaddingLeft = UDim.new(0, 6); TabPadding.PaddingRight = UDim.new(0, 6)
TabPadding.Parent = Sidebar
local PageContainer = Instance.new("Frame")
PageContainer.Size = UDim2.new(1, -134, 1, -50); PageContainer.Position = UDim2.new(0, 130, 0, 46)
PageContainer.BackgroundTransparency = 1; PageContainer.Parent = MainFrame
local Pages = {}
local PageGroups = {}
local TabButtons = {}
local PageTweens = {}
local activePageName = nil
local function switchPage(name)
    if not Pages[name] or activePageName == name then return end
    activePageName = name
    for pageName, page in pairs(Pages) do
        local active = pageName == name
        local group = PageGroups[pageName]
        local button = TabButtons[pageName]
        button.BackgroundColor3 = active and Color3.fromRGB(0, 140, 220) or Color3.fromRGB(26, 30, 42)
        button.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 160, 180)
        if PageTweens[pageName] then
            PageTweens[pageName]:Cancel()
            PageTweens[pageName] = nil
        end
        if active then
            group.Visible = true
            group.Position = UDim2.fromOffset(10, 0)
            group.GroupTransparency = 1
            PageTweens[pageName] = TweenService:Create(group, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Position = UDim2.fromOffset(0, 0), GroupTransparency = 0
            })
            PageTweens[pageName]:Play()
        else
            group.Visible = false
            group.GroupTransparency = 0
            group.Position = UDim2.fromOffset(0, 0)
        end
    end
end

local function createPage(name, icon)
local group = Instance.new("CanvasGroup")
group.Name = name .. "TransitionGroup"
group.Size = UDim2.new(1, 0, 1, 0)
group.Position = UDim2.fromOffset(0, 0)
group.BackgroundTransparency = 1
group.GroupTransparency = 0
group.Visible = false
group.Parent = PageContainer

local page = Instance.new("ScrollingFrame")
page.Name = name .. "Page"
page.Size = UDim2.new(1, 0, 1, 0); page.BackgroundTransparency = 1
page.ScrollBarThickness = 3; page.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 255)
page.CanvasSize = UDim2.new(0, 0, 0, 0); page.Visible = true
page.Parent = group
local pageLayout = Instance.new("UIListLayout")
pageLayout.Padding = UDim.new(0, 8); pageLayout.Parent = page
pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
page.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 12)
end)
local tabBtn = Instance.new("TextButton")
tabBtn.Size = UDim2.new(1, 0, 0, 34); tabBtn.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
tabBtn.BorderSizePixel = 0; tabBtn.Font = Enum.Font.GothamMedium; tabBtn.TextSize = 12
tabBtn.TextColor3 = Color3.fromRGB(150, 160, 180); tabBtn.Text = icon .. " " .. name
tabBtn.Parent = Sidebar; Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 6)
tabBtn.MouseEnter:Connect(function()
    if activePageName ~= name then
        TweenService:Create(tabBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(38, 48, 66) }):Play()
    end
end)
tabBtn.MouseLeave:Connect(function()
    if activePageName ~= name then
        TweenService:Create(tabBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(26, 30, 42) }):Play()
    end
end)
Pages[name] = page
PageGroups[name] = group
TabButtons[name] = tabBtn
tabBtn.MouseButton1Click:Connect(function() switchPage(name) end)
return page
end
-- ============================================================
-- UI COMPONENTS
-- ============================================================
local function addToggle(parent, labelText, defaultVal, onToggle)
local card = Instance.new("Frame")
card.Size = UDim2.new(1, -6, 0, 36); card.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
card.BorderSizePixel = 0; card.Parent = parent
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1, -60, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12
lbl.TextColor3 = Color3.fromRGB(220, 225, 235); lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.Text = labelText; lbl.Parent = card
local sw = Instance.new("TextButton")
sw.Size = UDim2.new(0, 42, 0, 20); sw.Position = UDim2.new(1, -50, 0.5, -10)
sw.BackgroundColor3 = defaultVal and Color3.fromRGB(0, 190, 220) or Color3.fromRGB(45, 50, 65)
sw.BorderSizePixel = 0; sw.Text = ""; sw.Parent = card
Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)
local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 16, 0, 16)
dot.Position = defaultVal and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255); dot.BorderSizePixel = 0
dot.Parent = sw; Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
local state = defaultVal
local function set(v, fire)
state = v
sw.BackgroundColor3 = v and Color3.fromRGB(0, 190, 220) or Color3.fromRGB(45, 50, 65)
local targetPos = v and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
TweenService:Create(dot, TweenInfo.new(0.14), { Position = targetPos }):Play()
if fire then onToggle(v) end
end
sw.MouseButton1Click:Connect(function() set(not state, true) end)
return { set = function(v) set(v, false) end }
end
local function addSlider(parent, labelText, min, max, defaultVal, onChange, isFloat)
local card = Instance.new("Frame")
card.Size = UDim2.new(1, -6, 0, 46); card.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
card.BorderSizePixel = 0; card.Parent = parent
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(0.65, 0, 0, 18); lbl.Position = UDim2.new(0, 10, 0, 4)
lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12
lbl.TextColor3 = Color3.fromRGB(200, 205, 215); lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.Text = labelText; lbl.Parent = card
local input = Instance.new("TextBox")
input.Size = UDim2.new(0, 52, 0, 18); input.Position = UDim2.new(1, -60, 0, 4)
input.BackgroundColor3 = Color3.fromRGB(34, 38, 52); input.BorderSizePixel = 0
input.Font = Enum.Font.GothamBold; input.TextSize = 11; input.TextColor3 = Color3.fromRGB(0, 200, 255)
input.Text = isFloat and string.format("%.2f", defaultVal) or tostring(math.floor(defaultVal))
input.Parent = card; Instance.new("UICorner", input).CornerRadius = UDim.new(0, 4)
local track = Instance.new("TextButton")
track.Text = ""; track.AutoButtonColor = false
track.Size = UDim2.new(1, -20, 0, 6); track.Position = UDim2.new(0, 10, 0, 28)
track.BackgroundColor3 = Color3.fromRGB(40, 45, 60); track.BorderSizePixel = 0
track.Parent = card; Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
local fill = Instance.new("Frame")
local ratio = (defaultVal - min) / (max - min)
fill.Size = UDim2.new(ratio, 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
fill.BorderSizePixel = 0; fill.Parent = track
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
local val = defaultVal
local function set(v, fire)
v = clamp(tonumber(v) or val, min, max)
if not isFloat then v = math.floor(v + 0.5) end
val = v
local r = (v - min) / (max - min)
fill.Size = UDim2.new(r, 0, 1, 0)
input.Text = isFloat and string.format("%.2f", v) or tostring(math.floor(v))
if fire then onChange(v) end
end
local dragging = false
local function updateFromPos(x)
if track.AbsoluteSize.X <= 0 then return end
local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
set(min + rel * (max - min), true)
end
track.InputBegan:Connect(function(i)
if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
dragging = true; updateFromPos(i.Position.X)
end
end)
trackUIConnection(UserInputService.InputChanged:Connect(function(i)
if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
updateFromPos(i.Position.X)
end
end))
trackUIConnection(UserInputService.InputEnded:Connect(function(i)
if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
dragging = false
end
end))
input.FocusLost:Connect(function() set(tonumber(input.Text), true) end)
end
local function addDropdown(parent, labelText, multi, getItems, onSelect)
local card = Instance.new("Frame")
card.Size = UDim2.new(1, -6, 0, 36); card.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
card.BorderSizePixel = 0; card.Parent = parent
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(0.48, 0, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12
lbl.TextColor3 = Color3.fromRGB(200, 205, 215); lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.Text = labelText; lbl.Parent = card
local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0.5, 0, 0, 24); btn.Position = UDim2.new(0.5, -4, 0.5, -12)
btn.BackgroundColor3 = Color3.fromRGB(35, 40, 55); btn.BorderSizePixel = 0
btn.Font = Enum.Font.GothamMedium; btn.TextSize = 11; btn.TextColor3 = Color3.fromRGB(0, 200, 255)
btn.Text = "Chọn..."; btn.Parent = card
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
local selected, singleVal = {}, nil
local modalOverlay = nil
local function closePanel()
if modalOverlay then modalOverlay:Destroy(); modalOverlay = nil end
end
local function updateLabel()
if multi then
local count = 0
local first = nil
for k in pairs(selected) do count += 1; if not first then first = k end end
if count == 0 then btn.Text = "Chọn..."
elseif count == 1 then btn.Text = first
else btn.Text = count .. " mục đã chọn" end
else
btn.Text = singleVal or "Chọn..."
end
end
local function openPanel()
closePanel()
local overlay = Instance.new("TextButton")
overlay.Name = "DropdownOverlay"
overlay.Text = ""; overlay.AutoButtonColor = false
overlay.BackgroundTransparency = 1
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.ZIndex = 80
overlay.Parent = screenGui
modalOverlay = overlay
overlay.MouseButton1Click:Connect(closePanel)
local pos = btn.AbsolutePosition
local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
local panelWidth, panelHeight = 210, 190
local panelX = clamp(pos.X - 20, 10, math.max(10, viewport.X - panelWidth - 10))
local panelY = pos.Y + 28
if panelY + panelHeight > viewport.Y - 10 then panelY = math.max(10, pos.Y - panelHeight - 8) end
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, panelWidth, 0, panelHeight)
panel.Position = UDim2.fromOffset(panelX, panelY)
panel.BackgroundColor3 = Color3.fromRGB(22, 25, 36); panel.BorderSizePixel = 0
panel.ZIndex = 81; panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 180, 255); stroke.Parent = panel
local search = Instance.new("TextBox")
search.Size = UDim2.new(1, -12, 0, 24); search.Position = UDim2.new(0, 6, 0, 6)
search.BackgroundColor3 = Color3.fromRGB(30, 34, 48); search.BorderSizePixel = 0
search.Font = Enum.Font.Gotham; search.TextSize = 11; search.TextColor3 = Color3.fromRGB(255, 255, 255)
search.PlaceholderText = "Tìm kiếm..."; search.ClearTextOnFocus = false
search.ZIndex = 82; search.Parent = panel
Instance.new("UICorner", search).CornerRadius = UDim.new(0, 4)
local sc = Instance.new("ScrollingFrame")
sc.Size = UDim2.new(1, -12, 1, -38); sc.Position = UDim2.new(0, 6, 0, 34)
sc.BackgroundTransparency = 1; sc.ScrollBarThickness = 3
sc.ZIndex = 82; sc.Parent = panel
local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0, 3); list.Parent = sc
local function refresh()
for _, c in ipairs(sc:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
local q = search.Text:lower()
for _, item in ipairs(getItems()) do
if q == "" or item:lower():find(q, 1, true) then
local b = Instance.new("TextButton")
b.Size = UDim2.new(1, 0, 0, 24)
b.BackgroundColor3 = (multi and selected[item] or singleVal == item)
and Color3.fromRGB(0, 140, 220) or Color3.fromRGB(32, 36, 50)
b.BorderSizePixel = 0; b.Font = Enum.Font.Gotham; b.TextSize = 11
b.TextColor3 = Color3.fromRGB(240, 240, 240); b.TextXAlignment = Enum.TextXAlignment.Left
b.Text = " " .. item; b.ZIndex = 83; b.Parent = sc
Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
b.MouseButton1Click:Connect(function()
if multi then
selected[item] = not selected[item] or nil
else
singleVal = item
selected = { [item] = true }
closePanel()
end
updateLabel()
onSelect(selected, singleVal)
refresh()
end)
end
end
sc.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y)
end
search:GetPropertyChangedSignal("Text"):Connect(refresh)
refresh()
end
btn.MouseButton1Click:Connect(function()
if modalOverlay then closePanel() else openPanel() end
end)
return {
setLabel = function(txt) singleVal = txt; updateLabel() end
}
end
-- ============================================================
-- KHỞI TẠO CÁC TRANG (PAGES)
-- ============================================================
-- TAB 1: DI CHUYỂN
local pageMove = createPage("Di chuyển", "⚡")
speedToggleRef = addToggle(pageMove, "Speed Walk", false, function(v)
if v and (AutoFarm.enabled or AutoLoot.enabled) then
notify("Hãy tắt Auto Farm/Auto Loot trước khi bật Speed Walk", true)
speedToggleRef.set(false)
return
end
if v then SpeedWalk:start() else SpeedWalk:stop() end
end)
addSlider(pageMove, "WalkSpeed", CONFIG.WalkSpeed.Min, CONFIG.WalkSpeed.Max, CONFIG.WalkSpeed.Default, function(v)
SpeedWalk:set(v)
end)
jumpToggleRef = addToggle(pageMove, "High Jump", false, function(v)
if v and (AutoFarm.enabled or AutoLoot.enabled) then
notify("Hãy tắt Auto Farm/Auto Loot trước khi bật High Jump", true)
jumpToggleRef.set(false)
return
end
if v then HighJump:start() else HighJump:stop() end
end)
addSlider(pageMove, "Jump Power / Height", CONFIG.Jump.Min, CONFIG.Jump.Max, CONFIG.Jump.Default, function(v)
HighJump:set(v)
end)
addToggle(pageMove, "Noclip (Xuyên tường)", false, function(v)
if v then NoclipManager:acquire() else NoclipManager:release() end
end)
-- TAB 2: TỰ ĐỘNG (AUTO FARM & AUTO LOOT)
local pageAuto = createPage("Tự động", "🤖")
local farmStatusLbl = Instance.new("TextLabel")
farmStatusLbl.Size = UDim2.new(1, -6, 0, 18); farmStatusLbl.BackgroundTransparency = 1
farmStatusLbl.Font = Enum.Font.GothamMedium; farmStatusLbl.TextSize = 11
farmStatusLbl.TextColor3 = Color3.fromRGB(0, 200, 255); farmStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
farmStatusLbl.Text = "Trạng thái Farm: Tắt"; farmStatusLbl.Parent = pageAuto
local lootToggleRef
local farmToggleRef = addToggle(pageAuto, "Auto Farm", false, function(on)
if on then
if AutoLoot.enabled then AutoLoot:stop(); if lootToggleRef then lootToggleRef.set(false) end end
if SpeedWalk.enabled then SpeedWalk:stop(); if speedToggleRef then speedToggleRef.set(false) end end
if HighJump.enabled then HighJump:stop(); if jumpToggleRef then jumpToggleRef.set(false) end end
AutoFarm:start()
else
AutoFarm:stop()
end
end)
local modeDropdown = addDropdown(pageAuto, "Chế độ di chuyển", false, function()
return { "Align (mượt, an toàn)", "Anchored (cũ, dễ bị chặn)", "Ground (đứng cạnh)" }
end, function(_, single)
if single == "Align (mượt, an toàn)" then CONFIG.MoveMode = "Align"
elseif single == "Anchored (cũ, dễ bị chặn)" then CONFIG.MoveMode = "Anchored"
elseif single == "Ground (đứng cạnh)" then CONFIG.MoveMode = "Ground" end
if AutoFarm.enabled then AutoFarm:restartMover() end
notify("Mode: " .. CONFIG.MoveMode)
end)
modeDropdown.setLabel("Align (mượt, an toàn)")
addDropdown(pageAuto, "Chọn loại quái", false, function()
local t = getEnemyTypes()
table.insert(t, 1, "Tất cả")
return t
end, function(_, single)
if single == "Tất cả" or single == nil then
AutoFarm.selectedType = nil
else
AutoFarm.selectedType = single
end
notify("Đã chọn quái: " .. (single or "Tất cả"))
end)
addSlider(pageAuto, "Độ cao farm (studs)", CONFIG.FarmHeight.Min, CONFIG.FarmHeight.Max, CONFIG.FarmHeight.Default, function(v)
AutoFarm:setHeight(v)
end)
addSlider(pageAuto, "KC Ground (studs)", CONFIG.FarmDistance.Min, CONFIG.FarmDistance.Max, CONFIG.FarmDistance.Default, function(v)
AutoFarm:setDistance(v)
end)
addSlider(pageAuto, "Tầm đánh tối đa (studs)", CONFIG.AttackDistance.Min, CONFIG.AttackDistance.Max, CONFIG.AttackDistance.Default, function(v)
AttackState.maxDistance = v
end)
addSlider(pageAuto, "Thời gian ổn định (s)", CONFIG.AttackSettle.Min, CONFIG.AttackSettle.Max, CONFIG.AttackSettle.Default, function(v)
AttackState.settleTime = v
end, true)
local lootStatusLbl = Instance.new("TextLabel")
lootStatusLbl.Size = UDim2.new(1, -6, 0, 18); lootStatusLbl.BackgroundTransparency = 1
lootStatusLbl.Font = Enum.Font.GothamMedium; lootStatusLbl.TextSize = 11
lootStatusLbl.TextColor3 = Color3.fromRGB(0, 200, 255); lootStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
lootStatusLbl.Text = "Trạng thái Loot: Tắt"; lootStatusLbl.Parent = pageAuto
lootToggleRef = addToggle(pageAuto, "Auto Loot", false, function(on)
if on then
if AutoFarm.enabled then AutoFarm:stop(); farmToggleRef.set(false) end
if SpeedWalk.enabled then SpeedWalk:stop(); if speedToggleRef then speedToggleRef.set(false) end end
if HighJump.enabled then HighJump:stop(); if jumpToggleRef then jumpToggleRef.set(false) end end
AutoLoot:start()
else
AutoLoot:stop()
end
end)
-- TAB 3: AIM
local pageAim = createPage("Aim", "🎯")
local aimToggleRef
local aimControls
local aimStatusLbl = Instance.new("TextLabel")
aimStatusLbl.Size = UDim2.new(1, -6, 0, 32)
aimStatusLbl.BackgroundTransparency = 1
aimStatusLbl.Font = Enum.Font.GothamMedium
aimStatusLbl.TextSize = 11
aimStatusLbl.TextWrapped = true
aimStatusLbl.TextColor3 = Color3.fromRGB(0, 200, 255)
aimStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
aimStatusLbl.Text = "Aim: Tắt"
aimStatusLbl.Parent = pageAim

aimToggleRef = addToggle(pageAim, "Bật Aim Assist", false, function(on)
    if on then
        if AimAssist:start() then
            aimControls.Visible = true
        else
            aimToggleRef.set(false)
            aimControls.Visible = false
        end
    else
        AimAssist:stop()
        aimControls.Visible = false
    end
end)

aimControls = Instance.new("Frame")
aimControls.Name = "AimAdvancedSettings"
aimControls.Size = UDim2.new(1, -6, 0, 0)
aimControls.AutomaticSize = Enum.AutomaticSize.Y
aimControls.BackgroundTransparency = 1
aimControls.Visible = false
aimControls.Parent = pageAim
local aimControlsLayout = Instance.new("UIListLayout")
aimControlsLayout.Padding = UDim.new(0, 7)
aimControlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
aimControlsLayout.Parent = aimControls

addSlider(aimControls, "Bán kính vòng FOV (px)", 40, 500, AIM_CONFIG.FOV, function(v)
    AimAssist:setFOV(v)
end)
addSlider(aimControls, "Lực ghim (1 nhẹ - 5 rất mạnh)", 1, 5, AIM_CONFIG.Strength, function(v)
    AimAssist:setStrength(v)
    local descriptions = { "Nhẹ", "Vừa nhẹ", "Cân bằng", "Mạnh", "Rất mạnh" }
    notify("Lực ghim: " .. descriptions[AIM_CONFIG.Strength])
end)
addToggle(aimControls, "Bỏ qua đồng đội", AIM_CONFIG.IgnoreTeam, function(on)
    AIM_CONFIG.IgnoreTeam = on
end)
local aimInfo = Instance.new("TextLabel")
aimInfo.Size = UDim2.new(1, -6, 0, 58)
aimInfo.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
aimInfo.BackgroundTransparency = 0.1
aimInfo.BorderSizePixel = 0
aimInfo.Font = Enum.Font.Gotham
aimInfo.TextSize = 10
aimInfo.TextWrapped = true
aimInfo.TextYAlignment = Enum.TextYAlignment.Center
aimInfo.TextColor3 = Color3.fromRGB(160, 175, 195)
aimInfo.Text = "Chỉ chọn người chơi đang hiện trong vòng FOV và có đường nhìn rõ. Ưu tiên mục tiêu gần nhất; tường/vật cản sẽ chặn khóa. Mức 5 ghim camera rất chắc nhưng không khóa chuyển động nhân vật."
aimInfo.Parent = aimControls
Instance.new("UICorner", aimInfo).CornerRadius = UDim.new(0, 6)

-- TAB 4: HIỂN THỊ
local pageVisual = createPage("Hiển thị", "👁️")
local fullBrightToggleRef
local fixLagToggleRef
fixLagToggleRef = addToggle(pageVisual, "Fix Lag (Cực mạnh)", false, function(on)
if on then
if FullBright.enabled then FullBright:stop(); if fullBrightToggleRef then fullBrightToggleRef.set(false) end end
FixLag:start()
else
FixLag:stop()
end
end)
fullBrightToggleRef = addToggle(pageVisual, "Full Bright", false, function(on)
if on then
if FixLag.enabled then FixLag:stop(); if fixLagToggleRef then fixLagToggleRef.set(false) end end
FullBright:start()
else
FullBright:stop()
end
end)
addToggle(pageVisual, "Player ESP", false, function(on)
if on then ESP:start() else ESP:stop() end
end)
addToggle(pageVisual, "ESP - Chỉ khác đội", CONFIG.ESP.SameTeamOnly, function(on)
CONFIG.ESP.SameTeamOnly = on
if ESP.enabled then ESP:stop(); ESP:start() end
end)
-- TAB 5: CÀI ĐẶT
local pageSettings = createPage("Cài đặt", "⚙️")
addToggle(pageSettings, "Debug đánh (F9 Console)", false, function(on)
AttackState.debug = on
notify("Debug đánh: " .. (on and "BẬT" or "TẮT"))
end)
local infoCard = Instance.new("Frame")
infoCard.Size = UDim2.new(1, -6, 0, 142); infoCard.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
infoCard.BorderSizePixel = 0; infoCard.Parent = pageSettings
Instance.new("UICorner", infoCard).CornerRadius = UDim.new(0, 6)
local infoText = Instance.new("TextLabel")
infoText.Size = UDim2.new(1, -16, 1, -10); infoText.Position = UDim2.new(0, 8, 0, 5)
infoText.BackgroundTransparency = 1; infoText.Font = Enum.Font.Gotham; infoText.TextSize = 11
infoText.TextColor3 = Color3.fromRGB(160, 170, 190); infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.TextYAlignment = Enum.TextYAlignment.Top
infoText.Text = "• PHIÊN BẢN HIỆN TẠI: v6.5.1\n• Nhấn [Right Shift] để ẩn/hiện menu.\n• Mobile: Bấm nút tròn ♊ để mở lại.\n• Aim: FOV + kiểm tra tầm nhìn + ưu tiên người gần nhất.\n• Chọn 'Tất cả' để farm mọi loại quái.\n• Trạng thái đánh chỉ xác nhận thao tác đã gửi."
infoText.Parent = infoCard
-- Mở mặc định Tab Tự động bằng chuyển cảnh mượt
switchPage("Tự động")
-- ============================================================
-- ĐĂNG NHẬP PREMIUM (KEY TẠM THỜI)
-- Lưu ý: key nhúng trong LocalScript chỉ khóa giao diện; không phải xác thực an toàn.
-- ============================================================
local ACCESS_KEY = "adminadmin123123"
local loginAttempts = 0

local LoginFrame = Instance.new("Frame")
LoginFrame.Name = "LoginFrame"
LoginFrame.AnchorPoint = Vector2.new(0.5, 0.5)
local loginCamera = workspace.CurrentCamera
local loginViewport = loginCamera and loginCamera.ViewportSize or Vector2.new(800, 600)
local loginWidth = math.min(360, math.max(280, loginViewport.X - 24))
LoginFrame.Size = UDim2.new(0, loginWidth, 0, 238)
LoginFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
LoginFrame.BackgroundColor3 = Color3.fromRGB(20, 23, 34)
LoginFrame.BorderSizePixel = 0
LoginFrame.ZIndex = 100
LoginFrame.Parent = screenGui
local LoginScale = Instance.new("UIScale")
LoginScale.Scale = 0.92
LoginScale.Parent = LoginFrame
TweenService:Create(LoginScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
Instance.new("UICorner", LoginFrame).CornerRadius = UDim.new(0, 14)
local LoginStroke = Instance.new("UIStroke")
LoginStroke.Color = Color3.fromRGB(0, 175, 230)
LoginStroke.Thickness = 1.4
LoginStroke.Parent = LoginFrame

local LoginTitle = Instance.new("TextLabel")
LoginTitle.BackgroundTransparency = 1
LoginTitle.Position = UDim2.new(0, 18, 0, 20)
LoginTitle.Size = UDim2.new(1, -36, 0, 30)
LoginTitle.Font = Enum.Font.GothamBold
LoginTitle.Text = "CHEEMS HUB  •  PREMIUM"
LoginTitle.TextColor3 = Color3.fromRGB(0, 205, 255)
LoginTitle.TextSize = 17
LoginTitle.ZIndex = 101
LoginTitle.Parent = LoginFrame

local LoginSubtitle = Instance.new("TextLabel")
LoginSubtitle.BackgroundTransparency = 1
LoginSubtitle.Position = UDim2.new(0, 18, 0, 55)
LoginSubtitle.Size = UDim2.new(1, -36, 0, 22)
LoginSubtitle.Font = Enum.Font.Gotham
LoginSubtitle.Text = "Nhập key để mở khóa bảng điều khiển"
LoginSubtitle.TextColor3 = Color3.fromRGB(165, 175, 195)
LoginSubtitle.TextSize = 11
LoginSubtitle.ZIndex = 101
LoginSubtitle.Parent = LoginFrame

local KeyBox = Instance.new("TextBox")
KeyBox.Name = "AccessKey"
KeyBox.Size = UDim2.new(1, -36, 0, 42)
KeyBox.Position = UDim2.new(0, 18, 0, 94)
KeyBox.BackgroundColor3 = Color3.fromRGB(31, 36, 50)
KeyBox.BorderSizePixel = 0
KeyBox.ClearTextOnFocus = false
KeyBox.PlaceholderText = "Nhập key..."
KeyBox.Text = ""
KeyBox.Font = Enum.Font.Gotham
KeyBox.TextSize = 13
KeyBox.TextColor3 = Color3.fromRGB(245, 248, 255)
KeyBox.PlaceholderColor3 = Color3.fromRGB(110, 120, 140)
KeyBox.ZIndex = 101
KeyBox.Parent = LoginFrame
Instance.new("UICorner", KeyBox).CornerRadius = UDim.new(0, 7)

local LoginButton = Instance.new("TextButton")
LoginButton.Size = UDim2.new(1, -36, 0, 40)
LoginButton.Position = UDim2.new(0, 18, 0, 148)
LoginButton.BackgroundColor3 = Color3.fromRGB(0, 145, 205)
LoginButton.BorderSizePixel = 0
LoginButton.AutoButtonColor = true
LoginButton.Text = "ĐĂNG NHẬP"
LoginButton.Font = Enum.Font.GothamBold
LoginButton.TextSize = 12
LoginButton.TextColor3 = Color3.new(1, 1, 1)
LoginButton.ZIndex = 101
LoginButton.Parent = LoginFrame
Instance.new("UICorner", LoginButton).CornerRadius = UDim.new(0, 7)

local LoginStatus = Instance.new("TextLabel")
LoginStatus.BackgroundTransparency = 1
LoginStatus.Position = UDim2.new(0, 18, 0, 198)
LoginStatus.Size = UDim2.new(1, -36, 0, 22)
LoginStatus.Font = Enum.Font.Gotham
LoginStatus.Text = "Chỉ người có key mới mở được giao diện"
LoginStatus.TextColor3 = Color3.fromRGB(125, 140, 160)
LoginStatus.TextSize = 10
LoginStatus.ZIndex = 101
LoginStatus.Parent = LoginFrame

local function attemptLogin()
if Authenticated then return end
if KeyBox.Text == ACCESS_KEY then
Authenticated = true
KeyBox.Text = ""
LoginStatus.Text = "Đăng nhập thành công"
LoginStatus.TextColor3 = Color3.fromRGB(80, 220, 150)
TitleLbl.Text = "♊ HUB GEMINI <font color='#f2c14e' size='11'>| PREMIUM</font> <font color='#8090a8' size='10'>v6.5.1</font>"
LoginFrame:Destroy()
animateMain(true)
notify("Đăng nhập Premium thành công", false)
else
loginAttempts += 1
KeyBox.Text = ""
LoginStatus.Text = string.format("Key không đúng (%d)", loginAttempts)
LoginStatus.TextColor3 = Color3.fromRGB(255, 100, 110)
end
end

LoginButton.MouseButton1Click:Connect(attemptLogin)
KeyBox.FocusLost:Connect(function(enterPressed)
if enterPressed then attemptLogin() end
end)

-- Cập nhật chu kỳ trạng thái
task.spawn(function()
while screenGui.Parent do
farmStatusLbl.Text = "Trạng thái Farm: " .. (AutoFarm.enabled and AutoFarm.status or "Tắt")
lootStatusLbl.Text = "Trạng thái Loot: " .. (AutoLoot.enabled and AutoLoot.status or "Tắt")
aimStatusLbl.Text = "Aim: " .. (AimAssist.enabled and AimAssist.status or "Tắt")
task.wait(0.25)
end
end)
-- Phím tắt PC
trackUIConnection(UserInputService.InputBegan:Connect(function(input, gp)
if gp or not Authenticated then return end
if input.KeyCode == CONFIG.ToggleKey then
animateMain(not mainStateOpen)
end
end))
-- Dọn dẹp an toàn khi GUI bị xoá
screenGui.Destroying:Connect(function()
SpeedWalk:stop(); HighJump:stop()
AutoFarm:stop(); AutoLoot:stop()
ESP:stop(); FixLag:stop(); FullBright:stop()
AimAssist:stop()
NoclipManager:forceStop()
for _, c in ipairs(uiConnections) do
pcall(function() c:Disconnect() end)
end
uiConnections = {}
end)
notify("Cheems Hub sẵn sàng — yêu cầu đăng nhập")

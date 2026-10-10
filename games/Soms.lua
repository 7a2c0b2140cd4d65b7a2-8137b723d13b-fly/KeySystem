-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer

-- Load WindUI
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kyoukara/WindUI/main/dist/main.lua"))()

-- Type Definitions
type ToggleState = {
    Speed: boolean,
    InfJump: boolean,
    Noclip: boolean,
    EnemyESP: boolean,
    ItemESP: boolean,
    ObjectESP: boolean,
    InstantInteract: boolean,
    PlayerESPName: boolean,
    PlayerESPHighlight: boolean,
}

type WaypointStore = {
    Home: CFrame?,
    Loot: CFrame?,
}

-- State Variables
local toggles: ToggleState = {
    Speed = false,
    InfJump = false,
    Noclip = false,
    EnemyESP = false,
    ItemESP = false,
    ObjectESP = false,
    InstantInteract = false,
    PlayerESPName = false,
    PlayerESPHighlight = false,
}

local waypoints: WaypointStore = {
    Home = nil,
    Loot = nil,
}

local selectedItemName = nil
local cachedItemList = {}
local itemDropdownRef = nil
local itemsFolderConn = {}
local currentItemsFolder = nil
local refreshDebounce = false
local originalPromptData = {}
local promptConnections = {}
local speedChangedConn = nil

-- Object ESP State
local selectedObjectName = nil
local cachedObjectList = {}
local objectDropdownRef = nil
local objectsFolderConn = {}
local objectRefreshDebounce = false

-- Player ESP State
local playerESPConnections = {}

-- Window
local Window = WindUI:CreateWindow({
    Title = "Flycer Hub",
    Icon = "rbxassetid://89557898457977",
    IconSize = 30,
    Author = "Survive Overnight in a Mega Store",
    Folder = "FlycerWorkspace",
    Size = UDim2.fromOffset(560, 460),
    Transparent = true,
    NewElements = true,
    Theme = "Midnight",
    SideBarWidth =160,
})

Window:EditOpenButton({
    Title = "Open Menu",
    Icon = "rbxassetid://89557898457977",
    CornerRadius = UDim.new(1, 0),
    StrokeThickness = 1.5,
    Scale = 0.8,
})


-- Tabs
local Tabs = {
    Menu = Window:Tab({ Title = "Dashboard", Icon = "layout-dashboard" }),
    Movement = Window:Tab({ Title = "Movement", Icon = "footprints" }),
    Visuals = Window:Tab({ Title = "Visuals", Icon = "eye" }),
    PlayerESP = Window:Tab({ Title = "Player ESP", Icon = "users" }),
    Items = Window:Tab({ Title = "Items", Icon = "package" }),
    Waypoints = Window:Tab({ Title = "Waypoints", Icon = "map-pin" }),
}

Window:SelectTab(1)

-- */ Utility Functions /* --
local function getItemsFolder()
    local map = Workspace:FindFirstChild("Map")
    if not map then return nil end
    local util = map:FindFirstChild("Util")
    if not util then return nil end
    return util:FindFirstChild("Items")
end

local function getObjectsFolder()
    local map = Workspace:FindFirstChild("Map")
    if not map then return nil end
    local util = map:FindFirstChild("Util")
    if not util then return nil end
    return util:FindFirstChild("Objects")
end

local function getHRP()
    local char = Player.Character
    if char then
        return char:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function listsEqual(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local function scanItemNames()
    local names = {}
    local seen = {}
    local folder = getItemsFolder()
    if folder then
        for _, item in ipairs(folder:GetChildren()) do
            if not seen[item.Name] then
                seen[item.Name] = true
                table.insert(names, item.Name)
            end
        end
    end
    table.sort(names)
    return names
end

local function scanObjectNames()
    local names = {}
    local seen = {}
    local folder = getObjectsFolder()
    if folder then
        for _, obj in ipairs(folder:GetChildren()) do
            if not seen[obj.Name] then
                seen[obj.Name] = true
                table.insert(names, obj.Name)
            end
        end
    end
    table.sort(names)
    return names
end

local function findFirstItemByName(name)
    local folder = getItemsFolder()
    if not folder then return nil end
    for _, item in ipairs(folder:GetChildren()) do
        if item.Name == name then
            return item
        end
    end
    return nil
end

-- */ Item ESP Management /* --
local function applyItemBillboard(item)
    if not toggles.ItemESP then return end
    if item:FindFirstChild("Flycer_ItemBillboard") then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Flycer_ItemBillboard"
    billboard.Size = UDim2.new(0, 150, 0, 30)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 2, 0)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = item.Name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = billboard

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 1.5
    stroke.Parent = label

    billboard.Parent = item
end

local function clearItemESP()
    local folder = getItemsFolder()
    if not folder then return end
    for _, item in ipairs(folder:GetChildren()) do
        local bb = item:FindFirstChild("Flycer_ItemBillboard")
        if bb then bb:Destroy() end
    end
end

-- */ Object ESP & Highlight Management /* --
local function applyObjectESP(obj)
    if not toggles.ObjectESP then return end
    if not selectedObjectName then return end
    if obj.Name ~= selectedObjectName then return end

    if not obj:FindFirstChild("Flycer_ObjectHighlight") then
        local hl = Instance.new("Highlight")
        hl.Name = "Flycer_ObjectHighlight"
        hl.FillColor = Color3.fromRGB(255, 140, 0)
        hl.FillTransparency = 0.4
        hl.OutlineTransparency = 1
        hl.Parent = obj
    end

    if not obj:FindFirstChild("Flycer_ObjectBillboard") then
        local bb = Instance.new("BillboardGui")
        bb.Name = "Flycer_ObjectBillboard"
        bb.Size = UDim2.new(0, 150, 0, 30)
        bb.AlwaysOnTop = true
        bb.StudsOffset = Vector3.new(0, 2.5, 0)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = obj.Name
        label.TextColor3 = Color3.fromRGB(255, 140, 0)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.Parent = bb

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Thickness = 1.5
        stroke.Parent = label

        bb.Parent = obj
    end
end

local function clearObjectESP()
    local folder = getObjectsFolder()
    if not folder then return end
    for _, obj in ipairs(folder:GetChildren()) do
        local hl = obj:FindFirstChild("Flycer_ObjectHighlight")
        if hl then hl:Destroy() end
        local bb = obj:FindFirstChild("Flycer_ObjectBillboard")
        if bb then bb:Destroy() end
    end
end

-- */ Player ESP & Highlight Management /* --
local function applyPlayerESPName(character, playerName)
    if character:FindFirstChild("Flycer_PlayerBillboard") then return end
    local head = character:FindFirstChild("Head")
    if not head then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "Flycer_PlayerBillboard"
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.Adornee = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = playerName
    label.TextColor3 = Color3.fromRGB(0, 255, 100)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 15
    label.Parent = bb

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 1.5
    stroke.Parent = label

    bb.Parent = character
end

local function applyPlayerHighlight(character)
    if character:FindFirstChild("Flycer_PlayerHighlight") then return end
    local hl = Instance.new("Highlight")
    hl.Name = "Flycer_PlayerHighlight"
    hl.FillColor = Color3.fromRGB(0, 200, 80)
    hl.FillTransparency = 0.35
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineTransparency = 0
    hl.Parent = character
end

local function removePlayerESPName(character)
    local bb = character:FindFirstChild("Flycer_PlayerBillboard")
    if bb then bb:Destroy() end
end

local function removePlayerHighlight(character)
    local hl = character:FindFirstChild("Flycer_PlayerHighlight")
    if hl then hl:Destroy() end
end

local function applyAllPlayerESP(character, playerName)
    if not character then return end
    local head = character:FindFirstChild("Head")
    if not head then
        character:WaitForChild("Head", 5)
    end
    if toggles.PlayerESPName then
        applyPlayerESPName(character, playerName)
    end
    if toggles.PlayerESPHighlight then
        applyPlayerHighlight(character)
    end
end

local function removeAllPlayerESP(character)
    if not character then return end
    removePlayerESPName(character)
    removePlayerHighlight(character)
end

local function cleanupPlayerConnections(userId)
    local conns = playerESPConnections[userId]
    if conns then
        for _, conn in ipairs(conns) do
            if conn.Connected then conn:Disconnect() end
        end
    end
    playerESPConnections[userId] = nil
end

local function bindPlayerCharacterWatch(targetPlayer)
    if targetPlayer == Player then return end
    local userId = targetPlayer.UserId
    cleanupPlayerConnections(userId)
    playerESPConnections[userId] = {}

    local function onCharacterReady(character)
        if not character then return end
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then return end

        applyAllPlayerESP(character, targetPlayer.DisplayName)

        local descAddedConn = character.DescendantAdded:Connect(function(desc)
            if desc.Name == "Head" and desc:IsA("BasePart") then
                task.wait(0.1)
                if toggles.PlayerESPName and not character:FindFirstChild("Flycer_PlayerBillboard") then
                    applyPlayerESPName(character, targetPlayer.DisplayName)
                end
            end
        end)

        local stateChangedConn = humanoid.StateChanged:Connect(function(_, newState)
            task.wait(0.2)
            if not character or not character.Parent then return end
            if toggles.PlayerESPName and not character:FindFirstChild("Flycer_PlayerBillboard") then
                applyPlayerESPName(character, targetPlayer.DisplayName)
            end
            if toggles.PlayerESPHighlight and not character:FindFirstChild("Flycer_PlayerHighlight") then
                applyPlayerHighlight(character)
            end
        end)

        local childRemovedConn = character.ChildRemoved:Connect(function(child)
            task.wait(0.15)
            if not character or not character.Parent then return end
            if child.Name == "Flycer_PlayerBillboard" and toggles.PlayerESPName then
                applyPlayerESPName(character, targetPlayer.DisplayName)
            end
            if child.Name == "Flycer_PlayerHighlight" and toggles.PlayerESPHighlight then
                applyPlayerHighlight(character)
            end
        end)

        local diedConn
        diedConn = humanoid.Died:Connect(function()
            if descAddedConn and descAddedConn.Connected then descAddedConn:Disconnect() end
            if stateChangedConn and stateChangedConn.Connected then stateChangedConn:Disconnect() end
            if childRemovedConn and childRemovedConn.Connected then childRemovedConn:Disconnect() end
            if diedConn and diedConn.Connected then diedConn:Disconnect() end
        end)

        local conns = playerESPConnections[userId]
        if conns then
            table.insert(conns, descAddedConn)
            table.insert(conns, stateChangedConn)
            table.insert(conns, childRemovedConn)
            table.insert(conns, diedConn)
        end
    end

    if targetPlayer.Character then
        task.spawn(onCharacterReady, targetPlayer.Character)
    end

    local charAddedConn = targetPlayer.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        onCharacterReady(character)
    end)

    playerESPConnections[userId] = playerESPConnections[userId] or {}
    table.insert(playerESPConnections[userId], charAddedConn)
end

local function enableAllPlayerESP()
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= Player then
            bindPlayerCharacterWatch(targetPlayer)
        end
    end
end

local function disableAllPlayerESP()
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= Player and targetPlayer.Character then
            removeAllPlayerESP(targetPlayer.Character)
        end
    end
    for userId, _ in pairs(playerESPConnections) do
        cleanupPlayerConnections(userId)
    end
    playerESPConnections = {}
end

local function refreshPlayerESPForAll()
    disableAllPlayerESP()
    if toggles.PlayerESPName or toggles.PlayerESPHighlight then
        enableAllPlayerESP()
    end
end

-- */ Dropdown Refresh System /* --
local function refreshItemDropdown()
    if refreshDebounce then return end
    refreshDebounce = true

    task.delay(0.3, function()
        refreshDebounce = false
        local newList = scanItemNames()
        if listsEqual(newList, cachedItemList) then return end

        cachedItemList = newList
        if itemDropdownRef then
            pcall(function()
                itemDropdownRef:Refresh(cachedItemList)
            end)
        end

        if selectedItemName then
            local stillExists = false
            for _, name in ipairs(cachedItemList) do
                if name == selectedItemName then
                    stillExists = true
                    break
                end
            end
            if not stillExists then
                selectedItemName = nil
            end
        end
    end)
end

local function refreshObjectDropdown()
    if objectRefreshDebounce then return end
    objectRefreshDebounce = true

    task.delay(0.3, function()
        objectRefreshDebounce = false
        local newList = scanObjectNames()
        if listsEqual(newList, cachedObjectList) then return end

        cachedObjectList = newList
        if objectDropdownRef then
            pcall(function()
                objectDropdownRef:Refresh(cachedObjectList)
            end)
        end

        if selectedObjectName then
            local stillExists = false
            for _, name in ipairs(cachedObjectList) do
                if name == selectedObjectName then
                    stillExists = true
                    break
                end
            end
            if not stillExists then
                selectedObjectName = nil
                clearObjectESP()
            end
        end
    end)
end

local function bindItemsFolderListeners()
    for _, conn in ipairs(itemsFolderConn) do
        if conn.Connected then conn:Disconnect() end
    end
    itemsFolderConn = {}

    local folder = getItemsFolder()
    if not folder then return end
    currentItemsFolder = folder

    table.insert(itemsFolderConn, folder.ChildAdded:Connect(function(child)
        refreshItemDropdown()
        if toggles.ItemESP then
            task.wait(0.1)
            applyItemBillboard(child)
        end
    end))

    table.insert(itemsFolderConn, folder.ChildRemoved:Connect(function()
        refreshItemDropdown()
    end))

    refreshItemDropdown()
end

local function bindObjectsFolderListeners()
    for _, conn in ipairs(objectsFolderConn) do
        if conn.Connected then conn:Disconnect() end
    end
    objectsFolderConn = {}

    local folder = getObjectsFolder()
    if not folder then return end

    table.insert(objectsFolderConn, folder.ChildAdded:Connect(function(child)
        refreshObjectDropdown()
        if toggles.ObjectESP and selectedObjectName and child.Name == selectedObjectName then
            task.wait(0.1)
            applyObjectESP(child)
        end
    end))

    table.insert(objectsFolderConn, folder.ChildRemoved:Connect(function()
        refreshObjectDropdown()
    end))

    refreshObjectDropdown()
end

local function watchItemsFolderExistence()
    local map = Workspace:WaitForChild("Map", 10)
    if not map then return end

    local util = map:WaitForChild("Util", 10)
    if not util then return end

    util.ChildAdded:Connect(function(child)
        if child.Name == "Items" then
            task.wait(0.1)
            bindItemsFolderListeners()
        elseif child.Name == "Objects" then
            task.wait(0.1)
            bindObjectsFolderListeners()
        end
    end)

    util.ChildRemoved:Connect(function(child)
        if child.Name == "Items" then
            cachedItemList = {}
            if itemDropdownRef then
                pcall(function()
                    itemDropdownRef:Refresh({})
                end)
            end
        elseif child.Name == "Objects" then
            cachedObjectList = {}
            if objectDropdownRef then
                pcall(function()
                    objectDropdownRef:Refresh({})
                end)
            end
        end
    end)
end

-- */ Instant Interact System /* --
local function makePromptInstant(prompt)
    if originalPromptData[prompt] == nil then
        originalPromptData[prompt] = prompt.HoldDuration
    end
    prompt.HoldDuration = 0
end

local function scanAndApplyInstantInteract()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            makePromptInstant(obj)
        end
    end
end

local function restoreAllPrompts()
    for prompt, holdDuration in pairs(originalPromptData) do
        if prompt and prompt.Parent then
            prompt.HoldDuration = holdDuration
        end
    end
    originalPromptData = {}
end

local function bindInstantInteract()
    for _, conn in ipairs(promptConnections) do
        if conn.Connected then conn:Disconnect() end
    end
    promptConnections = {}

    scanAndApplyInstantInteract()

    table.insert(promptConnections, Workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("ProximityPrompt") and toggles.InstantInteract then
            task.wait(0.05)
            makePromptInstant(desc)
        end
    end))
end

-- */ Bring & Equip Item /* --
local function bringAndEquipItem(itemName)
    if not itemName then
        WindUI:Notify({
            Title = "Item Handler",
            Content = "Silakan pilih item terlebih dahulu dari dropdown.",
            Duration = 3,
            Icon = "triangle-alert",
        })
        return
    end

    local hrp = getHRP()
    if not hrp then
        WindUI:Notify({
            Title = "Item Handler",
            Content = "Karakter Anda tidak ditemukan.",
            Duration = 3,
            Icon = "x",
        })
        return
    end

    local item = findFirstItemByName(itemName)
    if not item then
        WindUI:Notify({
            Title = "Item Handler",
            Content = 'Item "' .. itemName .. '" tidak ditemukan di map.',
            Duration = 3,
            Icon = "x",
        })
        return
    end

    local bringOffset = CFrame.new(0, 0, -2)

    if item:IsA("Model") then
        pcall(function()
            item:PivotTo(hrp.CFrame * bringOffset)
        end)
    elseif item:IsA("BasePart") then
        pcall(function()
            item.CFrame = hrp.CFrame * bringOffset
        end)
    end

    task.wait(0.15)

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local pickupRemote = remotes and remotes:FindFirstChild("RequestPickupItem")
    if pickupRemote then
        pcall(function()
            pickupRemote:FireServer(item)
        end)
        WindUI:Notify({
            Title = "Item Handler",
            Content = 'Berhasil mengambil "' .. itemName .. '"',
            Duration = 3,
            Icon = "check",
        })
    else
        WindUI:Notify({
            Title = "Item Handler",
            Content = "Item berhasil dibawa, namun remote pickup tidak ditemukan.",
            Duration = 3,
            Icon = "triangle-alert",
        })
    end
end

-- */ Movement / Speed Guard /* --
local function getEnhancedSpeed()
    return 20
end

local function getDefaultSpeed()
    return 16
end

local function applySpeedOverride()
    local char = Player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and toggles.Speed then
        hum.WalkSpeed = getEnhancedSpeed()
    end
end

local function setupSpeedGuard(char)
    local hum = char:WaitForChild("Humanoid", 3)
             or char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if speedChangedConn then
        speedChangedConn:Disconnect()
    end

    speedChangedConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        local target = getEnhancedSpeed()
        if toggles.Speed and hum.WalkSpeed ~= target then
            hum.WalkSpeed = target
        end
    end)
end

-- */ Dashboard Tab /* --
do
    Tabs.Menu:Section({ Title = "Interaction System" })

    Tabs.Menu:Toggle({
        Title = "Instant Interact",
        Value = false,
        Callback = function(state)
            toggles.InstantInteract = state
            if state then
                bindInstantInteract()
            else
                for _, conn in ipairs(promptConnections) do
                    if conn.Connected then conn:Disconnect() end
                end
                promptConnections = {}
                restoreAllPrompts()
            end
        end,
    })
end

-- */ Movement Tab /* --
do
    Tabs.Movement:Section({ Title = "Character Movement" })

    Tabs.Movement:Toggle({
        Title = "Enhanced Speed",
        Value = false,
        Callback = function(state)
            toggles.Speed = state
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.WalkSpeed = state and getEnhancedSpeed() or getDefaultSpeed()
                end
            end
        end,
    })

    Tabs.Movement:Toggle({
        Title = "Infinite Jump",
        Value = false,
        Callback = function(state)
            toggles.InfJump = state
        end,
    })

    Tabs.Movement:Section({ Title = "Collision Bypass" })

    Tabs.Movement:Toggle({
        Title = "Noclip Mode",
        Value = false,
        Callback = function(state)
            toggles.Noclip = state
            if not state and Player.Character then
                for _, part in ipairs(Player.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end,
    })
end

-- */ Visuals Tab /* --
do
    Tabs.Visuals:Section({ Title = "Enemy Detection" })

    Tabs.Visuals:Toggle({
        Title = "Enemy ESP",
        Desc = "Menampilkan highlight merah dan label ENEMY pada setiap NPC musuh.",
        Value = false,
        Callback = function(state)
            toggles.EnemyESP = state
            if not state then
                local folder = Workspace:FindFirstChild("Enemies")
                if folder then
                    for _, model in ipairs(folder:GetChildren()) do
                        local esp = model:FindFirstChild("Flycer_EnemyESP")
                        if esp then esp:Destroy() end
                        local bb  = model:FindFirstChild("Flycer_EnemyBillboard")
                        if bb  then bb:Destroy()  end
                    end
                end
            end
        end,
    })

    Tabs.Visuals:Section({ Title = "Item Detection" })

    Tabs.Visuals:Toggle({
        Title = "Item ESP",
        Desc = "Menampilkan nama item yang tersedia di sekitarnya.",
        Value = false,
        Callback = function(state)
            toggles.ItemESP = state
            if not state then
                clearItemESP()
            end
        end,
    })

    Tabs.Visuals:Section({ Title = "Object Detection" })

    Tabs.Visuals:Toggle({
        Title = "Object ESP",
        Desc = "Menampilkan ESP & Highlight Orange pada objek yang dipilih di dropdown.",
        Value = false,
        Callback = function(state)
            toggles.ObjectESP = state
            if not state then
                clearObjectESP()
            elseif not selectedObjectName then
                WindUI:Notify({
                    Title = "Object ESP",
                    Content = "Silakan pilih objek terlebih dahulu dari menu dropdown.",
                    Duration = 3,
                    Icon = "triangle-alert",
                })
            end
        end,
    })

    cachedObjectList = scanObjectNames()
    objectDropdownRef = Tabs.Visuals:Dropdown({
        Title = "Select Object",
        Desc = "Pilih satu objek untuk di-highlight. Toggle Object ESP harus ON.",
        Multi = false,
        AllowNone = true,
        Value = nil,
        Values = cachedObjectList,
        Callback = function(value)
            clearObjectESP()
            selectedObjectName = value
        end,
    })
end

-- */ Player ESP Tab /* --
do
    Tabs.PlayerESP:Section({ Title = "Player ESP & Highlight" })

    Tabs.PlayerESP:Toggle({
        Title = "ESP Username",
        Value = false,
        Callback = function(state)
            toggles.PlayerESPName = state
            refreshPlayerESPForAll()
        end,
    })

    Tabs.PlayerESP:Toggle({
        Title = "Highlight Player",
        Value = false,
        Callback = function(state)
            toggles.PlayerESPHighlight = state
            refreshPlayerESPForAll()
        end,
    })
end

-- */ Items Tab /* --
do
    Tabs.Items:Section({ Title = "Item Selector" })

    cachedItemList  = scanItemNames()
    itemDropdownRef = Tabs.Items:Dropdown({
        Title = "Available Items",
        Desc = "Daftar item akan diperbarui secara otomatis.",
        Multi = false,
        AllowNone = true,
        Value = nil,
        Values = cachedItemList,
        Callback = function(value)
            selectedItemName = value
        end,
    })

    Tabs.Items:Button({
        Title = "Bring & Equip Selected Items",
        Desc = "Memindahkan item terpilih ke posisi Kamu dan meng-equipnya.",
        Locked = false,
        Callback = function()
            bringAndEquipItem(selectedItemName)
        end,
    })
    
    Tabs.Items:Section({ Title = "Action Handler" })

    Tabs.Items:Button({
        Title = "Bring All Items",
        Desc = "Memindahkan seluruh item yang tersedia di map ke posisi Kamu",
        Callback = function()
            local hrp    = getHRP()
            local folder = getItemsFolder()
            if not (hrp and folder) then
                WindUI:Notify({
                    Title = "Bring All Items",
                    Content = "Item folder tidak ditemukan.",
                    Duration = 3,
                })
                return
            end

            local bringAllOffset = CFrame.new(0, 0, -3)
            local count = 0

            for _, item in ipairs(folder:GetChildren()) do
                if item:IsA("Model") then
                    pcall(function()
                        item:PivotTo(hrp.CFrame * bringAllOffset)
                    end)
                    count += 1
                elseif item:IsA("BasePart") then
                    pcall(function()
                        item.CFrame = hrp.CFrame * bringAllOffset
                    end)
                    count += 1
                end
            end
            WindUI:Notify({
                Title = "Bring All Items",
                Content = "Berhasil memindahkan " .. count .. " item.",
                Duration = 1,
            })
        end,
    })
    
    Tabs.Items:Paragraph({
    Title = "⚠️ Warning : Bring All Items",
    Desc = "Gunakan pada perangkat yang mumpuni untuk menghindari lag atau crash.",
})
end

-- */ Waypoints Tab /* --
do
    Tabs.Waypoints:Section({ Title = "Home Location" })

    Tabs.Waypoints:Button({
        Title = "Save Home Position",
        Desc = "Menyimpan lokasi Kamu saat ini sebagai titik Home.",
        Callback = function()
            local hrp = getHRP()
            if hrp then
                waypoints.Home = hrp.CFrame
                WindUI:Notify({
                    Title = "Waypoint System",
                    Content = "Home position disimpan.",
                    Duration = 2,
                })
            else
                WindUI:Notify({
                    Title = "Waypoint System",
                    Content = "Karakter tidak ditemukan.",
                    Duration = 2,
                })
            end
        end,
    })

    Tabs.Waypoints:Button({
        Title = "Teleport to Home",
        Desc = "Berpindah ke posisi Home yang telah disimpan sebelumnya.",
        Callback = function()
            local hrp = getHRP()
            if waypoints.Home and hrp then
                hrp.CFrame = waypoints.Home
            else
                WindUI:Notify({
                    Title = "Waypoint System",
                    Content = "Silakan simpan Home position terlebih dahulu.",
                    Duration = 3,
                })
            end
        end,
    })

    Tabs.Waypoints:Section({ Title = "Loot Location" })

    Tabs.Waypoints:Button({
        Title = "Save Loot Position",
        Desc = "Menyimpan lokasi Anda saat ini sebagai titik Loot Area.",
        Callback = function()
            local hrp = getHRP()
            if hrp then
                waypoints.Loot = hrp.CFrame
                WindUI:Notify({
                    Title = "Waypoint System",
                    Content = "Loot position berhasil disimpan.",
                    Duration = 2,
                })
            else
                WindUI:Notify({
                    Title = "Waypoint System",
                    Content = "Karakter tidak ditemukan.",
                    Duration = 2,
                })
            end
        end,
    })

    Tabs.Waypoints:Button({
        Title = "Teleport to Loot",
        Desc = "Berpindah ke titik Loot yang telah disimpan sebelumnya.",
        Callback = function()
            local hrp = getHRP()
            if waypoints.Loot and hrp then
                hrp.CFrame = waypoints.Loot
            else
                WindUI:Notify({
                    Title = "Waypoint System",
                    Content = "Silakan simpan Loot position terlebih dahulu.",
                    Duration = 3,
                })
            end
        end,
    })
end

-- */ Event Handlers /* --
local function onCharacterAdded(char)
    setupSpeedGuard(char)
end

local function onJumpRequest()
    if not toggles.InfJump then return end
    local char = Player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end

-- */ Initialization & Connections /* --
if Player.Character then
    setupSpeedGuard(Player.Character)
end

Player.CharacterAdded:Connect(onCharacterAdded)
UserInputService.JumpRequest:Connect(onJumpRequest)

bindItemsFolderListeners()
bindObjectsFolderListeners()
watchItemsFolderExistence()

Players.PlayerAdded:Connect(function(targetPlayer)
    if targetPlayer == Player then return end
    if toggles.PlayerESPName or toggles.PlayerESPHighlight then
        bindPlayerCharacterWatch(targetPlayer)
    end
end)

Players.PlayerRemoving:Connect(function(targetPlayer)
    cleanupPlayerConnections(targetPlayer.UserId)
end)

-- */ Loop / Life Cycle /* --
RunService.RenderStepped:Connect(applySpeedOverride)

RunService.Stepped:Connect(function()
    if not toggles.Noclip then return end
    local char = Player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if toggles.EnemyESP then
        local folder = Workspace:FindFirstChild("Enemies")
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                if not model:IsA("Model") then continue end

                if not model:FindFirstChild("Flycer_EnemyESP") then
                    local hl = Instance.new("Highlight")
                    hl.Name                = "Flycer_EnemyESP"
                    hl.FillColor           = Color3.fromRGB(255, 30, 30)
                    hl.FillTransparency    = 0.4
                    hl.OutlineTransparency = 1
                    hl.Parent              = model
                end

                if not model:FindFirstChild("Flycer_EnemyBillboard") then
                    local bb = Instance.new("BillboardGui")
                    bb.Name         = "Flycer_EnemyBillboard"
                    bb.Size         = UDim2.new(0, 100, 0, 30)
                    bb.AlwaysOnTop  = true
                    bb.StudsOffset  = Vector3.new(0, 3, 0)

                    local txt = Instance.new("TextLabel")
                    txt.Size                   = UDim2.new(1, 0, 1, 0)
                    txt.BackgroundTransparency = 1
                    txt.Text                   = "ENEMY"
                    txt.TextColor3             = Color3.fromRGB(255, 50, 50)
                    txt.Font                   = Enum.Font.GothamBold
                    txt.TextSize               = 10
                    txt.Parent                 = bb

                    local stroke = Instance.new("UIStroke")
                    stroke.Color     = Color3.fromRGB(0, 0, 0)
                    stroke.Thickness = 2
                    stroke.Parent    = txt

                    bb.Parent = model
                end
            end
        end
    end

    if toggles.ItemESP then
        local folder = getItemsFolder()
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                if not item:FindFirstChild("Flycer_ItemBillboard") then
                    applyItemBillboard(item)
                end
            end
        end
    end

    if toggles.ObjectESP and selectedObjectName then
        local folder = getObjectsFolder()
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if obj.Name == selectedObjectName then
                    if not obj:FindFirstChild("Flycer_ObjectHighlight")
                    or not obj:FindFirstChild("Flycer_ObjectBillboard") then
                        applyObjectESP(obj)
                    end
                end
            end
        end
    end

    if toggles.PlayerESPName or toggles.PlayerESPHighlight then
        for _, targetPlayer in ipairs(Players:GetPlayers()) do
            if targetPlayer == Player then continue end
            local character = targetPlayer.Character
            if not character then continue end
            if not character:FindFirstChild("Humanoid") then continue end

            if toggles.PlayerESPName and not character:FindFirstChild("Flycer_PlayerBillboard") then
                local head = character:FindFirstChild("Head")
                if head then
                    applyPlayerESPName(character, targetPlayer.DisplayName)
                end
            end

            if toggles.PlayerESPHighlight and not character:FindFirstChild("Flycer_PlayerHighlight") then
                applyPlayerHighlight(character)
            end
        end
    end
end)

-- */ End of Script /* --
WindUI:Notify({
    Title = "Flycer Hub",
    Content = "Thank you for using Flycer Hub! Have a nice play.",
    Duration = 3,
    Icon = "rbxassetid://89557898457977",
})

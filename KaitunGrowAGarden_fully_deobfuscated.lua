





local Player = game:GetService("Players").LocalPlayer
local Players = game:GetService("Players")
local Humanoid = Player.Character:WaitForChild("Humanoid")





local PetInfo = require(game:GetService("ReplicatedStorage"):WaitForChild("Data"):WaitForChild("PetRegistry"):WaitForChild("PetList"))

local config = getgenv().Config
local cachedPlayerData = nil
local IS_LOADED = false

local settings = {
    ["game"] = {
        ["npcs"] = {
            Eloise = Workspace.NPCS:FindFirstChild("Eloise") and Workspace.NPCS.Eloise:FindFirstChild("HumanoidRootPart") and Workspace.NPCS.Eloise.HumanoidRootPart.Position or nil,
            Raphael = Workspace.NPCS:FindFirstChild("Raphael") and Workspace.NPCS.Raphael:FindFirstChild("HumanoidRootPart") and Workspace.NPCS.Raphael.HumanoidRootPart.Position or nil,
            Sam = Workspace.NPCS:FindFirstChild("Sam") and Workspace.NPCS.Sam:FindFirstChild("HumanoidRootPart") and Workspace.NPCS.Sam.HumanoidRootPart.Position or nil,
            Steven = Workspace.NPCS:FindFirstChild("Steven") and Workspace.NPCS.Steven:FindFirstChild("HumanoidRootPart") and Workspace.NPCS.Steven.HumanoidRootPart.Position or nil,
        },
        ["seeds"] = {
            ["normal"] = {
                "Carrot", "Strawberry",
                "Blueberry", "Orange Tulip",
                "Tomato", "Corn",
                "Daffodil", "Watermelon", "Pumpkin", "Apple", "Bamboo",
                "Coconut", "Cactus", "Dragon Fruit", "Mango",
                "Grape", "Mushroom", "Pepper", "Cacao",
                "Beanstalk", "Ember Lily", "Sugar Apple"
            },
            ["event"] = {
                "Flower Seed Pack", "Nectarine", "Hive Fruit", "Pollen Radar"
            }
        },
        ["tools"] = {
            ["normal"] = {
                "Watering Can", "Trowel", "Recall Wrench", "Basic Sprinkler", "Advanced Sprinkler", "Godly Sprinkler", "Lightning Rod", "Master Sprinkler", "Favorite Tool", "Recall Wrench", "Haverst Tool", "Friendship Pot", "Cleaning Spray"
            },
            ["event"] = {
                "Honey Sprinkler"
            }
        },
        ["eggs"] = {
            ["normal"] = {
                "Common Egg", "Uncommon Egg", "Rare Egg", "Legendary Egg", "Mythical Egg", "Bug Egg"
            },
            ["event"] = {
                "Bee Egg"
            }
        },
        ["cosmetic"] = {
            ["normal"] = {},
            ["event"] = {
                "Honey Crate", "Honey Comb", "Bee Chair", "Honey Torch", "Honey Walkway", "Nectarshade Seed", "Lavender Seed", "Nectar Staff"
            }
        },
        ["mutations"] = {
            "Gold", "Rainbow", "Shocked", "Wet", "Frozen"
        }
    },
    ["player"] = {
        ["Sheckles"] = nil,
        ["Farm"] = nil,
        ["Place Egg"] = {},
        ["Favorite Fruit"] = {},
        ["Trigger"] = {
            isBuySeeds = false,
            isBuyTools = false,
            isBuyEggs = false
        },
        isSelling = false
    }
}





local function teleport(position)
    local Char = Player.Character
    if Char and Char:FindFirstChild("HumanoidRootPart") then
        local adjustedPos = position + Vector3.new(0, 0.5, 0)
        Char.HumanoidRootPart.CFrame = CFrame.new(adjustedPos)
    end
end

local function getFarm()
    for _, farm in ipairs(workspace:WaitForChild("Farm"):GetChildren()) do
        local success, owner = pcall(function()
            return farm:WaitForChild("Important").Data.Owner.Value
        end)
        if success and owner == Player.Name then
            return farm
        end
    end
    return nil
end

local function collectInventory()
    local all = {}
    for _, container in ipairs({Player.Backpack, Player.Character}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    table.insert(all, tool)
                end
            end
        end
    end
    return all
end

local function searchInventorySeed(item)
    local pattern = "%[x%d+%]$"
    local itemName = item:lower()
    for _, tool in ipairs(collectInventory()) do
        local name = tool.Name:lower()
        if name:find("^" .. itemName) and name:find(pattern) then
            return tool
        end
    end
end

local function removeFirstFruitByName(fruitName)
    local farm = getFarm()

    local plants = farm:WaitForChild("Important"):FindFirstChild("Plants_Physical")
    if plants then
        for _, plant in ipairs(plants:GetChildren()) do
            if plant.Name == fruitName then
                local fruitPart = plant:FindFirstChildWhichIsA("BasePart")
                if fruitPart then
                    game.ReplicatedStorage.GameEvents.Remove_Item:FireServer(fruitPart)
                    return true
                end
            end
        end
    end
    return false
end

local function isHungry(hunger, petType, hungerThreshold)
    hungerThreshold = hungerThreshold or 0.50 
    
    local maxHunger = PetInfo[petType].DefaultHunger

    if not hunger or not maxHunger then
        return false 
    end

    return (hunger / maxHunger) < hungerThreshold
end

local function isPetEquipped(tbl, uuid)
    for _, v in pairs(tbl) do
        if v == uuid then
            return true
        end
    end
    return false
end

local function rarityAllowed(rarityList, rarity)
    for _, r in ipairs(rarityList) do
        for k,v in pairs(r) do
            if k == rarity and v == true then return true end
        end
    end
    return false
end

local function petNameInList(petNameList, petName)
    for _, v in ipairs(petNameList or {}) do
        if v == petName then return true end
    end
    return false
end

local function filterByConfig(category, subcategory)
    local list = settings.game[category]
    local configKey = "Buy " .. category:sub(1,1):upper() .. category:sub(2)
    local configItems = config[configKey] and config[configKey].Item
    if not configItems or type(list) ~= "table" then return end

    local newList = {}
    for _, item in ipairs(list[subcategory]) do
        if configItems[item] then
            newList[#newList+1] = item
        end
    end
    list[subcategory] = newList
end


local function filterEventItems()
    local eventConfig = config["Buy Events"] and config["Buy Events"]["Item"]
    if not eventConfig then return end  

    for category, data in pairs(settings.game) do
        
        if type(data) == "table" and type(data["event"]) == "table" then
            local newList = {}
            for _, item in ipairs(data["event"]) do
                if eventConfig[item] == true then  
                    table.insert(newList, item)  
                end
            end
            settings.game[category]["event"] = newList  
        end
    end
end

local function ApplyLowGraphicsMode()
    local Players = game:GetService("Players")
    local Lighting = game:GetService("Lighting")
    local Workspace = game:GetService("Workspace")
    local Terrain = Workspace:FindFirstChildOfClass("Terrain")
    local Player = Players.LocalPlayer

    
    local function getMyFarm()
        for _, farm in ipairs(Workspace:WaitForChild("Farm"):GetChildren()) do
            local success, owner = pcall(function()
                return farm:WaitForChild("Important").Data.Owner.Value
            end)
            if success and owner == Player.Name then
                return farm
            end
        end
        return nil
    end

    
    local function destroyOtherFarms()
        local myFarm = getMyFarm()
        for _, farm in ipairs(Workspace:WaitForChild("Farm"):GetChildren()) do
            if farm ~= myFarm then
                farm:Destroy()
            end
        end
    end

    
    pcall(function()
        sethiddenproperty(Lighting, "Technology", Enum.Technology.Compatibility)
    end)
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 1e10
    Lighting.Brightness = 0
    Lighting.ClockTime = 14
    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("BloomEffect") or v:IsA("ColorCorrectionEffect") then
            v:Destroy()
        end
    end

    
    if Terrain then
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0
        Terrain.WaterTransparency = 1
    end

    
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
            obj.CastShadow = false
        elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceGui") then
            obj:Destroy()
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
            obj:Destroy()
        elseif obj:IsA("Sound") then
            obj.Volume = 0
        end
    end

    
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            for _, item in ipairs(p.Character:GetChildren()) do
                if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("CharacterMesh") then
                    item:Destroy()
                end
            end
        end
    end

    
    local cam = Workspace:FindFirstChildOfClass("Camera")
    if cam then
        cam.FieldOfView = 50
    end

    
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level02
        settings().Rendering.EagerBulkExecution = false
        game:GetService("UserSettings"):GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)

    
    local playerGui = Player:WaitForChild("PlayerGui")
    for _, gui in ipairs(playerGui:GetChildren()) do
        if not gui:IsA("ScreenGui") then
            gui:Destroy()
        end
    end

    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function(char)
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("CharacterMesh") then
                    item:Destroy()
                end
            end
        end)

        
        task.delay(2, function()
            for _, farm in ipairs(Workspace:WaitForChild("Farm"):GetChildren()) do
                local success, owner = pcall(function()
                    return farm:WaitForChild("Important").Data.Owner.Value
                end)
                if success and owner ~= Player.Name then
                    farm:Destroy()
                end
            end
        end)
    end)

    
    task.spawn(destroyOtherFarms)
end

local function optimizeMyFarm()
    local farm = settings["player"]["Farm"]

    
    for _, obj in ipairs(farm:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CanCollide = false
            obj.CastShadow = false
            obj.Reflectance = 0
            obj.Material = Enum.Material.SmoothPlastic
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
            obj:Destroy()
        elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceGui") then
            obj:Destroy()
        elseif obj:IsA("Sound") then
            obj.Volume = 0
        end
    end

    
    farm.DescendantAdded:Connect(function(obj)
        task.defer(function()
            if obj:IsA("BasePart") then
                obj.CanCollide = false
                obj.CastShadow = false
                obj.Reflectance = 0
                obj.Material = Enum.Material.SmoothPlastic
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
                obj:Destroy()
            elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceGui") then
                obj:Destroy()
            elseif obj:IsA("Sound") then
                obj.Volume = 0
            end
        end)
    end)
end




getgenv().kaitun = {loaded = true}

task.delay(5, function()
    ApplyLowGraphicsMode()
    optimizeMyFarm()
    IS_LOADED = true
end)

task.spawn(function()
    while task.wait(1) do
        settings['player']["Sheckles"] = Player:WaitForChild("leaderstats").Sheckles.Value
        settings["player"]["Farm"] = getFarm()
    end
end)


filterByConfig("seeds", "normal")
filterByConfig("eggs", "normal")
filterByConfig("tools", "normal")
filterEventItems()

repeat
    task.wait()
until(typeof(settings["player"]["Farm"]) == "Instance" and settings["player"]["Farm"].GetDescendants)

repeat
    task.wait()
until(typeof(settings["player"]["Sheckles"]) == "number")

for _, obj in ipairs(settings["player"]["Farm"]:GetDescendants()) do
    if obj:IsA("BasePart") then
        obj.CanCollide = false
    end
end

local base = settings["player"]["Farm"]:WaitForChild("Important").Plant_Locations.Can_Plant.Position
local points = {}


for i = -2, 2 do
    table.insert(points, {
        Used = false,
        Position = Vector3.new(base.X + (i * 4), base.Y, base.Z - 15)
    })
end


for i = -1, 1 do
    table.insert(points, {
        Used = false,
        Position = Vector3.new(base.X + (i * 4), base.Y, base.Z - 19)
    })
end

settings.player["Place Egg"] = points


task.spawn(function()
    local DataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
    if typeof(DataService.GetData) == "function" then
        local oldGetData = DataService.GetData

        DataService.GetData = function(self, ...)
            local data = oldGetData(self, ...)
            cachedPlayerData = data
            return data
        end
    else
        warn("DataService.GetData bukan fungsi atau belum tersedia.")
    end
end)


task.spawn(function()
    while task.wait(1) do
        local success, err = pcall(function()
            if not IS_LOADED then return end
            if not settings["player"]["Trigger"].isBuySeeds then return end

            local data = cachedPlayerData
            if not data or not data.SeedStock or not data.SeedStock.Stocks then return end

            local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):FindFirstChild("BuySeedStock")

            for _, itemName in ipairs(settings.game.seeds.normal) do
                local stockData = data.SeedStock.Stocks[itemName]
                if stockData and stockData.Stock > 0 then
                    for _ = 1, stockData.Stock do
                        remote:FireServer(itemName)
                        task.wait()
                    end
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Buy Seeds]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            if not IS_LOADED then return end
            if not settings["player"]["Trigger"].isBuyTools then return end

            local data = cachedPlayerData
            if not data or not data.GearStock or not data.GearStock.Stocks then return end

            local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):FindFirstChild("BuyGearStock")

            for _, itemName in ipairs(settings.game.tools.normal) do
                local stockData = data.GearStock.Stocks[itemName]
                if stockData and stockData.Stock > 0 then
                    for _ = 1, stockData.Stock do
                        remote:FireServer(itemName)
                        task.wait()
                    end
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Buy Tools]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            if not IS_LOADED then return end
            if not settings["player"]["Trigger"].isBuyEggs then return end

            local data = cachedPlayerData
            if not data or not data.PetEggStock or not data.PetEggStock.Stocks then return end

            local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("BuyPetEgg")

            for index, eggData in pairs(data.PetEggStock.Stocks) do
                if eggData and eggData.Stock > 0 then
                    for _, name in ipairs(settings.game.eggs.normal) do
                        if eggData.EggName == name then
                            remote:FireServer(index)
                            break
                        end
                    end
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Buy Eggs]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            if not IS_LOADED then return end
            if not config["Buy Events"]["Enabled"] then return end

            local data = cachedPlayerData
            if not data or not data.EventShopStock or not data.EventShopStock.Stocks then return end

            local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):FindFirstChild("BuyEventShopStock")

            local items = {}
            for _, v in ipairs(settings.game.seeds.event) do table.insert(items, v) end
            for _, v in ipairs(settings.game.tools.event) do table.insert(items, v) end
            for _, v in ipairs(settings.game.eggs.event) do table.insert(items, v) end
            for _, v in ipairs(settings.game.cosmetic.event) do table.insert(items, v) end

            for _, itemName in ipairs(items) do
                local stockData = data.EventShopStock.Stocks[itemName]
                if stockData and stockData.Stock > 0 then
                    for _ = 1, stockData.Stock do
                        remote:FireServer(itemName)
                        task.wait()
                    end
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Buy Event]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do 
        local success, err = pcall(function()
            if not IS_LOADED then return end

            local farm = settings["player"]["Farm"]
            if not farm then return end

            for _, egg in ipairs(farm:WaitForChild("Important").Objects_Physical:GetChildren()) do
                if egg.Name ~= "PetEgg" then continue end
                local time = egg:GetAttribute("TimeToHatch")
                if time == 0 then
                    local args = {"HatchPet", egg}
                    game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("PetEggService"):FireServer(unpack(args))
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Hatch Eggs]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do 
        local success, err = pcall(function()
            if not IS_LOADED then return end

            local sheckles = settings["player"]["Sheckles"]
            local dontBuyThreshold = config["Dont Buy Seed"]["If Money More Than"]

            
            if sheckles > dontBuyThreshold then
                for name, _ in pairs(config["Buy Seeds"]["Item"]) do
                    for _, dont in ipairs(config["Dont Buy Seed"]["Seed Name"]) do
                        if name == dont then
                            config["Buy Seeds"]["Item"][name] = false
                        end
                    end
                end
            else
                
                for name, _ in pairs(config["Buy Seeds"]["Item"]) do
                    for _, dont in ipairs(config["Dont Buy Seed"]["Seed Name"]) do
                        if name == dont then
                            config["Buy Seeds"]["Item"][name] = true
                        end
                    end
                end
            end

            filterByConfig("seeds", "normal")

            
            if sheckles > config["Buy Seeds"]["Threshold"] then
                settings["player"]["Trigger"].isBuySeeds = config["Buy Seeds"]["Enabled"]
            else
                settings["player"]["Trigger"].isBuySeeds = false
            end

            
            if sheckles > config["Buy Tools"]["Threshold"] then
                settings["player"]["Trigger"].isBuyTools = config["Buy Tools"]["Enabled"]
            else
                settings["player"]["Trigger"].isBuyTools = false
            end

            
            if sheckles > config["Buy Eggs"]["Threshold"] then
                settings["player"]["Trigger"].isBuyEggs = config["Buy Eggs"]["Enabled"]
            else
                settings["player"]["Trigger"].isBuyEggs = false
            end
        end)
        if not success then
            warn("[Task Error: Watch Sheckles]", err)
        end
    end
end)



task.spawn(function()
    while task.wait(1) do
        local success, err = pcall(function()
            if not IS_LOADED then return end

            local farm = settings["player"]["Farm"]

            local inventories = collectInventory()
            local pollinated = {}
            local seeds = {}
            local fruits = {}
            local eggs = {}
            local seedPack = {}
            local sprinklers = {}

            if #settings.player["Favorite Fruit"] > 100 then
                table.remove(settings.player["Favorite Fruit"], 1)
            end

            for _, tool in ipairs(inventories) do
                local itemName = tool:GetAttribute("ItemName")
                local itemType = tool:GetAttribute("ItemType")
                local uuid = tool:GetAttribute("ITEM_UUID")
                local isPollinated = tool:GetAttribute("Pollinated")
                local isFavorite = tool:GetAttribute("Favorite")

                if itemType == "Seed" then
                    if not (config["Dont Plant Inventory Seed"]["Enabled"] and table.find(config["Dont Plant Inventory Seed"]["Seed Name"], itemName)) then
                        table.insert(seeds, {name = itemName, tool = tool})
                    end

                elseif itemType == "Holdable" then
                    if farm:WaitForChild("Important").Plants_Physical:FindFirstChild(itemName) then
                        table.insert(fruits, itemName)
                    end

                    if isPollinated then
                        if not isFavorite then
                            if not table.find(settings.player["Favorite Fruit"], uuid) then
                                table.insert(settings.player["Favorite Fruit"], uuid)
                                game.ReplicatedStorage.GameEvents.Favorite_Item:FireServer(tool)
                                task.wait(0.05)
                            end
                        end

                        table.insert(pollinated, tool)
                    end

                elseif itemType == "PetEgg" then
                    table.insert(eggs, tool)

                elseif itemType == "Seed Pack" then
                    table.insert(seedPack, tool)

                elseif itemType == "Sprinkler" then
                    table.insert(sprinklers, {name = itemName, tool = tool})
                end
            end


            if #pollinated > 0 then
                local data = cachedPlayerData

                if data.HoneyMachine.TimeLeft == 0 then
                    manager:normal("GivePollinateFruit", function(cachedPlayerData)
                        local data = cachedPlayerData
                        if not data or not data.HoneyMachine then return end

                        for _, tool in ipairs(pollinated) do
                            if data.HoneyMachine.TimeLeft ~= 0 then return end
                            
                            local isFavorite = tool:GetAttribute("Favorite")
                            if isFavorite then
                                game.ReplicatedStorage.GameEvents.Favorite_Item:FireServer(tool)
                                task.wait(0.05)
                            end

                            local currentTool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
                            if currentTool ~= tool then
                                Player.Character.Humanoid:EquipTool(tool)
                                task.wait(0.5)
                            end

                            
                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("HoneyMachineService_RE"):FireServer("MachineInteract")
                            task.wait(0.3)
                            
                        end
                    end, {cachedPlayerData}, function() return true end)
                end
            end

            local function collectSeeds()
                local all = {}
                for _, container in ipairs({Player.Backpack, Player.Character}) do
                    if container then
                        for _, tool in ipairs(container:GetChildren()) do
                            if tool:IsA("Tool") and tool.Name:lower():find("seed") then
                                table.insert(all, tool)
                            end
                        end
                    end
                end
                return all
            end

            local seeds = collectSeeds()
            if #seeds == 0 then

            else
                local plants = farm:WaitForChild("Important").Objects_Physical:GetChildren()
                if #plants < 800 then
                    for _, seed in ipairs(seeds) do

                        if Player.Backpack:FindFirstChild(seed.Name) then
                            Player.Backpack[seed.Name].Parent = Player.Character
                            task.wait(0.01)
                        end
                        Player.Character.Humanoid:EquipTool(seed)
                        task.wait(0.01)
                        local quantity = tonumber(seed.Name:match("%[x(%d+)%]")) or 1
                        for i = 1, quantity do
                            local pos = farm:WaitForChild("Important").Plant_Locations.Can_Plant.Position
                            local offsetX = math.random(-5, 5) / 100
                            local offsetZ = math.random(-5, 5) / 100
                            local plantPos = Vector3.new(pos.X + offsetX, pos.Y, pos.Z + offsetZ)
                            local args = {plantPos, seed.Name:gsub(" Seed.*", "")}
                            local success, err = pcall(function()
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("Plant_RE"):FireServer(unpack(args))
                            end)
                            if not success then
                                warn("[AutoPlant] Plant_RE error:", err)
                            end
                            task.wait(0.01)
                        end
                    end
                else
                end
            end

            if #fruits > 100 then
                settings.player.isSelling = true

                manager:normal("AutoSelling", function(settings)
                    
                    teleport(settings.game.npcs.Steven)
                    task.wait(1)

                    game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("Sell_Inventory"):FireServer()
                    task.wait(1)

                    settings.player.isSelling = false
                end, {settings}, function() return true end)
            end

            if #eggs > 0 then
                local eggPlaced = 0

                
                for _, entry in ipairs(settings.player["Place Egg"]) do
                    entry.Used = false
                end

                
                for _, egg in ipairs(farm:WaitForChild("Important").Objects_Physical:GetChildren()) do
                    if egg.Name == "PetEgg" then
                        eggPlaced = eggPlaced + 1

                        
                        local pos = egg.PetEgg.Position
                        for _, entry in ipairs(settings.player["Place Egg"]) do
                            if not entry.Used then
                                local diffX = math.abs(entry.Position.X - pos.X)
                                local diffZ = math.abs(entry.Position.Z - pos.Z)
                                if diffX <= 1 and diffZ <= 1 then
                                    entry.Used = true
                                    break
                                end
                            end
                        end
                    end
                end

                
                local data = cachedPlayerData

                local maxEggs = data.PetsData.MutableStats.MaxEggsInFarm
                if eggPlaced < maxEggs then
                    
                    manager:normal("AutoPlaceEgg", function()
                        for _, egg in ipairs(eggs) do
                            local currentTool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
                            if currentTool ~= egg then
                                Player.Character.Humanoid:EquipTool(egg)
                                task.wait(2)
                            end

                            for i = 1, egg:GetAttribute("LocalUses") do
                                
                                local targetPos = nil
                                for _, entry in ipairs(settings.player["Place Egg"]) do
                                    if not entry.Used then
                                        targetPos = entry
                                        break
                                    end
                                end

                                if not targetPos then return end

                                
                                local args = {
                                    [1] = "CreateEgg",
                                    [2] = targetPos.Position
                                }
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("PetEggService"):FireServer(unpack(args))

                                
                                targetPos.Used = true

                                eggPlaced = eggPlaced + 1
                                task.wait(1)

                                if eggPlaced >= maxEggs then return end
                            end
                        end
                    end, {}, function() return true end)
                end
            end

            if #seedPack > 0 then
                manager:normal("OpenSeedPack", function()
                    for _, pack in ipairs(seedPack) do
                        local currentTool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
                        if currentTool ~= pack then
                            Player.Character.Humanoid:EquipTool(pack)
                            task.wait(2)
                        end

                        for i = 1, pack:GetAttribute("Uses") do
                            pack:Activate()
                            task.wait(1)
                        end
                    end
                end, {}, function() return true end)
            end

            if #sprinklers > 0 and config["Use Sprinklers"]["Enabled"] then
                local point = farm:WaitForChild("Important").Plant_Locations.Can_Plant
                local uses = {}
                local planted = {} 

                
                for _, obj in ipairs(farm:WaitForChild("Important").Objects_Physical:GetChildren()) do
                    if config["Use Sprinklers"]["Sprinkler"][obj.Name] and obj:FindFirstChild("Root") then
                        local dist = (obj.Root.Position - point.Position).Magnitude
                        if dist <= 2 then
                            planted[obj.Name] = true
                        end
                    end
                end

                
                for _, sprinkler in ipairs(sprinklers) do
                    local name = sprinkler.name
                    if config["Use Sprinklers"]["Sprinkler"][name] and not planted[name] then
                        uses[name] = sprinkler
                    end
                end

                
                local stack = config["Use Sprinklers"]["Stack"]
                local requireStack = false
                local allStackReady = true

                for name, state in pairs(stack) do
                    if state then
                        requireStack = true
                        if not (uses[name] or planted[name]) then
                            allStackReady = false
                            break
                        end
                    end
                end

                if not requireStack or allStackReady then
                    manager:normal("PlaceSprinkler", function(config)
                        for name, toolData in pairs(uses) do
                            if config["Use Sprinklers"]["Sprinkler"][name] then
                                local currentTool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
                                if currentTool ~= toolData.tool then
                                    Player.Character.Humanoid:EquipTool(toolData.tool)
                                    task.wait(2)
                                end

                                local cf = point.CFrame * CFrame.new(0, 0.5, 0)
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("SprinklerService"):FireServer("Create", cf)
                                task.wait(1)
                            end
                        end
                    end, {config}, function() return true end)
                end
            end
        end)
        if not success then
            warn("[Task Error: Check Inventory]", err)
        end
    end
end)








task.spawn(function()
    while task.wait(1) do
        local success, err = pcall(function()
            if not IS_LOADED then return end

            local skip = false
            if config["Dont Collect On Weather"]["Enabled"] then
                local workspaceAttr = workspace:GetAttributes()
                for weather, active in pairs(config["Dont Collect On Weather"]["Weather"]) do
                    if workspaceAttr[weather] and active then
                        skip = true
                        break
                    end
                end
            end

            if skip then return end

            local isHarvesting = false

            local farm = settings["player"]["Farm"]

            for _, plant in ipairs(farm:WaitForChild("Important").Plants_Physical:GetChildren()) do
                if isHarvesting then break end
                
                for _, descendant in ipairs(plant:GetDescendants()) do
                    if descendant:IsA("ProximityPrompt") and descendant.Enabled then
                        isHarvesting = true
                        break
                    end
                end
            end

            if isHarvesting then
                manager:normal("AutoHarvesting", function(settings)
                    for _, plant in ipairs(settings["player"]["Farm"]:WaitForChild("Important").Plants_Physical:GetChildren()) do
                        for _, descendant in ipairs(plant:GetDescendants()) do
                            if settings.player.isSelling then return end

                            if descendant:IsA("ProximityPrompt") and descendant.Enabled then
                                local part = descendant.Parent
                                if part and part:IsA("BasePart") then
                                    teleport(part.Position)
                                    task.wait(0.05)
                                    fireproximityprompt(descendant)
                                    task.wait()
                                end
                            end
                        end
                    end

                    settings.player.isSelling = true
                end, {settings}, function() return true end)
            end
        end)
        if not success then
            warn("[Task Error: Auto Harvesting]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(1) do
        local success, err = pcall(function()
            if not IS_LOADED then return end
            if not settings.player.isSelling then return end

            manager:normal("AutoSelling", function(settings)
                
                teleport(settings.game.npcs.Steven)
                task.wait(0.5)

                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("Sell_Inventory"):FireServer()
                task.wait(2)

                settings.player.isSelling = false
            end, {settings}, function() return true end)
        end)
        if not success then
            warn("[Task Error: Auto Selling]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            if not IS_LOADED then return end

            local farm = settings["player"]["Farm"]
            local plants = farm and farm:WaitForChild("Important").Plants_Physical:GetChildren() or {}

            local isPlanted = false

            for _, name in ipairs(config["Delete Planted Seed"]["Name Seed Delete"]) do
                if farm:WaitForChild("Important").Plants_Physical:FindFirstChild(name) then
                    isPlanted = true
                    break
                end
            end

            if isPlanted then
                local shekles = settings["player"]["Sheckles"]
                local selectedSlot = nil
                local maxMin = -math.huge

                for _, slot in ipairs(config["Delete Planted Seed"]["Slot"]) do
                    if shekles >= slot.min and slot.min > maxMin then
                        selectedSlot = slot.slot
                        maxMin = slot.min
                    end
                end

                local overCount = #plants - selectedSlot

                if overCount > 0 then
                    manager:normal("DestroyPlant", function(overCount)
                        local shovel = Player.Backpack:FindFirstChild("Shovel [Destroy Plants]") or Player.Character:FindFirstChild("Shovel [Destroy Plants]")
                        if shovel then Player.Character.Humanoid:EquipTool(shovel) task.wait(1) end

                        for _, name in ipairs(config["Delete Planted Seed"]["Name Seed Delete"]) do
                            if overCount < 1 then break end
                            for i = 1, overCount do 
                                local isDeleted = removeFirstFruitByName(name)
                                if not isDeleted then break end
                                task.wait(0.1)
                                overCount = overCount - 1
                            end
                        end
                    end, {overCount}, function() return true end)
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Remove Plants]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            if not IS_LOADED then return end

            local farm = settings["player"]["Farm"]
            local plants = farm and farm:WaitForChild("Important").Plants_Physical:GetChildren() or {}

            if #plants > 750 then
                manager:priority("BalancerPlant", function(settings)
                    
                    for _, plant in ipairs(farm:WaitForChild("Important").Plants_Physical:GetChildren()) do
                        for _, descendant in ipairs(plant:GetDescendants()) do
                            if settings.player.isSelling then return end

                            if descendant:IsA("ProximityPrompt") and descendant.Enabled then
                                local part = descendant.Parent
                                if part and part:IsA("BasePart") then
                                    teleport(part.Position)
                                    task.wait(0.05)
                                    fireproximityprompt(descendant)
                                    task.wait()
                                end
                            end
                        end
                    end

                    
                    teleport(settings.game.npcs.Steven)
                    task.wait(1)

                    game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("Sell_Inventory"):FireServer()
                    task.wait(1)

                    
                    local plants = settings["player"]["Farm"].Important.Plants_Physical:GetChildren() or {}

                    if #plants > 750 then
                        local plantGroups = {}
                        for _, plant in ipairs(plants) do
                            local name = plant.Name
                            plantGroups[name] = (plantGroups[name] or 0) + 1
                        end

                        local shovel = Player.Backpack:FindFirstChild("Shovel [Destroy Plants]") or Player.Character:FindFirstChild("Shovel [Destroy Plants]")
                        if shovel then Player.Character.Humanoid:EquipTool(shovel) task.wait(1) end

                        for _, name in ipairs(config["Delete Planted Seed"]["Name Seed Delete"]) do
                            local maxDelete = plantGroups[name] or 0

                            for i = 1, maxDelete do
                                local isDeleted = removeFirstFruitByName(name)
                                if not isDeleted then break end
                                task.wait(0.1)
                            end
                        end
                    end
                end, {settings}, function() return true end)
            end
        end)
        if not success then
            warn("[Task Error: Balancer Plant]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            if not IS_LOADED then return end
            if not config["Use Pets"]["Enabled"] then return end

            local data = cachedPlayerData
            if not data or not data.PetsData or not data.PetsData.PetInventory or not data.PetsData.PetInventory.Data then return end
            if next(data.PetsData.PetInventory.Data) == nil then return end

            local equipped = data.PetsData.EquippedPets
            local usePets = config["Use Pets"]

            local placed = #equipped
            local hungries = {}
            for uuid, pet in pairs(data.PetsData.PetInventory.Data) do
                local isEquipped = isPetEquipped(equipped, uuid)
                local allowedByName = petNameInList(usePets["Pet Name"], pet.PetType)
                local allowedByRarity = rarityAllowed(usePets["Pet Rarity"], PetInfo[pet.PetType] and PetInfo[pet.PetType].Rarity)
                local allowed = allowedByName or allowedByRarity
                local maxEquipped = data.PetsData.MutableStats.MaxEquippedPets

                if isEquipped and not allowed then
                    game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("UnequipPet", uuid)
                    task.wait(0.05)
                    placed = placed - 1
                elseif not isEquipped and allowed and placed < maxEquipped then
                    game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("EquipPet", uuid)
                    task.wait(0.05)
                    placed = placed + 1
                end

                local hungry = isHungry(pet.PetData.Hunger, pet.PetType)

                if hungry then table.insert(hungries, uuid) end
            end

            if #hungries > 0 then
                manager:normal("FeedPet", function(farm, collectInventory, isHungry, cachedPlayerData)
                    local data = cachedPlayerData
                    if not data then return end

                    local inventories = collectInventory()
                    local fruits = {}
                    for _, tool in ipairs(inventories) do
                        local itemName = tool:GetAttribute("ItemName")
                        local itemType = tool:GetAttribute("ItemType")
                        local isFavorite = tool:GetAttribute("Favorite")

                        if itemType == "Holdable" and not isFavorite then
                            if farm:WaitForChild("Important").Plants_Physical:FindFirstChild(itemName) then
                                table.insert(fruits, tool)
                            end
                        end
                    end

                    if #fruits == 0 then return end

                    for _, pet in ipairs(hungries) do
                        for i = #fruits, 1, -1 do
                            Player.Character.Humanoid:EquipTool(fruits[i])
                            task.wait(1)

                            game:GetService("ReplicatedStorage").GameEvents.ActivePetService:FireServer("Feed", pet)
                            task.wait(0.3)

                            table.remove(fruits, i)

                            local hungry = isHungry(data.PetsData.PetInventory.Data[pet]["PetData"].Hunger, data.PetsData.PetInventory.Data[pet]["PetType"])
                            if not hungry then break end
                        end
                    end

                end, {settings["player"]["Farm"], collectInventory, isHungry, cachedPlayerData}, function() return true end)
            end
        end)
        if not success then
            warn("[Task Error: Feed Pet]", err)
        end
    end
end)


if getgenv().Config["Auto Rejoin"]["Enabled"] then
    local function TryRejoin()
        local delayTime = getgenv().Config["Auto Rejoin"]["Delay"] or 5
        task.wait(delayTime)
        TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
    end

    Players.LocalPlayer.OnTeleport:Connect(function(State)
        if State == Enum.TeleportState.Failed or State == Enum.TeleportState.RequestRejected then
            TryRejoin()
        end
    end)

    game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
        if child.Name == "ErrorPrompt" then
            local msg = child:FindFirstChild("MessageArea") and child.MessageArea:FindFirstChild("ErrorFrame") and child.MessageArea.ErrorFrame:FindFirstChild("ErrorMessage")
            if msg and msg.Text then
                TryRejoin()
            end
        end
    end)
end

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

DrawingCache = DrawingCache or {}

local function createESP(id, text, color)
    if DrawingCache[id] then return end
    local label = Drawing.new("Text")
    label.Text = text
    label.Size = 18
    label.Color = color
    label.Center = true
    label.Outline = true
    label.OutlineColor = Color3.new(0, 0, 0)
    label.Visible = true

    DrawingCache[id] = {
        label = label,
        text = text,
        color = color,
    }
end

local function removeESP(id)
    if DrawingCache[id] then
        if DrawingCache[id].label then
            DrawingCache[id].label:Remove()
        end
        DrawingCache[id] = nil
    end
end

if getgenv().Config and getgenv().Config["ESP"] and getgenv().Config["ESP"]["Player"] == true then
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            createESP("player_" .. plr.Name, plr.Name, Color3.fromRGB(255, 255, 0))
        end
    end

    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function()
            task.wait(1)
            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                createESP("player_" .. plr.Name, plr.Name, Color3.fromRGB(255, 255, 0))
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(plr)
        removeESP("player_" .. plr.Name)
    end)
end

if getgenv().Config and getgenv().Config["ESP"] and getgenv().Config["ESP"]["Pollinated"] == true then
    for _, plant in ipairs(CollectionService:GetTagged("Plant")) do
        if plant:GetAttribute("Pollinated") then
            createESP("plant_" .. plant:GetDebugId(), "338 Pollinated", Color3.fromRGB(255, 105, 180))
        end
    end

    CollectionService:GetInstanceAddedSignal("Plant"):Connect(function(plant)
        if plant:GetAttribute("Pollinated") then
            createESP("plant_" .. plant:GetDebugId(), "338 Pollinated", Color3.fromRGB(255, 105, 180))
        end
    end)

    CollectionService:GetInstanceRemovedSignal("Plant"):Connect(function(plant)
        removeESP("plant_" .. plant:GetDebugId())
    end)
end

if getgenv().Config and getgenv().Config["ESP"] and getgenv().Config["ESP"]["Egg"] == true then
    local connections = getconnections(ReplicatedStorage.GameEvents.PetEggService.OnClientEvent)
    local hatchFunc = getupvalue(getupvalue(connections[1].Function, 1), 2)
    local eggPets = getupvalue(hatchFunc, 2)

    for _, egg in ipairs(CollectionService:GetTagged("PetEggServer")) do
        if egg:GetAttribute("OWNER") == LocalPlayer.Name then
            local uuid = egg:GetAttribute("OBJECT_UUID")
            local petName = eggPets[uuid] or "?"
            createESP(uuid, "95a " .. petName, Color3.fromRGB(0, 255, 0))
        end
    end

    CollectionService:GetInstanceAddedSignal("PetEggServer"):Connect(function(egg)
        if egg:GetAttribute("OWNER") == LocalPlayer.Name then
            local uuid = egg:GetAttribute("OBJECT_UUID")
            local petName = eggPets[uuid] or "?"
            createESP(uuid, "95a " .. petName, Color3.fromRGB(0, 255, 0))
        end
    end)

    CollectionService:GetInstanceRemovedSignal("PetEggServer"):Connect(function(egg)
        local uuid = egg:GetAttribute("OBJECT_UUID")
        if uuid then removeESP(uuid) end
    end)
end

RunService.RenderStepped:Connect(function()
    for id, data in pairs(DrawingCache) do
        local instance

        if id:sub(1, 7) == "player_" then
            local plr = Players:FindFirstChild(id:sub(8))
            if plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                instance = plr.Character.HumanoidRootPart
            end
        elseif id:sub(1, 6) == "plant_" then
            for _, plant in ipairs(CollectionService:GetTagged("Plant")) do
                if "plant_" .. plant:GetDebugId() == id then
                    instance = plant
                    break
                end
            end
        else
            for _, egg in ipairs(CollectionService:GetTagged("PetEggServer")) do
                if egg:GetAttribute("OBJECT_UUID") == id then
                    instance = egg
                    break
                end
            end
        end

        if instance then
            local pos, onScreen = Camera:WorldToViewportPoint(instance:GetPivot().Position)
            data.label.Position = Vector2.new(pos.X, pos.Y - 20)
            data.label.Visible = onScreen
        else
            data.label.Visible = false
        end
    end
end)

local player = game.Players.LocalPlayer
local farm = nil
for _, f in ipairs(workspace:WaitForChild("Farm"):GetChildren()) do
    local ok, owner = pcall(function()
        return f:WaitForChild("Important").Data.Owner.Value
    end)
    if ok and owner == player.Name then
        farm = f
        break
    end
end
if not farm then return end

local gui = Instance.new("ScreenGui")
gui.Name = "PlantStatsOverlay"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.new(0, 500, 0, 400)
bg.Position = UDim2.new(0.5, -250, 0.25, 0)
bg.BackgroundColor3 = Color3.new(0,0,0)
bg.BackgroundTransparency = 0.3
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Planted:"
title.TextColor3 = Color3.new(0.2,1,0.5)
title.Font = Enum.Font.Fondamento
title.TextSize = 32
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = bg

local lines = {}

local function updateStats()
    local stats = {}
    for _, plant in ipairs(farm:WaitForChild("Important").Plants_Physical:GetChildren()) do
        stats[plant.Name] = (stats[plant.Name] or 0) + 1
    end
    return stats
end

local function makeGradient(label)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0,255,128)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200,255,255))
    }
    grad.Parent = label
end

local function refresh()
    for _, l in ipairs(lines) do
        if l and l.Parent then l:Destroy() end
    end
    lines = {}
    local stats = updateStats()
    local names = {}
    for name in pairs(stats) do table.insert(names, name) end
    table.sort(names)
    local n = #names

    local maxPerCol = 12
    local colCount = math.ceil(n / maxPerCol)
    local colWidth = 180
    local totalWidth = colCount * colWidth
    local startX = 0.5 - (totalWidth/2)/500 
    for i, name in ipairs(names) do
        local col = math.floor((i-1)/maxPerCol)
        local row = (i-1) % maxPerCol
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, colWidth, 0, 28)
        label.Position = UDim2.new(startX + col*colWidth/500, 0, 0.25, 40 + row*30)
        label.BackgroundTransparency = 1
        label.Text = string.format("%s : %dx", name, stats[name])
        label.TextColor3 = Color3.new(0.2,1,0.5)
        label.Font = Enum.Font.Fondamento
        label.TextSize = 24
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = bg
        makeGradient(label)
        table.insert(lines, label)
    end
end

refresh()
task.spawn(function()
    while true do
        task.wait(2)
        refresh()
    end
end)


local playerGui = player:WaitForChild("PlayerGui")
local nameLabel = playerGui:FindFirstChild("PlayerInfoGui") and playerGui.PlayerInfoGui:FindFirstChildWhichIsA("TextLabel")
if nameLabel and nameLabel.Text == "Strawberry Cat Hub Kaitun" then
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0,255,128)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255))
    }
    grad.Parent = nameLabel
end


local fpsGui = Instance.new("ScreenGui")
fpsGui.Name = "FPSOverlay"
fpsGui.IgnoreGuiInset = true
fpsGui.ResetOnSpawn = false
fpsGui.Parent = player:WaitForChild("PlayerGui")

local fpsBg = Instance.new("Frame")
fpsBg.Size = UDim2.new(0, 180, 0, 40)
fpsBg.Position = UDim2.new(0.5, -90, 0, 10)
fpsBg.BackgroundColor3 = Color3.new(0,0,0)
fpsBg.BackgroundTransparency = 0.3
fpsBg.BorderSizePixel = 0
fpsBg.Parent = fpsGui

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(1, 0, 1, 0)
fpsLabel.Position = UDim2.new(0, 0, 0, 0)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "FPS: ..."
fpsLabel.TextColor3 = Color3.new(1,1,1)
fpsLabel.Font = Enum.Font.Fondamento
fpsLabel.TextSize = 28
fpsLabel.TextXAlignment = Enum.TextXAlignment.Center
fpsLabel.Parent = fpsBg

do
    local last = tick()
    local frames = 0
    task.spawn(function()
        while true do
            frames = frames + 1
            if tick() - last >= 0.5 then
                fpsLabel.Text = string.format("FPS: %d", math.floor(frames/(tick()-last)))
                last = tick()
                frames = 0
            end
            task.wait()
        end
    end)
end


local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
Players.LocalPlayer.OnTeleport:Connect(function(State)
    if State == Enum.TeleportState.Failed or State == Enum.TeleportState.RequestRejected then
        task.wait(5)
        TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
    end
end)
game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
    if child.Name == "ErrorPrompt" then
        local msg = child:FindFirstChild("MessageArea") and child.MessageArea:FindFirstChild("ErrorFrame") and child.MessageArea.ErrorFrame:FindFirstChild("ErrorMessage")
        if msg and msg.Text then
            task.wait(5)
            TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
        end
    end
end)


local vu = game:GetService('VirtualUser')
player.Idled:Connect(function()
    vu:CaptureController()
    vu:ClickButton2(Vector2.new())
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function TradeEgg()
    local args = {"MachineInteract"}
    ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE"):FireServer(unpack(args))
end

local function TradePet(petName)
    local Backpack = player:WaitForChild("Backpack")
    for _, item in ipairs(Backpack:GetChildren()) do
        if item.Name == petName then
            local args = {"TradePet", item}
            ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE"):FireServer(unpack(args))
            break
        end
    end
end

local function TradeMultiplePets(petList)
    local Backpack = player:WaitForChild("Backpack")
    local nameDict = {}
    for _, name in ipairs(petList) do
        nameDict[name] = true
    end
    for _, item in ipairs(Backpack:GetChildren()) do
        if nameDict[item.Name] then
            local args = {"TradePet", item}
            ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE"):FireServer(unpack(args))
            task.wait(0.1)
        end
    end
end

local function TradeAllPets()
    local Backpack = player:WaitForChild("Backpack")
    local dontTradeList = {}
    if getgenv().Config["Pet Dont Trade"] and getgenv().Config["Pet Dont Trade"]["Pet Dont Trade"] then
        for _, pet in ipairs(getgenv().Config["Pet Dont Trade"]["Pet Dont Trade"]) do
            dontTradeList[pet] = true
        end
    end
    for _, item in ipairs(Backpack:GetChildren()) do
        if not dontTradeList[item.Name] then
            local args = {"TradePet", item}
            ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE"):FireServer(unpack(args))
            task.wait(0.1)
        end
    end
end

local function ClaimReward()
    local args = {"ClaimReward"}
    ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE"):FireServer(unpack(args))
end

task.spawn(function()
    while true do
        local config = getgenv().Config["Dino Event"]
        if not config then return end
        if config["Trade Egg"] then
            TradeEgg()
        end
        if config["Pet Trade"] then
            if typeof(config["Pet Trade"]) == "string" then
                TradePet(config["Pet Trade"])
            elseif typeof(config["Pet Trade"]) == "table" then
                TradeMultiplePets(config["Pet Trade"])
            end
        elseif config["Trade All Pet"] then
            TradeAllPets()
        end
        if config["Claim Reward"] then
            ClaimReward()
        end
        task.wait(config["Delay"] or 10)
    end
end)

local function ClaimReward()
    local args = {"ClaimReward"}
    ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE"):FireServer(unpack(args))
end

task.spawn(function()
    while true do
        local config = getgenv().Config["Dino Event"]
        if not config then return end

        if config["Trade Egg"] then
            TradeEgg()
        end

        if config["Pet Trade"] and config["Pet Trade"] ~= "" then
            TradePet(config["Pet Trade"])
        elseif config["Trade All Pet"] then
            TradeAllPets()
        end

        if config["Claim Reward"] then
            ClaimReward()
        end

        task.wait(config["Delay"] or 10)
    end
end)"):gsub("\\x(%x%x)", function(h) return string.char(tonumber(h, 16)) end) 
  local ok = true 
  for i = 1, #check do 
    local b = check:sub(i, i) 
    if not b then ok = false break end 
  end 
  return ok 
end)()
assert(tamper_guard, "Script integrity check failed")
local src=("getgenv().Config = {
    ["Enable Screen Black"] = false,
    ["Screen Black FPS Cap"] = 30,

    ["Buy Seeds"] = {
        ["Enabled"] = true,
        ["Threshold"] = 10,
        ["Item"] = {
            ["Carrot"] = true,
            ["Strawberry"] = true,
            ["Blueberry"] = true,
            ["Orange Tulip"] = true,
            ["Tomato"] = true,
            ["Corn"] = true,
            ["Daffodil"] = true,
            ["Watermelon"] = true,
            ["Pumpkin"] = true,
            ["Apple"] = true,
            ["Bamboo"] = true,
            ["Coconut"] = true,
            ["Cactus"] = true,
            ["Dragon Fruit"] = true,
            ["Mango"] = true,
            ["Grape"] = true,
            ["Mushroom"] = true,
            ["Pepper"] = true,
            ["Cacao"] = true,
            ["Beanstalk"] = true,
            ["Ember Lily"] = true,
            ["Sugar Apple"] = true
        }
    },

    ["Buy Tools"] = {
        ["Enabled"] = true,
        ["Threshold"] = 10000000,
        ["Item"] = {
            ["Watering Can"] = true,
            ["Trowel"] = true,
            ["Recall Wrench"] = false,
            ["Basic Sprinkler"] = false,
            ["Advanced Sprinkler"] = false,
            ["Godly Sprinkler"] = true,
            ["Lightning Rod"] = true,
            ["Master Sprinkler"] = false,
            ["Favorite Tool"] = false,
            ["Haverst Tool"] = false,
            ["Friendship Pot"] = true,
            ["Cleaning Spray"] = true
        }
    },

    ["Buy Eggs"] = {
        ["Enabled"] = true,
        ["Threshold"] = 10000000,
        ["Item"] = {
            ["Common Egg"] = false,
            ["Uncommon Egg"] = false,
            ["Rare Egg"] = false,
            ["Legendary Egg"] = false,
            ["Mythical Egg"] = false,
            ["Bug Egg"] = true
        }
    },

    ["Buy Events"] = {
        ["Enabled"] = true,
        ["Item"] = {
            ["Flower Seed Pack"] = true,
            ["Nectarine"] = true,
            ["Hive Fruit"] = true,
            ["Honey Sprinkler"] = true,
            ["Bee Egg"] = true,
            ["Bee Crate"] = false,
            ["Honey Comb"] = false,
            ["Bee Chair"] = false,
            ["Honey Torch"] = false,
            ["Honey Walkway"] = false,
            ["Pollen Radar"] = false,
            ["Nectarshade Seed"] = false,
            ["Lavender Seed"] = false,
            ["Nectar Staff"] = false
        }
    },

    ["Use Sprinklers"] = {
        ["Enabled"] = true,
        ["Sprinkler"] = {
            ["Basic Sprinkler"] = true,
            ["Advanced Sprinkler"] = true,
            ["Godly Sprinkler"] = true,
            ["Master Sprinkler"] = true
        },
        ["Stack"] = {
            ["Basic Sprinkler"] = false,
            ["Advanced Sprinkler"] = false,
            ["Godly Sprinkler"] = false,
            ["Master Sprinkler"] = false
        }
    },

    ["Use Pets"] = {
        ["Enabled"] = true,
        ["Pet Name"] = {
            "Golden Lab"
        },
        ["Pet Rarity"] = {
            { ["Common"] = true },
            { ["Uncommon"] = true },
            { ["Rare"] = true },
            { ["Legendary"] = true },
            { ["Mythical"] = true },
            { ["Divine"] = true }
        }
    },

    ["Dont Collect On Weather"] = {
        ["Enabled"] = true,
        ["Weather"] = {
            ["RainEvent"] = false,
            ["FrostEvent"] = true,
            ["Thunderstorm"] = true,
            ["BeeSwarm"] = false
        }
    },

    ["Dont Buy Seed"] = {
        ["If Money More Than"] = 1000000,
        ["Seed Name"] = {
            "Strawberry",
            "Blueberry",
            "Tomato",
            "Corn",
            "Apple",
            "Carrot"
        }
    },

    ["Dont Plant Inventory Seed"] = {
        ["Enabled"] = false,
        ["Seed Name"] = {
            "Strawberry",
            "Blueberry",
            "Tomato",
            "Corn",
            "Apple",
            "Carrot",
            "Rose"
        }
    },

    ["Delete Planted Seed"] = {
        ["Enabled"] = true,
        ["Slot"] = {
            { slot = 300, min = 0 },
            { slot = 200, min = 1000000 },
            { slot = 150, min = 10000000 },
            { slot = 100, min = 20000000 },
            { slot = 50, min = 100000000 }
        },
        ["Name Seed Delete"] = {
            "Strawberry",
            "Blueberry",
            "Tomato",
            "Corn",
            "Apple",
            "Rose",
            "Foxglove",
            "Orange Tulip"
        },
        ["Auto Rejoin"] = {
            ["Enabled"] = true,
            ["Delay"] = 5
        }
    },

    ["ESP"] = {
        ["Egg"] = true,
        ["Player"] = true,
        ["Pollinated"] = true
    }
}

if getgenv().Config and getgenv().Config["Enable Screen Black"] == true then
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui")

        local old = playerGui:FindFirstChild("TrueFullBlackScreen")
        if old then old:Destroy() end

        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "TrueFullBlackScreen"
        screenGui.ResetOnSpawn = false
        screenGui.IgnoreGuiInset = true
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screenGui.DisplayOrder = 999999
        screenGui.Parent = playerGui

        local fullBlack = Instance.new("Frame")
        fullBlack.Size = UDim2.new(1, 0, 1, 0)
        fullBlack.Position = UDim2.new(0, 0, 0, 0)
        fullBlack.BackgroundColor3 = Color3.new(0, 0, 0)
        fullBlack.BackgroundTransparency = 0
        fullBlack.BorderSizePixel = 0
        fullBlack.ZIndex = 999999
        fullBlack.Parent = screenGui

        if setfpscap and typeof(getgenv().Config["Screen Black FPS Cap"]) == "number" then
            setfpscap(getgenv().Config["Screen Black FPS Cap"])
        end
    end)
end

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local coinsStat = nil
repeat wait()
    coinsStat = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Sheckles")
until coinsStat

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerInfoGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 1000000

local image = Instance.new("ImageLabel")
image.Size = UDim2.new(0, 50, 0, 50)
image.Position = UDim2.new(0.5, -20, 0, -5)
image.BackgroundTransparency = 1
image.Image = "rbxassetid://78163761481918"

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = image
image.Parent = screenGui

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(0, 400, 0, 50)
nameLabel.Position = UDim2.new(0.5, -200, 0, 60)
nameLabel.Text = "Strawberry Cat Hub Kaitun"
nameLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
nameLabel.BackgroundTransparency = 1
nameLabel.TextScaled = true
nameLabel.Font = Enum.Font.GothamBlack
nameLabel.Parent = screenGui

local timeLabel = Instance.new("TextLabel")
timeLabel.Size = UDim2.new(0, 300, 0, 30)
timeLabel.Position = UDim2.new(0.5, -150, 0, 115)
timeLabel.Text = "Time: 00h00m00s"
timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timeLabel.BackgroundTransparency = 1
timeLabel.Font = Enum.Font.GothamMedium
timeLabel.TextSize = 20
timeLabel.TextXAlignment = Enum.TextXAlignment.Center
timeLabel.Parent = screenGui

local coinsLabel = Instance.new("TextLabel")
coinsLabel.Size = UDim2.new(0, 500, 0, 30)
coinsLabel.Position = UDim2.new(0.5, -250, 0, 150)
coinsLabel.Text = ""
coinsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Font = Enum.Font.GothamMedium
coinsLabel.TextSize = 22
coinsLabel.TextXAlignment = Enum.TextXAlignment.Center
coinsLabel.Parent = screenGui

task.delay(6, function()
    screenGui.Parent = playerGui
end)

local seconds = 0
spawn(function()
    while wait(1) do
        seconds += 1
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        local s = seconds % 60
        timeLabel.Text = string.format("Time: %02dh%02dm%02ds", h, m, s)
    end
end)

spawn(function()
    while wait(0.5) do
        local coins = coinsStat.Value
        local formattedCoins = tostring(coins):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        coinsLabel.Text = "Coins:" .. formattedCoins
    end
end)


repeat wait() until game:IsLoaded()

if getgenv().kaitun and getgenv().kaitun.loaded then return end

local TaskManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/alienschub/alienhub/refs/heads/main/TaskManagerV3.luau"))()

local manager = TaskManager.new()
manager:register(true, "BalancerPlant", "high")
manager:register(false, "GivePollinateFruit", 80)
manager:register(false, "AutoPlaceEgg", 75)
manager:register(false, "DestroyPlant", 74)
manager:register(false, "PlaceSprinkler", 73)
manager:register(false, "AutoPlanting", 72)
manager:register(false, "OpenSeedPack", 71)
manager:register(false, "FeedPet", 69)
manager:register(false, "AutoSelling", 68)
manager:register(false, "AutoHarvesting", 65)


local VirtualUser = game:GetService('VirtualUser')
game:GetService('Players').LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)




local Player = game:GetService("Players").LocalPlayer
local Players = game:GetService("Players")
local Humanoid = Player.Character:WaitForChild("Humanoid")





local PetInfo = require(game:GetService("ReplicatedStorage"):WaitForChild("Data"):WaitForChild("PetRegistry"):WaitForChild("PetList"))

local config = getgenv().Config
local cachedPlayerData = nil
local IS_LOADED = false

local settings = {
    ["game"] = {
        ["npcs"] = {
            Eloise = Workspace.NPCS:FindFirstChild("Eloise") and Workspace.NPCS.Eloise:FindFirstChild("HumanoidRootPart") and Workspace.NPCS.Eloise.HumanoidRootPart.Position or nil,
            Raphael = Workspace.NPCS:FindFirstChild("Raphael") and Workspace.NPCS.Raphael:FindFirstChild("HumanoidRootPart") and Workspace.NPCS.Raphael.HumanoidRootPart.Position or nil,
            Sam = Workspace.NPCS:FindFirstChild("Sam") and Workspace.NPCS.Sam:FindFirstChild("HumanoidRootPart") and Workspace.NPCS.Sam.HumanoidRootPart.Position or nil,
            Steven = Workspace.NPCS:FindFirstChild("Steven") and Workspace.NPCS.Steven:FindFirstChild("HumanoidRootPart") and Workspace.NPCS.Steven.HumanoidRootPart.Position or nil,
        },
        ["seeds"] = {
            ["normal"] = {
                "Carrot", "Strawberry",
                "Blueberry", "Orange Tulip",
                "Tomato", "Corn",
                "Daffodil", "Watermelon", "Pumpkin", "Apple", "Bamboo",
                "Coconut", "Cactus", "Dragon Fruit", "Mango",
                "Grape", "Mushroom", "Pepper", "Cacao",
                "Beanstalk", "Ember Lily", "Sugar Apple"
            },
            ["event"] = {
                "Flower Seed Pack", "Nectarine", "Hive Fruit", "Pollen Radar"
            }
        },
        ["tools"] = {
            ["normal"] = {
                "Watering Can", "Trowel", "Recall Wrench", "Basic Sprinkler", "Advanced Sprinkler", "Godly Sprinkler", "Lightning Rod", "Master Sprinkler", "Favorite Tool", "Recall Wrench", "Haverst Tool", "Friendship Pot", "Cleaning Spray"
            },
            ["event"] = {
                "Honey Sprinkler"
            }
        },
        ["eggs"] = {
            ["normal"] = {
                "Common Egg", "Uncommon Egg", "Rare Egg", "Legendary Egg", "Mythical Egg", "Bug Egg"
            },
            ["event"] = {
                "Bee Egg"
            }
        },
        ["cosmetic"] = {
            ["normal"] = {},
            ["event"] = {
                "Honey Crate", "Honey Comb", "Bee Chair", "Honey Torch", "Honey Walkway", "Nectarshade Seed", "Lavender Seed", "Nectar Staff"
            }
        },
        ["mutations"] = {
            "Gold", "Rainbow", "Shocked", "Wet", "Frozen"
        }
    },
    ["player"] = {
        ["Sheckles"] = nil,
        ["Farm"] = nil,
        ["Place Egg"] = {},
        ["Favorite Fruit"] = {},
        ["Trigger"] = {
            isBuySeeds = false,
            isBuyTools = false,
            isBuyEggs = false
        },
        isSelling = false
    }
}





local function teleport(position)
    local Char = Player.Character
    if Char and Char:FindFirstChild("HumanoidRootPart") then
        local adjustedPos = position + Vector3.new(0, 0.5, 0)
        Char.HumanoidRootPart.CFrame = CFrame.new(adjustedPos)
    end
end

local function getFarm()
    for _, farm in ipairs(workspace:WaitForChild("Farm"):GetChildren()) do
        local success, owner = pcall(function()
            return farm:WaitForChild("Important").Data.Owner.Value
        end)
        if success and owner == Player.Name then
            return farm
        end
    end
    return nil
end

local function collectInventory()
    local all = {}
    for _, container in ipairs({Player.Backpack, Player.Character}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    table.insert(all, tool)
                end
            end
        end
    end
    return all
end

local function searchInventorySeed(item)
    local pattern = "%[x%d+%]$"
    local itemName = item:lower()
    for _, tool in ipairs(collectInventory()) do
        local name = tool.Name:lower()
        if name:find("^" .. itemName) and name:find(pattern) then
            return tool
        end
    end
end

local function removeFirstFruitByName(fruitName)
    local farm = getFarm()

    local plants = farm:WaitForChild("Important"):FindFirstChild("Plants_Physical")
    if plants then
        for _, plant in ipairs(plants:GetChildren()) do
            if plant.Name == fruitName then
                local fruitPart = plant:FindFirstChildWhichIsA("BasePart")
                if fruitPart then
                    game.ReplicatedStorage.GameEvents.Remove_Item:FireServer(fruitPart)
                    return true
                end
            end
        end
    end
    return false
end

local function isHungry(hunger, petType, hungerThreshold)
    hungerThreshold = hungerThreshold or 0.50 
    
    local maxHunger = PetInfo[petType].DefaultHunger

    if not hunger or not maxHunger then
        return false 
    end

    return (hunger / maxHunger) < hungerThreshold
end

local function isPetEquipped(tbl, uuid)
    for _, v in pairs(tbl) do
        if v == uuid then
            return true
        end
    end
    return false
end

local function rarityAllowed(rarityList, rarity)
    for _, r in ipairs(rarityList) do
        for k,v in pairs(r) do
            if k == rarity and v == true then return true end
        end
    end
    return false
end

local function petNameInList(petNameList, petName)
    for _, v in ipairs(petNameList or {}) do
        if v == petName then return true end
    end
    return false
end

local function filterByConfig(category, subcategory)
    local list = settings.game[category]
    local configKey = "Buy " .. category:sub(1,1):upper() .. category:sub(2)
    local configItems = config[configKey] and config[configKey].Item
    if not configItems or type(list) ~= "table" then return end

    local newList = {}
    for _, item in ipairs(list[subcategory]) do
        if configItems[item] then
            newList[#newList+1] = item
        end
    end
    list[subcategory] = newList
end


local function filterEventItems()
    local eventConfig = config["Buy Events"] and config["Buy Events"]["Item"]
    if not eventConfig then return end  

    for category, data in pairs(settings.game) do
        
        if type(data) == "table" and type(data["event"]) == "table" then
            local newList = {}
            for _, item in ipairs(data["event"]) do
                if eventConfig[item] == true then  
                    table.insert(newList, item)  
                end
            end
            settings.game[category]["event"] = newList  
        end
    end
end

local function ApplyLowGraphicsMode()
    local Players = game:GetService("Players")
    local Lighting = game:GetService("Lighting")
    local Workspace = game:GetService("Workspace")
    local Terrain = Workspace:FindFirstChildOfClass("Terrain")
    local Player = Players.LocalPlayer

    
    local function getMyFarm()
        for _, farm in ipairs(Workspace:WaitForChild("Farm"):GetChildren()) do
            local success, owner = pcall(function()
                return farm:WaitForChild("Important").Data.Owner.Value
            end)
            if success and owner == Player.Name then
                return farm
            end
        end
        return nil
    end

    
    local function destroyOtherFarms()
        local myFarm = getMyFarm()
        for _, farm in ipairs(Workspace:WaitForChild("Farm"):GetChildren()) do
            if farm ~= myFarm then
                farm:Destroy()
            end
        end
    end

    
    pcall(function()
        sethiddenproperty(Lighting, "Technology", Enum.Technology.Compatibility)
    end)
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 1e10
    Lighting.Brightness = 0
    Lighting.ClockTime = 14
    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("BloomEffect") or v:IsA("ColorCorrectionEffect") then
            v:Destroy()
        end
    end

    
    if Terrain then
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0
        Terrain.WaterTransparency = 1
    end

    
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
            obj.CastShadow = false
        elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceGui") then
            obj:Destroy()
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
            obj:Destroy()
        elseif obj:IsA("Sound") then
            obj.Volume = 0
        end
    end

    
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            for _, item in ipairs(p.Character:GetChildren()) do
                if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("CharacterMesh") then
                    item:Destroy()
                end
            end
        end
    end

    
    local cam = Workspace:FindFirstChildOfClass("Camera")
    if cam then
        cam.FieldOfView = 50
    end

    
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level02
        settings().Rendering.EagerBulkExecution = false
        game:GetService("UserSettings"):GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)

    
    local playerGui = Player:WaitForChild("PlayerGui")
    for _, gui in ipairs(playerGui:GetChildren()) do
        if not gui:IsA("ScreenGui") then
            gui:Destroy()
        end
    end

    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function(char)
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("CharacterMesh") then
                    item:Destroy()
                end
            end
        end)

        
        task.delay(2, function()
            for _, farm in ipairs(Workspace:WaitForChild("Farm"):GetChildren()) do
                local success, owner = pcall(function()
                    return farm:WaitForChild("Important").Data.Owner.Value
                end)
                if success and owner ~= Player.Name then
                    farm:Destroy()
                end
            end
        end)
    end)

    
    task.spawn(destroyOtherFarms)
end

local function optimizeMyFarm()
    local farm = settings["player"]["Farm"]

    
    for _, obj in ipairs(farm:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CanCollide = false
            obj.CastShadow = false
            obj.Reflectance = 0
            obj.Material = Enum.Material.SmoothPlastic
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
            obj:Destroy()
        elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceGui") then
            obj:Destroy()
        elseif obj:IsA("Sound") then
            obj.Volume = 0
        end
    end

    
    farm.DescendantAdded:Connect(function(obj)
        task.defer(function()
            if obj:IsA("BasePart") then
                obj.CanCollide = false
                obj.CastShadow = false
                obj.Reflectance = 0
                obj.Material = Enum.Material.SmoothPlastic
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
                obj:Destroy()
            elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceGui") then
                obj:Destroy()
            elseif obj:IsA("Sound") then
                obj.Volume = 0
            end
        end)
    end)
end




getgenv().kaitun = {loaded = true}

task.delay(5, function()
    ApplyLowGraphicsMode()
    optimizeMyFarm()
    IS_LOADED = true
end)

task.spawn(function()
    while task.wait(1) do
        settings['player']["Sheckles"] = Player:WaitForChild("leaderstats").Sheckles.Value
        settings["player"]["Farm"] = getFarm()
    end
end)


filterByConfig("seeds", "normal")
filterByConfig("eggs", "normal")
filterByConfig("tools", "normal")
filterEventItems()

repeat
    task.wait()
until(typeof(settings["player"]["Farm"]) == "Instance" and settings["player"]["Farm"].GetDescendants)

repeat
    task.wait()
until(typeof(settings["player"]["Sheckles"]) == "number")

for _, obj in ipairs(settings["player"]["Farm"]:GetDescendants()) do
    if obj:IsA("BasePart") then
        obj.CanCollide = false
    end
end

local base = settings["player"]["Farm"]:WaitForChild("Important").Plant_Locations.Can_Plant.Position
local points = {}


for i = -2, 2 do
    table.insert(points, {
        Used = false,
        Position = Vector3.new(base.X + (i * 4), base.Y, base.Z - 15)
    })
end


for i = -1, 1 do
    table.insert(points, {
        Used = false,
        Position = Vector3.new(base.X + (i * 4), base.Y, base.Z - 19)
    })
end

settings.player["Place Egg"] = points


task.spawn(function()
    local DataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
    if typeof(DataService.GetData) == "function" then
        local oldGetData = DataService.GetData

        DataService.GetData = function(self, ...)
            local data = oldGetData(self, ...)
            cachedPlayerData = data
            return data
        end
    else
        warn("DataService.GetData bukan fungsi atau belum tersedia.")
    end
end)


task.spawn(function()
    while task.wait(1) do
        local success, err = pcall(function()
            if not IS_LOADED then return end
            if not settings["player"]["Trigger"].isBuySeeds then return end

            local data = cachedPlayerData
            if not data or not data.SeedStock or not data.SeedStock.Stocks then return end

            local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):FindFirstChild("BuySeedStock")

            for _, itemName in ipairs(settings.game.seeds.normal) do
                local stockData = data.SeedStock.Stocks[itemName]
                if stockData and stockData.Stock > 0 then
                    for _ = 1, stockData.Stock do
                        remote:FireServer(itemName)
                        task.wait()
                    end
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Buy Seeds]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            if not IS_LOADED then return end
            if not settings["player"]["Trigger"].isBuyTools then return end

            local data = cachedPlayerData
            if not data or not data.GearStock or not data.GearStock.Stocks then return end

            local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):FindFirstChild("BuyGearStock")

            for _, itemName in ipairs(settings.game.tools.normal) do
                local stockData = data.GearStock.Stocks[itemName]
                if stockData and stockData.Stock > 0 then
                    for _ = 1, stockData.Stock do
                        remote:FireServer(itemName)
                        task.wait()
                    end
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Buy Tools]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            if not IS_LOADED then return end
            if not settings["player"]["Trigger"].isBuyEggs then return end

            local data = cachedPlayerData
            if not data or not data.PetEggStock or not data.PetEggStock.Stocks then return end

            local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("BuyPetEgg")

            for index, eggData in pairs(data.PetEggStock.Stocks) do
                if eggData and eggData.Stock > 0 then
                    for _, name in ipairs(settings.game.eggs.normal) do
                        if eggData.EggName == name then
                            remote:FireServer(index)
                            break
                        end
                    end
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Buy Eggs]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            if not IS_LOADED then return end
            if not config["Buy Events"]["Enabled"] then return end

            local data = cachedPlayerData
            if not data or not data.EventShopStock or not data.EventShopStock.Stocks then return end

            local remote = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):FindFirstChild("BuyEventShopStock")

            local items = {}
            for _, v in ipairs(settings.game.seeds.event) do table.insert(items, v) end
            for _, v in ipairs(settings.game.tools.event) do table.insert(items, v) end
            for _, v in ipairs(settings.game.eggs.event) do table.insert(items, v) end
            for _, v in ipairs(settings.game.cosmetic.event) do table.insert(items, v) end

            for _, itemName in ipairs(items) do
                local stockData = data.EventShopStock.Stocks[itemName]
                if stockData and stockData.Stock > 0 then
                    for _ = 1, stockData.Stock do
                        remote:FireServer(itemName)
                        task.wait()
                    end
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Buy Event]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do 
        local success, err = pcall(function()
            if not IS_LOADED then return end

            local farm = settings["player"]["Farm"]
            if not farm then return end

            for _, egg in ipairs(farm:WaitForChild("Important").Objects_Physical:GetChildren()) do
                if egg.Name ~= "PetEgg" then continue end
                local time = egg:GetAttribute("TimeToHatch")
                if time == 0 then
                    local args = {"HatchPet", egg}
                    game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("PetEggService"):FireServer(unpack(args))
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Hatch Eggs]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do 
        local success, err = pcall(function()
            if not IS_LOADED then return end

            local sheckles = settings["player"]["Sheckles"]
            local dontBuyThreshold = config["Dont Buy Seed"]["If Money More Than"]

            
            if sheckles > dontBuyThreshold then
                for name, _ in pairs(config["Buy Seeds"]["Item"]) do
                    for _, dont in ipairs(config["Dont Buy Seed"]["Seed Name"]) do
                        if name == dont then
                            config["Buy Seeds"]["Item"][name] = false
                        end
                    end
                end
            else
                
                for name, _ in pairs(config["Buy Seeds"]["Item"]) do
                    for _, dont in ipairs(config["Dont Buy Seed"]["Seed Name"]) do
                        if name == dont then
                            config["Buy Seeds"]["Item"][name] = true
                        end
                    end
                end
            end

            filterByConfig("seeds", "normal")

            
            if sheckles > config["Buy Seeds"]["Threshold"] then
                settings["player"]["Trigger"].isBuySeeds = config["Buy Seeds"]["Enabled"]
            else
                settings["player"]["Trigger"].isBuySeeds = false
            end

            
            if sheckles > config["Buy Tools"]["Threshold"] then
                settings["player"]["Trigger"].isBuyTools = config["Buy Tools"]["Enabled"]
            else
                settings["player"]["Trigger"].isBuyTools = false
            end

            
            if sheckles > config["Buy Eggs"]["Threshold"] then
                settings["player"]["Trigger"].isBuyEggs = config["Buy Eggs"]["Enabled"]
            else
                settings["player"]["Trigger"].isBuyEggs = false
            end
        end)
        if not success then
            warn("[Task Error: Watch Sheckles]", err)
        end
    end
end)



task.spawn(function()
    while task.wait(1) do
        local success, err = pcall(function()
            if not IS_LOADED then return end

            local farm = settings["player"]["Farm"]

            local inventories = collectInventory()
            local pollinated = {}
            local seeds = {}
            local fruits = {}
            local eggs = {}
            local seedPack = {}
            local sprinklers = {}

            if #settings.player["Favorite Fruit"] > 100 then
                table.remove(settings.player["Favorite Fruit"], 1)
            end

            for _, tool in ipairs(inventories) do
                local itemName = tool:GetAttribute("ItemName")
                local itemType = tool:GetAttribute("ItemType")
                local uuid = tool:GetAttribute("ITEM_UUID")
                local isPollinated = tool:GetAttribute("Pollinated")
                local isFavorite = tool:GetAttribute("Favorite")

                if itemType == "Seed" then
                    if not (config["Dont Plant Inventory Seed"]["Enabled"] and table.find(config["Dont Plant Inventory Seed"]["Seed Name"], itemName)) then
                        table.insert(seeds, {name = itemName, tool = tool})
                    end

                elseif itemType == "Holdable" then
                    if farm:WaitForChild("Important").Plants_Physical:FindFirstChild(itemName) then
                        table.insert(fruits, itemName)
                    end

                    if isPollinated then
                        if not isFavorite then
                            if not table.find(settings.player["Favorite Fruit"], uuid) then
                                table.insert(settings.player["Favorite Fruit"], uuid)
                                game.ReplicatedStorage.GameEvents.Favorite_Item:FireServer(tool)
                                task.wait(0.05)
                            end
                        end

                        table.insert(pollinated, tool)
                    end

                elseif itemType == "PetEgg" then
                    table.insert(eggs, tool)

                elseif itemType == "Seed Pack" then
                    table.insert(seedPack, tool)

                elseif itemType == "Sprinkler" then
                    table.insert(sprinklers, {name = itemName, tool = tool})
                end
            end


            if #pollinated > 0 then
                local data = cachedPlayerData

                if data.HoneyMachine.TimeLeft == 0 then
                    manager:normal("GivePollinateFruit", function(cachedPlayerData)
                        local data = cachedPlayerData
                        if not data or not data.HoneyMachine then return end

                        for _, tool in ipairs(pollinated) do
                            if data.HoneyMachine.TimeLeft ~= 0 then return end
                            
                            local isFavorite = tool:GetAttribute("Favorite")
                            if isFavorite then
                                game.ReplicatedStorage.GameEvents.Favorite_Item:FireServer(tool)
                                task.wait(0.05)
                            end

                            local currentTool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
                            if currentTool ~= tool then
                                Player.Character.Humanoid:EquipTool(tool)
                                task.wait(0.5)
                            end

                            
                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("HoneyMachineService_RE"):FireServer("MachineInteract")
                            task.wait(0.3)
                            
                        end
                    end, {cachedPlayerData}, function() return true end)
                end
            end

            local function collectSeeds()
                local all = {}
                for _, container in ipairs({Player.Backpack, Player.Character}) do
                    if container then
                        for _, tool in ipairs(container:GetChildren()) do
                            if tool:IsA("Tool") and tool.Name:lower():find("seed") then
                                table.insert(all, tool)
                            end
                        end
                    end
                end
                return all
            end

            local seeds = collectSeeds()
            if #seeds == 0 then

            else
                local plants = farm:WaitForChild("Important").Objects_Physical:GetChildren()
                if #plants < 800 then
                    for _, seed in ipairs(seeds) do

                        if Player.Backpack:FindFirstChild(seed.Name) then
                            Player.Backpack[seed.Name].Parent = Player.Character
                            task.wait(0.01)
                        end
                        Player.Character.Humanoid:EquipTool(seed)
                        task.wait(0.01)
                        local quantity = tonumber(seed.Name:match("%[x(%d+)%]")) or 1
                        for i = 1, quantity do
                            local pos = farm:WaitForChild("Important").Plant_Locations.Can_Plant.Position
                            local offsetX = math.random(-5, 5) / 100
                            local offsetZ = math.random(-5, 5) / 100
                            local plantPos = Vector3.new(pos.X + offsetX, pos.Y, pos.Z + offsetZ)
                            local args = {plantPos, seed.Name:gsub(" Seed.*", "")}
                            local success, err = pcall(function()
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("Plant_RE"):FireServer(unpack(args))
                            end)
                            if not success then
                                warn("[AutoPlant] Plant_RE error:", err)
                            end
                            task.wait(0.01)
                        end
                    end
                else
                end
            end

            if #fruits > 100 then
                settings.player.isSelling = true

                manager:normal("AutoSelling", function(settings)
                    
                    teleport(settings.game.npcs.Steven)
                    task.wait(1)

                    game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("Sell_Inventory"):FireServer()
                    task.wait(1)

                    settings.player.isSelling = false
                end, {settings}, function() return true end)
            end

            if #eggs > 0 then
                local eggPlaced = 0

                
                for _, entry in ipairs(settings.player["Place Egg"]) do
                    entry.Used = false
                end

                
                for _, egg in ipairs(farm:WaitForChild("Important").Objects_Physical:GetChildren()) do
                    if egg.Name == "PetEgg" then
                        eggPlaced = eggPlaced + 1

                        
                        local pos = egg.PetEgg.Position
                        for _, entry in ipairs(settings.player["Place Egg"]) do
                            if not entry.Used then
                                local diffX = math.abs(entry.Position.X - pos.X)
                                local diffZ = math.abs(entry.Position.Z - pos.Z)
                                if diffX <= 1 and diffZ <= 1 then
                                    entry.Used = true
                                    break
                                end
                            end
                        end
                    end
                end

                
                local data = cachedPlayerData

                local maxEggs = data.PetsData.MutableStats.MaxEggsInFarm
                if eggPlaced < maxEggs then
                    
                    manager:normal("AutoPlaceEgg", function()
                        for _, egg in ipairs(eggs) do
                            local currentTool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
                            if currentTool ~= egg then
                                Player.Character.Humanoid:EquipTool(egg)
                                task.wait(2)
                            end

                            for i = 1, egg:GetAttribute("LocalUses") do
                                
                                local targetPos = nil
                                for _, entry in ipairs(settings.player["Place Egg"]) do
                                    if not entry.Used then
                                        targetPos = entry
                                        break
                                    end
                                end

                                if not targetPos then return end

                                
                                local args = {
                                    [1] = "CreateEgg",
                                    [2] = targetPos.Position
                                }
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("PetEggService"):FireServer(unpack(args))

                                
                                targetPos.Used = true

                                eggPlaced = eggPlaced + 1
                                task.wait(1)

                                if eggPlaced >= maxEggs then return end
                            end
                        end
                    end, {}, function() return true end)
                end
            end

            if #seedPack > 0 then
                manager:normal("OpenSeedPack", function()
                    for _, pack in ipairs(seedPack) do
                        local currentTool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
                        if currentTool ~= pack then
                            Player.Character.Humanoid:EquipTool(pack)
                            task.wait(2)
                        end

                        for i = 1, pack:GetAttribute("Uses") do
                            pack:Activate()
                            task.wait(1)
                        end
                    end
                end, {}, function() return true end)
            end

            if #sprinklers > 0 and config["Use Sprinklers"]["Enabled"] then
                local point = farm:WaitForChild("Important").Plant_Locations.Can_Plant
                local uses = {}
                local planted = {} 

                
                for _, obj in ipairs(farm:WaitForChild("Important").Objects_Physical:GetChildren()) do
                    if config["Use Sprinklers"]["Sprinkler"][obj.Name] and obj:FindFirstChild("Root") then
                        local dist = (obj.Root.Position - point.Position).Magnitude
                        if dist <= 2 then
                            planted[obj.Name] = true
                        end
                    end
                end

                
                for _, sprinkler in ipairs(sprinklers) do
                    local name = sprinkler.name
                    if config["Use Sprinklers"]["Sprinkler"][name] and not planted[name] then
                        uses[name] = sprinkler
                    end
                end

                
                local stack = config["Use Sprinklers"]["Stack"]
                local requireStack = false
                local allStackReady = true

                for name, state in pairs(stack) do
                    if state then
                        requireStack = true
                        if not (uses[name] or planted[name]) then
                            allStackReady = false
                            break
                        end
                    end
                end

                if not requireStack or allStackReady then
                    manager:normal("PlaceSprinkler", function(config)
                        for name, toolData in pairs(uses) do
                            if config["Use Sprinklers"]["Sprinkler"][name] then
                                local currentTool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
                                if currentTool ~= toolData.tool then
                                    Player.Character.Humanoid:EquipTool(toolData.tool)
                                    task.wait(2)
                                end

                                local cf = point.CFrame * CFrame.new(0, 0.5, 0)
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("SprinklerService"):FireServer("Create", cf)
                                task.wait(1)
                            end
                        end
                    end, {config}, function() return true end)
                end
            end
        end)
        if not success then
            warn("[Task Error: Check Inventory]", err)
        end
    end
end)








task.spawn(function()
    while task.wait(1) do
        local success, err = pcall(function()
            if not IS_LOADED then return end

            local skip = false
            if config["Dont Collect On Weather"]["Enabled"] then
                local workspaceAttr = workspace:GetAttributes()
                for weather, active in pairs(config["Dont Collect On Weather"]["Weather"]) do
                    if workspaceAttr[weather] and active then
                        skip = true
                        break
                    end
                end
            end

            if skip then return end

            local isHarvesting = false

            local farm = settings["player"]["Farm"]

            for _, plant in ipairs(farm:WaitForChild("Important").Plants_Physical:GetChildren()) do
                if isHarvesting then break end
                
                for _, descendant in ipairs(plant:GetDescendants()) do
                    if descendant:IsA("ProximityPrompt") and descendant.Enabled then
                        isHarvesting = true
                        break
                    end
                end
            end

            if isHarvesting then
                manager:normal("AutoHarvesting", function(settings)
                    for _, plant in ipairs(settings["player"]["Farm"]:WaitForChild("Important").Plants_Physical:GetChildren()) do
                        for _, descendant in ipairs(plant:GetDescendants()) do
                            if settings.player.isSelling then return end

                            if descendant:IsA("ProximityPrompt") and descendant.Enabled then
                                local part = descendant.Parent
                                if part and part:IsA("BasePart") then
                                    teleport(part.Position)
                                    task.wait(0.05)
                                    fireproximityprompt(descendant)
                                    task.wait()
                                end
                            end
                        end
                    end

                    settings.player.isSelling = true
                end, {settings}, function() return true end)
            end
        end)
        if not success then
            warn("[Task Error: Auto Harvesting]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(1) do
        local success, err = pcall(function()
            if not IS_LOADED then return end
            if not settings.player.isSelling then return end

            manager:normal("AutoSelling", function(settings)
                
                teleport(settings.game.npcs.Steven)
                task.wait(0.5)

                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("Sell_Inventory"):FireServer()
                task.wait(2)

                settings.player.isSelling = false
            end, {settings}, function() return true end)
        end)
        if not success then
            warn("[Task Error: Auto Selling]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            if not IS_LOADED then return end

            local farm = settings["player"]["Farm"]
            local plants = farm and farm:WaitForChild("Important").Plants_Physical:GetChildren() or {}

            local isPlanted = false

            for _, name in ipairs(config["Delete Planted Seed"]["Name Seed Delete"]) do
                if farm:WaitForChild("Important").Plants_Physical:FindFirstChild(name) then
                    isPlanted = true
                    break
                end
            end

            if isPlanted then
                local shekles = settings["player"]["Sheckles"]
                local selectedSlot = nil
                local maxMin = -math.huge

                for _, slot in ipairs(config["Delete Planted Seed"]["Slot"]) do
                    if shekles >= slot.min and slot.min > maxMin then
                        selectedSlot = slot.slot
                        maxMin = slot.min
                    end
                end

                local overCount = #plants - selectedSlot

                if overCount > 0 then
                    manager:normal("DestroyPlant", function(overCount)
                        local shovel = Player.Backpack:FindFirstChild("Shovel [Destroy Plants]") or Player.Character:FindFirstChild("Shovel [Destroy Plants]")
                        if shovel then Player.Character.Humanoid:EquipTool(shovel) task.wait(1) end

                        for _, name in ipairs(config["Delete Planted Seed"]["Name Seed Delete"]) do
                            if overCount < 1 then break end
                            for i = 1, overCount do 
                                local isDeleted = removeFirstFruitByName(name)
                                if not isDeleted then break end
                                task.wait(0.1)
                                overCount = overCount - 1
                            end
                        end
                    end, {overCount}, function() return true end)
                end
            end
        end)
        if not success then
            warn("[Task Error: Auto Remove Plants]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            if not IS_LOADED then return end

            local farm = settings["player"]["Farm"]
            local plants = farm and farm:WaitForChild("Important").Plants_Physical:GetChildren() or {}

            if #plants > 750 then
                manager:priority("BalancerPlant", function(settings)
                    
                    for _, plant in ipairs(farm:WaitForChild("Important").Plants_Physical:GetChildren()) do
                        for _, descendant in ipairs(plant:GetDescendants()) do
                            if settings.player.isSelling then return end

                            if descendant:IsA("ProximityPrompt") and descendant.Enabled then
                                local part = descendant.Parent
                                if part and part:IsA("BasePart") then
                                    teleport(part.Position)
                                    task.wait(0.05)
                                    fireproximityprompt(descendant)
                                    task.wait()
                                end
                            end
                        end
                    end

                    
                    teleport(settings.game.npcs.Steven)
                    task.wait(1)

                    game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("Sell_Inventory"):FireServer()
                    task.wait(1)

                    
                    local plants = settings["player"]["Farm"].Important.Plants_Physical:GetChildren() or {}

                    if #plants > 750 then
                        local plantGroups = {}
                        for _, plant in ipairs(plants) do
                            local name = plant.Name
                            plantGroups[name] = (plantGroups[name] or 0) + 1
                        end

                        local shovel = Player.Backpack:FindFirstChild("Shovel [Destroy Plants]") or Player.Character:FindFirstChild("Shovel [Destroy Plants]")
                        if shovel then Player.Character.Humanoid:EquipTool(shovel) task.wait(1) end

                        for _, name in ipairs(config["Delete Planted Seed"]["Name Seed Delete"]) do
                            local maxDelete = plantGroups[name] or 0

                            for i = 1, maxDelete do
                                local isDeleted = removeFirstFruitByName(name)
                                if not isDeleted then break end
                                task.wait(0.1)
                            end
                        end
                    end
                end, {settings}, function() return true end)
            end
        end)
        if not success then
            warn("[Task Error: Balancer Plant]", err)
        end
    end
end)


task.spawn(function()
    while task.wait(5) do
        local success, err = pcall(function()
            if not IS_LOADED then return end
            if not config["Use Pets"]["Enabled"] then return end

            local data = cachedPlayerData
            if not data or not data.PetsData or not data.PetsData.PetInventory or not data.PetsData.PetInventory.Data then return end
            if next(data.PetsData.PetInventory.Data) == nil then return end

            local equipped = data.PetsData.EquippedPets
            local usePets = config["Use Pets"]

            local placed = #equipped
            local hungries = {}
            for uuid, pet in pairs(data.PetsData.PetInventory.Data) do
                local isEquipped = isPetEquipped(equipped, uuid)
                local allowedByName = petNameInList(usePets["Pet Name"], pet.PetType)
                local allowedByRarity = rarityAllowed(usePets["Pet Rarity"], PetInfo[pet.PetType] and PetInfo[pet.PetType].Rarity)
                local allowed = allowedByName or allowedByRarity
                local maxEquipped = data.PetsData.MutableStats.MaxEquippedPets

                if isEquipped and not allowed then
                    game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("UnequipPet", uuid)
                    task.wait(0.05)
                    placed = placed - 1
                elseif not isEquipped and allowed and placed < maxEquipped then
                    game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("EquipPet", uuid)
                    task.wait(0.05)
                    placed = placed + 1
                end

                local hungry = isHungry(pet.PetData.Hunger, pet.PetType)

                if hungry then table.insert(hungries, uuid) end
            end

            if #hungries > 0 then
                manager:normal("FeedPet", function(farm, collectInventory, isHungry, cachedPlayerData)
                    local data = cachedPlayerData
                    if not data then return end

                    local inventories = collectInventory()
                    local fruits = {}
                    for _, tool in ipairs(inventories) do
                        local itemName = tool:GetAttribute("ItemName")
                        local itemType = tool:GetAttribute("ItemType")
                        local isFavorite = tool:GetAttribute("Favorite")

                        if itemType == "Holdable" and not isFavorite then
                            if farm:WaitForChild("Important").Plants_Physical:FindFirstChild(itemName) then
                                table.insert(fruits, tool)
                            end
                        end
                    end

                    if #fruits == 0 then return end

                    for _, pet in ipairs(hungries) do
                        for i = #fruits, 1, -1 do
                            Player.Character.Humanoid:EquipTool(fruits[i])
                            task.wait(1)

                            game:GetService("ReplicatedStorage").GameEvents.ActivePetService:FireServer("Feed", pet)
                            task.wait(0.3)

                            table.remove(fruits, i)

                            local hungry = isHungry(data.PetsData.PetInventory.Data[pet]["PetData"].Hunger, data.PetsData.PetInventory.Data[pet]["PetType"])
                            if not hungry then break end
                        end
                    end

                end, {settings["player"]["Farm"], collectInventory, isHungry, cachedPlayerData}, function() return true end)
            end
        end)
        if not success then
            warn("[Task Error: Feed Pet]", err)
        end
    end
end)


if getgenv().Config["Auto Rejoin"]["Enabled"] then
    local function TryRejoin()
        local delayTime = getgenv().Config["Auto Rejoin"]["Delay"] or 5
        task.wait(delayTime)
        TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
    end

    Players.LocalPlayer.OnTeleport:Connect(function(State)
        if State == Enum.TeleportState.Failed or State == Enum.TeleportState.RequestRejected then
            TryRejoin()
        end
    end)

    game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
        if child.Name == "ErrorPrompt" then
            local msg = child:FindFirstChild("MessageArea") and child.MessageArea:FindFirstChild("ErrorFrame") and child.MessageArea.ErrorFrame:FindFirstChild("ErrorMessage")
            if msg and msg.Text then
                TryRejoin()
            end
        end
    end)
end

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

DrawingCache = DrawingCache or {}

local function createESP(id, text, color)
    if DrawingCache[id] then return end
    local label = Drawing.new("Text")
    label.Text = text
    label.Size = 18
    label.Color = color
    label.Center = true
    label.Outline = true
    label.OutlineColor = Color3.new(0, 0, 0)
    label.Visible = true

    DrawingCache[id] = {
        label = label,
        text = text,
        color = color,
    }
end

local function removeESP(id)
    if DrawingCache[id] then
        if DrawingCache[id].label then
            DrawingCache[id].label:Remove()
        end
        DrawingCache[id] = nil
    end
end

if getgenv().Config and getgenv().Config["ESP"] and getgenv().Config["ESP"]["Player"] == true then
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            createESP("player_" .. plr.Name, plr.Name, Color3.fromRGB(255, 255, 0))
        end
    end

    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function()
            task.wait(1)
            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                createESP("player_" .. plr.Name, plr.Name, Color3.fromRGB(255, 255, 0))
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(plr)
        removeESP("player_" .. plr.Name)
    end)
end

if getgenv().Config and getgenv().Config["ESP"] and getgenv().Config["ESP"]["Pollinated"] == true then
    for _, plant in ipairs(CollectionService:GetTagged("Plant")) do
        if plant:GetAttribute("Pollinated") then
            createESP("plant_" .. plant:GetDebugId(), "338 Pollinated", Color3.fromRGB(255, 105, 180))
        end
    end

    CollectionService:GetInstanceAddedSignal("Plant"):Connect(function(plant)
        if plant:GetAttribute("Pollinated") then
            createESP("plant_" .. plant:GetDebugId(), "338 Pollinated", Color3.fromRGB(255, 105, 180))
        end
    end)

    CollectionService:GetInstanceRemovedSignal("Plant"):Connect(function(plant)
        removeESP("plant_" .. plant:GetDebugId())
    end)
end

if getgenv().Config and getgenv().Config["ESP"] and getgenv().Config["ESP"]["Egg"] == true then
    local connections = getconnections(ReplicatedStorage.GameEvents.PetEggService.OnClientEvent)
    local hatchFunc = getupvalue(getupvalue(connections[1].Function, 1), 2)
    local eggPets = getupvalue(hatchFunc, 2)

    for _, egg in ipairs(CollectionService:GetTagged("PetEggServer")) do
        if egg:GetAttribute("OWNER") == LocalPlayer.Name then
            local uuid = egg:GetAttribute("OBJECT_UUID")
            local petName = eggPets[uuid] or "?"
            createESP(uuid, "95a " .. petName, Color3.fromRGB(0, 255, 0))
        end
    end

    CollectionService:GetInstanceAddedSignal("PetEggServer"):Connect(function(egg)
        if egg:GetAttribute("OWNER") == LocalPlayer.Name then
            local uuid = egg:GetAttribute("OBJECT_UUID")
            local petName = eggPets[uuid] or "?"
            createESP(uuid, "95a " .. petName, Color3.fromRGB(0, 255, 0))
        end
    end)

    CollectionService:GetInstanceRemovedSignal("PetEggServer"):Connect(function(egg)
        local uuid = egg:GetAttribute("OBJECT_UUID")
        if uuid then removeESP(uuid) end
    end)
end

RunService.RenderStepped:Connect(function()
    for id, data in pairs(DrawingCache) do
        local instance

        if id:sub(1, 7) == "player_" then
            local plr = Players:FindFirstChild(id:sub(8))
            if plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                instance = plr.Character.HumanoidRootPart
            end
        elseif id:sub(1, 6) == "plant_" then
            for _, plant in ipairs(CollectionService:GetTagged("Plant")) do
                if "plant_" .. plant:GetDebugId() == id then
                    instance = plant
                    break
                end
            end
        else
            for _, egg in ipairs(CollectionService:GetTagged("PetEggServer")) do
                if egg:GetAttribute("OBJECT_UUID") == id then
                    instance = egg
                    break
                end
            end
        end

        if instance then
            local pos, onScreen = Camera:WorldToViewportPoint(instance:GetPivot().Position)
            data.label.Position = Vector2.new(pos.X, pos.Y - 20)
            data.label.Visible = onScreen
        else
            data.label.Visible = false
        end
    end
end)

local player = game.Players.LocalPlayer
local farm = nil
for _, f in ipairs(workspace:WaitForChild("Farm"):GetChildren()) do
    local ok, owner = pcall(function()
        return f:WaitForChild("Important").Data.Owner.Value
    end)
    if ok and owner == player.Name then
        farm = f
        break
    end
end
if not farm then return end

local gui = Instance.new("ScreenGui")
gui.Name = "PlantStatsOverlay"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.new(0, 500, 0, 400)
bg.Position = UDim2.new(0.5, -250, 0.25, 0)
bg.BackgroundColor3 = Color3.new(0,0,0)
bg.BackgroundTransparency = 0.3
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Planted:"
title.TextColor3 = Color3.new(0.2,1,0.5)
title.Font = Enum.Font.Fondamento
title.TextSize = 32
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = bg

local lines = {}

local function updateStats()
    local stats = {}
    for _, plant in ipairs(farm:WaitForChild("Important").Plants_Physical:GetChildren()) do
        stats[plant.Name] = (stats[plant.Name] or 0) + 1
    end
    return stats
end

local function makeGradient(label)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0,255,128)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200,255,255))
    }
    grad.Parent = label
end

local function refresh()
    for _, l in ipairs(lines) do
        if l and l.Parent then l:Destroy() end
    end
    lines = {}
    local stats = updateStats()
    local names = {}
    for name in pairs(stats) do table.insert(names, name) end
    table.sort(names)
    local n = #names

    local maxPerCol = 12
    local colCount = math.ceil(n / maxPerCol)
    local colWidth = 180
    local totalWidth = colCount * colWidth
    local startX = 0.5 - (totalWidth/2)/500 
    for i, name in ipairs(names) do
        local col = math.floor((i-1)/maxPerCol)
        local row = (i-1) % maxPerCol
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, colWidth, 0, 28)
        label.Position = UDim2.new(startX + col*colWidth/500, 0, 0.25, 40 + row*30)
        label.BackgroundTransparency = 1
        label.Text = string.format("%s : %dx", name, stats[name])
        label.TextColor3 = Color3.new(0.2,1,0.5)
        label.Font = Enum.Font.Fondamento
        label.TextSize = 24
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = bg
        makeGradient(label)
        table.insert(lines, label)
    end
end

refresh()
task.spawn(function()
    while true do
        task.wait(2)
        refresh()
    end
end)


local playerGui = player:WaitForChild("PlayerGui")
local nameLabel = playerGui:FindFirstChild("PlayerInfoGui") and playerGui.PlayerInfoGui:FindFirstChildWhichIsA("TextLabel")
if nameLabel and nameLabel.Text == "Strawberry Cat Hub Kaitun" then
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0,255,128)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255))
    }
    grad.Parent = nameLabel
end


local fpsGui = Instance.new("ScreenGui")
fpsGui.Name = "FPSOverlay"
fpsGui.IgnoreGuiInset = true
fpsGui.ResetOnSpawn = false
fpsGui.Parent = player:WaitForChild("PlayerGui")

local fpsBg = Instance.new("Frame")
fpsBg.Size = UDim2.new(0, 180, 0, 40)
fpsBg.Position = UDim2.new(0.5, -90, 0, 10)
fpsBg.BackgroundColor3 = Color3.new(0,0,0)
fpsBg.BackgroundTransparency = 0.3
fpsBg.BorderSizePixel = 0
fpsBg.Parent = fpsGui

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(1, 0, 1, 0)
fpsLabel.Position = UDim2.new(0, 0, 0, 0)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "FPS: ..."
fpsLabel.TextColor3 = Color3.new(1,1,1)
fpsLabel.Font = Enum.Font.Fondamento
fpsLabel.TextSize = 28
fpsLabel.TextXAlignment = Enum.TextXAlignment.Center
fpsLabel.Parent = fpsBg

do
    local last = tick()
    local frames = 0
    task.spawn(function()
        while true do
            frames = frames + 1
            if tick() - last >= 0.5 then
                fpsLabel.Text = string.format("FPS: %d", math.floor(frames/(tick()-last)))
                last = tick()
                frames = 0
            end
            task.wait()
        end
    end)
end


local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
Players.LocalPlayer.OnTeleport:Connect(function(State)
    if State == Enum.TeleportState.Failed or State == Enum.TeleportState.RequestRejected then
        task.wait(5)
        TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
    end
end)
game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
    if child.Name == "ErrorPrompt" then
        local msg = child:FindFirstChild("MessageArea") and child.MessageArea:FindFirstChild("ErrorFrame") and child.MessageArea.ErrorFrame:FindFirstChild("ErrorMessage")
        if msg and msg.Text then
            task.wait(5)
            TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
        end
    end
end)


local vu = game:GetService('VirtualUser')
player.Idled:Connect(function()
    vu:CaptureController()
    vu:ClickButton2(Vector2.new())
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function TradeEgg()
    local args = {"MachineInteract"}
    ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE"):FireServer(unpack(args))
end

local function TradePet(petName)
    local Backpack = player:WaitForChild("Backpack")
    for _, item in ipairs(Backpack:GetChildren()) do
        if item.Name == petName then
            local args = {"TradePet", item}
            ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE"):FireServer(unpack(args))
            break
        end
    end
end

local function TradeMultiplePets(petList)
    local Backpack = player:WaitForChild("Backpack")
    local nameDict = {}
    for _, name in ipairs(petList) do
        nameDict[name] = true
    end
    for _, item in ipairs(Backpack:GetChildren()) do
        if nameDict[item.Name] then
            local args = {"TradePet", item}
            ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE"):FireServer(unpack(args))
            task.wait(0.1)
        end
    end
end

local function TradeAllPets()
    local Backpack = player:WaitForChild("Backpack")
    local dontTradeList = {}
    if getgenv().Config["Pet Dont Trade"] and getgenv().Config["Pet Dont Trade"]["Pet Dont Trade"] then
        for _, pet in ipairs(getgenv().Config["Pet Dont Trade"]["Pet Dont Trade"]) do
            dontTradeList[pet] = true
        end
    end
    for _, item in ipairs(Backpack:GetChildren()) do
        if not dontTradeList[item.Name] then
            local args = {"TradePet", item}
            ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE"):FireServer(unpack(args))
            task.wait(0.1)
        end
    end
end

local function ClaimReward()
    local args = {"ClaimReward"}
    ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE"):FireServer(unpack(args))
end

task.spawn(function()
    while true do
        local config = getgenv().Config["Dino Event"]
        if not config then return end
        if config["Trade Egg"] then
            TradeEgg()
        end
        if config["Pet Trade"] then
            if typeof(config["Pet Trade"]) == "string" then
                TradePet(config["Pet Trade"])
            elseif typeof(config["Pet Trade"]) == "table" then
                TradeMultiplePets(config["Pet Trade"])
            end
        elseif config["Trade All Pet"] then
            TradeAllPets()
        end
        if config["Claim Reward"] then
            ClaimReward()
        end
        task.wait(config["Delay"] or 10)
    end
end)

local function ClaimReward()
    local args = {"ClaimReward"}
    ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DinoMachineService_RE"):FireServer(unpack(args))
end

task.spawn(function()
    while true do
        local config = getgenv().Config["Dino Event"]
        if not config then return end

        if config["Trade Egg"] then
            TradeEgg()
        end

        if config["Pet Trade"] and config["Pet Trade"] ~= "" then
            TradePet(config["Pet Trade"])
        elseif config["Trade All Pet"] then
            TradeAllPets()
        end

        if config["Claim Reward"] then
            ClaimReward()
        end

        task.wait(config["Delay"] or 10)
    end
end)
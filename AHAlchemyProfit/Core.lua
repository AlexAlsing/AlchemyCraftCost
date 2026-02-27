local addonName, AHAP = ...
AHAP = AHAP or {}
_G.AHAlchemyProfit = AHAP

local DEFAULT_RECIPES = {
    {
        name = "Blinding Light Flask",
        output = "Flask of Blinding Light",
        mats = {
            { name = "Mana Thistle", qty = 3 },
            { name = "Fel Lotus", qty = 1 },
            { name = "Netherbloom", qty = 7 },
        },
    },
    {
        name = "Flask of Pure Death",
        output = "Flask of Pure Death",
        mats = {
            { name = "Mana Thistle", qty = 3 },
            { name = "Fel Lotus", qty = 1 },
            { name = "Nightmare Vine", qty = 7 },
        },
    },
    {
        name = "Flask of Fortification",
        output = "Flask of Fortification",
        mats = {
            { name = "Mana Thistle", qty = 3 },
            { name = "Fel Lotus", qty = 1 },
            { name = "Ancient Lichen", qty = 7 },
        },
    },
    {
        name = "Elixir of Major Mageblood",
        output = "Elixir of Major Mageblood",
        mats = {
            { name = "Ancient Lichen", qty = 1 },
            { name = "Netherbloom", qty = 1 },
        },
    },
    {
        name = "Elixir of Major Shadow Power",
        output = "Elixir of Major Shadow Power",
        mats = {
            { name = "Ancient Lichen", qty = 1 },
            { name = "Nightmare Vine", qty = 1 },
        },
    },
    {
        name = "Elixir of Draenic Wisdom",
        output = "Elixir of Draenic Wisdom",
        mats = {
            { name = "Felweed", qty = 1 },
            { name = "Terocone", qty = 1 },
        },
    },
    {
        name = "Elixir of Major Agility",
        output = "Elixir of Major Agility",
        mats = {
            { name = "Terocone", qty = 1 },
            { name = "Felweed", qty = 2 },
        },
    },
}

local DEFAULT_SETTINGS = {
    procRate = 0.20,
    ahCut = 0.05,
    usePresetValues = true,
    useAtlasLootMats = true,
}

local function ShallowCopy(src)
    local t = {}
    for k, v in pairs(src) do
        t[k] = v
    end
    return t
end

local function DeepCopyRecipes(src)
    local out = {}
    for i, recipe in ipairs(src) do
        local cloned = {
            name = recipe.name,
            output = recipe.output,
            enabled = recipe.enabled ~= false,
            mats = {},
        }
        for j, mat in ipairs(recipe.mats) do
            cloned.mats[j] = { name = mat.name, qty = mat.qty }
        end
        out[i] = cloned
    end
    return out
end

local function NormalizeRecipes(recipes)
    for _, recipe in ipairs(recipes) do
        if recipe.enabled == nil then
            recipe.enabled = true
        end
    end
end

function AHAP:RoundCopper(value)
    if not value then
        return 0
    end
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return -math.floor(-value + 0.5)
end

function AHAP:FormatCopper(copper)
    local amount = self:RoundCopper(copper or 0)
    local sign = ""
    if amount < 0 then
        sign = "-"
        amount = math.abs(amount)
    end

    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copperOnly = amount % 100
    return string.format("%s%dg %ds %dc", sign, gold, silver, copperOnly)
end

function AHAP:GetDB()
    return AHAlchemyProfitDB
end

function AHAP:EnsureDB()
    AHAlchemyProfitDB = AHAlchemyProfitDB or {}
    local db = AHAlchemyProfitDB

    db.settings = db.settings or {}
    if db.settings.procRate == nil then db.settings.procRate = DEFAULT_SETTINGS.procRate end
    if db.settings.ahCut == nil then db.settings.ahCut = DEFAULT_SETTINGS.ahCut end
    if db.settings.usePresetValues == nil then db.settings.usePresetValues = DEFAULT_SETTINGS.usePresetValues end
    if db.settings.useAtlasLootMats == nil then db.settings.useAtlasLootMats = DEFAULT_SETTINGS.useAtlasLootMats end

    db.presetValues = db.presetValues or {}
    db.recipes = db.recipes or DeepCopyRecipes(DEFAULT_RECIPES)
    NormalizeRecipes(db.recipes)

    self.db = db
end

local function NormalizeName(value)
    if type(value) ~= "string" then
        return nil
    end
    return string.lower((value:gsub("^%s+", ""):gsub("%s+$", "")))
end

local function AddAtlasRoot(list, seen, candidate)
    if type(candidate) ~= "table" or seen[candidate] then
        return
    end
    seen[candidate] = true
    table.insert(list, candidate)
end

function AHAP:GetAtlasLootRootTables()
    local roots = {}
    local seen = {}

    AddAtlasRoot(roots, seen, _G.AtlasLoot)
    AddAtlasRoot(roots, seen, _G.AtlasLoot_Data)
    AddAtlasRoot(roots, seen, _G.AtlasLootData)

    if type(_G.AtlasLoot) == "table" then
        AddAtlasRoot(roots, seen, _G.AtlasLoot.Data)
        AddAtlasRoot(roots, seen, _G.AtlasLoot.db)
    end

    return roots
end

local function ExtractReagentList(candidate)
    if type(candidate) ~= "table" then
        return nil
    end

    local possibleKeys = { "reagents", "mats", "materials", "ingredients", "cost" }
    for _, key in ipairs(possibleKeys) do
        local value = candidate[key]
        if type(value) == "table" and #value > 0 then
            return value
        end
    end

    return nil
end

local function ParseAtlasReagents(list)
    local mats = {}
    for _, mat in ipairs(list) do
        if type(mat) == "table" then
            local name = mat.name or mat.itemName or mat.label
            local qty = mat.qty or mat.count or mat.amount or mat.num
            if type(name) == "string" and type(qty) == "number" and qty > 0 then
                table.insert(mats, { name = name, qty = math.floor(qty) })
            end
        end
    end

    if #mats > 0 then
        return mats
    end

    return nil
end

function AHAP:FindAtlasLootMatsForOutput(outputName)
    local target = NormalizeName(outputName)
    if not target then
        return nil
    end

    local roots = self:GetAtlasLootRootTables()
    if #roots == 0 then
        return nil
    end

    local visited = {}
    local stack = {}
    for _, root in ipairs(roots) do
        table.insert(stack, root)
    end

    local maxNodes = 12000
    local scanned = 0
    while #stack > 0 and scanned < maxNodes do
        local node = table.remove(stack)
        if type(node) == "table" and not visited[node] then
            visited[node] = true
            scanned = scanned + 1

            local names = {
                node.output,
                node.name,
                node.itemName,
                node.recipeName,
                node.spellName,
            }
            for _, candidateName in ipairs(names) do
                if NormalizeName(candidateName) == target then
                    local reagentList = ExtractReagentList(node)
                    local parsed = ParseAtlasReagents(reagentList)
                    if parsed then
                        return parsed
                    end
                end
            end

            for _, value in pairs(node) do
                if type(value) == "table" and not visited[value] then
                    table.insert(stack, value)
                end
            end
        end
    end

    return nil
end

function AHAP:ApplyAtlasLootMats()
    if not self.db or not self.db.settings.useAtlasLootMats then
        return 0
    end

    local changed = 0
    for _, recipe in ipairs(self.db.recipes) do
        if type(recipe.output) == "string" and string.find(string.lower(recipe.output), "elixir", 1, true) then
            local atlasMats = self:FindAtlasLootMatsForOutput(recipe.output)
            if atlasMats then
                recipe.mats = atlasMats
                changed = changed + 1
            end
        end
    end

    return changed
end

function AHAP:GetAuctionatorRootTables()
    return {
        AUCTIONATOR_PRICE_DATABASE = _G.AUCTIONATOR_PRICE_DATABASE,
        AuctionatorPriceDatabase = _G.AuctionatorPriceDatabase,
        AuctionatorDB = _G.AuctionatorDB,
        AUCTIONATOR_DB = _G.AUCTIONATOR_DB,
    }
end

function AHAP:GetAuctionatorCandidateTables()
    local roots = self:GetAuctionatorRootTables()
    local tables = {}
    local seen = {}

    local function addTable(tbl)
        if type(tbl) ~= "table" or seen[tbl] then
            return
        end
        seen[tbl] = true
        table.insert(tables, tbl)
    end

    for _, root in pairs(roots) do
        addTable(root)
        if type(root) == "table" then
            addTable(root.prices)
            addTable(root.PriceDatabase)
            addTable(root.priceDatabase)

            local realmName = GetRealmName and GetRealmName() or nil
            if realmName then
                addTable(root[realmName])
                local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
                if faction then
                    addTable(root[realmName .. "_" .. faction])
                    addTable(root[realmName .. "-" .. faction])
                    addTable(root[faction .. "-" .. realmName])
                end
            end

            for _, sub in pairs(root) do
                if type(sub) == "table" then
                    if sub.prices then
                        addTable(sub.prices)
                    end
                    if sub.PriceDatabase then
                        addTable(sub.PriceDatabase)
                    end
                end
            end
        end
    end

    return tables
end

local function ExtractPrice(value)
    if type(value) == "number" then
        return value
    end
    if type(value) ~= "table" then
        return nil
    end

    local keys = { "price", "minBuyout", "m", "buy" }
    for _, key in ipairs(keys) do
        local candidate = value[key]
        if type(candidate) == "number" then
            return candidate
        end
    end

    for _, sub in pairs(value) do
        if type(sub) == "number" then
            return sub
        end
        if type(sub) == "table" then
            for _, key in ipairs(keys) do
                if type(sub[key]) == "number" then
                    return sub[key]
                end
            end
        end
    end

    return nil
end

function AHAP:GetPriceFromTable(tbl, itemName)
    if type(tbl) ~= "table" then
        return nil
    end

    local direct = ExtractPrice(tbl[itemName])
    if direct then
        return direct
    end

    local lowered = string.lower(itemName)
    for key, value in pairs(tbl) do
        if type(key) == "string" and string.lower(key) == lowered then
            local p = ExtractPrice(value)
            if p then
                return p
            end
        end
    end

    return nil
end

function AHAP:GetAuctionatorPrice(itemName)
    local candidates = self:GetAuctionatorCandidateTables()
    for _, tbl in ipairs(candidates) do
        local price = self:GetPriceFromTable(tbl, itemName)
        if price and price > 0 then
            return self:RoundCopper(price)
        end
    end
    return 0
end

function AHAP:GetSellPriceForRecipe(recipe)
    local preset = self.db.presetValues[recipe.output]
    if self.db.settings.usePresetValues and preset and preset > 0 then
        return preset, true
    end
    return self:GetAuctionatorPrice(recipe.output), false
end

function AHAP:CalculateRecipe(recipe)
    local craftCost = 0
    local missing = 0

    for _, mat in ipairs(recipe.mats) do
        local price = self:GetAuctionatorPrice(mat.name)
        if price <= 0 then
            missing = missing + 1
        end
        craftCost = craftCost + (mat.qty * price)
    end

    local sellPrice, usedPreset = self:GetSellPriceForRecipe(recipe)
    if sellPrice <= 0 then
        missing = missing + 1
    end

    local ahCut = self.db.settings.ahCut or DEFAULT_SETTINGS.ahCut
    local procRate = self.db.settings.procRate or DEFAULT_SETTINGS.procRate

    local baseProfit = self:RoundCopper((sellPrice * (1 - ahCut)) - craftCost)
    local expectedProfit = self:RoundCopper((sellPrice * (1 + procRate) * (1 - ahCut)) - craftCost)

    local expectedPct = 0
    if craftCost > 0 then
        expectedPct = (expectedProfit / craftCost) * 100
    end

    return {
        recipeName = recipe.name,
        output = recipe.output,
        craftCost = craftCost,
        sellPrice = sellPrice,
        baseProfit = baseProfit,
        expectedProfit = expectedProfit,
        expectedPct = expectedPct,
        missing = missing,
        usedPreset = usedPreset,
    }
end

function AHAP:GetAllRecipeResults()
    local rows = {}
    local missingCount = 0
    for _, recipe in ipairs(self.db.recipes) do
        if recipe.enabled ~= false then
            local result = self:CalculateRecipe(recipe)
            missingCount = missingCount + result.missing
            table.insert(rows, result)
        end
    end
    return rows, missingCount
end

function AHAP:SetRecipeEnabled(outputName, enabled)
    for _, recipe in ipairs(self.db.recipes) do
        if recipe.output == outputName then
            recipe.enabled = enabled and true or false
            return true
        end
    end
    return false
end

function AHAP:GetRecipeByOutput(outputName)
    for _, recipe in ipairs(self.db.recipes) do
        if recipe.output == outputName then
            return recipe
        end
    end
    return nil
end

function AHAP:ParseNumber(text, fallback)
    local n = tonumber(text)
    if not n then
        return fallback
    end
    return n
end

function AHAP:PrintDebugAuctionatorKeys()
    self:Print("[Debug] Scanning Auctionator globals...")
    local roots = self:GetAuctionatorRootTables()
    local foundAny = false

    local function listKeys(prefix, tbl)
        if type(tbl) ~= "table" then
            self:Print(prefix .. ": <not a table>")
            return
        end

        local keys = {}
        for key in pairs(tbl) do
            table.insert(keys, tostring(key))
        end
        table.sort(keys)

        self:Print(string.format("%s: table (%d keys)", prefix, #keys))
        if #keys == 0 then
            self:Print("  (no keys)")
            return
        end

        local limit = math.min(#keys, 30)
        for i = 1, limit do
            self:Print("  - " .. keys[i])
        end
        if #keys > limit then
            self:Print(string.format("  ... and %d more", #keys - limit))
        end
    end

    for name, tbl in pairs(roots) do
        if tbl ~= nil then
            foundAny = true
        end
        listKeys(name, tbl)
    end

    if not foundAny then
        self:Print("No known Auctionator global tables found.")
    end
end

function AHAP:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AHAlchemyProfit|r " .. tostring(msg))
end

SLASH_AHALCHEMY1 = "/ahalchemy"
SlashCmdList.AHALCHEMY = function()
    if AHAP.ToggleMainFrame then
        AHAP:ToggleMainFrame()
    else
        AHAP:Print("UI is not loaded yet.")
    end
end

SLASH_AHAPDEBUG1 = "/ahap_debug"
SlashCmdList.AHAPDEBUG = function()
    AHAP:PrintDebugAuctionatorKeys()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        AHAP:EnsureDB()
        AHAP:ApplyAtlasLootMats()
        AHAP:Print("Loaded. Use /ahalchemy to open the calculator.")
    end
end)

local _, AHAP = ...

local TAB_TITLES = { "Calculator", "Recipes", "PreValue", "Settings" }

local function CreateBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
end

function AHAP:ToggleMainFrame()
    if not self.mainFrame then
        self:CreateUI()
    end

    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        self:RefreshCalculator()
        self:RefreshRecipeToggleList()
        self:RefreshPresetList()
        self:LoadSettingsIntoUI()
    end
end

function AHAP:CreateUI()
    local frame = CreateFrame("Frame", "AHAlchemyProfitMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(980, 540)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    CreateBackdrop(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("AHAlchemyProfit")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)

    frame.tabs = {}
    frame.tabPanels = {}

    for i, tabName in ipairs(TAB_TITLES) do
        local tab = CreateFrame("Button", nil, frame, "OptionsFrameTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(tabName)
        PanelTemplates_TabResize(tab, 0)

        if i == 1 then
            tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
        else
            tab:SetPoint("LEFT", frame.tabs[i - 1], "RIGHT", -16, 0)
        end

        tab:SetScript("OnClick", function(btn)
            AHAP:SelectTab(btn:GetID())
        end)

        frame.tabs[i] = tab

        local panel = CreateFrame("Frame", nil, frame)
        panel:SetPoint("TOPLEFT", 16, -74)
        panel:SetPoint("BOTTOMRIGHT", -16, 16)
        panel:Hide()
        frame.tabPanels[i] = panel
    end

    self.mainFrame = frame
    self:CreateCalculatorTab(frame.tabPanels[1])
    self:CreateRecipesTab(frame.tabPanels[2])
    self:CreatePreValueTab(frame.tabPanels[3])
    self:CreateSettingsTab(frame.tabPanels[4])
    self:SelectTab(1)
end

function AHAP:SelectTab(index)
    for i, tab in ipairs(self.mainFrame.tabs) do
        local selected = (i == index)
        PanelTemplates_Tab_OnClick(tab, self.mainFrame)
        self.mainFrame.tabPanels[i]:SetShown(selected)
        if selected then
            PanelTemplates_SetTab(self.mainFrame, i)
        end
    end

    if index == 1 then
        self:RefreshCalculator()
    elseif index == 2 then
        self:RefreshRecipeToggleList()
    elseif index == 3 then
        self:RefreshPresetList()
    elseif index == 4 then
        self:LoadSettingsIntoUI()
    end
end

function AHAP:CreateRecipesTab(panel)
    local help = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    help:SetPoint("TOPLEFT", 8, -8)
    help:SetText("Toggle recipes on/off for Calculator tab.")

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    panel.recipeRows = {}
    panel.scrollContent = content
end

function AHAP:GetOrCreateRecipeToggleRow(panel, index)
    if panel.recipeRows[index] then
        return panel.recipeRows[index]
    end

    local row = CreateFrame("Frame", nil, panel.scrollContent)
    row:SetSize(860, 22)
    if index == 1 then
        row:SetPoint("TOPLEFT", 0, 0)
    else
        row:SetPoint("TOPLEFT", panel.recipeRows[index - 1], "BOTTOMLEFT", 0, -4)
    end

    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetPoint("LEFT", 0, 0)
    row.check = check

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", check, "RIGHT", 4, 0)
    text:SetJustifyH("LEFT")
    text:SetWidth(780)
    row.text = text

    panel.recipeRows[index] = row
    return row
end

function AHAP:RefreshRecipeToggleList()
    if not self.mainFrame then
        return
    end

    local panel = self.mainFrame.tabPanels[2]
    local recipes = self.db.recipes or {}

    table.sort(recipes, function(a, b)
        return (a.output or "") < (b.output or "")
    end)

    for i, recipe in ipairs(recipes) do
        local row = self:GetOrCreateRecipeToggleRow(panel, i)
        row:Show()
        row.text:SetText(recipe.output or recipe.name or "Unknown")
        row.check:SetChecked(recipe.enabled ~= false)
        row.check:SetScript("OnClick", function(btn)
            AHAP:SetRecipeEnabled(recipe.output, btn:GetChecked() and true or false)
            AHAP:RefreshCalculator()
        end)
    end

    for i = #recipes + 1, #panel.recipeRows do
        panel.recipeRows[i]:Hide()
    end

    panel.scrollContent:SetHeight(math.max(1, (#recipes * 26) + 20))
end

function AHAP:CreateCalculatorTab(panel)
    local headers = {
        { "Output Item", 8 },
        { "Craft Cost", 220 },
        { "Sell Price", 350 },
        { "Base Profit", 470 },
        { "Expected Profit", 600 },
        { "Expected Profit %", 760 },
    }

    for _, header in ipairs(headers) do
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", header[2], -8)
        fs:SetText(header[1])
    end

    local missingLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    missingLabel:SetPoint("TOPLEFT", 8, -32)
    missingLabel:SetText("Missing prices count: 0")
    panel.missingLabel = missingLabel

    local refreshBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    refreshBtn:SetSize(90, 24)
    refreshBtn:SetPoint("TOPRIGHT", -8, -28)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        AHAP:RefreshCalculator()
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -58)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    panel.rows = {}
    panel.scrollContent = content
end

function AHAP:GetOrCreateCalcRow(panel, index)
    if panel.rows[index] then
        return panel.rows[index]
    end

    local row = CreateFrame("Frame", nil, panel.scrollContent)
    row:SetSize(900, 20)
    if index == 1 then
        row:SetPoint("TOPLEFT", 0, 0)
    else
        row:SetPoint("TOPLEFT", panel.rows[index - 1], "BOTTOMLEFT", 0, -4)
    end

    row.cols = {}
    local colPoints = { 8, 220, 350, 470, 600, 760 }
    for i = 1, 6 do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", colPoints[i], 0)
        fs:SetWidth(140)
        fs:SetJustifyH("LEFT")
        row.cols[i] = fs
    end

    panel.rows[index] = row
    return row
end

function AHAP:RefreshCalculator()
    if not self.mainFrame then
        return
    end

    local panel = self.mainFrame.tabPanels[1]
    if not panel then
        return
    end

    local rows, missingCount = self:GetAllRecipeResults()
    panel.missingLabel:SetText("Missing prices count: " .. tostring(missingCount))

    for i, result in ipairs(rows) do
        local row = self:GetOrCreateCalcRow(panel, i)
        row:Show()

        row.cols[1]:SetText(result.output)
        row.cols[2]:SetText(self:FormatCopper(result.craftCost))

        local sellText = self:FormatCopper(result.sellPrice)
        if result.usedPreset then
            sellText = sellText .. " *"
        end
        row.cols[3]:SetText(sellText)

        row.cols[4]:SetText(self:FormatCopper(result.baseProfit))
        row.cols[5]:SetText(self:FormatCopper(result.expectedProfit))
        row.cols[6]:SetText(string.format("%.1f%%", result.expectedPct))
    end

    for i = #rows + 1, #panel.rows do
        panel.rows[i]:Hide()
    end

    local totalHeight = math.max(1, (#rows * 24) + 20)
    panel.scrollContent:SetHeight(totalHeight)
end

function AHAP:CreatePreValueTab(panel)
    local itemLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemLabel:SetPoint("TOPLEFT", 8, -8)
    itemLabel:SetText("Item Name")

    local itemEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    itemEdit:SetSize(260, 24)
    itemEdit:SetPoint("TOPLEFT", 8, -28)
    itemEdit:SetAutoFocus(false)
    panel.itemEdit = itemEdit

    local function CreateSmallMoneyBox(labelText, anchor, relTo)
        local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT", relTo, anchor, 10, 0)
        lbl:SetText(labelText)

        local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        edit:SetSize(60, 24)
        edit:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
        edit:SetAutoFocus(false)
        return edit
    end

    local goldEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    goldEdit:SetSize(60, 24)
    goldEdit:SetPoint("TOPLEFT", itemEdit, "TOPRIGHT", 20, 0)
    goldEdit:SetAutoFocus(false)
    panel.goldEdit = goldEdit

    local gLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gLbl:SetPoint("LEFT", goldEdit, "RIGHT", 4, 0)
    gLbl:SetText("g")

    local silverEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    silverEdit:SetSize(60, 24)
    silverEdit:SetPoint("LEFT", gLbl, "RIGHT", 12, 0)
    silverEdit:SetAutoFocus(false)
    panel.silverEdit = silverEdit

    local sLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sLbl:SetPoint("LEFT", silverEdit, "RIGHT", 4, 0)
    sLbl:SetText("s")

    local copperEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    copperEdit:SetSize(60, 24)
    copperEdit:SetPoint("LEFT", sLbl, "RIGHT", 12, 0)
    copperEdit:SetAutoFocus(false)
    panel.copperEdit = copperEdit

    local cLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cLbl:SetPoint("LEFT", copperEdit, "RIGHT", 4, 0)
    cLbl:SetText("c")

    local saveBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    saveBtn:SetSize(90, 24)
    saveBtn:SetPoint("TOPLEFT", itemEdit, "BOTTOMLEFT", 0, -12)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        AHAP:SavePresetFromUI()
    end)

    local removeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    removeBtn:SetSize(90, 24)
    removeBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    removeBtn:SetText("Remove")
    removeBtn:SetScript("OnClick", function()
        AHAP:RemovePresetFromUI()
    end)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", saveBtn, "BOTTOMLEFT", 0, -8)
    hint:SetText("Click a preset below to load it into fields.")

    local listFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    listFrame:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
    listFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local listContent = CreateFrame("Frame", nil, listFrame)
    listContent:SetSize(1, 1)
    listFrame:SetScrollChild(listContent)

    panel.presetRows = {}
    panel.listContent = listContent
end

function AHAP:LoadCopperIntoPresetFields(copper)
    local panel = self.mainFrame.tabPanels[3]
    local amount = math.max(0, self:RoundCopper(copper or 0))
    local g = math.floor(amount / 10000)
    local s = math.floor((amount % 10000) / 100)
    local c = amount % 100
    panel.goldEdit:SetText(g)
    panel.silverEdit:SetText(s)
    panel.copperEdit:SetText(c)
end

function AHAP:GetPresetCopperFromFields()
    local panel = self.mainFrame.tabPanels[3]
    local g = tonumber(panel.goldEdit:GetText() or "") or 0
    local s = tonumber(panel.silverEdit:GetText() or "") or 0
    local c = tonumber(panel.copperEdit:GetText() or "") or 0
    g = math.max(0, math.floor(g))
    s = math.max(0, math.floor(s))
    c = math.max(0, math.floor(c))
    return (g * 10000) + (s * 100) + c
end

function AHAP:SavePresetFromUI()
    local panel = self.mainFrame.tabPanels[3]
    local item = (panel.itemEdit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if item == "" then
        self:Print("Enter an item name to save preset value.")
        return
    end

    local copper = self:GetPresetCopperFromFields()
    self.db.presetValues[item] = copper
    self:Print("Saved preset for " .. item .. " = " .. self:FormatCopper(copper))
    self:RefreshPresetList()
    self:RefreshCalculator()
end

function AHAP:RemovePresetFromUI()
    local panel = self.mainFrame.tabPanels[3]
    local item = (panel.itemEdit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if item == "" then
        self:Print("Enter an item name to remove preset value.")
        return
    end

    self.db.presetValues[item] = nil
    self:Print("Removed preset for " .. item)
    self:RefreshPresetList()
    self:RefreshCalculator()
end

function AHAP:GetOrCreatePresetRow(panel, index)
    if panel.presetRows[index] then
        return panel.presetRows[index]
    end

    local btn = CreateFrame("Button", nil, panel.listContent)
    btn:SetSize(860, 20)
    if index == 1 then
        btn:SetPoint("TOPLEFT", 0, 0)
    else
        btn:SetPoint("TOPLEFT", panel.presetRows[index - 1], "BOTTOMLEFT", 0, -4)
    end

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetAllPoints(true)
    fs:SetJustifyH("LEFT")
    btn.text = fs

    panel.presetRows[index] = btn
    return btn
end

function AHAP:RefreshPresetList()
    if not self.mainFrame then
        return
    end

    local panel = self.mainFrame.tabPanels[3]
    local entries = {}
    for item, copper in pairs(self.db.presetValues) do
        table.insert(entries, { item = item, copper = copper })
    end
    table.sort(entries, function(a, b) return a.item < b.item end)

    for i, entry in ipairs(entries) do
        local row = self:GetOrCreatePresetRow(panel, i)
        row:Show()
        row.text:SetText(entry.item .. " - " .. self:FormatCopper(entry.copper))
        row:SetScript("OnClick", function()
            panel.itemEdit:SetText(entry.item)
            AHAP:LoadCopperIntoPresetFields(entry.copper)
        end)
    end

    for i = #entries + 1, #panel.presetRows do
        panel.presetRows[i]:Hide()
    end

    panel.listContent:SetHeight(math.max(1, (#entries * 24) + 20))
end

function AHAP:CreateSettingsTab(panel)
    local procLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    procLabel:SetPoint("TOPLEFT", 8, -8)
    procLabel:SetText("Proc Rate (e.g. 0.20)")

    local procEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    procEdit:SetSize(120, 24)
    procEdit:SetPoint("TOPLEFT", 8, -28)
    procEdit:SetAutoFocus(false)
    panel.procEdit = procEdit

    local cutLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cutLabel:SetPoint("TOPLEFT", procEdit, "BOTTOMLEFT", 0, -14)
    cutLabel:SetText("AH Cut (e.g. 0.05)")

    local cutEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    cutEdit:SetSize(120, 24)
    cutEdit:SetPoint("TOPLEFT", cutLabel, "BOTTOMLEFT", 0, -4)
    cutEdit:SetAutoFocus(false)
    panel.cutEdit = cutEdit

    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", cutEdit, "BOTTOMLEFT", 0, -14)
    check.text:SetText("Use preset raid-night values")
    panel.usePresetCheck = check

    local atlasCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    atlasCheck:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 0, -10)
    atlasCheck.text:SetText("Use AtlasLoot elixir materials when available")
    panel.useAtlasLootMatsCheck = atlasCheck

    local saveBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    saveBtn:SetSize(90, 24)
    saveBtn:SetPoint("TOPLEFT", atlasCheck, "BOTTOMLEFT", 0, -14)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        AHAP:SaveSettingsFromUI()
    end)
end

function AHAP:LoadSettingsIntoUI()
    if not self.mainFrame then
        return
    end

    local panel = self.mainFrame.tabPanels[4]
    panel.procEdit:SetText(tostring(self.db.settings.procRate or 0.20))
    panel.cutEdit:SetText(tostring(self.db.settings.ahCut or 0.05))
    panel.usePresetCheck:SetChecked(self.db.settings.usePresetValues and true or false)
    panel.useAtlasLootMatsCheck:SetChecked(self.db.settings.useAtlasLootMats and true or false)
end

function AHAP:SaveSettingsFromUI()
    local panel = self.mainFrame.tabPanels[4]

    local procRate = tonumber(panel.procEdit:GetText() or "")
    local ahCut = tonumber(panel.cutEdit:GetText() or "")
    if not procRate then procRate = 0.20 end
    if not ahCut then ahCut = 0.05 end

    self.db.settings.procRate = procRate
    self.db.settings.ahCut = ahCut
    self.db.settings.usePresetValues = panel.usePresetCheck:GetChecked() and true or false
    self.db.settings.useAtlasLootMats = panel.useAtlasLootMatsCheck:GetChecked() and true or false

    local changed = self:ApplyAtlasLootMats()

    self:Print("Settings saved. AtlasLoot sync updated " .. tostring(changed) .. " recipe(s).")
    self:RefreshCalculator()
    self:RefreshRecipeToggleList()
end

---------------
--XML Constants
---------------
local BOOSTER_CHART_FILE_WIDTH = 1024
local BOOSTER_CHART_FILE_HEIGHT = 32
ZO_GAMEPAD_SMITHING_IMPROVEMENT_BOOSTER_CHART_WIDTH = 608
ZO_GAMEPAD_SMITHING_IMPROVEMENT_BOOSTER_CHART_HEIGHT = 25
ZO_GAMEPAD_SMITHING_IMPROVEMENT_BOOSTER_AREA_HEIGHT = 140
ZO_GAMEPAD_SMITHING_IMPROVEMENT_BOOSTER_CHART_STEP_X = ZO_GAMEPAD_SMITHING_IMPROVEMENT_BOOSTER_CHART_WIDTH / 4
ZO_GAMEPAD_SMITHING_IMPROVEMENT_BOOSTER_CHART_TEXTURE_COORD_BOTTOM = ZO_GAMEPAD_SMITHING_IMPROVEMENT_BOOSTER_CHART_HEIGHT / BOOSTER_CHART_FILE_HEIGHT
ZO_GAMEPAD_SMITHING_IMPROVEMENT_BOOSTER_CHART_TEXTURE_COORD_RIGHT = ZO_GAMEPAD_SMITHING_IMPROVEMENT_BOOSTER_CHART_WIDTH / BOOSTER_CHART_FILE_WIDTH
ZO_GAMEPAD_SMITHING_IMPROVEMENT_TOOLTIP_PANEL_FLOATING_CENTER_OFFSET_Y = ZO_GAMEPAD_PANEL_FLOATING_CENTER_OFFSET_Y + (ZO_GAMEPAD_SMITHING_IMPROVEMENT_BOOSTER_AREA_HEIGHT / 2)

local IMPROVEMENT_TOOLTIP_PANEL_FLOATING_HEIGHT_DISCOUNT = ZO_GAMEPAD_PANEL_FLOATING_HEIGHT_DISCOUNT + ZO_GAMEPAD_SMITHING_IMPROVEMENT_BOOSTER_AREA_HEIGHT
local BOOSTER_CHART_TEXTURE_COORD_STEP_X = ZO_GAMEPAD_SMITHING_IMPROVEMENT_BOOSTER_CHART_STEP_X / BOOSTER_CHART_FILE_WIDTH

--Normal -> Fine
ZO_GAMEPAD_SMITHING_IMPROVEMENT_NORMAL_FINE_TEXTURE_COORD_LEFT = 0
ZO_GAMEPAD_SMITHING_IMPROVEMENT_NORMAL_FINE_TEXTURE_COORD_RIGHT = ZO_GAMEPAD_SMITHING_IMPROVEMENT_NORMAL_FINE_TEXTURE_COORD_LEFT + BOOSTER_CHART_TEXTURE_COORD_STEP_X
--Fine -> Superior
ZO_GAMEPAD_SMITHING_IMPROVEMENT_FINE_SUPERIOR_TEXTURE_COORD_LEFT = ZO_GAMEPAD_SMITHING_IMPROVEMENT_NORMAL_FINE_TEXTURE_COORD_RIGHT
ZO_GAMEPAD_SMITHING_IMPROVEMENT_FINE_SUPERIOR_TEXTURE_COORD_RIGHT = ZO_GAMEPAD_SMITHING_IMPROVEMENT_FINE_SUPERIOR_TEXTURE_COORD_LEFT + BOOSTER_CHART_TEXTURE_COORD_STEP_X
--Superior -> Epic
ZO_GAMEPAD_SMITHING_IMPROVEMENT_SUPERIOR_EPIC_TEXTURE_COORD_LEFT = ZO_GAMEPAD_SMITHING_IMPROVEMENT_FINE_SUPERIOR_TEXTURE_COORD_RIGHT
ZO_GAMEPAD_SMITHING_IMPROVEMENT_SUPERIOR_EPIC_TEXTURE_COORD_RIGHT = ZO_GAMEPAD_SMITHING_IMPROVEMENT_SUPERIOR_EPIC_TEXTURE_COORD_LEFT + BOOSTER_CHART_TEXTURE_COORD_STEP_X
--Epic -> Legendary
ZO_GAMEPAD_SMITHING_IMPROVEMENT_EPIC_LEGENDARY_TEXTURE_COORD_LEFT = ZO_GAMEPAD_SMITHING_IMPROVEMENT_SUPERIOR_EPIC_TEXTURE_COORD_RIGHT
ZO_GAMEPAD_SMITHING_IMPROVEMENT_EPIC_LEGENDARY_TEXTURE_COORD_RIGHT = ZO_GAMEPAD_SMITHING_IMPROVEMENT_EPIC_LEGENDARY_TEXTURE_COORD_LEFT + BOOSTER_CHART_TEXTURE_COORD_STEP_X

-- Object
ZO_GamepadSmithingImprovement = ZO_SharedSmithingImprovement:Subclass()

function ZO_GamepadSmithingImprovement:New(...)
    return ZO_SharedSmithingImprovement.New(self, ...)
end

function ZO_GamepadSmithingImprovement:Initialize(panelControl, floatingControl, owner, scene)
    self.panelControl = panelControl
    self.floatingControl = floatingControl

    -- called before initialize on purpose, as functions called from it need these
    self.mode = ZO_SMITHING_IMPROVEMENT_SHARED_FILTER_TYPE_WEAPONS
    self.tooltip = floatingControl:GetNamedChild("Tooltip")
    self.sourceTooltip = floatingControl:GetNamedChild("SourceTooltip")
    self.qualityBridge = floatingControl:GetNamedChild("QualityBridge")
    self.resultTooltip = floatingControl:GetNamedChild("ResultTooltip")
    self.slotContainer = floatingControl:GetNamedChild("SlotContainer")

    -- Pre-init setup done
    ZO_SharedSmithingImprovement.Initialize(self, panelControl, floatingControl:GetNamedChild("BoosterContainer"), self.resultTooltip, owner)

    self:InitializeInventory()
    self:InitializeKeybindStripDescriptors()

    -- set up inventory keybinds and tooltips
    self.inventory.list:SetOnSelectedDataChangedCallback(function(list, selectedData)
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
        if selectedData and selectedData.bagId and selectedData.slotIndex then
            self.tooltip.tip:ClearLines()
            self.tooltip.tip:LayoutBagItem(selectedData.bagId, selectedData.slotIndex)
            self.tooltip.icon:SetTexture(selectedData.pressedIcon)
            self.tooltip:SetHidden(false)

            -- purposely not showing this one yet...
            self.sourceTooltip.tip:ClearLines()
            self.sourceTooltip.tip:LayoutBagItem(selectedData.bagId, selectedData.slotIndex)
            self.sourceTooltip.icon:SetTexture(selectedData.pressedIcon)

            self:Refresh()

            self:ColorizeText(self:GetBoosterRowForQuality(selectedData.quality))

            self.selectedItem = selectedData

            if not self:HasSelections() then
                self.sourceTooltip:SetHidden(true)
                self.resultTooltip:SetHidden(true)
                self.slotContainer:SetHidden(true)
                self:EnableQualityBridge(false)
            end

            self:SetInventoryActive(true)

            if self.shouldActivateTabBar then
                ZO_GamepadGenericHeader_Activate(self.owner.header)
            end

            self.spinner:Deactivate()
            self.spinner:SetValue(1)

            GAMEPAD_CRAFTING_RESULTS:SetCraftingTooltip(self.resultTooltip)
            GAMEPAD_CRAFTING_RESULTS:SetTooltipAnimationSounds(ZO_SharedSmithingImprovement_GetImprovementTooltipSounds())
        else
            self.tooltip.tip:ClearLines()
            self.tooltip:SetHidden(true)

            self:ClearBoosterRowHighlight()

            self.selectedItem = nil
        end
    end)

    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            KEYBIND_STRIP:RemoveDefaultExit()
            KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
            self:SetInventoryActive(true)

            -- LB / RB handling for switching filters on improvement screen
            local tabBarEntries = {}

            self:AddEntry(GetString(SI_CHARACTER_EQUIP_SECTION_WEAPONS), ZO_SMITHING_IMPROVEMENT_SHARED_FILTER_TYPE_WEAPONS, CanSmithingWeaponPatternsBeCraftedHere(), tabBarEntries)
            self:AddEntry(GetString(SI_CHARACTER_EQUIP_SECTION_APPAREL), ZO_SMITHING_IMPROVEMENT_SHARED_FILTER_TYPE_ARMOR, CanSmithingApparelPatternsBeCraftedHere(), tabBarEntries)

            local titleString = ZO_GamepadCraftingUtils_GetLineNameForCraftingType(GetCraftingInteractionType())

            ZO_GamepadCraftingUtils_SetupGenericHeader(self.owner, titleString, tabBarEntries)

            if #tabBarEntries > 1 then
                ZO_GamepadGenericHeader_Activate(self.owner.header)
                self.shouldActivateTabBar = true
            else
                self.shouldActivateTabBar = false
            end

            ZO_GamepadCraftingUtils_RefreshGenericHeader(self.owner)

            -- tab bar / screen state fight with each other when switching between apparel only / other stations when sharing a tab bar...kick apparel station to the right mode
            if #tabBarEntries == 1 then
                self:ChangeMode(tabBarEntries[1].mode)
            end

            -- used to update extraction slot UI with text / etc., PC does this as well
            self:RemoveItemFromWorkbench()

            if self.selectedItem then
                self:ColorizeText(self:GetBoosterRowForQuality(self.selectedItem.quality))
            end

            self.owner:SetEnableSkillBar(true)
        elseif newState == SCENE_HIDDEN then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
            KEYBIND_STRIP:RestoreDefaultExit()
            self:SetInventoryActive(false)

            self.tooltip.tip:ClearLines()
            self.tooltip:SetHidden(true)
            self.sourceTooltip.tip:ClearLines()
            self.sourceTooltip:SetHidden(true)
            self.resultTooltip.tip:ClearLines()
            self.resultTooltip:SetHidden(true)
            self.slotContainer:SetHidden(true)
            self:EnableQualityBridge(false)

            ZO_GamepadGenericHeader_Deactivate(self.owner.header)

            self:ClearBoosterRowHighlight()

            self.owner:SetEnableSkillBar(false)

            self.spinner:Deactivate()
            self.spinner:SetValue(1)
        end
    end)

    CALLBACK_MANAGER:RegisterCallback("CraftingAnimationsStarted", function() 
        if SCENE_MANAGER:IsShowing("gamepad_smithing_improvement") then
            self.spinner:Deactivate()
        end
    end)

    CALLBACK_MANAGER:RegisterCallback("CraftingAnimationsStopped", function()
        if SCENE_MANAGER:IsShowing("gamepad_smithing_improvement") then
            self:RemoveItemFromWorkbench()
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
            self:SetInventoryActive(true)

            if self.shouldActivateTabBar then
                ZO_GamepadGenericHeader_Activate(self.owner.header)
            end
        end
    end)
end

function ZO_GamepadSmithingImprovement:ChangeMode(mode)
    self.mode = mode
    self.inventory.filterType = mode

    if self.mode == ZO_SMITHING_IMPROVEMENT_SHARED_FILTER_TYPE_ARMOR then
        self.inventory.noItemsLabel:SetText(GetString(SI_SMITHING_IMPROVE_NO_ARMOR))
    elseif self.mode == ZO_SMITHING_IMPROVEMENT_SHARED_FILTER_TYPE_WEAPONS then
        self.inventory.noItemsLabel:SetText(GetString(SI_SMITHING_IMPROVE_NO_WEAPONS))
    end

    self.inventory:HandleDirtyEvent()
    -- used to update improvement slot UI with text / etc., PC does this as well
    -- note that on gamepad this gives a possibly unwanted side effect of losing the active item when switching filters
    if not GAMEPAD_CRAFTING_RESULTS:IsCraftInProgress() then
        self:RemoveItemFromWorkbench()
    end

    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)

    if self.selectedItem then
        self:ColorizeText(self:GetBoosterRowForQuality(self.selectedItem.quality))
    else
        self:ClearBoosterRowHighlight()
    end
end

function ZO_GamepadSmithingImprovement:AddEntry(name, mode, allowed, tabBarEntries)
    if allowed then
        local entry = {}
        entry.text = name
        entry.callback = function()
            self:ChangeMode(mode)
        end
        entry.mode = mode

        table.insert(tabBarEntries, entry)
    end
end

function ZO_GamepadSmithingImprovement:InitializeSlots()
    self.improvementSlot = ZO_SmithingImprovementSlot:New(self, self.slotContainer:GetNamedChild("ImprovementSlot"), SLOT_TYPE_PENDING_CRAFTING_COMPONENT, self.inventory)
    self.boosterSlot = self.slotContainer:GetNamedChild("BoosterSlot")
    
    ZO_InventorySlot_SetType(self.boosterSlot, SLOT_TYPE_SMITHING_BOOSTER)
    ZO_ItemSlot_SetAlwaysShowStackCount(self.boosterSlot, true)

    self.slotAnimation = ZO_CraftingCreateSlotAnimation:New("gamepad_smithing_improvement", function() return not self.panelControl:IsHidden() end)
    self.slotAnimation:AddSlot(self.improvementSlot)
    self.slotAnimation:AddSlot(self.boosterSlot)

    self.improvementChanceLabel = self.slotContainer.extraInfoLabel
    self.spinner = ZO_Spinner_Gamepad:New(self.slotContainer:GetNamedChild("Spinner"))
    self.spinner:SetValue(1)

    self.boosterStackCount = self.boosterSlot:GetNamedChild("StackCount")

    self.spinner:RegisterCallback("OnValueChanged", function(value)
        self:RefreshImprovementChance()

        local row = self:GetRowForSelection()
        if row then
            local color = value > row.currentStack and ZO_ERROR_COLOR or ZO_SELECTED_TEXT
            self.improvementChanceLabel:SetColor(color:UnpackRGBA())
        end

        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
    end)

    ZO_CraftingUtils_ConnectSpinnerToCraftingProcess(self.spinner)
end

function ZO_GamepadSmithingImprovement:InitializeInventory()
    self.inventoryControl = self.panelControl:GetNamedChild("Inventory")
    self.inventory = ZO_GamepadImprovementInventory:New(self, self.inventoryControl)
end

function ZO_GamepadSmithingImprovement:IsCurrentSelected()
    if self.improvementSlot:HasItem() then
        local bagId, slotIndex = self.improvementSlot:GetBagAndSlot()
        local selectedBagId, selectedSlotIndex = self.inventory:CurrentSelectionBagAndSlot()
        return bagId == selectedBagId and slotIndex == selectedSlotIndex
    end
end

function ZO_GamepadSmithingImprovement:UpdateSelection()
    local bagId, slotIndex = self.improvementSlot:GetBagAndSlot()
    for _, data in pairs(self.inventory.list.dataList) do
        if data.bagId == bagId and data.slotIndex == slotIndex then
            data.isEquippedInCurrentCategory = true
        else
            data.isEquippedInCurrentCategory = false
        end
    end

    if self.selectedItem then
        self:ColorizeText(self:GetBoosterRowForQuality(self.selectedItem.quality))
    else
        self:ClearBoosterRowHighlight()
    end

    self.inventory:PerformFullRefresh()
end

function ZO_GamepadSmithingImprovement:AddItemToWorkbench()
    local bagId, slotIndex = self.inventory:CurrentSelectionBagAndSlot()
    self:AddItemToCraft(bagId, slotIndex)

    self:UpdateSelection()

    if self.selectedItem then
        self.tooltip:SetHidden(true)
        self.sourceTooltip:SetHidden(false)
        self.slotContainer:SetHidden(false)

        -- I need the functionality of a crafting slot, but don't want to see these things (essentially an invisible crafting slot)
        local improvementSlotControl = self.improvementSlot:GetControl()
        improvementSlotControl:GetNamedChild("Bg"):SetHidden(true)
        improvementSlotControl:GetNamedChild("Icon"):SetHidden(true)

        self:SetInventoryActive(false)
        ZO_GamepadGenericHeader_Deactivate(self.owner.header)
        self.spinner:Activate()
        self.spinner:SetValue(1)
    end
end

function ZO_GamepadSmithingImprovement:RemoveItemFromWorkbench()
    self:SetImprovementSlotItem(nil)
    self:UpdateSelection()

    self.tooltip:SetHidden(false)
    self.sourceTooltip:SetHidden(true)
    self.slotContainer:SetHidden(true)

    if not self.selectedItem then
        self.tooltip.tip:ClearLines()
        self.tooltip:SetHidden(true)
    end

    self:SetInventoryActive(true)

    if self.shouldActivateTabBar then
        ZO_GamepadGenericHeader_Activate(self.owner.header)
    end

    self.spinner:Deactivate()
    self.spinner:SetValue(1)
end

function ZO_GamepadSmithingImprovement:ConfirmImprove()
    self:Improve()
end

function ZO_GamepadSmithingImprovement:CanImprove()
    return self.spinner:GetValue() <= self:GetBoosterRowForQuality(self.selectedItem.quality).currentStack
end

function ZO_GamepadSmithingImprovement:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor = 
    {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,

        -- need to have special exits for this scene
        {
            keybind = "UI_SHORTCUT_EXIT",
            callback = function()
                SCENE_MANAGER:ShowBaseScene()
            end,
            visible = function()
                return not ZO_CraftingUtils_IsPerformingCraftProcess()
            end,
            ethereal = true,
        },

        -- always backs up one step (improve dialog -> spinner -> item list -> hide scene)
        {
            name = function()
                if self:IsCurrentSelected() then
                    return GetString(SI_ITEM_ACTION_REMOVE_FROM_CRAFT)
                else
                    return GetString(SI_GAMEPAD_BACK_OPTION)
                end
            end,
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                if self:IsCurrentSelected() then
                    self:RemoveItemFromWorkbench()
                    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
                else
                    SCENE_MANAGER:HideCurrentScene()
                end
            end,
            visible = function()
                return not ZO_CraftingUtils_IsPerformingCraftProcess()
            end
        },

        -- Select
        {
            name = function()
                return GetString(SI_ITEM_ACTION_ADD_TO_CRAFT)
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function() return not ZO_CraftingUtils_IsPerformingCraftProcess() and not self:IsCurrentSelected() end,
            callback = function() 
                self:AddItemToWorkbench()
                KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
            end,
        },

        -- Perform craft
        {
            name = function()
                return GetString(SI_SMITHING_IMPROVE)
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
        
            callback = function() self:ConfirmImprove() end,

            visible = function() return not ZO_CraftingUtils_IsPerformingCraftProcess() and self:HasSelections() and self:CanImprove() end,
        },
    }

    ZO_Gamepad_AddListTriggerKeybindDescriptors(self.keybindStripDescriptor, self.inventory.list)
    ZO_CraftingUtils_ConnectKeybindButtonGroupToCraftingProcess(self.keybindStripDescriptor)
end

function ZO_GamepadSmithingImprovement:RefreshImprovementChance()
    ZO_SharedSmithingImprovement.RefreshImprovementChance(self)
    local row = self:GetRowForSelection()
    if row then
        self.slotContainer.selectedLabel:SetText(zo_strformat(SI_GAMEPAD_SMITHING_IMPROVEMENT_REAGENT_SELECTION, GetString("SI_ITEMQUALITY", row.quality), self.spinner:GetValue(), row.reagentName))
    end
end

function ZO_GamepadSmithingImprovement:OnSlotChanged()
    self.currentQuality = nil

    local hasItem = self.improvementSlot:HasItem()
    if hasItem then
        local row = self:GetRowForSelection()
        if row then
            self.spinner:SetMinMax(1, self:FindMaxBoostersToApply())

            self.currentQuality = row.quality - 1 -- need the "from" quality

            self.spinner:SetSoftMax(row.currentStack)

            self.boosterSlot.craftingType = GetCraftingInteractionType()
            self.boosterSlot.index = row.index

            ZO_ItemSlot_SetupSlot(self.boosterSlot, row.currentStack, row.icon)
            self:RefreshImprovementChance()

            self:ColorizeText(row)
        else
            self:ClearSelections()
            return
        end
    else
        self.canImprove = false

        self.improvementChanceLabel:SetText(GetString(SI_SMITHING_IMPROVE_CHANCE_HEADER))
        self:ClearBoosterRowHighlight()

        self.owner:OnImprovementSlotChanged()
    end

    self.boosterSlot:SetHidden(not hasItem)

    if hasItem then
        self.resultTooltip:SetHidden(false)
        self.resultTooltip.tip:ClearLines()
        self:SetupResultTooltip(self:GetCurrentImprovementParams())
        self:EnableQualityBridge(true, self.currentQuality)
    else
        self.resultTooltip:SetHidden(true)
        self:EnableQualityBridge(false)
    end

    self.inventory:HandleVisibleDirtyEvent()
end

function ZO_GamepadSmithingImprovement:Improve()
    self:SharedImprove("CONFIRM_IMPROVE_ITEM")
end

function ZO_GamepadSmithingImprovement:HighlightBoosterRow(rowToHighlight)
    for _, row in ipairs(self.rows) do
        if row ~= rowToHighlight then
            row.iconTexture:SetAlpha(.5)
            row.iconTexture:SetDesaturation(1)
            row.stackLabel:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
        end
    end
    
    rowToHighlight.iconTexture:SetAlpha(1)
    rowToHighlight.iconTexture:SetDesaturation(0)

    local colorToUse = (rowToHighlight.currentStack == 0) and ZO_ERROR_COLOR or ZO_SELECTED_TEXT
    rowToHighlight.stackLabel:SetColor(colorToUse:UnpackRGBA())
end

function ZO_GamepadSmithingImprovement:ClearBoosterRowHighlight()
    for _, row in ipairs(self.rows) do
        row.iconTexture:SetAlpha(1)
        row.iconTexture:SetDesaturation(0)

        local colorToUse = (row.currentStack == 0) and ZO_ERROR_COLOR or ZO_SELECTED_TEXT
        row.stackLabel:SetColor(colorToUse:UnpackRGBA())
    end
end

function ZO_GamepadSmithingImprovement:ColorizeText(qualityRow)
    -- there seems to be an edge case where if you start and quit the screen very quickly, you can select a new inventory item but the rows have been destroyed, causing an assert
    if qualityRow ~= nil then
        if self.improvementSlot:HasItem() then
            self:HighlightBoosterRow(qualityRow)
            local qualityColor = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, qualityRow.quality))
            self.slotContainer.selectedLabel:SetColor(qualityColor:UnpackRGBA())
        else
            self:ClearBoosterRowHighlight()
        end

        local spinnerControl = self.spinner:GetControl()
        local spinnerIcon = spinnerControl:GetNamedChild("Icon")
        local spinnerStackCount = spinnerIcon:GetNamedChild("StackCount")
        local spinnerDisplay = spinnerControl:GetNamedChild("Display")

        spinnerIcon:SetTexture(qualityRow.icon)
        spinnerStackCount:SetText(qualityRow.currentStack)

        local colorForText = (qualityRow.currentStack == 0) and ZO_ERROR_COLOR or ZO_SELECTED_TEXT
        spinnerStackCount:SetColor(colorForText:UnpackRGBA())
        spinnerDisplay:SetColor(colorForText:UnpackRGBA())
        self.improvementChanceLabel:SetColor(colorForText:UnpackRGBA())
    end
end

function ZO_GamepadSmithingImprovement:SetupResultTooltip(...)
    self.resultTooltip.tip:LayoutImprovedSmithingItem(...)
end

function ZO_GamepadSmithingImprovement:SetInventoryActive(active)
    if active then
        self.inventory:Activate()
        self.inventoryControl:SetHidden(false)
    else
        self.inventory:Deactivate()
        self.inventoryControl:SetHidden(true)
    end
end

do
    local QUALITY_TEXTURES = {
        [ITEM_QUALITY_NORMAL] = "EsoUI/Art/Crafting/Gamepad/gp_smithing_quality_normal2fine.dds",
        [ITEM_QUALITY_MAGIC] = "EsoUI/Art/Crafting/Gamepad/gp_smithing_quality_fine2superior.dds",
        [ITEM_QUALITY_ARCANE] = "EsoUI/Art/Crafting/Gamepad/gp_smithing_quality_superior2epic.dds",
        [ITEM_QUALITY_ARTIFACT] = "EsoUI/Art/Crafting/Gamepad/gp_smithing_quality_epic2legendary.dds",
    }

    function ZO_GamepadSmithingImprovement:EnableQualityBridge(enable, quality)
        if enable then 
            self.qualityBridge:SetTexture(QUALITY_TEXTURES[quality])
        end

        self.qualityBridge:SetHidden(not enable)
    end
end

function ZO_GamepadSmithingImprovement_TooltipScreenResizeHandler(control)
    local maxHeight = GuiRoot:GetHeight() - IMPROVEMENT_TOOLTIP_PANEL_FLOATING_HEIGHT_DISCOUNT - (ZO_GAMEPAD_CRAFTING_UTILS_FLOATING_PADDING_Y * 2)
    control:SetDimensionConstraints(0, 0, 0, maxHeight)
end

-- Gamepad inventory

ZO_GamepadImprovementInventory = ZO_GamepadCraftingInventory:Subclass()

function ZO_GamepadImprovementInventory:New(...)
    return ZO_GamepadCraftingInventory.New(self, ...)
end

function ZO_GamepadImprovementInventory:Initialize(owner, control, ...)
    ZO_GamepadCraftingInventory.Initialize(self, control, ...)

    self.owner = owner
    self.noItemsLabel = control.noItemsLabel
    self.filterType = ZO_SMITHING_IMPROVEMENT_SHARED_FILTER_TYPE_WEAPONS
end

function ZO_GamepadImprovementInventory:GetCurrentFilterType()
    return self.filterType
end

function ZO_GamepadImprovementInventory:Refresh(data)
    local validItemIds = self:EnumerateInventorySlotsAndAddToScrollData(ZO_SharedSmithingImprovement_CanItemBeImproved, ZO_SharedSmithingImprovement_DoesItemPassFilter, self.filterType, data)
    self.owner:OnInventoryUpdate(validItemIds)

    self.noItemsLabel:SetHidden(#data > 0)

    self.owner.spinner:GetControl():SetHidden(#data < 1 or not self.owner:HasSelections())
end
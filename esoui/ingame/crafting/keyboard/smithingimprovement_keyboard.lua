ZO_SmithingImprovement = ZO_SharedSmithingImprovement:Subclass()

function ZO_SmithingImprovement:New(...)
    return ZO_SharedSmithingImprovement.New(self, ...)
end

function ZO_SmithingImprovement:Initialize(control, owner)
    self.control = control
    ZO_SharedSmithingImprovement.Initialize(self, control, control:GetNamedChild("BoosterContainer"), control:GetNamedChild("ResultTooltip"),  owner)

    self.inventory = ZO_SmithingImprovementInventory:New(self, self.control:GetNamedChild("Inventory"))

    if IsChatSystemAvailableForCurrentPlatform() then
        local function OnTooltipMouseUp(control, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then
                local link = ZO_LinkHandler_CreateChatLink(GetSmithingImprovedItemLink, self:GetCurrentImprovementParams())
                if link ~= "" then
                    ClearMenu()

                    local function AddLink()
                        ZO_LinkHandler_InsertLink(zo_strformat(SI_TOOLTIP_ITEM_NAME, link))
                    end

                    AddMenuItem(GetString(SI_ITEM_ACTION_LINK_TO_CHAT), AddLink)
                    
                    ShowMenu(self)
                end
            end
        end

        self.resultTooltip:SetHandler("OnMouseUp", OnTooltipMouseUp)
        self.resultTooltip:GetNamedChild("Icon"):SetHandler("OnMouseUp", OnTooltipMouseUp)
    end
end

function ZO_SmithingImprovement:SetHidden(hidden)
    self.control:SetHidden(hidden)
    if not hidden then
        CRAFTING_RESULTS:SetCraftingTooltip(self.resultTooltip)
        CRAFTING_RESULTS:SetTooltipAnimationSounds(ZO_SharedSmithingImprovement_GetImprovementTooltipSounds())
        if self.dirty then
            self:Refresh()
        end
    end
end

function ZO_SmithingImprovement:InitializeSlots()
	local slotContainer = self.control:GetNamedChild("SlotContainer")
    self.improvementSlot = ZO_SmithingImprovementSlot:New(self, slotContainer:GetNamedChild("ImprovementSlot"), SLOT_TYPE_PENDING_CRAFTING_COMPONENT, self.inventory)
    self.boosterSlot = slotContainer:GetNamedChild("BoosterSlot")
    
    ZO_InventorySlot_SetType(self.boosterSlot, SLOT_TYPE_SMITHING_BOOSTER)
    ZO_ItemSlot_SetAlwaysShowStackCount(self.boosterSlot, true)

    self.slotAnimation = ZO_CraftingCreateSlotAnimation:New("smithing", function() return not self.control:IsHidden() end)
    self.slotAnimation:AddSlot(self.improvementSlot)
    self.slotAnimation:AddSlot(self.boosterSlot)

    self.awaitingLabel = slotContainer:GetNamedChild("AwaitingLabel")
    self.improvementChanceLabel = slotContainer:GetNamedChild("ChanceLabel")
    self.spinner = ZO_Spinner:New(slotContainer:GetNamedChild("Spinner"))
    self.spinner:SetValue(1)

    self.spinner:RegisterCallback("OnValueChanged", function(value)
        self:RefreshImprovementChance()
    end)

    ZO_CraftingUtils_ConnectSpinnerToCraftingProcess(self.spinner)
end

function ZO_SmithingImprovement:SetCraftingType(craftingType, oldCraftingType, isCraftingTypeDifferent)
	ZO_SharedSmithingImprovement.SetCraftingType(self, craftingType, oldCraftingType, isCraftingTypeDifferent)
    if isCraftingTypeDifferent then
        self.inventory:SetActiveFilterByDescriptor(nil)
    end
end

function ZO_SmithingImprovement:OnItemReceiveDrag(slotControl, bagId, slotIndex)
    if self.improvementSlot:HasItem() then
        PickupInventoryItem(self.improvementSlot:GetBagAndSlot())
    end
    self:SetImprovementSlotItem(bagId, slotIndex)
end

function ZO_SmithingImprovement:OnMouseEnterInventoryRow(quality)
    self:HighlightBoosterRow(self:GetBoosterRowForQuality(quality))
end

function ZO_SmithingImprovement:OnMouseExitInventoryRow()
    local row = self:GetRowForSelection()
    if row then
        self:HighlightBoosterRow(row)
    else
        self:ClearBoosterRowHighlight()
    end
end

function ZO_SmithingImprovement:OnSlotChanged()
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

            self:HighlightBoosterRow(row)
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

    self.awaitingLabel:SetHidden(hasItem)
    self.boosterSlot:SetHidden(not hasItem)
    self.spinner:GetControl():SetHidden(not hasItem)

    if hasItem then
        self.resultTooltip:SetHidden(false)
        self.resultTooltip:ClearLines()
		self:SetupResultTooltip(self:GetCurrentImprovementParams())
    else
        self.resultTooltip:SetHidden(true)
    end

    self.inventory:HandleVisibleDirtyEvent()
end

function ZO_SmithingImprovement:Improve()
	self:SharedImprove("CONFIRM_IMPROVE_ITEM")
end

do
    local function PlayRowForward(row)
        row.fadeAnimation:PlayForward()
        row.fromLabel.fadeAnimation:PlayForward()
        row.toLabel.fadeAnimation:PlayForward()
    end

    local function PlayRowBackward(row)
        row.fadeAnimation:PlayBackward()
        row.fromLabel.fadeAnimation:PlayBackward()
        row.toLabel.fadeAnimation:PlayBackward()
    end

    function ZO_SmithingImprovement:HighlightBoosterRow(rowToHighlight)
        for _, row in ipairs(self.rows) do
            if row ~= rowToHighlight then
                PlayRowBackward(row)
            end
        end

        PlayRowForward(rowToHighlight)
    end

    function ZO_SmithingImprovement:ClearBoosterRowHighlight()
        for _, row in ipairs(self.rows) do
            PlayRowForward(row)
        end
    end
end

function ZO_SmithingImprovement:SetupResultTooltip(...)
    self.resultTooltip:SetSmithingImprovementResult(...)
end

ZO_SmithingImprovementInventory = ZO_CraftingInventory:Subclass()

function ZO_SmithingImprovementInventory:New(...)
    return ZO_CraftingInventory.New(self, ...)
end

function ZO_SmithingImprovementInventory:Initialize(owner, control, ...)
    ZO_CraftingInventory.Initialize(self, control, ...)

    local infoBar = control:GetNamedChild("InfoBar")
    local backpack = control:GetNamedChild("Backpack")

    infoBar:ClearAnchors()
    infoBar:SetAnchor(TOPLEFT, backpack, BOTTOMLEFT, 0, 145)
    infoBar:SetAnchor(TOPRIGHT, backpack, BOTTOMRIGHT, 0, 145)

    self.owner = owner
    self.noItemsLabel = control:GetNamedChild("NoItemsLabel")

    self:SetFilters{
        self:CreateNewTabFilterData(ZO_SMITHING_IMPROVEMENT_SHARED_FILTER_TYPE_ARMOR, GetString("SI_ITEMFILTERTYPE", ITEMFILTERTYPE_ARMOR), "EsoUI/Art/Inventory/inventory_tabIcon_armor_up.dds", "EsoUI/Art/Inventory/inventory_tabIcon_armor_down.dds", "EsoUI/Art/Inventory/inventory_tabIcon_armor_over.dds", "EsoUI/Art/Inventory/inventory_tabIcon_armor_disabled.dds", CanSmithingApparelPatternsBeCraftedHere),
        self:CreateNewTabFilterData(ZO_SMITHING_IMPROVEMENT_SHARED_FILTER_TYPE_WEAPONS, GetString("SI_ITEMFILTERTYPE", ITEMFILTERTYPE_WEAPONS), "EsoUI/Art/Inventory/inventory_tabIcon_weapons_up.dds", "EsoUI/Art/Inventory/inventory_tabIcon_weapons_down.dds", "EsoUI/Art/Inventory/inventory_tabIcon_weapons_over.dds", "EsoUI/Art/Inventory/inventory_tabIcon_weapons_disabled.dds", CanSmithingWeaponPatternsBeCraftedHere),
    }
end

function ZO_SmithingImprovementInventory:IsLocked(bagId, slotIndex)
    return ZO_CraftingInventory.IsLocked(self, bagId, slotIndex) or self.owner:IsSlotted(bagId, slotIndex)
end

function ZO_SmithingImprovementInventory:ChangeFilter(filterData)
    ZO_CraftingInventory.ChangeFilter(self, filterData)

    self.filterType = filterData.descriptor

    if self.filterType == ZO_SMITHING_IMPROVEMENT_SHARED_FILTER_TYPE_ARMOR then
        self.noItemsLabel:SetText(GetString(SI_SMITHING_IMPROVE_NO_ARMOR))
    elseif self.filterType == ZO_SMITHING_IMPROVEMENT_SHARED_FILTER_TYPE_WEAPONS then
        self.noItemsLabel:SetText(GetString(SI_SMITHING_IMPROVE_NO_WEAPONS))
    end

    self.owner:OnFilterChanged(self.filterType)
    self:HandleDirtyEvent()
end

function ZO_SmithingImprovementInventory:Refresh(data)
    local validItemIds = self:EnumerateInventorySlotsAndAddToScrollData(ZO_SharedSmithingImprovement_CanItemBeImproved, ZO_SharedSmithingImprovement_DoesItemPassFilter, self.filterType, data)
    self.owner:OnInventoryUpdate(validItemIds)

    self.noItemsLabel:SetHidden(#data > 0)
end

function ZO_SmithingImprovementInventory:ShowAppropriateSlotDropCallouts(bagId, slotIndex)
    self.owner:ShowAppropriateSlotDropCallouts()
end

function ZO_SmithingImprovementInventory:HideAllSlotDropCallouts()
    self.owner:HideAllSlotDropCallouts()
end

function ZO_SmithingImprovementInventory:AddListDataTypes()
    local defaultSetup = self:GetDefaultTemplateSetupFunction()

    local function OnMouseEnter(rowControl)
        self.owner:OnMouseEnterInventoryRow(rowControl.quality)
    end

    local function OnMouseExit(rowControl)
        self.owner:OnMouseExitInventoryRow(rowControl.quality)
    end

    local function RowSetup(rowControl, data)
        defaultSetup(rowControl, data)
        rowControl.quality = data.quality
        if not rowControl.isMouseHooked then
            rowControl.isMouseHooked = true

            ZO_PreHookHandler(rowControl, "OnMouseEnter", OnMouseEnter)
            ZO_PreHookHandler(rowControl, "OnMouseExit", OnMouseExit)
        end
    end

    ZO_ScrollList_AddDataType(self.list, self:GetScrollDataType(), "ZO_CraftingInventoryComponentRow", 52, RowSetup, nil, nil, ZO_InventorySlot_OnPoolReset)
end
﻿local ZO_ApplyEnchant_Gamepad = ZO_InventoryItemImprovement_Gamepad:Subclass()

function ZO_ApplyEnchant_Gamepad:New(...)
    local screen = ZO_Object.New(self)
    screen:Initialize(...)
    return screen
end

function ZO_ApplyEnchant_Gamepad:Initialize(control)
    local function IsItemEnchantment(enchantBag, enchantSlotIndex) 
        return CanItemTakeEnchantment(self.itemBag, self.itemIndex, enchantBag, enchantSlotIndex) 
    end

    local function SortComparator(left, right)
        return left.name < right.name
    end

    ZO_InventoryItemImprovement_Gamepad.Initialize(
        self, 
        control, 
        GetString(SI_ENCHANT_TITLE),
        "enchantGamepad",
        GetString(SI_ENCHANT_SELECT),
        GetString(SI_ENCHANT_NONE_FOUND),
        GetString(SI_ENCHANT_CONFIRM),
        SOUNDS.INVENTORY_ITEM_APPLY_ENCHANT,
        IsItemEnchantment,
        SortComparator)
end

function ZO_ApplyEnchant_Gamepad:SetupScene()
    APPLY_ENCHANT_SCENE_GAMEPAD = ZO_Scene:New(self.sceneName, SCENE_MANAGER)
    SYSTEMS:RegisterGamepadRootScene("enchant", APPLY_ENCHANT_SCENE_GAMEPAD)
end

function ZO_ApplyEnchant_Gamepad:OnSelectionChanged(list, selectedData, oldSelectedData)
    if selectedData then
        self.improvementKitBag = selectedData.bag
        self.improvementKitIndex = selectedData.index
    end
end

function ZO_ApplyEnchant_Gamepad:OnTargetChanged(list, targetData, oldTargetData, reachedTarget, targetSelectedIndex)
    if targetData then
        GAMEPAD_TOOLTIPS:LayoutPendingEnchantedItem(GAMEPAD_LEFT_TOOLTIP, self.itemBag, self.itemIndex, targetData.bag, targetData.index)
        GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_RIGHT_TOOLTIP, self.itemBag, self.itemIndex, ZO_ENCHANT_DIFF_REMOVE)
    end
end

function ZO_ApplyEnchant_Gamepad:ClearTooltip()
    GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
    self:InitializeDefaultTooltip(GAMEPAD_RIGHT_TOOLTIP)
end

function ZO_ApplyEnchant_Gamepad:InitializeDefaultTooltip(tooltip)
    GAMEPAD_TOOLTIPS:ClearTooltip(tooltip)

    if self.itemBag and self.itemIndex then
        GAMEPAD_TOOLTIPS:LayoutBagItem(tooltip, self.itemBag, self.itemIndex, ZO_ENCHANT_DIFF_NONE)

        if self.itemBag == BAG_WORN then
            ZO_InventoryUtils_UpdateTooltipEquippedIndicatorText(tooltip, self.itemIndex)
        else
            GAMEPAD_TOOLTIPS:ClearStatusLabel(tooltip)
        end
    end
end

function ZO_ApplyEnchant_Gamepad:CheckEmptyList()
    ZO_InventoryItemImprovement_Gamepad.CheckEmptyList(self)
    if self.itemList:GetNumItems() == 0 then
        self:InitializeDefaultTooltip(GAMEPAD_LEFT_TOOLTIP) -- reset left tooltip to original result if we don't have any applicable enchantments
    end
end

function ZO_ApplyEnchant_Gamepad:ResetTooltipToDefault()
    self:InitializeDefaultTooltip(GAMEPAD_LEFT_TOOLTIP) -- Enchantment result defaults to the same item
    self:InitializeDefaultTooltip(GAMEPAD_RIGHT_TOOLTIP)
end

do
    local FORMATTED_VETERAN_RANK_ICON = zo_iconFormat(GetGamepadVeteranRankIcon(), 48, 48)
    function ZO_ApplyEnchant_Gamepad:AddItemKitSubLabelsToCurrentEntry(itemLink)
        local minLevel, maxLevel, minVeteranRank, maxVeteranRank = GetItemLinkGlyphMinMaxLevels(itemLink)
        if minVeteranRank then
             local vetRankString
             if minVeteranRank ~= maxVeteranRank then
                vetRankString = zo_strformat(SI_ENCHANTING_GLYPH_REQUIRED_VETERAN_RANK_GAMEPAD, FORMATTED_VETERAN_RANK_ICON, minVeteranRank, maxVeteranRank)
            else
                vetRankString = zo_strformat(SI_ENCHANTING_GLYPH_REQUIRED_SINGLE_VETERAN_RANK_GAMEPAD, FORMATTED_VETERAN_RANK_ICON, minVeteranRank)
            end
            self:AddSubLabel(vetRankString)
        else
            local levelString
            if minLevel ~= maxLevel then
                levelString = zo_strformat(SI_ENCHANTING_GLYPH_REQUIRED_LEVEL, minLevel, maxLevel)
            else
                levelString = zo_strformat(SI_ENCHANTING_GLYPH_REQUIRED_SINGLE_LEVEL, minLevel)
            end
            self:AddSubLabel(levelString)
        end
    end
end

function ZO_ApplyEnchant_Gamepad:BuildEnumeratedImprovementKitList(itemList)
    for _,v in pairs(itemList) do
        v.name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(v.bag, v.index))
        table.insert(self.enumeratedList, v)
    end
end

function ZO_ApplyEnchant_Gamepad:GetItemName(itemInfo)
    return itemInfo.name
end

function ZO_ApplyEnchant_Gamepad:PerformItemImprovement()
   EnchantItem(self.itemBag, self.itemIndex, self.improvementKitBag, self.improvementKitIndex)
end

function ZO_ApplyEnchant_Gamepad:GetItemTemplateName()
    return "ZO_Gamepad_ApplyEnchant_ItemTemplate"
end

--[[ Globals ]]--
function ZO_Gamepad_ApplyEnchant_OnInitialize(control)
    APPLY_ENCHANT_GAMEPAD = ZO_ApplyEnchant_Gamepad:New(control)
    SYSTEMS:RegisterGamepadObject("enchant", APPLY_ENCHANT_GAMEPAD)
end
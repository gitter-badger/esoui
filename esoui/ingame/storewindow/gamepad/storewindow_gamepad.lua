GAMEPAD_STORE_SCENE_NAME = "gamepad_store"

ZO_GamepadStoreManager = ZO_Object.MultiSubclass(ZO_SharedStoreManager, ZO_Gamepad_ParametricList_Screen)

function ZO_GamepadStoreManager:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

local function OnOpenStore()
    if IsInGamepadPreferredMode() then
        STORE_WINDOW_GAMEPAD:SetActiveComponents(ZO_MODE_STORE_BUY, ZO_MODE_STORE_BUY_BACK, ZO_MODE_STORE_SELL, ZO_MODE_STORE_REPAIR)
        SCENE_MANAGER:Show(GAMEPAD_STORE_SCENE_NAME)
    end
end

local function OnCloseStore()
    if IsInGamepadPreferredMode() then
        SCENE_MANAGER:Hide(GAMEPAD_STORE_SCENE_NAME)
    end
end

local DONT_ACTIVATE_LIST_ON_SHOW = false

function ZO_GamepadStoreManager:Initialize(control)
    self.control = control
    self.sceneName = GAMEPAD_STORE_SCENE_NAME
    
    GAMEPAD_VENDOR_SCENE = ZO_InteractScene:New(self.sceneName, SCENE_MANAGER, STORE_INTERACTION)

    ZO_Gamepad_ParametricList_Screen.Initialize(self, control, ZO_GAMEPAD_HEADER_TABBAR_CREATE, DONT_ACTIVATE_LIST_ON_SHOW, GAMEPAD_VENDOR_SCENE)

    self.spinner = control:GetNamedChild("SpinnerContainer")
    self.spinner:InitializeSpinner()

    self.control:RegisterForEvent(EVENT_OPEN_STORE, OnOpenStore)
    self.control:RegisterForEvent(EVENT_CLOSE_STORE, OnCloseStore)

    local OnCurrencyChanged = function()
        if not self.control:IsControlHidden() then
            self:RefreshHeaderData()
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.currentKeybindButton)
        end
    end

    local OnFailedRepair = function(eventId, reason)
        self:FailedRepairMessageBox(reason)
    end

    local OnBuySuccess = function(...)
        if not self.control:IsControlHidden() then
            ZO_StoreManager_OnPurchased(...)
        end
    end

    local OnSellSuccess = function(eventId, itemName, quantity, money)
        if not self.control:IsControlHidden() then
            PlaySound(SOUNDS.ITEM_MONEY_CHANGED)
        end
    end

    local OnBuyBackSuccess = function(eventId, itemName, itemQuantity, money, itemSoundCategory)
        if(itemSoundCategory == ITEM_SOUND_CATEGORY_NONE) then
            -- Fall back sound if there was no other sound to play
            PlaySound(SOUNDS.ITEM_MONEY_CHANGED)
        else
            PlayItemSound(itemSoundCategory, ITEM_SOUND_ACTION_ACQUIRE)
        end    
    end

    self.control:RegisterForEvent(EVENT_MONEY_UPDATE, OnCurrencyChanged)
    self.control:RegisterForEvent(EVENT_ALLIANCE_POINT_UPDATE, OnCurrencyChanged)
    self.control:RegisterForEvent(EVENT_TELVAR_STONE_UPDATE, OnCurrencyChanged)
    self.control:RegisterForEvent(EVENT_BUY_RECEIPT, OnBuySuccess)
    self.control:RegisterForEvent(EVENT_SELL_RECEIPT, OnSellSuccess)
    self.control:RegisterForEvent(EVENT_BUYBACK_RECEIPT, OnBuyBackSuccess)
    self.control:RegisterForEvent(EVENT_ITEM_REPAIR_FAILURE, OnFailedRepair)

    self:InitializeKeybindStrip()
    self.components = {}

    local function OnItemRepaired(bagId, slotIndex)
        if self.isRepairingAll then
            if self.numberItemsRepairing > 0 then
                self.numberItemsRepairing = self.numberItemsRepairing - 1
                if self.numberItemsRepairing == 0 then
                    self:RepairMessageBox()
                    self.isRepairingAll = false
                end
            end
        else
            self:RepairMessageBox(bagId, slotIndex)
        end

        local activeComponent = self:GetActiveComponent()
        if activeComponent then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(activeComponent.keybindStripDescriptor)
        end
    end

    SHARED_INVENTORY:RegisterCallback("ItemRepaired", OnItemRepaired)
end

function ZO_GamepadStoreManager:SetDeferredStartingMode(mode)
    self.deferredStartingMode = mode
end

function ZO_GamepadStoreManager:GetActiveComponent()
    return self.activeComponent
end

function ZO_GamepadStoreManager:GetCurrentMode()
    return self.activeComponent and self.activeComponent:GetStoreMode() or nil
end

function ZO_GamepadStoreManager:SetActiveComponents(...)
    self.activeComponents = {}
    for i = 1, select("#", ...) do
        local componentMode = select(i, ...)
        local component = self.components[componentMode]
        component:Refresh()
        table.insert(self.activeComponents, component)
    end
    self:RebuildHeaderTabs()
end

function ZO_GamepadStoreManager:AddComponent(component)
    self.components[component:GetStoreMode()] = component
end

function ZO_GamepadStoreManager:OnStateChanged(oldState, newState)
    if newState == SCENE_SHOWING then
        self:InitializeStore()
        self:SetMode(self.deferredStartingMode or self.activeComponents[1]:GetStoreMode())
        self.deferredStartingMode = nil
        ZO_GamepadGenericHeader_Activate(self.header)
    elseif newState == SCENE_HIDING then
        self.spinner:DetachFromListEntry()
        GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_LEFT_TOOLTIP)
    elseif newState == SCENE_HIDDEN then
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        ZO_GamepadGenericHeader_Deactivate(self.header)
    end
end

function ZO_GamepadStoreManager:GetSpinnerValue()
    return self.spinner:GetValue()
end

function ZO_GamepadStoreManager:SetupSpinner(max, value, unitPrice, currencyType)
    self.spinner:SetMinMax(1, max)
    self.spinner:SetValue(value)
    self.spinner:SetupCurrency(unitPrice, currencyType)
end

function ZO_GamepadStoreManager:SetQuantitySpinnerActive(activate, list, ignoreInvalidCost)
    if activate then
        ZO_GamepadGenericHeader_Deactivate(self.header)

        list:RefreshVisible()
        list:SetDirectionalInputEnabled(false)
        self.spinner:AttachToTargetListEntry(list)
        self.spinner:SetIgnoreInvalidCost(ignoreInvalidCost)
    else
        self.spinner:DetachFromListEntry()
        ZO_GamepadGenericHeader_Activate(self.header)

        list:RefreshVisible()
        list:SetDirectionalInputEnabled(true)
    end
end

function ZO_GamepadStoreManager:GetRepairAllKeybind()
    return self.repairAllKeybind
end

function ZO_GamepadStoreManager:InitializeKeybindStrip()
    self.repairAllKeybind = {
            name = function()
                local goldIcon = zo_iconFormat(ZO_GAMEPAD_CURRENCY_ICON_GOLD_TEXTURE, 24, 24)
                local cost = GetRepairAllCost()
                if GetCarriedCurrencyAmount(CURT_MONEY) >= cost then
                    return zo_strformat(SI_REPAIR_ALL_KEYBIND_TEXT, ZO_CurrencyControl_FormatCurrency(cost), goldIcon)
                end
                return zo_strformat(SI_REPAIR_ALL_KEYBIND_TEXT, ZO_ERROR_COLOR:Colorize(ZO_CurrencyControl_FormatCurrency(cost)), goldIcon)
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function() return GetRepairAllCost() > 0 end,
            enabled = function() return GetRepairAllCost() <= GetCarriedCurrencyAmount(CURT_MONEY) end,
            callback = function()
                local cost = GetRepairAllCost()
                if cost > GetCarriedCurrencyAmount(CURT_MONEY) then
                    self:FailedRepairMessageBox()
                else
                    self.isRepairingAll = true
                    self.numberItemsRepairing = self.components[ZO_MODE_STORE_REPAIR]:GetNumRepairItems()
                    RepairAll()
                    PlaySound(SOUNDS.INVENTORY_ITEM_REPAIR)
                end
            end,
    }
end

function ZO_GamepadStoreManager:RebuildHeaderTabs()
    local function OnCategoryChanged(component)
        if self.activeComponent ~= component then
            self:ShowComponent(component)
        end
    end
    
    local function OnActivatedChanged(list, activated)
        if activated then
            local component = self.activeComponents[list:GetSelectedIndex()]
            if not self.activeComponent or self.activeComponent ~= component then
                self:ShowComponent(component)
            end
        else
            if not SCENE_MANAGER:IsShowing(self.sceneName) then
                self:HideActiveComponent()
            end
        end
        ZO_GamepadOnDefaultScrollListActivatedChanged(list, activated)
    end

    local tabsTable = {}
    for _, component in ipairs(self.activeComponents) do
        table.insert(tabsTable, {
            text = component:GetTabText(),
            callback = function() OnCategoryChanged(component) end,
        })
    end
    
    self.headerData = 
    {
        tabBarEntries = tabsTable,
        activatedCallback = function(...) OnActivatedChanged(...) end,
    }
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
end

function ZO_GamepadStoreManager:ShowComponent(component)
    if SCENE_MANAGER:IsShowing(self.sceneName) then
        self:HideActiveComponent()
        self.activeComponent = component
        component:Show()
        self:RefreshHeaderData()
    end
end

function ZO_GamepadStoreManager:HideActiveComponent()
    if self.activeComponent then
        self.activeComponent:Hide()
        self.activeComponent = nil
    end
end

do
    local function UpdateCapacityString()
        return zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK))
    end

    local function UpdateGold(control)
        ZO_CurrencyControl_SetSimpleCurrency(control, CURT_MONEY, GetCarriedCurrencyAmount(CURT_MONEY), ZO_GAMEPAD_CURRENCY_OPTIONS_LONG_FORMAT)
        return true
    end

    local function UpdateAlliancePoints(control)
        ZO_CurrencyControl_SetSimpleCurrency(control, CURT_ALLIANCE_POINTS, GetCarriedCurrencyAmount(CURT_ALLIANCE_POINTS), ZO_GAMEPAD_CURRENCY_OPTIONS_LONG_FORMAT)
        return true
    end

    local function UpdateTelvarStones(control)
        ZO_CurrencyControl_SetSimpleCurrency(control, CURT_TELVAR_STONES, GetCarriedCurrencyAmount(CURT_TELVAR_STONES), ZO_GAMEPAD_CURRENCY_OPTIONS_LONG_FORMAT)
        return true
    end

    local function UpdateRidingTrainingCost(control)
        ZO_CurrencyControl_SetSimpleCurrency(control, CURT_MONEY, STABLE_MANAGER.trainingCost, ZO_GAMEPAD_CURRENCY_OPTIONS_LONG_FORMAT, nil, not STABLE_MANAGER:CanAffordTraining())
        return true
    end

    local function GetTransactionLabelString() 
        return GetString(FENCE_GAMEPAD:IsLaundering() and SI_GAMEPAD_FENCE_LAUNDER_LIMIT or SI_GAMEPAD_FENCE_SELL_LIMIT)
    end

    local function GetTransactionValueString()
        local mode = STORE_WINDOW_GAMEPAD:GetCurrentMode()
        local usedTransactions = FENCE_MANAGER:GetNumTransactionsUsed(mode)
        local totalTransactions = FENCE_MANAGER:GetNumTotalTransactions(mode)
        if usedTransactions == totalTransactions then
            return ZO_ERROR_COLOR:Colorize(zo_strformat(SI_GAMEPAD_FENCE_TRANSACTION_COUNT, usedTransactions, totalTransactions))
        else
            return zo_strformat(SI_GAMEPAD_FENCE_TRANSACTION_COUNT, usedTransactions, totalTransactions)
        end
    end

    local CAPACITY_HEADER_DATA =
    {
        headerText = GetString(SI_GAMEPAD_INVENTORY_CAPACITY),
        text = UpdateCapacityString
    }
    local GOLD_HEADER_DATA =
    {
        headerText = GetString(SI_GAMEPAD_VENDOR_GOLD),
        text = UpdateGold
    }
    local AP_HEADER_DATA =
    {
        headerText = GetString(SI_GAMEPAD_VENDOR_ALLIANCE_POINTS),
        text = UpdateAlliancePoints
    }
    local TELVAR_STONE_HEADER_DATA =
    {
        headerText = GetString(SI_CURRENCY_TELVAR_STONES),
        text = UpdateTelvarStones
    }

    local RIDING_TRAINING_COST_HEADER_DATA =
    {
        headerText = GetString(SI_GAMEPAD_STABLE_TRAINING_COST_HEADER),
        text = UpdateRidingTrainingCost
    }

    local LAUNDER_TRANSACTION_HEADER_DATA =
    {
        headerText = GetTransactionLabelString,
        text = GetTransactionValueString
    }

    local g_pendingHeaderData = {}
    function ZO_GamepadStoreManager:RefreshHeaderData()
        if not self.activeComponent then
            return
        end

        ZO_SharedStoreManager.RefreshCurrency(self)

        ZO_ClearTable(g_pendingHeaderData)
        local mode = self:GetCurrentMode()

        local isStable = mode == ZO_MODE_STORE_STABLE
        local showCapacity = not isStable
        
        if mode == ZO_MODE_STORE_BUY then
            local usedFilterTypes = ZO_StoreManager_GetStoreFilterTypes()
            if usedFilterTypes[ITEMFILTERTYPE_COLLECTIBLE] and NonContiguousCount(usedFilterTypes) == 1 then
                showCapacity = false
            end
        end

        if showCapacity then
            table.insert(g_pendingHeaderData, CAPACITY_HEADER_DATA)
        end

        -- mirroring PC here:
        -- Buy screen shows the appropriate currency for that screen (gold or AP)
        -- Sell shows both, always
        -- Repair and Buyback show gold and not AP, always

        local hideGold = false
        local hideAP = false
        local hideTelvarStones = false

        if mode == ZO_MODE_STORE_BUY then
            hideGold = not self.storeUsesMoney
            hideAP = not self.storeUsesAP
            hideTelvarStones = not self.storeUsesTelvarStones
        else
            hideAP = true
            hideTelvarStones = true
        end

        if not isStable then
            local cost = GetRepairAllCost()
            if cost > 0 then
                hideGold = false
            end
        end

        if not hideGold then
            table.insert(g_pendingHeaderData, GOLD_HEADER_DATA)
        end

        if not hideAP then
            table.insert(g_pendingHeaderData, AP_HEADER_DATA)
        end

        if not hideTelvarStones then
            table.insert(g_pendingHeaderData, TELVAR_STONE_HEADER_DATA)
        end

        if isStable then
            table.insert(g_pendingHeaderData, RIDING_TRAINING_COST_HEADER_DATA)
        end

        if mode == ZO_MODE_STORE_SELL_STOLEN or mode == ZO_MODE_STORE_LAUNDER then
            table.insert(g_pendingHeaderData, LAUNDER_TRANSACTION_HEADER_DATA)
        end

        local data = g_pendingHeaderData[1]
        self.headerData.data1HeaderText = data and data.headerText or nil
        self.headerData.data1Text = data and data.text or nil
        local data = g_pendingHeaderData[2]
        self.headerData.data2HeaderText = data and data.headerText or nil
        self.headerData.data2Text = data and data.text or nil
        local data = g_pendingHeaderData[3]
        self.headerData.data3HeaderText = data and data.headerText or nil
        self.headerData.data3Text = data and data.text or nil
        local data = g_pendingHeaderData[4]
        self.headerData.data4HeaderText = data and data.headerText or nil
        self.headerData.data4Text = data and data.text or nil

        ZO_GamepadGenericHeader_RefreshData(self.header, self.headerData)
    end
end

function ZO_GamepadStoreManager:UpdateRightTooltip(list, mode)
    GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_RIGHT_TOOLTIP)

    local selectedData = list:GetTargetData()

    local itemLink = nil
    if selectedData then
        if mode == ZO_MODE_STORE_BUY and selectedData.entryType ~= STORE_ENTRY_TYPE_COLLECTIBLE then
            itemLink = selectedData.itemLink
        elseif mode == ZO_MODE_STORE_BUY_BACK then
            itemLink = selectedData.itemLink
        elseif mode == ZO_MODE_STORE_SELL then
            itemLink = GetItemLink(selectedData.bagId, selectedData.slotIndex)
        end
    end

    if not itemLink then
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
        return
    end

    local equipType = GetItemLinkEquipType(itemLink)
    local equipSlot = ZO_InventoryUtils_GetEquipSlotForEquipType(equipType)

    if equipSlot and GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_RIGHT_TOOLTIP, BAG_WORN, equipSlot) then 
        ZO_InventoryUtils_UpdateTooltipEquippedIndicatorText(GAMEPAD_RIGHT_TOOLTIP, equipSlot)
    else
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
    end
end

function ZO_GamepadStoreManager:SetMode(mode)
    for i, component in ipairs(self.activeComponents) do
        if component:GetStoreMode() == mode then
            ZO_GamepadGenericHeader_SetActiveTabIndex(self.header, i)
            break
        end
    end
end

function ZO_GamepadStoreManager:RepairMessageBox(bagId, slotId)
    if not bagId then
        local message = zo_strformat(SI_GAMEPAD_REPAIR_ALL_SUCCESS)
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, message)
    else
        local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(bagId, slotId))
        local message = zo_strformat(SI_GAMEPAD_REPAIR_ITEM_SUCCESS, name)
        if message then
            ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, message)
        end
    end
end

function ZO_GamepadStoreManager:FailedRepairMessageBox(reason)
    local message = ""
    if reason == ITEM_REPAIR_ALREADY_REPAIRED then
        message = zo_strformat(SI_ITEMREPAIRREASON1)
    elseif reason == ITEM_REPAIR_CANT_AFFORD_REPAIR then
        message = zo_strformat(SI_ITEMREPAIRREASON2)
    elseif reason == nil then
        message = zo_strformat(SI_REPAIR_ALL_CANNOT_AFFORD)
    end
    if message ~= "" then
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, message)
        PlaySound(SOUNDS.GENERAL_ALERT_ERROR)
    end
end

function ZO_GamepadStoreManager:Show()
    SCENE_MANAGER:Show(self.sceneName)
end

function ZO_GamepadStoreManager:Hide()
    SCENE_MANAGER:Hide(self.sceneName)
end

-------------------
-- Global functions
-------------------

function ZO_Store_OnInitialize_Gamepad(control)
    STORE_WINDOW_GAMEPAD = ZO_GamepadStoreManager:New(control)
    STORE_WINDOW_GAMEPAD:AddComponent(ZO_GamepadStoreBuy:New(STORE_WINDOW_GAMEPAD))
    STORE_WINDOW_GAMEPAD:AddComponent(ZO_GamepadStoreBuyback:New(STORE_WINDOW_GAMEPAD))
    STORE_WINDOW_GAMEPAD:AddComponent(ZO_GamepadStoreSell:New(STORE_WINDOW_GAMEPAD))
    STORE_WINDOW_GAMEPAD:AddComponent(ZO_GamepadStoreRepair:New(STORE_WINDOW_GAMEPAD))
end

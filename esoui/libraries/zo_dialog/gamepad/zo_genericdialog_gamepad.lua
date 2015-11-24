local GAMEPAD_DIALOG_SHOWING = false

----------------------
-- Helper Functions --
----------------------

local DialogKeybindStripDescriptor = ZO_Object:Subclass()

function DialogKeybindStripDescriptor:New()
    local obj = ZO_Object.New(self)
    obj:Initialize()
    return obj
end

function DialogKeybindStripDescriptor:Initialize()
    -- dialog buttons expect the dialog to be the callbackArg
    self.callback = function(pressState)
        if self.buttonCallback then
            self.buttonCallback(self.dialog, pressState)
        end
    end
    self.visible = function()
        if self.buttonVisible then
            if type(self.buttonVisible) == "function" then
                return self.buttonVisible(self.dialog)
            else
                return self.buttonVisible
            end
        else 
            return true
        end
    end
    self:Reset()
end

function DialogKeybindStripDescriptor:Reset()
    self.buttonVisible = nil
    self.buttonCallback = nil
    self.name = nil
    self.dialog = nil
    self.keybind = nil
    self.sound = nil
    self.alignment = KEYBIND_STRIP_ALIGN_LEFT
    self.enabled = nil
    self.handlesKeyUp = nil
    self.onShowCooldown = nil
    self.cooldown = nil
end

function DialogKeybindStripDescriptor:SetAlignment(alignment)
    if alignment then
        self.alignment = alignment
    end
end

function DialogKeybindStripDescriptor:SetButtonCallback(buttonCallback)
    self.buttonCallback = buttonCallback
end

-- keybinds expect text to be under 'name' and already looked up.
function DialogKeybindStripDescriptor:SetText(text)
    self.name = text
    if(type(self.name) == "number") then
        self.name = GetString(self.name)
    end
end

function DialogKeybindStripDescriptor:SetDialog(dialog)
    self.dialog = dialog
end

function DialogKeybindStripDescriptor:SetVisible(visible)
    self.buttonVisible = visible
end

function DialogKeybindStripDescriptor:SetEthereal(ethereal)
    self.ethereal = ethereal
end

function DialogKeybindStripDescriptor:SetEnabled(enabled)
    self.enabled = enabled
end

function DialogKeybindStripDescriptor:SetHandlesKeyUp(handlesKeyUp)
    self.handlesKeyUp = handlesKeyUp
end

function DialogKeybindStripDescriptor:SetKeybind(keybind, index)
    if keybind then
        self.keybind = keybind
    else
        if index == 1 then
            self.keybind = "DIALOG_PRIMARY"
        elseif index == 2 then
            self.keybind = "DIALOG_NEGATIVE"
        end
    end
end

function DialogKeybindStripDescriptor:SetSound(sound)
    self.sound = sound
end

function DialogKeybindStripDescriptor:SetOnShowCooldown(timeMs)
    self.onShowCooldown = timeMs
end

function DialogKeybindStripDescriptor:GetOnShowCooldown()
    return self.onShowCooldown
end

function DialogKeybindStripDescriptor:SetDefaultSoundFromKeybind(twoOrMoreButtons)
    if twoOrMoreButtons then
        if self.keybind == "DIALOG_PRIMARY" then
            self.sound = SOUNDS.DIALOG_ACCEPT
        elseif self.keybind == "DIALOG_NEGATIVE" then
            self.sound = SOUNDS.DIALOG_DECLINE
        end
    end
end

local function MakeKeybindStripDescriptor(pool)
    local descriptor = DialogKeybindStripDescriptor:New()
    return descriptor
end

local function ResetKeybindStripDescriptor(descriptor)
    descriptor:Reset()
end

local g_keybindStripDescriptors = ZO_ObjectPool:New(MakeKeybindStripDescriptor, ResetKeybindStripDescriptor)
local g_keybindGroupDesc = {}
local g_keybindState = nil

local function TryRefreshKeybind(dialog, keybindDesc, buttonData, twoOrMoreButtons, index)
    if(dialog.textParams ~= nil and dialog.textParams.buttonTextOverrides ~= nil and dialog.textParams.buttonTextOverrides[index] ~= nil) then
        keybindDesc:SetText(dialog.textParams.buttonTextOverrides[index])
    else
        keybindDesc:SetText(buttonData.text)
    end

    if(dialog.textParams ~= nil and dialog.textParams.buttonKeybindOverrides ~= nil and dialog.textParams.buttonKeybindOverrides[index] ~= nil) then
        keybindDesc:SetKeybind(dialog.textParams.buttonKeybindOverrides[index], index)
    else
        keybindDesc:SetKeybind(buttonData.keybind, index)
    end
                
    keybindDesc:SetDialog(dialog)
    keybindDesc:SetAlignment(buttonData.alignment)
    keybindDesc:SetButtonCallback(buttonData.callback)
    keybindDesc:SetVisible(buttonData.visible)
    keybindDesc:SetEthereal(buttonData.ethereal)
    keybindDesc:SetEnabled(buttonData.enabled)
	keybindDesc:SetOnShowCooldown(buttonData.onShowCooldown)
    keybindDesc:SetHandlesKeyUp(buttonData.handlesKeyUp)

    if buttonData.clickSound then
        keybindDesc:SetSound(buttonData.clickSound)
    else
        keybindDesc:SetDefaultSoundFromKeybind(twoOrMoreButtons)
    end
end

local function TryShowKeybinds(dialog)
    ZO_ClearNumericallyIndexedTable(g_keybindGroupDesc)

    local buttons = dialog.info.buttons
    local numButtons = buttons and #buttons or 0
    local dialogType = dialog.info.gamepadInfo.dialogType
    if numButtons > 0 then
        for index, value in ipairs(buttons) do
            if(type(value) == "table") then
                local keybindDesc = g_keybindStripDescriptors:AcquireObject()

                TryRefreshKeybind(dialog, keybindDesc, value, (numButtons > 1), index)

                table.insert(g_keybindGroupDesc, keybindDesc)
            end
        end
    end

    if(#g_keybindGroupDesc > 0) then
        KEYBIND_STRIP:AddKeybindButtonGroup(g_keybindGroupDesc, g_keybindState)

        for _, keybindDesc in ipairs(g_keybindGroupDesc) do
            local onShowCooldown = keybindDesc:GetOnShowCooldown()
            if onShowCooldown then
                KEYBIND_STRIP:TriggerCooldown(keybindDesc, onShowCooldown, g_keybindState)
            end
        end
    end
end

local function TryRefreshKeybinds(dialog)
    local buttons = dialog.info.buttons
    local numButtons = buttons and #buttons or 0
    local dialogType = dialog.info.gamepadInfo.dialogType
    if numButtons > 0 then
        for index, value in ipairs(buttons) do
            if(type(value) == "table") then
                local keybindDesc = g_keybindGroupDesc[index]
                if keybindDesc then
                    TryRefreshKeybind(dialog, keybindDesc, value, (numButtons > 1), index)
                end
            end
        end
    end

    KEYBIND_STRIP:UpdateKeybindButtonGroup(g_keybindGroupDesc, g_keybindState)
end

local function TryRemoveKeybinds()
    if(#g_keybindGroupDesc > 0) then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(g_keybindGroupDesc, g_keybindState)
    end
end

function ZO_GenericGamepadDialog_RefreshKeybinds(dialog)
    TryRefreshKeybinds(dialog)
end

function ZO_GenericGamepadDialog_UpdateDirectionalInput(dialog)
    --[[Different dialogs have different needs for input blocking. Most will want to eat all input so you don't end up scrolling lists
    below the dialog or moving characters. Some want the right stick to pass through to control tooltip scrolling on the scene below. In that case
    add allowRightStickPassThrough = true to the dialog's gamepadInfo table.]]--
    DIRECTIONAL_INPUT:Consume(unpack(dialog.directionalInputEaters))
    if not dialog.info.gamepadInfo.allowRightStickPassThrough then
        ZO_SCROLL_SHARED_INPUT:Consume()
    end
end

do
    local ALLOW_RIGHT_STICK = { ZO_DI_LEFT_STICK, ZO_DI_DPAD }
    local CONSUME_ALL = { ZO_DI_LEFT_STICK, ZO_DI_RIGHT_STICK, ZO_DI_DPAD }

    function ZO_GenericGamepadDialog_SetupDirectionalInput(dialog)
        if dialog.info.gamepadInfo.allowRightStickPassThrough then
            dialog.directionalInputEaters = ALLOW_RIGHT_STICK
        else
            dialog.directionalInputEaters = CONSUME_ALL
        end
    end
end

----------------------------
-- Global Gamepad Dialogs --
----------------------------

function ZO_GenericGamepadDialog_GetControl(dialogType)
    if(dialogType == GAMEPAD_DIALOGS.BASIC) then
        return ZO_GamepadDialogBase
    elseif(dialogType == GAMEPAD_DIALOGS.PARAMETRIC) then
        return ZO_GamepadDialogPara
    elseif(dialogType == GAMEPAD_DIALOGS.COOLDOWN) then
        return ZO_GamepadDialogCool
    elseif(dialogType == GAMEPAD_DIALOGS.TRANSACTION) then
        return ZO_GamepadDialogTransaction
    elseif(dialogType == GAMEPAD_DIALOGS.CENTERED) then
        return ZO_GamepadDialogCentered
    elseif(dialogType == GAMEPAD_DIALOGS.STATIC_LIST) then
        return ZO_GamepadDialogStaticList
    end

    return nil
end

-----------------------
-- Dialog Management --
-----------------------

local function OnDialogShowing(dialog)
    GAMEPAD_DIALOG_SHOWING = true
    CALLBACK_MANAGER:FireCallbacks("OnGamepadDialogShowing")
    PushActionLayerByName(GetString(SI_KEYBINDINGS_LAYER_DIALOG))
    dialog:Activate()
    g_keybindState = KEYBIND_STRIP:PushKeybindGroupState()

    if(dialog.shouldShowTooltip) then
        ZO_GenericGamepadDialog_ShowTooltip(dialog)
    end

    dialog.hideSceneOnClose = false
end

local function OnDialogShown(dialog)
    TryShowKeybinds(dialog)

    if dialog.isShowingOnBase then
        PlaySound(SOUNDS.GAMEPAD_OPEN_WINDOW)
    else
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    end

    if dialog.info.shownCallback then
        dialog.info.shownCallback(dialog)
    end
end

local function OnDialogHiding(dialog)
    ZO_GenericGamepadDialog_HideTooltip(dialog)
    if dialog.entryList then
        dialog.entryList:Deactivate()
    end
    TryRemoveKeybinds()
end

local function OnDialogHidden(dialog)
    local releasedFromButton = dialog.releasedFromButton
    dialog.releasedFromButton = nil

    RemoveActionLayerByName(GetString(SI_KEYBINDINGS_LAYER_DIALOG))
    dialog:Deactivate()
    KEYBIND_STRIP:PopKeybindGroupState()
    g_keybindStripDescriptors:ReleaseAllObjects()

    if dialog.owningScene then
        -- In this case, the scene the dialog belongs to is being hidden
        dialog.owningScene = nil
    end

    ZO_CompleteReleaseDialogOnDialogHidden(dialog, releasedFromButton)

    if dialog.isShowingOnBase then
        PlaySound(SOUNDS.GAMEPAD_CLOSE_WINDOW)
    else
        PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
    end

    if dialog.info.finishedCallback then
        dialog.info.finishedCallback(dialog)
    end

    if dialog.hideSceneOnClose then
        SCENE_MANAGER:HideCurrentScene()
    end
    GAMEPAD_DIALOG_SHOWING = false
    CALLBACK_MANAGER:FireCallbacks("OnGamepadDialogHidden")
end

-- this always gets called
function ZO_GenericGamepadDialog_BaseSetup(dialog, title, mainText)
    local headerData = dialog.headerData
    ZO_ClearTable(headerData) -- make sure we are not bringing over header data from the previous setup.
    headerData.titleText = title
    headerData.titleTextAlignment = TEXT_ALIGN_LEFT

    dialog.mainTextControl:SetText(mainText)
    dialog.scrollIndicator:SetTexture(ZO_GAMEPAD_RIGHT_SCROLL_ICON)

    if (not ZO_GenericGamepadDialog_DefaultSetup(dialog, dialog.data)) then
        ZO_GamepadGenericHeader_Refresh(dialog.header, headerData)
    end
end

function ZO_GenericGamepadDialog_DefaultSetup(dialog, data)
    local headerData = dialog.headerData

    local needRefresh = false

    if (data) then
        if (data.data1) then
            headerData.data1HeaderText  = data.data1.header
            headerData.data1Text  = data.data1.value
            needRefresh = true
        end

        if (data.data2) then
            headerData.data2HeaderText  = data.data2.header
            headerData.data2Text  = data.data2.value
            needRefresh = true
        end

        if (data.data3) then
            headerData.data3HeaderText  = data.data3.header
            headerData.data3Text  = data.data3.value
            needRefresh = true
        end

        if (data.data4) then
            headerData.data4HeaderText  = data.data4.header
            headerData.data4Text  = data.data4.value
            needRefresh = true
        end
    end

    if (needRefresh) then
        ZO_GamepadGenericHeader_Refresh(dialog.header, headerData)
    end

    return needRefresh
end

function ZO_GenericGamepadDialog_OnInitialized(dialog)
    dialog.setupFunc = ZO_GenericGamepadDialog_DefaultSetup

    -- Management

    dialog.Activate = function() 
        if not dialog.info.blockDirectionalInput then
            DIRECTIONAL_INPUT:Activate(dialog, dialog) 
        end
    end

    dialog.Deactivate = function() DIRECTIONAL_INPUT:Deactivate(dialog) end
    dialog.UpdateDirectionalInput = ZO_GenericGamepadDialog_UpdateDirectionalInput

    dialog.fragment = dialog.fragment or ZO_TranslateFromLeftSceneFragment:New(dialog, true)

    dialog.hideFunction = function(dialog, releasedFromButton)
        local hideLater = function()
            if dialog.owningScene == nil then return end --player pressed another button before call later

            dialog.owningScene = nil
            if dialog.isShowingOnBase then
                SCENE_MANAGER:RemoveFragmentGroup(ZO_GAMEPAD_DIALOG_FRAGMENT_GROUP)
            end
            SCENE_MANAGER:RemoveFragment(dialog.fragment)
        end

        dialog.releasedFromButton = releasedFromButton
        TryRemoveKeybinds()

        if dialog.info.onHideDelayMS and dialog:IsHidden() ~= true then
            zo_callLater(hideLater, dialog.info.onHideDelayMS)
            return
        end

        hideLater()
    end

    dialog.fragment:RegisterCallback("StateChange", function(oldState, newState)
                                                        if(newState == SCENE_FRAGMENT_SHOWING) then
                                                            OnDialogShowing(dialog)
                                                        elseif(newState == SCENE_FRAGMENT_SHOWN) then
                                                            OnDialogShown(dialog)
                                                        elseif(newState == SCENE_FRAGMENT_HIDING) then
                                                            OnDialogHiding(dialog)
                                                        elseif(newState == SCENE_FRAGMENT_HIDDEN) then
                                                            OnDialogHidden(dialog)
                                                        end
                                                    end)

    dialog.headerData = {}
    dialog.header = dialog:GetNamedChild("HeaderContainer").header

    local container = dialog:GetNamedChild("Container")
    dialog.scrollChild = container:GetNamedChild("ScrollChild")
    dialog.scrollIndicator = container:GetNamedChild("ScrollIndicator")
    dialog.mainTextControl = dialog.scrollChild:GetNamedChild("MainText")

    ZO_GamepadGenericHeader_Initialize(dialog.header)
end

function ZO_GenericGamepadDialog_Show(dialog)
    ZO_GenericGamepadDialog_SetupDirectionalInput(dialog)

    --Attach the dialog fragment to whichever scene is currenty showing
    dialog.isShowingOnBase = false
    local currentScene
    if SCENE_MANAGER:IsShowingBaseScene() and ZO_GAMEPAD_DIALOG_BASE_SCENE_NAME then
        currentScene = SCENE_MANAGER:GetScene(ZO_GAMEPAD_DIALOG_BASE_SCENE_NAME)
        SCENE_MANAGER:AddFragmentGroup(ZO_GAMEPAD_DIALOG_FRAGMENT_GROUP)
        dialog.isShowingOnBase = true
    else
        currentScene = SCENE_MANAGER:GetCurrentScene()
    end

	dialog.scrollIndicator:ClearAnchors()
	local offsetY = dialog.info.offsetScrollIndictorForArrow and ZO_GAMEPAD_PANEL_BG_SCROLL_INDICATOR_OFFSET_FOR_ARROW
	ZO_Scroll_Gamepad_SetScrollIndicatorSide(dialog.scrollIndicator, dialog, RIGHT, dialog.rightStickScrollIndicatorOffsetX, offsetY)

    dialog.owningScene = currentScene
    SCENE_MANAGER:AddFragment(dialog.fragment)

    if dialog.entryList then
        dialog.entryList:Activate()
    end
end

function ZO_GenericGamepadDialog_IsShowing()
    return GAMEPAD_DIALOG_SHOWING
end

-------------
-- Tooltip --
-------------

function ZO_GenericGamepadDialog_ShowTooltip(dialog)
    dialog.shouldShowTooltip = true

    GAMEPAD_TOOLTIPS:SetBgType(GAMEPAD_LEFT_DIALOG_TOOLTIP, GAMEPAD_TOOLTIP_DARK_BG)
    GAMEPAD_TOOLTIPS:ShowBg(GAMEPAD_LEFT_DIALOG_TOOLTIP)
end

function ZO_GenericGamepadDialog_HideTooltip(dialog)   
    if dialog.shouldShowTooltip then   
        
        GAMEPAD_TOOLTIPS:HideBg(GAMEPAD_LEFT_DIALOG_TOOLTIP)
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_DIALOG_TOOLTIP)
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_DIALOG_TOOLTIP)

        dialog.shouldShowTooltip = false
    end
end

-------------------------------------
-- Parametric List Dialog Template --
-------------------------------------

-- Dialog
function ZO_GenericParametricListGamepadDialogTemplate_OnInitialized(dialog)  
    ZO_GenericGamepadDialog_OnInitialized(dialog)

    dialog.setupFunc = ZO_GenericParametricListGamepadDialogTemplate_Setup
    local baseHideFunction = dialog.hideFunction 
    dialog.hideFunction = function(dialog, releasedFromButton)
        baseHideFunction(dialog, releasedFromButton)
        dialog.entryList:RemoveAllOnSelectedDataChangedCallbacks()
        dialog.entryList:Deactivate()
    end

    local listControl = dialog:GetNamedChild("EntryList"):GetNamedChild("List")
    dialog.entryList = ZO_GamepadVerticalItemParametricScrollList:New(listControl)
    dialog.entryList:SetAlignToScreenCenter(true)
end

local function ParametricListControlSetupFunc(control, data, selected, reselectingDuringRebuild, enabled, active)
    if control.resetFunction then
        control.resetFunction()
    end
    data.setup(control, data, selected, reselectingDuringRebuild, enabled, active)
end

do
    local function DefaultOnSelectionChangedCallback()
        KEYBIND_STRIP:UpdateKeybindButtonGroup(g_keybindGroupDesc, g_keybindState)
    end
    -- Valid fields for parametric list entries are:
    --   visible - a bool or function whcih determines if we show the entry
    --   template - the template for the gamepad entry data in the parametric list
    --   templateData - A table of fields to add to the entry data
    --   text - the text that will appear in the list
    --   icon - an optional icon to show next to the entry in the parametric list
    --   entryData - a premade ZO_GamepadEntryData in place of the one created from templateData, text, and icon
    --   initializeData - a function called after creating the ZO_GamepadEntryData and is passed the entry data object and the templateData
    function ZO_GenericParametricListGamepadDialogTemplate_Setup(dialog, limitNumEntries, data)
        if(data) then
            ZO_GenericGamepadDialog_DefaultSetup(dialog, data)
        end

        dialog.entryList:Clear()

        local onSelectionChangedCallback
        local dialogOnSelectionChangedCallback = dialog.info.parametricListOnSelectionChangedCallback
        if dialogOnSelectionChangedCallback then
            onSelectionChangedCallback =    function(...)
                                                dialogOnSelectionChangedCallback(...)
                                                DefaultOnSelectionChangedCallback()
                                            end
        else
            onSelectionChangedCallback = DefaultOnSelectionChangedCallback
        end

        dialog.entryList:SetOnSelectedDataChangedCallback(onSelectionChangedCallback)

        for i, entryInfoTable in ipairs(dialog.info.parametricList) do
            if(limitNumEntries == nil or i <= limitNumEntries) then
                local visible = true
                local entryDataOverrides = entryInfoTable.templateData -- this table will be copied on to the entry data that we create
                -- By default all entries are visible
                -- entries will only be hidden if entryDataOverrides.visible is false or is a function that returns false
                if entryDataOverrides and (entryDataOverrides.visible ~= nil) then
                    visible = entryDataOverrides.visible
                    if type(visible) == "function" then
                        visible = visible()
                    end
                end
            
                if visible then
                    local entryData = entryInfoTable.entryData
                    if entryData == nil then
                        local entryDataText = entryInfoTable.text
                        if(entryDataText ~= nil) then
                            if(type(entryDataText) == "number") then
                                entryDataText = GetString(entryDataText)
                            end
                        else -- default entry text
                            entryDataText = "EntryItem" .. tostring(i)
                        end

                        entryData = ZO_GamepadEntryData:New(entryDataText, entryInfoTable.icon)

                        -- TODO: This loop is pretty awful (and we should just pass in entryData see Achievements_Gamepad.lua)
                        if(entryDataOverrides) then
                            for dataKey, dataValue in pairs(entryDataOverrides) do
                                entryData[dataKey] = dataValue
                            end
                        end
                    end

                    -- TODO remove this? might only be used in TradingHouse_Dialogs_Gamepad.lua for an icon
                    if entryInfoTable.initializeData then
                        entryInfoTable.initializeData(entryData, entryDataOverrides)
                    end
        
                    local entryTemplate = entryInfoTable.template
                    if(not dialog.entryList:HasDataTemplate(entryTemplate)) then
                        dialog.entryList:AddDataTemplateWithHeader(entryTemplate, ParametricListControlSetupFunc, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, entryInfoTable.headerTemplate or "ZO_GamepadMenuEntryHeaderTemplate")
                        dialog.entryList:AddDataTemplate(entryTemplate, ParametricListControlSetupFunc, ZO_GamepadMenuEntryTemplateParametricListFunction)
                    end
        
                    local headerText = entryInfoTable.header
                    if(headerText ~= nil) then
                        if(type(headerText) == "number") then
                            headerText = GetString(headerString)
                        end
                        entryData:SetHeader(headerText) 
                        dialog.entryList:AddEntryWithHeader(entryTemplate, entryData)
                    else
                        dialog.entryList:AddEntry(entryTemplate, entryData)
                    end
                end
            end
        end

        dialog.entryList:CommitWithoutReselect()
    end
end

-------------------------------------
-- Cooldown Dialog Template --
-------------------------------------

function ZO_GenericCooldownGamepadDialogTemplate_OnInitialized(dialog)  
    ZO_GenericGamepadDialog_OnInitialized(dialog)

    dialog.setupFunc = ZO_GenericCooldownGamepadDialogTemplate_Setup
    dialog.cooldownLabelControl = dialog:GetNamedChild("LoadingContainerCooldownLabel")
    dialog.loadingControl = dialog:GetNamedChild("LoadingContainerLoading")
end

function ZO_GenericCooldownGamepadDialogTemplate_Setup(dialog)
    local loadingMode = dialog.info.loading ~= nil

    dialog.cooldownLabelControl:SetText("")

    dialog.loadingControl:SetHidden(not loadingMode)
    if(loadingMode) then
        local loadingString = dialog.info.loading.text

        if type(loadingString) == "function" then
            loadingString = loadingString(dialog)
        end

        if loadingString and loadingString ~= "" then
            dialog.cooldownLabelControl:SetText(loadingString)
            dialog.cooldownLabelControl:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
        end
    else
        dialog.cooldownLabelControl:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
    end
end

-------------------------------------
-- Transaction Dialog Template --
-------------------------------------

function ZO_GenericTransactionGamepadDialogTemplate_OnInitialized(dialog)
    ZO_GenericGamepadDialog_OnInitialized(dialog)
    dialog.setupFunc = ZO_GenericTransactionGamepadDialogTemplate_Setup
    dialog.messageControl = dialog:GetNamedChild("Message")
    
    local itemContainer = dialog:GetNamedChild("ItemContainer")
    dialog.itemIconControl = itemContainer:GetNamedChild("Icon")
    dialog.itemLabelControl = itemContainer:GetNamedChild("Name")
    dialog.itemStackCount = itemContainer:GetNamedChild("IconStackCount")
    
    local data1Header = dialog:GetNamedChild("HeaderContainerHeaderData1Header")
    data1Header:SetParent(itemContainer)
    data1Header:ClearAnchors()
    data1Header:SetAnchor(TOPLEFT, itemContainer, BOTTOMLEFT)
    data1Header:SetAnchor(TOPRIGHT, itemContainer, BOTTOMRIGHT, 0, SCREEN_HEADER_DATA_OFFSET_Y)
end

function ZO_GenericTransactionGamepadDialogTemplate_Setup(dialog, data)
    if(data) then
        dialog.messageControl:SetText(dialog.headerData.messageText)
        dialog.headerData.messageText = nil
        ZO_GenericGamepadDialog_DefaultSetup(dialog, data)
        dialog.itemIconControl:SetTexture(data.itemIcon)
        dialog.itemLabelControl:SetText(data.itemName)

        local hasStack = data.itemStackSize > 0
        if hasStack then
            dialog.itemStackCount:SetText(data.itemStackSize)
        end

        dialog.itemStackCount:SetHidden(not hasStack)
    end
end

-------------------------------------
-- Centered Template --
-------------------------------------

function ZO_GenericCenteredGamepadDialogTemplate_OnInitialized(dialog)
    dialog.fragment = ZO_FadeSceneFragment:New(dialog)

    ZO_GenericGamepadDialog_OnInitialized(dialog)
    dialog.scrollPadding = dialog.scrollChild:GetNamedChild("Padding")
    dialog.setupFunc = ZO_GenericCenteredGamepadDialogTemplate_Setup

	
    local GENERIC_CENTERED_DIALOG_RIGHT_SCROLL_INDICATOR_X_OFFSET = -1
	dialog.rightStickScrollIndicatorOffsetX = GENERIC_CENTERED_DIALOG_RIGHT_SCROLL_INDICATOR_X_OFFSET

    dialog:GetNamedChild("InteractKeybind"):SetText(zo_strformat(SI_TUTORIAL_CONTINUE, ZO_Keybindings_GetKeyText(KEY_GAMEPAD_BUTTON_1)))
end

local MIN_HEIGHT_SCROLL_WINDOW = 480
local MIN_HEIGHT_SCROLL_CONTAINER = 187
local EXPAND_HEIGHT_SCROLL_WINDOW = 210

function ZO_GenericCenteredGamepadDialogTemplate_Setup(dialog)
    dialog.headerData.titleTextAlignment = TEXT_ALIGN_CENTER
    ZO_GamepadGenericHeader_Refresh(dialog.header, dialog.headerData)

    local height = dialog:GetHeight()
    local scrollContentsHeight = dialog.mainTextControl:GetTextHeight() + dialog.scrollPadding:GetHeight()
    if scrollContentsHeight < MIN_HEIGHT_SCROLL_CONTAINER then
        height = MIN_HEIGHT_SCROLL_WINDOW
    elseif scrollContentsHeight < MIN_HEIGHT_SCROLL_CONTAINER + EXPAND_HEIGHT_SCROLL_WINDOW then
        height = MIN_HEIGHT_SCROLL_WINDOW + (scrollContentsHeight - MIN_HEIGHT_SCROLL_CONTAINER)
    else
        height = MIN_HEIGHT_SCROLL_WINDOW + EXPAND_HEIGHT_SCROLL_WINDOW
    end

    dialog:SetHeight(height)
end

-------------------------------------
-- Static List Dialog Template --
-------------------------------------

-- Dialog
function ZO_GenericGamepadStaticListDialogTemplate_OnInitialized(dialog)  
    ZO_GenericGamepadDialog_OnInitialized(dialog)
    dialog.setupFunc = ZO_GenericStaticListGamepadDialogTemplate_Setup

    local containerName = dialog.scrollChild:GetName()
    dialog.listHeaderControl = CreateControlFromVirtual(containerName .. "ListHeader", dialog.scrollChild, "ZO_GamepadStaticListHeader")

    local function CreateEntryControl(objectPool)
        return ZO_ObjectPool_CreateNamedControl(containerName .. "Entry", "ZO_GamepadStaticListIconEntry", objectPool, dialog.scrollChild)
    end

    local function ResetEntryControl(entryControl)
        entryControl:SetHidden(true)
        entryControl:ClearAnchors()
    end

    dialog.entryPool = ZO_ObjectPool:New(CreateEntryControl, ResetEntryControl)
end

function ZO_GenericStaticListGamepadDialogTemplate_Setup(dialog, data)
    if(data) then
        ZO_GenericGamepadDialog_DefaultSetup(dialog, data)
    end

    dialog.entryPool:ReleaseAllObjects()

    local listEntryAnchorControl
    local entryRowSpacing = 11
    local entryContainerOffsetY = 70

    local listHeader = dialog.listHeader
    local listHeaderControl = dialog.listHeaderControl
    if listHeader then
        local listHeaderLabelControl = listHeaderControl.labelControl
        listHeaderLabelControl:SetText(listHeader)
        listHeaderControl:SetHidden(false)
        listHeaderControl:SetAnchor(TOPLEFT, dialog.mainTextControl, BOTTOMLEFT, 0, entryContainerOffsetY)
        listEntryAnchorControl = listHeaderControl
        entryRowSpacing = 24
    else
        listHeaderControl:SetHidden(true)
    end

    for i, itemInfo in ipairs(dialog.info.itemInfo) do
        local entryControl = dialog.entryPool:AcquireObject()
        if listEntryAnchorControl then
            entryControl:SetAnchor(TOPLEFT, listEntryAnchorControl, BOTTOMLEFT, 0, entryRowSpacing) --there is a built in 4 tall spacer
        else
            entryControl:SetAnchor(TOPLEFT, dialog.mainTextControl, BOTTOMLEFT, 0, entryContainerOffsetY)
        end
        
        local iconControl = entryControl.iconControl
        local labelControl = entryControl.labelControl

        iconControl:SetTexture(itemInfo.icon)
        local iconSize = itemInfo.iconSize or 32
        iconControl:SetDimensions(iconSize, iconSize)
        if itemInfo.iconColor then
            iconControl:SetColor(itemInfo.iconColor:UnpackRGB())
        end

        labelControl:SetText(itemInfo.label)
        if itemInfo.labelFont then
            labelControl:SetFont(itemInfo.labelFont)
        end

        entryControl:SetHidden(false)

        listEntryAnchorControl = entryControl
        entryRowSpacing = 11
    end
end

-------------------------------------
-- Dialog Utility Global Functions --
-------------------------------------

function ZO_GenericGamepadDialog_Parametric_TextFieldFocusLost(control)
    ZO_GamepadEditBox_FocusLost(control)
    local paraDialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
    paraDialog.entryList:RefreshVisible()
end
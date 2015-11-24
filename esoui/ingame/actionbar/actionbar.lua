local g_actionBarButtons = {}
local g_showHiddenButtonsRefCount = 1
local g_actionBarActiveWeaponPair
local g_activeWeaponSwapInProgress = false

local ACTION_BUTTON_TEMPLATE = "ZO_ActionButton"
local ULTIMATE_ABILITY_BUTTON_TEMPLATE = "ZO_UltimateActionButton"

local function GetRemappedActionSlotNum(slotNum)
    if slotNum > ACTION_BAR_FIRST_UTILITY_BAR_SLOT and slotNum <= ACTION_BAR_FIRST_UTILITY_BAR_SLOT + ACTION_BAR_UTILITY_BAR_SIZE
    then
        return ACTION_BAR_FIRST_UTILITY_BAR_SLOT + 1
    else
        return slotNum
    end
end

function ZO_ActionBar_HasAnyActionSlotted()
    for physicalSlot in pairs(g_actionBarButtons) do
        if GetSlotType(physicalSlot) ~= ACTION_TYPE_NOTHING then
            return true
        end
    end
    return false
end

function ZO_ActionBar_GetButton(slotNum)
    local remappedSlotNum = GetRemappedActionSlotNum(slotNum)
    return g_actionBarButtons[remappedSlotNum]
end

local function CanUseActionSlots()
    return ((not IsGameCameraActive() and not IsInteractionCameraActive()) or SCENE_MANAGER:IsShowing("hud")) and not IsUnitDead("player")
end

function ActionButtonDownAndUp(slotNum)
    if CanUseActionSlots() then
        local button = ZO_ActionBar_GetButton(slotNum)
        if button then
            button:HandlePressAndRelease()
        end
    end
end

function ActionButtonDown(slotNum)
    if CanUseActionSlots() then
        local button = ZO_ActionBar_GetButton(slotNum)
        if button then
            button:HandlePress()
        end
    end
end

function ActionButtonUp(slotNum)
    local button = ZO_ActionBar_GetButton(slotNum)
    if button then
        if CanUseActionSlots() then
            button:HandleRelease()
        else
            button:ResetVisualState() --in case CanUseActionSlots() returns false after ActionButtonDown already fired.
        end
    end
end

function AreActionBarsLocked()
    return GetSetting_Bool(SETTING_TYPE_ACTION_BARS, ACTION_BAR_SETTING_LOCK_ACTION_BARS)
end

function ZO_ActionBar_AreHiddenButtonsShowing()
    return (g_showHiddenButtonsRefCount > 0)
end

function ZO_ActionBar_AttemptPlacement(slotNum)
    PlaceInActionBar(slotNum)   -- Fails and shows an error if the button is locked
end

function ZO_ActionBar_AttemptPickup(slotNum)
    if(AreActionBarsLocked())
    then
        return
    end

    PickupAction(slotNum)   -- Fails and shows an error if the button is locked
    ClearTooltip(AbilityTooltip)
end

local g_currentUltimateMax = 0
local g_ultimateBarFull = nil
local g_ultimateReadyBurstTimeline = nil
local g_ultimateReadyLoopTimeline = nil
local g_ultimateFillTimeline = nil
local g_ultimateBarFillLeftTimeline = nil
local g_ultimateBarFillRightTimeline = nil

local ZO_ULTIMATE_BAR_GRADIENT_COLORS = { ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_ULTIMATE_BAR, ULTIMATE_BAR_COLOR_BAR_START)), ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_ULTIMATE_BAR, ULTIMATE_BAR_COLOR_BAR_END)) }
local ZO_ULTIMATE_BAR_FULL_GRADIENT_COLORS = { ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_ULTIMATE_BAR, ULTIMATE_BAR_COLOR_FULL_BAR_START)), ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_ULTIMATE_BAR, ULTIMATE_BAR_COLOR_FULL_BAR_END)) }

local function UpdateCurrentUltimateMax()
    local cost, mechanic = GetSlotAbilityCost(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1)

    if(mechanic == POWERTYPE_ULTIMATE)
    then
        g_currentUltimateMax = cost
    else
        g_currentUltimateMax = 0
    end
end

local function StopUltimateReadyAnimations()
    if(g_ultimateReadyBurstTimeline) then
        g_ultimateReadyBurstTimeline:Stop()
        g_ultimateReadyLoopTimeline:Stop()
    end
end

local function PlayUltimateReadyAnimations(ultimateReadyBurstTexture, ultimateReadyLoopTexture)
    if(not g_ultimateReadyBurstTimeline) then
        g_ultimateReadyBurstTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("UltimateReadyBurst", ultimateReadyBurstTexture)
        g_ultimateReadyLoopTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("UltimateReadyLoop", ultimateReadyLoopTexture)
        g_ultimateReadyBurstTimeline:SetHandler("OnPlay", function() PlaySound(SOUNDS.ABILITY_ULTIMATE_READY) end)

        local function OnStop(self)
            if(self:GetProgress() == 1.0) then
                ultimateReadyBurstTexture:SetHidden(true)
                g_ultimateReadyLoopTimeline:PlayFromStart()
                ultimateReadyLoopTexture:SetHidden(false)
            end
        end
        g_ultimateReadyBurstTimeline:SetHandler("OnStop", OnStop)
    end
    if not g_activeWeaponSwapInProgress then
        if not g_ultimateReadyBurstTimeline:IsPlaying() and not g_ultimateReadyLoopTimeline:IsPlaying() then
            ultimateReadyBurstTexture:SetHidden(false)
            g_ultimateReadyBurstTimeline:PlayFromStart()
        end
    elseif not g_ultimateReadyLoopTimeline:IsPlaying() then
        g_ultimateReadyLoopTimeline:PlayFromStart()
        ultimateReadyLoopTexture:SetHidden(false)
    end
end

local function ResetUltimateFillAnimations()
    if g_ultimateBarFillLeftTimeline then
        g_ultimateBarFillLeftTimeline.currentOffset = 0
        g_ultimateBarFillRightTimeline.currentOffset = 0

        g_ultimateBarFillLeftTimeline:ClearAllCallbacks()
        g_ultimateBarFillRightTimeline:ClearAllCallbacks()
    end
end

local function StopAnimationTimeline(timeline)
    timeline:Stop()
end

local function PlayAnimationFromOffset(animation, newOffset)
    animation:ClearAllCallbacks()
    animation:InsertCallback(StopAnimationTimeline, newOffset)

    if newOffset == 0 then
        animation:PlayBackward()
    else
        animation:PlayFromStart(newOffset)
    end

    animation.currentOffset = newOffset
end

local function PlayUltimateFillAnimation(button, leftTexture, rightTexture, newPercentComplete, setProgressNoAnim)
    if not g_ultimateBarFillLeftTimeline then
        g_ultimateBarFillLeftTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("UltimateBarFillLoopAnimation", leftTexture)
        g_ultimateBarFillRightTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("UltimateBarFillLoopAnimation", rightTexture)
        g_ultimateBarFillRightTimeline:GetFirstAnimation():SetMirrorAlongY(true)
    end

    if not g_ultimateBarFillLeftTimeline:IsPlaying() then
        local duration = g_ultimateBarFillLeftTimeline:GetDuration()
        local offset = zo_floor(duration * newPercentComplete)
        if g_ultimateBarFillLeftTimeline.currentOffset ~= offset then
            PlayAnimationFromOffset(g_ultimateBarFillLeftTimeline, offset)
            PlayAnimationFromOffset(g_ultimateBarFillRightTimeline, offset)

            if offset == duration then
                if setProgressNoAnim then
                    button:AnchorKeysIn()
                else
                    button:PlayGlow()
                    button:SlideKeysIn()
                end
            elseif offset == 0 then
                button:SlideKeysOut()
            end
        end
    end
end

local function SetUltimateMeter(ultimateCount, setProgressNoAnim)
    local isSlotUsed = IsSlotUsed(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1)
    local ultimateButton = g_actionBarButtons[ACTION_BAR_ULTIMATE_SLOT_INDEX + 1]
    local ultimateSlot = ultimateButton.slot
    local barTexture = GetControl(ultimateSlot, "UltimateBar")
    local leadingEdge = GetControl(ultimateSlot, "LeadingEdge")
    local ultimateReadyBurstTexture = GetControl(ultimateSlot, "ReadyBurst")
    local ultimateReadyLoopTexture = GetControl(ultimateSlot, "ReadyLoop")
    local ultimateFillLeftTexture = GetControl(ultimateSlot, "FillAnimationLeft")
    local ultimateFillRightTexture = GetControl(ultimateSlot, "FillAnimationRight")
    local icon = GetControl(ultimateSlot, "Icon")
    local ultimateFillFrame = GetControl(ultimateSlot, "Frame")

    local isGamepad = IsInGamepadPreferredMode()
    
    if(isSlotUsed) then
        if(ultimateCount >= g_currentUltimateMax) then
            --hide progress bar
            barTexture:SetHidden(true)
            leadingEdge:SetHidden(true)

            -- Saturate icon
            ultimateButton:UpdateUseFailure()
            icon:SetDesaturation((isGamepad and ultimateButton.useFailure) and 1 or 0)

            -- Show fill bar if platform appropriate
            ultimateFillFrame:SetHidden(not isGamepad)
            ultimateFillLeftTexture:SetHidden(not isGamepad)
            ultimateFillRightTexture:SetHidden(not isGamepad)

            -- Set fill bar to full
            PlayUltimateFillAnimation(ultimateButton, ultimateFillLeftTexture, ultimateFillRightTexture, 1, setProgressNoAnim)

            PlayUltimateReadyAnimations(ultimateReadyBurstTexture, ultimateReadyLoopTexture)
        else
            --stop animation
            ultimateReadyBurstTexture:SetHidden(true)
            ultimateReadyLoopTexture:SetHidden(true)
            StopUltimateReadyAnimations()

            -- show platform appropriate progress bar
            barTexture:SetHidden(isGamepad)
            leadingEdge:SetHidden(isGamepad)
            ultimateFillLeftTexture:SetHidden(not isGamepad)
            ultimateFillRightTexture:SetHidden(not isGamepad)
            ultimateFillFrame:SetHidden(not isGamepad)
            icon:SetDesaturation(isGamepad and 1 or 0)
        
            -- update both platforms progress bars
            local slotHeight = ultimateSlot:GetHeight()
            local percentComplete = ultimateCount / g_currentUltimateMax
            local yOffset = zo_floor(slotHeight * (1 - percentComplete))
            barTexture:SetHeight(yOffset)

            leadingEdge:ClearAnchors()
            leadingEdge:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, yOffset - 5)
            leadingEdge:SetAnchor(TOPRIGHT, nil, TOPRIGHT, 0, yOffset - 5)

            PlayUltimateFillAnimation(ultimateButton, ultimateFillLeftTexture, ultimateFillRightTexture, percentComplete, setProgressNoAnim)
            ultimateButton:AnchorKeysOut()
        end
    else
        --stop animation
        ultimateReadyBurstTexture:SetHidden(true)
        ultimateReadyLoopTexture:SetHidden(true)
        StopUltimateReadyAnimations()
        ResetUltimateFillAnimations()

        --hide progress bar for all platforms
        barTexture:SetHidden(true)
        leadingEdge:SetHidden(true)
        ultimateFillLeftTexture:SetHidden(true)
        ultimateFillRightTexture:SetHidden(true)
        ultimateFillFrame:SetHidden(true)
        ultimateButton:AnchorKeysOut()
    end

    ultimateButton:HideKeys(not isGamepad)
end

local SET_ULTIMATE_METER_NO_ANIM = true

local function UpdateUltimateMeter()
    UpdateCurrentUltimateMax()
    local ultimateCount =  GetUnitPower("player", POWERTYPE_ULTIMATE)
    SetUltimateMeter(ultimateCount, SET_ULTIMATE_METER_NO_ANIM)
end

local function OnPowerUpdate(evt, unitTag, powerPoolIndex, powerType, powerPool, powerPoolMax)
    SetUltimateMeter(powerPool)
end

local function OnItemSlotChanged(eventCode, itemSoundCategory)
    PlayItemSound(itemSoundCategory, ITEM_SOUND_ACTION_SLOT)
end

local function OnAbilitySlotted(eventCode, newAbilitySlotted, slotNum)
    if(newAbilitySlotted == true)
    then
        PlaySound(SOUNDS.ABILITY_SLOTTED)
    else
        PlaySound(SOUNDS.ABILITY_SLOT_CLEARED)
    end
end

local function HandleSlotChanged(slotNum)
    local btn = ZO_ActionBar_GetButton(slotNum)
    if(btn and not btn.noUpdates)
    then
        btn:HandleSlotChanged()

        local buttonTemplate = ZO_GetPlatformTemplate(ACTION_BUTTON_TEMPLATE)

        if(slotNum == ACTION_BAR_ULTIMATE_SLOT_INDEX + 1) then
            buttonTemplate = ZO_GetPlatformTemplate(ULTIMATE_ABILITY_BUTTON_TEMPLATE)
            UpdateUltimateMeter()
        end

        btn:ApplyStyle(buttonTemplate)
    end
end

local function HandleStateChanged(slotNum)
    local btn = ZO_ActionBar_GetButton(slotNum)
    if(btn and not btn.noUpdates)
    then
        btn:UpdateState()
    end
end

local function HandleAbilityUsed(slotNum)
    local btn = ZO_ActionBar_GetButton(slotNum)
    if btn and IsInGamepadPreferredMode() then
        btn:PlayAbilityUsedBounce()
    end
end

local function UpdateAllSlots(eventCode)
    for physicalSlotNum in pairs(g_actionBarButtons)
    do
        HandleSlotChanged(physicalSlotNum)
    end
end

local function UpdateCooldowns()
    for i, button in pairs(g_actionBarButtons)
    do
        button:UpdateCooldown()
    end
end

local function MakeActionButton(physicalSlot, buttonStyle, buttonObject)
    buttonObject = buttonObject or ActionButton

    local button = buttonObject:New(physicalSlot,buttonStyle.type, buttonStyle.parentBar, buttonStyle.template)
    button:SetShowBindingText(buttonStyle.showBinds)
    g_actionBarButtons[physicalSlot] = button

    return button
end

local function HandleInventoryChanged(eventCode, bag, slot)
    for _, physicalSlot in pairs(g_actionBarButtons)
    do
        if(physicalSlot)
        then
            local slotType = GetSlotType(physicalSlot:GetSlot())
            if(slotType == ACTION_TYPE_ITEM) then
                local itemCount = GetSlotItemCount(physicalSlot:GetSlot())
                local consumable = IsSlotItemConsumable(physicalSlot:GetSlot())
                physicalSlot:SetupCount(itemCount, consumable)
                physicalSlot:UpdateState()
		    elseif(slotType == ACTION_TYPE_ABILITY) then
				physicalSlot:UpdateState()
            end
        end
    end
end

local function ShowHiddenButtons()
    g_showHiddenButtonsRefCount = g_showHiddenButtonsRefCount + 1
    if(g_showHiddenButtonsRefCount == 1) then
        for _, control in pairs(g_actionBarButtons) do
            if(control:GetButtonType() == ACTION_BUTTON_TYPE_HIDDEN) then
                control.slot:SetHidden(false)
            end
        end
    end
end

local function HideHiddenButtons()
    g_showHiddenButtonsRefCount = g_showHiddenButtonsRefCount - 1
    if(g_showHiddenButtonsRefCount == 0) then
        for _, control in pairs(g_actionBarButtons) do
            if(control:GetButtonType() == ACTION_BUTTON_TYPE_HIDDEN) then
                if(not control:HasAction()) then
                    control.slot:SetHidden(true)
                end
            end
        end
    end
end

local function HideAllAbilityActionButtonDropCallouts()
    for i = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 do
        local callout = ZO_ActionBar_GetButton(i).slot:GetNamedChild("DropCallout")
        callout:SetHidden(true)
    end
end

local function ShowAppropriateAbilityActionButtonDropCallouts(abilityIndex)
    HideAllAbilityActionButtonDropCallouts()

    for i = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 do
        local isValid = IsValidAbilityForSlot(abilityIndex, i)
        local callout = ZO_ActionBar_GetButton(i).slot:GetNamedChild("DropCallout")

        if(not isValid) then
            callout:SetColor(1, 0, 0, 1)
        else
            callout:SetColor(1, 1, 1, 1)
        end

        callout:SetHidden(false)
    end
end

local function HandleCursorPickup(eventCode, cursorType, param1, param2, param3)
    if(cursorType == MOUSE_CONTENT_ACTION or cursorType == MOUSE_CONTENT_INVENTORY_ITEM or cursorType == MOUSE_CONTENT_QUEST_ITEM or cursorType == MOUSE_CONTENT_QUEST_TOOL) then
        ShowHiddenButtons()
    end

    if(cursorType == MOUSE_CONTENT_ACTION and param1 == ACTION_TYPE_ABILITY) then
        ShowAppropriateAbilityActionButtonDropCallouts(param3)
        if(param3 ~= 0)
        then
            PlaySound(SOUNDS.ABILITY_PICKED_UP)
        end
    end
end

local function HandleCursorDropped(eventCode, cursorType)
    if(cursorType == MOUSE_CONTENT_ACTION or cursorType == MOUSE_CONTENT_INVENTORY_ITEM or cursorType == MOUSE_CONTENT_QUEST_ITEM or cursorType == MOUSE_CONTENT_QUEST_TOOL) then
        HideHiddenButtons()
    end

    if(cursorType == MOUSE_CONTENT_ACTION) then
        HideAllAbilityActionButtonDropCallouts()
    end
end

local function OnActiveQuickslotChanged(eventCode, slotId)
    HandleSlotChanged(ACTION_BAR_FIRST_UTILITY_BAR_SLOT + 1)
end

local function OnActiveWeaponPairChanged(eventCode, activeWeaponPair)
    if (activeWeaponPair ~= g_actionBarActiveWeaponPair) then
        g_activeWeaponSwapInProgress = true
        UpdateUltimateMeter()
        g_actionBarActiveWeaponPair = activeWeaponPair
    end
end

local GAMEPAD_CONSTANTS =
{
    abilitySlotOffsetX = 10,
    ultimateSlotOffsetX = 65,
}

local KEYBOARD_CONSTANTS =
{
    abilitySlotOffsetX = 2,
    ultimateSlotOffsetX = 62,
}

local function GetPlatformConstants()
    return IsInGamepadPreferredMode() and GAMEPAD_CONSTANTS or KEYBOARD_CONSTANTS
end

local function ApplyStyle()
    ApplyTemplateToControl(ZO_ActionBar1, ZO_GetPlatformTemplate("ZO_ActionBar1"))

    local lastButton
    local constants = GetPlatformConstants()
    local buttonTemplate = ZO_GetPlatformTemplate(ACTION_BUTTON_TEMPLATE)
    for physicalSlot, button in pairs(g_actionBarButtons) do
        if button then
            button:ApplyStyle(buttonTemplate)
            if physicalSlot > ACTION_BAR_FIRST_NORMAL_SLOT_INDEX and physicalSlot < ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE then
                local anchorTarget = lastButton and lastButton.slot
                if not lastButton then
                    anchorTarget = ZO_ActionBar1WeaponSwap
                    anchorOffsetX = 5
                end
                button:ApplyAnchor(anchorTarget, constants.abilitySlotOffsetX)
                lastButton = button
            elseif physicalSlot == ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 then
                button:ApplyStyle(ZO_GetPlatformTemplate(ULTIMATE_ABILITY_BUTTON_TEMPLATE))
                button:SetShowBindingText(not IsInGamepadPreferredMode())
                button:ApplyAnchor(g_actionBarButtons[ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1].slot, constants.ultimateSlotOffsetX)
            end
        end
    end

    local isGamepad = IsInGamepadPreferredMode()
    ZO_ActionBar1:GetNamedChild("KeybindBG"):SetHidden(isGamepad)
    ZO_WeaponSwap_SetPermanentlyHidden(ZO_ActionBar1:GetNamedChild("WeaponSwap"), isGamepad)

    UpdateUltimateMeter()
end

local function OnGamepadPreferredModeChanged()
    ApplyStyle()
end

function ZO_ActionBar_Initialize()    
    local MAIN_BAR_STYLE =
    {
        type = ACTION_BUTTON_TYPE_VISIBLE,
        template = ACTION_BUTTON_TEMPLATE,
        showBinds = true,
        parentBar = ZO_ActionBar1,
    }

    --Quick Bar Slot
    local quickBarButton = MakeActionButton(ACTION_BAR_FIRST_UTILITY_BAR_SLOT + 1, MAIN_BAR_STYLE, QuickslotActionButton)
    quickBarButton.slot:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 0)  
    quickBarButton:SetupBounceAnimation()
    
    ZO_ActionBar1WeaponSwap:SetAnchor(LEFT, quickBarButton.slot, RIGHT, 5, 0)

    local function OnSwapAnimationHalfDone(animation, button)
        button:HandleSlotChanged()

        if(button:GetSlot() == ACTION_BAR_ULTIMATE_SLOT_INDEX + 1)
        then
            UpdateUltimateMeter()
        end
    end

    local function OnSwapAnimationDone(animation, button)
        button.noUpdates = false
        if(button:GetSlot() == ACTION_BAR_ULTIMATE_SLOT_INDEX + 1) then
            g_activeWeaponSwapInProgress = false
        end
    end

    local function SetupFlipAnimation(button)
        button:SetupFlipAnimation(OnSwapAnimationHalfDone, OnSwapAnimationDone)
    end

    local constants = GetPlatformConstants()

    --Main Bar
    local buttonTemplate = ZO_GetPlatformTemplate(ACTION_BUTTON_TEMPLATE)
    local lastButton = nil
    for i = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1 do
        local barButton = MakeActionButton(i, MAIN_BAR_STYLE)
        barButton:ApplyStyle(buttonTemplate)

        local anchorTarget = lastButton and lastButton.slot
        local anchorOffsetX = constants.abilitySlotOffsetX
        if not lastButton then
            anchorTarget = ZO_ActionBar1WeaponSwap
            anchorOffsetX = 5
        end
        barButton:ApplyAnchor(anchorTarget, anchorOffsetX)

        SetupFlipAnimation(barButton)
        barButton:SetupBounceAnimation()

        lastButton = barButton
    end

    --Ultimate Button
    local ULTIMATE_BUTTON_STYLE =
    {
        type = ACTION_BUTTON_TYPE_VISIBLE,
        template = "ZO_UltimateActionButton",
        showBinds = true,
        parentBar = ZO_ActionBar1,
    }

    local ultimateButton = MakeActionButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, ULTIMATE_BUTTON_STYLE)
    ultimateButton:ApplyStyle(buttonTemplate)
    ultimateButton:ApplyAnchor(lastButton.slot, constants.ultimateSlotOffsetX)
    SetupFlipAnimation(ultimateButton)
    ultimateButton:SetupBounceAnimation()
    ultimateButton:SetupKeySlideAnimation()
    UpdateUltimateMeter()

    local function OnActionSlotsFullUpdate(event, isHotbarSwap)
        if isHotbarSwap then
            for _, physicalSlot in pairs(g_actionBarButtons) do
                if physicalSlot.hotbarSwapAnimation then
                    physicalSlot.noUpdates = true
                    physicalSlot.hotbarSwapAnimation:PlayFromStart()
                end
            end
        else
            g_activeWeaponSwapInProgress = false
            UpdateAllSlots()
        end
    end

    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_ACTION_SLOT_UPDATED, function (_, slotnum) HandleSlotChanged(slotnum) end)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_ACTION_SLOTS_FULL_UPDATE, OnActionSlotsFullUpdate)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_ACTION_SLOT_STATE_UPDATED, function (_, slotnum) HandleStateChanged(slotnum) end)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_ACTION_SLOT_ABILITY_USED, function (_, slotnum) HandleAbilityUsed(slotnum) end)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_ACTION_UPDATE_COOLDOWNS, UpdateCooldowns)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_INVENTORY_FULL_UPDATE, HandleInventoryChanged)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, HandleInventoryChanged)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_OPEN_BANK, HandleInventoryChanged)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_CLOSE_BANK, HandleInventoryChanged)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_CURSOR_PICKUP, HandleCursorPickup)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_CURSOR_DROPPED, HandleCursorDropped)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_POWER_UPDATE, OnPowerUpdate)
    EVENT_MANAGER:AddFilterForEvent("ZO_ActionBar", EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, POWERTYPE_ULTIMATE, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_ITEM_SLOT_CHANGED, OnItemSlotChanged)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_ACTION_SLOT_ABILITY_SLOTTED, OnAbilitySlotted)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_ACTIVE_QUICKSLOT_CHANGED, OnActiveQuickslotChanged)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_PLAYER_ACTIVATED, UpdateAllSlots)
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnActiveWeaponPairChanged)

    ApplyStyle() -- Setup initial visual style based on current mode.
    EVENT_MANAGER:RegisterForEvent("ZO_ActionBar", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, OnGamepadPreferredModeChanged)

    HideHiddenButtons()
end

function ZO_ActionBar1_OnInitialized(self)
    ACTION_BAR_FRAGMENT = ZO_HUDFadeSceneFragment:New(self)
end


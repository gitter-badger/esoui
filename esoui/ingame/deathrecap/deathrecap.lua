--Death Recap Toggle
----------------------

local DeathRecapToggle = ZO_Object:Subclass()

function DeathRecapToggle:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function DeathRecapToggle:Initialize(control)
    DEATH_RECAP:RegisterCallback("OnDeathRecapAvailableChanged", function() self:RefreshEnabled() end)
    self:RefreshEnabled()
end

function DeathRecapToggle:RefreshEnabled()
    self.enabled = DEATH_RECAP:IsDeathRecapAvailable()
    DEATH:SetDeathRecapToggleButtonsEnabled(self.enabled)
end

function DeathRecapToggle:Toggle()
    DEATH:ToggleDeathRecap()
end

function DeathRecapToggle:Hide()
    if(self.enabled) then
        if(DEATH_RECAP:IsWindowOpen()) then
            DEATH_RECAP:SetWindowOpen(false)
            return true
        end
    end
    return false
end

--Death Recap
------------------

local DEATH_RECAP_DELAY = 2000

local DeathRecap = ZO_CallbackObject:Subclass()

function DeathRecap:New(...)
    local object = ZO_CallbackObject.New(self)
    object:Initialize(...)
    return object
end

function DeathRecap:Initialize(control)
    self.control = control
    self.scrollContainer = control:GetNamedChild("ScrollContainer")
    self.scrollControl = self.scrollContainer:GetNamedChild("ScrollChild")
    self.waitingToShowPrompt = false
    self.windowOpen = true
    self.deathRecapAvailable = false

    self.killingBlowIcon = GetControl(self.scrollControl, "AttacksKillingBlowIcon")
    self.killingBlowTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ZO_DeathRecapKillingBlowAnimation", self.killingBlowIcon)

    self:InitializeAttackPool()
    self:InitializeTelvarStoneLossLabel()
    self:InitializeHintPool()
    self.hintTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ZO_DeathRecapHintAnimation", self.scrollControl:GetNamedChild("HintsContainerHints"))

    EVENT_MANAGER:RegisterForEvent("DeathRecap", EVENT_PLAYER_DEAD, function() self:OnPlayerDead() end)
    EVENT_MANAGER:RegisterForEvent("DeathRecap", EVENT_PLAYER_ALIVE, function() self:OnPlayerAlive() end)
    EVENT_MANAGER:RegisterForEvent("DeathRecap", EVENT_PLAYER_ACTIVATED, function() self:SetupDeathRecap() end)
    CALLBACK_MANAGER:RegisterCallback("UnitFramesCreated", function() self:OnUnitFramesCreated() end)

    DEATH_RECAP_FRAGMENT = ZO_HUDFadeSceneFragment:New(control)
    DEATH_RECAP_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
        self:RefreshBossBarVisibility()
        self:RefreshUnitFrameVisibility()
        if(newState == SCENE_FRAGMENT_SHOWING) then
            if(self.animateOnShow) then
                self.animateOnShow = nil
                self:Animate()
            end
        end
    end)

    local function OnAddOnLoaded(event, name)
        if name == "ZO_Ingame" then
            local defaults = { recapOn = true, }
            self.savedVars = ZO_SavedVars:New("ZO_Ingame_SavedVariables", 1, "DeathRecap", defaults)
            self:SetWindowOpen(self.savedVars.recapOn)
            self.control:UnregisterForEvent(EVENT_ADD_ON_LOADED)
        end
    end
    self.control:RegisterForEvent(EVENT_ADD_ON_LOADED, OnAddOnLoaded)
    
    self.control:SetHandler("OnEffectivelyShown", function() self:OnEffectivelyShown() end)
    self.control:SetHandler("OnEffectivelyHidden", function() self:OnEffectivelyHidden() end)

    self:ApplyStyle() -- Setup initial visual style based on current mode.
    self.control:RegisterForEvent(EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function() self:OnGamepadPreferredModeChanged() end)

    local DEATH_RECAP_RIGHT_SCROLL_INDICATOR_OFFSET_X = -64
    ZO_Scroll_Gamepad_SetScrollIndicatorSide(self.scrollContainer:GetNamedChild("ScrollIndicator"), self.control, RIGHT, DEATH_RECAP_RIGHT_SCROLL_INDICATOR_OFFSET_X)
end

function DeathRecap:InitializeAttackPool()
    self.attackPool = ZO_ControlPool:New("ZO_DeathRecapAttack", self.scrollControl:GetNamedChild("Attacks"), "")
    self.attackTemplate = ZO_GetPlatformTemplate("ZO_DeathRecapAttack")

    self.attackPool:SetCustomFactoryBehavior(function(control)
        control.timeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ZO_DeathRecapAttackAnimation")
        local nestedTimeline = control.timeline:GetAnimationTimeline(1)
        local iconTexture = control:GetNamedChild("Icon")
        local textContainer = control:GetNamedChild("Text")
        for i = 1, 3 do
            local animation = nestedTimeline:GetAnimation(i)
            animation:SetAnimatedControl(iconTexture)
        end
        nestedTimeline:GetAnimation(4):SetAnimatedControl(textContainer)
    end)

    self.attackPool:SetCustomAcquireBehavior(function(control)
        ApplyTemplateToControl(control, self.attackTemplate)
    end)

    self.attackPool:SetCustomResetBehavior(function(control)
        control.timeline:Stop()
        local iconTexture = control:GetNamedChild("Icon")
        iconTexture:SetScale(1)
        ApplyTemplateToControl(control, self.attackTemplate)
    end)
end

function DeathRecap:InitializeHintPool()
    self.hintPool = ZO_ControlPool:New("ZO_DeathRecapHint", self.scrollControl:GetNamedChild("HintsContainerHints"), "")
    self.hintTemplate = ZO_GetPlatformTemplate("ZO_DeathRecapHint")
    
    self.hintPool:SetCustomAcquireBehavior(function(control)
        ApplyTemplateToControl(control, self.hintTemplate)
    end)
    
    self.hintPool:SetCustomResetBehavior(function(control)
        ApplyTemplateToControl(control, self.hintTemplate)
    end)
end

function DeathRecap:InitializeTelvarStoneLossLabel()
    self.telvarStoneLossControl = self.scrollControl:GetNamedChild("TelvarStoneLoss")
    self.telvarStoneLossTemplate = ZO_GetPlatformTemplate("ZO_DeathRecapTelvarStoneLoss")
    ApplyTemplateToControl(self.telvarStoneLossControl, self.telvarStoneLossTemplate)

    self.telvarStoneLossValueControl = self.telvarStoneLossControl:GetNamedChild("Value");

    self.telvarLossTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ZO_DeathRecapTelvarLossAnimation", self.telvarStoneLossControl)
end

function DeathRecap:IsWindowOpen()
    return self.windowOpen
end

function DeathRecap:SetWindowOpen(open)
    self.savedVars.recapOn = open
    self.windowOpen = open
    self:RefreshVisibility()

    if IsConsoleUI() then
        AUTO_SAVING:MarkDirty()
    end
end

function DeathRecap:IsDeathRecapAvailable()
    return self.deathRecapAvailable
end

function DeathRecap:SetDeathRecapAvailable(available)
    self.deathRecapAvailable = available
    self:FireCallbacks("OnDeathRecapAvailableChanged", available)
    self:RefreshVisibility()
end

function DeathRecap:RefreshVisibility()
    DEATH_RECAP_FRAGMENT:SetHiddenForReason("NotAvailable", not self.deathRecapAvailable)
    DEATH_RECAP_FRAGMENT:SetHiddenForReason("WindowHiddenByUser", not self.windowOpen, DEFAULT_HUD_DURATION, DEFAULT_HUD_DURATION)
end

function DeathRecap:RefreshBossBarVisibility()
    COMPASS_FRAME:SetBossBarHiddenForReason("deathRecap", not DEATH_RECAP_FRAGMENT:IsHidden())
end

function DeathRecap:RefreshUnitFrameVisibility()
    if(UNIT_FRAMES) then
        UNIT_FRAMES:SetFrameHiddenForReason("reticleover", "deathRecap", not DEATH_RECAP_FRAGMENT:IsHidden())
        UNIT_FRAMES:SetGroupAndRaidFramesHiddenForReason("deathRecap", not DEATH_RECAP_FRAGMENT:IsHidden())
    end
end

local function SortAttacks(left, right)
    if(left.wasKillingBlow) then
        return false
    elseif(right.wasKillingBlow) then
        return true
    else
        return left.lastUpdateAgoMS > right.lastUpdateAgoMS
    end    
end

local ATTACK_FRAME_TEXTURE = "EsoUI/Art/DeathRecap/deathRecap_attackFrame.dds"
local ATTACK_BOSS_FRAME_TEXTURE = "EsoUI/Art/DeathRecap/deathRecap_attackBossFrame.dds"

function DeathRecap:SetupAttacks()
    local startAlpha = self.animateOnShow and 0 or 1
    self.attackPool:ReleaseAllObjects()
    self.killingBlowIcon:SetAlpha(startAlpha)

    local attacks = {}
    for i = 1, GetNumKillingAttacks() do
        local attackName, attackDamage, attackIcon, wasKillingBlow, castTimeAgoMS, durationMS = GetKillingAttackInfo(i)
        local attackInfo = {
            index = i,
            attackName = attackName,
            attackDamage = attackDamage,
            attackIcon = attackIcon,
            wasKillingBlow = wasKillingBlow,
            lastUpdateAgoMS = castTimeAgoMS - durationMS,
        }

        table.insert(attacks, attackInfo)
    end

    table.sort(attacks, SortAttacks)

    local prevAttackControl
    for i, attackInfo in ipairs(attacks) do
        local attackControl = self.attackPool:AcquireObject(i)
        local iconControl = attackControl:GetNamedChild("Icon")
        iconControl:SetTexture(attackInfo.attackIcon)
        local attackNameControl = attackControl:GetNamedChild("AttackName")
        attackNameControl:SetText(zo_strformat(SI_DEATH_RECAP_ATTACK_NAME, attackInfo.attackName))
        local damageControl = attackControl:GetNamedChild("Damage")
        damageControl:SetText(ZO_CommaDelimitNumber(attackInfo.attackDamage))

        iconControl:SetAlpha(startAlpha)
        attackControl:GetNamedChild("Text"):SetAlpha(startAlpha)

        if(attackInfo.wasKillingBlow) then
            self.killingBlowIcon:SetAnchor(CENTER, attackControl, TOPLEFT, 32, 32)
        end

        local attackerNameControl = attackControl:GetNamedChild("AttackerName")
        local isBoss = false
        if(DoesKillingAttackHaveAttacker(attackInfo.index)) then
            local attackerRawName, attackerVeteranRank, attackerLevel, attackerAvARank, isPlayer, isBoss, alliance, minionName, attackerDisplayName = GetKillingAttackerInfo(attackInfo.index)
            
            local attackerNameLine
            if(isPlayer) then
                local coloredRankIconMarkup = GetColoredAvARankIconMarkup(attackerAvARank, alliance, 32)
                local nameToShow = IsInGamepadPreferredMode() and ZO_FormatUserFacingDisplayName(attackerDisplayName) or attackerRawName
                if(minionName == "") then
                    attackerNameLine = zo_strformat(SI_DEATH_RECAP_RANK_ATTACKER_NAME, coloredRankIconMarkup, attackerAvARank, nameToShow)
                else
                    attackerNameLine = zo_strformat(SI_DEATH_RECAP_RANK_ATTACKER_NAME_MINION, coloredRankIconMarkup, attackerAvARank, nameToShow, minionName)
                end
            else
                if(minionName == "") then
                    attackerNameLine = zo_strformat(SI_DEATH_RECAP_ATTACKER_NAME, attackerRawName)
                else
                    attackerNameLine = zo_strformat(SI_DEATH_RECAP_ATTACKER_NAME_MINION, attackerRawName, minionName)
                end
            end

            attackerNameControl:SetText(attackerNameLine)
            attackerNameControl:SetHidden(false) 

            attackerNameControl:ClearAnchors()
            attackerNameControl:SetAnchor(TOPRIGHT, damageControl, TOPLEFT, -10, 0)
            attackerNameControl:SetAnchor(TOPLEFT, nil, TOPLEFT, 150, 6)

            attackNameControl:ClearAnchors()
            attackNameControl:SetAnchor(TOPRIGHT, damageControl, TOPLEFT, -10, 0)
            attackNameControl:SetAnchor(TOPLEFT, attackerNameControl, BOTTOMLEFT, 0, 2)
        else
            attackerNameControl:SetHidden(true)

            attackNameControl:ClearAnchors()
            attackNameControl:SetAnchor(TOPRIGHT, damageControl, TOPLEFT, -10, 0)
            attackNameControl:SetAnchor(LEFT, nil, TOPLEFT, 150, 32)
        end

        local frameControl = iconControl:GetNamedChild("Frame")
        if(isBoss) then
            frameControl:SetTexture(ATTACK_BOSS_FRAME_TEXTURE)
            frameControl:SetDimensions(128, 128)
        else
            frameControl:SetTexture(ATTACK_FRAME_TEXTURE)
            frameControl:SetDimensions(56, 56)
        end

        if(prevAttackControl) then
            attackControl:SetAnchor(TOPLEFT, prevAttackControl, BOTTOMLEFT, 0, 10)
        else
            attackControl:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 0)
        end

        prevAttackControl = attackControl
    end
end

local function RandomlyTake(array)
    local index = zo_random(1, #array)
    local value = array[index]
    table.remove(array, index)
    return value
end

function DeathRecap:AddHint(text, prevHintControl)
    local hintIndex = #self.hintPool:GetActiveObjects() + 1
    local hintControl = self.hintPool:AcquireObject(hintIndex)

    hintControl:GetNamedChild("Text"):SetText(text)
            
    if(prevHintControl) then
        hintControl:SetAnchor(TOPLEFT, prevHintControl, BOTTOMLEFT, 0, 10)
    else
        hintControl:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 0)
    end

    return hintControl
end

function DeathRecap:SetupHints()
    self.hintPool:ReleaseAllObjects()
    self.hintTimeline:Stop()

    local startAlpha = self.animateOnShow and 0 or 1
    self.scrollControl:GetNamedChild("HintsContainerHints"):SetAlpha(startAlpha)

    local numHints = GetNumDeathRecapHints()

    if numHints == 0 then
        self:AddHint(GetString(SI_DEATH_RECAP_NO_HINTS))
    else
        local exclusiveHints = {}
        local alwaysShowHints = {}
        local normalHints = {}

        for i = 1, numHints do
            local hintText, hintImportance = GetDeathRecapHintInfo(i)
            if(hintImportance == DEATH_RECAP_HINT_IMPORTANCE_EXCLUSIVE) then
                table.insert(exclusiveHints, hintText)
            elseif(hintImportance == DEATH_RECAP_HINT_IMPORTANCE_ALWAYS_INCLUDE) then
                table.insert(alwaysShowHints, hintText)
            else
                table.insert(normalHints, hintText)
            end
        end

        local prevHintControl
        if(#exclusiveHints > 0) then
            local text = RandomlyTake(exclusiveHints)
            self:AddHint(text)
            return
        end

        local hintsAdded = 0
        local MAX_HINTS = 3
        while #alwaysShowHints > 0 and hintsAdded < MAX_HINTS do
            local text = RandomlyTake(alwaysShowHints)
            prevHintControl = self:AddHint(text, prevHintControl)
            hintsAdded = hintsAdded + 1
        end

        while #normalHints > 0 and hintsAdded < MAX_HINTS do
            local text = RandomlyTake(normalHints)
            prevHintControl = self:AddHint(text, prevHintControl)
            hintsAdded = hintsAdded + 1
        end        
    end
end

function DeathRecap:SetupTelvarStoneLoss()
    local telvarStonesLost = GetNumTelvarStonesLost()
    
    if telvarStonesLost > 0 then
        self.telvarStoneLossValueControl:SetText(zo_strformat(SI_DEATH_RECAP_TELVAR_STONE_LOSS_VALUE, telvarStonesLost))
        self.telvarStoneLossControl:SetAlpha(self.animateOnShow and 0 or 1)
    else
        self.telvarStoneLossControl:SetAlpha(0)
    end
end

function DeathRecap:SetupDeathRecap()
    local numAttacks = GetNumKillingAttacks()
    if(numAttacks > 0 and IsUnitDead("player")) then
        self:SetupAttacks()
        self:SetupHints()
        self:SetupTelvarStoneLoss()
        self:SetDeathRecapAvailable(true)
    else
        self:SetDeathRecapAvailable(false)
    end
end

local ATTACK_ROW_ANIMATION_OVERLAP_PERCENT = 0.5
local HINT_ANIMATION_DELAY_MS = 300

function DeathRecap:Animate()
    local delay = 0
    local lastRowDuration
    for attackRowIndex, attackControl in ipairs(self.attackPool:GetActiveObjects()) do
        local timeline = attackControl.timeline
        local isLastRow = (attackRowIndex == #self.attackPool:GetActiveObjects())
        local nestedTimeline = timeline:GetAnimationTimeline(1)
        local duration = nestedTimeline:GetDuration()
        timeline:SetAnimationTimelineOffset(nestedTimeline, delay)
        nestedTimeline.isKillingBlow = isLastRow
        timeline:PlayFromStart()
        delay = delay + duration * ATTACK_ROW_ANIMATION_OVERLAP_PERCENT

        if(isLastRow) then
            lastRowDuration = duration
        end
    end

    local nestedKBTimeline = self.killingBlowTimeline:GetAnimationTimeline(1)
    self.killingBlowTimeline:SetAnimationTimelineOffset(nestedKBTimeline, delay - lastRowDuration)
    self.killingBlowTimeline:PlayFromStart()

    if GetNumTelvarStonesLost() > 0 then
        local nestedTelvarLossTimeline = self.telvarLossTimeline:GetAnimationTimeline(1)
        self.telvarLossTimeline:SetAnimationTimelineOffset(nestedTelvarLossTimeline, delay)
        self.telvarLossTimeline:PlayFromStart()
    end
    
    local nestedTimeline = self.hintTimeline:GetAnimationTimeline(1)    
    self.hintTimeline:SetAnimationTimelineOffset(nestedTimeline, delay + HINT_ANIMATION_DELAY_MS)
    self.hintTimeline:PlayFromStart()
end

--Events

function DeathRecap:OnPlayerAlive()
    self:SetDeathRecapAvailable(false)
end

function DeathRecap:OnPlayerDead()
    self.isPlayerDead = true
    if(not self.waitingToShowPrompt) then
        self.waitingToShowPrompt = true
        EVENT_MANAGER:RegisterForUpdate("DeathRecapUpdate", DEATH_RECAP_DELAY, function()
            self.waitingToShowPrompt = false
            EVENT_MANAGER:UnregisterForUpdate("DeathRecapUpdate")
            self.animateOnShow = true
            self:SetupDeathRecap()
        end)
    end
end

function DeathRecap:OnUnitFramesCreated()
    self:RefreshUnitFrameVisibility()
end

function DeathRecap:ApplyStyle()
    ApplyTemplateToControl(self.control, ZO_GetPlatformTemplate("ZO_DeathRecap"))
    self.attackTemplate = ZO_GetPlatformTemplate("ZO_DeathRecapAttack")
    self.hintTemplate = ZO_GetPlatformTemplate("ZO_DeathRecapHint")
    self.telvarStoneLossTemplate = ZO_GetPlatformTemplate("ZO_DeathRecapTelvarStoneLoss")
    ApplyTemplateToControl(self.telvarStoneLossControl, ZO_GetPlatformTemplate("ZO_DeathRecapTelvarStoneLoss"))

    if self.isPlayerDead then
        self:SetupDeathRecap()
        if (not self.control:IsHidden()) then
            if IsInGamepadPreferredMode() then
                DIRECTIONAL_INPUT:Activate(self, self.control)
            else
                DIRECTIONAL_INPUT:Deactivate(self)
            end
        end
    end
end

function DeathRecap:OnGamepadPreferredModeChanged()
    self:ApplyStyle()
end

function DeathRecap:UpdateDirectionalInput()
    if not self.control:IsHidden() then
        DIRECTIONAL_INPUT:Consume(ZO_DI_RIGHT_STICK) -- Consume input to block camera movement when in gamepad mode with the death recap screen up.
    end
end

function DeathRecap:OnEffectivelyShown()
    if IsInGamepadPreferredMode() then
        DIRECTIONAL_INPUT:Activate(self, self.control)
    end
end

function DeathRecap:OnEffectivelyHidden()
    DIRECTIONAL_INPUT:Deactivate(self)
end

--Global XML

function ZO_DeathRecap_OnInitialized(self)
    DEATH_RECAP = DeathRecap:New(self)
    DEATH_RECAP_TOGGLE = DeathRecapToggle:New()
end
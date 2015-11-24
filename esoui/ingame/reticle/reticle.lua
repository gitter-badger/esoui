ZO_Reticle = ZO_Object:Subclass()

function ZO_Reticle:New(...)
    local reticle = ZO_Object.New(self)
    reticle:Initialize(...)
    
    return reticle
end

do
    local RETICLE_KEYBOARD_STYLE =
    {
        font = "ZoInteractionPrompt",
        keybindButtonStyle = KEYBIND_STRIP_STANDARD_STYLE,
    }

    local RETICLE_GAMEPAD_STYLE =
    {
        font = "ZoFontGamepad42",
        keybindButtonStyle = KEYBIND_STRIP_GAMEPAD_STYLE,
    }

    function ZO_Reticle:ApplyPlatformStyle(style)
        self.interactContext:SetFont(style.font)
        self.additionalInfo:SetFont(style.font)
        self.nonInteractText:SetFont(style.font)
        self.interactKeybindButton:SetupStyle(style.keybindButtonStyle)
    end

    function ZO_Reticle:Initialize(control)
        self.control = control

        self.interact = control:GetNamedChild("Interact")
        self.interactKeybindButton = self.interact:GetNamedChild("KeybindButton")
        self.interactContext = self.interact:GetNamedChild("Context")
        self.additionalInfo = self.interact:GetNamedChild("AdditionalInfo")

        self.nonInteract = control:GetNamedChild("NonInteract")
        self.nonInteractText = self.nonInteract:GetNamedChild("Text")

        self.reticleTexture = control:GetNamedChild("Reticle")
        self.padlockOverlayTexture = control:GetNamedChild("PadlockOverlay")

        self.stealthIcon = ZO_StealthIcon:New(control:GetNamedChild("StealthIcon"))

        self.reticleOpenCloseTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ReticleOpenCloseAnimation", self.reticleTexture)
        self.hitIndicatorTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ReticleHitIndicatorAnimation", self.reticleTexture)
        self.bonusScrollTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("PickpocketBonusScrollAnimation", self.additionalInfo)

        self.control:RegisterForEvent(EVENT_RETICLE_HIDDEN_UPDATE, function(event, ...) self:UpdateHiddenState(...) end)
        self.control:RegisterForEvent(EVENT_STEALTH_STATE_CHANGED, function(event, unitTag, ...) if unitTag == "player" then  self:OnStealthStateChanged(...) end end)
        self.control:RegisterForEvent(EVENT_DISGUISE_STATE_CHANGED, function(event, unitTag, ...) if unitTag == "player" then self:OnDisguiseStateChanged(...) end end)
        self.control:RegisterForEvent(EVENT_PLAYER_ACTIVATED, function(event, ...) self:SetupReticle(...) end)
        self.control:RegisterForEvent(EVENT_IMPACTFUL_HIT, function(event, ...) self:OnImpactfulHit(...) end)
        self.control:RegisterForEvent(EVENT_NO_INTERACT_TARGET, function(event, ...) PlaySound(SOUNDS.NO_INTERACT_TARGET) end)    
     
        local hideUnbound = false
        self.interactKeybindButton:SetKeybind("GAME_CAMERA_INTERACT", hideUnbound, "GAMEPAD_JUMP_OR_INTERACT")
        self.control:SetHandler("OnUpdate", function() self:OnUpdate() end)

        if IsPlayerActivated() then
            self:SetupReticle()
        end

        ZO_PlatformStyle:New(function(style) self:ApplyPlatformStyle(style) end, RETICLE_KEYBOARD_STYLE, RETICLE_GAMEPAD_STYLE)
    end
end

function ZO_Reticle:SetupReticle()
    self:OnDisguiseStateChanged(GetUnitDisguiseState("player"))
end

function ZO_Reticle:OnStealthStateChanged(newState)
    self:UpdateHiddenState()
    self.stealthIcon:OnStealthStateChanged(newState)
end

function ZO_Reticle:OnDisguiseStateChanged(newState)
    self:UpdateHiddenState()
    self.stealthIcon:OnDisguiseStateChanged(newState)
end

function ZO_Reticle:TryHandlingQuestInteraction(questInteraction, questTargetBased, questJournalIndex, questToolIndex, questToolOnCooldown)
    if questInteraction then
        local questToolName = select(4, GetQuestToolInfo(questJournalIndex, questToolIndex))

        self.interactKeybindButton:SetText(zo_strformat(SI_GAME_CAMERA_ACTION_QUEST_ITEM, questToolName))
        if not questInteraction or questTargetBased then
            self.interactContext:SetText(GetNameOfGameCameraQuestToolTarget())
        else
            self.interactContext:SetText("")
        end

        self.interactKeybindButton:SetEnabled(not questToolOnCooldown)
        return true
    end
end

function ZO_Reticle:TryHandlingInteraction(interactionPossible)
    if interactionPossible then
        local action, interactableName, interactionBlocked, isOwned, additionalInteractInfo, context, contextLink = GetGameCameraInteractableActionInfo()
        local interactKeybindButtonColor = ZO_NORMAL_TEXT
        local additionalInfoLabelColor = ZO_CONTRAST_TEXT
        self.interactKeybindButton:ShowKeyIcon()

        if action and interactableName then
            if additionalInteractInfo == ADDITIONAL_INTERACT_INFO_NONE or additionalInteractInfo == ADDITIONAL_INTERACT_INFO_INSTANCE_TYPE then
                self.interactKeybindButton:SetText(zo_strformat(SI_GAME_CAMERA_TARGET, action))
                if (isOwned) then 
                    interactKeybindButtonColor = ZO_ERROR_COLOR
                end
            elseif additionalInteractInfo == ADDITIONAL_INTERACT_INFO_EMPTY then
                self.interactKeybindButton:SetText(zo_strformat(SI_FORMAT_BULLET_TEXT, GetString(SI_GAME_CAMERA_ACTION_EMPTY)))
                self.interactKeybindButton:HideKeyIcon()
            elseif additionalInteractInfo == ADDITIONAL_INTERACT_INFO_LOCKED then
                local lockQuality = context
                self.interactKeybindButton:SetText(zo_strformat(SI_GAME_CAMERA_TARGET_ADDITIONAL_INFO, action, GetString("SI_LOCKQUALITY", lockQuality)))
                if (isOwned) then 
                    TriggerTutorial(TUTORIAL_TRIGGER_OWNED_LOCK_VIEWED)
                    interactKeybindButtonColor = ZO_ERROR_COLOR
                end
            elseif additionalInteractInfo == ADDITIONAL_INTERACT_INFO_FISHING_NODE then
                self.additionalInfo:SetHidden(false)
                self.additionalInfo:SetText(GetString(SI_HOLD_TO_SELECT_BAIT))
                local lure = GetFishingLure()
                if lure then
                    local name = GetFishingLureInfo(lure)
                    self.interactKeybindButton:SetText(zo_strformat(SI_GAME_CAMERA_TARGET_ADDITIONAL_INFO_BAIT, action, name))
                else
                    self.interactKeybindButton:SetText(zo_strformat(SI_GAME_CAMERA_TARGET_ADDITIONAL_INFO, action, GetString(SI_NO_BAIT_OR_LURE_SELECTED)))
                end
            elseif additionalInteractInfo == ADDITIONAL_INTERACT_INFO_REQUIRES_KEY then
                local itemName = GetItemLinkName(contextLink)
                if interactionBlocked == true then
                    self.interactKeybindButton:SetText(zo_strformat(SI_GAME_CAMERA_TARGET_ADDITIONAL_INFO_REQUIRES_KEY, action, itemName))
                else
                    self.interactKeybindButton:SetText(zo_strformat(SI_GAME_CAMERA_TARGET_ADDITIONAL_INFO_WILL_CONSUME_KEY, action, itemName))
                end                
            elseif additionalInteractInfo == ADDITIONAL_INTERACT_INFO_PICKPOCKET_CHANCE then
                local isHostile, difficulty, isEmpty
				self.isInBonus, isHostile, self.percentChance, difficulty, isEmpty, prospectiveResult = GetGameCameraPickpocketingBonusInfo()

                -- Prevent your success chance from going over 100%
                self.percentChance = zo_min(self.percentChance, 100)

                local additionalInfoText
				if(isEmpty and prospectiveResult == PROSPECTIVE_PICKPOCKET_RESULT_INVENTORY_FULL) then
					additionalInfoText = GetString(SI_JUSTICE_PICKPOCKET_TARGET_EMPTY)
                elseif prospectiveResult ~= PROSPECTIVE_PICKPOCKET_RESULT_CAN_ATTEMPT then
                    additionalInfoText = GetString("SI_PROSPECTIVEPICKPOCKETRESULT", prospectiveResult)
                else
                    additionalInfoText = (isEmpty and GetString(SI_JUSTICE_PICKPOCKET_TARGET_EMPTY) or GetString("SI_PICKPOCKETDIFFICULTYTYPE", difficulty))
                end
                
                self.interactKeybindButton:SetText(zo_strformat(SI_GAME_CAMERA_TARGET_ADDITIONAL_INFO, action, additionalInfoText))
                
                interactKeybindButtonColor = ((not isHostile) and ZO_ERROR_COLOR or ZO_NORMAL_TEXT)
                
                if not interactionBlocked then
                    TriggerTutorial(TUTORIAL_TRIGGER_PICKPOCKET_PROMPT_VIEWED)
                    self.additionalInfo:SetHidden(false)
                    additionalInfoLabelColor = (self.isInBonus and ZO_SUCCEEDED_TEXT or ZO_CONTRAST_TEXT)

                    if(self.isInBonus and not self.wasInBonus) then
                        self.bonusScrollTimeline:PlayForward()
                        PlaySound(SOUNDS.JUSTICE_PICKPOCKET_BONUS)
                        self.wasInBonus = true
                    elseif(not self.isInBonus and self.wasInBonus) then
                        self.bonusScrollTimeline:PlayBackward()
                        self.wasInBonus = false
                    elseif(not self.bonusScrollTimeline:IsPlaying()) then
                        self.additionalInfo:SetText(zo_strformat(SI_PICKPOCKET_SUCCESS_CHANCE, self.percentChance))
                        self.oldPercentChance = self.percentChance
                    end
                else
                    self.additionalInfo:SetHidden(true)
                end
            elseif additionalInteractInfo == ADDITIONAL_INTERACT_INFO_WEREWOLF_ACTIVE_WHILE_ATTEMPTING_TO_CRAFT then
                self.interactKeybindButton:SetText(zo_strformat(SI_CANNOT_CRAFT_WHILE_WEREWOLF))
            end
			
			local interactContextString = interactableName;
			if(additionalInteractInfo == ADDITIONAL_INTERACT_INFO_INSTANCE_TYPE) then
				local instanceType = context
				if instanceType ~= INSTANCE_DISPLAY_TYPE_NONE then 
					local instanceTypeString = zo_iconTextFormat(GetInstanceDisplayTypeIcon(instanceType), 34, 34, GetString("SI_INSTANCEDISPLAYTYPE", instanceType))
					interactContextString = zo_strformat(SI_ZONE_DOOR_RETICLE_INSTANCE_TYPE_FORMAT, interactableName, instanceTypeString)
				end
			end
            self.interactContext:SetText(interactContextString)

            self.interactionBlocked = interactionBlocked
            self.interactKeybindButton:SetNormalTextColor(interactKeybindButtonColor)
            self.additionalInfo:SetColor(additionalInfoLabelColor:UnpackRGBA())  
            return true
        end
    end
end


function ZO_Reticle:TryHandlingGroundTargetingError()
    local error = GetGroundTargetingError()
    if error then
        self.nonInteractText:SetText(zo_strformat(GetString("SI_ACTIONRESULT", error)))
        return true
    end

    return false
end

function ZO_Reticle:TryHandlingNonInteractableFixture()
    local nonInteractableName = GetGameCameraNonInteractableName()
    if nonInteractableName then
        self.nonInteractText:SetText(zo_strformat(SI_TOOLTIP_FIXTURE_INSTANCE, nonInteractableName))
        return true
    end
    return false
end

function ZO_Reticle:UpdateInteractText()
    self.additionalInfo:SetHidden(true)
    if IsGameCameraActive() and not IsGameCameraUIModeActive() then
        --Priority is
        --1. Ground targeting
        --2. Target based quest item
        --3. Unit interaction
        --4. Non-target based quest item
        --5. Non-interactable fixtures, such as signs

        self.interact:SetHidden(true)
        self.nonInteract:SetHidden(true)
        self.interactionBlocked = false
        self.interactKeybindButton:SetNormalTextColor(ZO_NORMAL_TEXT)

		local interactionType = GetInteractionType()

        -- The loot window does some fancy stuff with this text...wait until it is gone to show it again
        if interactionType == INTERACTION_LOOT then
            return
        end

        if IsPlayerGroundTargeting() then
            if self:TryHandlingGroundTargetingError() then
                self.nonInteract:SetHidden(false)
            end
        else
            local interactionExists, interactionAvailableNow, questInteraction, questTargetBased, questJournalIndex, questToolIndex, questToolOnCooldown = GetGameCameraInteractableInfo()
            if questTargetBased and self:TryHandlingQuestInteraction(questInteraction, questTargetBased, questJournalIndex, questToolIndex, questToolOnCooldown) then
                self.interact:SetHidden(false)
            elseif self:TryHandlingInteraction(interactionExists) then
                self.interact:SetHidden(false)
            elseif self:TryHandlingQuestInteraction(questInteraction, questTargetBased, questJournalIndex, questToolIndex, questToolOnCooldown) then
                self.interact:SetHidden(false)
            elseif self:TryHandlingNonInteractableFixture() then
                self.nonInteract:SetHidden(false)
            end
        end

		local showBusy = interactionType ~= INTERACTION_NONE and interactionType ~= INTERACTION_FISH and interactionType ~= INTERACTION_PICKPOCKET or (IsInGamepadPreferredMode() and IsBlockActive())
		self.interactKeybindButton:SetEnabled(not showBusy and not self.interactionBlocked)
    end
end

function ZO_Reticle:OnUpdate()
    local interactionPossible = not self.interact:IsHidden()

    if interactionPossible or PLAYER_TO_PLAYER:HasTarget() or IsGameCameraUnitHighlightedAttackable() then
        self.reticleOpenCloseTimeline:PlayForward()
    else
        self.reticleOpenCloseTimeline:PlayBackward()
    end

    self:UpdateInteractText()
end

function ZO_Reticle:RequestHidden(hidden)
    self.reticleHiddenExternalRequest = hidden
    self:UpdateHiddenState()
end

function ZO_Reticle:GetInteractPromptVisible()
    return not self.interact:IsHidden()
end

function ZO_Reticle:UpdateHiddenState()
    local reticleHidden = IsReticleHidden() or self.reticleHiddenExternalRequest
    local inStealthOrDisguise = GetUnitDisguiseState("player") ~= DISGUISE_STATE_NONE or GetUnitStealthState("player") ~= STEALTH_STATE_NONE

    self.control:SetHidden(reticleHidden)
    self.reticleTexture:SetHidden(inStealthOrDisguise)

    if not inStealthOrDisguise then
        self.stealthIcon:AnimateInStealthText()
    end
end

function ZO_Reticle:OnImpactfulHit()
    self.hitIndicatorTimeline:PlayFromStart()
end

function ZO_Reticle:AnimatePickpocketBonus(progress)
    local animatedChance = zo_floor((self.percentChance - (self.oldPercentChance or 0)) * progress) + (self.oldPercentChance or 0)
    self.additionalInfo:SetText(zo_strformat(SI_PICKPOCKET_SUCCESS_CHANCE, animatedChance))
end

function ZO_Reticle_AnimatePickpocketBonus(progress)
    RETICLE:AnimatePickpocketBonus(progress)
end

function ZO_Reticle_Initialize(control)
    RETICLE = ZO_Reticle:New(control)
end

-------------------------------
--  Stealth icon
-------------------------------

local STEALTH_ANIMATION_FRAMES = 64
local STEALTH_ANIMATION_DEFAULT_DURATION = 500

local STEALTH_ANIMATION_START = 0
local STEALTH_ANIMATION_MID = 1
local STEALTH_ANIMATION_END = 2

local DisguiseToStealthState = 
{
    [DISGUISE_STATE_DISGUISED] = STEALTH_STATE_STEALTH,
    [DISGUISE_STATE_DANGER] = STEALTH_STATE_STEALTH_ALMOST_DETECTED,
    [DISGUISE_STATE_SUSPICIOUS] = STEALTH_STATE_STEALTH_ALMOST_DETECTED,
    [DISGUISE_STATE_DISCOVERED] = STEALTH_STATE_DETECTED,
}

ZO_StealthIcon = ZO_Object:Subclass()

--
-- Lifecycle
--

function ZO_StealthIcon:New(...)
    local stealthIcon = ZO_Object.New(self)
    stealthIcon:Initialize(...)
    
    return stealthIcon
end
do
    local STEALTH_KEYBOARD_STYLE =
    {
        font = "ZoInteractionPrompt",
    }

    local STEALTH_GAMEPAD_STYLE =
    {
        font = "ZoFontGamepad36",
    }

    function ZO_StealthIcon:ApplyPlatformStyle(style)
        self.stealthText:SetFont(style.font)
    end

    function ZO_StealthIcon:Initialize(control)
        self.hiddenStates =
        {
            [STEALTH_STATE_HIDDEN] = true,
            [STEALTH_STATE_STEALTH] = true,
            [STEALTH_STATE_HIDDEN_ALMOST_DETECTED] = true,        
            [STEALTH_STATE_STEALTH_ALMOST_DETECTED] = true,
            [STEALTH_STATE_NONE] = false,
            [STEALTH_STATE_DETECTED] = false,
        }

        self.stealthSounds =
        {
            [STEALTH_STATE_HIDDEN] = SOUNDS.STEALTH_HIDDEN,
            [STEALTH_STATE_STEALTH] = SOUNDS.STEALTH_HIDDEN,
            [STEALTH_STATE_DETECTED] = SOUNDS.STEALTH_DETECTED,
        }

        self.control = control

        self.stealthEyeTexture = control:GetNamedChild("StealthEye")
        self.stealthText = control:GetNamedChild("StealthText")

        self.stealthEyeTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("StealthIconStealthEyeAnimation", self.stealthEyeTexture)
        self.stealthEyeTimeline:SetHandler("OnStop", function(timeline) timeline:ClearAllCallbacks() end)
        self.currentStealthState = STEALTH_STATE_NONE
        self.nextStealthState = STEALTH_STATE_NONE
        self.disguiseState = DISGUISE_STATE_NONE

        self.stealthTextTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("StealthIconStealthTextFadeAnimation", self.stealthText)

        ZO_PlatformStyle:New(function(style) self:ApplyPlatformStyle(style) end, STEALTH_KEYBOARD_STYLE, STEALTH_GAMEPAD_STYLE)
    end
end

--
-- Animations and updates
--

function ZO_StealthIcon:AnimateInStealthText(stringId)
    if stringId then
        self.stealthText:SetText(zo_strformat(stringId))

        if not self.stealthTextStringId or not stringId == self.stealthTextStringId then
            self.stealthTextTimeline:PlayFromStart()
        end
    end

    self.stealthTextStringId = stringId
end

function ZO_StealthIcon:HideStealthText()
    self.stealthTextStringId = nil
    self.stealthTextTimeline:PlayInstantlyToEnd()
end

function ZO_StealthIcon:SnapEyeAnimationToPoint(animPoint)
    if animPoint == STEALTH_ANIMATION_START then
        self.stealthEyeTexture:SetTextureCoords(0, 1 / STEALTH_ANIMATION_FRAMES, 0, 1)
    elseif animPoint == STEALTH_ANIMATION_MID then
        self.stealthEyeTexture:SetTextureCoords(0.5 - 1 / STEALTH_ANIMATION_FRAMES, 0.5, 0, 1)
    elseif animPoint == STEALTH_ANIMATION_END then
        self.stealthEyeTexture:SetTextureCoords(1 - 1 / STEALTH_ANIMATION_FRAMES, 1, 0, 1)
    end
end

function ZO_StealthIcon:UpdateStealthEye(stealthState)
    self.stealthEyeTexture:SetHidden(stealthState == STEALTH_STATE_NONE)

    self.stealthEyeTimeline:Stop()

    if stealthState == STEALTH_STATE_STEALTH or stealthState == STEALTH_STATE_HIDDEN then
        if self.currentStealthState == STEALTH_STATE_STEALTH_ALMOST_DETECTED or self.currentStealthState == STEALTH_STATE_HIDDEN_ALMOST_DETECTED then
            self.stealthEyeTimeline:GetFirstAnimation():SetDuration(STEALTH_ANIMATION_DEFAULT_DURATION)
            self.stealthEyeTimeline:InsertCallback(function(timeline) timeline:Stop(); timeline:ClearAllCallbacks() end, STEALTH_ANIMATION_DEFAULT_DURATION)
            self.stealthEyeTimeline:PlayFromStart(STEALTH_ANIMATION_DEFAULT_DURATION * .5)
        else
            PlaySound(SOUNDS.STEALTH_HIDDEN)
            self:SnapEyeAnimationToPoint(STEALTH_ANIMATION_END)
            self:AnimateInStealthText(SI_STEALTH_HIDDEN)
        end
    elseif stealthState == STEALTH_STATE_DETECTED then
        if self.currentStealthState == STEALTH_STATE_STEALTH_ALMOST_DETECTED or self.currentStealthState == STEALTH_STATE_HIDDEN_ALMOST_DETECTED then
            PlaySound(SOUNDS.STEALTH_DETECTED)
            self.stealthEyeTimeline:GetFirstAnimation():SetDuration(STEALTH_ANIMATION_DEFAULT_DURATION)
            self.stealthEyeTimeline:PlayFromEnd(STEALTH_ANIMATION_DEFAULT_DURATION * .5)
        elseif self.currentStealthState == STEALTH_STATE_STEALTH or self.currentStealthState == STEALTH_STATE_HIDDEN then
            PlaySound(SOUNDS.STEALTH_DETECTED)
            self.stealthEyeTimeline:GetFirstAnimation():SetDuration(STEALTH_ANIMATION_DEFAULT_DURATION)
            self.stealthEyeTimeline:PlayFromEnd()
        else
            self:SnapEyeAnimationToPoint(STEALTH_ANIMATION_START)
        end
    elseif stealthState == STEALTH_STATE_HIDING then
        local currentTime = GetFrameTimeSeconds()
        local hidingEndTime = GetUnitHidingEndTime("player")
        local hidingTimeRemaining = zo_max(zo_ceil(hidingEndTime - currentTime), 0)
        self.stealthEyeTimeline:GetFirstAnimation():SetDuration(hidingTimeRemaining * 1000)
        self.stealthEyeTimeline:PlayFromStart()
    elseif stealthState == STEALTH_STATE_STEALTH_ALMOST_DETECTED or stealthState == STEALTH_STATE_HIDDEN_ALMOST_DETECTED then
        if self.currentStealthState == STEALTH_STATE_STEALTH or self.currentStealthState == STEALTH_STATE_HIDDEN then
            self.stealthEyeTimeline:GetFirstAnimation():SetDuration(STEALTH_ANIMATION_DEFAULT_DURATION)
            self.stealthEyeTimeline:InsertCallback(function(timeline) timeline:Stop() timeline:ClearAllCallbacks() end, STEALTH_ANIMATION_DEFAULT_DURATION * .5)
            self.stealthEyeTimeline:PlayFromEnd()
        else
            self:SnapEyeAnimationToPoint(STEALTH_ANIMATION_MID)

            if stealthState == STEALTH_STATE_HIDDEN_ALMOST_DETECTED then
                self:AnimateInStealthText(SI_STEALTH_HIDDEN)
            end
        end
    end

    self.currentStealthState = stealthState
end

-- 
-- Event Handlers
--
function ZO_StealthIcon:RefreshStealthReticle()
    -- Update the text    
    if self.disguiseState == DISGUISE_STATE_DISGUISED then
        self:AnimateInStealthText(SI_DISGUISE_DISGUISED)
    elseif self.disguiseState == DISGUISE_STATE_DANGER then
        self:AnimateInStealthText(SI_DISGUISE_DANGER)
    elseif self.disguiseState == DISGUISE_STATE_SUSPICIOUS then
        self:AnimateInStealthText(SI_DISGUISE_SUSPICIOUS)
    elseif self.disguiseState == DISGUISE_STATE_DISCOVERED then
        self:AnimateInStealthText(SI_DISGUISE_DISCOVERED)
    elseif self.hiddenStates[self.nextStealthState] then
        self:AnimateInStealthText(SI_STEALTH_HIDDEN)
    elseif self.nextStealthState == STEALTH_STATE_DETECTED then
        self:AnimateInStealthText(SI_STEALTH_DETECTED)
    else
        self:HideStealthText()
    end

    -- Then update the eye
    if DisguiseToStealthState[self.disguiseState] then
        self:UpdateStealthEye(DisguiseToStealthState[self.disguiseState])
    else
        self:UpdateStealthEye(self.nextStealthState)
    end
end

function ZO_StealthIcon:OnStealthStateChanged(stealthState)
    self.nextStealthState = stealthState
    self:RefreshStealthReticle()
end

function ZO_StealthIcon:OnDisguiseStateChanged(disguiseState)
    self.disguiseState = disguiseState
    self:RefreshStealthReticle()
end

local MAX_CHATTER_OPTIONS = 10 -- keep this updated with the keybinds
local CHATTER_OPTION_INDENT = 30

local REWARD_STRIDE = 2
local REWARD_PADDING_X = 20
local REWARD_PADDING_Y = 10
local REWARD_SIZE_X = 240
local REWARD_SIZE_Y = 52
local REWARD_ROOT_OFFSET_X = 0
local REWARD_ROOT_OFFSET_Y = 10

local ENABLED_PLAYER_OPTION_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_CHATTER_PLAYER_OPTION))
local SEEN_PLAYER_OPTION_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_GENERAL, INTERFACE_GENERAL_COLOR_DISABLED))
local DISABLED_PLAYER_OPTION_COLOR = ZO_ERROR_COLOR
local HIGHLIGHT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_HIGHLIGHT))

local INTERACT_GOLD_ICON = zo_iconFormat("EsoUI/Art/currency/currency_gold.dds", 16, 16)


--Keyboard Interaction
---------------------

ZO_Interaction = ZO_SharedInteraction:Subclass()

function ZO_Interaction:New(...)
    local interaction = ZO_SharedInteraction.New(self)
    interaction:Initialize(...)
    return interaction
end

function ZO_Interaction:Initialize(control)
    self.control = control
    self.sceneName = "interaction"

    ZO_SharedInteraction.Initialize(self, control)

    self:InitInteraction()

    local function OnStateChange(oldState, newState)
        if(newState == SCENE_HIDDEN) then
            ZO_SharedInteraction.OnHidden(self)
        end
    end

    local interactScene = self:CreateInteractScene("interact")
    interactScene:RegisterCallback("StateChange", OnStateChange)

    SYSTEMS:RegisterKeyboardObject(ZO_INTERACTION_SYSTEM_NAME, self)

    self:OnScreenResized()
end

function ZO_Interaction:InitInteraction()

    self.titleControl = self.control:GetNamedChild("TargetAreaTitle")
    self.chatterOptionName = "ZO_ChatterOption"
    self.questRewardName = "ZO_QuestReward"
    self.currencyTemplateName = "ZO_CurrencyTemplate"

    --create options
    CreateControlRangeFromVirtual(self.chatterOptionName, self.control:GetNamedChild("PlayerAreaOptions"), self.chatterOptionName, 1, MAX_CHATTER_OPTIONS)

    self.optionControls = {}

    local currentAnchor = ZO_Anchor:New(TOPLEFT, ZO_InteractWindowPlayerAreaOptions, TOPLEFT, CHATTER_OPTION_INDENT, 0)
    local previousOption
    for i = 1, MAX_CHATTER_OPTIONS do
        local currentOption = GetControl(self.chatterOptionName, i)
        self.optionControls[i] = currentOption

        currentOption:SetHidden(true)

        currentAnchor:Set(currentOption)
        currentAnchor:SetTarget(currentOption)
        currentAnchor:SetOffsets(0, 8)
        currentAnchor:SetRelativePoint(BOTTOMLEFT)

        previousOption = currentOption
    end

    --create rewards
    self.givenRewardPool = ZO_ControlPool:New(self.questRewardName, self.control:GetNamedChild("RewardArea"), "Given")
    self.currencyRewardPool = ZO_ControlPool:New(self.currencyTemplateName, self.control:GetNamedChild("RewardArea"), "Currency")
end

function ZO_Interaction:ResetInteraction(bodyText)
    self.titleControl:SetText(zo_strformat(GetString(SI_INTERACT_TITLE_FORMAT), GetUnitName("interact")))

    self.control:GetNamedChild("TargetAreaBodyText"):SetText(bodyText)

    for i = 1, MAX_CHATTER_OPTIONS do
        local option = self.optionControls[i]
        option:SetHandler("OnUpdate", nil)
        option.optionIndex = nil
        option:SetHidden(true)
    end

    self.givenRewardPool:ReleaseAllObjects()
    self.currencyRewardPool:ReleaseAllObjects()

    self.control:GetNamedChild("RewardArea"):SetHidden(true)
    self.control:GetNamedChild("RewardArea"):SetHeight(0)
end

local INTERACTION_AREA_PERC_WIDTH = 0.4
local INTERACTION_AREA_RIGHT_OFFSET_PERC = 0.0534

function ZO_Interaction:OnScreenResized()
    local uiWidth, uiHeight = GuiRoot:GetDimensions()

    local divider = self.control:GetNamedChild("Divider")
    divider:ClearAnchors()
    divider:SetAnchor(RIGHT, GuiRoot, TOPRIGHT, -uiWidth * INTERACTION_AREA_RIGHT_OFFSET_PERC, uiHeight * .5)

    local interactionElementWidth = uiWidth * INTERACTION_AREA_PERC_WIDTH

    divider:SetWidth(interactionElementWidth)

    for i = 1, MAX_CHATTER_OPTIONS do
        local currentOption = GetControl(self.chatterOptionName, i)
        currentOption:SetWidth(interactionElementWidth - CHATTER_OPTION_INDENT)
    end
end

function ZO_Interaction:DimOtherImportantOptions(chatterControl)
    if chatterControl.isImportant then
        for i, control in ipairs(self.importantOptions) do
            if control ~= chatterControl then
                control:SetColor(DISABLED_PLAYER_OPTION_COLOR:UnpackRGBA())
            end
        end
    end
end

function ZO_Interaction:RestoreOtherImportantOptions(chatterControl)
    for i, control in ipairs(self.importantOptions) do
        if control ~= chatterControl then
            if control.enabled then
                control:SetColor(ENABLED_PLAYER_OPTION_COLOR:UnpackRGBA())
            else
                control:SetColor(DISABLED_PLAYER_OPTION_COLOR:UnpackRGBA())
            end
        end
    end
end

local function DisableChatterOption(option, useDisabledColor)
    if useDisabledColor then
        option:SetColor(DISABLED_PLAYER_OPTION_COLOR:UnpackRGBA())
    end

    GetControl(option, "IconImage"):SetDesaturation(1)
    option.enabled = false
end

local function EnableChatterOption(option)
    if(option.chosenBefore) then
        option:SetColor(SEEN_PLAYER_OPTION_COLOR:UnpackRGBA())
    else
        option:SetColor(ENABLED_PLAYER_OPTION_COLOR:UnpackRGBA())
    end
    GetControl(option, "IconImage"):SetDesaturation(0)
    option.enabled = true
end

function ZO_Interaction:PopulateChatterOption(controlID, optionIndex, optionText, optionType, optionalArg, isImportant, chosenBefore, importantOptions)
    local optionControl = self.optionControls[controlID]
    optionControl:SetHidden(false)

    local chatterData = self:GetChatterOptionData(optionIndex, optionText, optionType, optionalArg, isImportant, chosenBefore)

    optionControl.optionIndex = chatterData.optionIndex
    optionControl.optionType = chatterData.optionType
    optionControl.isImportant = chatterData.isImportant
    optionControl.chosenBefore = chatterData.chosenBefore
    optionControl.gold = chatterData.gold

    if optionControl.isImportant then
        importantOptions[#importantOptions + 1] = optionControl
        TriggerTutorial(TUTORIAL_TRIGGER_IMPORTANT_DIALOGUE)
    end

    if(chatterData.optionsEnabled) then

        if(chatterData.optionUsable) then
            EnableChatterOption(optionControl)
        else
            DisableChatterOption(optionControl, chatterData.recolorIfUnusable)
        end

        optionControl:SetText(chatterData.optionText)
        optionControl:SetHandler("OnUpdate", chatterData.labelUpdateFunction)

        local icon = GetControl(optionControl, "IconImage")

        icon:SetHidden((chatterData.iconFile == nil) or not USE_CHATTER_OPTION_ICON)

        if(chatterData.iconFile) then
            icon:SetTexture(chatterData.iconFile)
        end

        local _, textHeight = optionControl:GetTextDimensions()
        return textHeight
    end

    return 0
end

function ZO_Interaction:AnchorBottomBG(optionControl)
    -- NOTE: The -10 and 120 come from the XML offset...see how $(parent)TopBG is set up.
    self.control:GetNamedChild("BottomBG"):ClearAnchors()
    self.control:GetNamedChild("BottomBG"):SetAnchor(TOPRIGHT, GuiRoot, RIGHT)
    self.control:GetNamedChild("BottomBG"):SetAnchor(BOTTOMLEFT, optionControl, BOTTOMLEFT, -10 - CHATTER_OPTION_INDENT, 120)
end

function ZO_Interaction:FinalizeChatterOptions(optionCount)
    self:AnchorBottomBG(self.optionControls[optionCount])
end

function ZO_Interaction:UpdateChatterOptions(optionCount, backToTOCOption)

    self.optionCount, self.importantOptions = self:PopulateChatterOptions(optionCount, backToTOCOption)

    if #self.importantOptions > 0 and self.currentMouseLabel then
        self:DimOtherImportantOptions(self.currentMouseLabel)
    end
end

function ZO_Interaction:SelectChatterOptionByIndex(optionIndex)
    local option = self.optionControls[optionIndex]
    if option and option.optionIndex then
        self:HandleChatterOptionClicked(option)
    end
end

function ZO_Interaction:SelectLastChatterOption()
    self:SelectChatterOptionByIndex(self.optionCount)
end

function ZO_Interaction:ShowQuestRewards(journalQuestIndex)
    local anchorIndex = 0
    local ROOT_REWARD_ANCHOR = ZO_Anchor:New(TOPLEFT, self.control:GetNamedChild("RewardAreaHeader"), BOTTOMLEFT, 0, 0)
    local rewardCurrencyOptions = {showTooltips = true, font = "ZoFontConversationQuestReward", iconSize = 24, iconSide = LEFT }

    g_numItemRewardsForQuest = 0
    local moneyAnchorControl = ZO_InteractWindowRewardAreaHeader
    local moneyControls = {}

    local rewardData = self:GetRewardData(journalQuestIndex)
    local numRewards = #rewardData

    for i, reward in ipairs(rewardData) do
        local creatorFunc = self:GetRewardCreateFunc(reward.rewardType)
        if(creatorFunc) then
            if(self:IsCurrencyReward(reward.rewardType)) then
                local control = self.currencyRewardPool:AcquireObject()
                creatorFunc(control, reward.name, reward.amount, rewardCurrencyOptions)

                if(#moneyControls ~= 0) then
                    control:ClearAnchors()
                    control:SetAnchor(TOPLEFT, moneyControls[#moneyControls], BOTTOMLEFT, 0, 4)
                end

                moneyControls[#moneyControls + 1] = control
            else
                local control = self.givenRewardPool:AcquireObject()
                control.index = i
                control.itemType = reward.itemType
                if control.itemType == REWARD_ITEM_TYPE_COLLECTIBLE then
                    control.itemId = GetJournalQuestRewardCollectibleId(journalQuestIndex, i)
                end

                creatorFunc(control, reward.name, reward.amount, reward.icon, reward.meetsUsageRequirement, reward.quality)

                -- Money rewards do not get box-anchored, they're shown after all the reward icons (or immediately if there were no icons)
                ZO_Anchor_BoxLayout(ROOT_REWARD_ANCHOR, control, anchorIndex, REWARD_STRIDE, REWARD_PADDING_X, REWARD_PADDING_Y, REWARD_SIZE_X, REWARD_SIZE_Y, REWARD_ROOT_OFFSET_X, REWARD_ROOT_OFFSET_Y)
                anchorIndex = anchorIndex + 1

                -- Controls in the first column and last row serve as the anchor for the money reward control
                if(zo_mod(anchorIndex, REWARD_STRIDE) == 1) then
                    moneyAnchorControl = control
                end
            end
        end
    end

    local rewardWindowHeight = zo_ceil(anchorIndex / REWARD_STRIDE) * (REWARD_SIZE_Y + REWARD_PADDING_Y) + 50
    local initialMoneyControl = moneyControls[1]

    if(initialMoneyControl) then
        rewardWindowHeight = rewardWindowHeight + (#moneyControls * 28)

        initialMoneyControl:ClearAnchors()
        initialMoneyControl:SetAnchor(TOPLEFT, moneyAnchorControl, BOTTOMLEFT, 0, 28)
    end

    ZO_InteractWindowRewardArea:SetHidden(numRewards == 0)
    ZO_InteractWindowRewardArea:SetHeight(rewardWindowHeight)
end

function ZO_Interaction:GetInteractGoldIcon()
    return INTERACT_GOLD_ICON
end

--XML Handlers
--------------

function ZO_ChatterOption_MouseUp(label, button, upInside)
    if(button == MOUSE_BUTTON_INDEX_LEFT and upInside) then
        INTERACTION:HandleChatterOptionClicked(label)
    end
end

function ZO_ChatterOption_MouseEnter(label)
    local highlight = ZO_InteractWindowPlayerAreaHighlight
    highlight:ClearAnchors()
    highlight:SetAnchorFill(label)
    highlight:SetHidden(false)

    if label.isImportant then
        INTERACTION:DimOtherImportantOptions(label)
    end

    INTERACTION.currentMouseLabel = label
end

function ZO_ChatterOption_MouseExit(label)
    ZO_InteractWindowPlayerAreaHighlight:SetHidden(true)

    if label.isImportant then
        INTERACTION:RestoreOtherImportantOptions(label)
    end

    INTERACTION.currentMouseLabel = nil
end

function ZO_QuestReward_MouseEnter(control)
    if control.allowTooltip then
        if control.itemType == REWARD_ITEM_TYPE_ITEM then
            InitializeTooltip(ItemTooltip)
            ItemTooltip:SetQuestReward(control.index)
            ItemTooltip:ShowComparativeTooltips()
            ZO_PlayShowAnimationOnComparisonTooltip(ComparativeTooltip1)
            ZO_PlayShowAnimationOnComparisonTooltip(ComparativeTooltip2)
            ZO_Tooltips_SetupDynamicTooltipAnchors(ItemTooltip, control, ComparativeTooltip1, ComparativeTooltip2)
        elseif control.itemType == REWARD_ITEM_TYPE_COLLECTIBLE then
            InitializeTooltip(ItemTooltip, control, RIGHT, -5, 0, LEFT)
            local ADD_NICKNAME, SHOW_HINT = false, false
            ItemTooltip:SetCollectible(control.itemId, ADD_NICKNAME, SHOW_HINT)
        end
    end
end

function ZO_QuestReward_MouseExit(control)
    if control.allowTooltip then
        ClearTooltip(ItemTooltip)
        if control.itemType == REWARD_ITEM_TYPE_ITEM then
            ZO_PlayHideAnimationOnComparisonTooltip(ComparativeTooltip1)
            ZO_PlayHideAnimationOnComparisonTooltip(ComparativeTooltip2)
        end
    end
end

function ZO_InteractWindow_Initialize(control)
    INTERACTION = ZO_Interaction:New(control)
end

local WorldMapQuests_Gamepad = ZO_WorldMapQuests_Shared:Subclass()

local ASSISTED_TEXTURE = "EsoUI/Art/Journal/Gamepad/gp_trackedQuestIcon.dds"
local QUEST_DATA = 1

function WorldMapQuests_Gamepad:New(...)
    local object = ZO_WorldMapQuests_Shared.New(self, ...)
    return object
end

function WorldMapQuests_Gamepad:Initialize(control)
    ZO_WorldMapQuests_Shared.Initialize(self, control)
    self.control = control
    self.noQuestsLabel = control:GetNamedChild("Main"):GetNamedChild("NoQuests")

    self.scrollTooltip = control:GetNamedChild("SideContent"):GetNamedChild("Tooltip")
    ZO_ScrollTooltip_Gamepad:Initialize(self.scrollTooltip, ZO_TOOLTIP_STYLES, "worldMapTooltip")
    zo_mixin(self.scrollTooltip, ZO_MapInformationTooltip_Gamepad_Mixin)
    ZO_Scroll_Gamepad_SetScrollIndicatorSide(self.scrollTooltip.scrollIndicator, ZO_SharedGamepadNavQuadrant_4_Background, LEFT)

    self.questList = ZO_GamepadVerticalParametricScrollList:New(control:GetNamedChild("Main"):GetNamedChild("List"))
    self.questList:SetAlignToScreenCenter(true)
    self.questList:AddDataTemplate("ZO_GamepadSubMenuEntryTemplateWithStatusLowercase42", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    self.questList:SetOnSelectedDataChangedCallback(function(list, selectedData) self:SetupQuestDetails(selectedData) end)

    self.entriesByIndex = {}

    self:InitializeKeybindDescriptor()

    GAMEPAD_WORLD_MAP_QUESTS_FRAGMENT = ZO_FadeSceneFragment:New(control)
    GAMEPAD_WORLD_MAP_QUESTS_FRAGMENT:RegisterCallback("StateChange",  function(oldState, newState)
        if(newState == SCENE_SHOWING) then
            self.data:RefreshList()
            self.questList:Activate()
            KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
        elseif(newState == SCENE_HIDDEN) then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
            self.questList:Deactivate()
        end
    end)
end

local BLACK = ZO_ColorDef:New(0, 0, 0)
function WorldMapQuests_Gamepad:LayoutList()
    if not IsInGamepadPreferredMode() then return end

    self.hasQuests = #self.data.masterList > 0
    self.noQuestsLabel:SetHidden(self.hasQuests)

    self.data:Sort()

    self.questList:Clear()
    ZO_ClearTable(self.entriesByIndex)
    self.assistedEntryData = nil

    local questJournalObject = SYSTEMS:GetObject("questJournal")
    for index, srcData in ipairs(self.data.masterList) do
        local questIndex = srcData.questIndex
        local questIcon = questJournalObject:GetIconTexture(srcData.questType)

        local entryData = ZO_GamepadEntryData:New(srcData.name, questIcon)
        self.entriesByIndex[questIndex] = entryData

        entryData.questInfo = srcData

        local isAssisted = ZO_QuestTracker.tracker:IsTrackTypeAssisted(TRACK_TYPE_QUEST, questIndex)
        entryData.isAssisted = isAssisted
        if isAssisted then
            self.assistedEntryData = entryData
        end

        local questLevel = GetJournalQuestLevel(questIndex)
        local questColor = GetColorDefForCon(GetCon(questLevel))

        entryData:SetNameColors(questColor, questColor:Lerp(BLACK, 0.25))
        entryData:SetFontScaleOnSelection(false)
        entryData:SetHeightScaleOnSelection(true)

        self.questList:AddEntry("ZO_GamepadSubMenuEntryTemplateWithStatusLowercase42", entryData)
    end

    self.questList:Commit()
end

function WorldMapQuests_Gamepad:RefreshHeaders()
    self:LayoutList()
end

function WorldMapQuests_Gamepad:SetupQuestDetails(selectedData)
    if self.control:IsHidden() then return end

    self.scrollTooltip:ClearLines()
    
    if not selectedData then 
        self:RefreshKeybind()
        return 
    end

    local tooltipControl = self.scrollTooltip

    local questName = selectedData.questInfo.name
    local questIndex = selectedData.questInfo.questIndex

    local isAssisted = ZO_QuestTracker.tracker:IsTrackTypeAssisted(TRACK_TYPE_QUEST, questIndex)

    local questLevel = GetJournalQuestLevel(questIndex)
    local questColor = GetColorDefForCon(GetCon(questLevel))

    local titleStyle = tooltipControl.tooltip:GetStyle("mapQuestTitle")
    local groupSection = tooltipControl.tooltip:AcquireSection(titleStyle, tooltipControl.tooltip:GetStyle("mapKeepCategorySpacing"))
    local icon = isAssisted and ASSISTED_TEXTURE or nil
    tooltipControl:LayoutGroupHeader(groupSection, icon, questColor:Colorize(questName), titleStyle, tooltipControl.tooltip:GetStyle("mapTitle"))
    tooltipControl.tooltip:AddSection(groupSection)

    local stepOverrideText, completed = select(5, GetJournalQuestInfo(questIndex))

    if completed then
        tooltipControl:AppendQuestEnding(questIndex)
    else
        if stepOverrideText ~= "" then
            tooltipControl:AppendQuestCondition(questIndex, QUEST_MAIN_STEP_INDEX)
        else
            local conditionCount = GetJournalQuestNumConditions(questIndex, QUEST_MAIN_STEP_INDEX)
            for i = 1, conditionCount do
                tooltipControl:AppendQuestCondition(questIndex, QUEST_MAIN_STEP_INDEX, i)
            end
        end
    end

    self:RefreshKeybind()
end

function WorldMapQuests_Gamepad:RefreshKeybind()
    if self.keybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
    end
end

function WorldMapQuests_Gamepad:InitializeKeybindDescriptor()
    self.keybindStripDescriptor =
    {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            keybind = "UI_SHORTCUT_PRIMARY",

            name = GetString(SI_GAMEPAD_WORLD_MAP_INTERACT_SET_ACTIVE_QUEST),

            callback = function()
                local selectedData = self.questList:GetTargetData()
                local questIndex = selectedData.questInfo.questIndex

                if self.assistedEntryData then
                    self.assistedEntryData.isAssisted = false
                end
                local newEntry = self.entriesByIndex[questIndex]
                self.assistedEntryData = newEntry
                if newEntry then
                    newEntry.isAssisted = true
                end

                ZO_WorldMap_PanToQuest(questIndex)
                QUEST_TRACKER:ForceAssist(questIndex)
                self.questList:RefreshVisible()
                PlaySound(SOUNDS.MAP_LOCATION_CLICKED)
            end,

            enabled = function()
                local selectedData = self.questList:GetTargetData()
                return selectedData ~= nil and selectedData.questInfo ~= nil and selectedData.questInfo.questIndex ~= nil
            end
        },
    }

    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, ZO_WorldMapInfo_OnBackPressed)
    ZO_Gamepad_AddListTriggerKeybindDescriptors(self.keybindStripDescriptor, self.questList)
end

--Global XML

function ZO_WorldMapQuests_Gamepad_OnInitialized(self)
    GAMEPAD_WORLD_MAP_QUESTS = WorldMapQuests_Gamepad:New(self)
end


local GAMEPAD_PLAYER_EMOTE_SCENE_NAME = "gamepad_player_emote"
local GAMEPAD_PLAYER_EMOTE_MENU_ENTRY_TEMPLATE = "ZO_GamepadMenuEntryTemplate"

local EMPTY_QUICKSLOT_TEXTURE = "EsoUI/Art/Quickslots/quickslot_emptySlot.dds"
local EMPTY_QUICKSLOT_STRING = GetString(SI_QUICKSLOTS_EMPTY)

local MODE_CATEGORY_INACTIVE = 0
local MODE_CATEGORY_SELECTION = 1
local MODE_EMOTE_SELECTION = 2
local MODE_EMOTE_ASSIGNMENT = 3

ZO_EMOTE_COLUMN_WIDTH = 400
ZO_EMOTE_ROW_HEIGHT = 70
local NUM_EMOTE_ITEMS_IN_COLUMN = 9
local NUM_EMOTE_ITEM_COLUMNS = 3
local NUM_EMOTES_ON_PAGE = NUM_EMOTE_ITEM_COLUMNS * NUM_EMOTE_ITEMS_IN_COLUMN

local EMOTE_GRID_MODE_EMOTES = 0
local EMOTE_GRID_MODE_QUICK_CHAT = 1

--
-- ZO_EmoteItem class. These items wrap the controls that make up the grid of emotes the user can select from
--
local EMOTE_ITEM_TYPE_NONE = 0
local EMOTE_ITEM_TYPE_EMOTE = 1
local EMOTE_ITEM_TYPE_QUICK_CHAT = 2

local ZO_EmoteItem = ZO_Object:Subclass()

function ZO_EmoteItem:New(...)
    local emote = ZO_Object.New(self)
    emote:Initialize(...)
    return emote
end

function ZO_EmoteItem:Initialize(control)
    self.control = control
    self.title = control:GetNamedChild("Title")
    self.highlight = control:GetNamedChild("Highlight")
    self.itemType = EMOTE_ITEM_TYPE_NONE
    self.id = 0
end

function ZO_EmoteItem:SetAnchor(column, row)
    self.control:ClearAnchors()
    self.control:SetAnchor(TOPLEFT, nil, TOPLEFT, (column - 1) * ZO_EMOTE_COLUMN_WIDTH, (row - 1) * ZO_EMOTE_ROW_HEIGHT)
end

function ZO_EmoteItem:SetVisible(visible)
    self.control:SetHidden(not visible)
end

function ZO_EmoteItem:SetHighlightVisible(visible)
    self.highlight:SetHidden(not visible)
end

function ZO_EmoteItem:Reset()
    self:SetVisible(false)
    self:SetHighlightVisible(false)
end

function ZO_EmoteItem:SetEmoteInfo(emoteId)
    self.itemType = EMOTE_ITEM_TYPE_EMOTE
    self.id = emoteId
    local emoteInfo = PLAYER_EMOTE_MANAGER:GetEmoteItemInfo(emoteId)
    self:SetName(emoteInfo.displayName)
end

function ZO_EmoteItem:SetQuickChatInfo(quickChatId)
    self.itemType = EMOTE_ITEM_TYPE_QUICK_CHAT
    self.id = quickChatId
    self:SetName(QUICK_CHAT_MANAGER:GetFormattedQuickChatName(quickChatId))
end

function ZO_EmoteItem:SetName(name)
    self.title:SetText(name)
    self.name = name
end

function ZO_EmoteItem:GetName()
    return self.name
end

function ZO_EmoteItem:GetId()
    return self.id
end

function ZO_EmoteItem:GetItemType()
    return self.itemType
end

--
-- ZO_GamepadEmoteGrid class. This class manages the full grid of items including page switching
--

local ZO_GamepadEmoteGrid = ZO_GamepadPagedGrid:Subclass()

function ZO_GamepadEmoteGrid:New(...)
    return ZO_GamepadPagedGrid.New(self, ...)
end

function ZO_GamepadEmoteGrid:Initialize(control, footerControl)
    local COLUMN_MAJOR = false
    ZO_GamepadPagedGrid.Initialize(self, control, COLUMN_MAJOR, footerControl)

    self.allowHighlight = true
    self.emoteItems = {}
    self.visibleEmotes = {}
    self.mode = EMOTE_GRID_MODE_EMOTES
    self.emoteList = nil

    self:InitializeEmoteItemGrid()

    self:SetPageNumberFont("ZoFontGamepadBold54")
end

do
    local function ResetEmote(emote)
        emote:Reset()
    end

    function ZO_GamepadEmoteGrid:InitializeEmoteItemPool()
        local function CreateEmote(objectPool)
            local emoteControl = ZO_ObjectPool_CreateControl("ZO_PlayerEmoteItemControl", objectPool, self.control)
            return ZO_EmoteItem:New(emoteControl)
        end

        self.emoteItemPool = ZO_ObjectPool:New(CreateEmote, ResetEmote)
    end
end

function ZO_GamepadEmoteGrid:InitializeEmoteItemGrid()
    self:InitializeEmoteItemPool()

    for column = 1, NUM_EMOTE_ITEM_COLUMNS do
        self.emoteItems[column] = {}

        for row = 1, NUM_EMOTE_ITEMS_IN_COLUMN do
            local emoteItem = self.emoteItemPool:AcquireObject()
            emoteItem:SetAnchor(column, row)
            self.emoteItems[column][row] = emoteItem
        end
    end
end

function ZO_GamepadEmoteGrid:ResetGridItem(column, row, visible)
    local emoteItem = self.emoteItems[column][row]

    emoteItem:SetHighlightVisible(false)
    emoteItem:SetVisible(visible)
end

function ZO_GamepadEmoteGrid:ResetPageInfo()
    local FIRST_PAGE = 1
    local numPages = math.ceil(#self.emoteList / NUM_EMOTES_ON_PAGE)
    self:SetPageInfo(FIRST_PAGE, numPages)
end

local function ShouldEmoteShowInGamepadUI(emoteData)
    return emoteData.showInGamepadUI
end

function ZO_GamepadEmoteGrid:ChangeEmoteListForEmoteType(emoteType)
    self.mode = EMOTE_GRID_MODE_EMOTES
    self.emoteList = PLAYER_EMOTE_MANAGER:GetEmoteListForType(emoteType, ShouldEmoteShowInGamepadUI)

    self:ResetPageInfo()
end

function ZO_GamepadEmoteGrid:ChangeEmoteListForQuickChat()
    self.mode = EMOTE_GRID_MODE_QUICK_CHAT
    self.emoteList = QUICK_CHAT_MANAGER:BuildQuickChatList()

    self:ResetPageInfo()
end

function ZO_GamepadEmoteGrid:GetCurrentSelectedEmote()
    if self.currentHighlight then
        return self.emoteItems[self.currentHighlight.column][self.currentHighlight.row]
    end

    return nil
end

function ZO_GamepadEmoteGrid:GetSelectedEmoteName()
    return self:GetCurrentSelectedEmote():GetName()
end

function ZO_GamepadEmoteGrid:GetSelectedEmoteId()
    return self:GetCurrentSelectedEmote():GetId()
end

function ZO_GamepadEmoteGrid:GetSelectedEmoteType()
    return self:GetCurrentSelectedEmote():GetItemType()
end

function ZO_GamepadEmoteGrid:SetAllowHighlight(allow)
    self.allowHighlight = allow
    self:RefreshGridHighlight()
end

do
    local SHOW_GRID_ITEM = true
    local HIDE_GRID_ITEM = false
    function ZO_GamepadEmoteGrid:RefreshGrid()
        --[[
            Refresh the grid by resetting the visibleEmotes boolean array used by ZO_GamepadGrid and then setting controls
            Visible or Hidden based on how many items are needed to be shown for the current list size on the current page
        --]]
        ZO_ClearNumericallyIndexedTable(self.visibleEmotes)
        local currentPage = self:GetCurrentPage()

        local emoteStartIndex = ((currentPage - 1) * NUM_EMOTES_ON_PAGE)
        local numEmotes = #self.emoteList
        local numEmotesToShow = numEmotes > 0 and zo_min(numEmotes - emoteStartIndex, NUM_EMOTES_ON_PAGE) or numEmotes

        local numShown = 0
        for column = 1, NUM_EMOTE_ITEM_COLUMNS do
            if numShown < numEmotesToShow then
                self.visibleEmotes[column] = {}
            end

            for row = 1, NUM_EMOTE_ITEMS_IN_COLUMN do
                if numShown < numEmotesToShow then
                    self:ResetGridItem(column, row, SHOW_GRID_ITEM)
                    self.visibleEmotes[column][row] = true
                    numShown = numShown + 1
                    if self.mode == EMOTE_GRID_MODE_EMOTES then
                        self.emoteItems[column][row]:SetEmoteInfo(self.emoteList[emoteStartIndex + numShown])
                    elseif self.mode == EMOTE_GRID_MODE_QUICK_CHAT then
                        self.emoteItems[column][row]:SetQuickChatInfo(self.emoteList[emoteStartIndex + numShown])
                    end
                else
                    self:ResetGridItem(column, row, HIDE_GRID_ITEM)
                end
            end
        end

        self:ResetGridPosition()
    end
end

function ZO_GamepadEmoteGrid:GetNumEmoteItems()
    return self.emoteList and #self.emoteList or 0
end

-- functions overriden from base class

function ZO_GamepadEmoteGrid:GetGridItems()
    return self.visibleEmotes
end

function ZO_GamepadEmoteGrid:RefreshGridHighlight()
    if self.currentHighlight then
        self.emoteItems[self.currentHighlight.column][self.currentHighlight.row]:SetHighlightVisible(false)
    end

    local column, row = self:GetGridPosition()
    if column > 0 and row > 0 then
        self.emoteItems[column][row]:SetHighlightVisible(self.allowHighlight)
        self.currentHighlight = {row = row, column = column}
    end
end

function ZO_GamepadEmoteGrid:Activate()
    ZO_GamepadPagedGrid.Activate(self)
    self.footer.control:SetHidden(false)
end

function ZO_GamepadEmoteGrid:Deactivate()
    ZO_GamepadPagedGrid.Deactivate(self)
    self.footer.control:SetHidden(true)
end

--
-- ZO_GamepadPlayerEmote class. This class creates our gamepad scene and emote category list and contains
-- a ZO_GamepadEmoteGrid object and quickslot radial menu

local ZO_GamepadPlayerEmote = ZO_Gamepad_ParametricList_Screen:Subclass()

function ZO_GamepadPlayerEmote:New(...)
    return ZO_Gamepad_ParametricList_Screen.New(self, ...)
end

function ZO_GamepadPlayerEmote:Initialize(control)
    self.control = control
    self.emoteListGridControl = control:GetNamedChild("EmoteListGrid")

    local quickslotControl = control:GetNamedChild("Quickslot")
    self.radialControl = quickslotControl:GetNamedChild("Radial")
    self.assignLabel = quickslotControl:GetNamedChild("Assign")
    self.selectedEmoteNameLabel = quickslotControl:GetNamedChild("SelectedEmoteName")

    GAMEPAD_PLAYER_EMOTE_SCENE = ZO_Scene:New(GAMEPAD_PLAYER_EMOTE_SCENE_NAME, SCENE_MANAGER)
    local ACTIVATE_ON_SHOW = true
    ZO_Gamepad_ParametricList_Screen.Initialize(self, control, ZO_GAMEPAD_HEADER_TABBAR_DONT_CREATE, ACTIVATE_ON_SHOW, GAMEPAD_PLAYER_EMOTE_SCENE)
end

function ZO_GamepadPlayerEmote:OnDeferredInitialize()
    self:InitializeHeader()
    self:InitializeEmoteGrid()
    self:InitializeList()
    self:InitializeRadialMenu()
end

function ZO_GamepadPlayerEmote:OnSelectionChanged()
    local targetData = self.itemList:GetTargetData()
    if targetData then
        self.currentData = targetData
        if targetData.type == ACTION_TYPE_EMOTE then
            self.emoteListGrid:ChangeEmoteListForEmoteType(targetData.emoteCategory)
        elseif targetData.type == ACTION_TYPE_QUICK_CHAT then
            self.emoteListGrid:ChangeEmoteListForQuickChat()
        end
    end
    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
end

function ZO_GamepadPlayerEmote:InitializeList()
    self.itemList = self:GetMainList()

    self.itemList:Clear()

    local quickChatIcon = QUICK_CHAT_MANAGER:GetQuickChatIcon()
    local data = ZO_GamepadEntryData:New(GetString(SI_QUICK_CHAT_EMOTE_MENU_ENTRY_NAME), quickChatIcon)
    data:SetIconTintOnSelection(true)
    data.type = ACTION_TYPE_QUICK_CHAT
    self.itemList:AddEntry(GAMEPAD_PLAYER_EMOTE_MENU_ENTRY_TEMPLATE, data)

    local categories = PLAYER_EMOTE_MANAGER:GetEmoteCategories()

    for _, category in ipairs(categories) do
        if category ~= EMOTE_CATEGORY_INVALID then
            local emoteIcon = PLAYER_EMOTE_MANAGER:GetEmoteIconForCategory(category)
            local data = ZO_GamepadEntryData:New(GetString("SI_EMOTECATEGORY", category), emoteIcon)
            data:SetIconTintOnSelection(true)
            data.type = ACTION_TYPE_EMOTE
            data.emoteCategory = category
            self.itemList:AddEntry(GAMEPAD_PLAYER_EMOTE_MENU_ENTRY_TEMPLATE, data)
        end
    end

    self.itemList:Commit()
end

function ZO_GamepadPlayerEmote:InitializeHeader()
    self.headerData = {titleText = GetString(SI_GAMEPAD_MAIN_MENU_EMOTES)}
    local rightPane = self.control:GetNamedChild("RightPane")
    local contentContainer = rightPane:GetNamedChild("Container"):GetNamedChild("ContentHeader")
    self.contentHeader = contentContainer:GetNamedChild("Header")
    ZO_GamepadGenericHeader_Initialize(self.contentHeader, ZO_GAMEPAD_HEADER_TABBAR_DONT_CREATE, ZO_GAMEPAD_HEADER_LAYOUTS.DATA_PAIRS_TOGETHER)

    local titleControl = self.contentHeader:GetNamedChild("TitleContainerTitle")
    titleControl:SetFont("ZoFontGamepad54")

    self.contentHeaderData = {
        titleText = function()
            if self.mode == MODE_CATEGORY_SELECTION or self.mode == MODE_EMOTE_SELECTION then
                local currentData = self.currentData
                if currentData then
                    if currentData.type == ACTION_TYPE_QUICK_CHAT then
                        return GetString(SI_QUICK_CHAT_EMOTE_MENU_ENTRY_NAME)
                    elseif currentData.type == ACTION_TYPE_EMOTE then
                        return GetString("SI_EMOTECATEGORY", currentData.emoteCategory)
                    end
                end
            end
        end,
    }
end

function ZO_GamepadPlayerEmote:InitializeEmoteGrid()
    self.emoteListGrid = ZO_GamepadEmoteGrid:New(self.emoteListGridControl, self.control:GetNamedChild("RightPaneContainerFooter"))
    self.emoteListGrid:SetPageChangedCallback(function() self:RefreshHeader() end)
end

local function OnPlayerEmoteFailedPlay()
    ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, GetString(SI_GAMEPAD_EMOTE_FAILED_PLAY))
end

function ZO_GamepadPlayerEmote:InitializeRadialMenu(control)
    self.radialMenu = ZO_RadialMenu:New(self.radialControl, "ZO_GamepadPlayerEmoteRadialMenuEntryTemplate", nil, "SelectableItemRadialMenuEntryAnimation", "RadialMenu")
    --store entry controls to animate with later
    self.entryControls = {}

    local function SetupEntryControl(entryControl, data)
        entryControl.label:SetText(data.name)
        self.entryControls[data.slot] = entryControl
        ZO_SetupSelectableItemRadialMenuEntryTemplate(entryControl)
    end

    self.radialMenu:SetCustomControlSetUpFunction(SetupEntryControl)

    local function OnActionSlotUpdated(eventCode, physicalSlot)
        self:RefreshQuickslotMenu()
    end

    self.radialControl:RegisterForEvent(EVENT_ACTION_SLOT_UPDATED, OnActionSlotUpdated)
    self.radialControl:RegisterForEvent(EVENT_PLAYER_EMOTE_FAILED_PLAY, OnPlayerEmoteFailedPlay)
end

function ZO_GamepadPlayerEmote:PerformUpdate()
    self:RefreshHeader()
end

function ZO_GamepadPlayerEmote:RefreshHeader()
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
    ZO_GamepadGenericHeader_Refresh(self.contentHeader, self.contentHeaderData)
end

function ZO_GamepadPlayerEmote:InitializeKeybindStripDescriptors()
    -- keybinds when a category is selected
    self.categoryKeybindStripDescriptor = {
        {
            name = GetString(SI_GAMEPAD_PLAYER_EMOTE_USE_EMOTE),
            keybind = "UI_SHORTCUT_PRIMARY",
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            visible = function() return self.emoteListGrid:GetCurrentSelectedEmote() ~= nil end,
            callback = function()
                SCENE_MANAGER:ShowBaseScene()
                local emoteId = self.emoteListGrid:GetSelectedEmoteId()
                if self.currentData.type == ACTION_TYPE_QUICK_CHAT then
                    QUICK_CHAT_MANAGER:PlayQuickChat(emoteId)
                elseif self.currentData.type == ACTION_TYPE_EMOTE then
                    local emoteIndex = PLAYER_EMOTE_MANAGER:GetEmoteItemInfo(emoteId).emoteIndex
                    PlayEmoteByIndex(emoteIndex)
                end
            end,
        },

        {
            name = GetString(SI_GAMEPAD_PLAYER_EMOTE_ASSIGN_EMOTE),
            keybind = "UI_SHORTCUT_SECONDARY",
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            visible = function() return self.emoteListGrid:GetCurrentSelectedEmote() ~= nil end,
            callback = function()
                self:ChangeCurrentMode(MODE_EMOTE_ASSIGNMENT)
            end,
        },
    }

    ZO_Gamepad_AddBackNavigationKeybindDescriptorsWithSound(self.categoryKeybindStripDescriptor,
                                                            GAME_NAVIGATION_TYPE_BUTTON,
                                                            function() self:ChangeCurrentMode(MODE_CATEGORY_SELECTION) end)

    -- keybinds when assigning emotes
    self.emoteAssignmentKeybindStripDescriptor = {}
    ZO_Gamepad_AddForwardNavigationKeybindDescriptors(self.emoteAssignmentKeybindStripDescriptor,
                                            GAME_NAVIGATION_TYPE_BUTTON, 
                                            function() self:AssignSelectedQuickslot() end,
                                            GetString(SI_GAMEPAD_ITEM_ACTION_QUICKSLOT_ASSIGN))

    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.emoteAssignmentKeybindStripDescriptor,
                                                GAME_NAVIGATION_TYPE_BUTTON,
                                                function() self:ChangeCurrentMode(MODE_EMOTE_SELECTION) end)

    -- keybinds when selecting a category
    self.keybindStripDescriptor = {}
    ZO_Gamepad_AddForwardNavigationKeybindDescriptorsWithSound(self.keybindStripDescriptor,
                                                GAME_NAVIGATION_TYPE_BUTTON,
                                                function() self:ChangeCurrentMode(MODE_EMOTE_SELECTION) end,
                                                GetString(SI_GAMEPAD_SELECT_OPTION),
                                                function() return self.emoteListGrid:GetNumEmoteItems() > 0 end)

    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)

    self:SetListsUseTriggerKeybinds(true)
end

function ZO_GamepadPlayerEmote:DeselectCurrentMode()
    if self.mode == MODE_CATEGORY_SELECTION then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
        self:DeactivateCurrentList()
    elseif self.mode == MODE_EMOTE_SELECTION then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.categoryKeybindStripDescriptor)
        self.emoteListGrid:Deactivate()
        self.emoteListGrid:SetAllowHighlight(false)
    elseif self.mode == MODE_EMOTE_ASSIGNMENT then
        self:HideQuickslotMenu()
        self.emoteListGridControl:SetHidden(false)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.emoteAssignmentKeybindStripDescriptor)
    end
    self.mode = MODE_CATEGORY_INACTIVE
end

function ZO_GamepadPlayerEmote:SelectMode(mode)
    self.mode = mode

    if self.mode == MODE_CATEGORY_SELECTION then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
        self:ActivateCurrentList()
        self.emoteListGrid:SetAllowHighlight(false)
    elseif self.mode == MODE_EMOTE_SELECTION then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.categoryKeybindStripDescriptor)
        self.emoteListGrid:SetAllowHighlight(true)
        self.emoteListGrid:Activate()
    elseif self.mode == MODE_EMOTE_ASSIGNMENT then
        self.emoteListGridControl:SetHidden(true)
        KEYBIND_STRIP:AddKeybindButtonGroup(self.emoteAssignmentKeybindStripDescriptor)
        self:ShowQuickslotMenu()
    end
end

function ZO_GamepadPlayerEmote:ChangeCurrentMode(mode)
    if self.mode ~= mode then
        self:DeselectCurrentMode()
        self:SelectMode(mode)
        self:RefreshHeader()
    end
end

function ZO_GamepadPlayerEmote:ShowQuickslotMenu()
    self.radialMenu:Clear()
    self:PopulateRadialMenu()

    self.activeEmoteId = self.emoteListGrid:GetSelectedEmoteId()
    self.activeEmoteType = self.emoteListGrid:GetSelectedEmoteType()
    self.assignLabel:SetHidden(false)
    self.selectedEmoteNameLabel:SetHidden(false)
    self.selectedEmoteNameLabel:SetText(self.emoteListGrid:GetSelectedEmoteName())

    -- This will Activate the menu and show it
    self.radialMenu:Show()
end

function ZO_GamepadPlayerEmote:HideQuickslotMenu()
    self.activeEmoteId = nil
    self.activeEmoteType = nil
    self.slotIndexForAnim = nil
    self.assignLabel:SetHidden(true)
    self.selectedEmoteNameLabel:SetHidden(true)

    -- This will deactivate the menu and hide it
    self.radialMenu:Clear()
end

function ZO_GamepadPlayerEmote:PopulateRadialMenu()
    local slottedEmotes = PLAYER_EMOTE_MANAGER:GetSlottedEmotes()
    for i, emote in ipairs(slottedEmotes) do
        local type = emote.type
        local id = emote.id
        
        local found = false
        local name
        local icon

        if type == ACTION_TYPE_EMOTE then
            local emoteInfo = PLAYER_EMOTE_MANAGER:GetEmoteItemInfo(id)
            found = emoteInfo ~= nil
            if found then
                icon = PLAYER_EMOTE_MANAGER:GetEmoteIconForCategory(emoteInfo.emoteCategory)
                name = emoteInfo.displayName
            end
        elseif type == ACTION_TYPE_QUICK_CHAT then
            found = QUICK_CHAT_MANAGER:HasQuickChat(id)
            if found then
                icon = QUICK_CHAT_MANAGER:GetQuickChatIcon()
                name = QUICK_CHAT_MANAGER:GetFormattedQuickChatName(id)
            end
        end
        
        if found then
            local data = {name = name, slot = i}
            self.radialMenu:AddEntry(name, icon, icon, nil, data)
        else
            self.radialMenu:AddEntry(EMPTY_QUICKSLOT_STRING, EMPTY_QUICKSLOT_TEXTURE, EMPTY_QUICKSLOT_TEXTURE, nil, {name = EMPTY_QUICKSLOT_STRING, slot = i})
        end
    end

    if self.slotIndexForAnim then
        ZO_PlaySparkleAnimation(self.entryControls[self.slotIndexForAnim])
    end
end

function ZO_GamepadPlayerEmote:RefreshQuickslotMenu()
    self.radialMenu:ResetData()
    self:PopulateRadialMenu()
    self.radialMenu:Refresh()
end

function ZO_GamepadPlayerEmote:AssignSelectedQuickslot()
    if self.radialMenu.selectedEntry then
        local selectedData = self.radialMenu.selectedEntry.data
        local slotIndex = selectedData.slot + ACTION_BAR_FIRST_EMOTE_QUICK_SLOT_INDEX
        if self.activeEmoteType == EMOTE_ITEM_TYPE_EMOTE then
            SelectSlotEmote(self.activeEmoteId, slotIndex)
        elseif self.activeEmoteType == EMOTE_ITEM_TYPE_QUICK_CHAT then
            SelectSlotQuickChat(self.activeEmoteId, slotIndex)
        end
        self.slotIndexForAnim = selectedData.slot
        PlaySound(SOUNDS.RADIAL_MENU_SELECTION)
    end
end

function ZO_GamepadPlayerEmote:OnShowing()
    self:ChangeCurrentMode(MODE_CATEGORY_SELECTION)
end

function ZO_GamepadPlayerEmote:OnHide()
    self:ChangeCurrentMode(MODE_CATEGORY_INACTIVE)
end

--Global XML Handlers
-----------------------

function ZO_GamepadPlayerEmote_OnInitialized(control)
    GAMEPAD_PLAYER_EMOTE = ZO_GamepadPlayerEmote:New(control)
end
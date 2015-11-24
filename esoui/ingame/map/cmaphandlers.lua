local CMapHandlers = ZO_Object:Subclass()

function CMapHandlers:New()
    local object = ZO_Object.New(self)
    object:Initialize()
    return object
end

function CMapHandlers:Initialize()
    self:InitializeRefresh()
    self:InitializeEvents()
end

function CMapHandlers:InitializeRefresh()
    self.refresh = ZO_Refresh:New()

    self.refresh:AddRefreshGroup("keep",
    {
        RefreshAll = function()
            self:RefreshKeeps()
        end,
        RefreshSingle = function(...)
            self:RefreshKeep(...)
        end,
    })

    self.refresh:AddRefreshGroup("avaObjectives",
    {
        RefreshAll = function()
            self:RefreshAvAObjectives()
        end,
    })
end

function CMapHandlers:InitializeEvents()
    local function RefreshKeep(_, keepId, bgContext)
        self.refresh:RefreshSingle("keep", keepId, bgContext)
    end
    EVENT_MANAGER:RegisterForEvent("CMapHandler", EVENT_KEEP_ALLIANCE_OWNER_CHANGED, RefreshKeep)
    EVENT_MANAGER:RegisterForEvent("CMapHandler", EVENT_KEEP_UNDER_ATTACK_CHANGED, RefreshKeep)
    EVENT_MANAGER:RegisterForEvent("CMapHandler", EVENT_KEEP_INITIALIZED, RefreshKeep)

    local function RefreshKeeps()
        self.refresh:RefreshAll("keep")
    end
    EVENT_MANAGER:RegisterForEvent("CMapHandler", EVENT_KEEP_GATE_STATE_CHANGED, RefreshKeeps)
    EVENT_MANAGER:RegisterForEvent("CMapHandler", EVENT_KEEPS_INITIALIZED, RefreshKeeps)

    local function RefreshAvAObjectives()
        self.refresh:RefreshAll("avaObjectives")
    end
    EVENT_MANAGER:RegisterForEvent("CMapHandler", EVENT_OBJECTIVES_UPDATED, RefreshAvAObjectives)
    EVENT_MANAGER:RegisterForEvent("CMapHandler", EVENT_OBJECTIVE_CONTROL_STATE, RefreshAvAObjectives)
    EVENT_MANAGER:RegisterForEvent("CMapHandler", EVENT_GAME_STATE_CHANGED, RefreshAvAObjectives)
    EVENT_MANAGER:RegisterForEvent("CMapHandler", EVENT_ZONE_SCORING_CHANGED, RefreshAvAObjectives)

    local function RefreshAll()
        self:RefreshAll()
    end
    EVENT_MANAGER:RegisterForEvent("CMapHandler", EVENT_PLAYER_ACTIVATED, RefreshAll)

    EVENT_MANAGER:RegisterForUpdate("CMapHandler", 100, function()
        self.refresh:UpdateRefreshGroups()
    end)
end

function CMapHandlers:RefreshAll()
    self:RefreshKeeps()
    self:RefreshAvAObjectives()
end

function CMapHandlers:AddKeep(keepId, bgContext)
    local pinType = GetKeepPinInfo(keepId, bgContext)
	if(pinType ~= MAP_PIN_TYPE_INVALID) then
		self:AddMapPin(pinType, keepId)

        local keepUnderAttack = GetKeepUnderAttack(keepId, bgContext)
		if(keepUnderAttack) then
            local keepUnderAttackPinType = ZO_WorldMap_GetUnderAttackPinForKeepPin(pinType)
			self:AddMapPin(keepUnderAttackPinType, keepId)
		end
    end
end

function CMapHandlers:RefreshKeeps()
    RemoveMapPinsInRange(MAP_PIN_TYPE_KEEP_NEUTRAL, MAP_PIN_TYPE_KEEP_ATTACKED_SMALL)
    local numKeeps = GetNumKeeps()
    for i = 1, numKeeps do
		local keepId, bgContext = GetKeepKeysByIndex(i)
        if(IsLocalBattlegroundContext(bgContext)) then
		    self:AddKeep(keepId, bgContext)
        end
    end
end

function CMapHandlers:RefreshKeep(keepId, bgContext)
    RemoveMapPinsInRange(MAP_PIN_TYPE_KEEP_NEUTRAL, MAP_PIN_TYPE_KEEP_ATTACKED_SMALL, keepId)
    if(IsLocalBattlegroundContext(bgContext)) then
		self:AddKeep(keepId, bgContext)
    end
end

local AVA_OBJECTIVE_PINS_WITH_ARROWS =
{    
    [MAP_PIN_TYPE_FLAG_ALDMERI_DOMINION] = true,
    [MAP_PIN_TYPE_FLAG_EBONHEART_PACT] = true,
    [MAP_PIN_TYPE_FLAG_DAGGERFALL_COVENANT] = true,
    [MAP_PIN_TYPE_FLAG_NEUTRAL] = true,
    [MAP_PIN_TYPE_BALL_ALDMERI_DOMINION] = true,
    [MAP_PIN_TYPE_BALL_EBONHEART_PACT] = true,
    [MAP_PIN_TYPE_BALL_DAGGERFALL_COVENANT] = true,
    [MAP_PIN_TYPE_BALL_NEUTRAL] = true,       
}

function CMapHandlers:RefreshAvAObjectives()
    RemoveMapPinsInRange(MAP_PIN_TYPE_FLAG_ALDMERI_DOMINION, MAP_PIN_TYPE_HALF_CAPTURE_FLAG_DAGGERFALL_COVENANT)    

    local numObjectives = GetNumAvAObjectives()
    for i = 1, numObjectives do
        local keepId, objectiveId, bgContext = GetAvAObjectiveKeysByIndex(i)
        if(IsLocalBattlegroundContext(bgContext)) then            
            if(ZO_WorldMap_IsObjectiveShown(keepId, objectiveId, bgContext)) then
                --spawn locations
                local pinType, spawnX, spawnY = GetAvAObjectiveSpawnPinInfo(keepId, objectiveId, bgContext)            
                if(pinType ~= MAP_PIN_TYPE_INVALID) then
                    self:AddMapPin(pinType, keepId, objectiveId)
                end            

                -- current locations
                local pinType, currentX, currentY, continuousUpdate = GetAvAObjectivePinInfo(keepId, objectiveId, bgContext)
                if(pinType ~= MAP_PIN_TYPE_INVALID) then
                    self:AddMapPin(pinType, keepId, objectiveId)
                
                    if(continuousUpdate) then
                        SetMapPinContinuousPositionUpdate(pinType, true, keepId, objectiveId)    
                    end

                    if(AVA_OBJECTIVE_PINS_WITH_ARROWS[pinType]) then
                        SetMapPinAssisted(pinType, true, keepId, objectiveId)
                    end
                end
            end
        end
    end
end

function CMapHandlers:AddMapPin(pinType, keepId, objectiveId)
    if self:ValidateAVAPinAllowed(pinType) then
        AddMapPin(pinType, keepId, objectiveId)
    end
end

function CMapHandlers:ValidateAVAPinAllowed(pinType)
    if IsInCyrodiil() then
        return true
    else
        local isAvAObjective = ZO_MapPin.AVA_OBJECTIVE_PIN_TYPES[pinType] or ZO_MapPin.AVA_SPAWN_OBJECTIVE_PIN_TYPES[pinType]
        local isAvARespawn = ZO_MapPin.AVA_RESPAWN_PIN_TYPES[pinType]
        local isForwardCamp = ZO_MapPin.FORWARD_CAMP_PIN_TYPES[pinType]
        local isFastTravelKeep = ZO_MapPin.FAST_TRAVEL_KEEP_PIN_TYPES[pinType]
        local isKeep = ZO_MapPin.KEEP_PIN_TYPES[pinType]

        return not (isAvAObjective or isAvARespawn or isForwardCamp or isFastTravelKeep or isKeep)
    end
end

C_MAP_HANDLERS = CMapHandlers:New()


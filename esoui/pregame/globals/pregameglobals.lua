CHARACTER_OPTION_CLEAN_TEST_AREA = true
CHARACTER_OPTION_EXISTING_AREA = false

CHARACTER_CREATE_DEFAULT_LOCATION = 1
CHARACTER_CREATE_SKIP_TUTORIAL = 2

--[[
    MouseCursor Update Utility for Character Select/Create
--]]

local g_lastControl, g_lastSceneState

function ZO_UpdatePaperDollManipulationForScene(control, sceneState)
    g_lastControl, g_lastSceneState = control, sceneState
    local fullyLoaded = GetNumTotalSubsystemsToLoad() == GetNumLoadedSubsystems()

    if(not fullyLoaded or (sceneState == SCENE_HIDDEN)) then
        control:SetMouseEnabled(false)
        WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
    elseif(fullyLoaded and (sceneState == SCENE_SHOWN)) then
        control:SetMouseEnabled(true)

        local mouseIsOverControl = MouseIsOver(control)
        local currentMouseOverControl = WINDOW_MANAGER:GetMouseOverControl()
        local allowHandler = (currentMouseOverControl == control) or (currentMouseOverControl == GuiRoot)
        
        if(mouseIsOverControl and allowHandler) then
            control:GetHandler("OnMouseEnter")(control)
        end    
    end
end

local function OnPregameFullyLoaded()
    if(g_lastControl ~= nil and g_lastSceneState == SCENE_SHOWN) then
        ZO_UpdatePaperDollManipulationForScene(g_lastControl, g_lastSceneState)
    end
end

CALLBACK_MANAGER:RegisterCallback("PregameFullyLoaded", OnPregameFullyLoaded)

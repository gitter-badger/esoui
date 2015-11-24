GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT = ZO_TranslateFromLeftSceneFragment:New(ZO_SharedGamepadNavQuadrant_1_Background)
GAMEPAD_NAV_QUADRANT_2_3_BACKGROUND_FRAGMENT = ZO_FadeSceneFragment:New(ZO_SharedGamepadNavQuadrant_2_3_Background)

-----------------------------
--Movie Background Fragment
-----------------------------

ZO_MovieBackgroundFragment = ZO_SceneFragment:Subclass()

function ZO_MovieBackgroundFragment:New(movieFile)
    local fragment = ZO_SceneFragment.New(self)
    fragment.movieFile = movieFile
    return fragment
end

function ZO_MovieBackgroundFragment:Show()
    local PLAY_IMMEDIATELY = true
    local PLAY_IN_BACKGROUND = true
    local LOOP = true
    PlayVideo(self.movieFile, PLAY_IMMEDIATELY, VIDEO_SKIP_MODE_NO_SKIP, nil, PLAY_IN_BACKGROUND, LOOP)
    self:OnShown()
end

function ZO_MovieBackgroundFragment:Hide()
    CancelCurrentVideoPlayback()
    self:OnHidden()
end

ZO_MutedMovieBackgroundFragment = ZO_MovieBackgroundFragment:Subclass()

function ZO_MutedMovieBackgroundFragment:Show()
    local PLAY_IMMEDIATELY = true
    local PLAY_IN_BACKGROUND = true
    local LOOP = true
    local MUTE = true
    PlayVideo(self.movieFile, PLAY_IMMEDIATELY, VIDEO_SKIP_MODE_NO_SKIP, nil, PLAY_IN_BACKGROUND, LOOP, MUTE)
    self:OnShown()
end

CLOUDS_BACKGROUND_FRAGMENT = ZO_MovieBackgroundFragment:New("Video/BG_SMoke.bik")
CREATE_ACCOUNT_BACKGROUND_FRAGMENT = CLOUDS_BACKGROUND_FRAGMENT
LINK_ACCOUNT_BACKGROUND_FRAGMENT = CLOUDS_BACKGROUND_FRAGMENT
CREDIT_GAMEPAD_BACKGROUND_FRAGMENT = ZO_MutedMovieBackgroundFragment:New("Video/BG_SMoke.bik")

----------------------------------------
--Pregame Scene State Advance From Fragment
----------------------------------------

ZO_PregameSceneStateAdvanceFromFragment = ZO_SceneFragment:Subclass()

function ZO_PregameSceneStateAdvanceFromFragment:New(state)
    local fragment = ZO_SceneFragment.New(self)
    fragment:SetHideOnSceneHidden(true)
    fragment.advanceFromState = state
    return fragment
end

function ZO_PregameSceneStateAdvanceFromFragment:Show()
    self:OnShown()
end

function ZO_PregameSceneStateAdvanceFromFragment:Hide()
    --Advancing can often change scenes causing fragments to refresh and this Hide be re-run. So protect the advance until the previous advance completes.
    --also only advance if we are in an expected state
    if not self.advancing then
        self.advancing = true
        PregameStateManager_AdvanceStateFromState(self.advanceFromState)
        self:OnHidden()
    end
    self.advancing = nil
end

PREGAME_GAMMA_ADJUST_INTRO_ADVANCE_FRAGMENT = ZO_PregameSceneStateAdvanceFromFragment:New("GammaAdjust")
PREGAME_SCREEN_ADJUST_INTRO_ADVANCE_FRAGMENT = ZO_PregameSceneStateAdvanceFromFragment:New("ScreenAdjustIntro")

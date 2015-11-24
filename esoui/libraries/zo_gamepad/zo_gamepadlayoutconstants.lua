------------------
--Base Constants--
------------------

ZO_GAMEPAD_PANEL_WIDTH = 470
ZO_GAMEPAD_PANEL_WIDE_WIDTH = 683
ZO_GAMEPAD_UI_REFERENCE_WIDTH = 1920

ZO_GAMEPAD_SAFE_ZONE_INSET_X = 96
ZO_GAMEPAD_SAFE_ZONE_INSET_Y = 54

ZO_GAMEPAD_ALLEY_WIDTH = 10

ZO_GAMEPAD_LIST_LABEL_INSET_TO_LEFT = 100
ZO_GAMEPAD_LIST_ICON_INSET_TO_CENTER = 56
ZO_GAMEPAD_LIST_INDICATOR_INSET_TO_CENTER = 0
ZO_GAMEPAD_LIST_ICON_SIZE = 64
ZO_GAMEPAD_LIST_INDICATOR_SIZE = 32

ZO_GAMEPAD_CONTENT_INSET_X = 40
ZO_GAMEPAD_CONTENT_TITLE_HEIGHT = 96
ZO_GAMEPAD_CONTENT_TITLE_DIVIDER_PADDING_Y = 7
--Height of the keybinds that show next to the divider. This dictates the divider section size
ZO_GAMEPAD_CONTENT_DIVIDER_HEIGHT = 35
ZO_GAMEPAD_CONTENT_DIVIDER_INFO_PADDING_Y = 15
ZO_GAMEPAD_CONTENT_WIDTH = ZO_GAMEPAD_PANEL_WIDTH - 2 * ZO_GAMEPAD_CONTENT_INSET_X

ZO_GAMEPAD_PANEL_BG_HEIGHT = 1080
--The BG texture spans from left safezone less the content inset to right safezone less the content inset
ZO_GAMEPAD_PANEL_BG_WIDTH = ZO_GAMEPAD_UI_REFERENCE_WIDTH - (ZO_GAMEPAD_SAFE_ZONE_INSET_X - ZO_GAMEPAD_CONTENT_INSET_X) * 2
--The UI unit where the panel BG starts
ZO_GAMEPAD_PANEL_BG_LEFT = ZO_GAMEPAD_SAFE_ZONE_INSET_X - ZO_GAMEPAD_CONTENT_INSET_X
ZO_GAMEPAD_PANEL_BG_FILE_WIDTH = 512
ZO_GAMEPAD_PANEL_BG_FILE_HEIGHT = 512
ZO_GAMEPAD_PANEL_BG_VERTICAL_DIVIDER_WIDTH = 8
ZO_GAMEPAD_PANEL_BG_VERTICAL_DIVIDER_HALF_WIDTH = ZO_GAMEPAD_PANEL_BG_VERTICAL_DIVIDER_WIDTH / 2
--The arrow specifying screen center on some BG's interferes with default R Scroll indicator position, R Scroll will need to go below the arrow
ZO_GAMEPAD_PANEL_BG_SCROLL_INDICATOR_OFFSET_FOR_ARROW = 48
--This gives us the distance between the edge of a panel and the inside edge of the vertical dividers gold line
ZO_GAMEPAD_PANEL_BG_EDGE_VERTICAL_DIVIDER_INSIDE_PADDING_X = 5

ZO_GAMEPAD_QUADRANT_VERT_DIVIDER_PADDING = 8

---------------------
--Derived Constants--
---------------------

--QUADRANTS--

local function ComputeBGTextureCoord(horizontalPosition)
    return ((horizontalPosition - ZO_GAMEPAD_PANEL_BG_LEFT) / ZO_GAMEPAD_PANEL_BG_WIDTH) * (ZO_GAMEPAD_PANEL_BG_WIDTH / ZO_GAMEPAD_PANEL_BG_FILE_WIDTH)
end

--All quadrants adjoin the safezone on the top
ZO_GAMEPAD_QUADRANT_TOP_OFFSET = ZO_GAMEPAD_SAFE_ZONE_INSET_Y

--All quadrants adjoin the keybind strip on the bottom
ZO_GAMEPAD_QUADRANT_BOTTOM_OFFSET = -125

--Quadrant 1 aligns it's content section's left edge with the left safe zone boundary
ZO_GAMEPAD_QUADRANT_1_LEFT_OFFSET = ZO_GAMEPAD_SAFE_ZONE_INSET_X - ZO_GAMEPAD_CONTENT_INSET_X
ZO_GAMEPAD_QUADRANT_1_RIGHT_OFFSET = ZO_GAMEPAD_QUADRANT_1_LEFT_OFFSET + ZO_GAMEPAD_PANEL_WIDTH
ZO_GAMEPAD_QUADRANT_1_LEFT_COORD = ComputeBGTextureCoord(ZO_GAMEPAD_QUADRANT_1_LEFT_OFFSET)
ZO_GAMEPAD_QUADRANT_1_RIGHT_COORD = ComputeBGTextureCoord(ZO_GAMEPAD_QUADRANT_1_RIGHT_OFFSET)

--Quadrant 2 is an alley width to the right of Quadrant 1
ZO_GAMEPAD_QUADRANT_2_LEFT_OFFSET = ZO_GAMEPAD_QUADRANT_1_RIGHT_OFFSET + ZO_GAMEPAD_ALLEY_WIDTH
ZO_GAMEPAD_QUADRANT_2_RIGHT_OFFSET = ZO_GAMEPAD_QUADRANT_2_LEFT_OFFSET + ZO_GAMEPAD_PANEL_WIDTH
ZO_GAMEPAD_QUADRANT_2_LEFT_COORD = ComputeBGTextureCoord(ZO_GAMEPAD_QUADRANT_2_LEFT_OFFSET)
ZO_GAMEPAD_QUADRANT_2_RIGHT_COORD = ComputeBGTextureCoord(ZO_GAMEPAD_QUADRANT_2_RIGHT_OFFSET)

--Quadrant 4 aligns it's content section's right edge with the right safe zone boundary. It is anchored to the right side of the screen. These values
--reflect offsets from the right side of the screen
ZO_GAMEPAD_QUADRANT_4_RIGHT_OFFSET = -ZO_GAMEPAD_SAFE_ZONE_INSET_X + ZO_GAMEPAD_CONTENT_INSET_X
ZO_GAMEPAD_QUADRANT_4_LEFT_OFFSET = ZO_GAMEPAD_QUADRANT_4_RIGHT_OFFSET - ZO_GAMEPAD_PANEL_WIDTH

--While these offsets are from the left and are used only for texture coordinates
ZO_GAMEPAD_QUADRANT_4_RIGHT_REFERENCE_OFFSET = ZO_GAMEPAD_UI_REFERENCE_WIDTH - (ZO_GAMEPAD_SAFE_ZONE_INSET_X - ZO_GAMEPAD_CONTENT_INSET_X)
ZO_GAMEPAD_QUADRANT_4_LEFT_REFERENCE_OFFSET = ZO_GAMEPAD_QUADRANT_4_RIGHT_REFERENCE_OFFSET - ZO_GAMEPAD_PANEL_WIDTH
ZO_GAMEPAD_QUADRANT_4_WIDE_LEFT_REFERENCE_OFFSET = ZO_GAMEPAD_QUADRANT_4_RIGHT_REFERENCE_OFFSET - ZO_GAMEPAD_PANEL_WIDE_WIDTH
ZO_GAMEPAD_QUADRANT_4_LEFT_COORD = ComputeBGTextureCoord(ZO_GAMEPAD_QUADRANT_4_LEFT_REFERENCE_OFFSET)
ZO_GAMEPAD_QUADRANT_4_WIDE_LEFT_COORD = ComputeBGTextureCoord(ZO_GAMEPAD_QUADRANT_4_WIDE_LEFT_REFERENCE_OFFSET)
ZO_GAMEPAD_QUADRANT_4_RIGHT_COORD = ComputeBGTextureCoord(ZO_GAMEPAD_QUADRANT_4_RIGHT_REFERENCE_OFFSET)

--Quadrant 3 is an alley width to the left of Quadrant 4. It is anchored to the right side of the screen. These values
--reflect offsets from the right side of the screen.
ZO_GAMEPAD_QUADRANT_3_RIGHT_OFFSET = ZO_GAMEPAD_QUADRANT_4_LEFT_OFFSET - ZO_GAMEPAD_ALLEY_WIDTH
ZO_GAMEPAD_QUADRANT_3_LEFT_OFFSET = ZO_GAMEPAD_QUADRANT_3_RIGHT_OFFSET - ZO_GAMEPAD_PANEL_WIDTH

--While these offsets are from the left and are used only for texture coordinates
ZO_GAMEPAD_QUADRANT_3_RIGHT_REFERENCE_OFFSET = ZO_GAMEPAD_QUADRANT_4_LEFT_REFERENCE_OFFSET - ZO_GAMEPAD_ALLEY_WIDTH
ZO_GAMEPAD_QUADRANT_3_LEFT_REFERENCE_OFFSET = ZO_GAMEPAD_QUADRANT_3_RIGHT_REFERENCE_OFFSET - ZO_GAMEPAD_PANEL_WIDTH
ZO_GAMEPAD_QUADRANT_3_LEFT_COORD = ComputeBGTextureCoord(ZO_GAMEPAD_QUADRANT_3_LEFT_REFERENCE_OFFSET)
ZO_GAMEPAD_QUADRANT_3_RIGHT_COORD = ComputeBGTextureCoord(ZO_GAMEPAD_QUADRANT_3_RIGHT_REFERENCE_OFFSET)

--Quadrant 2 3
ZO_GAMEPAD_QUADRANT_2_3_WIDTH = ZO_GAMEPAD_QUADRANT_3_RIGHT_REFERENCE_OFFSET - ZO_GAMEPAD_QUADRANT_2_LEFT_OFFSET
ZO_GAMEPAD_QUADRANT_2_3_CONTAINER_WIDTH = ZO_GAMEPAD_QUADRANT_2_3_WIDTH - (2 * ZO_GAMEPAD_CONTENT_INSET_X)
ZO_GAMEPAD_QUADRANT_2_3_CONTENT_BACKGROUND_WIDTH = ZO_GAMEPAD_QUADRANT_2_3_WIDTH - 2 * ZO_GAMEPAD_QUADRANT_VERT_DIVIDER_PADDING

--Quadrant 2 3 4
ZO_GAMEPAD_QUADRANT_2_3_4_WIDTH = ZO_GAMEPAD_QUADRANT_4_RIGHT_REFERENCE_OFFSET - ZO_GAMEPAD_QUADRANT_2_LEFT_OFFSET

--Quadrant 1 2 3
ZO_GAMEPAD_QUADRANT_1_2_3_WIDTH = ZO_GAMEPAD_QUADRANT_3_RIGHT_REFERENCE_OFFSET - ZO_GAMEPAD_QUADRANT_1_LEFT_OFFSET
ZO_GAMEPAD_QUADRANT_1_2_3_CONTAINER_WIDTH = ZO_GAMEPAD_QUADRANT_1_2_3_WIDTH - (2 * ZO_GAMEPAD_CONTENT_INSET_X)

--Quadrant 1 2 3 4
ZO_GAMEPAD_QUADRANT_1_2_3_4_WIDTH = ZO_GAMEPAD_QUADRANT_4_RIGHT_REFERENCE_OFFSET - ZO_GAMEPAD_QUADRANT_1_LEFT_OFFSET

ZO_GAMEPAD_PANEL_BG_BOTTOM_COORD = ZO_GAMEPAD_PANEL_BG_HEIGHT / ZO_GAMEPAD_PANEL_BG_FILE_HEIGHT

ZO_GAMEPAD_DEFAULT_PANEL_SUB_CONTAINER_WIDTH = ZO_GAMEPAD_PANEL_WIDTH - (2 * ZO_GAMEPAD_PANEL_BG_EDGE_VERTICAL_DIVIDER_INSIDE_PADDING_X)

--Quadrant Floating Areas
ZO_GAMEPAD_PANEL_FLOATING_WIDTH_QUADRANT_1_SHOWN = ZO_GAMEPAD_UI_REFERENCE_WIDTH - ZO_GAMEPAD_SAFE_ZONE_INSET_X - ZO_GAMEPAD_QUADRANT_1_RIGHT_OFFSET
ZO_GAMEPAD_PANEL_FLOATING_CENTER_QUADRANT_1_SHOWN = ZO_GAMEPAD_QUADRANT_1_RIGHT_OFFSET + (ZO_GAMEPAD_PANEL_FLOATING_WIDTH_QUADRANT_1_SHOWN / 2)

ZO_GAMEPAD_PANEL_FLOATING_WIDTH_QUADRANT_1_2_SHOWN = ZO_GAMEPAD_UI_REFERENCE_WIDTH - ZO_GAMEPAD_SAFE_ZONE_INSET_X - ZO_GAMEPAD_QUADRANT_2_RIGHT_OFFSET
ZO_GAMEPAD_PANEL_FLOATING_CENTER_QUADRANT_1_2_SHOWN = ZO_GAMEPAD_QUADRANT_2_RIGHT_OFFSET + (ZO_GAMEPAD_PANEL_FLOATING_WIDTH_QUADRANT_1_2_SHOWN / 2)

--This is the value of units off of GuiRoot's LEFT anchor that accounts for the bottom offset and the top title safe zone
ZO_GAMEPAD_PANEL_FLOATING_CENTER_OFFSET_Y = (ZO_GAMEPAD_QUADRANT_BOTTOM_OFFSET / 2) + (ZO_GAMEPAD_SAFE_ZONE_INSET_Y / 2)
--This is the area that can be disregarded when counting eligible vertical range in the floating area
ZO_GAMEPAD_PANEL_FLOATING_HEIGHT_DISCOUNT = -ZO_GAMEPAD_QUADRANT_BOTTOM_OFFSET + ZO_GAMEPAD_SAFE_ZONE_INSET_Y

--The distance between a nav panel's content edge and the center of the closest vertical divider
ZO_GAMEPAD_PANEL_BG_CONTENT_DIVIDER_CENTER_OFFSET_X = ZO_GAMEPAD_CONTENT_INSET_X - ZO_GAMEPAD_PANEL_BG_VERTICAL_DIVIDER_WIDTH / 2

--HEADER AREA--

--Divider offset is the distance from title safe to the top of the divider
ZO_GAMEPAD_CONTENT_HEADER_DIVIDER_OFFSET_Y = ZO_GAMEPAD_CONTENT_TITLE_HEIGHT + ZO_GAMEPAD_CONTENT_TITLE_DIVIDER_PADDING_Y

--Title/Info offset is the distance from header title bottom to the top of the info fields
ZO_GAMEPAD_CONTENT_HEADER_TITLE_INFO_PADDING_Y = ZO_GAMEPAD_CONTENT_TITLE_DIVIDER_PADDING_Y + ZO_GAMEPAD_CONTENT_DIVIDER_HEIGHT + ZO_GAMEPAD_CONTENT_DIVIDER_INFO_PADDING_Y

-----------------
--Old Constants--
-----------------

ZO_GAMEPAD_SCREEN_PADDING = 56
ZO_GAMEPAD_CONTENT_VERT_OFFSET_PADDING = 20
ZO_GAMEPAD_CONTENT_VERT_OFFSET_PADDING_WIDE = 40

ZO_GAMEPAD_CONTENT_BOTTOM_OFFSET = 900

ZO_GAMEPAD_DEFAULT_HEADER_DATA_PADDING = 10

ZO_GAMEPAD_DEFAULT_SELECTION_ICON_SIZE = 64
ZO_GAMEPAD_DEFAULT_SELECTION_ICON_HIGHLIGHT_SIZE = 75

-- List Constants
ZO_GAMEPAD_DEFAULT_LIST_MAX_CONTROL_SCALE = 1.375
ZO_GAMEPAD_DEFAULT_LIST_MIN_CONTROL_SCALE = 1.0

local GAMEPAD_LIST_SCREEN_X_OFFSET = 197 -- x offset to the left limit of the entry text.
ZO_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT = GAMEPAD_LIST_SCREEN_X_OFFSET - ZO_GAMEPAD_SAFE_ZONE_INSET_X
ZO_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH_AFTER_INDENT = ZO_GAMEPAD_CONTENT_WIDTH - ZO_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT
ZO_GAMEPAD_DEFAULT_LIST_ENTRY_HEIGHT = 40
ZO_GAMEPAD_DEFAULT_LIST_ENTRY_SELECTED_HEIGHT = 50
ZO_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_X_OFFSET = -38
ZO_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_DIMENSION = 40
ZO_GAMEPAD_DEFAULT_LIST_ENTRY_SECOND_ICON_X_OFFSET = -85

local DEFAULT_LIST_ICON_MAX_SIZE = ZO_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_DIMENSION * ZO_GAMEPAD_DEFAULT_LIST_MAX_CONTROL_SCALE
local ICON_TEXT_GAP = math.abs(ZO_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_X_OFFSET) - DEFAULT_LIST_ICON_MAX_SIZE / 2 --assumes icon is centered on the left of the text
ZO_GAMEPAD_DEFAULT_LIST_ENTRY_MINIMUM_INDENT = DEFAULT_LIST_ICON_MAX_SIZE + ICON_TEXT_GAP --the minimum indentation of a list entry so that an icon arbitrarily anchored off the label is not indented

local GAMEPAD_LIST_ICON_WIDTH = 64
local GAMEPAD_LIST_ICON_SCREEN_X_OFFSET = 120 + (GAMEPAD_LIST_ICON_WIDTH / 2)
ZO_GAMEPAD_DEFAULT_LIST_ICON_INDENT_CENTER = GAMEPAD_LIST_ICON_SCREEN_X_OFFSET - ZO_GAMEPAD_SAFE_ZONE_INSET_X

--Special cases for VOIP since we have the icons to the right of the entries
ZO_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_X_OFFSET_VOICECHAT = GAMEPAD_LIST_ICON_WIDTH / 2
ZO_GAMEPAD_DEFAULT_LIST_ENTRY_SECOND_ICON_X_OFFSET_VOICECHAT = ZO_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_X_OFFSET_VOICECHAT + ZO_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_DIMENSION
ZO_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH_VOICECHAT = ZO_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH_AFTER_INDENT - ZO_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_DIMENSION * 2
ZO_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH_VOICECHAT_HISTORY = ZO_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH_AFTER_INDENT - ZO_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_DIMENSION
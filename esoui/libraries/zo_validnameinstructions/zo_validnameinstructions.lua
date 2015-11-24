ZO_ValidNameInstructions = ZO_Object:Subclass()

function ZO_ValidNameInstructions:New(...)
    local instructions = ZO_Object.New(self)
    instructions:Initialize(...)
    return instructions
end

function ZO_ValidNameInstructions:Initialize(control, template)
    self.m_control = control
    self.m_ruleToControl = {}
    self.m_template = template or "ZO_NameInstructionLine"

    self:AddInstruction(NAME_RULE_TOO_SHORT)
    self:AddInstruction(NAME_RULE_CANNOT_START_WITH_SPACE)
    self:AddInstruction(NAME_RULE_MUST_END_WITH_LETTER)
    self:AddInstruction(NAME_RULE_TOO_MANY_IDENTICAL_ADJACENT_CHARACTERS)
    self:AddInstruction(NAME_RULE_NO_NUMBERS)
    self:AddInstruction(NAME_RULE_NO_ADJACENT_PUNCTUATION_CHARACTERS)
    self:AddInstruction(NAME_RULE_TOO_MANY_PUNCTUATION_CHARACTERS)
    self:AddInstruction(NAME_RULE_INVALID_CHARACTERS)
end

function ZO_ValidNameInstructions:GetControl()
    return self.m_control
end

function ZO_ValidNameInstructions:AddInstruction(instructionEnum)
    self.instructionLineCounter = (self.instructionLineCounter or 0) + 1
    local instruction = CreateControlFromVirtual("$(parent)NameInstructionLine" .. instructionEnum .. self.instructionLineCounter, self.m_control, self.m_template)
    instruction:SetText(GetString("SI_NAMINGERROR", instructionEnum))
    instruction.m_rule = instructionEnum

    if(self.m_anchorTo) then
        instruction:SetAnchor(TOPLEFT, self.m_anchorTo, BOTTOMLEFT, 0, 15)
    else
        instruction:SetAnchor(TOP, self.m_control, TOP, 0, 10)
    end

    self.m_anchorTo = instruction
    self.m_ruleToControl[instructionEnum] = instruction
end

local function HasViolatedRule(rule, ruleViolations)
    for i = 1, #ruleViolations do
        if(rule == ruleViolations[i]) then
            return true
        end
    end

    return false
end

function ZO_ValidNameInstructions:UpdateViolations(ruleViolations)
    for rule, instructionLine in pairs(self.m_ruleToControl) do
        if(HasViolatedRule(rule, ruleViolations)) then
            instructionLine:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_FAILED))
        else
            instructionLine:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
        end
    end
end

function ZO_ValidNameInstructions:SetPreferredAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
    self.m_preferredAnchor = ZO_Anchor:New(point, relativeTo, relativePoint, offsetX, offsetY)
end

function ZO_ValidNameInstructions:Show(editControl, ruleViolations)
    if(self.m_preferredAnchor) then
        self.m_preferredAnchor:Set(self.m_control)
    elseif editControl then
        self.m_control:ClearAnchors()
        self.m_control:SetAnchor(TOPRIGHT, editControl, TOPLEFT, -50, 0)
    end

    self.m_control:SetHidden(false)
    self:UpdateViolations(ruleViolations)
end

function ZO_ValidNameInstructions:Hide()
    self.m_control:SetHidden(true)
end

local NAME_RULES_TABLE = nil

function ZO_ValidNameInstructions_GetViolationString(name, ruleViolations, hideUnviolatedRules, format)
    format = format or SI_INVALID_NAME_DIALOG_INSTRUCTION_FORMAT

    if(NAME_RULES_TABLE == nil) then
        NAME_RULES_TABLE = {}

        table.insert(NAME_RULES_TABLE, NAME_RULE_TOO_SHORT)
        table.insert(NAME_RULES_TABLE, NAME_RULE_CANNOT_START_WITH_SPACE)
        table.insert(NAME_RULES_TABLE, NAME_RULE_MUST_END_WITH_LETTER)
        table.insert(NAME_RULES_TABLE, NAME_RULE_TOO_MANY_IDENTICAL_ADJACENT_CHARACTERS)
        table.insert(NAME_RULES_TABLE, NAME_RULE_NO_NUMBERS)
        table.insert(NAME_RULES_TABLE, NAME_RULE_NO_ADJACENT_PUNCTUATION_CHARACTERS)
        table.insert(NAME_RULES_TABLE, NAME_RULE_TOO_MANY_PUNCTUATION_CHARACTERS)
        table.insert(NAME_RULES_TABLE, NAME_RULE_INVALID_CHARACTERS)
    end

    local invalidNameString = ""

    for i, instructionEnum in ipairs(NAME_RULES_TABLE) do
        local violatedRule = HasViolatedRule(instructionEnum, ruleViolations)
        if(violatedRule or hideUnviolatedRules ~= true) then
            local color = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
            if(violatedRule) then
                color = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_FAILED))
            end

            local text = GetString("SI_NAMINGERROR", instructionEnum)
            local coloredText = color:Colorize(text)

            invalidNameString = invalidNameString .. zo_strformat(format, coloredText)
        end
    end

    return invalidNameString
end
-- Luacheck configuration for the CMO Lua reference library.
-- CMO scripts run inside the game engine against a large custom API and
-- are loaded by the engine (which calls entry-point functions by name),
-- so the usual "undefined/non-standard global" and "unused argument"
-- warnings are expected and not actionable here. We keep luacheck focused
-- on real problems: syntax errors, undefined LOCAL variables, etc.

std = "lua51"

-- Allow files to define their own globals (CMO calls entry points such as
-- setupCSAR(), campaignTick(), redAITick(), checkCSARSuccess() by name).
allow_defined_top = true

-- Unused function arguments and loop variables are common and harmless in
-- API-shaped code and type stubs; do not warn on them.
unused_args = false

-- This is a REFERENCE library: example/template files intentionally declare
-- illustrative constants and expose helper/entry-point functions (which CMO
-- calls by name), so "unused" results are expected, not defects. We suppress
-- those classes while still failing on real problems (syntax errors,
-- references to genuinely-undefined locals, etc.).
ignore = {
    "131",  -- unused/exposed global (CMO entry points: setupCSAR, campaignTick, ...)
    "211",  -- unused local variable/function (illustrative constants & helpers)
    "212",  -- unused argument
    "213",  -- unused loop variable
    "231",  -- local set but never accessed
    "241",  -- local mutated but never accessed
    "611",  -- line contains only whitespace
    "612",  -- line contains trailing whitespace
    "614",  -- trailing whitespace in comment
    "631",  -- line is too long (long API/DMS literals are common here)
}

-- The CMO API surface. These are provided by the game engine at runtime;
-- treat them as known read-only globals so luacheck does not flag every call.
read_globals = {
    -- ScenEdit_* (scenario editing)
    "ScenEdit_AddUnit", "ScenEdit_GetUnit", "ScenEdit_SetUnit", "ScenEdit_DeleteUnit",
    "ScenEdit_UpdateUnit", "ScenEdit_SetUnitSide", "ScenEdit_AssignUnitToMission",
    "ScenEdit_UnitX", "ScenEdit_UnitY", "ScenEdit_UnitC",
    "ScenEdit_AddMission", "ScenEdit_SetMission", "ScenEdit_DeleteMission", "ScenEdit_GetMission",
    "ScenEdit_SetEvent", "ScenEdit_SetTrigger", "ScenEdit_SetEventTrigger",
    "ScenEdit_SetCondition", "ScenEdit_SetEventCondition",
    "ScenEdit_SetAction", "ScenEdit_SetEventAction", "ScenEdit_SetSpecialAction",
    "ScenEdit_SetSidePosture", "ScenEdit_SetDoctrine",
    "ScenEdit_SetEMCON", "ScenEdit_SetEmcon", "ScenEdit_SetGroupEMCON",
    "ScenEdit_AddReferencePoint", "ScenEdit_DeleteReferencePoint",
    "ScenEdit_GetReferencePoint", "ScenEdit_SetReferencePoint",
    "ScenEdit_AddZone", "ScenEdit_SetZone",
    "ScenEdit_SetKeyValue", "ScenEdit_GetKeyValue",
    "ScenEdit_GetScore", "ScenEdit_SetScore",
    "ScenEdit_SpecialMessage", "ScenEdit_EndScenario",
    "ScenEdit_CurrentTime", "ScenEdit_SetWeather", "ScenEdit_GetWeather",
    "ScenEdit_GetTimeOfDay", "ScenEdit_TransferUnit",
    "ScenEdit_GetUnits", "ScenEdit_AddContact", "ScenEdit_RemoveContact",
    "ScenEdit_GetScenarioInfo", "ScenEdit_SetScenarioInfo", "ScenEdit_GetSide",
    "ScenEdit_InputBox", "ScenEdit_MsgBox",
    -- VP_* (read-only view)
    "VP_GetSide", "VP_GetUnit", "VP_GetContact",
    -- Tool_* / World_* / UI_*
    "Tool_Range", "Tool_Bearing", "Tool_LOS", "Tool_EmulateNoConsole",
    "World_GetElevation", "UI_SetCameraView",
}

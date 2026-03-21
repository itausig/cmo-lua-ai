--- CMO Lua UI Messages Library
--- Player messaging, military message formatting, dialogs, DTG, ACP-126.
---
--- @module ui.messages
---
--- USAGE EXAMPLE:
---   local Msg = dofile('path/to/lib/ui/messages.lua')
---
---   -- Simple special message
---   Msg.send('USA', 'Phase 2 has begun.')
---
---   -- DTG-formatted intel report
---   Msg.intelReport('USA', 'TRACK-001', 'SA-21 battery detected at N38.5 E012.3')
---
---   -- ACP-126 military message
---   local text = Msg.acp126({
---       from    = 'CTF 60',
---       to      = 'ALL SHIPS',
---       subject = 'COMMENCE HOSTILITIES',
---       body    = 'Execute OPLAN BLUE SWORD effective immediately.',
---   })
---   Msg.send('USA', text)
---
---   -- Warning alert with severity
---   Msg.alert('USA', Msg.SEVERITY.CRITICAL, 'Carrier under missile attack!')

local Msg = {}

-- ============================================================
-- SEVERITY LEVELS
-- ============================================================

--- Message severity constants for alerts.
Msg.SEVERITY = {
    INFO     = 'INFO',
    WARNING  = 'WARNING',
    CRITICAL = 'CRITICAL',
    FLASH    = 'FLASH',
}

-- ============================================================
-- DTG FORMATTER
-- ============================================================

--- Format a Unix timestamp as a DTG (Date-Time Group).
--- Format: "DDHHMMZ MON YY"  e.g. "211430Z MAR 26"
---
--- @param timeVar number|nil  Unix timestamp; defaults to ScenEdit_CurrentTime()
--- @return string  Uppercase DTG string
function Msg.DTG(timeVar)
    if timeVar == nil then
        local ok, t = pcall(ScenEdit_CurrentTime)
        timeVar = ok and t or os.time()
    end
    return string.upper(os.date('!%d%H%MZ %b %y', timeVar))
end

-- ============================================================
-- SEND MESSAGES
-- ============================================================

--- Send a plain-text special message to a side.
--- Wraps ScenEdit_SpecialMessage with error handling.
---
--- @param sideName string  Side name or GUID receiving the message
--- @param text     string  Message body
--- @return boolean
function Msg.send(sideName, text)
    local ok, err = pcall(ScenEdit_SpecialMessage, sideName, tostring(text))
    if not ok then
        print('[Msg] send error: ' .. tostring(err))
        return false
    end
    return true
end

--- Send a message to multiple sides simultaneously.
---
--- @param sides table   Array of side name/GUID strings
--- @param text  string
function Msg.broadcast(sides, text)
    for _, side in ipairs(sides or {}) do
        Msg.send(side, text)
    end
end

-- ============================================================
-- DIALOG FUNCTIONS
-- ============================================================

--- Show a message box to the player and wait for acknowledgement.
--- Wraps ScenEdit_MsgBox.
---
--- @param text string
--- @return boolean  true if shown successfully
function Msg.msgBox(text)
    local ok, err = pcall(ScenEdit_MsgBox, tostring(text))
    if not ok then
        print('[Msg] msgBox error: ' .. tostring(err))
        return false
    end
    return true
end

--- Show an input dialog and return the player's response.
--- Wraps ScenEdit_InputBox.
---
--- @param prompt string  Prompt text shown to the player
--- @return string|nil   Player's input, or nil on cancel/error
---
--- EXAMPLE:
---   local name = Msg.inputBox('Enter your callsign:')
---   if name then Msg.send('USA', 'Welcome, ' .. name) end
function Msg.inputBox(prompt)
    local ok, result = pcall(ScenEdit_InputBox, tostring(prompt))
    if ok then return result end
    return nil
end

-- ============================================================
-- ALERT MESSAGES
-- ============================================================

--- Send a severity-prefixed alert message.
---
--- @param sideName string
--- @param severity string  Msg.SEVERITY constant
--- @param text     string  Alert text
--- @return boolean
---
--- EXAMPLE:
---   Msg.alert('USA', Msg.SEVERITY.CRITICAL, 'Surface contact inbound!')
function Msg.alert(sideName, severity, text)
    local prefix = '*** ' .. (severity or 'ALERT') .. ' ***'
    return Msg.send(sideName, prefix .. '\n' .. tostring(text))
end

--- Send a FLASH-precedence alert (highest priority message).
---
--- @param sideName string
--- @param text     string
--- @return boolean
function Msg.flash(sideName, text)
    return Msg.alert(sideName, Msg.SEVERITY.FLASH, text)
end

-- ============================================================
-- ACP-126 MILITARY MESSAGE FORMATTER
-- ============================================================
-- ACP-126 is the Allied Communications Publication standard for
-- military message traffic. Format follows the community Cookbook pattern.
-- Structure: PRECEDENCE / FROM / TO / INFO / DTG / SUBJECT / / TEXT / /

--- Format a message in ACP-126 military message style.
---
--- @param params table
---   {
---     from       = string,       -- Originator (e.g. 'CTF 60')
---     to         = string,       -- Primary addressee(s)
---     info       = string|nil,   -- Info addressees (optional)
---     subject    = string,       -- Message subject
---     body       = string,       -- Message body
---     precedence = string|nil,   -- 'FLASH'|'IMMEDIATE'|'PRIORITY'|'ROUTINE' (default ROUTINE)
---     classification = string|nil -- 'TOP SECRET'|'SECRET'|'UNCLASSIFIED' (default UNCLASSIFIED)
---   }
--- @return string  Formatted ACP-126 message
---
--- EXAMPLE:
---   local msg = Msg.acp126({
---       from='CTF 60', to='USS NIMITZ', subject='TASKING',
---       body='Proceed immediately to position ALPHA.'
---   })
---   Msg.send('USA', msg)
function Msg.acp126(params)
    params = params or {}
    local dtg        = Msg.DTG()
    local precedence = (params.precedence or 'ROUTINE'):upper()
    local classif    = (params.classification or 'UNCLASSIFIED'):upper()
    local from       = (params.from or 'UNKNOWN'):upper()
    local to         = (params.to   or 'ALL'):upper()
    local subject    = (params.subject or ''):upper()
    local body       = params.body or ''
    local info       = params.info

    local lines = {
        classif,
        precedence,
        'FM ' .. from,
        'TO ' .. to,
    }
    if info then lines[#lines + 1] = 'INFO ' .. info:upper() end
    lines[#lines + 1] = 'DTG ' .. dtg
    lines[#lines + 1] = 'SUBJ ' .. subject
    lines[#lines + 1] = '//'
    lines[#lines + 1] = ''
    lines[#lines + 1] = body
    lines[#lines + 1] = ''
    lines[#lines + 1] = '//'
    lines[#lines + 1] = classif

    return table.concat(lines, '\n')
end

-- ============================================================
-- INTEL REPORT FORMATTER
-- ============================================================

--- Format and send an intelligence report.
---
--- @param sideName   string
--- @param trackId    string  Track/contact identifier
--- @param body       string  Report body
--- @param sourceName string|nil  Intelligence source (default 'SIGINT')
--- @return boolean
---
--- EXAMPLE:
---   Msg.intelReport('USA', 'TGT-007', 'SA-21 Triumf battery, grid N38.50 E012.30')
function Msg.intelReport(sideName, trackId, body, sourceName)
    local dtg  = Msg.DTG()
    local src  = (sourceName or 'SIGINT'):upper()
    local text = string.format(
        '[INTEL] DTG: %s\nSOURCE: %s\nTRACK: %s\n\n%s',
        dtg, src, tostring(trackId), tostring(body))
    return Msg.send(sideName, text)
end

-- ============================================================
-- STANDARD SCENARIO MESSAGES
-- ============================================================

--- Send a phase-change notification to a side.
---
--- @param sideName  string
--- @param phaseName string  e.g. 'PHASE 2', 'ENDGAME'
--- @param detail    string|nil  Optional descriptive text
--- @return boolean
function Msg.phaseChange(sideName, phaseName, detail)
    local text = string.format('=== %s ===\nDTG: %s\n%s',
        tostring(phaseName):upper(),
        Msg.DTG(),
        detail or '')
    return Msg.send(sideName, text)
end

--- Send a unit status report message.
---
--- @param sideName string
--- @param unitName string
--- @param status   string  e.g. 'BINGO FUEL', 'WINCHESTER', 'RTB'
--- @param extra    string|nil
--- @return boolean
function Msg.unitStatus(sideName, unitName, status, extra)
    local text = string.format('[STATUS] %s: %s\nDTG: %s%s',
        tostring(unitName),
        tostring(status),
        Msg.DTG(),
        extra and ('\n' .. extra) or '')
    return Msg.send(sideName, text)
end

--- Send a SITREP (Situation Report) to a side.
---
--- @param sideName string
--- @param lines    table   Array of strings forming the report body
--- @return boolean
function Msg.sitrep(sideName, lines)
    local header = string.format('SITREP DTG: %s', Msg.DTG())
    local body   = table.concat(lines or {}, '\n')
    return Msg.send(sideName, header .. '\n' .. body)
end

return Msg

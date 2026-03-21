--- CMO Lua Scoring Library
--- Score management, thresholds, kill/loss tracking, after-action reporting.
---
--- @module scoring.scoring
---
--- USAGE EXAMPLE:
---   local Scoring = dofile('path/to/lib/scoring/scoring.lua')
---   local KS      = dofile('path/to/core/keystore.lua')
---
---   -- Add 100 points to USA
---   Scoring.addScore('USA', 100, 'Carrier destroyed')
---
---   -- Get current score
---   local score = Scoring.getScore('USA')
---
---   -- Check if win condition met (score >= 500)
---   if Scoring.meetsThreshold('USA', 500) then
---       ScenEdit_EndScenario()
---   end
---
---   -- After-action report
---   ScenEdit_SpecialMessage('USA', Scoring.aarReport('USA', KS))

local Scoring = {}

-- ============================================================
-- SCORE OPERATIONS
-- ============================================================

--- Get the current score for a side.
---
--- @param sideName string  Side name or GUID
--- @return number  Current score (0 if not available)
function Scoring.getScore(sideName)
    local ok, score = pcall(ScenEdit_GetScore, sideName)
    return (ok and type(score) == 'number') and score or 0
end

--- Set the score for a side to an absolute value.
--- CMO uses ScenEdit_SetScore to assign a specific score.
---
--- @param sideName string
--- @param value    number   New absolute score
--- @return boolean
function Scoring.setScore(sideName, value)
    local ok, err = pcall(ScenEdit_SetScore, sideName, value, 'Score set by script')
    if not ok then
        print('[Scoring] setScore error: ' .. tostring(err))
        return false
    end
    return true
end

--- Add a score delta to a side.
--- Reads the current score and sets it to current + delta.
---
--- @param sideName string
--- @param delta    number   Points to add (positive) or subtract (negative)
--- @param reason   string|nil  Optional reason string logged to CMO
--- @return boolean
---
--- EXAMPLE:
---   Scoring.addScore('USA', 250, 'Destroyed enemy carrier')
function Scoring.addScore(sideName, delta, reason)
    local current  = Scoring.getScore(sideName)
    local newScore = current + (delta or 0)
    local ok, err  = pcall(ScenEdit_SetScore, sideName, newScore, reason or '')
    if not ok then
        print('[Scoring] addScore error: ' .. tostring(err))
        return false
    end
    return true
end

--- Subtract points from a side's score (convenience wrapper).
---
--- @param sideName string
--- @param delta    number  Points to subtract (positive value)
--- @param reason   string|nil
--- @return boolean
function Scoring.subtractScore(sideName, delta, reason)
    return Scoring.addScore(sideName, -(delta or 0), reason)
end

-- ============================================================
-- THRESHOLD EVALUATION
-- ============================================================

--- Check if a side's score meets or exceeds a threshold.
---
--- @param sideName  string
--- @param threshold number
--- @return boolean  true if score >= threshold
function Scoring.meetsThreshold(sideName, threshold)
    return Scoring.getScore(sideName) >= threshold
end

--- Check if a side's score is at or below a threshold (e.g. loss condition).
---
--- @param sideName  string
--- @param threshold number
--- @return boolean  true if score <= threshold
function Scoring.belowThreshold(sideName, threshold)
    return Scoring.getScore(sideName) <= threshold
end

--- Evaluate a score against named outcome thresholds.
--- Returns the highest matching outcome label.
---
--- @param sideName   string
--- @param thresholds table   Ordered table: {{score=number, label=string}, ...}
---                            Must be sorted descending by score.
--- @return string|nil  First matching label, or nil
---
--- EXAMPLE:
---   local result = Scoring.evaluate('USA', {
---       {score=500, label='Decisive Victory'},
---       {score=300, label='Marginal Victory'},
---       {score=100, label='Draw'},
---       {score=0,   label='Defeat'},
---   })
---   ScenEdit_SpecialMessage('USA', 'OUTCOME: ' .. result)
function Scoring.evaluate(sideName, thresholds)
    local score = Scoring.getScore(sideName)
    for _, entry in ipairs(thresholds) do
        if score >= entry.score then
            return entry.label
        end
    end
    return 'Unknown'
end

-- ============================================================
-- KILL / LOSS TRACKING (USES KEYSTORE)
-- ============================================================

--- Record a kill for a side (stores in keystore).
---
--- @param ks       table   Keystore module instance
--- @param sideName string
--- @param unitName string  Name or type of the destroyed unit
--- @param unitType string|nil  'Aircraft'|'Ship' etc.
function Scoring.recordKill(ks, sideName, unitName, unitType)
    ks.increment('score.kills.' .. sideName .. '.total')
    if unitType then
        ks.increment('score.kills.' .. sideName .. '.' .. unitType)
    end
    -- Log kill names for after-action report
    local existing = ks.get('score.kills.' .. sideName .. '.log', '')
    local separator = (existing ~= '') and ',' or ''
    ks.set('score.kills.' .. sideName .. '.log',
           existing .. separator .. tostring(unitName))
end

--- Record a friendly loss for a side (stores in keystore).
---
--- @param ks       table
--- @param sideName string
--- @param unitName string
--- @param unitType string|nil
function Scoring.recordLoss(ks, sideName, unitName, unitType)
    ks.increment('score.losses.' .. sideName .. '.total')
    if unitType then
        ks.increment('score.losses.' .. sideName .. '.' .. unitType)
    end
    local existing = ks.get('score.losses.' .. sideName .. '.log', '')
    local separator = (existing ~= '') and ',' or ''
    ks.set('score.losses.' .. sideName .. '.log',
           existing .. separator .. tostring(unitName))
end

--- Get kill count for a side (optionally by unit type).
---
--- @param ks       table
--- @param sideName string
--- @param unitType string|nil
--- @return number
function Scoring.getKills(ks, sideName, unitType)
    local key = 'score.kills.' .. sideName .. '.' .. (unitType or 'total')
    return ks.getNumber(key, 0)
end

--- Get loss count for a side.
---
--- @param ks       table
--- @param sideName string
--- @param unitType string|nil
--- @return number
function Scoring.getLosses(ks, sideName, unitType)
    local key = 'score.losses.' .. sideName .. '.' .. (unitType or 'total')
    return ks.getNumber(key, 0)
end

-- ============================================================
-- SCORE-BASED EVENTS
-- ============================================================

--- Award points for a kill and optionally send a message.
---
--- @param sideName   string
--- @param points     number
--- @param victimName string
--- @param msgSide    string|nil  Side to receive the message (nil = no message)
--- @return boolean
function Scoring.awardKill(sideName, points, victimName, msgSide)
    local ok = Scoring.addScore(sideName, points,
        string.format('Kill: %s (+%d pts)', tostring(victimName), points))

    if msgSide then
        local score = Scoring.getScore(sideName)
        pcall(ScenEdit_SpecialMessage, msgSide,
            string.format('KILL: %s destroyed. +%d points. Total: %d',
                tostring(victimName), points, score))
    end
    return ok
end

--- Penalize a side for a friendly unit loss.
---
--- @param sideName   string
--- @param penalty    number  Positive value subtracted from score
--- @param unitName   string
--- @param msgSide    string|nil
--- @return boolean
function Scoring.penalizeLoss(sideName, penalty, unitName, msgSide)
    local ok = Scoring.subtractScore(sideName, penalty,
        string.format('Loss: %s (-%d pts)', tostring(unitName), penalty))

    if msgSide then
        local score = Scoring.getScore(sideName)
        pcall(ScenEdit_SpecialMessage, msgSide,
            string.format('LOSS: %s destroyed. -%d points. Total: %d',
                tostring(unitName), penalty, score))
    end
    return ok
end

-- ============================================================
-- AFTER-ACTION REPORT
-- ============================================================

--- Generate an after-action report combining scores, kills, and losses.
---
--- @param sideName  string
--- @param ks        table|nil  Keystore instance (nil = no kill/loss data)
--- @param outcomes  table|nil  Threshold table for evaluate() (nil = no outcome line)
--- @return string   Multi-line AAR text
---
--- EXAMPLE:
---   ScenEdit_SpecialMessage('USA', Scoring.aarReport('USA', KS, {
---       {score=500, label='Decisive Victory'},
---       {score=0,   label='Defeat'},
---   }))
function Scoring.aarReport(sideName, ks, outcomes)
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    local ok_t, t = pcall(ScenEdit_CurrentTime)
    local dtg = string.upper(os.date('!%d%H%MZ %b %y', ok_t and t or os.time()))

    add('=== AFTER-ACTION REPORT ===')
    add(dtg)
    add('SIDE: ' .. tostring(sideName))
    add('')
    add(string.format('FINAL SCORE : %d', Scoring.getScore(sideName)))

    if outcomes then
        local outcome = Scoring.evaluate(sideName, outcomes)
        add('OUTCOME     : ' .. tostring(outcome))
    end

    if ks then
        add('')
        add(string.format('KILLS  : %d', Scoring.getKills(ks, sideName)))
        add(string.format('LOSSES : %d', Scoring.getLosses(ks, sideName)))

        local killLog = ks.get('score.kills.'  .. sideName .. '.log', '')
        local lossLog = ks.get('score.losses.' .. sideName .. '.log', '')

        if killLog ~= '' then
            add('')
            add('KILLS DETAIL:')
            for name in killLog:gmatch('([^,]+)') do
                add('  + ' .. name)
            end
        end
        if lossLog ~= '' then
            add('')
            add('LOSSES DETAIL:')
            for name in lossLog:gmatch('([^,]+)') do
                add('  - ' .. name)
            end
        end
    end

    add('')
    add('=== END AAR ===')
    return table.concat(lines, '\n')
end

return Scoring

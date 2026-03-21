--- CMO Lua KeyStore Library
--- Persistent state management wrapper around ScenEdit_GetKeyValue /
--- ScenEdit_SetKeyValue. Provides namespacing, counters, booleans,
--- table serialization, one-time guards, and a state machine helper.
---
--- @module keystore
---
--- USAGE EXAMPLE:
---   local KS = dofile('path/to/keystore.lua')
---
---   -- Namespaced values survive hot-reload and persist across saves.
---   KS.set('scenario.phase', 'SETUP')
---   print(KS.get('scenario.phase'))  -- 'SETUP'
---
---   -- Counter
---   KS.increment('kills.blue')
---   KS.increment('kills.blue')
---   print(KS.getNumber('kills.blue'))  -- 2
---
---   -- One-time guard
---   KS.once('intro_briefing', function()
---       ScenEdit_SpecialMessage('USA', 'Welcome, commander.')
---   end)
---
---   -- State machine
---   KS.setState('campaign', 'PHASE_1')
---   if KS.getState('campaign') == 'PHASE_1' then
---       -- launch phase 1 logic
---   end

local KS = {}

--- Global namespace prefix applied to all keys. Avoids collisions
--- between multiple scripts sharing the same keystore.
--- Override before using the module: KS.NS = 'myscen.'
KS.NS = 'cmo.'

-- ============================================================
-- INTERNAL HELPERS
-- ============================================================

--- Build a namespaced key string.
--- @param key string
--- @return string
local function nskey(key)
    return KS.NS .. tostring(key)
end

-- ============================================================
-- CORE GET / SET
-- ============================================================

--- Set a persistent key-value pair.
--- Values are stored as strings; use typed helpers for numbers/booleans.
---
--- @param key   string  Logical key (namespace prefix applied automatically)
--- @param value any     Stored via tostring()
function KS.set(key, value)
    ScenEdit_SetKeyValue(nskey(key), tostring(value))
end

--- Get a persistent value as a raw string.
--- Returns nil if the key has never been set.
---
--- @param key      string
--- @param default  string|nil  Returned when key is absent or empty
--- @return string|nil
function KS.get(key, default)
    local v = ScenEdit_GetKeyValue(nskey(key))
    if v == nil or v == '' then return default end
    return v
end

--- Delete a key (set to empty string, which is the CMO "unset" state).
---
--- @param key string
function KS.delete(key)
    ScenEdit_SetKeyValue(nskey(key), '')
end

--- Check whether a key has been set (non-empty).
---
--- @param key string
--- @return boolean
function KS.exists(key)
    local v = ScenEdit_GetKeyValue(nskey(key))
    return v ~= nil and v ~= ''
end

-- ============================================================
-- TYPED ACCESSORS
-- ============================================================

--- Get a key value as a number. Returns default (0) if absent or non-numeric.
---
--- @param key     string
--- @param default number|nil
--- @return number
function KS.getNumber(key, default)
    local v = KS.get(key)
    return tonumber(v) or (default or 0)
end

--- Set a key to a numeric value.
---
--- @param key   string
--- @param value number
function KS.setNumber(key, value)
    KS.set(key, tostring(tonumber(value) or 0))
end

--- Get a boolean flag. Stored as 'true' or 'false'.
--- Returns default (false) if key is absent.
---
--- @param key     string
--- @param default boolean|nil
--- @return boolean
function KS.getBool(key, default)
    local v = KS.get(key)
    if v == 'true'  then return true  end
    if v == 'false' then return false end
    return (default == true)
end

--- Set a boolean flag.
---
--- @param key   string
--- @param value boolean
function KS.setBool(key, value)
    KS.set(key, value and 'true' or 'false')
end

--- Toggle a boolean flag. Returns the new value.
---
--- @param key string
--- @return boolean  New value after toggle
function KS.toggleBool(key)
    local new = not KS.getBool(key)
    KS.setBool(key, new)
    return new
end

-- ============================================================
-- COUNTER HELPERS
-- ============================================================

--- Increment a numeric counter by step (default 1). Returns new value.
---
--- @param key  string
--- @param step number|nil  Increment amount (default 1)
--- @return number  New counter value
function KS.increment(key, step)
    step = step or 1
    local new = KS.getNumber(key) + step
    KS.setNumber(key, new)
    return new
end

--- Decrement a numeric counter by step (default 1). Returns new value.
--- Will not go below zero unless allowNegative is true.
---
--- @param key          string
--- @param step         number|nil   Decrement amount (default 1)
--- @param allowNegative boolean|nil  Allow result < 0 (default false)
--- @return number  New counter value
function KS.decrement(key, step, allowNegative)
    step = step or 1
    local new = KS.getNumber(key) - step
    if not allowNegative and new < 0 then new = 0 end
    KS.setNumber(key, new)
    return new
end

--- Reset a counter to zero (or a given value).
---
--- @param key   string
--- @param value number|nil  Reset target (default 0)
function KS.resetCounter(key, value)
    KS.setNumber(key, value or 0)
end

-- ============================================================
-- TABLE SERIALIZATION
-- ============================================================

--- Serialize a flat (depth-1) table to a JSON-like string.
--- Supports string and number values only. Nested tables are skipped.
---
--- @param t table
--- @return string  Serialized representation
local function serializeTable(t)
    local parts = {}
    for k, v in pairs(t) do
        local vtype = type(v)
        if vtype == 'string' then
            -- Escape quotes
            local vs = v:gsub('"', '\\"')
            parts[#parts + 1] = '"' .. tostring(k) .. '":"' .. vs .. '"'
        elseif vtype == 'number' or vtype == 'boolean' then
            parts[#parts + 1] = '"' .. tostring(k) .. '":' .. tostring(v)
        end
    end
    table.sort(parts)   -- deterministic ordering
    return '{' .. table.concat(parts, ',') .. '}'
end

--- Deserialize a JSON-like string (produced by serializeTable) back to a table.
---
--- @param s string
--- @return table
local function deserializeTable(s)
    local t = {}
    if not s or s == '' then return t end
    -- Quoted-value pairs: "key":"value"
    for k, v in s:gmatch('"([^"]+)":"([^"]*)"') do
        t[k] = v
    end
    -- Numeric/boolean pairs: "key":value
    for k, v in s:gmatch('"([^"]+)":([%d%.%-]+)') do
        if t[k] == nil then
            t[k] = tonumber(v) or v
        end
    end
    for k, v in s:gmatch('"([^"]+)":(true)') do
        if t[k] == nil then t[k] = true end
    end
    for k, v in s:gmatch('"([^"]+)":(false)') do
        if t[k] == nil then t[k] = false end
    end
    return t
end

--- Store a flat table in the keystore.
---
--- @param key string
--- @param t   table
function KS.setTable(key, t)
    KS.set(key, serializeTable(t))
end

--- Retrieve a flat table from the keystore.
--- Returns an empty table if the key is absent.
---
--- @param key string
--- @return table
function KS.getTable(key)
    local s = KS.get(key, '')
    return deserializeTable(s)
end

--- Update individual fields in a stored table without replacing it.
---
--- @param key    string
--- @param fields table   Key-value pairs to merge into the stored table
function KS.updateTable(key, fields)
    local t = KS.getTable(key)
    for k, v in pairs(fields) do
        t[k] = v
    end
    KS.setTable(key, t)
end

-- ============================================================
-- ONE-TIME EXECUTION GUARD
-- ============================================================

--- Execute fn exactly once per scenario playthrough.
--- The flag is stored in the keystore under the guard key.
--- Once triggered, subsequent calls to KS.once() with the same key are no-ops.
---
--- @param guardKey string    Unique key for this guard
--- @param fn       function  Code to run on first invocation
--- @return boolean           true if fn was executed, false if already ran
---
--- EXAMPLE:
---   KS.once('intro_message', function()
---       ScenEdit_SpecialMessage('USA', 'Phase 1 begins.')
---   end)
function KS.once(guardKey, fn)
    local stateKey = 'once.' .. guardKey
    if KS.getBool(stateKey) then return false end
    KS.setBool(stateKey, true)
    if type(fn) == 'function' then
        local ok, err = pcall(fn)
        if not ok then
            ScenEdit_SpecialMessage and pcall(ScenEdit_SpecialMessage,
                '', 'KS.once error [' .. guardKey .. ']: ' .. tostring(err))
        end
    end
    return true
end

--- Reset a one-time guard so it can fire again.
---
--- @param guardKey string
function KS.resetOnce(guardKey)
    KS.setBool('once.' .. guardKey, false)
end

--- Check whether a one-time guard has already fired.
---
--- @param guardKey string
--- @return boolean
function KS.hasFired(guardKey)
    return KS.getBool('once.' .. guardKey)
end

-- ============================================================
-- STATE MACHINE HELPER
-- ============================================================

--- Set the named state machine to a given state string.
--- Any string is valid as a state name.
---
--- @param machine string  Logical machine name (e.g. 'campaign', 'patrol')
--- @param state   string  State value (e.g. 'IDLE', 'TRANSIT', 'ON_STATION')
function KS.setState(machine, state)
    KS.set('sm.' .. machine, tostring(state))
end

--- Get the current state of a named state machine.
---
--- @param machine  string
--- @param default  string|nil  Returned if machine has no state set
--- @return string
function KS.getState(machine, default)
    return KS.get('sm.' .. machine, default or 'UNKNOWN')
end

--- Check whether a state machine is in a specific state.
---
--- @param machine string
--- @param state   string
--- @return boolean
function KS.inState(machine, state)
    return KS.getState(machine) == state
end

--- Transition a state machine and record a timestamp of the transition.
--- Use KS.getStateAge() to measure time spent in current state.
---
--- @param machine  string
--- @param newState string
function KS.transition(machine, newState)
    KS.setState(machine, newState)
    local ok, t = pcall(ScenEdit_CurrentTime)
    KS.setNumber('sm.' .. machine .. '.ts', ok and t or os.time())
end

--- Return the number of seconds the state machine has been in its current state.
--- Requires transitions to have been set via KS.transition().
---
--- @param machine string
--- @return number  Seconds since last transition (0 if no timestamp recorded)
function KS.getStateAge(machine)
    local ts = KS.getNumber('sm.' .. machine .. '.ts', 0)
    if ts == 0 then return 0 end
    local ok, now = pcall(ScenEdit_CurrentTime)
    if not ok then now = os.time() end
    return now - ts
end

-- ============================================================
-- UTILITY: DUMP ALL KNOWN KEYS
-- ============================================================

--- Return a summary table of all keys whose names are known to this session.
--- NOTE: CMO does not expose an "enumerate all keys" API. This function
--- only reports keys that were set during the current Lua session by
--- calling KS.set(). For debugging only.
---
--- @return table  {key = value, ...}
local _sessionKeys = {}

local _origSet = KS.set
KS.set = function(key, value)
    _sessionKeys[nskey(key)] = true
    _origSet(key, value)
end

function KS.dumpSession()
    local t = {}
    for k in pairs(_sessionKeys) do
        t[k] = ScenEdit_GetKeyValue(k)
    end
    return t
end

return KS

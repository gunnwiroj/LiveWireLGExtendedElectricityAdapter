local function loadModule(name)
    local ok, err = pcall(require, name)
    if not ok then
        print("[LiveWireLGEEAdapter] Could not load " .. name .. ": " .. tostring(err))
    end
    return ok
end

if not loadModule("LiveWire/LW_Config") or not loadModule("LiveWire/LW_Anchor")
    or not loadModule("LGExtendedElectricity/LGEECore")
    or not loadModule("LGExtendedElectricity/LGEECover") then
    return
end

LiveWireLGEEAdapter = LiveWireLGEEAdapter or {}
if LiveWireLGEEAdapter.loaded then return end

local Adapter = LiveWireLGEEAdapter
local LW, EE = LiveWire, LGEE
local Config, Anchor = LW.Config, LW.Anchor

local function warnOnce(key, message)
    Adapter.warnings = Adapter.warnings or {}
    if Adapter.warnings[key] then return end
    Adapter.warnings[key] = true
    print("[LiveWireLGEEAdapter] " .. message)
end

local function takeoverActive()
    if type(EE.takeoverActive) ~= "function" then return false end
    local ok, active = pcall(EE.takeoverActive)
    return ok and active == true
end

local function supported()
    return type(EE.generatorRange) == "function"
        and type(EE.generatorVertical) == "function"
        and type(EE.engineRange) == "function"
        and type(EE.engineVerticalRange) == "function"
        and type(EE.cover) == "function"
        and type(EE.stackCover) == "function"
        and type(EE.noteRelay) == "function"
        and type(EE.beginRelayDiff) == "function"
        and type(EE.relayKey) == "function"
        and type(EE.CHUNK) == "number"
end

local function integrationActive()
    return takeoverActive() and supported()
end

local function rangeOverride(name, maximum)
    local ok, value = pcall(function()
        local options = getSandboxOptions and getSandboxOptions()
        local option = options and options:getOptionByName("LiveWireLGEE." .. name)
        if option then return option:getValue() end
        local vars = SandboxVars and SandboxVars.LiveWireLGEE
        return vars and vars[name]
    end)
    if ok and type(value) == "number" and value >= 0 and value <= maximum then
        return math.floor(value)
    end
    return nil
end

local originalTileRange = Config.tileRange
local originalVerticalRange = Config.verticalRange

Config.tileRange = function()
    if integrationActive() then
        local override = rangeOverride("PowerRangeOverride", 100)
        if override and override > 0 then return override end
        return 20
    end
    return originalTileRange()
end

Config.verticalRange = function()
    if integrationActive() then return 3 end
    return originalVerticalRange()
end

local function authority()
    if type(EE.isAuthority) == "function" then
        local ok, value = pcall(EE.isAuthority)
        if ok then return value == true end
    end
    return not (isClient and isClient())
end

local function exists(cell, x, y, z)
    return cell:getGridSquare(x, y, z) ~= nil
end

local function canHost(cell, x, y, z)
    local square = cell:getGridSquare(x, y, z)
    if not square then return false end
    local ok, generator = pcall(function() return square:getGenerator() end)
    return ok and generator == nil
end

local function circleInChunk(anchor, radius, kx, ky)
    local flat = {}
    local minX = math.max(kx * EE.CHUNK, anchor.x - radius)
    local maxX = math.min(kx * EE.CHUNK + EE.CHUNK - 1, anchor.x + radius)
    local minY = math.max(ky * EE.CHUNK, anchor.y - radius)
    local maxY = math.min(ky * EE.CHUNK + EE.CHUNK - 1, anchor.y + radius)
    local radius2 = radius * radius

    for y = minY, maxY do
        local dy = y - anchor.y
        for x = minX, maxX do
            local dx = x - anchor.x
            if dx * dx + dy * dy <= radius2 then
                flat[#flat + 1] = x
                flat[#flat + 1] = y
            end
        end
    end
    return flat
end

local coverageCaches = {}

local function chunkKey(kx, ky)
    return tostring(kx) .. ":" .. tostring(ky)
end

local function cacheForAnchor(id, anchor)
    local radius = Config.tileRange()
    local vertical = Config.verticalRange()
    local engine = EE.engineRange()
    local engineVertical = EE.engineVerticalRange()
    if type(anchor.x) ~= "number" or type(anchor.y) ~= "number"
        or type(anchor.z) ~= "number" or type(radius) ~= "number"
        or type(vertical) ~= "number" or type(engine) ~= "number"
        or type(engineVertical) ~= "number" then
        return nil
    end

    local signature = table.concat({
        tostring(anchor.x), tostring(anchor.y), tostring(anchor.z), tostring(radius),
        tostring(vertical), tostring(engine), tostring(engineVertical),
    }, ":")
    local cache = coverageCaches[id]
    if cache and cache.signature == signature then return cache end

    cache = {
        signature = signature,
        radius = radius,
        vertical = vertical,
        engine = engine,
        engineVertical = engineVertical,
        chunks = {},
        chunkByKey = {},
    }

    if radius >= engine and vertical >= engineVertical then
        local kx0, kx1 = math.floor((anchor.x - radius) / EE.CHUNK),
            math.floor((anchor.x + radius) / EE.CHUNK)
        local ky0, ky1 = math.floor((anchor.y - radius) / EE.CHUNK),
            math.floor((anchor.y + radius) / EE.CHUNK)
        for ky = ky0, ky1 do
            for kx = kx0, kx1 do
                local flat = circleInChunk(anchor, radius, kx, ky)
                if #flat > 0 then
                    local key = chunkKey(kx, ky)
                    local chunk = {
                        key = key, kx = kx, ky = ky, flat = flat,
                    }
                    cache.chunks[#cache.chunks + 1] = chunk
                    cache.chunkByKey[key] = chunk
                end
            end
        end
    end

    coverageCaches[id] = cache
    return cache
end

local function stampRegistrations(registrations)
    for i = 1, #registrations do
        local registration = registrations[i]
        registration.key = EE.relayKey(registration)
    end
    return registrations
end

local function registrationsForChunk(cell, anchor, cache, chunk)
    local registrations = {}
    local radius, vertical = cache.radius, cache.vertical
    local engine, engineVertical = cache.engine, cache.engineVertical

    if radius == engine then
        local minX, minY = chunk.kx * EE.CHUNK, chunk.ky * EE.CHUNK
        local maxX, maxY = minX + EE.CHUNK - 1, minY + EE.CHUNK - 1
        local nearestX = math.max(minX, math.min(anchor.x, maxX))
        local nearestY = math.max(minY, math.min(anchor.y, maxY))
        local dx, dy = nearestX - anchor.x, nearestY - anchor.y
        if dx * dx + dy * dy <= radius * radius then
            registrations[1] = {
                x = anchor.x, y = anchor.y, z = anchor.z, kx = chunk.kx, ky = chunk.ky,
            }
        end
    else
        local planned = EE.cover(chunk.flat, anchor.z, engine, function(x, y, z)
            return canHost(cell, x, y, z)
        end, registrations)
        if not planned then return {} end
    end

    if vertical > engineVertical then
        EE.stackCover(chunk.flat, chunk.kx, chunk.ky, anchor.z, vertical, engine,
            engineVertical, function(x, y, z) return exists(cell, x, y, z) end,
            function(x, y, z) return canHost(cell, x, y, z) end, registrations)
    end
    return stampRegistrations(registrations)
end

local function invalidateCoverageChunk(cx, cy)
    -- A host square can sit up to the engine radius across a target chunk boundary.
    local reach = math.ceil(EE.engineRange() / EE.CHUNK)
    for _, cache in pairs(coverageCaches) do
        for ky = cy - reach, cy + reach do
            for kx = cx - reach, cx + reach do
                local chunk = cache.chunkByKey[chunkKey(kx, ky)]
                if chunk then chunk.registrations = nil end
            end
        end
    end
end

local function invalidateCoverageAt(x, y)
    invalidateCoverageChunk(math.floor(x / EE.CHUNK), math.floor(y / EE.CHUNK))
end

local originalApply = Anchor.apply
Anchor.apply = function(anchor, on)
    if integrationActive() then return end
    return originalApply(anchor, on)
end

local originalBeginRelayDiff = EE.beginRelayDiff
EE.beginRelayDiff = function(...)
    local diff = originalBeginRelayDiff(...)
    if not authority() or not integrationActive() then return diff end

    local ok, anchors = pcall(Anchor.table)
    if not ok or type(anchors) ~= "table" then return diff end
    local cell = getCell()
    if not cell then return diff end
    for id in pairs(coverageCaches) do
        local anchor = anchors[id]
        if not anchor or anchor.on ~= true then coverageCaches[id] = nil end
    end
    for id, anchor in pairs(anchors) do
        if anchor and anchor.on == true then
            local planned, cache = pcall(cacheForAnchor, id, anchor)
            if planned and type(cache) == "table" then
                for c = 1, #cache.chunks do
                    local chunk = cache.chunks[c]
                    local registrations = chunk.registrations
                    if not registrations then
                        local calculated, result = pcall(registrationsForChunk, cell, anchor,
                            cache, chunk)
                        if calculated and type(result) == "table" then
                            registrations = result
                            chunk.registrations = registrations
                        else
                            warnOnce("coverage", "Could not plan one or more LiveWire anchor registrations.")
                            registrations = {}
                        end
                    end
                    for i = 1, #registrations do
                        local added = pcall(EE.noteRelay, diff, registrations[i])
                        if not added then
                            warnOnce("diff", "Could not add LiveWire coverage to LGEE's relay diff.")
                            break
                        end
                    end
                end
            else
                warnOnce("coverage", "Could not plan one or more LiveWire anchor registrations.")
            end
        end
    end
    return diff
end

local pendingSweep = false
local pendingUrgent = false
local lastSignature = nil
local pollTicks = 0

local function signature()
    if not integrationActive() then return "inactive" end
    local ok, anchors = pcall(Anchor.table)
    if not ok or type(anchors) ~= "table" then return nil end
    local parts = {}
    for id, anchor in pairs(anchors) do
        if anchor and anchor.on == true then
            parts[#parts + 1] = tostring(id) .. ":" .. tostring(anchor.x) .. ","
                .. tostring(anchor.y) .. "," .. tostring(anchor.z)
        end
    end
    table.sort(parts)
    return tostring(Config.tileRange()) .. ":" .. tostring(Config.verticalRange())
        .. ":" .. table.concat(parts, "|")
end

local originalSet = Anchor.set
local knownAnchors = {}
Anchor.set = function(id, anchor, on)
    local previous = knownAnchors[id]
    local current
    if on and anchor then
        current = { x = anchor.x, y = anchor.y, z = anchor.z, on = true }
    end
    local changed = (previous == nil) ~= (current == nil)
    if previous and current then
        changed = previous.x ~= current.x or previous.y ~= current.y or previous.z ~= current.z
    end

    local result = originalSet(id, anchor, on)
    knownAnchors[id] = current
    if changed and authority() and integrationActive() then
        coverageCaches[id] = nil
        pendingSweep = true
        pendingUrgent = true
    end
    return result
end

Events.OnInitGlobalModData.Add(function()
    if authority() and integrationActive() then
        coverageCaches = {}
        pendingSweep = true
    end
end)

Events.LoadChunk.Add(function(chunk)
    if not authority() or not chunk then return end
    local ok, cx, cy = pcall(Anchor.chunkCoords, chunk)
    if ok and type(cx) == "number" and type(cy) == "number" then
        -- LGEE already coalesces a sweep for chunk loads; only invalidate affected plans.
        invalidateCoverageChunk(cx, cy)
    elseif not ok then
        warnOnce("chunk", "Could not invalidate cached coverage after a chunk load.")
    end
end)

local function invalidateObjectCoverage(object)
    if not authority() or not object or not instanceof(object, "IsoGenerator") then return end
    local ok, x, y = pcall(function()
        local square = object:getSquare()
        if not square then return nil, nil end
        return square:getX(), square:getY()
    end)
    if ok and type(x) == "number" and type(y) == "number" then
        invalidateCoverageAt(x, y)
    elseif not ok then
        warnOnce("object", "Could not invalidate cached coverage after a world-object change.")
    end
end

Events.OnObjectAdded.Add(function(object)
    if not object or not instanceof(object, "IsoGenerator") then return end
    invalidateObjectCoverage(object)
    if authority() and type(EE.requestSweep) == "function" then
        EE.requestSweep("a generator was placed on cached LiveWire coverage")
    end
end)
Events.OnObjectAboutToBeRemoved.Add(invalidateObjectCoverage)

Events.OnProcessAction.Add(function(action, _, args)
    if action ~= "build" or not authority() or type(args) ~= "table" then
        return
    end
    local x, y = tonumber(args.x), tonumber(args.y)
    if x and y then invalidateCoverageAt(math.floor(x), math.floor(y)) end
end)

Events.OnTick.Add(function()
    if not authority() or not integrationActive() then return end
    pollTicks = pollTicks + 1
    if pollTicks >= 120 then
        pollTicks = 0
        local current = signature()
        if current and lastSignature and current ~= lastSignature then
            pendingSweep = true
            pendingUrgent = true
        end
        if current then lastSignature = current end
    end

    if pendingSweep and type(EE.requestSweep) == "function" then
        pendingSweep = false
        EE.requestSweep("LiveWire adapter coverage changed", pendingUrgent)
        pendingUrgent = false
    end
end)

if takeoverActive() and not supported() then
    warnOnce("api", "LG Extended Electricity takeover detected, but its coverage API is unsupported; LiveWire is using its original range behavior.")
end

Adapter.loaded = true
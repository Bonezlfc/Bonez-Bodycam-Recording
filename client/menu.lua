---@diagnostic disable: undefined-global, undefined-field, need-check-nil
-- bonez-bodycam_evidence | client/menu.lua
-- NativeUI menus: Evidence System root + Clip Detail sub-menu.

BodycamEvidenceMenu = {}

local menuPool    = nil
local mainMenu    = nil
local clipsMenu   = nil
local detailMenu  = nil

-- State for currently browsed data
local currentUnitId  = nil
local currentClips   = {}   -- received from server
local selectedClip   = nil  -- currently highlighted clip

-- ── Keyboard text input helper (uses FiveM onscreen keyboard) ──────────────
local function GetKeyboardInput(title, maxLen)
    AddTextEntry('BCE_INPUT', title)
    DisplayOnscreenKeyboard(1, 'BCE_INPUT', '', '', '', '', '', maxLen or 20)
    while UpdateOnscreenKeyboard() == 0 do
        DisableAllControlActions(0)
        Citizen.Wait(0)
    end
    EnableAllControlActions(0)
    if UpdateOnscreenKeyboard() == 1 then
        return GetOnscreenKeyboardResult()
    end
    return nil
end

-- ── Build / rebuild menus ──────────────────────────────────────────────────

local function BuildDetailMenu(clip)
    if not detailMenu then
        detailMenu = NativeUI.CreateMenu('Clip Detail', 'Unit ' .. tostring(clip.unitId or 'N/A'))
        menuPool:Add(detailMenu)
    else
        -- Clear existing items so we can repopulate for this clip
        detailMenu.Items      = {}
        detailMenu.ActiveItem = 1
    end

    local function MkInfo(label, value)
        local item = NativeUI.CreateItem(label, tostring(value or 'N/A'))
        item.Enabled = false
        detailMenu:AddItem(item)
    end

    MkInfo('Clip ID',    clip.clipId)
    MkInfo('Trigger',    clip.trigger)
    MkInfo('Date/Time',  FormatTimestamp(clip.startTime))
    MkInfo('Duration',   FormatDuration(clip.duration))
    MkInfo('Service',    clip.serviceType)
    MkInfo('Frames',     clip.totalFrames)
    MkInfo('Status',     clip.uploadStatus)

    local watchItem = NativeUI.CreateItem('Watch Footage', 'Stream clip in evidence viewer')
    detailMenu:AddItem(watchItem)

    local backItem = NativeUI.CreateItem('Back', 'Return to clips list')
    detailMenu:AddItem(backItem)

    detailMenu.OnItemSelect = function(sender, item, index)
        if item == watchItem then
            if clip.fivemanageUrl and clip.fivemanageUrl ~= '' then
                Viewer.Open(clip.fivemanageUrl, clip)
                menuPool:CloseAllMenus()
            else
                ShowNotification('~r~No footage URL available for this clip.')
            end
        elseif item == backItem then
            detailMenu:Visible(false)
            clipsMenu:Visible(true)
        end
    end
end

local function BuildClipsMenu()
    if not clipsMenu then
        clipsMenu = NativeUI.CreateMenu('Evidence Clips', 'Unit ' .. tostring(currentUnitId or '?'))
        menuPool:Add(clipsMenu)
    else
        clipsMenu.Items      = {}
        clipsMenu.ActiveItem = 1
    end

    if #currentClips == 0 then
        local emptyItem = NativeUI.CreateItem('No clips found.', 'No evidence clips stored for this unit.')
        emptyItem.Enabled = false
        clipsMenu:AddItem(emptyItem)
        return
    end

    for _, clip in ipairs(currentClips) do
        local label   = string.format('[%s] %s', clip.trigger or '?', ShortDate(clip.startTime))
        local sublabel = string.format('%s | %s | %s', FormatDuration(clip.duration), clip.serviceType or 'N/A', clip.uploadStatus or '?')
        local item = NativeUI.CreateItem(label, sublabel)
        clipsMenu:AddItem(item)
    end

    clipsMenu.OnItemHighlighted = function(sender, item, index)
        selectedClip = currentClips[index]
    end

    clipsMenu.OnItemSelect = function(sender, item, index)
        local clip = currentClips[index]
        if not clip then return end
        selectedClip = clip
        BuildDetailMenu(clip)
        clipsMenu:Visible(false)
        detailMenu:Visible(true)
    end
end

-- ── Initialise the main menu pool ─────────────────────────────────────────

local function InitMenus()
    menuPool = NativeUI.CreatePool()
    mainMenu = NativeUI.CreateMenu('Evidence System', 'San Andreas United — Court Evidence')
    menuPool:Add(mainMenu)

    -- Items
    local searchItem = NativeUI.CreateItem('Search by Unit ID', 'Enter a unit ID to retrieve clips')
    local browseItem = NativeUI.CreateItem('Browse Clips', 'List clips for searched unit')
    local watchItem  = NativeUI.CreateItem('Watch Selected Clip', 'Open evidence viewer for selected clip')
    local exportItem = NativeUI.CreateItem('Export Clip Info to Chat', 'Print selected clip metadata to chat')
    local deleteItem = NativeUI.CreateItem('[Admin] Delete Clip', 'Permanently delete selected clip (admin only)')
    local closeItem  = NativeUI.CreateItem('Close', 'Close the evidence system')

    mainMenu:AddItem(searchItem)
    mainMenu:AddItem(browseItem)
    mainMenu:AddItem(watchItem)
    mainMenu:AddItem(exportItem)
    mainMenu:AddItem(deleteItem)
    mainMenu:AddItem(closeItem)

    -- Item select handler
    mainMenu.OnItemSelect = function(sender, item, index)
        if item == searchItem then
            -- Close menu briefly to allow keyboard
            menuPool:CloseAllMenus()
            Citizen.SetTimeout(200, function()
                local input = GetKeyboardInput('Enter Unit ID', 10)
                if input and input ~= '' then
                    local uid = tonumber(input)
                    if uid then
                        currentUnitId = uid
                        currentClips  = {}
                        selectedClip  = nil
                        ShowNotification('~b~Searching for clips for unit ' .. uid .. '...')
                        TriggerServerEvent('bonez-bodycam_evidence:requestClips', uid)
                    else
                        ShowNotification('~r~Invalid unit ID. Must be a number.')
                    end
                end
                mainMenu:Visible(true)
            end)

        elseif item == browseItem then
            if not currentUnitId then
                ShowNotification('~y~Search for a unit ID first.')
                return
            end
            if #currentClips == 0 then
                ShowNotification('~y~No clips loaded. Search for a unit ID first, or wait for results.')
                return
            end
            BuildClipsMenu()
            mainMenu:Visible(false)
            clipsMenu:Visible(true)

        elseif item == watchItem then
            if not selectedClip then
                ShowNotification('~y~Select a clip from Browse Clips first.')
                return
            end
            if selectedClip.fivemanageUrl and selectedClip.fivemanageUrl ~= '' then
                Viewer.Open(selectedClip.fivemanageUrl, selectedClip)
                menuPool:CloseAllMenus()
            else
                ShowNotification('~r~No footage URL for this clip.')
            end

        elseif item == exportItem then
            if not selectedClip then
                ShowNotification('~y~Select a clip from Browse Clips first.')
                return
            end
            local c = selectedClip
            TriggerEvent('chat:addMessage', {
                color = {0, 200, 255},
                multiline = true,
                args = {
                    'EVIDENCE',
                    string.format(
                        'Clip: %s | Unit: %s | Trigger: %s | Date: %s | Duration: %s | Service: %s | Frames: %s | Status: %s',
                        c.clipId or 'N/A',
                        tostring(c.unitId or 'N/A'),
                        c.trigger or 'N/A',
                        FormatTimestamp(c.startTime),
                        FormatDuration(c.duration),
                        c.serviceType or 'N/A',
                        tostring(c.totalFrames or 0),
                        c.uploadStatus or 'N/A'
                    )
                }
            })

        elseif item == deleteItem then
            if not selectedClip then
                ShowNotification('~y~Select a clip from Browse Clips first.')
                return
            end
            TriggerServerEvent('bonez-bodycam_evidence:deleteClip', selectedClip.clipId)

        elseif item == closeItem then
            menuPool:CloseAllMenus()
        end
    end

    -- Render loop
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            menuPool:ProcessMenus()
            if menuPool:IsAnyMenuOpen() then
                -- NativeUI has already read keyboard inputs in ProcessMenus above.
                -- Now kill ALL controls so the camera cannot rotate, then restore
                -- only the movement inputs so the player can walk while browsing.
                DisableAllControlActions(0)
                EnableControlAction(0, 30, true)   -- Move Left/Right (A/D)
                EnableControlAction(0, 31, true)   -- Move Up/Down    (W/S)
                EnableControlAction(0, 21, true)   -- Sprint
                EnableControlAction(0, 22, true)   -- Jump
            end
        end
    end)
end

-- ── Event: receive clips from server ──────────────────────────────────────

RegisterNetEvent('bonez-bodycam_evidence:receiveClips')
AddEventHandler('bonez-bodycam_evidence:receiveClips', function(clips)
    currentClips = clips or {}
    selectedClip = nil
    local count  = #currentClips
    if count == 0 then
        ShowNotification('~y~No clips found for unit ' .. tostring(currentUnitId or '?') .. '.')
    else
        ShowNotification(string.format('~g~Found %d clip(s) for unit %s. Open Browse Clips.', count, tostring(currentUnitId or '?')))
    end
end)

-- ── Event: server confirms clip deleted ───────────────────────────────────

RegisterNetEvent('bonez-bodycam_evidence:clipDeleted')
AddEventHandler('bonez-bodycam_evidence:clipDeleted', function(clipId, success, reason)
    if success then
        ShowNotification('~g~Clip deleted: ' .. tostring(clipId))
        -- Remove from local list
        for i = #currentClips, 1, -1 do
            if currentClips[i].clipId == clipId then
                table.remove(currentClips, i)
            end
        end
        if selectedClip and selectedClip.clipId == clipId then
            selectedClip = nil
        end
    else
        ShowNotification('~r~Delete failed: ' .. tostring(reason or 'unknown error'))
    end
end)

-- ── Public API ─────────────────────────────────────────────────────────────

local menuInitialized = false

function BodycamEvidenceMenu.Init()
    if menuInitialized then return end
    menuInitialized = true
    InitMenus()
end

function BodycamEvidenceMenu.Open(bodycamOk, ersOk)
    -- Guard: init may not have run yet if the command fires before onClientResourceStart
    if not menuInitialized then
        BodycamEvidenceMenu.Init()
    end
    if not bodycamOk then
        ShowNotification('~r~BODYCAM NOT DETECTED. bonez-bodycam must be running.')
        return
    end
    if not ersOk then
        ShowNotification('~r~ERS NOT DETECTED. night_ers must be running.')
        return
    end
    mainMenu:Visible(true)
end

-- ── Utility ────────────────────────────────────────────────────────────────

function ShowNotification(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

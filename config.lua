-- bonez-bodycam_evidence | config.lua
-- Shared configuration. API keys → server/apiKeys.lua (server-side only).

Config = {}

-- ── Debug ──────────────────────────────────────────────────────────────────
-- Set to true to print state transitions and upload events to the F8 / txAdmin console.
-- Leave false on production.
Config.Debug = false

-- ── Keybind ────────────────────────────────────────────────────────────────
Config.DefaultKey   = 'F9'       -- Default key for /evidence command (rebindable in FiveM Settings)
Config.MenuCommand  = 'evidence' -- In-game chat command to open the evidence system

-- ── ERS polling ────────────────────────────────────────────────────────────
Config.ERSPollInterval = 500  -- ms between night_ers state polls

-- ── Recording triggers ─────────────────────────────────────────────────────
Config.TrackingCooldown   = 60  -- seconds of cooldown after tracking ends before finalizing (Trigger 2)
Config.WeaponClipDuration = 60  -- seconds a weapon-fired clip records before auto-stopping (Trigger 3)

-- ── Clip storage ───────────────────────────────────────────────────────────
Config.ClipsPerUnit = 20  -- max clips stored per unit ID; oldest are deleted when exceeded

-- ── Job permissions (validated server-side only) ───────────────────────────
-- Any player whose framework job name matches a value here can view evidence.
Config.AuthorizedJobs = {
    'police',   -- replace with your framework's job name(s)
    'da',
}

-- Admin jobs — can delete clips in addition to viewing.
-- txAdmin / server ACE 'command' permission always grants admin access regardless.
Config.AdminJobs = {
    'admin',    -- replace with your framework's admin job name(s)
}

-- ── Unit identifier ────────────────────────────────────────────────────────
-- Which player identifier to tag clips with and search by in the hub.
-- The prefix is stripped before storing, so 'fivem:787929' is stored as '787929'.
--
--   'fivem'   — CFX.re account number  (e.g. 787929)       ← recommended, short & easy to type
--   'license' — Rockstar license key   (e.g. f02e5e4aba…)
--   'discord' — Discord user ID        (e.g. 313541362806947842)
--   'steam'   — Steam hex ID           (e.g. 1100001096ff9a3)
--   'xbl'     — Xbox Live ID
--   'live'    — Microsoft Live ID
Config.UnitIdentifierType = 'discord'

-- ── Service type resolver ───────────────────────────────────────────────────
-- Returns a string label for the officer's current service/department.
-- This is stored with every clip for evidence records.
--
-- Pick ONE option and uncomment it. Delete the others.
Config.GetServiceType = function()

    -- Option A — Static value (simplest). Replace with your department name.
    return 'YOUR_DEPARTMENT'

    -- Option B — ESX job label
    -- local ESX = exports['es_extended']:getSharedObject()
    -- local ply = ESX.GetPlayerData()
    -- return (ply and ply.job and ply.job.label) or 'UNKNOWN'

    -- Option C — QBCore job label
    -- local QBCore = exports['qb-core']:GetCoreObject()
    -- local ply = QBCore.Functions.GetPlayerData()
    -- return (ply and ply.job and ply.job.label) or 'UNKNOWN'

    -- Option D — night_ers service type export
    -- local ok, svc = pcall(function() return exports['night_ers']:getServiceType() end)
    -- return (ok and svc) or 'UNKNOWN'

end

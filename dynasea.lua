addon.name      = 'dynasea';
addon.author    = 'Kalrir';
addon.version   = '1.1';
addon.desc      = 'A Dynamis Zone Search GUI for Ashita v4 for use on the HorizonXI Private Server.';

_G._XIUI_USE_ASHITA_4_3 = false;
require('imgui_compat');

local imgui = require('imgui');
require('common');

local showGui = { true };

-- =========================
-- Zones / Keys
-- =========================
local ZONE_KEYS = {
    'sandoria','bastok','windurst','jeuno',
    'beau','xarc','valkurm','bub','qufim','tav',
};

-- =========================
-- Saved fields
-- =========================
local zoneCounts = {
    sandoria='--', bastok='--', windurst='--', jeuno='--',
    beau='--', xarc='--', valkurm='--', bub='--', qufim='--', tav='--',
};

local zoneExitTime = {
    sandoria='', bastok='', windurst='', jeuno='',
    beau='', xarc='', valkurm='', bub='', qufim='', tav='',
};

local pendingZoneKey = nil;

-- =========================
-- Settings persistence
-- =========================
local settingsPath = (addon.path or '') .. 'dynasea_settings.lua';

local function EscapeLuaString(s)
    s = tostring(s or '');
    return s:gsub('\\','\\\\'):gsub('\r','\\r'):gsub('\n','\\n'):gsub('"','\\"');
end

local function SaveSettings()
    local f = io.open(settingsPath, 'w');
    if not f then return end
    f:write('return {\n  counts = {\n');
    for _,k in ipairs(ZONE_KEYS) do
        f:write(string.format('    %s = "%s",\n', k, EscapeLuaString(zoneCounts[k])));
    end
    f:write('  },\n  exitTime = {\n');
    for _,k in ipairs(ZONE_KEYS) do
        f:write(string.format('    %s = "%s",\n', k, EscapeLuaString(zoneExitTime[k])));
    end
    f:write('  },\n}\n');
    f:close();
end

local function LoadSettings()
    local ok, data = pcall(dofile, settingsPath);
    if not ok or type(data) ~= 'table' then return end
    if type(data.counts) == 'table' then
        for _,k in ipairs(ZONE_KEYS) do
            if data.counts[k] ~= nil then zoneCounts[k] = tostring(data.counts[k]); end
        end
    end
    if type(data.exitTime) == 'table' then
        for _,k in ipairs(ZONE_KEYS) do
            if data.exitTime[k] ~= nil then zoneExitTime[k] = tostring(data.exitTime[k]); end
        end
    end
end

local function ResetAll()
    for _,k in ipairs(ZONE_KEYS) do
        zoneCounts[k] = '--';
        zoneExitTime[k] = '';
    end
    pendingZoneKey = nil;
    SaveSettings();
end

LoadSettings();

-- =========================
-- Cursor workaround (unchanged)
-- =========================
local holdGuiUntilMouseMoves = false;
local holdStartTime = 0.0;
local holdTimeoutSec = 2.5;
local lastMouseX, lastMouseY = nil, nil;

local function GetMousePosSafe()
    local ok,x,y = pcall(function()
        local p = imgui.GetMousePos();
        if type(p) == 'table' then return p[1] or p.x, p[2] or p.y end
        return p, select(2, imgui.GetMousePos());
    end);
    if not ok or type(x)~='number' or type(y)~='number' then return nil,nil end
    return x,y;
end

local function BeginHoldUntilMouseMoves()
    holdGuiUntilMouseMoves = true;
    holdStartTime = os.clock();
    lastMouseX, lastMouseY = GetMousePosSafe();
end

local function ShouldReleaseHold()
    if not holdGuiUntilMouseMoves then return true end
    if os.clock() - holdStartTime >= holdTimeoutSec then
        holdGuiUntilMouseMoves = false; return true;
    end
    local x,y = GetMousePosSafe();
    if x and y and lastMouseX and lastMouseY and (x~=lastMouseX or y~=lastMouseY) then
        holdGuiUntilMouseMoves = false; return true;
    end
    return false;
end

-- =========================
-- UI helpers
-- =========================
local function DrawHeaderRow(title)
    imgui.Columns(3,nil,false);
    imgui.SetColumnWidth(1,70);
    imgui.SetColumnWidth(2,110);
    imgui.Text(title); imgui.NextColumn();
    imgui.Text('Players:'); imgui.NextColumn();
    imgui.Text('Exit Time:');
    imgui.Columns(1); imgui.Separator();
end

local function DrawZoneRow(label, cmd, key)
    imgui.Columns(3,nil,false);
    imgui.SetColumnWidth(1,70);
    imgui.SetColumnWidth(2,110);

    if imgui.Button(label,{ -1,0 }) then
        pendingZoneKey = key;
        zoneCounts[key] = '...';
        SaveSettings();
        BeginHoldUntilMouseMoves();
        AshitaCore:GetChatManager():ExecuteScriptString(
            '/sendkey esc down;/sendkey esc up;/releasekeys;/wait 0.2;' .. cmd,'',true);
    end

    imgui.NextColumn(); imgui.Text(zoneCounts[key]);
    imgui.NextColumn();
    imgui.PushItemWidth(-1);
    local buf = { zoneExitTime[key] };
    if imgui.InputText('##exit_'..key, buf, 24) then
        zoneExitTime[key] = buf[1]; SaveSettings();
    end
    imgui.PopItemWidth();
    imgui.Columns(1);
end

-- =========================
-- Main window
-- =========================
local function DrawGui()
    imgui.SetNextWindowSize({500,500}, ImGuiCond_FirstUseEver);

    if imgui.Begin('DynaSea Version 1.1', showGui) then
        DrawHeaderRow('Cities:');
        DrawZoneRow('Sand D\'oria','/sea "Dynamis - San d\'Oria"','sandoria'); imgui.Separator();
        DrawZoneRow('Bastok','/sea "Dynamis - Bastok"','bastok'); imgui.Separator();
        DrawZoneRow('Windurst','/sea "Dynamis - Windurst"','windurst'); imgui.Separator();
        DrawZoneRow('Jeuno','/sea "Dynamis - Jeuno"','jeuno'); imgui.Separator();

        imgui.Spacing();

        DrawHeaderRow('Outlands:');
        DrawZoneRow('Beaucedine','/sea "Dynamis - Beaucedine"','beau'); imgui.Separator();
        DrawZoneRow('Xarcabard','/sea "Dynamis - Xarcabard"','xarc'); imgui.Separator();
        DrawZoneRow('Valkurm','/sea "Dynamis - Valkurm"','valkurm'); imgui.Separator();
        DrawZoneRow('Buburimu','/sea "Dynamis - Buburimu"','bub'); imgui.Separator();
        DrawZoneRow('Qufim','/sea "Dynamis - Qufim"','qufim'); imgui.Separator();
        DrawZoneRow('Tavnazia','/sea "Dynamis - Tavnazia"','tav'); imgui.Separator();

        imgui.Spacing(); imgui.Separator();

        -- Commands (left) + Reset (right) on same line
        imgui.Text('Commands: /dynasea or /ds to toggle');
        imgui.SameLine();

        local bw = 120;
        imgui.SetCursorPosX(imgui.GetWindowWidth() - bw - 16);
        if imgui.Button('Reset',{bw,0}) then ResetAll(); end
    end

    imgui.End();
end

-- =========================
-- Events
-- =========================
ashita.events.register('d3d_present','dynasea_present_cb',function()
    if holdGuiUntilMouseMoves and not ShouldReleaseHold() then return end
    if showGui[1] then DrawGui(); end
end);

ashita.events.register('command','dynasea_command_cb',function(e)
    local a = e.command:lower():args();
    if #a>0 and (a[1]=='/dynasea' or a[1]=='/ds') then
        e.blocked=true; showGui[1]=not showGui[1];
    end
end);

ashita.events.register('text_in','dynasea_textin_cb',function(e)
    local msg = e.message or e.text or '';
    local c = msg:match('Search result:%s*(%d+)%s*people found in this area%.');
    if c and pendingZoneKey then
        zoneCounts[pendingZoneKey] = (tonumber(c)==0) and 'Open' or tostring(c);
        pendingZoneKey=nil; SaveSettings();
    end
end);

ashita.events.register('unload','dynasea_unload_cb',function()
    SaveSettings();
end);

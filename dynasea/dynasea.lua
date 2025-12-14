addon.name      = 'dynasea';
addon.author    = 'Kalrir';
addon.version   = '1.0';
addon.desc      = 'A Dynamis Scanner GUI for Ashita v4';

_G._XIUI_USE_ASHITA_4_3 = false;
require('imgui_compat');

local imgui = require('imgui');
require('common');

local showGui = { true };

-- =========================
-- Data
-- =========================

local zoneCounts = {
    sandoria = '--',
    bastok   = '--',
    windurst = '--',
    jeuno    = '--',
    beau     = '--',
    xarc     = '--',
    valkurm  = '--',
    bub      = '--',
    qufim    = '--',
    tav      = '--',
};

local zoneOutTime = {
    sandoria = '',
    bastok   = '',
    windurst = '',
    jeuno    = '',
    beau     = '',
    xarc     = '',
    valkurm  = '',
    bub      = '',
    qufim    = '',
    tav      = '',
};

local pendingZoneKey = nil;

-- =========================
-- Cursor workaround
-- (hide GUI until mouse moves or timeout)
-- =========================

local holdGuiUntilMouseMoves = false;
local holdStartTime = 0.0;
local holdTimeoutSec = 2.5;
local lastMouseX = nil;
local lastMouseY = nil;

local function GetMousePosSafe()
    local ok, x, y = pcall(function()
        local pos = imgui.GetMousePos();
        if type(pos) == 'table' then
            return pos[1] or pos.x, pos[2] or pos.y;
        end
        return pos, select(2, imgui.GetMousePos());
    end);

    if not ok or type(x) ~= 'number' or type(y) ~= 'number' then
        return nil, nil;
    end
    return x, y;
end

local function BeginHoldUntilMouseMoves()
    holdGuiUntilMouseMoves = true;
    holdStartTime = os.clock();
    lastMouseX, lastMouseY = GetMousePosSafe();
end

local function ShouldReleaseHold()
    if not holdGuiUntilMouseMoves then
        return true;
    end

    if (os.clock() - holdStartTime) >= holdTimeoutSec then
        holdGuiUntilMouseMoves = false;
        return true;
    end

    local x, y = GetMousePosSafe();
    if x and y and lastMouseX and lastMouseY then
        if x ~= lastMouseX or y ~= lastMouseY then
            holdGuiUntilMouseMoves = false;
            return true;
        end
    end

    return false;
end

-- =========================
-- UI helpers
-- =========================

local function DrawHeaderRow(leftLabel)
    imgui.Columns(3, nil, false);
    imgui.SetColumnWidth(1, 70); -- Players
    imgui.SetColumnWidth(2, 90); -- Out Time

    imgui.Text(leftLabel or ''); -- "Cities:" / "Outlands:"
    imgui.NextColumn();
    imgui.Text('Players:');
    imgui.NextColumn();
    imgui.Text('Exit Time:');

    imgui.Columns(1);
    imgui.Separator();
end

local function DrawZoneRow(label, seaCmd, key)
    imgui.Columns(3, nil, false);
    imgui.SetColumnWidth(1, 70);
    imgui.SetColumnWidth(2, 90);

    -- Zone button (left column)
    if imgui.Button(label, { -1, 0 }) then
        pendingZoneKey = key;
        zoneCounts[key] = '...';

        -- Cursor workaround: hide until mouse moves
        BeginHoldUntilMouseMoves();

        -- Close any open menu, wait, then run /sea
        AshitaCore:GetChatManager():ExecuteScriptString(
            '/sendkey esc down;' ..
            '/sendkey esc up;' ..
            '/releasekeys;' ..
            '/wait 0.2;' ..
            seaCmd,
            '',
            true
        );
    end

    -- Players column
    imgui.NextColumn();
    imgui.Text(tostring(zoneCounts[key] or '--'));

    -- Out Time column (editable)
    imgui.NextColumn();
    imgui.PushItemWidth(-1);
    local buf = { zoneOutTime[key] or '' };
    if imgui.InputText('##outtime_' .. key, buf, 16) then
        zoneOutTime[key] = buf[1];
    end
    imgui.PopItemWidth();

    imgui.Columns(1);
end

-- =========================
-- Main window
-- =========================

local function DrawGui()
    imgui.SetNextWindowSize({ 460, 480 }, ImGuiCond_FirstUseEver);

    if imgui.Begin('DynaSea Version 1.0', showGui) then
        -- Cities section
        DrawHeaderRow('Cities:');

        DrawZoneRow('Sand D\'oria', '/sea "Dynamis - San d\'Oria"', 'sandoria'); imgui.Separator();
        DrawZoneRow('Bastok',      '/sea "Dynamis - Bastok"',      'bastok');   imgui.Separator();
        DrawZoneRow('Windurst',    '/sea "Dynamis - Windurst"',    'windurst'); imgui.Separator();
        DrawZoneRow('Jeuno',       '/sea "Dynamis - Jeuno"',       'jeuno');    imgui.Separator();
        DrawZoneRow('Tavnazia',    '/sea "Dynamis - Tavnazia"',    'tav');      imgui.Separator();

        imgui.Spacing();

        -- Outlands section
        DrawHeaderRow('Outlands:');

        DrawZoneRow('Beaucedine',  '/sea "Dynamis - Beaucedine"',  'beau');     imgui.Separator();
        DrawZoneRow('Xarcabard',   '/sea "Dynamis - Xarcabard"',   'xarc');     imgui.Separator();
        DrawZoneRow('Valkurm',     '/sea "Dynamis - Valkurm"',     'valkurm');  imgui.Separator();
        DrawZoneRow('Buburimu',    '/sea "Dynamis - Buburimu"',    'bub');      imgui.Separator();
        DrawZoneRow('Qufim',       '/sea "Dynamis - Qufim"',       'qufim');    imgui.Separator();

        imgui.Spacing();
        imgui.Text('Commands: /dynasea or /ds to toggle');
    end

    imgui.End();
end

-- =========================
-- Events
-- =========================

ashita.events.register('d3d_present', 'dynasea_present_cb', function ()
    if holdGuiUntilMouseMoves and not ShouldReleaseHold() then
        return;
    end

    if showGui[1] then
        DrawGui();
    end
end);

ashita.events.register('command', 'dynasea_command_cb', function (e)
    local args = e.command:lower():args();
    if #args > 0 and (args[1] == '/dynasea' or args[1] == '/ds') then
        e.blocked = true;
        showGui[1] = not showGui[1];
    end
end);

-- Parse: "Search result: X people found in this area."
ashita.events.register('text_in', 'dynasea_textin_cb', function (e)
    local msg = e.message or e.text or '';
    if msg == '' then return; end

    local count = msg:match('Search result:%s*(%d+)%s*people found in this area%.');
    if count ~= nil and pendingZoneKey ~= nil then
        if tonumber(count) == 0 then
            zoneCounts[pendingZoneKey] = 'Open';
        else
            zoneCounts[pendingZoneKey] = tostring(count);
        end
        pendingZoneKey = nil;
    end
end);

ashita.events.register('unload', 'dynasea_unload_cb', function ()
    ashita.events.unregister('d3d_present', 'dynasea_present_cb');
    ashita.events.unregister('command', 'dynasea_command_cb');
    ashita.events.unregister('text_in', 'dynasea_textin_cb');
end);

script_name('Sawnoff')
script_author('sakuta')
script_version('2.4')

-- Подключение библиотек
local se = require 'lib.samp.events'
local imgui = require 'mimgui'
local inicfg = require 'inicfg'
local encoding = require 'encoding'
local dlstatus = require('moonloader').download_status
encoding.default = 'CP1251'
u8 = encoding.UTF8

-- Загрузка конфигурации
local cfg = inicfg.load({
	settings = {
		auto_start = false,
		connected = false,
		auto_swap = false,
        auto_cycle_cd = false,
		alt_model_id = 3166,
        sawnoffId = 5822,
		auto_update = true,
        dbg = false
	}
}, 'sawnoff')

if not doesFileExist('sawnoff.ini') then
    inicfg.save(cfg, 'sawnoff.ini')
end

-- Глобальные переменные
local sawnoff = { [4] = false, [5] = false }
local alt = {_, _, _, false, false}
local inventory = {}
local sw, sh = getScreenResolution()
local main_window = imgui.new.bool()
local work = false
local first_start = true
local delay_time = nil
local inventory_fix = false
local cycle_thread_running = false
local swap_thread_running = false

-- Кэшированные слоты
local cached_sawnoff_slot = nil
local cached_sawnoff_type = nil
local cached_alt_slot = nil
local cached_alt_type = nil

-- Настройки ImGui
local auto_start = imgui.new.bool(cfg.settings.auto_start)
local connected = cfg.settings.connected
local auto_swap = imgui.new.bool(cfg.settings.auto_swap)
local alt_model_id = imgui.new.int(cfg.settings.alt_model_id)
local sawnoffId = imgui.new.int(cfg.settings.sawnoffId)
local auto_cycle_cd = imgui.new.bool(cfg.settings.auto_cycle_cd)
local auto_update = imgui.new.bool(cfg.settings.auto_update)
local debug_mode = imgui.new.bool(cfg.settings.dbg)

if auto_swap[0] and auto_cycle_cd[0] then
	auto_cycle_cd[0] = false
	cfg.settings.auto_cycle_cd = false
	inicfg.save(cfg, 'sawnoff.ini')
end

-- ========================== ОБНОВЛЕНИЕ ==========================
local update_version = nil
local update_url = nil
local update_available = false
local update_notified = false
local update_check_running = false

local function checkForUpdate(manual)
    if update_check_running then return end
    update_check_running = true
    lua_thread.create(function()
        local json_url = "https://raw.githubusercontent.com/HentaikaZ/sawnoff/refs/heads/main/autoupdate.json"
        local json_path = getWorkingDirectory() .. '\\' .. thisScript().name .. '-version.json'
        if doesFileExist(json_path) then os.remove(json_path) end
        downloadUrlToFile(json_url, json_path, function(id, status, p1, p2)
            if status == dlstatus.STATUSEX_ENDDOWNLOAD then
                if doesFileExist(json_path) then
                    local f = io.open(json_path, 'r')
                    if f then
                        local content = f:read('*a')
                        f:close()
                        os.remove(json_path)
                        -- Используем встроенный decodeJson
                        local success, info = pcall(decodeJson, content)
                        if success and info and info.latest and info.updateurl then
                            local latest = info.latest
                            local update_link = info.updateurl
                            update_version = latest
                            update_url = update_link
                            if latest ~= thisScript().version then
                                update_available = true
                                if manual then
                                    sampAddChatMessage(string.format('[Обновление] {FFFFFF}Доступна новая версия {FF6347}%s{FFFFFF}. Начинаю обновление...', latest), 0x96FF00)
                                    lua_thread.create(function()
                                        wait(250)
                                        downloadUrlToFile(update_link, thisScript().path,
                                            function(id3, status1, p13, p23)
                                                if status1 == dlstatus.STATUS_DOWNLOADINGDATA then
                                                    print(string.format('Скачано %d из %d.', p13, p23))
                                                elseif status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
                                                    print('Обновление успешно завершено.')
                                                    sampAddChatMessage('[Обновление] {FFFFFF}Обновление установлено!', 0x96FF00)
                                                    lua_thread.create(function() wait(500) thisScript():reload() end)
                                                end
                                            end
                                        )
                                    end)
                                else
                                    if auto_update and auto_update[0] then
                                        sampAddChatMessage(string.format('[Обновление] {FFFFFF}Доступна новая версия {FF6347}%s{FFFFFF}. Обновляю...', latest), 0x96FF00)
                                        lua_thread.create(function()
                                            wait(250)
                                            downloadUrlToFile(update_link, thisScript().path,
                                                function(id3, status1, p13, p23)
                                                    if status1 == dlstatus.STATUS_DOWNLOADINGDATA then
                                                        print(string.format('Скачано %d из %d.', p13, p23))
                                                    elseif status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
                                                        print('Обновление успешно завершено.')
                                                        sampAddChatMessage('[Обновление] {FFFFFF}Обновление установлено!', 0x96FF00)
                                                        lua_thread.create(function() wait(500) thisScript():reload() end)
                                                    end
                                                end
                                            )
                                        end)
                                    else
                                        if not update_notified then
                                            sampAddChatMessage('[Обновление] {FFFFFF}Доступно обновление. Нажмите "Проверить обновления" для установки.', 0x96FF00)
                                            update_notified = true
                                        end
                                    end
                                end
                            else
                                update_available = false
                                if manual then
                                    sampAddChatMessage('[Обновление] {FFFFFF}У вас установлена последняя версия.', 0x96FF00)
                                end
                            end
                        else
                            sampAddChatMessage('[Обновление] {FF6347}Ошибка проверки обновлений. Повторите позже.', 0x96FF00)
                        end
                    end
                end
            elseif status == dlstatus.STATUSEX_ABORTED then
                sampAddChatMessage('[Обновление] {FF6347}Процесс обновления отменён.', 0x96FF00)
            end
            update_check_running = false
        end)
    end)
end

-- ======================== ФУНКЦИИ РАБОТЫ С ИНВЕНТАРЁМ ========================
function send_cef(str)
	if not str or type(str) ~= 'string' or #str == 0 then return end
	local bs = raknetNewBitStream()
	if not bs then return end
	pcall(function()
		raknetBitStreamWriteInt8(bs, 220)
		raknetBitStreamWriteInt8(bs, 18)
		raknetBitStreamWriteInt16(bs, #str)
		raknetBitStreamWriteString(bs, str)
		raknetBitStreamWriteInt32(bs, 0)
		raknetSendBitStream(bs)
	end)
	raknetDeleteBitStream(bs)
end

local function isEquippedItemData(data)
    return data and tonumber(data.type) == 2
end

local function clickSawnoffSlot(slot, data)
    local click_slot = isEquippedItemData(data) and slot or 3
    send_cef('clickOnButton|{"type": 2,"slot": ' .. tostring(click_slot) .. ', "action": 1}')
end

function findItemById(inventory, item_id)
	if not inventory or type(inventory) ~= 'table' or not item_id or item_id <= 0 then 
		return nil, nil 
	end
	for slot, data in pairs(inventory) do
		if data and type(data) == 'table' and data.item == item_id then
			return slot, data
		end
	end
	return nil, nil
end

function FindAltItem(inventory, alt_model_id)
	if not inventory or type(inventory) ~= 'table' or not alt_model_id or alt_model_id <= 0 then 
		return nil, nil 
	end
	for slot, data in pairs(inventory) do
		if data and type(data) == 'table' and data.item == alt_model_id then
			return slot, data
		end
	end
	return nil, nil
end

local function updateCachedSlots()
    if sawnoffId and sawnoffId[0] and sawnoffId[0] > 0 then
        local slot, data = findItemById(inventory, sawnoffId[0])
        if slot then
            cached_sawnoff_slot = slot
            cached_sawnoff_type = data and data.type or nil
            if debug_mode and debug_mode[0] then
                sampAddChatMessage(string.format("[Отладка] Слот обреза: %d, тип: %s", slot, cached_sawnoff_type == 2 and "надет" or "в инвентаре"), 0x96FF00)
            end
        else
            cached_sawnoff_slot = nil
            cached_sawnoff_type = nil
        end
    end
    if alt_model_id and alt_model_id[0] and alt_model_id[0] > 0 then
        local slot, data = FindAltItem(inventory, alt_model_id[0])
        if slot then
            cached_alt_slot = slot
            cached_alt_type = data and data.type or nil
            if debug_mode and debug_mode[0] then
                sampAddChatMessage(string.format("[Отладка] Слот альт-предмета: %d, тип: %s", slot, cached_alt_type == 2 and "надет" or "в инвентаре"), 0x96FF00)
            end
        else
            cached_alt_slot = nil
            cached_alt_type = nil
        end
    end
end

-- Парсинг JSON строки (без cjson)
local function parseInventoryPacket(json_str)
    if not json_str or json_str == "" then return false end
    local success, data = pcall(decodeJson, json_str)
    if not success or not data then return false end

    if data.event == "inventory.playerInventory" and data.data then
        local inv_data = data.data
        if type(inv_data) == "table" then
            for _, inv_type_data in ipairs(inv_data) do
                local inv_type = inv_type_data.type
                local items = inv_type_data.items
                if items and type(items) == "table" then
                    for _, item in ipairs(items) do
                        local slot = tonumber(item.slot)
                        if slot then
                            if item.item then
                                local item_id = tonumber(item.item)
                                if item_id then
                                    inventory[slot] = {
                                        slot = slot,
                                        type = inv_type,
                                        available = item.available,
                                        item = item_id,
                                        amount = item.amount or 1
                                    }
                                end
                            else
                                inventory[slot] = nil
                            end
                        end
                    end
                end
            end
            updateCachedSlots()
            return true
        end
    end
    return false
end

local function readCefStringFromPacket(bs)
    if not bs then return nil end
    local ok, str = pcall(function()
        raknetBitStreamIgnoreBits(bs, 8)
        if raknetBitStreamReadInt8(bs) ~= 17 then return nil end
        raknetBitStreamIgnoreBits(bs, 32)
        local length = raknetBitStreamReadInt16(bs)
        local encoded = raknetBitStreamReadInt8(bs)
        if encoded ~= 0 then
            return raknetBitStreamDecodeString(bs, length + encoded)
        end
        return raknetBitStreamReadString(bs, length)
    end)
    if ok then return str end
    return nil
end

function onReceivePacket(id, bs)
    if id == 220 then
        local json_str = readCefStringFromPacket(bs)
        if json_str then
            if debug_mode and debug_mode[0] then
                sampAddChatMessage("[Отладка] Получен CEF: " .. json_str:sub(1, 200), 0x96FF00)
            end
            parseInventoryPacket(json_str)
        end
    end

    if id == 31 or id == 32 or id == 33 or id == 12 or id == 35 or id == 36 or id == 37 then
        inventory = {}
        cached_sawnoff_slot = nil
        cached_alt_slot = nil
        cfg.settings.connected = false
        inicfg.save(cfg, 'sawnoff.ini')
        if work then work = false end
    elseif id == 34 then
        inventory = {}
        cached_sawnoff_slot = nil
        cached_alt_slot = nil
        cfg.settings.connected = true
        inicfg.save(cfg, 'sawnoff.ini')
        if auto_start and auto_start[0] then
            lua_thread.create(function() 
                repeat wait(0) until sampIsLocalPlayerSpawned() and sampGetGamestate() == 3
                wait(2000)
                if cfg.settings.connected then
                    if not work then
                        work = true
                        sampAddChatMessage('[Sawnoff] {FFFFFF}Автоматический режим работы: {42B02C}включён{FFFFFF}.', 0x96FF00)
                        if auto_swap and auto_swap[0] then startAutoSwapThread() end
                        if auto_cycle_cd and auto_cycle_cd[0] and not cycle_thread_running then startCycleWithCD() end
                    end
                end
            end)
        end
    end
end

-- ======================== ОСНОВНЫЕ ФУНКЦИИ ========================
local function isPayDayBlocked()
    local t = os.date('*t')
    local min = t.min
    return (min >= 28 and min <= 31) or (min >= 58 or min <= 1)
end

local function getPayDayUnlockTime()
    local t = os.date('*t')
    local min = t.min
    local sec = t.sec
    if min >= 28 and min <= 31 then
        return math.max(0, (32 - min) * 60 - sec)
    elseif min >= 58 then
        return math.max(0, (60 - min) * 60 - sec + 2 * 60)
    elseif min <= 1 then
        return math.max(0, (2 - min) * 60 - sec)
    end
    return 0
end

local function startCycleWithCD()
    if cycle_thread_running then return end
    if not auto_cycle_cd or not auto_cycle_cd[0] then return end
    cycle_thread_running = true
    lua_thread.create(function()
        while work and auto_cycle_cd and auto_cycle_cd[0] do
            if isPayDayBlocked() then
                local wait_time = getPayDayUnlockTime()
                sampAddChatMessage(string.format('[Sawnoff] {FFFFFF}Цикл приостановлен из-за PayDay! Ждите {FF6347}%d сек.', wait_time), 0x96FF00)
                wait(wait_time * 1000)
            end
            sampSendChat('/invent')
            wait(500)
            updateCachedSlots()
            if cached_sawnoff_slot then
                local sawnoff_data = inventory[cached_sawnoff_slot]
                if cached_sawnoff_slot ~= 3 and not isEquippedItemData(sawnoff_data) then
                    repeat
                        wait(333)
                        updateCachedSlots()
                        sawnoff_data = cached_sawnoff_slot and inventory[cached_sawnoff_slot] or nil
                    until cached_sawnoff_slot or not work
                end
                if cached_sawnoff_slot and (cached_sawnoff_slot == 3 or isEquippedItemData(sawnoff_data)) then
                    clickSawnoffSlot(cached_sawnoff_slot, sawnoff_data)
                    sawnoff[5] = true
                    delay_time = nil
                    local wait_start = os.time()
                    repeat wait(100) until delay_time ~= nil or not work or os.time() - wait_start > 10
                    if delay_time == nil then delay_time = 60 end
                elseif cached_sawnoff_slot then
                    send_cef('inventory.moveItemForce|{"slot": ' .. tostring(cached_sawnoff_slot) .. ', "type": 1, "amount": 1}')
                    wait(333)
                    clickSawnoffSlot(cached_sawnoff_slot, sawnoff_data)
                    sawnoff[5] = true
                    delay_time = nil
                    local wait_start = os.time()
                    repeat wait(100) until delay_time ~= nil or not work or os.time() - wait_start > 10
                    if delay_time == nil then delay_time = 60 end
                end
            end
            wait(444)
            if cached_alt_slot then
                local alt_data = inventory[cached_alt_slot]
                if cached_alt_slot ~= 3 and not isEquippedItemData(alt_data) then
                    send_cef('inventory.moveItemForce|{"slot": ' .. tostring(cached_alt_slot) .. ', "type": 1, "amount": 1}')
                    wait(222)
                end
                sampAddChatMessage('[Sawnoff] {FFFFFF}Альт-предмет надет. [CEF]', 0x96FF00)
                send_cef('inventoryClose')
            else
                sampAddChatMessage('[Sawnoff] {FF6347}Альт-предмет не найден. [CEF]', 0x96FF00)
            end
            if delay_time then
                local wait_minutes = tonumber(delay_time) or 60
                sampAddChatMessage(string.format('[Sawnoff] {FFFFFF}Ожидание: {FFD700}%d {FFFFFF}минут.', wait_minutes), 0x96FF00)
                local total_wait = wait_minutes * 60000
                local elapsed = 0
                local check_interval = 5000
                while elapsed < total_wait and work and auto_cycle_cd and auto_cycle_cd[0] do
                    if isPayDayBlocked() then
                        local wait_time = getPayDayUnlockTime()
                        sampAddChatMessage(string.format('[Sawnoff] {FFFFFF}Цикл приостановлен из-за PayDay! Ждите {FF6347}%d сек.', wait_time), 0x96FF00)
                        wait(wait_time * 1000)
                        elapsed = 0
                    else
                        wait(math.min(check_interval, total_wait - elapsed))
                        elapsed = elapsed + check_interval
                    end
                end
                delay_time = nil
            else
                sampAddChatMessage('[Sawnoff] {FFFFFF}КД не получен, жду 60 минут.', 0x96FF00)
                local total_wait = 60 * 60000
                local elapsed = 0
                local check_interval = 5000
                while elapsed < total_wait and work and auto_cycle_cd and auto_cycle_cd[0] do
                    if isPayDayBlocked() then
                        local wait_time = getPayDayUnlockTime()
                        sampAddChatMessage(string.format('[Sawnoff] {FFFFFF}Цикл приостановлен из-за PayDay! Ждите {FF6347}%d сек.', wait_time), 0x96FF00)
                        wait(wait_time * 1000)
                        elapsed = 0
                    else
                        wait(math.min(check_interval, total_wait - elapsed))
                        elapsed = elapsed + check_interval
                    end
                end
            end
            if not work or not auto_cycle_cd or not auto_cycle_cd[0] then
                break
            end
        end
        cycle_thread_running = false
    end)
end

function startAutoSwapThread()
    if swap_thread_running then return end
    if not auto_swap or not auto_swap[0] then return end
    swap_thread_running = true
    lua_thread.create(function()
        while work and auto_swap and auto_swap[0] do
            local t = os.date('*t')
            local secs_now = t.min * 60 + t.sec
            local target1 = 28 * 60
            local target2 = 58 * 60
            local diff1 = (target1 - secs_now) % 3600
            local diff2 = (target2 - secs_now) % 3600
            local wait_secs = math.min(diff1, diff2)
            wait(wait_secs * 1000)
            if not work or not auto_swap or not auto_swap[0] then break end
            swapToAlt(false)
            wait(5 * 60000)
            if not work then break end
            swapToSawnoff()
        end
        swap_thread_running = false
    end)
end

function swapToSawnoff()
    sampSendChat('/invent')
    wait(333)
    updateCachedSlots()
    if cached_sawnoff_slot then
        local data = inventory[cached_sawnoff_slot]
        if cached_sawnoff_slot == 3 or isEquippedItemData(data) then
            clickSawnoffSlot(cached_sawnoff_slot, data)
        else
            send_cef('inventory.moveItemForce|{"slot": ' .. tostring(cached_sawnoff_slot) .. ', "type": 1, "amount": 1}')
            wait(200)
            clickSawnoffSlot(cached_sawnoff_slot, data)
        end
        send_cef('inventoryClose')
        sampAddChatMessage('[Sawnoff] {FFFFFF}Надет Sawnoff.', 0x96FF00)
    else
        sampAddChatMessage('[Sawnoff] {FFFFFF}Sawnoff не найден в инвентаре.', 0x96FF00)
    end
end

function swapToAlt(scheduleReturn)
    if scheduleReturn == nil then scheduleReturn = true end
    sampSendChat('/invent')
    wait(333)
    updateCachedSlots()
    if cached_alt_slot then
        local alt_data = inventory[cached_alt_slot]
        if cached_alt_slot ~= 3 and not isEquippedItemData(alt_data) then
            send_cef('inventory.moveItemForce|{"slot": ' .. tostring(cached_alt_slot) .. ', "type": 1, "amount": 1}')
            wait(200)
        end
        sampAddChatMessage('[Sawnoff] {FFFFFF}Альт-предмет (ID '..alt_model_id[0]..') надет.', 0x96FF00)
        send_cef('inventoryClose')
        if scheduleReturn and auto_swap and auto_swap[0] then
            lua_thread.create(function()
                wait(5 * 60000)
                swapToSawnoff()
            end)
        end
    else
        sampAddChatMessage('[Sawnoff] {FFFFFF}Альт-предмет с ID: {FFD700}'..alt_model_id[0]..' {FF6347}не найден{FFFFFF}.', 0x96FF00)
        sampAddChatMessage('[Sawnoff] {FFFFFF}Auto Swap {FF6347}отключён{FFFFFF}. Укажите правильный ID предмета.', 0x96FF00)
        if auto_swap then auto_swap[0] = false end
        cfg.settings.auto_swap = false
        inicfg.save(cfg, 'sawnoff.ini')
    end
end

-- ======================== ОБРАБОТЧИКИ СОБЫТИЙ ========================
function se.onShowDialog(dialogId, style, title, button1, button2, text)
    if not title then return end
    if inventory_fix and title:find('Инвентарь') then
        sampSendDialogResponse(dialogId, 0, nil, nil)
        inventory_fix = false
        return false
    end
    if title:find('Информация о персонаже') then
        sampAddChatMessage('[Sawnoff] {FFFFFF}Появилось окно "Информация"! Скрипт {FF6347}остановлен.', 0x96FF00)
        work = false
    end
end

function se.onServerMessage(color, text)
    if work and sawnoff and sawnoff[5] then
        local delay_match = text:match('Для использования этого аксессуара должно пройти ещё (%d+) минут!')
        if delay_match then
            delay_time = delay_match
            sampAddChatMessage('[Sawnoff] {FFFFFF}КД на использование! Ожидание: {FFD700}'..delay_time..' {FFFFFF}мин.', 0x96FF00)
            sawnoff[5] = false
            first_start = true
        end
    end
    if work then
        if text:find('Использование аксессуара на данный момент невозможно из-за недостаточного количества зарядов!') then
            sampAddChatMessage('[Sawnoff] {FFFFFF}Аксессуар {FF6347}сломан! Скрипт {FF6347}остановлен.', 0x96FF00)
            thisScript():reload()
            work = false
        end
    end
end

function se.onApplyPlayerAnimation(playerId, animLib, animName, frameDelta, loop, lockX, lockY, freeze, time)
    if work and sawnoff and sawnoff[5] then
        local playerPed = getPlayerPed()
        if playerPed then
            local _, id = sampGetPlayerIdByCharHandle(playerPed)
            if playerId == id and animLib == 'BOMBER' then
                sawnoff[5] = false
            end
        end
    end
end

-- ========================== ГЛАВНЫЙ ПОТОК ==========================
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    if auto_update and auto_update[0] then
        checkForUpdate(false)
    end
    sampRegisterChatCommand('sawnoff', function() if main_window then main_window[0] = not main_window[0] end end)
    sampAddChatMessage('[Sawnoff] {FFFFFF}Скрипт загружен. Используйте {FFD700}/sawnoff{FFFFFF} для настройки.', 0x96FF00)
    while true do
        wait(0)
        if work then
            if not sampIsLocalPlayerSpawned() and sampGetGamestate() == 3 then
                work = false
            else
                if auto_cycle_cd and auto_cycle_cd[0] then
                    wait(1000)
                else
                    if first_start then
                        sampSendChat('/invent')
                        local timeout = 0
                        while not cached_sawnoff_slot and timeout < 50 do
                            wait(100)
                            timeout = timeout + 1
                        end
                        if cached_sawnoff_slot then
                            local sawnoff_data = inventory[cached_sawnoff_slot]
                            if cached_sawnoff_slot == 3 or (sawnoff_data and sawnoff_data.type == 2) then
                                clickSawnoffSlot(cached_sawnoff_slot, sawnoff_data)
                                sawnoff[5] = true
                                delay_time = nil
                                local wait_start = os.time()
                                repeat wait(100) until delay_time ~= nil or not work or os.time() - wait_start > 10
                                if delay_time == nil then delay_time = 60 end
                                send_cef('inventoryClose')
                            elseif cached_sawnoff_slot then
                                send_cef('inventory.moveItemForce|{"slot": ' .. tostring(cached_sawnoff_slot) .. ', "type": 1, "amount": 1}')
                                wait(333)
                                clickSawnoffSlot(cached_sawnoff_slot, sawnoff_data)
                                sawnoff[5] = true
                                delay_time = nil
                                local wait_start = os.time()
                                repeat wait(100) until delay_time ~= nil or not work or os.time() - wait_start > 10
                                if delay_time == nil then delay_time = 60 end
                                send_cef('inventoryClose')
                            end
                        else
                            sampAddChatMessage('[Sawnoff] {FFFFFF}Обрез (Sawnoff) {FF6347}не найден{FFFFFF}.', 0x96FF00)
                            sampAddChatMessage('[Sawnoff] {FFFFFF}Автоматический режим работы: {FF6347}отключён{FFFFFF}.', 0x96FF00)
                            send_cef('inventoryClose')
                            showCursor(false)
                            thisScript():reload()
                        end
                        wait(1)
                    end
                    send_cef('inventoryClose')
                end
                if delay_time ~= nil then
                    wait((tonumber(delay_time) or 60) * 60000 + 60000)
                    delay_time = nil
                    first_start = true
                end
            end
        end
    end
end

function se.onShowTextDraw(id, data)
    if id == 65535 then
        updateCachedSlots()
    end
end

-- ========================== ИНТЕРФЕЙС ==========================
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    imgui.Theme()
    Font = {}
    imgui.GetIO().Fonts:Clear()
    local ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    Font[18] = imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(EagleSans, 18, nil, ranges)
    Font[24] = imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(EagleSans, 24, nil, ranges)
end)

imgui.OnFrame(function() return main_window and main_window[0] and not isPauseMenuActive() end, function()
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowBgAlpha(0.70)
    imgui.Begin('##main_window', main_window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar)
    imgui.BeginChild('##menu', imgui.ImVec2(580, 450), true)
    imgui.PushFont(Font[24])
    imgui.CenterText('Настройка скрипта')
    imgui.PopFont()
    imgui.PushFont(Font[18])
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.48, 0.48, 0.48, 0.72))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.62, 0.62, 0.62, 0.82))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.78, 0.78, 0.78, 0.92))
    if imgui.Button('X', imgui.ImVec2(50, 25), imgui.SameLine(530)) then
        if main_window then main_window[0] = false end
    end
    imgui.PopStyleColor(3)
    imgui.PopFont()
    imgui.PushFont(Font[24])
    imgui.CenterText('Работа с аксессуаром')
    imgui.PopFont()
    imgui.PushFont(Font[18])
    imgui.CenterText('by SAKUTA')
    imgui.PopFont()
    imgui.PushFont(Font[18])
    imgui.CenterText('Версия скрипта: ' .. thisScript().version)
    imgui.Separator()

    if imgui.Checkbox(u8('  Автоматический старт при входе на сервер'), auto_start) then
        cfg.settings.auto_start = auto_start[0]
        inicfg.save(cfg, 'sawnoff.ini')
    end

    if imgui.Checkbox(u8('  Автоматическая смена на альт-предмет'), auto_swap) then
        if auto_swap[0] then auto_cycle_cd[0] = false end
        cfg.settings.auto_swap = auto_swap[0]
        cfg.settings.auto_cycle_cd = auto_cycle_cd[0]
        inicfg.save(cfg, 'sawnoff.ini')
        if work and auto_swap[0] then startAutoSwapThread() end
    end

    if imgui.Checkbox(u8('  Автоматический цикл по КД'), auto_cycle_cd) then
        if auto_cycle_cd[0] then auto_swap[0] = false end
        cfg.settings.auto_cycle_cd = auto_cycle_cd[0]
        cfg.settings.auto_swap = auto_swap[0]
        inicfg.save(cfg, 'sawnoff.ini')
        if work and auto_cycle_cd[0] and not cycle_thread_running then 
            startCycleWithCD()
        elseif not auto_cycle_cd[0] then
            cycle_thread_running = false
        end
    end

    imgui.Checkbox(u8('  Автообновление'), auto_update)
    if auto_update[0] ~= cfg.settings.auto_update then
        cfg.settings.auto_update = auto_update[0]
        inicfg.save(cfg, 'sawnoff.ini')
    end

    imgui.SameLine()
    if imgui.Checkbox(u8('  Debug'), debug_mode) then
        cfg.settings.dbg = debug_mode[0]
        inicfg.save(cfg, 'sawnoff.ini')
    end

    imgui.InputInt(u8('  ID альтернативного предмета'), alt_model_id, 0, 0)
    if alt_model_id[0] ~= cfg.settings.alt_model_id then
        cfg.settings.alt_model_id = alt_model_id[0]
        inicfg.save(cfg, 'sawnoff.ini')
    end
    imgui.Separator()

    imgui.InputInt(u8('  ID обреза (Sawnoff)'), sawnoffId, 0, 0)
    if sawnoffId[0] ~= cfg.settings.sawnoffId then
        cfg.settings.sawnoffId = sawnoffId[0]
        inicfg.save(cfg, 'sawnoff.ini')
        updateCachedSlots()
    end
    imgui.Separator()

    if work then 
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.48, 0.48, 0.48, 0.72))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.62, 0.62, 0.62, 0.82))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.78, 0.78, 0.78, 0.92))
    else
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.48, 0.48, 0.48, 0.72))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.62, 0.62, 0.62, 0.82))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.78, 0.78, 0.78, 0.92))
    end
    imgui.SetCursorPosY(372)
    imgui.SetCursorPosX(205)
    if imgui.Button(work and u8('Остановить') or u8('Запустить'), imgui.ImVec2(170, 30)) then 
        if not work then
            if cfg.settings.connected and sampGetGamestate() == 3 and sampIsLocalPlayerSpawned() then
                work = true
                if main_window then main_window[0] = false end
                if auto_swap and auto_swap[0] then startAutoSwapThread() end
                if auto_cycle_cd and auto_cycle_cd[0] and not cycle_thread_running then startCycleWithCD() end
                sampAddChatMessage('[Sawnoff] {FFFFFF}Автоматический режим работы: {42B02C}включён{FFFFFF}.', 0x96FF00)
            else
                sampAddChatMessage('[Sawnoff] {FFFFFF}Вы не находитесь на сервере.', 0x96FF00)
            end
        else
            send_cef('inventoryClose')
            thisScript():reload()
            sampAddChatMessage('[Sawnoff] {FFFFFF}Автоматический режим работы: {FF6347}отключён{FFFFFF}.', 0x96FF00)
        end
    end
    imgui.PopStyleColor(3)

    imgui.Separator()
    imgui.SetCursorPosY(410)
    imgui.SetCursorPosX(115)
    if imgui.Button(u8('Проверить обновления'), imgui.ImVec2(170, 30)) then
        checkForUpdate(true)
    end
    imgui.SameLine()
    if imgui.Button(u8('Ryodan famq <3'), imgui.ImVec2(170, 30)) then
        os.execute('explorer.exe "https://parad1st.github.io/Screamer/"')
    end
    imgui.PopFont()
    imgui.EndChild()
    imgui.End()
end)

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - imgui.CalcTextSize(u8(text)).x / 2)
    imgui.Text(u8(text))
end

function imgui.Theme()
    imgui.SwitchContext()
    imgui.GetStyle().WindowPadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().FramePadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemSpacing = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(2, 2)
    imgui.GetStyle().IndentSpacing = 0
    imgui.GetStyle().ScrollbarSize = 10
    imgui.GetStyle().GrabMinSize = 10
    imgui.GetStyle().WindowBorderSize = 1
    imgui.GetStyle().ChildBorderSize = 1
    imgui.GetStyle().PopupBorderSize = 1
    imgui.GetStyle().FrameBorderSize = 1
    imgui.GetStyle().TabBorderSize = 1
    imgui.GetStyle().WindowRounding = 5
    imgui.GetStyle().ChildRounding = 5
    imgui.GetStyle().FrameRounding = 5
    imgui.GetStyle().PopupRounding = 5
    imgui.GetStyle().ScrollbarRounding = 5
    imgui.GetStyle().GrabRounding = 5
    imgui.GetStyle().TabRounding = 5
    imgui.GetStyle().WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    -- Цветовая схема (оставлена из оригинального скрипта)
    local colors = imgui.GetStyle().Colors
    colors[imgui.Col.Text] = imgui.ImVec4(0.96, 0.96, 0.96, 1.00)
    colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.62, 0.62, 0.62, 1.00)
    colors[imgui.Col.WindowBg] = imgui.ImVec4(0.42, 0.42, 0.42, 0.70)
    colors[imgui.Col.ChildBg] = imgui.ImVec4(0.46, 0.46, 0.46, 0.62)
    colors[imgui.Col.PopupBg] = imgui.ImVec4(0.42, 0.42, 0.42, 0.86)
    colors[imgui.Col.Border] = imgui.ImVec4(0.74, 0.74, 0.74, 0.30)
    colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[imgui.Col.FrameBg] = imgui.ImVec4(0.56, 0.56, 0.56, 0.58)
    colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.64, 0.64, 0.64, 0.70)
    colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.72, 0.72, 0.72, 0.82)
    colors[imgui.Col.TitleBg] = imgui.ImVec4(0.44, 0.44, 0.44, 0.72)
    colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.50, 0.50, 0.50, 0.78)
    colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.38, 0.38, 0.38, 0.62)
    colors[imgui.Col.MenuBarBg] = imgui.ImVec4(0.46, 0.46, 0.46, 0.68)
    colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.38, 0.38, 0.38, 0.44)
    colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.48, 0.48, 0.48, 0.82)
    colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.62, 0.62, 0.62, 0.92)
    colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.76, 0.76, 0.76, 1.00)
    colors[imgui.Col.CheckMark] = imgui.ImVec4(0.94, 0.94, 0.94, 1.00)
    colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.74, 0.74, 0.74, 0.86)
    colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.88, 0.88, 0.88, 0.94)
    colors[imgui.Col.Button] = imgui.ImVec4(0.48, 0.48, 0.48, 0.72)
    colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.62, 0.62, 0.62, 0.82)
    colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.78, 0.78, 0.78, 0.92)
    colors[imgui.Col.Header] = imgui.ImVec4(0.52, 0.52, 0.52, 0.66)
    colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.64, 0.64, 0.64, 0.76)
    colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.78, 0.78, 0.78, 0.88)
    colors[imgui.Col.Separator] = imgui.ImVec4(0.74, 0.74, 0.74, 0.26)
    colors[imgui.Col.SeparatorHovered] = imgui.ImVec4(0.82, 0.82, 0.82, 0.46)
    colors[imgui.Col.SeparatorActive] = imgui.ImVec4(0.90, 0.90, 0.90, 0.70)
    colors[imgui.Col.ResizeGrip] = imgui.ImVec4(0.76, 0.76, 0.76, 0.25)
    colors[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.86, 0.86, 0.86, 0.67)
    colors[imgui.Col.ResizeGripActive] = imgui.ImVec4(0.96, 0.96, 0.96, 0.95)
    colors[imgui.Col.Tab] = imgui.ImVec4(0.32, 0.32, 0.32, 0.86)
    colors[imgui.Col.TabHovered] = imgui.ImVec4(0.56, 0.56, 0.56, 0.95)
    colors[imgui.Col.TabActive] = imgui.ImVec4(0.46, 0.46, 0.46, 0.92)
    colors[imgui.Col.TabUnfocused] = imgui.ImVec4(0.24, 0.24, 0.24, 0.72)
    colors[imgui.Col.TabUnfocusedActive] = imgui.ImVec4(0.36, 0.36, 0.36, 0.86)
    colors[imgui.Col.PlotLines] = imgui.ImVec4(0.76, 0.76, 0.76, 1.00)
    colors[imgui.Col.PlotLinesHovered] = imgui.ImVec4(0.92, 0.92, 0.92, 1.00)
    colors[imgui.Col.PlotHistogram] = imgui.ImVec4(0.66, 0.66, 0.66, 1.00)
    colors[imgui.Col.PlotHistogramHovered] = imgui.ImVec4(0.86, 0.86, 0.86, 1.00)
    colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.30)
    colors[imgui.Col.DragDropTarget] = imgui.ImVec4(0.90, 0.90, 0.90, 0.90)
    colors[imgui.Col.NavHighlight] = imgui.ImVec4(0.88, 0.88, 0.88, 0.94)
    colors[imgui.Col.NavWindowingHighlight] = imgui.ImVec4(1.00, 1.00, 1.00, 0.70)
    colors[imgui.Col.NavWindowingDimBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.20)
    colors[imgui.Col.ModalWindowDimBg] = imgui.ImVec4(0.00, 0.00, 0.00, 0.55)
end
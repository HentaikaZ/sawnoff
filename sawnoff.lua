script_name("Sawnoff")
script_version("1.0.2")
script_author('SAKUTA')

local se = require 'lib.samp.events'
local imgui = require 'mimgui'
local inicfg = require 'inicfg'
local encoding = require 'encoding'
local acef = require 'arizona-events'
local requests = require 'requests'
local dlstatus = require('moonloader').download_status
local cjson = require 'cjson'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local function logError(err)
    local gameDir = getGameDirectory() or ''
    local logPath = gameDir .. '\\moonloader\\config\\sawnoff_crash_log.txt'
    
    local file = io.open(logPath, 'a')
    if file then
        local time = os.date('%Y-%m-%d %H:%M:%S')
        file:write(string.format('[%s] ERROR: %s\n', time, tostring(err)))
        local trace = debug.traceback('', 2)
        file:write(trace .. '\n\n')
        file:close()
    end
end

local cfg = inicfg.load({
	settings = {
		auto_start = false,
		random_delay = false,
		random_delay_time_min = 0,
		random_delay_time_max = 5,
		open_inventory = false,
		connected = false,
		auto_swap = false,
		alt_model_id = 3166,
		cef = false,
		dbg = false,
		auto_cycle_cd = false,
		auto_update = true
	}
}, 'sawnoff_auto_collector')

if not doesFileExist('sawnoff_auto_collector.ini') then
    inicfg.save(cfg, 'sawnoff_auto_collector.ini')
end

local inventory = {}
local targetId = 5822
local sw, sh = getScreenResolution()
local main_window = imgui.new.bool()
local work = false
local inventory_fix = false
local inventory_id = nil
local first_start = true
local delay_time = nil
local sawnoff = {
    textdraw_id = nil,
    textdraw_put_id = nil,
    textdraw_use_id = nil,
    [4] = false,
    [5] = false
}
local auto_start = imgui.new.bool(cfg.settings.auto_start)
local connected = cfg.settings.connected
local random_delay = imgui.new.bool(cfg.settings.random_delay)
local random_delay_time_min = imgui.new.int(cfg.settings.random_delay_time_min)
local random_delay_time_max = imgui.new.int(cfg.settings.random_delay_time_max)
local open_inventory = imgui.new.bool(cfg.settings.open_inventory)
local timer = imgui.new.bool(false)
local timer_time = imgui.new.int(0)
local cef = imgui.new.bool(cfg.settings.cef)
local alt = {_, _, _, false, false}
local auto_swap = imgui.new.bool(cfg.settings.auto_swap)
local alt_model_id = imgui.new.int(cfg.settings.alt_model_id)
local swap_thread_running = false
local debug_mode = imgui.new.bool(cfg.settings.dbg)
local auto_cycle_cd = imgui.new.bool(cfg.settings.auto_cycle_cd)
local auto_update = imgui.new.bool(cfg.settings.auto_update)
local cycle_thread_running = false
local payday_block = false
local updateversion = thisScript().version
local update_check_running = false
local update_available = false
local update_notified = false
local update_version = nil
local update_url = nil

local function checkForUpdate(manual)
    if update_check_running then return end
    update_check_running = true
    lua_thread.create(function()
        local json_url = "https://raw.githubusercontent.com/HentaikaZ/sawnoff/refs/heads/main/autoupdate.json"
        local temp_name = thisScript().name..'_'..os.time()..'_'..math.random(1000,9999)..'.json'
        local json_path = getWorkingDirectory() .. '\\' .. temp_name
        
        local success, err = pcall(downloadUrlToFile, json_url, json_path, function(id, status, p1, p2)
            if status == dlstatus.STATUSEX_ENDDOWNLOAD then
                if doesFileExist(json_path) then
                    local f = io.open(json_path, 'r')
                    if f then
                        local content = f:read('*a')
                        f:close()
                        os.remove(json_path)
                        local ok, info = pcall(cjson.decode, content)
                        if ok and info and info.latest and info.updateurl then
                            local latest = info.latest
                            local update_link = info.updateurl
                            update_version = latest
                            update_url = update_link
                            if latest ~= thisScript().version then
                                update_available = true
                                if manual then
                                    sampAddChatMessage(string.format('[Èíôîðìàöèÿ] {FFFFFF}Îáíàðóæåíî îáíîâëåíèå {FF6347}%s{FFFFFF}. Íà÷èíàþ îáíîâëåíèå...', latest), 0x96FF00)
                                    downloadUrlToFile(update_link, thisScript().path,
                                        function(id3, status1, p13, p23)
                                            if status1 == dlstatus.STATUS_DOWNLOADINGDATA then
                                                print(string.format('Çàãðóæåíî %d èç %d.', p13, p23))
                                            elseif status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
                                                print('Çàãðóçêà îáíîâëåíèÿ çàâåðøåíà.')
                                                sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Îáíîâëåíèå çàâåðøåíî!', 0x96FF00)
                                                lua_thread.create(function() wait(500) thisScript():reload() end)
                                            end
                                        end
                                    )
                                else
                                    if auto_update and auto_update[0] then
                                        sampAddChatMessage(string.format('[Èíôîðìàöèÿ] {FFFFFF}Îáíàðóæåíî îáíîâëåíèå {FF6347}%s{FFFFFF}. Àâòîîáíîâëåíèå...', latest), 0x96FF00)
                                        downloadUrlToFile(update_link, thisScript().path,
                                            function(id3, status1, p13, p23)
                                                if status1 == dlstatus.STATUS_DOWNLOADINGDATA then
                                                    print(string.format('Çàãðóæåíî %d èç %d.', p13, p23))
                                                elseif status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
                                                    print('Çàãðóçêà îáíîâëåíèÿ çàâåðøåíà.')
                                                    sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Îáíîâëåíèå çàâåðøåíî!', 0x96FF00)
                                                    lua_thread.create(function() wait(500) thisScript():reload() end)
                                                end
                                            end
                                        )
                                    else
                                        if not update_notified then
                                            sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Äîñòóïíî îáíîâëåíèå. Íàæìèòå êíîïêó "Ïðîâåðêà îáíîâëåíèÿ" äëÿ îáíîâëåíèÿ.', 0x96FF00)
                                            update_notified = true
                                        end
                                    end
                                end
                            else
                                update_available = false
                                if manual then
                                    sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Ó âàñ àêòóàëüíàÿ âåðñèÿ ñêðèïòà.', 0x96FF00)
                                end
                            end
                        else
                            sampAddChatMessage('[Èíôîðìàöèÿ] {FF6347}Îøèáêà ïðîâåðêè îáíîâëåíèÿ. Ñâÿæèòåñü ñ ðàçðàáîò÷èêîì.', 0x96FF00)
                        end
                    else
                        sampAddChatMessage('[Èíôîðìàöèÿ] {FF6347}Íå óäàëîñü ïðî÷èòàòü ôàéë îáíîâëåíèÿ. Ñâÿæèòåñü ñ ðàçðàáîò÷èêîì.', 0x96FF00)
                    end
                    if doesFileExist(json_path) then os.remove(json_path) end
                else
                    sampAddChatMessage('[Èíôîðìàöèÿ] {FF6347}Íå óäàëîñü çàãðóçèòü ôàéë îáíîâëåíèÿ. Ñâÿæèòåñü ñ ðàçðàáîò÷èêîì.', 0x96FF00)
                end
            end
        end)
        
        if not success then
            sampAddChatMessage('[Èíôîðìàöèÿ] {FF6347}Îøèáêà ïðè çàãðóçêå îáíîâëåíèÿ. Ñâÿæèòåñü ñ ðàçðàáîò÷èêîì.', 0x96FF00)
        end
        update_check_running = false
    end)
end

local isInventoryTextdrawValid, clickInventoryTextdraw, safeClick, textdrawExists

local function safeClearInventory()
    inventory = {}
    collectgarbage()
end

local function safeGetInventoryItem(slot)
    if not inventory or type(inventory) ~= 'table' then
        return nil
    end
    if slot then
        return inventory[slot]
    end
    return nil
end

local function safeSetInventoryItem(slot, data)
    if not inventory or type(inventory) ~= 'table' then
        inventory = {}
    end
    if slot and data then
        inventory[slot] = data
    end
end

local function safeRemoveInventoryItem(slot)
    if not inventory or type(inventory) ~= 'table' then
        return
    end
    if slot then
        inventory[slot] = nil
    end
end

local function openInventoryAndWait()
    if not sampIsLocalPlayerSpawned() then return end
	inventory_fix = true
	sampSendClickTextdraw(65535)
	wait(333)
	sampSendChat('/invent')
	local wait_count = 0
	repeat 
		wait(100) 
		wait_count = wait_count + 1
	until (isInventoryTextdrawValid() or wait_count > 50)
	wait(500)
end

local function isPayDayBlocked()
    local t = os.date('*t')
    local min = t.min
    
    if (min >= 28 and min <= 31) or (min >= 58 or min <= 1) then
        return true
    end
    return false
end

local function getPayDayUnlockTime()
    local t = os.date('*t')
    local min = t.min
    local sec = t.sec
    local wait_sec = 0
    
    if min >= 28 and min <= 31 then
        wait_sec = (32 - min) * 60 - sec
    elseif min >= 58 then
        wait_sec = (60 - min) * 60 - sec + 2 * 60
    elseif min <= 1 then
        wait_sec = (2 - min) * 60 - sec
    end
    
    return wait_sec
end

local function startCycleWithCD()
    if cycle_thread_running then return end
    if not auto_cycle_cd or not auto_cycle_cd[0] then return end
    cycle_thread_running = true
    
    lua_thread.create(function()
        while work and auto_cycle_cd and auto_cycle_cd[0] do
            if isPayDayBlocked() then
                local wait_time = getPayDayUnlockTime()
                sampAddChatMessage(string.format('[Èíôîðìàöèÿ] {FFFFFF}Ñìåíà íà îáðåç îòìåíåíà èç-çà ïðèáëèæåíèÿ {FF6347}PayDay!{FFFFFF} Ïîäîæäèòå {FF6347}%d ñåê.', wait_time), 0x96FF00)
                wait(wait_time * 1000)
            end
            
            if cef and cef[0] then
                openInventoryAndWait()
                wait(333)
                
                local sawnoff_slot = findItemById(inventory, targetId)
                if sawnoff_slot ~= nil then
                    if sawnoff_slot ~= 3 then
                        repeat
                            sampSendChat('/invent')
                            wait(333)
                            sawnoff_slot = findItemById(inventory, targetId)
                        until sawnoff_slot or not work
                    end
                    if sawnoff_slot == 3 then
                        send_cef('clickOnButton|{"type": 2,"slot": 3, "action": 1}')
                        sawnoff[5] = true
                        delay_time = nil
                        local wait_start = os.time()
                        repeat wait(100) until delay_time ~= nil or not work or os.time() - wait_start > 10
                        if delay_time == nil then delay_time = 60 end
                    elseif sawnoff_slot and type(sawnoff_slot) == 'number' then
                        send_cef('inventory.moveItemForce|{"slot": ' .. tostring(sawnoff_slot) .. ', "type": 1, "amount": 1}')
                        wait(333)
                        send_cef('clickOnButton|{"type": 2,"slot": 3, "action": 1}')
                        sawnoff[5] = true
                        delay_time = nil
                        local wait_start = os.time()
                        repeat wait(100) until delay_time ~= nil or not work or os.time() - wait_start > 10
                        if delay_time == nil then delay_time = 60 end
                    end
                end
                
                wait(500)
                
                local alt_slot = FindAltItem(inventory, alt_model_id[0])
                if alt_slot then
                    if alt_slot ~= 3 then
                        send_cef('inventory.moveItemForce|{"slot": ' .. alt_slot .. ', "type": 1, "amount": 1}')
                        wait(333)
                    end
                    sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Àëüò-ïðåäìåò îäåò. [CEF]', 0x96FF00)
                    sampSendClickTextdraw(65535)
                else
                    sampAddChatMessage('[Èíôîðìàöèÿ] {FF6347}Àëüò-ïðåäìåò íå íàéäåí. [CEF]', 0x96FF00)
                end
            else
                openInventoryAndWait()
                wait(333)
                
                if sawnoff and sawnoff['textdraw_id'] then
                    safeClick(sawnoff['textdraw_id'])
                    wait(500)
                    
                    if sawnoff['textdraw_use_id'] and sampTextdrawIsExists(sawnoff['textdraw_use_id']) then
                        safeClick(sawnoff['textdraw_use_id'])
                        sawnoff[5] = true
                        sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Îáðåç èñïîëüçîâàí.', 0x96FF00)
                    end
                    
                    delay_time = nil
                    local wait_start = os.time()
                    repeat 
                        wait(100) 
                        if not work then break end
                    until delay_time ~= nil or os.time() - wait_start > 10
                    
                    wait(500)
                    if alt and alt[1] then
                        safeClick(alt[1])
                        wait(500)
                        if alt[2] and sampTextdrawIsExists(alt[2]) then
                            safeClick(alt[2])
                        end
                        sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Àëüò-ïðåäìåò îäåò.', 0x96FF00)
                        sampSendClickTextdraw(65535)
                    end
                end
            end
            
            if delay_time then
                local wait_minutes = tonumber(delay_time) or 60
                sampAddChatMessage(string.format('[Èíôîðìàöèÿ] {FFFFFF}Îæèäàíèå ÊÄ: {FFD700}%d {FFFFFF}ìèíóò.', wait_minutes), 0x96FF00)
                
                local total_wait = wait_minutes * 60000
                local elapsed = 0
                local check_interval = 5000
                
                while elapsed < total_wait and work and auto_cycle_cd and auto_cycle_cd[0] do
                    if isPayDayBlocked() then
                        local wait_time = getPayDayUnlockTime()
                        sampAddChatMessage(string.format('[Èíôîðìàöèÿ] {FFFFFF}Îæèäàíèå ïðåðâàíî èç-çà {FF6347}PayDay!{FFFFFF} Ïàóçà {FF6347}%d ñåê.', wait_time), 0x96FF00)
                        wait(wait_time * 1000)
                        elapsed = 0
                    else
                        wait(math.min(check_interval, total_wait - elapsed))
                        elapsed = elapsed + check_interval
                    end
                end
                
                delay_time = nil
            else
                sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}ÊÄ íå îïðåäåëåí, îæèäàíèå 60 ìèíóò.', 0x96FF00)
                
                local total_wait = 60 * 60000
                local elapsed = 0
                local check_interval = 5000
                
                while elapsed < total_wait and work and auto_cycle_cd and auto_cycle_cd[0] do
                    if isPayDayBlocked() then
                        local wait_time = getPayDayUnlockTime()
                        sampAddChatMessage(string.format('[Èíôîðìàöèÿ] {FFFFFF}Îæèäàíèå ïðåðâàíî èç-çà {FF6347}PayDay!{FFFFFF} Ïàóçà {FF6347}%d ñåê.', wait_time), 0x96FF00)
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

function main()
	if not isSampLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(100) end
	
	if auto_update then
	    checkForUpdate(false)
	end
	
	sampRegisterChatCommand('sawnoff', function() if main_window then main_window[0] = not main_window[0] end end)
	
	if debug_mode and debug_mode[0] then
		if cef and cef[0] then
			sampAddChatMessage('[Îòëàäêà] {FFFFFF}Ðåæèì CEF: {42B02C}ÂÊËÞ×ÅÍ', 0x96FF00)
			sampAddChatMessage('[Îòëàäêà] {FFFFFF}Áóäóò ïîêàçûâàòüñÿ ID ïðåäìåòîâ èç CEF ïàêåòîâ', 0x96FF00)
		else
			sampAddChatMessage('[Îòëàäêà] {FFFFFF}Ðåæèì CEF: {FF6347}ÂÛÊËÞ×ÅÍ', 0x96FF00)
			sampAddChatMessage('[Îòëàäêà] {FFFFFF}Áóäóò ïîêàçûâàòüñÿ MODEL ID èç òåêñòäðàâîâ', 0x96FF00)
			sampAddChatMessage('[Îòëàäêà] {FFFFFF}Îòêðîéòå èíâåíòàðü (/invent) ÷òîáû óâèäåòü ìîäåëè', 0x96FF00)
		end
	end
	
	while true do
		wait(0)
		xpcall(function()
			if work then
				if not sampIsLocalPlayerSpawned() and sampGetGamestate() == 3 then
					work = false
				else
					if auto_cycle_cd and auto_cycle_cd[0] then
						wait(1000)
					else
						if first_start and timer and timer[0] then
							if timer_time and timer_time[0] and timer_time[0] > 0 then
							    wait(timer_time[0] * 60000)
							    timer_time[0] = 0
							end
						end	
						if first_start then
							if targetId and targetId > 0 then findItemById(inventory, targetId) end
							if alt_model_id and alt_model_id[0] and alt_model_id[0] > 0 then FindAltItem(inventory, alt_model_id[0]) end
							sampSendClickTextdraw(65535)
							sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Ñåé÷àñ îòêðîåòñÿ èíâåíòàðü.', 0x96FF00)
						elseif not first_start and open_inventory and not open_inventory[0] then
							if targetId and targetId > 0 then findItemById(inventory, targetId) end
							if alt_model_id and alt_model_id[0] and alt_model_id[0] > 0 then FindAltItem(inventory, alt_model_id[0]) end
							sampSendClickTextdraw(65535)
							sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Ñåé÷àñ îòêðîåòñÿ èíâåíòàðü.', 0x96FF00)
						end
						wait(333)
						inventory_fix = true
						wait(333)
						if first_start then
							if targetId and targetId > 0 then findItemById(inventory, targetId) end
							if alt_model_id and alt_model_id[0] and alt_model_id[0] > 0 then FindAltItem(inventory, alt_model_id[0]) end
							sampSendChat('/invent')
						elseif not first_start and open_inventory and not open_inventory[0] then
							if targetId and targetId > 0 then findItemById(inventory, targetId) end
							if alt_model_id and alt_model_id[0] and alt_model_id[0] > 0 then FindAltItem(inventory, alt_model_id[0]) end
							sampSendChat('/invent')
						elseif not first_start and open_inventory and open_inventory[0] and not isInventoryTextdrawValid() then
							if targetId and targetId > 0 then findItemById(inventory, targetId) end
							if alt_model_id and alt_model_id[0] and alt_model_id[0] > 0 then FindAltItem(inventory, alt_model_id[0]) end
							sampSendChat('/invent')
						end
						
						if cef and cef[0] then
							wait(333)
							local sawnoff_slot = findItemById(inventory, targetId)
							if sawnoff_slot ~= nil then
								if sawnoff_slot ~= 3 then
									repeat
										sampSendChat('/invent')
										wait(333)
										sawnoff_slot = findItemById(inventory, targetId)
									until sawnoff_slot or not work
								end
								if sawnoff_slot == 3 then
									send_cef('clickOnButton|{"type": 2,"slot": 3, "action": 1}')
									sawnoff[5] = true
									delay_time = nil
									local wait_start = os.time()
									repeat wait(100) until delay_time ~= nil or not work or os.time() - wait_start > 10
									if delay_time == nil then delay_time = 60 end
								elseif sawnoff_slot and type(sawnoff_slot) == 'number' then
									send_cef('inventory.moveItemForce|{"slot": ' .. tostring(sawnoff_slot) .. ', "type": 1, "amount": 1}')
									wait(333)
									send_cef('clickOnButton|{"type": 2,"slot": 3, "action": 1}')
									sawnoff[5] = true
									delay_time = nil
									local wait_start = os.time()
									repeat wait(100) until delay_time ~= nil or not work or os.time() - wait_start > 10
									if delay_time == nil then delay_time = 60 end
								end
							end
						else
							repeat wait(1) until not work or isInventoryTextdrawValid()
							wait(333)
							if sawnoff and sawnoff['textdraw_id'] ~= nil then
								if not isInventoryTextdrawValid() then
									repeat
										sampSendChat('/invent')
										wait(1000)
									until isInventoryTextdrawValid() or not work
								end
								sawnoff[5] = true
								repeat
									safeClick(sawnoff['textdraw_id'])
									repeat wait(1) until (sawnoff and (textdrawExists(sawnoff['textdraw_put_id']) or textdrawExists(sawnoff['textdraw_use_id']))) or not work
									wait(500)
									if sawnoff and sawnoff[4] == false then
										safeClick(sawnoff['textdraw_put_id'])
										wait(1000)
										safeClick(sawnoff['textdraw_id'])
										repeat wait(1) until (sawnoff and (textdrawExists(sawnoff['textdraw_put_id']) or textdrawExists(sawnoff['textdraw_use_id']))) or not work
										wait(500)
									end
									safeClick(sawnoff['textdraw_use_id'])
									wait(500)
								until sawnoff and sawnoff[5] == false or not work
							else
								sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}«Îáðåç (àêòèâíûé àêñåññóàð)» {FF6347}íå íàéäåí{FFFFFF}.', 0x96FF00)
								sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Àâòîìàòè÷åñêèé ñáîð îáðåçà: {FF6347}âûêëþ÷åí{FFFFFF}.', 0x96FF00)
								sampSendClickTextdraw(65535)
								showCursor(false)
								thisScript():reload()
							end
							wait(500)
						end

						if open_inventory and not open_inventory[0] then
							sampSendClickTextdraw(65535)
						end
						if delay_time ~= nil then
							if random_delay and not random_delay[0] then
								wait(tonumber(delay_time) * 60000 + 60000)
							else
								wait(tonumber(delay_time) * 60000 + 60000 + math.random(random_delay_time_min[0] * 60000, random_delay_time_max[0] * 60000))
							end
							delay_time = nil
							first_start = true
						else
							if random_delay and not random_delay[0] then
								wait(61 * 60000)
							else
								wait(61 * 60000 + math.random(random_delay_time_min[0] * 60000, random_delay_time_max[0] * 60000))
							end
						end
					end
				end
			end
		end, logError)
	end
end

function acef.onArizonaDisplay(packet)
	xpcall(function()
		if not packet then return end
		if not acef.decode(packet) then return end
		
		if packet.event == 'event.inventory.playerInventory' then
			local data = packet.json and packet.json[1]
			if not data or not data.data then return end
			
			if data.data.type ~= 1 and data.data.type ~= 2 and data.data.type ~= 3 then return end
			if data.action ~= 0 and data.action ~= 1 and data.action ~= 2 and data.action ~= 3 then return end
			
			local items = data.data.items
			if not items then return end
			
			for _, item in ipairs(items) do
				if item and item.item and item.slot then
					local amount = item.amount or 1
					
					if debug_mode and debug_mode[0] and cef and cef[0] then
						sampAddChatMessage(
							string.format("[Èíôîðìàöèÿ] {FF6347}[CEF] {FFFFFF}Ñëîò {FFD700}%d {FFFFFF}| Ìîäåëü: {42B02C}%d", 
								item.slot, item.item), 
							0x96FF00
						)
					end
					
					safeSetInventoryItem(item.slot, {
						slot = item.slot,
						available = item.available,
						item = item.item,
						amount = amount
					})
				else
					if item and item.slot then
						safeRemoveInventoryItem(item.slot)
					end
				end
			end
			
			if alt_model_id and alt_model_id[0] and alt_model_id[0] > 0 then
				FindAltItem(inventory, alt_model_id[0])
			end
			
			if targetId and targetId > 0 then
				findItemById(inventory, targetId)
			end
		end
	end, logError)
end

function se.onShowTextDraw(id, data)
	xpcall(function()
		if not id or not data then return end
		
		if debug_mode and debug_mode[0] and cef and not cef[0] then
			if data.modelId and data.modelId ~= 0 then
				sampAddChatMessage(
					string.format("[Èíôîðìàöèÿ] {FF6347}[TD] {FFFFFF}Ìîäåëü: {42B02C}%d", data.modelId), 
					0x96FF00
				)
			end
		end
		
		local text = data.text or ""
		if text == 'INVENTORY' or (text == 'HEHAP' and data.style == 2) then
			inventory_id = id
			if not cfg.settings.connected then
				cfg.settings.connected = true
				inicfg.save(cfg, 'sawnoff_auto_collector.ini')
			end
		end
		
		if id == 65535 then
			if targetId and targetId > 0 then findItemById(inventory, targetId) end
			if alt_model_id and alt_model_id[0] and alt_model_id[0] > 0 then FindAltItem(inventory, alt_model_id[0]) end
		end

		if data.modelId and data.rotation then
			if data.modelId == 350 and data.rotation.x == -20 and data.rotation.y == 0 and data.rotation.z == 75 and 
			   (data.backgroundColor == -13469276 or data.backgroundColor == -13149076) then
				sawnoff["textdraw_id"] = id
			end
		end
		
		if alt_model_id and alt_model_id[0] and data.modelId == alt_model_id[0] then
			alt[1] = id
		end
		
		if text == 'PUT' or text == 'HAE' then
			sawnoff[4] = false
			sawnoff["textdraw_put_id"] = id + 1
			alt[4] = false
			alt[2] = id + 1
		end
		if text == 'USE' or text == 'COOA' then
			sawnoff[4] = true
			sawnoff["textdraw_use_id"] = id + 1
			alt[4] = true
			alt[3] = id + 1
		end
	end, logError)
end

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

function findItemById(inventory, targetId)
	if not inventory or type(inventory) ~= 'table' or not targetId or targetId <= 0 then 
		return nil, nil 
	end
	for slot, data in pairs(inventory) do
		if data and type(data) == 'table' and data.item == targetId then
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

imgui.OnInitialize(function()
	imgui.GetIO().IniFilename = nil
	imgui.Theme()
	Font = {}
	imgui.GetIO().Fonts:Clear()
	local ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
	Font[18] = imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(EagleSans, 18, nil, ranges)
	Font[24] = imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(EagleSans, 24, nil, ranges)
end)

imgui.OnFrame(function() return main_window and main_window[0] and not isPauseMenuActive() end, function(self)
	imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	imgui.Begin('##main_window', main_window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar)
	imgui.BeginChild('##menu', imgui.ImVec2(520, 450), true)
	imgui.PushFont(Font[24])
	imgui.CenterText('Àâòîìàòè÷åñêèé ñáîð')
	imgui.PopFont()
	imgui.PushFont(Font[18])
	imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.13, 0.13, 0.13, 1.00))
	imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.66, 0.00, 0.00, 1.00))
	imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.50, 0.00, 0.00, 1.00))
	if imgui.Button('X', imgui.ImVec2(50, 25), imgui.SameLine(470)) then
		if main_window then main_window[0] = false end
	end
	imgui.PopStyleColor(3)
	imgui.PopFont()
	imgui.PushFont(Font[24])
	imgui.CenterText('ïàòðîíîâ c àêñåññóàðà «Îáðåç»')
	imgui.PopFont()
	imgui.PushFont(Font[18])
	imgui.CenterText('Remake by SAKUTA')
	imgui.PopFont()
	imgui.PushFont(Font[18])
	imgui.CenterText('Âåðñèÿ ñêðèïòà: ' .. thisScript().version)
	imgui.Separator()
	
	imgui.Checkbox(u8' Çàïóñêàòü ñêðèïò ïðè ïîäêëþ÷åíèè ê ñåðâåðó', auto_start)
	if auto_start and auto_start[0] then 
		if cfg.settings.auto_start ~= auto_start[0] then
			cfg.settings.auto_start = true
			inicfg.save(cfg, 'sawnoff_auto_collector.ini')
		end
	else
		if cfg.settings.auto_start ~= auto_start[0] then
			cfg.settings.auto_start = false
			inicfg.save(cfg, 'sawnoff_auto_collector.ini')
		end
	end
	
	imgui.Checkbox(u8' Ðàíäîìíàÿ çàäåðæêà: îò', random_delay)
	if random_delay and random_delay[0] then
		if cfg.settings.random_delay ~= random_delay[0] then
			cfg.settings.random_delay = true
			inicfg.save(cfg, 'sawnoff_auto_collector.ini')
		end
	else
		if cfg.settings.random_delay ~= random_delay[0] then
			cfg.settings.random_delay = false
			inicfg.save(cfg, 'sawnoff_auto_collector.ini')
		end
	end
	imgui.PushItemWidth(30)
	imgui.InputInt(u8' ìèí.  äî##random_delay_time_min', random_delay_time_min, 0, 0, imgui.SameLine())
	if random_delay_time_min and random_delay_time_min[0] then
		if random_delay_time_min[0] < 0 then random_delay_time_min[0] = 0 end
		if random_delay_time_max and random_delay_time_max[0] and random_delay_time_min[0] > random_delay_time_max[0] then random_delay_time_min[0] = random_delay_time_max[0] end
		if cfg.settings.random_delay_time_min ~= random_delay_time_min[0] then
			cfg.settings.random_delay_time_min = random_delay_time_min[0]
			inicfg.save(cfg, 'sawnoff_auto_collector.ini')
		end
	end
	imgui.InputInt(u8' ìèí.##random_delay_time_max', random_delay_time_max, 0, 0, imgui.SameLine())
	if random_delay_time_max and random_delay_time_max[0] then
		if random_delay_time_max[0] > 99 then random_delay_time_max[0] = 99 end
		if random_delay_time_min and random_delay_time_min[0] and random_delay_time_max[0] < random_delay_time_min[0] then random_delay_time_max[0] = random_delay_time_min[0] end
		if cfg.settings.random_delay_time_max ~= random_delay_time_max[0] then
			cfg.settings.random_delay_time_max = random_delay_time_max[0]
			inicfg.save(cfg, 'sawnoff_auto_collector.ini')
		end
	end
	imgui.PopItemWidth()
	imgui.Separator()
	
	imgui.Checkbox(u8' Àâòî ñìåíà íà ïðåäìåò (âêë/âûêë)', auto_swap)
	if auto_swap and auto_swap[0] then
		if cfg.settings.auto_swap ~= auto_swap[0] then cfg.settings.auto_swap = true; inicfg.save(cfg, 'sawnoff_auto_collector.ini') end
		if work and auto_swap[0] then startAutoSwapThread() end
	else
		if cfg.settings.auto_swap ~= auto_swap[0] then cfg.settings.auto_swap = false; inicfg.save(cfg, 'sawnoff_auto_collector.ini') end
	end
	
	imgui.Checkbox(u8' Àâòî ñìåíà íà îáðåç ïîñëå ÊÄ', auto_cycle_cd)
	if auto_cycle_cd and auto_cycle_cd[0] then
		if cfg.settings.auto_cycle_cd ~= auto_cycle_cd[0] then cfg.settings.auto_cycle_cd = true; inicfg.save(cfg, 'sawnoff_auto_collector.ini') end
		if work and auto_cycle_cd[0] and not cycle_thread_running then 
			startCycleWithCD()
		end
	else
		if cfg.settings.auto_cycle_cd ~= auto_cycle_cd[0] then cfg.settings.auto_cycle_cd = false; inicfg.save(cfg, 'sawnoff_auto_collector.ini') end
		cycle_thread_running = false
	end
	
	imgui.Checkbox(u8' Àâòîîáíîâëåíèå', auto_update)
	if auto_update and auto_update[0] then
		if cfg.settings.auto_update ~= auto_update[0] then
			cfg.settings.auto_update = true
			inicfg.save(cfg, 'sawnoff_auto_collector.ini')
		end
	else
		if cfg.settings.auto_update ~= auto_update[0] then
			cfg.settings.auto_update = false
			inicfg.save(cfg, 'sawnoff_auto_collector.ini')
		end
	end

	imgui.SameLine()
	imgui.Checkbox(u8' CEF Èíâåíòàðü', cef)
	if cef and cef[0] then
		if cfg.settings.cef ~= cef[0] then cfg.settings.cef = true; inicfg.save(cfg, 'sawnoff_auto_collector.ini') end
	else
		if cfg.settings.cef ~= cef[0] then cfg.settings.cef = false; inicfg.save(cfg, 'sawnoff_auto_collector.ini') end
	end

	imgui.SameLine()
	imgui.Checkbox(u8' Debug', debug_mode)
	if debug_mode and debug_mode[0] then
		if cfg.settings.dbg ~= debug_mode[0] then cfg.settings.dbg = true; inicfg.save(cfg, 'sawnoff_auto_collector.ini') end
	else
		if cfg.settings.dbg ~= debug_mode[0] then cfg.settings.dbg = false; inicfg.save(cfg, 'sawnoff_auto_collector.ini') end
	end
	
	imgui.InputInt(u8' ID ìîäåëè ïðåäìåòà', alt_model_id, 0, 0)
	if alt_model_id and alt_model_id[0] and cfg.settings.alt_model_id ~= alt_model_id[0] then cfg.settings.alt_model_id = alt_model_id[0]; inicfg.save(cfg, 'sawnoff_auto_collector.ini') end
	imgui.Separator()
	
	imgui.Checkbox(u8' Íå çàêðûâàòü èíâåíòàðü ïîñëå ïåðâîãî îòêðûòèÿ', open_inventory)
	if open_inventory and open_inventory[0] then
		if cfg.settings.open_inventory ~= open_inventory[0] then
			cfg.settings.open_inventory = true
			inicfg.save(cfg, 'sawnoff_auto_collector.ini')
		end
	else
		if cfg.settings.open_inventory ~= open_inventory[0] then
			cfg.settings.open_inventory = false
			inicfg.save(cfg, 'sawnoff_auto_collector.ini')
		end
	end
	
	imgui.Checkbox(u8' Çàïóñòèòü ñêðèïò ÷åðåç:', timer)
	imgui.PushItemWidth(30)
	imgui.SameLine()
	imgui.InputInt(u8' ìèí.##timer_time', timer_time, 0, 0)
	if timer_time and timer_time[0] then
		if timer_time[0] < 0 then timer_time[0] = 0 end
		if timer_time[0] > 0 and timer_time[0] <= 99 then timer[0] = true else timer[0] = false end
		if timer_time[0] > 99 then timer_time[0] = 99 end
	end
	imgui.PopItemWidth()
	imgui.Separator()
	
	if work then 
		imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.13, 0.13, 0.13, 1.00))
		imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.66, 0.00, 0.00, 1.00))
		imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.50, 0.00, 0.00, 1.00))
	else
		imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.13, 0.13, 0.13, 1.00))
		imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.00, 0.66, 0.00, 1.00))
		imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.00, 0.50, 0.00, 1.00))
	end
	if imgui.Button(work and u8'Âûêëþ÷èòü' or u8'Âêëþ÷èòü', imgui.ImVec2(170, 30)) then 
		if not work then
			if cfg.settings.connected and sampGetGamestate() == 3 and sampIsLocalPlayerSpawned() then
				work = true
				if main_window then main_window[0] = false end
				if auto_swap and auto_swap[0] then startAutoSwapThread() end
				if auto_cycle_cd and auto_cycle_cd[0] and not cycle_thread_running then startCycleWithCD() end
				if timer and timer[0] and timer_time and timer_time[0] and timer_time[0] ~= 0 and timer_time[0] > 0 then
					sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Àâòîìàòè÷åñêèé ñáîð îáðåçà: {42B02C}âêëþ÷åí{FFFFFF}.', 0x96FF00)
					sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Çàïóñê ÷åðåç {FFD700}'..timer_time[0]..' {FFFFFF}ìèí.', 0x96FF00)
				else
					sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Àâòîìàòè÷åñêèé ñáîð îáðåçà: {42B02C}âêëþ÷åí{FFFFFF}.', 0x96FF00)
				end
			else
				sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Âû íå ïîäêëþ÷åíû ê ñåðâåðó.', 0x96FF00)
			end
		else
			sampSendClickTextdraw(65535)
			thisScript():reload()
			sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Àâòîìàòè÷åñêèé ñáîð îáðåçà: {FF6347}âûêëþ÷åí{FFFFFF}.', 0x96FF00)
		end
	end
	imgui.PopStyleColor(3)
	
	imgui.SameLine()
	if imgui.Button(u8'Ïðîâåðêà îáíîâëåíèÿ', imgui.ImVec2(170, 30)) then
		checkForUpdate(true)
	end
	imgui.SameLine()
	if imgui.Button(u8'Ryodan famq <3', imgui.ImVec2(170, 30)) then
		os.execute(('explorer.exe "%s"'):format('https://parad1st.github.io/Screamer/'))
	end
	
	imgui.Separator()
	imgui.PopFont()
	imgui.EndChild()
	imgui.End()
end)

function swapToAlt(scheduleReturn)
	xpcall(function()
		if scheduleReturn == nil then scheduleReturn = true end
		if alt_model_id == nil then alt_model_id = imgui.new.int(cfg.settings.alt_model_id or 3166) end
		if alt_model_id[0] == nil then alt_model_id[0] = cfg.settings.alt_model_id or 3166 end
		cfg.settings.alt_model_id = alt_model_id[0]
		inicfg.save(cfg, 'sawnoff_auto_collector.ini')

		if cef and cef[0] then
			openInventoryAndWait()
			wait(333)
			local wait_count = 0
			repeat
				wait(100)
				wait_count = wait_count + 1
				if wait_count > 50 then break end
			until next(inventory) ~= nil
			
			local alt_slot = FindAltItem(inventory, alt_model_id[0])
			if alt_slot then
				if alt_slot ~= 3 then
					send_cef('inventory.moveItemForce|{"slot": ' .. alt_slot .. ', "type": 1, "amount": 1}')
					wait(333)
				end
				sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Àëüò-ïðåäìåò (ID '..alt_model_id[0]..') îäåò. [CEF]', 0x96FF00)
				sampSendClickTextdraw(65535)
				wait(333)
				if scheduleReturn and auto_swap and auto_swap[0] then
					local dur = 5
					lua_thread.create(function()
						wait(dur * 60000)
						swapToSawnoff()
					end)
				end
			else
				sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Àëüòåðíàòèâíûé ïðåäìåò ñ ID: {FFD700}'..alt_model_id[0]..' {FF6347}íå íàéäåí{FFFFFF}. [CEF]', 0x96FF00)
				sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Auto Swap {FF6347}îòêëþ÷åí{FFFFFF}. Îáðåç áóäåò ñîáèðàòüñÿ áåç ñâàïà. [CEF]', 0x96FF00)
				if auto_swap then auto_swap[0] = false end
				cfg.settings.auto_swap = false
				inicfg.save(cfg, 'sawnoff_auto_collector.ini')
			end
		else
			openInventoryAndWait()
			if alt and alt[1] ~= nil then
				if not isInventoryTextdrawValid() then
					repeat
						sampSendChat('/invent')
						wait(1000)
					until not work or isInventoryTextdrawValid()
				end
				alt[5] = true
				safeClick(alt[1])
				local waited = 0
				local opt = nil
				repeat
					if alt[3] and sampTextdrawIsExists(alt[3]) then opt = 'use'; break end
					if alt[2] and sampTextdrawIsExists(alt[2]) then opt = 'put'; break end
					wait(100)
					waited = waited + 100
				until waited > 2000
				if opt == 'use' then
					safeClick(alt[3])
				elseif opt == 'put' then
					safeClick(alt[2])
				end
				wait(500)
				if open_inventory and not open_inventory[0] then sampSendClickTextdraw(65535) end
				sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Ñìåíåí ïðåäìåò íà ID: {FFD700}'..alt_model_id[0], 0x96FF00)
				if scheduleReturn and auto_swap and auto_swap[0] then
					local dur = 5
					lua_thread.create(function()
						wait(dur * 60000)
						swapToSawnoff()
					end)
				end
			else
				sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Àëüòåðíàòèâíûé ïðåäìåò íå íàéäåí â èíâåíòàðå.', 0x96FF00)
			end
		end
	end, logError)
end

function swapToSawnoff()
	xpcall(function()
		if cef and cef[0] then
			openInventoryAndWait()
			wait(333)
			local sawnoff_slot = findItemById(inventory, targetId)
			if sawnoff_slot then
				if sawnoff then sawnoff[5] = true end
				if sawnoff_slot == 3 then
					send_cef('clickOnButton|{"type": 2,"slot": 3, "action": 1}')
					sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Âåðíóëñÿ ïðåäìåò Sawnoff [CEF].', 0x96FF00)
					sampSendClickTextdraw(65535)
				else
					send_cef('inventory.moveItemForce|{"slot": ' .. sawnoff_slot .. ', "type": 1, "amount": 1}')
					wait(333)
					send_cef('clickOnButton|{"type": 2,"slot": 3, "action": 1}')
					sampSendClickTextdraw(65535)
					sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Âåðíóëñÿ ïðåäìåò Sawnoff [CEF].', 0x96FF00)
				end
			else
				sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Sawnoff íå íàéäåí â èíâåíòàðå. [CEF]', 0x96FF00)
			end
		else
			openInventoryAndWait()
			if sawnoff and sawnoff["textdraw_id"] ~= nil then
				if not isInventoryTextdrawValid() then
					repeat
						sampSendChat('/invent')
						wait(1000)
					until not work or isInventoryTextdrawValid()
				end
				if sawnoff then sawnoff[5] = true end
				safeClick(sawnoff["textdraw_id"])
				local waited = 0
				local opt = nil
				repeat
					if sawnoff["textdraw_use_id"] and sampTextdrawIsExists(sawnoff["textdraw_use_id"]) then opt = 'use'; break end
					if sawnoff["textdraw_put_id"] and sampTextdrawIsExists(sawnoff["textdraw_put_id"]) then opt = 'put'; break end
					wait(100)
					waited = waited + 100
				until waited > 2000
				if opt == 'use' then
					safeClick(sawnoff["textdraw_use_id"])
				elseif opt == 'put' then
					safeClick(sawnoff["textdraw_put_id"])
				end
				wait(500)
				if open_inventory and not open_inventory[0] then sampSendClickTextdraw(65535) end
				sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Âåðíóëñÿ ïðåäìåò Sawnoff .', 0x96FF00)
			else
				sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Sawnoff íå íàéäåí â èíâåíòàðå.', 0x96FF00)
			end
		end
	end, logError)
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
			local wait_secs
			local diff1 = target1 - secs_now
			if diff1 <= 0 then diff1 = diff1 + 3600 end
			local diff2 = target2 - secs_now
			if diff2 <= 0 then diff2 = diff2 + 3600 end
			if diff1 <= diff2 then wait_secs = diff1 else wait_secs = diff2 end
			wait(wait_secs * 1000)
			if not work or not auto_swap or not auto_swap[0] then break end
			swapToAlt(false)
			local dur = 5
			wait(dur * 60000)
			if not work then break end
			swapToSawnoff()
		end
		swap_thread_running = false
	end)
end

isInventoryTextdrawValid = function()
    return inventory_id ~= nil and sampTextdrawIsExists(inventory_id)
end

clickInventoryTextdraw = function()
    if inventory_id and sampTextdrawIsExists(inventory_id) then
        sampSendClickTextdraw(inventory_id)
    end
end

safeClick = function(id)
    if id and sampTextdrawIsExists(id) then
        sampSendClickTextdraw(id)
    end
end

textdrawExists = function(id)
    return id and sampTextdrawIsExists(id)
end

function se.onShowDialog(dialogId, style, title, button1, button2, text)
	xpcall(function()
		if not title then return end
		if inventory_fix and title:find('Èãðîâîå ìåíþ') then
			sampSendDialogResponse(dialogId, 0, nil, nil)
			inventory_fix = false
			return false
		end
		if title:find('Èíôîðìàöèÿ îá àðåíäå') then
			sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Àêñåññóàð "Îáðåç" íàõîäèòüñÿ â {FF6347}Àðåíäå! {FFFFFF}Ñêðèïò {FF6347}âûêëþ÷åí.', 0x96FF00)
			work = false
		end
	end, logError)
end

function se.onServerMessage(color, text)
	if work and sawnoff and sawnoff[5] then
		if text:find('Äëÿ èñïîëüçîâàíèÿ ýòîãî àêñåññóàðà äîëæíî ïðîéòè åù¸ (.+) ìèíóò!') then
			delay_time = text:match('Äëÿ èñïîëüçîâàíèÿ ýòîãî àêñåññóàðà äîëæíî ïðîéòè åù¸ (.+) ìèíóò!')
			if sawnoff then sawnoff[5] = false end
			first_start = true
		end
	end
	if work then
		if text:find('Âîñïîëüçóéòå ìàñòåðñêîé ïî ðåìîíòó îäåæäû äëÿ âîññòàíîâëåíèÿ ñîñòîÿíèÿ àêñåññóàðà!') then
			sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Àêñåññóàð "Îáðåç" {FF6347}Ñëîìàëñÿ! {FFFFFF}Ñêðèïò {FF6347}âûêëþ÷åí.', 0x96FF00)
			thisScript():reload()
			work = false
		end
	end
end

function se.onApplyPlayerAnimation(playerId, animLib, animName, frameDelta, loop, lockX, lockY, freeze, time)
	xpcall(function()
		if work and sawnoff and sawnoff[5] then
			if playerPed then
				local _, id = sampGetPlayerIdByCharHandle(playerPed)
				if playerId == id and animLib == 'BOMBER' then
					if sawnoff then sawnoff[5] = false end
				end
			end
		end
	end, logError)
end

function onReceivePacket(id)
	xpcall(function()
		if id == 31 or id == 32 or id == 33 or id == 12 or id == 35 or id == 36 or id == 37 then
			safeClearInventory()
			inventory_id = nil
			sawnoff = { textdraw_id = nil, textdraw_put_id = nil, textdraw_use_id = nil, [4] = false, [5] = false }
			alt = {_, _, _, false, false}
			cfg.settings.connected = false
			inicfg.save(cfg, 'sawnoff_auto_collector.ini')
			if work then work = false end
		elseif id == 34 then
			safeClearInventory()
			inventory_id = nil
			sawnoff = { textdraw_id = nil, textdraw_put_id = nil, textdraw_use_id = nil, [4] = false, [5] = false }
			alt = {_, _, _, false, false}
			cfg.settings.connected = true
			inicfg.save(cfg, 'sawnoff_auto_collector.ini')
			if auto_start and auto_start[0] then
				lua_thread.create(function() 
					repeat wait(0) until sampIsLocalPlayerSpawned() and sampGetGamestate() == 3
					if cfg.settings.connected ~= false then
						if not work then
							work = true
							sampAddChatMessage('[Èíôîðìàöèÿ] {FFFFFF}Àâòîìàòè÷åñêèé ñáîð îáðåçà: {42B02C}âêëþ÷åí{FFFFFF}.', 0x96FF00)
							if auto_swap and auto_swap[0] then startAutoSwapThread() end
							if auto_cycle_cd and auto_cycle_cd[0] and not cycle_thread_running then startCycleWithCD() end
						end
					end
				end)
			end
		end
	end, logError)
end

function onQuitGame()
	cfg.settings.connected = false
	inicfg.save(cfg, 'sawnoff_auto_collector.ini')
end

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
    imgui.GetStyle().TouchExtraPadding = imgui.ImVec2(0, 0)
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
    imgui.GetStyle().SelectableTextAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().Colors[imgui.Col.Text]                   = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextDisabled]           = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    imgui.GetStyle().Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ChildBg]                = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Border]                 = imgui.ImVec4(0.25, 0.25, 0.25, 0.54)
    imgui.GetStyle().Colors[imgui.Col.BorderShadow]           = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBg]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive]          = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]            = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]          = imgui.ImVec4(0.00, 0.00, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]   = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]    = imgui.ImVec4(0.00, 0.00, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.CheckMark]              = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrab]             = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Button]                 = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header]                 = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.47, 0.47, 0.47, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Separator]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive]        = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip]             = imgui.ImVec4(1.00, 1.00, 1.00, 0.25)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(1.00, 1.00, 1.00, 0.67)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]       = imgui.ImVec4(1.00, 1.00, 1.00, 0.95)
    imgui.GetStyle().Colors[imgui.Col.Tab]                    = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabHovered]             = imgui.ImVec4(0.28, 0.28, 0.28, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabActive]              = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocused]           = imgui.ImVec4(0.07, 0.10, 0.15, 0.97)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive]     = imgui.ImVec4(0.14, 0.26, 0.42, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLines]              = imgui.ImVec4(0.61, 0.61, 0.61, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]       = imgui.ImVec4(1.00, 0.43, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram]          = imgui.ImVec4(0.90, 0.70, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]   = imgui.ImVec4(1.00, 0.60, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]         = imgui.ImVec4(1.00, 1.00, 1.00, 0.25)
    imgui.GetStyle().Colors[imgui.Col.DragDropTarget]         = imgui.ImVec4(1.00, 1.00, 0.00, 0.90)
    imgui.GetStyle().Colors[imgui.Col.NavHighlight]           = imgui.ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight]  = imgui.ImVec4(1.00, 1.00, 1.00, 0.70)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg]      = imgui.ImVec4(0.80, 0.80, 0.80, 0.20)
    imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.00, 0.00, 0.00, 0.70)
end

EagleSans = "7])########A>*p'/###I),##c'ChLYqH##$@;*>^>4&p<$(G`cf>11fY;99<nKB#v$u+DArEn/(RdL<A8*HOkA^01s%,>>=ExF>-DNJHe)m<-vKD21kZn42gI%Q<Z,>>#D'g<6aNV=BNg)F<Xvmo%f?uu#k0XGHp0j%&#`+/(A>tc3@Jk7Ds[6?2,<jl&`7YY#p`(*HMY`=-%U^C-A'[#5#-0%JJ<l+Ec.CG)C1FG2D.d<B93UUUUbDE-h<oY-TT$=(+j)<%*UG-Mx#%KD-0R)@j'P#MM.n###VCoE3V6Nj^3FuL]__sLV.-;FqMu+$Z?@#M(QwtL,%ODFoKB0blS:'#I8s:#^@s5Gh<T]SR`P.#[s`E[;I(8GlO+J>1om9;x^SnLpo^=#.c&gL=P52&W#$t'uvwu,;X('#lPFGK+(n*%f6K]rK0]r-w-#BXlv^w'OMYY#0]Wh#cc'=%NjN9#H9x[ul/;s%qcW3M<JpV-G,MX(3F0jClLjt(,mZw'_E$)*xO5W-VZPX(nkm`EeXZV$lJ#mSJH6R*D8HF%xc*9#6*###*VUV$_#p*%EJ)4#O>R+#4Y<U)x#I79TEG&#*oI`t;Aodu;d68%0-BkLvUTvLMUvu#6)YoLoPG&#^CFcM#L>gLCHGonP_ri0*9'>l')tP8RLm-$nDh;H0trVQdZw7Re(t%O($o-$`F@s$JqPk+6O#:)Rl._JkL.F%t]MYc7[t9)q.eulK>O]trp)/hCH.Z,J7glf.(Wa4coiS@.3e--Sr&gLU>:@-ZZjfL0B8#M'Wf>M&2_YG03K)arZ:a*p=X875*qrd7%bJL*E28]Avj>Hdp/d;S%d8Jf:l=uIvR&GkusrZMuCpJnr-Z>g?kfMob2gVC@nul+.-Z$<@Rm/p]cJ$S_Oq$7^0-3Ku'7%J1(V$`i%T$K]iS$N92mLd%@9M+O#<-A>jN4k3>uuw:>>#UJN)#2w>3#8?t9#n?/vL`Xp-#d+Y6#SJAvL-^41#*%D*M4g38v']7+M:d[;#uHo-#f(6tL>6S>-eN#<-1@:@-jBRm/Ar9f#?I:;$W]fC3A0'Y$[+-$$Y@uu#)^K#$2FpkLoiVV$1irmLC8xiLq.kO#77YY#]W;uLAlL%MmGgnL3FfqL]?<2M9SkA++IM##uk_AF&hiAlI&U`am+Ok+SOD##FQhfLM?FV.%=<)#O1OR/9K6,$.#3H$+7Mk4=,(8RijF_&3f]S@:)M/(N=b-6q/<dM>s=.$[dbYG3I5a*mxY/$$wB#voIR8#SYa,8>IPF%Iv=:v9ux=#ZN#<-7e1p.<?e0#B[`2MH[ocV@5u.$qm^7n;L+QBN,PlS016?$K]iS$]iI>/4SPJ$fTsCRr/)sdp#s+idM,W-t&pF%?989vM8s<#dN#<-0I5s-xf;uL`=7F%gYH_&6_2[$u0LN$?X)@$gHtkO2I*>l5JUPS=):F%PYTwK3u^>$P`^wK;ZYQs2q/d;2Z0F%6n<8R`m75]K>>kX)n.R3<fhERi4NH%2'Sw96k[1^%0jFi/QjFiT=B`N]qxuZO>w.is%/DtAkNYdFp4R*M,>>#&.i?#<S]vLMqWg$K+20$?SPJ$)T&E#wY6O$.*m<-^Kb(MsUwlJ&$+;nRKvF%nRUtM&>75J*(L#vNHv7vuDZtLB@f0#jv#<-Rx05%`p?#QOhKcMP>0K1rHv=P,40JL(dKlS*R?_854_#vd';$#hHG##Vx7Q/R^H+r=n)##5.-Z$>XT,.-FnkX2AXMg1d=/_78>8RC51>l$26F%cT:7#jFS5#.JPp7A6bwTqGpR*`u+?$VB*;NhL+P$=GJvLAD4jLK+:kLgoNuLBhsK$e<ig$4o-I/_>`K$SfMuLc71M#<S]vL*un?$0>:Z%SlQS%e^=Z-8]-F%n?&>G,90F%UM###iA,F%*g:-mhC.F%&@;_8w=Y<%WQuB$lY:_$mll-MV(wX.BZqr$+)m<-RWjfLc;#gL3OjulchpP^6uWJLnOBk=l:1/#R/E'M5>Ov/Zb;D%vNIH%s@:@-*3RA-)SF0MASS8#ol:xLpZs$#mv9'#ZIr>n@rU.$E-pI$@/@<$[tfe$PHY'$>qxA$Sll-MuxYoL?9U*#.0/F.m58R3`j6#QV2B_/RZYSI+Q&vPao%T@4Al%k^']k+ubPfC#Mb%O#>g9V]9@_8oO*:2JpJ)E-A?v?Oe-RE&R31#UOW-?'`u@$@itI#R8TM#w>XA#@qu3%JAws$sH+kLC=5,MgW`QM-.n+#H&#F@BZJp7[Lwct^mMVZ/&Is?=VSF%i4:/#(u;'MZ9NiM3*uOoIP,WI6%1GD>OG&#$MJ.$/=h>$:T'8/hLrG#E_$6M/IWul_qm-$04w-$9r/*#7CpV-@2i^odw>MBc'B?.jD>VH,tiAl,`1,;TRm-$=9^S%67DkF*`d)4&nDM9rq`cW&928]4a0<-C65W/(mE=$,H.%#KuS&#'`Ys-nlRfLK=?>#%G5-Mm8#&#(ZajL$*HU9igWV$RS2MKWhAMKf<q]+(N5,2xWe%k1*XD<<WdPA]A]fM`s_8&<b`D+Ns9v-e_bJ2&6s]5]cbSA3&Hv-f.:pA6Gt:#w1P:v%XYm/9>)4#UeNp#fv^^#r;eo#Z[C;$5<rC$4Osi,*U&U-tZr<-BN4>-1I,[.p(R@-PCkB-YL2[%k,P:vu]1]bX+v:HntGV-lq4cM;Xn@=j.6`<6nUu,4MY:cSH1i]GboO[A7W7Z-pb@Wo3:lR:/b(22')lR01dLJb,1#lW'5eQc.Qv$JW%C8+=r:QC>-##UE31#'PF&#0DbA#.?iG`*;G##.GY##2Sl##6`($#:l:$#>xL$#B.`$#F:r$#JF.%#NR@%#R_R%#Vke%#Zww%#_-4&#c9F&#gEX&#kQk&#o^''#sj9'#wvK'#%-_'#)9q'#-E-(#1Q?(#5^Q(#9jd(#=vv(#A,3)#E8E)#IDW)#MPj)#Q]&*#Ui8*#YuJ*#^+^*#b7p*#fC,+#jO>+#n[P+#rhc+#vtu+#$+2,#(7D,#,CV,#0Oi,#4[%-#8h7-#&-4i%8sf(N6I(AOM25PSdba(Wiw&DWn6B`Ws^YxXxsu=Y&<r:Z*N7VZ.m3S[5DKl]7Pg1^<f,M^D@Df_H_@c`fCHYGB88JC_kKlf;2)GVT=1DEw9arHm8X%kD#l1TK?e#H9T=]klgf'&=t(dE-jc$'WP(J_]%XiBu8G_&#E9`jV.C,FsWh1g]/2JL>To4SLmLG)_2Zucio7SecJ;Vd*5Ke-q=jR#7GBU#,=0U#4*?V#,`*9#iHnS#qwN9#2lj1#2rs1#;(02#C4B2#ELg2#TRb[6RwP3#ZqG3#cE5F#;,CJ#jUPF#A]6K#qbcF#so,th7$h5#)1'Z;rFF#;NWi5#NU`U[?5m`6rnXU%I-dD-h@7,)G_sW[Kst+j89tN1M0W0;6aR?.&%tW[)Pnk*/8Fg<8F4g7_K)N$6+>80XNH8JBL@reA<>_/onYx+Sh);.%0>j0>`1$I:o.Y-Rb+R<8]k6'c&vW[)^c/.W9g?KNNmb@KFg5#l`x;%Ti#KMt)5gN@gp/1JqUA59#],&qm-9MDgC%M1cRV[c2v?.tQW5/oaT`<K]kKO09Qb%iDGY-C_rCO(N]D=;M5-MCuLdMe8?_+;ve<CHpp?-(gWv3UhF/2c(sW@Xs(m9XT23Evw?2C_dh@-_gF?-ZwFsLtGHDO[_)]9REtI-o82OFs^g5#jA6g71=#kkE9hV[X-l$'/xqP'$8*[6T`'Z-kplWOFrnoLC*9nLe9MlMV^KwLS#Z01oKT?NdEu>-5EMf+OcRV?Y/9$gC_eDO:Y$Y:`pipL:B=/MP_sfL2BtW[Zst+j>KtN1)85na6K0j(HjO0Y*qY?.0<WgO]I.m-TPD0c1k[I-FUQj:<dvF%G/WC?i>u$Mrd211nZ/E#>-DE#7[f$#fn]e$HlPA>OT6?-&mTA.=U(1.&&BiL+U;8.:*TV[l#3>]17CP8''@Q#xmf*%*#(mBo$a-,Sc1nj::Mv)B[Yq)EK8#M=Kp;.P####c3X(Nc%'2#x;Ha</JM>#X,8a9#8s`-3kF5;h=5oL>N(e?x5Gj03g0S[:]MZ[FxDZ[@o.<]GBxi0-._>$-=-Z$sxP<-+ulW-Ih/%')Q_$'PMP-N-@,gLal,J_2IZ;%.FHv$X12t-d#[)N*i2<-+IXS%O9cY#Iq`M9e#EZ[LdF?-wEa/N4_YgL:;@E3JT8p&5$&T&R4d<-7+)X-BLx['72@['TM>dN8w(hL=QnaN'4Y][7H80uIv$GV2=(AOM>l1T2r?c`vU:L#6b1VdTixIhFo%Pow)g:mi(q4Skwa(WZKxCa#Gu7RgaLI$p#1(#%jAE#k*Cf#:<bx#G43-$'PoT$r+W@$5NbE$ku.p$vHhj$%QI%%/8fP%csHo%PZn[%n?Gb%_[X2&(FjH&iX)@&aueh&Z'j[&CnSe&T.Jp&YW:$'56EL'j<HC'57mV'5mCc'#7vr'qHA&(&mu/(LAg6(:pW=(bEFM(8D[%)`Upu(-N=6)b.kA)oQHK)Gu?w)F@ik)(QZ,*j[WX*ipBN*Ts.x**6sd*wvYv*KMH0+8ZqZ+j;=Q+@c'n+v5JA,65uB,:7(_,t=cf,(6[%-P;?0-#u?@-m*ik-FY$[-27Y/.8A_v-l=D[.u=o].m5t.//n?%/eg8:/M+=Q/D;2`/qN&q/<0T#0OXxI0n(9b0E<NX0GWQs0&LUG17EEA1fL'R1Oqt'27B6<2/B?W2xo9$3=*v(3wK^J3<6oa3OIP?4;%d,4RYCS46d^r4,FTj4<09/5-*_?5Kcxq5j4:06#cu$6nULS6WX-h6[2T/7&ViL7dFsA7_Y;T7ZK>,8WF/#8)Ke98@LoQ8m14+9JUtF9.vE>9].bY9I>Tn9K<]6:2f_w:n=[=;.=9Z;pD<Q;=dAf;c&G$<8Wc,<d#YZ<'BUS<P<1w<N+;l<).Q@=IgH5=/.Z[=BjSJ=c3]U=<Vea=`5<m=GK]#>3=`P>.,>G>K%7]>bS?5?$WvH?gL8J?#x$a?2__%@'-+R@/Une@:u?]@4/]u@nSr9A5Cf^ASi%#BECx>Bn#MPBtEC)Cx79GCX<EYCudQXCMunqC(#O/DbF9KDn.tfD:'prD@Hw*En3a6EWOF_E?YKOE`6HlEg:)*FeDPWFMRBoF,]raFDVnmF[*h<Gp2l0GWs2YGJ&7MG-vZaGV%kjGENV*H(#p;HJNKoHuf8_HKMS7I$nP-I1u]?IfN;mIhQr*JsLcwIbF3/J?j;:J7$]FJ(sT[J9[G-Kk4YsJ#O>HKG?t;K89BOKa5V*Lc`9%L-OL5Lrj&KLB8HxLO>vpLZQ>-MNHe:MXuRJMumNVMin,tMXEG)NLn66NZ,VEN)#QTNnfchNDu*(OwN_TOW0ULOMMgsOdGWjOEN8(P:6HAPwSPLP-s+`Pcs`#QT)&?Q(LFoQ&7aS%g`n]0$c#p<;h02Pww/>h=Lxc7p2dc['aX83uEP8EJY@vCXZaPb.#wos^gHpE2AuPb%<8?13u7WM=Q39<HhBoep%.GV,Bxu#fMiu5+=)##V/6Q#t-0N$b??g%/s=fhgJft[#Vxl[ft7T%d0fv#^*&t[&]=2]X)U'#@&PJ(%`o>5BvA+4LBUD3@,2)h762=Zl^&Z>5wKfLgBtiC>AacM`PYS%cK]f1X5(,2p%lq]44no%c%xG&oDO#)D&c$B0.L-MX,b)'4g&?)Z9jK2V;*F3Xq.[#@%RF%]a-q,$DY)siBJ60oEdV#I9bc2<+:t%G>N9`Jwfx=nau.qcvla+5_di9sr<iL63`v)dp`I32aHQ3pp,c*W=bF3p,kon[9c$,X4F+3hg$T]tv*#-7U$Z$:qZv$r01-M?gc,2JA#n&`I]p.$LK/2wk;0]7Pxl[Zj-K%_oIg%'U>K%jB]T]xL<p%mM%0(-6Tq)E1Tq)H3..M,]=.)HJHg)sj_gL1vhQ&6cqA#Oi-G+*mVerP'uk0N27W/A]Ub%(ft1(O]#;%nM)3$(+?v$=xd<C%Y#'+pBaW[];<H&$HGb%wlgQ])CcgLS9iHM3?rHM5Hr-MDNx>-Zmt;.neds*^oAk=-&(x9J.OX(*n^A,ISWS]h)Y?-V*xU.#WB[#nrkg0pIKF*:$8A,sE4_P>a4g7IUch2]MO1)I(.m/8JT/)Lt.i)+crS%X*SX->FT_4xq=&>HpnMnkd?E#61o.8nIxZdM'].8]45dbfEaV-.c#V#aOQG)?D3huL#iP/<W-NS$FDVQCd4R*f9wu#9<Q4fgXOv5w2^f179)DNG;(&#lE.W**aqA#uo%.3sEa8&_kj),x$aW[(btJ.mJ+J3EG2O+>bJX[<MtD'9@ufLecMW%?GY55/s=fhBY1png91q[rt@9]PHH-3U049+BLn<$l;;N'Y.;t-7YR.MiMj4'$n<T+OHGH2;<^j0Yh0q[3l%t[0P=2]xf(e$F;gF4s3rI3_]B.*,otM(LR0C,j^Aj0jn0N(a%NT/X)q*%R_1+*O[FU%dtf@#r3lD#TMrB#nD[+RlCxiM&B5KbN,3vTfu-k>`Bu4SITp_faUO<BXNAMBZ&]S9;r`FlgbOomn]EcuTRX%oj1Q4fJx:$-lBF(LrcoC#D)#V?>+sC57v2;6H=h+vZb_r$[#M$#dEX&#B]&*#fon2-Vq@9]dE(a3MlYonI@Lt[>;xl[srO#)2R@q[L2r*3#W2N$nw>S[F-h5#rXMn&e>a68RF;s%1hVs%5P9jL@RqkL>QR4(F?*C&j,VpnMB.F%/Z%L(()6v-,_Em5mmq&4,8:D5B2=1)')'J3LR(f)rkh8.:tM3t95^+4)&Pk/t`<.)(hro.oNQ8/S5)<-XC%I#19V8:9`@a`r7HGa4I7=-5diw,e5(pttKEh>QXtr.pxaLp+aKh,4A`k-*-qf`'SL8.XCcHGtqgCWx7sq+ld+A#vCZ(+.7u^$D'NYfXI1*H'CLV%I=+f>%p^F*`KPg+kTS%#&/,##';PYuD2CJ1b:IY>T4I'#wSY/.>:p[$XhE.2'TkonBV]22]r:0]Olti]dKSS%xuDV%97&8&LvOg71t]j0B,UfLHN@O($Yf>5/*C70Ch`#5Ihi;*d3.W-g#4H*j:SC#W@n=7==gV6uqU%6w+m]#=^Bv-[5MG)3aZ]4diXV-a@i?#J><j1vP^W$r$?87e.Wt(p6W@#E$rZdKxso&2:@Y5-d`>$m=b61W?7S[WEuU#f<fe_(ceoDLQAA8%H?L;IF8E+'-Ohun-4P'uZWG8'P,(11Sw<.rZc7)U/H#>6XB>.%)Yr-S*(ruS]]H.F9tPCB[Lx$)FYKL8Ba7+v1$##/5WlA@UJD3`PYS%Jj.S[tc,0NZ58S[b,h5#goP2'`=T;-PL*$'FWH6-rW339f*Ow92i*2''?m>5Mj(,)B%Hs*l+$6'8Gu8+()?W6$2f]4as$d)i&l]#sim$$?xtkWBXN`H?NGP9E)kcFi[$D#1898MS$P$/5OkYJn@(cVMY8H?BK4NCK&1hY;R@Q'-8Kxt:PBZ$FxAbN[_7u6KUFb3][_a4NS+C.H'5N'AZL&,P@DQ23%47FJ'CLX3&G>?Lg9e#9pP524+w%/]^Y@MFT9na=5x&#C],B46`s-$mkt&#eVH(#kG/X[nl23$5r$<$e)S&(1)Pfh>';$#it%t[gk%t[M2Rh(nH*)#ivBHMAwcL2N+K]$,t.p.^Q^:%Zk_a462E;$2X[?#L(l[t+AG&T>LDMpb4/##aFx(Qh5&5iOP^AMsM;8]`6D>Pg(VP&p:g4]XR`i0_#/X[fG6Q#o6Kj$8HC,2k<P154`6)3)pTpnhS+:]lWfj0']59%j14H&4:rp.b3]j06,,NDiK4]-DNAX-8*x9.')CSRl[,ju0mr.UhH;ku1;(JCcw`-HT*n[t'?-Vd.#d5/eD66#bOb,Mi(v,2e4;0]Ksu`Ma$Rq$,g0i)NCI8%M/E3.*m-B=i:SZIC20kXb4T3:,8>M^qmwu#swJfLZo5Q#Dk%.$_q'N$ZCD>#k22j'Y*/j0Pv3@TT'?b#1&hqWQ6RA-2sU5/xA[8#BP?3:@[L0Em?5</]r:0]Gdu`MkNPW/)a0i)D<LMe]j2'#?8M0$W:O$MT/AD*,6420@.XSudZOs-)^QfLPvB^#Wl'##=(&Z>S%PV-YMf4][R`i0(KFon(2Kt[iW2W#SHh0MqN:U%3+o0(pPji0ve]6E?MxKYpFEZ[er0L3bB:a#o=]:/:5Rv$+ZMaJDx#.Q)`mbr:oEZ3+BdX1bSj#5BW$0>ditfCk&r-H_Z>8MnJ;e4Ml-%-ikm&6LC@>#KG'##9^fERCf>M9a^U,M;L)W%r-0N$7B:,2ex6-2f7;0]wXXM]fTfj0w4Bs$i(o,&,uus-xR^p7B@vr[dEYf%iTCK(wFJ>5B2=1)manO(m_G)4;R[K#M8OVuA9dPJAb/i9o=uM'wX15/D:L/#1KmtL*4#&#(7s'%b_FonjJJt[uW2W#&&0X[rl9T+5J1T+mE(gL6F`hL34lX$Q^9g)c*.e-v(2C&aksp%K2biL'-,A#0kn5AqfJo[k%Sh(,$l@5FTNI3+M>c4_T^:/0MHx6WHL,3l5MG)FQhc):AN5**3777X0(C&WDV=8t@2[T/5Xx+J4]]4Lm^@#%kZd4aY5G*<:j.cj8_[uS4/4#NT4oLm=TnL)qR(#g7Rq$EJ0jLP;U024Fh*%'+Jt[4QUH/_/rG/DYnhLO-@@-s=Ed&VipJ2-bOc/24]j0s7mn0V4`D4,a+T&?uV..VIQlLMmFn08W9j(3R/N-4:a..)fGm8Nvc<.A]R_#(OL,3r66GM2<ST%F_@?,:?mD#@`KG.>6YT%4>)C,q+0buOaf.46?'5S:W](>kU,>P2Qjf<:7U]%D?eENIOT:8cxlY#s75K3Cj&VAb1_'+):/G5a0tE5M8Y5_-e&KWcZ?T-Omv5.h_kgLNfn,&jgWr$1Uot[5<;N8xUkQ'8S:ghocft[l8sm.i4Sg%j)sM/fE]j0kgX,M.RGgLc>lu[_)U'#F5GJ(v@A>5BusT[vVeh2JADD3J#G:.8BXq.TWDc#WTjln92At#hxWWS,:Q:Q(;:R#/WmoIYeGB#Wl'##(L6kO]?o(<b+*N0k1xl[F;W)'B9@hLIr`-2x8Fon#FB/2i@;0]1cXM]Atk?K<I(hL?k`K(B&uq&_$aW[Rj-K%mBr;*<13N-2q&T.?;-x6keT`$916g)vJ&R1#nZS'62Cv-1dVS@cq5m'hlcL^>@rC<bgMoN9MUL=K9$2O>_`^+j_ZI:i,9]V?x-.H&IZX@csc&#UPW-ZvLK-ZRgU`3wOg4]oR`i0#rmQWXjKt[Ai/gLCa4<%,q:0]@Gxl[<;i,/kUmh-xaP6W-51q[?JQL--JQL-X'?=2*vZO(/Fu?5SoJL(vcMD3/r[H*,5Rv$3+tD#I1F^,`(4I)RSTj11_1+*pfS^-ai<'.:M?x0cdQD#SeZ:2Xo$s8e5SI#tHD%8[/[DG4.b&@R-YTfobclABWE/<dm?>IZfUv#Ss2a6:3%??MS1i^.(WQ9^l6>#gm/S12;-e>i*Ll:XV*;&;,>>#7`###S5:-moV4;-sZZ58rkis[fW2W#gAJt[1$#k-^LqZ^+]$[^pH7g)]GMG)*uS=Yq=OE$Y:0ltk$G6#vbT#$uMSw9s=Uw9^fju56cCYG*l^jLxro>2LYb55qN8mLo=^32isEh>)^1X[-e#B1&nCd&2R@q[g=@Q/DM0W3xPGj-I@9Z-(^3.MuZWmLs+0322)1pnj_3O+Q`WK(G9Os$^nr;*x?>H2#,:D5L[Z)5Tj_j$0:.T.,x5A%eOo$$wHeF4soq_,W5MG),):q7i(6g)@p'='C0@FNm,8S'U.i?-e+2PfC;&_-ag7o'u/d70<D(l<58<.F-na#3R/`7<8N@bu;&iI*[U,5A6Q3/<XvF(6B#a]+sHdm'a?/R/Fr>BEqJZ#@h#C:8a.M;$s+#K3Fma:AR>QT8aWC?7fW6-92wLE#kv,G4A%*e46JF3;9s+D%TYg4]bR`i0,WFonVXkT[.1ZvIBoZY'?51q[qb`W[@]'E'8`_p+oB]T].b&o8A=_'#.NlM(;97A5x_t'4uDX588E`9/(OL,3XS<O'^F.j:Hl]G3bYu`4JfIT%o,RDG(34.@Wb?n0`N-`u7dZ:2W^'s8bv.eu&JD%8Fo8j;Ii8>I8TDau[X2&$.v,<ASN.R;+L?WJhnFPA01aQ9W-Ke4LYIS@i*Ll:8`i/M'E1;?sgwq$cB5Ls_;Mj$`ISet8#V)34GTE<SMbwnr%tI3h;`ah=gCp#DAP8#Sue+Mu)YY>'Y(X%S7LS.bl$-2S(=[9=I/X[gwb,&lgG2'M&@HM`1Ba'5ON/:r;kM(@_BmgOL0X%XRhEG4dSVQpu2T%xgfi0#/_f_)5###,2jc)H2BU[EJvnn+jt4SMSZ([C/uXlP%5<1iMMS$VXJ=#-Mc##(3Ch$;2xl[c`Mj$>D%m-*b6LG]H7g).hA,2]?b9ua[d6m2%luGjmC>#FtHm0UY+:D&[Qu%p1jc)Fd7%uri&,1@sw@#.v#PSl4j9DPL%##WxvY>`C5;-j(g4]lR`i09;(pn`,Jt[pMAqDM00X[0's>)T>tiL,1f*3a'1q[ok%t[,Y=2]qm8_/YtWM(`CXh()A?W-o:]^-'nC$%hBE:.OM>c4-U^:/]9rI3M*7Z,xRMBd=j)'-dfk[t.GYA#-Yh^dYUa<<rq9J)2V[H5p3C^-&aD(1I]o'N'(.i91OW6WW/5##sKvC%u_=.#U=#+#bs#<*(`+X[V,>g794Ej-n2&22@'e'&nSLt[@Gp;-'q9*9@U>L2PsDZ2bB]T](LZu%#CKO:bEWZ6[1?j6VmfmLY:xiL,:Y2(1U)C&NlkZgp[.F%,eamL;.Nk'GgJo[n+d^?q?o79mkW>-s0b20f35N's3vr-qaQR*hND.3C1]T%jMD8.,m@d)i&l]#X0fX-wnQ>#4(XD#)W=P(wE/[#C0U'QZij+iQG%^N$5O:(mc(2:Y&R`J*L1[8Mf@j>ZMneOaZmmk)a^-Y]xFQu7,WUP71G[1HT38:)XQ*1RFY,M5V)/c1cTNo4RYIP`m%1(8%mJ#8oRY86A^w209Q_@0?<j_stEqCIS:7ThvDS#Vu9.*v'gY(xJbr7R/8X%?gmD*0g98%H5W]+AI+T%EmZD3f>Jt[rg2W#kMJt[[)U'#dIfC#lj^#$&uQX-6(.s$/ihV$2XaRn%YL`WMgpItqH;ku#D>b#sT.>/jc53#ZB7#M^qA%#nvK'#xvnu/,WFon*8Kt[CP5W-h',HtbmU02]r:0]2Gxl[>[.W*V;:A#>9@hLIJ1?-nfh/%HH$B13XQv$54q9T5pb>-i64kO3S=wRClhA&D#^ZnLUf^-+:OdT]9Qs.L6H12bv(KE8BwS#0b)D5x]:?#X6h+4KaM[$aLScmmg@K)fWJR/q.V@kx1XW/q7V`ls%5R4A:/#7Cm%B#X.t^f#/t^fGKU`3D)c%#gk>^(aACp.iW2W#9.V0cOe0pnCT35&PABT'i,Te$8k]j0hiNqKWR.+%7_1+*E/aO'72Cv-B;krMhxkxIhnmr:7Qwb#BD3Z6w&Rf('4k9$SoZI-u/1;8#TbA6_`Y(+sVsNOH/5##?l*J-J;Bc.AL7%#G7H&%^MkKPA&+H=9^IIMG7YT%-]70(e/ji0xM0pnML/RN&Zg0:Q=Zv$$ZT88Npv5/<iK-OmF/Lu9ov_>S8<f2h)3l$pG9.u`JkTVg%B)*OR#Q'S(4GMN/AqLsx2$#+GcG-GU_D.g`Mj$n%Dp.fW2W#6sX$KK[F$K;R+:]b9fj0++MQ&`2Hm#2&Go$C,;d;SbV]-6n@X-MH)5f=tV]FaCC##t;,kuKU0G26Ec(.A4ViMGZ)mPK?YsQSFSG;XarS&0M)=CTg3bN?<8b-BmVwB*#(##EW7wgi3Wf:Olq&#k9Vv)[TGa+M&OiLM)G-;bXlS/Ak3j(V[7j(jn@p.;YXM]eQjQj?ddr%)5[B#7'8)+ZP&E'L',)#8=SH+R<><%]KJk9)Cc)4VF3]-HP7T%@].A0cdQD#xw%>8btnC<(9)p9@C;E5I)ro@*v104VErGQp+.J5:A+W%gU+=?gM4.hac:%6m,gNu;iQ)69-U&Qq5228E2jW[n=xG&^U`>#xVT5&nT)$$c$aW[-1KvR-_YgLH.2)3K=0q[^b`W[h%/K%;$Y&Q@dnO(D$nO(VBlD3;qfrZm$7]=BjlXc[gqtY$AJ(Nqx5W-'T=kFe)sx+G_J)<*G4[9`LYm$L]_xL*db)#/Cj'MG0'%#qDF^(Uh%t[p1xl[eD8S[nXU:'Z2d2$E*J?#:wqgLNFT@#a^Dd&SYBq[C/9D5F8g+4B`)B6&Qrb=rVb;/V3gu7RlTd4Vg2guP(/Ptd0RM7$RUA$,9EbJuK>K*35P$Mox2$#;.a..Oe1u7]*QUr@V=u%Mw@8%J=pp#<w2%t]eL=ur'YuLUI^d#CsQKu/V(jV];MfLJF-##kH:;$$C2&.5YchM*:jb$.:fj0qV[>#_88S[P4+n-tdoq)+C]j0P8+KNE#oO(l?rDfv,(Z>[do3#wg2Z$+j>%.:MPhMJ9`/%%TX5'q4_p&'w_)'gMCp.xO=2]QdNw9)QRh(jFV>5iUch2K+rZ^>^nO(&D:8.Xx?mk;>=S[kaW.UrtCg$4Fq3$h442$WG.d#th]gMI_?Mp6o>s%Ae>B6gM)0(-k.w.+_YgLc@4p%5]^;%4,oA#K]MqL@e*s##=+VuE)P[2#P#Bt1eP^tn15##aQUV$r@/j>Ws`aJC&9.Q2<A%X>+'<4*Isb1`Sj#5IuK'>Uo^5+Wlc;-Ok5d.CL7%#M7H&%1IJt[QQd2(J[0pnnYJX[UfxA(qK4u-OCHM9]4s20>Q-/Tf4aKu5J4A<09.bu(5/GP,x@fJgv&q#aKwirK@[Y#Pr2cV8n+_JGHu(3$Yg4]'n'-%fN,_J@wJt[7Gp;-WcE/%Zg0X[$CShNnZj5,hcL4(2Q3B((C]T]>0?r%u(o0(jqkebo6oR9g?8i)Xq.[##ZWI)$]K+*B7E:.TekD#iWJbGWlbK&Go2]Tk*8dW8M#NDpdA`+@j^GK9;MOO$cnF#)@;G+_Yeburh@.s2r<WLBAukfMq)r0['?&4u@XBK'Qr$T)U8X-7mw`*xKT;8`85<-Gtpk.Ke[%#b+6&%;[SX[p(],&HN3eM,OH>#.:)T+g<An'+EwA(%#f0(23Vv@<j@iL%Vsk'ZP&E'P`6Y[L>W)''wsM9cE[m0GKkA#ZSqx&mhYLS0KM-Ha,4uuKd#Q#cE$G4E6dZ$$)?fuJ.^IuS]4oL(QCw4]<tA6aE7VQM>ZPJE5K31&`g4]#S`i0pAI6%1IJt[1;-L-<)b06=MtD'2S$)38;1pn_xT6&_kj),v$aW[[WLj$:*DW.JZZ#2(.-Z$81s..`'n1MpX`+=`9Bv-@wjn%BheX-x5MG)^nJv$2p0[#ZVd8/EBUI7+_:aupn_XLO,iQ58P=W%L>ql3l),ASMapBH#7m%HfBGN3gHS%6&PHNRJBKF*$__Uh2tlVLnu7]8th$##DsC*M.w,wLqjd##j6q/%GL0W[[Gd2$)],-0bfq,2c.;0]4Kck-pN8q`Z@3p%b9=W$/LZv$NFjK;i:W%$Z0fX-wr;O'8pq+)N#IZVdS:C$3.Qt$nRxE@;Bq%4pm3r$9xEontS-IM)@NN9<OBt8U9oS%QiDb&,CEs-lXeR93Jc'&v#-9.^tvh;j80/4^A#jDsIc*T+NAA$=0Bl6<W3C$-Omf9o?9_Y=e=Jr.2PYmIFUv$<hd9i[Q.?5fAVD3bcdC#?0EW#,=HMloV=q$TbSI$TvWk4Bm+##fYMk4]RPuY70A$#_xe,&)JbQ1k>qi'$&;/(]mii0)vgpnr?nMN32w'_tkac)k)W)'[Uf5#P8Pm#8eZS[3P_07+a<,M)#^S[q:YT[KG;Q#6$Pm#CKaT[dFK9b+IejMFjYg1GvWT%XxUR'9b,'tCcL7#2=cY#9Ra5&:.3W-m-4@'e3TQ&?_7U.]O3H+R#0(/Ts?g%a`'@gPDeC#poXV-nVkY#vP8X#pk,ruhXftu`)ssuh7)>4$U<dt#'kHtT7:btI.>>#a5+##Tko^oeNCG)GEo;-dTHp-Zh49^DD4jLEu;?#=o.T%Q3$MpXE&s$e]BG;CF&a#vcxtu:(Ti#&G^iu#9sWu#Od_#O8H&MT-q(Ms6&#MNom##a?6K%CSNd2cl$-2d1;0]'`=2]ak%t[cS-MNP^p5#PF:ObKo0N(Re7>G1RLruX$'Z>$'wl8uW_@OtcaE[[72mLA4urLTlv##T$P,/r&FonXGr>n5,)-2b&ji0/S;^=qB)s[)]bp:2XZV-:eS@#FO^&$P+I<$YU57$_W$^4aZsqdO[o]%S=Wf1?';^+`mp%4X5(,2t8kond8Jt[jd2W#g;/X[a'PK%?(7<$3^6)3$^Kpn1.L#$I$tr$I-<rTAWdkK=1#cr`wG3%I*@+;B5n0#]PEMEPL=F3>ndseGkPm$dQg:#`;iu5GRZ8&.Mnv6``h,2$kiEIsB?FI-'vj[i./0%T$Rw$FN^P&C>1,2r]dEN#RU@-r]oN/hmxX-c_-lL1RXD#PvL*M6[fb4vn-6tP04k3??TQ$eE<)#J?O&#e5/X[fYQQ#vAcg$=lET%+?Rh(B>DM2F0CD35x:?#l+*<W=8;muv2+M$_0+AuYhPl]pj@>#qf4>#0LuUZ=Q?D*T7O0Y6.ton*e1p.^ML,2<uInN2]5g)a9P/(gb'VZ%t6M0lOGM9#$3Jh-F4R3x*9R3S</Q'^*t63's=fh>0V$#stC5%P[.v#L%K&#d=p,28m4:.PFwAWmaMkuP7YY#?#'##g0N]kod&/157h4]lR`i0#/pt[;>xl[1W2N$43S9&osBX$A;.^1YV,52?YLpna'1q['c`W[wNVv)Vbfi)]+8o&XhE.2/;ki0[uGJ(Q/ZQ&^nr;*f[-&/%gJo[E5Zb%8#gb4K)'J33t4g$NC[x6=J))3-[w9.LK7T@FVIg:nZAX-'^:@GH1GSIS/Cc;7TN8At(@cRn2`[,rL*r]3t`c9i1td<I?gL7*w3?CB^-#7NQMO'3ulJuuA<J)IBv-P4%As$VH6_>`N<$Q931g(Z:fc)GsO`<X$+T.dDot[ln^O.0&Jg%#PpP0fEO,*Ag.^##]dBf&Cf2-TAl;-Zo8gLZ0(U[RP@m-IGsaeFNPu[.5-F%d6DM2%lB_4PNdcM4Y(u$BKc8/IKo.*1rSfLb+Q`%7,_s$6.(j%B]'R1BI#5O;HrlC)m.P'_H-p0^d7A6Pu6@6[']W$Vgn[b$rXi(0sSf(u]S70BUks$LG^%6`HNA6>4Rs$$),##V?uu#Ipg:#ib+.<(0rJW%=5,MW5d1%aTNeblPhq%9,n)3j<VgL=w6+<'XcB]m-i-Qnj4cG7CPm:6TnF#_C:69>p3]ND1s@tfN6t.>Uu`u3QeM;rw9J),'x+M-2a;$X4fc)Xbt1BfV(T.qlot[jjE+.WvA#M9U;N$2C]T]'u/q%ACN,8`rv5/pBf2-`%xG&uAvQ&0oR0(.)UpnnVJt[,l%t[t4Sh(rT*)#08.IMX/2N$O77Q/sVeh2+$fF4KBh^,/lA_4%U#*=5>HT0ix=c4Zwkj16pCl-0aC0cj]Aa1sx*W%&,t9.7ps]NH15;8shT2)hM***mve<eIJCX#xX3u(j$aZ#@2N:6b1nhM%lHY%7xLZ#U)r;$P<>)#e]K%3F&P]kbbLS.n4g4]gR`i0D,&nj3OJt[H_a/1+ji/%ow>S[(-h5#kL.m-meB'f>Xji0)mKpn0C6F%FHY%7vw#=&>)]L(.M0+*=<1u$]::8.Jq-0)ks2EQFLViMG'd_7eB[.QbkFF=#aG8/?&w`u(1oedv:&F=rdREt^7vsAwtA'J7APJ7u$U1($3=L#=4?#7%uZB]A1xM0lE%m]1$o(<0/PO9#M0N(6.YfL8XR*3omC_]Qe/X[l7Nm#%gVR&SRN*3]1?7&Uou2)q,Te$1R]j0+vh-Ml^/%#Q]mA:`*i*4K;gF4S$]I*.;Rv$o;;'Q*1v9[2S/kM6,g41$X'lo$=99THI13<V,i0ixFq3$]7Bs2T?3hukpUv#)a''#rA+.#f5E'SM%$kLlHi-2u[g*%>qwER<>3*3@JJ22]r:0]6SI#1'uMp+0(,Z2uAvQ&JRx20u$aW[R8Ed&falHdfgki0b-=M()x=?5wkDw-Cie&,LYS#5ieMW-?aA*[U7#`4ls/c$oV@^=UC*j1;K1Q/SV>c4S%]]4^Q>T%@9r,FEjZmCI8V2Qe'Qm6Nu=w$fq)F5n@*G<7u]kD3sQM7J$$21Z'A[#;`ZhWQ17Y#2Xl4<LQi'>ls'?Kr81>$Jx=T^&`>_+01Y;9r_pfLjP_M'WkBp&@t=)#_,92#$2(r$TT@%#a'3b$9SaE3Ww(:8WocG*jfYW-/</4rkSqQ&-,u@#[0h/%G;1]&Pe[Nk(,m]#(o0N(P4vr-&WFwPpi34<$>i[8./[TV2$qW$VsN=c9]QT8xVXx+,wKp)Qxj9#T;Y<1]a0pI-l68%]Vf4]>LSZ$NSru>EWd?$2S$)3&dKpna(#+%-hh,MnV;;$ph:W6NW5x#^1HwPA&rP$W_;qtGV0:uF5YY#4fg:Q_iZ-?ckJM'S//S[<d8c$.1/X[qIb)'2.7m'^1tjhgJft[.Vxl[sw#B([E/L2l0D.3(M+F3)d^;.JewJ4Z<b'6)rlXl=&bah1+qV6vB[7%cuv-8)4JDt>JU`<wR^*[&Dr3=AgnO(J*CD3QW'B#EC#GeZ;Asu)-b[p;<bf$+EqL9MFw=>;?5GVH6ek=v&loL524K(BY=2]w4T;-#'6`-=qa*7&&E)#(7$C#^((##8KO]kb?6JCf4K#5=KgG3^w502';pt[uF=2]@<;.33Q)12=0oi$/^6)3oQ1q[8EU)&:#)C&:*M$BRY-F%EHHJ(kvfM0O+;D5)E(N(d'D?,GgJo[2Y)C&=m7?5FTNI3qu,l926,+%7Y.N0B4vr-OKOA#&^X2CPde,;jFke)4;fh%wA%%RTtZi(^ZqW;a]5YdT6m,6(`<p%vO$nCsjtZ#(@tG,+ZYB,'uMZ@q*X]#([q2)(vP<.jm>Vdg>2u$,?K@uC0.gL*Mf(sw;Cd*1k0_o7GNE3Bkg0M2d,Q#o#L)+r&Cd*+_fHmvc0q[OGT(%<m,F%e3<qiEw_hLp[@Q-=Xlh%n&7>_m<&d>uerddReHM?L6rNX70(DPNi3]#,+_I*ZtD'Sn?%29>ug>$S;]AB>6$Z$>xd;-'lXv%j2T2(06g8.(Y=2]SQGu-6uOI<prnZ7nU]aJDjwkO'IqIU6cE;4f.J:B>k%Z=B4GipkvLLG,h98M1[ma6SmVrZxHBv7_l5d.ERYJ$v[e>1bpB'#;3f&(Uh%t[%&mD/t5h5#i]Ys7XEe<&5E`hL/9=+3vMBpnASpQC+_YgLwgrB#mvt[#OEc2$)DMp+:6Eb$HdsJMbgdh21W5T%+)4I)([xf.>L.*+;fv6)oega'(G,>nK<BSNF?V-4rSWE*mj.[d$+tu7sqgM)._`:QS^r;0IGgeu4d^W$58j`#Z.r;$MBYD#M`u4:;px2`&Lu(Nf3Ks94=vr[cIB0//MX)'1Zx#nYV[,&4`2f',(ji0,Ggt[NkKW[N&e,&([c,&pa/W-.jZHdrkBHk<.T?5oWj;-Z1U1&Z7#`4Fo0N(=O`Qj<g#<-6GH.'sw#oN(9DC._<)j%B`9n1'=OfdLjJA2<9?r%BRCX6F3=E5,i#wFaKbW@BHYuc$rXi(U<1&6s&ps-/4DP8Cd0^#IIk3.Vih:8wM5qVO=dTi=dVEeFU/X[gg)B(wwWm#2^a#)gb#B(t.?W-7RqGbSFw[-v:Rv$nKd>5GLZF<PBv&4BR:p(gkeLA8.2n+9m4b+U?<kF`m&##`L?kFsvO`<S.@'#V/6Q#Ete2(fP15i@u@.2*^konPd1e<&crS&l</<-cP=K&00N216oJ50S$]I*4(,Q'cXRXf'Uu#%ZVd8/q*eN8pE_auBVY>TCsVqEeMnH3Ta/w6uChKG(?3rm%RVO;ZuK32D*PTLWw@h<;KA*+(4#BGO,3>Kp3n0#uQj-$giD]bdr<A+i_59'-ecgLkWwt$?^A]$x@Dp+H_whheDft['Pxl[k=o,&u`R*-EmOg7o^]j0&Hc,M0g^%#%$k5,*W>G2#erI3HZAX-)M4I)5Djc)q*KT%B>^<ZZ^R[u[vC)l4wU>?E3xB?R.ZM9UuJ;.#F*Nu7)YK;r.'F*f$%s0NCj9V(m'##OAP]k61o-*T_`W[tui/%vK#0%U_-&/`9]j0a42RW4q:0]wOxl[JJ&E'ge5^(xS;R&#q#1%uP'U[vfJo[wuYb%5#gb40Bp?T=G>c45C.lLT7M*%T<r%Ou<BT%(@hh%Z'a+c;g2'-YEQVuxo9.*7/Yb+`?Mr-R.pu.@H(?77QrhLRXZ)MZNP1)0iqL3X;U_kC95/(^jnNkS6`[tJPFr-K1HP/eaeVQaYKp&0uuL3Omhpn%f)<-c>%Y%6nE'q0'uk0HW^.+Z0jV$<kW`a,3epp]*UL([q_n[GoKl][fLW-<ni7(:SQt$VSCW-O8K/+<x<F3pNWh#rw:8.$Z1T/EBR4dp):pufu'MetaKUu$^wSu#an8uNXoPut8<+M*ih%kqi6Y&?U,u%,6Rg1YJVs%J[-gu'mDVlV$AP#Lk=>#qi4YujQ3f_HoD`3-O7>G]+(##D9O]uSkK%MT4e##L*_/%26(,2akdC#S9w3:akDw$N<Gm#&3=1)1INh#P*SX-NSa@t]O%Ud_p.F/wVmRtXvq=MmoI(#$UTsLd*0O&HNUa<I2WI3?T:1pjd(oe:D5h#U,*Ku&uf-?-iRf1Yv;^+jpMcD+'?02=>conro%s[`n7T%:XJt[ta2W#<i0X[3]f/%2`xS&Yw/+3-E#:&c9,B-/%aW[B.B^1S$kN0/4]j05Mki0O-:kL$^v@5O3no.mHf2-t`6Y[Vn2T+HR3N0Rp-K%0/FM26fwR9WPsv6wCjc)0hD0C/[w],F'aGMpC(p1JUFb3p85x6/-*@?EP+24L-r9&h3hX%h2Vo0LxWr9IINrK-:Jt-Pr0&RbKu70PoOcQ9FdV)2_2du1NK>.eXH9.W<M4fA@W2)a)tFPCm<700%<$#stG_#BG^q#=H=&#=XI%#t`l8.#^Tpn>.Dn:gGQJ(Z1QM9Zv:O%K_N?MGiPV-1<r%Oe$4Q/63q5#=bxG/f_`8.5kn8+ucN#5mj;^(>R:U&ed>,3h(l5&oPs5107A9]qc[h%BNi#%:%aW[ShLs3-`sA1RP'U[pfJo[m,Rh(AGnB5C[HN(o&cgL)+>i(>mLA5*WTI*qhF<%48Cs75Jem0jfE.3-H8gkINwq7DV=gLPxF)4L<Iq&g*L=%g)Do0L=To:E1*rK0=S9.Wc_[6.k6_>X3ox8AqF`@j.>_5e9>/(ZC/C#]&*)79xND=V(A(jb-m2(nDG)45FUsF&?R&#tF<`W%BlfUm`su,<A4S[.Ii;*mNbW$N4w)3fned)vWe8+h04W$)>Mj'=rFPAg]Zp.Oi-G+<.)AbZ'uk0%oEi1g8&X[Yah/%?6d,&dkK.).RC#FO8i0,fK_/%IKbs$t^]T]6f&gL6@IW*8J@['9ZTe$=97O+q;tI-:1-N'0?5Y[DDK#MCOem/'#,P]bI,c*Ru-20>Zt8%b=^F*b:6;'a;Jo[vlRh(jiOu[g;,F%.ar?5+[it6TOr_,tq-x6,(tO'DO=j1#.,Q'0q^F&Mb^b65?2XB@2#K3u'&x&Pk>_756)XB@&Kj2Kx&AXLwvK3]mAa+qmjN9Cc=Q1a>P^,3UW$#[jj1#25Xa$'6>##da:N;'EDikBS`)3$d^pn5I>##cSMj$$7Kj$a<J2&5$$U%o<N1)bau)(pPd]O,C2rH$4Gr6%5YY#a]R4fR:.T%h0IP/A[h4]jR`i0$2pt[9>xl[26Xp+-C]T]K^Qr%Rep/2qlot[:'xU.jf;N$hAiI2bE]j0,'?02]r:0]<Pxl[OTjb$YoS,3.AJo&bB/j0rRH*39[V(+cL3d*t3T?.<YwD0a[0H2NZ)F3Z]B.*,otM(k'Jw#mC].%6hf7Vv<P#%kEDSNe(XL=g>R.Uh@-Q/cLp6:i&PRN6HLFGa>;lqi_&SM$5^FifH_Eu8l(^+uEL4fmH7eQLQ*;ZV/$kkI=n(<V;XciH?ru,xTfh4*/HA#[-B+3]kkT[m62Z)ceI;$Wks*3&*j-E5(H@-M'OiheDft[1Gxl[/_%<*S)Re/,q]j0:6O4'?AVd*(<Tm,M-4r.v3]j0KTG$gljrI3GU=#GX`,g))LFth5$9Z-+#HjBHuGrM9;9#@9`Q>ufV,`#$5cY#+K2QNkJdn#0KflA=98e)3HLa6mhGMRn,kW'mW2Pf%/5##c.EH$&+O9#DoA*#ic[2-Ahlx$.lx22#KtonJ1P325R<0]PPxl[SI%N6<[n;-)b_&4QcSh(LBAQ0QhaX.ajsM6O&Qm&DP2C&#v#R]t*)`+0FU'#<vcM(t&S%,p1ujLHZO,8fw5F*]>ts%Dwwr$,xSq)q2=1)c,H`,%=tD#ae_F*<KA=%lYWI)UArO'aLXQ':]d8/*Fv;%QTWjLKc7C#OM>c4L/96(^G8f3*Y*T%h=L>6Nn)T1uN_6:a-?3-doF?2UgGq]Ug#2_oEU6:kmk<@t=I),[9W0M_a@%/SjP^6nxes.O&i;8P]J?$L;RD,X#en0QZGQ^5/Jp]m*:6:nA3C&3lA'1u9C02Z-/#6P0j52gnkT9lAt:6-OvN1E=Ic40_2O1VBMfLPX-##fPUV$/92,#GRQR;QP]X[vCX)'tv9=$O:**3uf/X[&e7W*-=-Z$@;k?%Bn/X[x&s>)WgQ)3ukKa'qB]T]1=0q%7vZ)3wG:-Mr%&L(O:8.*x51A#sl@k'N<Gm#%v5W*VlCa%BhBD38gfX-v<6g)4o0N(%kH)4)?sI3>cM*%F72:sG7jC#Nu-Uh$ws1TC0+trl1shpl5$A4:+*AR$Nm7e:]h?RlRPM9YTv;%Rtl+DG%Ap&M[3;2#^Tpn`vii00:SC#&?gw#P5Z20WtbFi$AJ(N(([e$bq$##)OLrZ:po]FqS]i9BdT%b7pV12S.mon$nlT[*f^&(ow>S[b-h5#Q7=[%l'm6(=#]ihK0Zl$D90Q,:FMX-*-4'oSo)C&2p<O+(fNW%u-PH#Oi-G+FsLTbe(uk0/'0d8<9@ga.MS'tF$k$`h:DXsN:pX[>8P2?vf2g)Zuicar7$Z-@c9O;vm'w@1K&;QHK4g74GQ-H/Q'U[BFT#27d^6]]d[B5GgJo[B1Th(iUC_&&oVqUObax-wSucc#b*r$+A,Z,acW2%a&g@8S7ws.J-8M)6pdA4r'UfLbC-&2xXnv$Nghc)44hv-UPEI)6OMK#avdD6&))ulCsCu$#M7MT#N$Y-;NhH2Kmn=9WRL^?5i;Z#d0_u.W=A`9g[w4gfKQcMWpLK(5`iT/]<b6&VFs=c)K2L3k1uZ,QL#RG)m#G*Qj._+EFDt0.j`h+k+Qf6qA7V%%P?veRVYL)l8h:%L3dFF4MW$>3Kd.<Ek`R'X9.1(%7qQ*:/*8&VkuN'jx###]'mR$n.?Z$V6>##Y>$(#_#/X[cG6Q#u6Kj$#qri%$q:0]&wRq$#fii0&kp58-ip/))`OF3W7P)kp&ZQ$,ot0#q3n0#wWj-$o-s]F:lIJ(.l+878oWW/tEVv)MG+T4Ch5a#qMv02.4h*%L0Kt[la2W#I:1X[A0tj(1WW#)4J0jLKU2r&jK8x-LvOg7bg^j0B.LX[^;QX$LnTpnBuki0ef/+4^.)W-C)M*6#CMp$iQ6R*_>:Z-t`<.)3-0<-@.)X-com?AgY%'1Z#QpSG/Cn[GSYJE&`$sZ`_N(>dbqP2VO;=u0=vjHUTmR9m+HYuA7dn0K*,+%Bn[e4Bj64s2Y%?K[M41poG552c+sE5-QZG2&UTv7A$hlAdnU-)Y)]j2o>$u4_uAd)Z1Y.#3M8MBdb78IH?ru,w>>G2;=1S[E^Gj-2]h5,K.TF3=8Pon:%Hq]IJ4;-c%xG&lWF[#E`Ev2/s=fhDlUpne31q[-u@9]4lW+3LGf^$LqT,3v*I7&nGWp0i-&t[3l%t[k,Rh(OP`A55[>d/iP'U[nltb$c3YD#pLRt-`>F%?I_g/)MgbeD]P(KCN;Rv$GPgJ=l1c]uKx3i()&,&B/=C/(5b&%@7JeS%<Lu+*]Xmg);Yow#1p'k;2[JO9_Aed)aUQo7tUK'+nJf=PST%AbAYlY#iV`$#&*2,#@FN-$#IY##C$(,)twEx#uA5+%ECuu5G#w2Ji2+vI&.?K#u7;JLv]ikuO]YiK:_$(#$),##/I:;$EEN)#EVH3:o6wC#p/_/%35cfh#^Tpn<HN5&F<2B$0_U[%fT=O(cNu2$Mnr.U2o6S#eYEnL-D2R5TUH##C>w4$ikt&#Yd0'#FVs)#tkrD't)u[#gQ/j0?r0X[uK*653aD8]M4vKPa_0t%e/J.3NbHq]b-xU./YGq]5naj0Fo+32`77-^N$gi'oU;3(d4[B#kBAiMlVs.3xm1q[h.v<-`Rr9..uMp+1_;s%OX(v[Dl%t[e(Th(vKPC5L<EO(GR6Y[4M'W3iUch2NV(^S[gVa4wM5;HEwsj162Cv-[S<.)(Sa20m%JD*P*Ig),UQ.u7.sB#^/BYY>xR+H]*%/GT1wY64D6M3e[PgLC3`e3?4v[6*nNL#)?.12sp?xKvU)S*0WACO+=XucjdH`@(HR,G&]VB58XNq.QsGVH6KtM(Sifs6QVZxbcnvs0NH/oXQSeL(_ei$#$),##k996$D'b'IFWdZ$ppeV$5%F/IU=[p.h/<H$$(23#=Xd%F*$r1gTYmi'r)#,2f.I-2)QOon&,Kt[A';b7R($B?OgEr7i=DH*`xe,&[^d0<iifF4Rq@.*-7UhL8]d8/5gkb$2fjr?E7x*F-gwm@)H7pq?o-U*43o-*JNC&4ZR_Qp'$bm;iFLD?Kb4#-;5?Z-]P@-d#2KpT,%I]kI(Mm'lMYRqSm5Q#]H,hch.=d&dbr>#N4w)3>Ta5&F<2B$l$aW[aD8S[wU9a'8xZ)3-&Upnl`+:]5tQh,,JffLL;%*3u>1-M`0N$#5hZ?$oT4@#ZUch2#c4j$TB59.$Nf4/;NDT%F9ll#YqVP/G&:ku%^t&#EI6,$Js`w$txw%#fIf5#'*j7A0LkB,4;lfh32CpntS$.M2;#gLJXOg7T0'<-06Si&LegON=d0G(^IRP3V1Yr):nq$%uvC80k1Za?hpX%=ukYM9'Xs`-ugLF*[T3.)0kpu8Ta^[u4+@3#$),##,_BK-tOr&0Rtu+#$&Kt[)#?H.SG[)0WU.W-`50TpOaoih9ogt[1Mxl[2vl/.4_t_0B9^j0ePFU]F2mp8TW;L)oP'U[rfJo[@MSh(7EVikZh#/ChZ2<%c9FA#lC6d$cT,fE(0f,;ITk1<UAp->aHf[#on9J)-OnE5A#kb>OL72-f^+]u8qQX-pP$Z$X3+-2mR:I,khrZ#n&Kr.:5)n9W+BX%tH4MCRQ%T*o2Wf)c-'t0rPG&#dOXqAtHQL2Fg;F3e'ijV+Z,pI$)'fh6mmu50nF6#;c9b$7A%%#;w.E'T_`W[pF=d&<)wD3t=oD3$MtD'rO2n&la/j0O[,n];Lno%%]O&#[C.q.`vii0)ECO+LkGK1lDji0BGD3'[YAa'qOPcQbP&J38%1N(*6_s-,):M^*CpS%xm7?Uf@<22eX$K#5I>NN$#JPf*`g+i(haiMHEgH#Gn)`#(H/,&(BjG:Xsg>$49j](sjrI3nA[T#)8+&M=BhB#6D%A4()###ngAJ1rwa.25C5##t;qB#')0X[vGx;*?(n2-mBr;*U3t.+:^.iL#rJfLs5TE#PU%],k(TF4atVs-=Fn8%rV`)3ig'u$a%NT/S40o0ErAC4j2)cFe>mN'BZGq22[KlF-D2;.K`T_%j^FK16eeY#5og)3KpXa6WfW6&.),##s;,b#+5'2#-$),#`,Jt[o=xl[hY)N$ak7Z#t,o;$LvOg7eXFgL&=2-2_x:0]'`XM]qR]q)etsp%a<kS%-4U^#_-&t[1e]j-Z;*hY28*)#4VlY>bsUNt&s(:%)BoO((S8A_B(+JZ^Nxj#WTHe6cdA3#>[d%F;NU`W7PMM'W7lr-c]/S[#o#B(#*%E'GWnhLZ0>/2q)Xon'_g/2[iuj[)=v>)2as>),p<iL;SGgLCre*3%sji0xg44:+qP,*@]ei$$bjm874]v5KJ[>A]rbc^YVH_uKe*/M47i[,1fxw#+B+E=kA/buJUobum+GM#Ntgb*_]S+*Pf###lL>M9->c]FGbs5/Ram]4l$l(N3V(9pr`;;6&pZhpnD9F%D)nr?):Gcu0rY.L:.kj0dN7VQFCbMp]R75&+,n*+R%;c`C#Y%#`.=d&ETS3/#/pt[H:dTiM-=T+qB]T]B*_q%:A>M,/TqDP,,Ag%S)u@#LIp+358Cpnv(,:].I'I?)9-r%0IvF*?82d*'2F2%$7YJ(*(G?5['qQ]e4gB+HN5Y[do4^((;2T+G34V.uY6Q#;V>W-:4oPhf$<?#KLPsI'p5Q8c-,V/n1Tfdq;Fr`)*mD*kcis#$5BQZ.9d>rq_%OTnHLLLK+vUT?23#Y/c2cL=R<P&qIQHS@x###cK7VQ]Y5<$aqEm/CD24#6F###3/pn$nHlon##Kt[8Yti]cY6V%:53E3k6s9)?U3=-tS5Y->@ji0@YCpnl3j8&Vx:N)o,Te$?*^j0[o7dbbx@T&2JXL(TllN'VB3H*dOo5#tP'U[4T-Q#2_C@5_w'U[-Weh27Bop7,uxc3diQs-RTY89ofhJu,5mt$#Lem(vEW]3ZI(s)<0w<&WIUV6#`F50%))m&F*:U%o+(84nkO?4fhZ?&N_TY8U^K[u4.I3#mrc/vS4lq$&:q'#=>N)#t0l6#h/%##bv@I3<i0X[*q]/7OPFp4$,uJ3A;.w6=%aW[80k5,W-Qs.qCIQ9Ctfs7O3bihHpm^?+RhJ)tmC?-'@]T]+QFjLZo81(=fki0LRht[XMxl[$Xj26*$_8/w5_j0&5+2M)V^J3K&uG8k0;Z)nYBq[+l:D5(-;q[q..F%T.Dq[Qi:D5F(uJ3+VBs3Bh`c*gU8W7Yors.G9,;.:2Cv-j3mPJ?t&*Y;@C58_[:QT&V]F#SngU9[vS1;H/5u<9nf._4@V@,lTh]+6II=-v&#d$rMFig;?v?^uYkf_*si-E'Vsr.GflY#5dk#-H4XT19k:I&sP&Y,>'GR/n*^*#XiD[$MwJW-B;QNWHI+/29;(pnY(1mBY#17'@br>#NU,,3'gKpnF1wwHFWeA,*<Lv$Ch44:t75H3Ynn8%1A`h$d^Jw#J><j193rI3qb7s.klQ5-sj6n7[)V,%x0CW9=G%x8^Gmpg-lgoiZ]8%%?a54064&/_-+@tUZSl##EHBu$#Pc##<xL$#aue&'VRtonZL?C#oYJt[`)U'#H`_K(-:c?5sFx*&Zm4:.M-_C'm0EI_H'MVHWb)w$Stp:uqj`FPI-#<QFnJvPp4HjB,kF#']0N?#6DdrH.14^GovfLp5S<6/.=c]+;SJ`NrtTm&][2Q'ImxRjHf_kF9bJt[bRXR-Dl+G-l?61/V2`:%KLB8MSZ>5rI:XDm3AULlKkGErH<v5u5/US-hOB%%0,Z-HAkEM0@<QsHV`1p/Y`/Y[3+Z#)&WW#)gQ[<-4db/.kw>S[[lsA1w96p//KAR0;+UM(:+6Y[V#Ig%?Q'cRGC[x6TVJ3%@V&E#U35N'BO=j1#.,Q'nZDYPo19v-4wU>?e0T?7#c#)4q:96A507v?`wSZ7':MA5Z$SK:au.;A]f7M14FmC+rH@-D^]il07X;`+[4m#uC8Fn-0Fm9i=rSW/^Ks$#W0/k(^S@g%E`sE3$Q'pnm6[C#r]/X[j9Ld&&nCd&JHx?#pDQU%UM[hLm;cT%O?>Q#RM9D5-,+L(NCvanUn7Z#Y[_68Kxu)4:JlV-mMg*%9>-t-[K%sL2mK;g=uRj0uD2$`<pBA=+$6$`-<j;%+%lG/Tke%#8@u-PLc<r7IVMh)$NU]#sv/j0+MGq]4rls-x=0/M#pjp+lk'hL7xx1(sYji0%@7@'C>tiLHl@iL`l5Q#OGsB1qh)T+0AXh()qk@5d-5k-#n`#n$`Jg%AAA=/53SX-B9@+4hi*J/b%axRs'flL9KV;&IZ^8AO8;CfeODT;vv+qKLtY)u;;X3.I>PfLShQuuP[qr$Z;2,#D:r$#DQ9c$+Z?D3D#V>90'2hLTfl,2#PhZ$Jr8F3ljEonmR*.2h7vj[:qlJI/m@p&7+u3(5@ji0RnE=.uY$[$1aMD-f?[>#28w$$/k2Wu=KP>u`Y^2uAu8pp)51>Ghp2H2$]/PA9.nrH$),##*fp>$QAtZ1xrt.#cv$##J@pF3W&]?TMQGq]qJ4;-,sg;-t^lP4=-h5#m.-U%1u[0(/;ki0=VUpnO3_0MX6wr%rXV*/1k]j0UlQn*4tCR'k-NT+)goF4HN5Y[q_d8+9*V&1mP'U[j<@p4)A;8/fJ..%X1RB&ahNg:eflS/OM1<-N,$X$XK6sI$.@T.itKL=?nZK;Wrrl0Di&(4i)dFFe;dN'0BgXNdJMAFc?H50-W/:&oWYa6U]N6&UUH_%i^FK1bE_fLjx)]N%5YY#gC(##7?e`s=wfi'.N5W+-@c>B2%d,'17ji0cSNI3x4-W-8,-F%8[M1)1Vq_%Js]=u'qmZV&V)9.]%7rmctb/)c??xK:eFTtpZG=Lm-UI9I/p&$$C;W-@<cf(7Y6KNtKL,J:tK/)XHcS/kk%t[O,Rh(8:/<-(gd.%0cqo.2VQp.mLrx0D@,#,,LV(=HcmRnpg@w$Cn,OA?K)##ZW'-%?pkERjQ(,)_w[)S;)@-2tuot['Dxl[*5c8;22E2+p/6q%^*&t[*Gxl[SfxA(7fv/)1#^v)1lx?>Kbub[w/*E_I?Wi-6gt0#N2Puu;.>>#nQr*MSad##[[^0%+W?C#g;/X[6Mhf4_[Ds[Q8Rh(h=M>5iUch2:m4:.&$nO(bnmZV,%i`s&QsR.$drtYwX15/^v&2#@bI/N:Z'gM(U?@.tcdC#Q@'BPp&,ipIMtPh#w#`-`E8R<sTO&#3`($#_^]6%n?T9V4C/X[h01H&1BXq&a++H&Uc^6]eG`>5A;@$@#I=(0>7VZq2k)$O)mB-%F&#LMHKZuu]D2&.WEP`MH$3$#c8,o._#/X[*(l_$.vZC#'^l#%`G)3$b9Sj0r;0pnHSEs[wbti]54v<-*bNa%wJrh+4_Nj0RN38fDDHj0ihSehN4p'&q3n0#tlIfLEV8Gr6G22'B8du>D?Fs-hKo+MfUa5,R@g'&T-KX[vMm2$kw>S[-DX)'4`6)316N*IP<,:]s^fj0A8I$,lCk)'@$001d3]j0NF0q[ik%t[_G,`/o)U'#vRb'4Mh:H24IRX-'K+P(ULD8.616g)AWhv$x(2*gL4bm/$C?cDCodk#c)@[$n_-guQM<=%J,qQV)#`m/eY8=#UpB'#T@&m%.<1,2gGSX[7=;Z)FOaK)i^n<-6vBg.WAoP0U9LpIe3.m0,g?T%?'5Y[DWum#rTRx,ltY@5G1'U[(gJo[G,Rh(ob%?5=7hM(=:Qu[B(]w'M7u@5bpb;-eJ7l$3UwgWr`i)JSJk',3tU>?f9pZ7#f#)4@1dQUcv180R=/),_Hd6'1n5ftp#1<-&+-U*m4X&#ldOY$KdJ=#S?O&#'Rh+=L=vr[Jl@w[Mi0KM$o@w[)2MB#)ck1(VpZv-)jMcF=8dF<Y_P8/b&v9.Jm4:.]0(;.okdZV^*c:.u#5rmMGFa+I=RiTGf<H_Owv/TAZF`Wmt?p7^aD<%S(V$#Xaxs71?M50Hv9=-GU;^%ZRv>@UX5l$PAc9&41wN#$^dOo]Q+?_`C5El5%co7XYm+s`1q/2$Qj(ETC*Q/G2xl[FW2N$IXPs.Kp<iL(%p1(5a[ihg@nB#jZh%%5OcX%SA<4(W6&hcBU0pnL?.F%JNHJ(/Fu?5'6rQ]Vf7.2HN5Y[eKxM-3I^,/?N0S/V6+T+lgw<-$2H<-4%-o$lgER8v`U#$YvB>AC`6<.,m@d)F.aQ/R1LZ-'MW69`@Ds-slLpLK,hG5_qrD5o^ho0wEN/4$j-.KdX-Z$5$]?**4rd*Qd0t-kCgP8tjQYmYYe^$k&l%=</Ik0+50X[Q&)K.Ak=d/-X8Q8tmGw-&v_,/@X],/8cTjLNikjL9T&e*`u1<-0)$s'^g5*nt.Vk9t&thuac`9.sTBEgF4<Y-Sit0#q3n0#g-.##B(a@$%m`4#A$(,)&kHD*=LWp%4tf7n4EaD#K5wXc1mAgu,;+GK5WF20dk-S#L)@xbb`OK#$iPhLD(wu#sM<P8%^5T%VrSY,o(v7I,-nD34pFoniwM8&Vx:N)s$aW['&Jg%5h)W%JI`t-_>u;HV/W@$u_vU%9OO1(&vji0,m0pn4L-F%pJY=$N95Q#[`6Y[m><H&?sgV.41qA(TGD3'GgJo[$jRh(jc4Y[pem8+rP2Q0PJsD'*WTI*<Sfo@o/,H3UYf)*>m:j0hF0+*)wAv-sTRX-ne+T%-MrRBVK8RT_s(W'GsAc@2<A%XsumY#Tkt:6Tb'P#^9M(,,5T-oIuJ'$5*0B]w:00uvSW6a-jE_+<)?m6-r3:(@8;#$aEBU%%Y8q^G727%hx]7.47xIEO^2w$kh3Q#AGNE3*ee5AkRV8&XCZ5'o/-a+-[`8&W*_o-Nxo^fw4KUJq=(B#^3vSJ-$Lj(HqBbJ(ldv$V4Q;#'(nJhqv<F3j(hc.30dtuW+UG.xbb]+C)o&-#C;W-T`sx+uAl&-4bdc*)j4=6uk%t[I,Rh()M5Y[__HW*@aKV.1ltD'8'r@5Sot-*^x_K*/tX_0LQOlT;^dbu3uXPR^bx?9apR?nG727%W9Af.Y'+&#1$*>2uf/X[9e7W*5SLp+%]@m,F(N,*?U4*+4Al8+,p<iLBvRiL-bdc*NTt/:md#alJ0;2%8'7B#,WKEg]-XMLSjCg1a6Q;#1*L/%$Vl##4dwqJI,S5'_:*<-kou%0SARh(Ag/6&NDKc$1WmV[b[#7K<bKN(tW4A#tZjs:hImJ_2ts/KL'L#$3?/C'C#%Z>Gp?D*6HX'69>;-2#<FonwrJt[%P5W-lB^@>HwiW%$scM'EVtD's>LQ/i)U'#t/oO(ehha*CdB9.Pw.oSZGTd'6r1YP,x@fJi&tT#_KwirI.%##wKe;6/@VM^jdm+DBsO%#Tvg5#)gZY$?t02(.DKt[[Qu)38W2N$ow>S[8-h5#@/.V&drZCGPTgJ)`2=702R@q[)cXM]5Ufj0Zt^E+Aj-^4-.&t[7l%t[o4Sh(qQ*)#/^:N(W]rN'/`T5AUp3B,Hq.[#O)oa$qV6>>0+i*4e*gm0jfE.3wc``3B`4R*BOBd)/G9SN.,Q%TMr[?$B#U$7.B/>Jh@jk:P)'5`6F48('sm`kOd45]#p8?K;^?42r^XK1xE)]XdHp%>acnf(H7ed7#Le*40E.0<BM#v#LbJs-.+#2B,VpfDPn8<-0eQT-:'36.3c7UJ/1i)dLBlJBl-QV[WB#=-'U?1%n2ZQ&D+;D5nWU6]cSO/M'o+i($n*)#?M?SJisq/):K_#$)Cj;-6:$9-42%BW^XfWJ^CeZ$/g39u#FRSJRdnktNZ>G2l0`ktg)GeM1TvoJAj%kt%tGJ(Q/ZQ&AULT/BBQk1O8,o.UXtT[D]R;5@HCD3_sr2/Qw6_pIN-t,+Hot@bfa-v<_vu,'d:D3udw-vDmAvnqpAo%wxWtIOT3j18^t')SNki0)Y4-v?14K17eXj-`iQW.:hi;*nuPe$$a9q[2A:D5A7V98v.;B#0]2Q/Ev4Q/mV(s$+*P/CQ:>68'Me?$5b0^ue.==kduOQ(-,m9%Zctu,Y;9G;W5fp'CQd^$JP6X8dR_s-?xKt[>2xl[3tT,/2R@q[IX2W#Vb1X[AoCg7_L;g7n2Cw73kc.<Aj=g7Ol#R]B?N;7HN5Y[T3q,/Snsu7^n512q',)#+k/L(_bvD5lK:q[U49kK5K<'mbTER8fe01;0kC>?_ha^6wXg(4m(XT@R6Bk0Zk/$7#xl`4/]L<-X@8s.sIs`+1/vCd.ti@,hki;-0Uf_%IG:;$Z&p;-kKY)%H]VoI'hl11)/0X[ZjGj-L#j;3soCE%hdLpnq_l&#+d(K.FT[A%'f.6/Ti]ihDOdkLk^612<_h*%[@['&TQki0I=GdX6%co7J7Q)4/+3QL(xSfLt+BP+`6t8Y_Ois-0T_g8Eh6?$N^M6uU>2:%31aT`c5n0#We/N0t5=&#68E)#0k3%9R/wV[)n]j6#_f8.#Vlv2.4LB#J=1X[E=[)9,-'O1Aa]j6BLn<$L8^5(nW^D&IDPi)2Fxp]$:x:.&.IT4ou'</>'CE#xwRu7x)=r7PaK/)&&`9.;:k=.t0Ic*@bsp.k)&>S=mCI$@$r<ax-rb*Sju/1xVFT;rs4qK)5:32al(]$n?)/##q(($5S?(#]C,+#8_<Z2T_`W[g'.T494Ej-u]f22*Dpt[4hE30S;xG&)c$L3t'`$'&J`U8DHGH3Q,/W3f^tV8&Zw],/WIV8dh/a,LvOg7IR]j0_w0q[El%t[;Y=2]&]Nj0L:Th(NonB5oJco8U9mw-d',)#L.SO(KDtB5r)PgLCX>@5Xr)r.W]DD3<4,<q6IYQ'lPh-%jJ))3k=8C#OwAv-&qVd*_`Tp7p16Q8M'WF*DR<8.PjT+DcY%j'D8#QBk5N<<0E_I;^>vxMG97t8OKxx.>JZ@bfcioIv:&F=N'E0iq<[7MQXEO)78[.24fKd2>goRe1r_L;r.'F*5-/B5wSI&-0isF38b-I3qL?#7Eo$##T.FcMH7ilS?t9>5Tm#sB>9lonGOc<'6e2W#@fN'%`,vrB6;iq%9,n)3<cki0I>GJ(2r.9/u@K#2#W'>-h,'(%loRPDFOXD#qKW78=hRPDcui;?CxV78)':N(K^2cPf,LT.0'8F4WtWb$CPY78Nt<3NgW)kBwwa/M&5>##YAnM0`hM4#[-4&#a@Ei*Y*,k07>xl[/ji/%ow>S[ZjQ)3+Pxl[2VtD'[YhA#k/ZQ&l'$kLnjE$#htDp+>=qM(-8]],*a6Y[Wu=^(_l[LE^PSO(K<N1)Sl;E,UHlv.YC?ap]m<x*$?q7/t`&fha1b&8mwk_feFp^fD^*`fdZW78i$Y_fmX2J'e)2',[c^6]q1CKM*CU6]oNU^>YSCa4SH:a#9pob**d59.vuD%$qfUYdZFP&GivA$+A%EY-Vi'wnhMm*&71CA+paai0,v*`fc@p^fLnZ2V`g_02]r:0]+Pxl[5VtD'IYPs7l9eM1?Qdd2'7&6,P;$W..PxG&bIXh(BA)C&bC<S,'IIp7)ENHEr:mN#qr)Hq00SS+cP-3:]D4Aug=Ej$_:QpKgP8C8L<[21H6kLlu3#-2$v/X[M<k5,D0:a049.^1:fS$-1Y+5'^*&t[vdqM8GjiS]QEniLXikjLd?C02Hl1pn/;ki0YBX)4=TZ&Q%xSfLPiUY*:Tn/S^Y&B#85hAdP$eM9$,e@Oe@5C#Bx.7#Zhp:#CFHc$saXS*DY=2]]NvZ?mQQ[-9.>O5AbMku*gJ.$re.d<fZ]8SL:ZP/CJFp/mW>U)x)-Q#-f8sHMDIO=]qFJ(Y19a*)X9N0(m;F3PhDPd(>LEM:gUs$WjO+`P9kA58m2)QcFQ_?2ckA#k#PG%[<N1)loi,)jG0O9_4]HCsW4)eKT)al@=+%X&kZ#$C7xE@>#O7i7'8g-==8p?#fwK)d#ZG0*>E]`Bh(MML[5<-8)NV6UE31#6C[W$HYt&#x(1/#N9$##.`&[$wrV12A_N3;RO/.2.jkon<2&22]r:0]DPxl[8m7^1`%xG&S8kiL1W*C5')%H/MYBq[ji9D5qgqQ]d4Bb*HN5Y[uhm8+[',)#tYvO()x=?5VhT6]'M<X(H_Mv)oarC+1i#?5Zdp_,AO]:/Zk_a4)3qB#nNeG*9Ze)*-a/clK+D*%-,6l94*@dD;G*$3c)Vu$w$2`16LJ[B]2.,2:2DeWwOZOO=X_OOH#(rg%vXE*[COHaOJhX#aI*q)rE7)EAVdx8Mr+1UKME6C#Ck^a.n98Mh8;e4M4.Yu;@wS%OR[Y#^((##hDcMTtfmx4R3[78pG>Y[Up(K.7F&K.xcK>-ER0W3kw>S[<-h5#]+#S8^`K`5oTRs*Pu>n]ik5(+%uY@5OXpQ]qp2I3C)lU&8IF60GgJo[^`Rh(mrOu[5t+F%l]6Y[xem8+o[sR846sR8qiK#&oVI]KuA88S+i#]%haFV.<g0W-o*C*u190,5B;69.,e5a-RiZu'A:.,;.lY3)f;qM'1Eli'[Uho.6Nl:gq](Y$eZ^/2s5konF&$N*w7[R&7C=1(t]ji0(jKpn0@-F%j&C-mE95Y[kxF^(o4C-4[Z1p&bDXa*B3>r.^nEXV8`tR8]tQZ$lf39uS8/f$:@WG8&6;T95]C_]Mqi_]^T8o8Nc:_]ZK8o8>A@AexGl/.Fl'eZh]IK(&&qrgWluf*<KgT.vuD%$XKbd=3v)7W^E@o8dT:B#V%U^uTJS_%,#ni'b$el/i%i2DVVc1:ln^>$_/5<-;[AN-N)^c$[DaEGLZ3r7,=9?-dbBI)Mw;,>E(r9Ran6F<nwvDG+RDJ#x6*s$vaP0'87jO9ZAo%u^8lp)hhZ52>-L4NlQqkL%VW22?+MP-x;@F+`*^527S$4@7./t[*c:D5'6rQ]L8ZO0Z':s[K`gx?6:ZL<0+pD*fsTf+NEgc5_hiD5g'c70`#)H,K0tf4^t%a5h?u70A-Er7LTrlK@gpX-aa$61[_H##WH:;$T^R_8%w_50pYkv@qOpA(]?DH3pvU52$,[R&:X0I)^*&t[K>/BH.83E05@9U)U[9U)MHKt[/$Z[$GxMX-rb:u&&&'V-R$778c%<,WcbZLlg`v9gZZ'q.<`&[`wYn_fg/1G`87>##Rfg>$L@b$M^wd##]8q'#d8Jt[7dLL.Z;6Q#^*Fs-(qK/B,S]X[l%/K%*e(H&k<f?#ZUch2LH7g)RFG#$p[pq]Q8%]XPc.U#hx4luDfCp#e8+&M)m.$v#tnD$)aR%#mvK'#5GC%%Z3lon%)Kt[bqS*@QN0X[tL&2+&;MB#qS;R&n36kLj>Yx#x84bH2tUN(eLZ7&GZ,d5us-v?aA7Q0M5&K%<hOm/oUFb35IL,3-8+v%K_RP/bI:8.rM[L(;sG9%s)QN1tG^aJLe&r%Tg7q<'IqIUmx$9In8lHl2T:I$7@;G+4:EWs#cBip/Fp+`*#0gu/X[h#P.Ro#1bu`u$sYw,#XVrZm.JfLKL6##Z?uu#G3f+%Tig4]eR`i0tuot[iAoJ0hU9a''f[2-`/>o8YDX>-sCr8.5ltD'rY,<-,5-Qqa%=F3PK;o*=]2:.YnEXV98<(*/.6ru1wu=PLES[[nxAw#j*Wp+%/:D5.24L(=d:A5Gd#+/8g;F38E5g.LroBp(K#K.a/pi0@r[_]=_e;-:=BN-Yr%4*edg2DnTNp+H'c,/f0s5,K<b9`t.c#)A8d'&Z$Z^.>0T8RaA%R;wYN2c*AZw@L7$##Bd%32aDr]$(R.DE^w#X[=E^2-+#<;%fjG,3#16o$`ZpP&4Vqx#Qg1x$pfAb*mq79.lbm3']0L$-:xd2-.P8W%fXBjLxoO#-,6Fa*BKeSJxwkojRC@ZW.$Pn-]cS&]V_6##+H>/$=hM4#M>ja*CJqW-4Y8kXLOo5#</ri':m;F34?)_$[jh*W`WwO9Z)h>$I+[q$97VuPq)U/(X4fc)I/1A=03jp$_GBD(1N?C#3M0X[l>]v)wwWm#al#f*cBf<-D3;k`mGHm#u@A>5SoJL(U+tD#Rq@.*t<4Y$cxLu*B4`2C.bnHb*mi,).di./'tN*cN7(p7T5ggM5FNP&3ZGY>XG<q0jx@g%BMWE3$Q'pnj-[C#*BJeEXJ+q&fX^&(-TE^(da:N0M;9D5*peK(_-]fLp7Ah(Q'iu78=<vS/Kf$&(w]vWPV+@&)lT/aa^e%F+5V`bp80Q'R2u9B+gUD3m]rr[1vxfLLbe,&J;Nf,cL3]-r(Ff,b:pd#OTT?FNgwm0o<4Y,xp%##]A(<-jW't-GLK/2YOZ]o#s8fhgYJp(.8=H&>;$W.;nr;*rCvV';;h;.mX:a*V/WYHZu5Z&Cmkh#@9'2<-eRj)KH/[S85)<@qOJX%?gmD*5o68%aF5;-D?CdF1sg_,ph3Q#Kxa.2&Nbon]@m7&PABT'g$aW[oM8S[,v@g%qI)n&la/j0K=0q[k0xp]?+vW-W)Xa,l%j/%e`6Y[PKcm#,vpV.8U2Z)aqLv,#?Vs[f1Sh(o2KxAkVsI3@]WF3u?lD#6EFQ'CO=j1NM^V'3Wl?:,?^mUq`RBAq=9(-dwEg&nS4k(@)J6:P@-u@QP269+#]l#@P&V%_6Uj$T5=&#MuJ*#_(wx%t5monLqAMj-J7$$sf7*4-fBp/$@qS-A&$a2J-h5#FSeV&qfw]5aExp](Rdl.%w1q[][n2&mQ]ihInVhM<:hw%h2li0Rn4jLI(lC5YSIJ=kIt'4H@`[,tq-x6*J%R&K9EH3wu;9.Xr6x6Ym3q*N-:?A<$p:7:XVD4IbSY.g#fK)g$0>.sQ]oBb=oN:r(NG8/dQ_#h`Rr6F?#Z>m9.5/.Anv.`n`s[V,aI3ulJt[v4xl[J#Dg.ph3Q#+X5d/Ie*ih&aBpn))ki0^t3M(]x-W-#gGb%I95Y[J`]&(biQu[/(]w'Y?$'$b^o8%[YWI)+2pb4`hb%AbJ8f3`xc<-XT@bQwSr41T-0;8S4lI)BHfA,2GQu@Qd*q0#OH@RW_9G&hsk#-_$)S0P-E&FH$BQ&04iH4e<l50qdaID+h/a#&HVr6h.H]kQaw.:ZQi4]2S`i0?.qt[YPXM]?.D9.H90Q,72N59ls1-2MCl32]r:0]ZPxl[e39d8ELXg1IPWR84`sA1IBqA1Kp<iL`2BnL<u(g*@NKW-CCOBo&N6Y[o98Q,Ci:D5GS(Q5kYBq[8Y:D5*-vT[DGP-*VkQq7GAmS/ep7m0]h@T%.c5%5;Ef#6N6ZR0.Li@,1D,42vx*w.[fZX78_wM3=q/L*KZFO)3#(##_`f`s^7pu,pC]`*X''=-`U5=99;(jClexCmFA:Z-*H2,).n&fDUT:B#X2dtu_14j((9$Z>vJ?m/UE31#oCig$U48q*5Ue*NOCvG,Xs?K?&/S$TWjurBs]2]NTZ<)Wwn]:@+?L#$h-_`$O5YY#[x'##2x>W-,CPv-).6K3eMKs7_vpV.=@3W-KpKU^g:cP(DLIp78O^WR3.wN#$TH4o:uDW8cKW@C+q<W8KqE^MBnuf*$s^*Ndd:6('//s[aDO_R$wsk)9$Jp7CwE?6r:mN#olm,qrhSb<URF&#>k]&?6n]Vm=eT#-W<`&?%ba5,()E;%Iv4D%c,-U%;nNb(qr[0(sYji0j6Oa*`A#<-*-&n$5cwQ/ZVd8/L`0i)RYHu--@+08UT&dW/Nho7#XjfM^<lS8W7@wPv:Fs'(KX5'E)%?@L.;+8`<uA#me1H=]*HN`-i9=DT6Ap.NQJs7IaEKV9fe@#qsO:m_Y*4)?GC;A;cLPr(=o>nI-716Fw%KWaY5J*@V:8.A>iR/Qmm,qs-5.UDAVR/0/==kJA9:##/&N0@WO&#<.`$#r'Kp9N;CW-%2xl[w;6Q#kw>S[v,h5#p@HU%41x0(lDji0xM0pn'%-F%Wjcu>?%Zg)Wf@0(Y$BZ$a,1<-_xE_$wA>(FV6L>?%FNs-Uwc;G55-Z$vx#o$tvfIA;cLPrwgaCFox)%$S`'##Of[Vdb**20jpMcDu[i;-o>O#fj.X)'b^rH3vC1f*AjSa*0KqU.MC0q[_&Re/LY=2].*U'#v=L)(.nhgLnA-h2p_qJ2L0)Th/9QJ(8ZVO'N$mRAM=.$$wFJ50b*_$+[bgP0v[0AO%>YZ8/2JfLF=6##vRE36WH:;$U.%8#rJ6(#mJVp+T_`W[>jGj-FTQ#2kmb5/x-m>)BwqgLJue*3j$@C#;f0X[IO,-&^$ki0u[H*3'siR&U_a*3rTA9&W+Vj)s6A9]B)2C&,31q%s)1lB_w]G3Pn/lB3:op&iYBq[co#,c60AX-;d4c4N#G:.l=n+//<gM#$[DB_n=7j-BZPMTPdw^Tnus;0f>kv)'gZ5/Gh1$#P=C%I0>Es[vd2W#,9.:.Uq%$#bbZp&qeBYINF>)4Q):0'Pt'n#u_t>&=,X3O4f)<-MV'0%+)5q@_Qvr[R5D>.:0o%,QV+H&pl#R],n[],c9siLF3+5An+1ZH#98(jMebr.ImlMuarjg4K=6##W%c?$?QG##O?O&#Vm7k*W-Kt[+MXM]2<gj06t*4't<i;*)+X/.(W(<-YV>M=n/1q%aExp]3R-a$k50q[o0xp]O<K010#)K.l9Vv)[P'U[pZlX(IXg9Im'`lgbN/q7hUVR:4+(w%xFBA+@Fgr6_>-<B<[9]$(GA22)i_e5t+`#$ip,K2toe;.kXkR-xXkR-3Zg_%_)LX[R@wX$DDBfMT0o.2/I)(&kA0q[0s^c$BJQ?-@rr&1;pvr[pIVX-#-YKlSLs[GiMvZ&vO(i)5f`>-wb:X%Ha'P9,sZ#JiB(x7Xi-Z$UGsj(c)Wa*=Bt58V,?v$L[j;--DGa*4OJt[;?:KExY[,&VBiCHB`Z:(#3xq7wP4Au7eGG'@GS2`/j41#bQk&#6k^x7tAKZf&ZU,/Xlp/MR5[*(Gtji0I(`pnS'(:'De0K%vdeLCHsL/)d_%PBW@l`Ov21-)wu$HB`Mh'#g]5ju&wZk$Ke0'#-li#&c*8$#r&'Q,ojb[#KBtXHh#2p/FgTT.I70q[tER^2/`XM]5Kgj02U7R&`2Hm#e0p,2f-&t[#*U'#N1IL(vMBu-^Yh;-^dSm%VURr7_P(a4Ca-I%P<=>-Ho^b4-;n59XB5W8*<kh<k_$##T?3hujeV8$5S?(#<4?8Dog`s[(>xl[D'Op+XFZp&e[vkLe2*22SUe;-XCm]%Gw=4:rRid*58Ps*]'xU8D;vr[bV>W-UZ*a.<dwO(@m[oB0oBc+ctY@5vOhb+geZs*4S:D5.24L(3F/Bf;@T_'^RIw#@@/:.gJD]-`mWR+[iBU7b[su7MqoQ/)i;g*-;BPOFjSp76,o+4.H?M;hkT9&Nq`@&N^10(JmDo0@6/4($25g&I'Q2K4@@[7HAkK&RGST=TM*&+JV)GU)KPg:TIapBpE3$JlCH,D5.egD#.idC_FTQX.5)>-ri?.%a?04JCJiD<h0b#dr3.5/XI]o@hfC-+W'lUIG<E22itY#)LP'U[M-f8+9OF60bT3H*=:$j(of]N0DT,9.c2v[-(IB,,a@La*;&[>-d4I-&;jVI,K/3W<42L'#V4FcMg$Es$kZ,_og$1JLM`_&#17Pv2GM7*&g>Lt[2@rT.hM8S[]5C-1LPxl[.uMp+7h?p4X<[Q+^GTKuKsxKuHt:hLG:hKMw_sg(CJeB5+vnK(7Q+)#9v(N(;97A5GK2mLBtHQ8=+'fDKtUmVHMGf*I7170B$D/U*b49qVY'fD6:V#$ma6V:h-Is*df3b<E6b#dT1-5/018PJ;1_C4B+Lt[FMXM]i8hj0m`Tq/91Gv2K_J)9M/jl(-WW#)m3cT&9XCq&la/j0kE1q[41xp]_%Z<->N7gYX(;g*EvV@-rd#t(@9lk-OvT$:&:LD&[%[Y--X[lV=m=%&._35/d:.>>s`6KE%t=<8`;SD=5/@T%dJJ22FVYonKxV;&rlo220%aW[<N8S[Y-h5#M(OW&)%vs7>$CW/$bx;8v<$j:%fi9.6d$_+u+$d3w<a8.s6ep4$ILa3*Sxl[gEZ2?5RLs3wP'U[JgJo[<r*G%d=EdO5H7r)TVBa*EZ4I3%v;9.Xiq[6[&X6+M-:?A:e&>6VA2[-1:A$[kL[[b%8A_=G,b#d5/55/T7AS@Qa,V.SG[)0k;Z[$#q:0]5@8Q/+M<a0E0:a0*rD=-Tj?83Z3rI3ro4e-tYGDgpn<;.N,7$`K^4<-+spk.HJa)#<4N1FN*sM6pKA2M.xjAH,'R>6w,$<7`CvJ77ke;-Q*+s'3tfB&1u;[0&TcN=ojrI3F1Uc*fKU[-$maCFN0)B#'4j*9c(:BuDfjl$J_''#?$->8i>uA#:$`ppU7LkLuBpT&)1M9871'g2g)Q@-Zoxn$[dVZ%=#XTbG:9t%.@[?,KlXx8OCU9&v&BW-#2$kkr<`l8=?np'gs7S[mM[j'DfVHm'sWZ%B*P<815Sd3#C.J3_Csd2,&I506[0=8aMQ`kQ;Cs-qxMfLClcd$DD5XJsOO$%3/*E33c7UJ[s`W[cP8S[l,h5#$Xpa*%BT[5kk%t[Q,Rh(u.5Y[RY8E'xZEU.+5&K%D]mE<+KC1LGrB#$L&.Q/uR5DgW_Uo(>3Ps-cwN#+&apa*(NHT%Z3W1^uME`s)Etr$@&->>2hi##i*2Z)Oxa.2&Qkonce?C#')0X[%26Q,8I7q.3x92(OqkKPP3Lpn((-F%+)Fa*pNTj0Vb9q[G29D5PkG'+0/l9&'^IK(EGDM2qbm%F7$8HY*hmc*-Wvm/cTc.UU0Nom7Fj1F8Bb20$Mu_j&k2Xtg@II.6<:W(W####R7':#'=+i$7A%%#OM=.#'dW9`ObSX[(=;Z)j_n5#%D9**<H6Q#p<Tj$AvKX[$Vti%+Q8S[-%Q#)4`6)3-p0pnun)+3+DFL(LvOg7j3]j0QO0q[]k,L/MT;.3WUNa*TLE9.j-&t[YC]5/o+B+4emwiL?20i)6o0N(NhA,2]F3]-4X_p##3CXajXQ=f'fXAuZ[oDVG3ei0+Tn[#%`8.$_5D9#rCbA#3T3$$</%8#Y)mZA`ST/);aTg-eL^FE^$EW[^D8S[?3'Q,>LO&,*=jM-(F/j-9cK*[vHXp%:?+&,C`[A,HnO&,#Q&7.@ERhLAvcA#bg`)'eP'U[rVeh2[RIa4:0fX-J]:p7NwG<.7xCKe$:DrQQ&:K'UGK>PPV1jU2R0S.VDhK'0-'2#WF9`N=I)B4DX8=#fKb&#>x3N-T_`W[>n*T+`br>#(>`/(*?[ihQmX@#8?9g.O3bih?P1pn&vji0E=oiLqm&?59=U0P1C]2-2cGB+M0p5#AosNXeN6/,I;*F3lJ-c<T'@B5k?Co0soLpL<TgG5^noV%*vgGfhKCm*PuQW$L]_xLT]`7[hwtP9Z)u:`>b/X[1D+H&<;#9&lB(gLq?T&(WclCODJn&O'?Rs*Uo)kbvX`D4;P%q.vBo8%p?W9`cWb.+7uUL3HV9J3G*@O(a90/+7i(l2FM0J3C'.4(L(T+e8XLd2q.'F*;[JA,GR))+rxWe)^;U=H'=N9`=Lk]b-l68%cr[`*-tOW-vpS.;ejO&#Zi-_[AY7&4lWPJ(=a$_#^kl@f0D`&T?@PW&K%_=#$8:r$*]^C-ABV=/^,h5#:w2AOg2bm$QUch2&>Pw$lMlIU[uIgSl?PhM8KZY#afCwT9t,>%@e[%#;[P+#Et###I.t.2ulJt[wLXM]v#gj0vu3?#lI9a'<.>-&BSxl[+TK&Zc?a?#r]Vn&Dd,Q/hYBq[^A9D5[(;Qi#5@n6(xdW-PMC@6^PKR+L-_vAv.VRfR)II0[_j=.%<0I$4hJW-Or]6sr$a8.[CMG`uIq]>*[H#$:Mxo]h3@q$4vOT&@$:2('H/j-/Kcn*t1k`W9:U@0njf(4)GMc+tjV:7jW]GG[ch0ePZ*.*u.Hb+uKK>.^NXlCp'_-<4AF2$w;X&##sxXu8Apm$C4=&#9>Dp+m^O[#Ich,2$LK/2c.;0]'cti]HU3T%`?95&B8(,2,sBpnxiji0R.rK(SJ%K(?+;D5V?M_+cFh;*%Q7K(#RF@5$w[O(%/)W-I6*t0s&2W/9ZB:f':H)4=U'O0[ogrAFVRZ$rTDS=C7u&#%/5##0US/.YQBsLn_c&#=4E#Mt7Gj-3GmX$1$vj[08f,&@=a/.qvPO-UQlk-l1>']6n4Y['bjT`X1R/)p0'1)YfaO'2_DE4nqj<.$D0Hu_cS/&PSfpu*e:$/V1I]kGeTfd^2C(a[ZcD1h->>#xFH;#-Mc##gm+n%$w0T.bfq,2E157%AGxl[fVm2$l-0V%jF+F3;w#XL3hbJfJgpItexpj_4+,##Xi>%.>]8(M:d^cNjxSfLC3+'%g%'a*Cf79.tXG,edhK&#XhCZ$K'YoL?nJ%#7A^NE7@_l8Sf'B#XaxN9(WeLCTTZV[EZ`m$n_`BS9Oji05EB5&=Dne%Lx?a4GVie;5)>)4H',M):2Cv-`EP2[gx8gWV5o2RQ&IiJj@>O-`IH:;^_H##DI>/$#PBsL5md##KR@%#UN[#%7Dr-2wAkond2/X[j8h5#IxAF3r8'pnqB[C#vi/X[rSOs*6vX,M[:B@#=D<*37G_pnqift[ok%t[aEpTV2FfMb?7t'4FcffL(<bF3r?lUIa*I#QSudYE@Lv0&J.gu%TvqUIAi-(#eIa)#:dZK%W@%%#0+^*#7Cw<'h)pO9<aV8&O3&6'8cq5,EGv9%dUu@5+vnK(pv>(+$(,)#^_l,-a?.J3pcD<%/-I=LOPS(sN<sZ=*M1B6^2]S[*1Ap.4-umu''Yitg_BN(^M/S[rr.K%$w_)'lDO#):`Lgh-#LpnNJ^6&M&FW&p-&t[x4?h-KGN*G)?>G2,C8a%77(p7'?Lv'(-Gw7+#a5*mg_kf_3#K1i2KlS2,LG`45QP&QX=x>N%a<%7<1,2bndC#gF:hN?Q7IMWJ>2]8M#<-@B'b%8r4?5NCtT[jfJo[G,Rh(ph.?5FTNI3$-0@#,pXV-So/F*eQ@a*t?L30gAA50N$D_$p<]COcq:5KH-o;-d=;E/Ywb:$#=X4QhRG,28kCeN+lLpnd;JX[jkqp$8CUdMUBoH)ak%_SPt0N$t2gF-&XW5af#jp*;:S<-Gq`p*Wa0'O9T?>#^((##Y`P]k6N/j1b[Hp70m7p&qtYGMS7qZ$UC.=-kht,69.I]kg1f`*%i@Q85PZ?$'eJ=#1Yu##B#l@9Ta,Q#u0`8&m8X2)%0Ur(ZJr/%7d@D$ODoO(H16g)lCeC#,?,Gr(PDTtms'Z>t<Qq*6?agL;-dV-*6xu#RLdl/7[^V[*<uk-KKgw#Q2tuPFe9_p4CII.1^+Q/CV.6/d*(V$['YoLe5N$#nZ5O-LpPk-[bevRa&CQ&%Q+@#m6Fc%an>R_>5ee/2dc4-smJg:7BwDPUR6##We+Y#tpK%Mg)<$#^gYO-[q*c%DPxl[eVm2$/xqP'_K4a4e;;^QOXBfdIc#5M]iux7IFLkb[?9T.m1xl[Tp1]$V5kv$`xe,&C.'s[.ac3bPO7f$tpI,M=aj.1r<N'fn`3T#@>*7%Ev%'#,eti$`b@Q-(;Xj.cqdC#YH7BMo(d2$l?ufL9lL)N'/Qm#MYBq[Bc+?I=p<P(G`x'.>MvrM``'o-V;<EQYRVe$W17kk5^.;66=WT.gr.K%o93e$clk-M)JHP.)tLd&<I<9.L`0i)r#kSJY-+n-fA[($4J:2#FQKY$[[@Q-)mG9%4x_58HV6xgw^Bj0B8uJ(v@A>5t/oO(XTsBA>t]%rGf)edSHRA%4b;<#o)1kbXf#2970A$#_xe,&m$k2$hv7a';fUghH?9u?EXJ9]nTfj0$8X?#nX^&(@Fgs[RGRh(qwR?5GD4H2NS=P(LIZg)p06g)l8x<ZUxRdu`(E<u44Y+^TJUJuQK%Ke3CNk#M,Guuj7YY#Obg0/fom(#3W+_JL;AB#kG/X[]'xVU@QJ-[NIuG-KO:d-vRd3F6xB_4t0w9.]?;hdCBkS#J*Qd#sUM7[a+6Hu+%v+#qIIm/gfJ=#9rC$#@=FM*o&jM/`'l,&38Ps*SJqs-8)^KM*8dm#e$eT.uv^d%W7s&-(oeC#)M=<.QW4A#oY@%>l>SDtp&,ipL[Gd&iN>g1`,92#x%lq$5aR%#h3NYJS%cA#jkpPJ](x],i6CC'uoeK(%a`%,*a6Y[btDp+^d7QJ7=Q6W'O?WCK5G1WqsMW:Re#$%mQ2gLs5oo%8.*rRM8ZV[Gv[j%iB<p79D0j((m'q&*w_)'N<rfCxUgJ)=)-k(UP'U[ilm2$.M#<-o?<K*q>CQ/(N<bf^#ZJt*mSa*jVYm8?6LWfI(6:$qaR%#C`x>%bchg'7+@p7d*tY-m(*a+-uEa+tphgLh5_Q&#]Ps7/sKshx#gH+3CVm:afjqMvf<4)Mlh<-8>O'%ZGl2M'oKb*6S;=--G[iNv]?3'(R2H*%TIg(sL.K<f4xo@?*i/<j&A-D@XqxlP@ma&P:r58i,`5gZ.pu,[;NpTKdVPKUQtY-)eJp.Yeje)ZrdT2.-j%,CG2C&j>'U[E?Be.)f6Q2%*=8(eF&tps&n[tkLB5)13aTD_i0^#XIVS%T&lq$=Ul##Og7-#4@###F(KF3$&Kt['>xl[gM8S[.)],&-h+T&P@3*3YFDs%^&q5#*rb&#4:lfLi9#a=A=T;.]+j/17&Hj-Qc^6]N3DA5#p/G0p%Sh(ISDM2EZ:;(e`i,)B6Ih,AD`4-n?n29Z,Ek0:Ei%O'S1w8te04f`Vx'#h/KlSOWCMpCh>A+BiCjM`7Ka'I`#9&_/ck9vTR$9Ja^tAr(@V%=ht1(i-B*[5j(C&uJ0q[Xb`W[$si/%Xao;-.FsM-5)*b0G,Rh(Vb8b*O^rhLJcnO(FZ)F3=FJs-)<BG;ZV4K1tqOJ(FIv(WeEm;_5R^s4r_Vd4q*xY>$'klSDHB^JDCVA.2p>c4'q?AXA#W-Zl3e:QUSP]kC5HY>&)aV[;WAc$/#oA.)W()3LO$-4%fjS&G`6)30&2hLLS't[+cXM]wZfj08-OO'*QGj-PBC#-s(S8]+[9VI(;Md*OEc2$4`iG*I2%6/%EsI3.5?f*vmQ01Z'a+cp3:xk>Be'63dxNOI1sbV2=e:8NPA.M,EX=?#/xabS%PV-2x+8786J$#]V0Cg%?Y/.?<Jd*=^Wa*ZCB^->+>x>b<x[>%F+Q'`#)]>X[GtTb#qM'rlx^]7lu^]h;%'ApL>^(?cmJ)S5Gx)x44L(PMf,&kYBq[ehtX?g5?Pjd:ML*LvLPJB*kT2EhLXS)EvTKh[9u?,t^>$Q^HZ-mmm+DnQ-F3`G[)0A*l)0?C]T]clWs%^Z`-3BF>L%ChQx%8:lp&la/j0f61q[/1xp]e30k0,cm8+`xe,&Ui0Q5RH[m0rP'U[JXA^&e>$F<iPT:@Z7$?A4pXPt:#B9A('%W]VLo(Wk(FL15eoM'I8mi'2`ju5,ls&$+%F[$%5&22#>9@%j8Px#RuGr.LvOg7+h]j0%b[C#E.1X[+RBa01W<B(+.Sj0gD2HGu^B1;nXiS]W`pkLR;OfMT:+/20Iv'&aB&mLAC1/)r#U,/M/@XHAe`JsJS.F)?e<.D9]S`tX9=o&3+v=P<KqG)diJP8Pt_50lZ&-+ls_K%mxc<-4B0%3p]Rh(Dhv8/YH3H*'^IK(#H^cn;r7R/vuD%$JVE%$ZxVf+d:iQt2EJqsn8J$,F@fRn$c1p.'G:;$/?4I$5O2#&[RCP8w9n-d94?-MvV/%#BdCp.n4c^(I%,Cfe$VDf<A>T&gh#c*FX[<-8a^v*-,mT.:J]7mGkB5q*cf;SAR(V7)9T%oG5%-FZ,o4]j%W/1^v&2#HSEl$55i$#l,J]%MOFonnYJX[m%Jg%I(Je*<)wD3osEonv3'/2YE)&&GFji0(a0pnk]+:]%'gj00OI3'cMDj$V]GW-BethUA-6kaaYna-bA9M)ItuM(,m@d)xh+*%n)-_#$F_n#cSmUPVT8f<(BH7eScH:$#2FTVqD#kuiKg<UhSJ)*NUwu#OS'##dtM]k<FGS78%@VHWFe'#uA#N-?@#]$_?^+3ulJt[iu19.1Q-a97Ei'&42[C#Wx3_]o/MpnpT1q[][AN-@<:H/^Ri;*TaSmLsfQR&8JYnLinG,*1d^6]`5JB5ZRv>):ZBq[v%:D53KH41s,qG/O%uV67VEN05IL,3(i^F*<o;g*E^YU.A=-S')mdU92Hf?&jqr[&7/tNLA4MS@%@MF*]c3i(25=>5PjT+DcP`M'D8#QBW.`q4GO/[#)%id4*oB4Oo9?i&&?[S#C9J=fLMhX#-bqd-66+#-Ea[MLh_PcI<sbu-pxtV-SkYn*?>aQ/83?#77]$##hY.N0ofJ=#Ke[%#,3MR:1:A4T2FO^,/s=fhAEQZC/#ZA##;xk']]8E'2aKV.<$Js*luAs.tcdC#p#A4T72+#HE76a*t_6F3h=b]+`AbY#^((###cs`WG^CG)hx?W-Ft=$IBjab$:Bu:%$XtWUdnFJ(0L(@5R[T6]?^+1:1F8(O0ah#$Q2tuPMo&q&.WsBpdIIx*Ogba*<M4H2hSpMut+lq$3)V$#_EX&#pXAd+<O&?7K>+jL]ENS&&(j;Bh+=a*(J$<-0Uof./[;Z)>M#<-4JE@.-N(lM'B^1*;]@o,WgAp7OL8Dt$/@6'LA(;$@t0hLjB`g*PW(=-Ovqh.trft[<K_d/qMQm#;YUp+G/m2041qA(wLS>5xUYCO9K,S1+0fv&?o[4-XWdM:tFnd;=v)%$gC(##F`BW-Hm$)*GSDV?T+]01+2xl[%<6Q#kw>S[Bn`^%A$KX[c?OwT?L0pns_mQWw?GJ(^44L(b?Fp+VDZ6&tL9+*L-l,/NGa)'hdFvoF#&X)XMCe;:hB#$Rgom%DZb<-(`/F%BE_Q#h?MK)WJ`/1fkv=7sMG)#%2PuuV07m/Nx<9#@XI%#0Dwt$K[Jt[%>xl[eM8S[xl%K%#+&S&)5mm&7]+o$-YU?^$;+gL+toL(mE*)#XF.L(6]GW-YL213c>dJ(W=tD#]j/M&sp59qs&n[t_k5TBZTu<%(PQ+8P^0hP79K2#SK&*%H/_'#qq8j*mB:>-$fKNc]_]C#wUP#,ZGEH&$t6L2HN5Y[8&f>2iUch24k[af/B2,)Vk-p*5>p508rDTtZx,WAD9?1U;n5g)solsiZ^dYY$4/rm&b?*Fnc(/UL9JM0hC[EnoF$##&3G4kK#^e*$Ti>-<hQ5./%[-NB&$XRiKXD#qXaA*CHCD31L#Jq'e_s,ln:_p]?7%PQ]h>$2M5L%6/(##v@>W--v:D38.H&d*`;u7b)?)4';/(,YP'U[?#Ej$jN@<-:QNI3mEAj(C+,r$tZpdEZvT8gc0g^J>Y2mh`8)r?5WX&#>DM2iv->9#)K6(#9+o@^(S)u7pm^G3w#;s[<[n1MU+FH&4cm98&[Tj(l$5C5D3$:/lcdC#DeLp7Z6Y2(1BAq$_e?vnU=vRE?(e(#`2KiutBad$o7p*#K7uA:T_`W[8KVIVUG,h2Ek,a#sv/j0A&UIVv^?/;.R`W%?t02(-Bk^o#3VpnM1s;&qcSm1v$aW[+YQs*%w#<-mN_V%^$HM(kH%w,Qw+S94uY@5qaU6]Z10?5GgJo[v7Th(tT(D5Lvs-03/f`*`[24BMN:a4&p,98W<1$HINdFP((LF,IUK7Jr^7EFfAmN'&h4w*L0:n8juu_F<4AJ3$,>>#pH'A4PCM]kQit:Qr8Q*#&,7d/eli:%Y)Hq]HSpw%<>xl[#VSLE(3Pw7'J10aYAHZ$%mCg.MT6B1*=Sj0^bVpnG:Lt[MfXM]mGhj0XXFh)SoM#;%T?T%>YlC5[A#Q(,rC50i);99HN5Y[K2n,&3M:D5Tt4a92ZBq[5qEs7tE23;=vcM*f:X=?aPm5LkQHh2VmSQ%N`'E>cvnR;*3B5+-a%7*Qltd=T]7f?@I&r8]a&g2&Eq$Go`eA,`jg_0eL/@>AwOjDJ;<Y5N'ugG^b9HOMpS;QDOWp$mWdD-&x*G%)3eh268:m8C3@VB<-@?,#9f`;k`c(H&(D*8xVO#-X@$>J_q?>#6)br-ux$Z>_Z.DEf.I-2d_JN2#0#,2$q$Z%Kh'02+4<0]xXXM],Ifj0;km&#&'bp+*ETj0*sTpn)2[.Mwg&w#02@d/rpNp+uu>n]mF#?,*U6T-Fu6X$0TiK(1R1@5Ax8q[Q>Q;B-k6g)h;Gp8uOLN(4+/luwTU:@nA7xGCXem0ua1XVvPPE,kfKM^6mmu5#sxXu8EEl$$dZ(#%bBZ)Uh%t[$>xl[HG@H/g7c;%o3xP/bM8S[nXCs3d-9Q/vt2+3EtLu%/[*d3oj(W[mGvD0kg0d*0&%e*5C]T]6=Xp%/tnP'Mv'a4DZ/t%.m#R]lT6h2t#2s[/=(tq@c*)#C(AiLXdVA5WqpQ]c<qK2A8*W[#;Fv2DUaJQSQn$,68f`*L'@h18TKL=?h?0;Xx%m0Q-nq7#5+6'?@-j<jxwlblWXi*RQcT.l1QP94HU]4tI=<:*3&##n/s<#vqnH%KMc##vh8*#7JP6(gjMCXmh_3([SMj$Tc^6]ROgQAx?6$$Z0fX-jQ/@#Jw&Q/4+/luX63uu?h[p7f+$?$,-dQ8&f0^#$u-20%-B>laX18.$H,rR+26W.^pJr7N9ZV[(5UMuo9[s*0qTW-miKX8$`aS&RLE*3ite`*p7%<->#Tn$^CE7SWpkA#cbre$(m1v*RYj6/['b4-jqUp72;+70>@9_#<G7@#kpqsAstPgLX<?>#+hAp.8Yii'@]$6);D;-2kYot[w1xl[N>1d8jc03(9YCgh4uX5VaTgZ$1=]j0']59%j14H&nV(C&'8f+Mo;qm&pk>^(]r)B?v?Ha$hF3]-vPeA4$q8iT6oYN#<xHZVt-qQV$sLPJ:$YWMf)rP/ed.W-Uq5JC1S.W-T=PI>D3[68]LO6'9NL,2ofot[O4T@5fM8S[GW>j-_)4s$J+?^('XPg%F2-:]gCuKP=RC-MCR?R&8gG,*7[,Z-CUV=-:%&f.gJft[AF=C0',B+4k;oO(><M3XOT/i)aIaRS[F3Z6j/0,8pIKJ`_C`)J+^e1g4cbN##A`CaWcwmg@:JL*.QP40xEZZmHFx5/mY8=#0<=f*(bSp.q#Fonk8sT`R9Z02.X`$'1skT[F):b(EMGonpZa4C`gu`4wooF'w.]m0xtY@5NF'U[4gJo[4gRh(HU6Y[rIq;*)Vdf*9G[FE=J#pS;E'ok*9^Q,RdPD6^`:8%=`bN(ZQ.%YZM-Z$X$tks1rJfLSe6##Z?uu#_+H3#x+3)#r/F.Fu5.12:,Gone-lT[K):b(J]GonQ<+v7dc.T&'RJ(=lPvr[c/dt$oQNp++a6Y[kZ=N-':0Y.41qA($&DO0O+;D5v@c.*`(Y#)dNQs..vEiLI)ge*NiMc*]0fc*E<dh1ugb#-$5wT8**t`+Pr'b*;-Jb*V$X=-jl-Yo`a6:&x.fc)/Ov.:EOHl(iG-Y$qx:b%n9Gg(uoIfLiB_F*Tr'E'/cPW-1Av_F-Ch/)%Rwq7i4F>d`TT2itK8$ThmkJad_,.#[-4&#:kJ@)B'Kt[$BSq*vF3v-9cIiL]km3'a.c#)8IDa*eAH/MYiC:)>QLPJ[o6u-o=,BB*2a,sCB_c)`?QfC=Kt<-_Y4<35i$6,3C]T]JT?r%QhG,3ooFe*a-Q-2Rd;$#rk`W[sBf2-&m(0.M@9v-JP%*&P6ki0t^+M(%Qod*Y9Eu?Uq)QL9HX(V+B&x8Y.kqKZX8q;#3iu(*-W[?^XBpTaS)7#`fqU8/kT;.*/+[(:]R*niMSN%g$=G%J0wa*w@Q<-CamAQ+8N&1DKC1UgIlA%YclA)r*@r7)C(69-sZ#JLo+gj>K[LI1sF&#eM)30DFbc)rZ*20_HjPqk@%N:tD760#HL]#`u*a*KT:Q8khr-**;@H/BLn<$5X63(6w%@'Jo@@'?/L5q%ArB#j44G6tce`*:DZq7CDCB#G$axR>pCI$B3@Xa+#QX-ev-lK^^W/2Jkw[>12pGjhBEM0kH#]>3LMp/bFdKMLXJ#2USKJMUs7S[:;TW&XfsaelR9be3G1q[TrY<-P.vW-qCx[>tKvr[*c0o-oA#]>9PD1LK`1a4R$vX?<39Gj[7#Tg,iBb*nCB?>9e;w$/O7%#Y'+&#'w&)(d%Hs*U$(n/ak%t[)P=2][8l7%3L)c*DjTV.1ltD'D>GS8)-<,Yq7+@(6qnSUl(=<))P/8@L'*%$Wl'##&cj`W[+TY,F>HY>_R.=-$6pc5GvWc'/O:u?/>f5^DH+#-s/XacD$;Z/Sm+0<MUFGS>:xHSEQc)Go%$/_$)'fh:<<)#$),##QdoA$v;2,#`a.-#[a$##Dr8F3Ild`*gi(9.e:=d&$+[m%a:m;-_sqh.5Mxl[J%Jr%btXt()mwL(r)==-p:=*eiCMp+B+L`$:]:q[THE3V/>rB#MlIK+YVd8/.iQ<-b=BQCF//D$g)dZ.ZfZX7XR<KH?8V$GN$;E4e<l50g'Q9rCiF9rv?J]k%GZrH6b21M;(1kL)?lonu$M_&L<Kt[-5xl[xQwP'Kp'a4:WeB4/)Lpn_:m3'/2@d/Dk=d/#jM7&$'NlLf(E4'Jgok1.24L(=t[21ptY@5eSKu-Z*:C,PTjO(Qi@B5%TIg(.>(5:e+MZ%Xu2T/_2qB#aO-CBTCdr'2P<W%n(f*JJblE*v_eG%NWs[tV54,iWHkl&;6i7[kj`&4E)UX[]GHQ#TC-T.uP8S[m,h5#wmD7]T#-g)?Qd^'vgjT[YI_T[<6Gm#l&nD5.E_c)dB[S[]86Q#nLs9)k)*H&:kdS[eBE7]?HmV[$_Rs*KY001Hna`a0hXm#9LTk1UM;mPmSi/%Oc^6]@d9e;J^lH3bcdC#6CZV-OLt]>Tf>7]E$Y]Yr<'t-MO0a*Np?<-rF9*[[nZY#JC$##;Z72gBH(,)WsMW&a5v2$>6`I3:QWa*.e0q7C*6+Wk$U#$(/F<q[NbW$SA>+WmM0xpH_Lk+YA>+Wj)]?pk2dm&&R2H*iUch2Ymbx&Jjk;-&jr-I7JXD>'06+Wu0,M=[_$##aC7rm+bqrZS$SS%J)[`*3eiB4pl%K%j+m2'&W4@#cHt8%QNcm#u9:-MatGa9.L.p.2VQp.eK@g#dYe%+#1BK19nwb`3hQr-t#=>G8Wjf=vcP]u+UWl$QOc##Y?qY]>AV-2g5ji0OpX4)500W-.S=+WVZ-Nqr:mN#qr)HqJ63>&*S9r@)H=kk^3p(M30<$#:b3A@koQ(#9mZD3h>/X[uC+H&(3@a'n;4^(w>RT]DR<T%gdTT%+pBs.(a0pn#O3=(Nk0pni;ji0[nsa*`3)V.N`0i)s`+p7k/vcab1%9P+5Y?MqqJfL%@Ho$ime`s9_/2'fAhQ)C:JeEC;d;%8.l(.'*Ss*pQHU.lCeC#?<G^CjK2cDp&,ip)$pLV0#:8GkO>H3L8QPJq-7SEB>xl[aV2N$ow>S[ZVb#$Jt[e*%1>T.21uBp]BKkl8rw.%/&PYmj)u]56mj4(2s--2lpkGMsmwG&l($U%^8r4.,&U_O6d@Agc@:w$ocr6#%/5##*/rfM3sDRjSbV5']X2(oD.xvNe/mrFaT/<7G^bVHARR-HPxS2`EGi-2aZVO^tFO.Ffpre0kV%G#PDM(=,S,qNAvrR><8mEnlSh.HaYsA#ffi`.4^g@#$obR-q68f$I#Qhlmk%<-wX15/.Sl##W@,c*?=XlL%3Fa*DO,R/Q`V4n?TO<MlSof&sPFp_&3H<u[oc+#Bx'/#36Uj$KJ<%U'%;a*7ata*vNU01^Q0B(efU.;djL_J9`va$P7)s*N_]>-0X@q$rG4h6v2I-&:I7VQF5dPJU`(/1iT6JC0J7>-C*;2+RNki0&JG,%*H(C&^Q1pn@q-F%[[GM(f9%w,L)Nj$SY5<-mK*=*n)>R%XFJZ-1G]B.2Ys;,+XrW0]nZY#49e[tPCM]k+p:D3`kqAIl.d%&QcXM],bfj0HM`f)$ta5,E[vkLiZ>U&G45X@%n7T&wj2lLf'NIN'c/^1'r4?5F.'U[Ed:a)rhWU.ZVd8/u<Af$YhWrp>4P(N(caZ+^*i6sFeC+rh`:/U0g98%r.fr6D+p-2pc`/%:.n)3wJ0pnmc+:]9vAh)+6p7L.L1N(gcEl>/Pvv$XBJ60MDIoh3MR*&Q)###7`M]bdr<A+vBrL3[1E2iZp7S[-tEc*<pFe2H.kT[H):b(BcLpn-AKt[Tp73O&b.9.nT=j-j<^YAWO=j1C^8@^x^H[>'>$j:GG)Y-9)ds89kc1%6FH;#4`($#@4g>%6mZD3f>Jt[w@xl[u?[R]L5ss[*P=2]gk%t[cmlQW6D*)#cWtGMXddh2>L%`%s'N?#OlsP'cWL`W^]O=Qt>q^#lw(G#*er6#h/_m/s4=&#*E-(#R4SJlmQh02Il(pnk2M4KPKeM10W=K2Pg2Z2@MJ>gl-Is*sv4<-$T`M1n,Rh(#4A?54VkL(HDnDc?A5f*+KW?-VK=,ms.N<B`g[xggjsh_qmh#$tv.7#Ubf[S7q]Vmi<3e$m*==K*?Y/.UYT/M6I<u14*<d*Pvh&FAh(T/(S_FEc9Z[J,xSfL;+Aj+jGsa*]ZC>-Z:eC@a_h-QAGlon(2Kt[>*wYPFiLpnPL0q[7;(6'HT-3(TeEs-coI)TV_#<'7lu^]a8hdD]AE;R6,#>'&>E`#Iu.7#*UXM$/UR`$PIY##Xn'N$<)wD36Uc##_;qB#f8/X[]X83$=r$<$_t7?#WbOm#d?ke`Eq(T/F2@@.11ma;#7Xl=0XFq]qsG%.;wCIN%(IAOZde`*23Pj9_]9>ZFuV/:OsZC#_C2vGq*NG`(fbo7n_<.26p;r7jY`D+X[Ar7*p;r7^lRa+dF'E'0H1h.L,?G2esBl)lshE&>)OI3*JWjT^Ae#B[#iH+'aIY/dUH>#4U*p#./ln*mCb:.$+t2$%(6Z$BUV0G75%&4Xat4S+>E]`77YY#54P877?JDjEQ(,)bY/S[$+?B(I^^>$AS*.2jIu'&g.2W-DGk=Ap4j0(h8ji0s'7@'<v&+NmxlP(+(Dd*+^hW-`;#5)i0I>#9P8a#x%###o>$(#04###FrW.2R4n`*1(AT.)V=2]X'b,5b$xL(2X:@5F19q[R`9D5e>``3SV>c4oVHQ)$wJJ1Z]?=7EsEt.blTj2;o,(+u7@J;*]Ov8$bUq6?_&e*Q2FhL/m?>#Qi6/U5W^MTlH*20n_<.2[7R^&h51A#*4#?-SMB/MwRpmCcZLI,i0-lKL2(r&$:sr.N/@V/P(ac+Y-6q&CqwsAbdu831-j@,/YfP'.KNG7qIrK$_a9b$v6>##Fww%#_#/X[fYQQ#<Fe<$6pQ)3R^KT%Nv`b=#Rq2U>0U%av+R`;@7BY&S4dd$Z9XG`v(=l>OPhXQVwR5'6D5V*6?sI39>_f_QZW]FL?PlonD.U#00H%>x[O&#kL`o@B(#^$e92,#PsI-#9O###PePG3)NFonSOkT[&aMj$%U,gbb?P/2&%<0]9Gxl[*QTm,+C]T]874p%>^t],G(O#-B*Z*7(YQs*a++H&5Dcs*A0F7/.q]j0V9+5ARThhhiYvv$J><j1P4d9UF##:.N]=Iumd.OTO13(8pc&p0-7.g:,07buP9&am)<@mKCc:@E@pcC+Jw)D58E>Dud%G6#kD,MTZ^^D33]UV$VeDM0rO)W-VdTRD&Ykm$X>kKPx(f+M/mMv#_HwS&`gaL&UHCD3[o12T:u9clDL5n$]xhI:.=B>5Jvp&-XoNuL^PYa$C4=&#$3pc$imX@#SIn-2l@g*%CRb'G:paG6jMLU%RLE*3)rs9Dr6kp%G+B+399'1(>DiLCueBZ-)M4I)ZKbg'FiMO3,7e'6$Q?%X*h$,MdOnN:Y6S3&B97??to'fh-I^r*i$-t-2W;uLUQKvLn92'#D8v8+Uh%t[0]iE/&tT,/I&gBOG2:02]r:0]nM7gYulhU%Jj2g)LvOg73aM3XU*ki0iniK(sD^q.[_Mv)LdTT%Rs'W-8%g+6035cg0_i8._%NT/>2h[6WFl/MP'FcOTHD`ap>DCu<9v:8>'8bRMtM`*vEl^#x#J899Q*1P?FbTPXF[??v]Pf3Fww?O_xC>?KX8`5TF&c$5D(##*qB-de)sx+Pk.W-:,<+WU:)I3g-=nSHgpIt&7>##&j?x-'*at*-brq/u_n5#id5m&,KB/HAaUpnv?bU%;W5x#:.$%$wlvk0m5Jm6;1uF`_en+MPDGdMq3OA`c>6##+[V<%a;2,#x>$(##3/Z$L:gF3ljEon2SKX[Bf^&(?GiD+-t+56DV*Z2GXnhhBY1pnp`JX[5Q;a0k0;Z)MvVv2oUK&4ui0r-nkf9&L;`/(NZs-]Y'`n[<:f$'_<=W$s^]T](Dg;-.hG<->RO;jA%t>5=dBT%n-Js$K)9;-D))e2/7-A#aAnh2Qr-x6Xmit6KNfeiM8Hv$OLem/]CI8%ZFL8.eF4f%:2EG3<bFt$>-(Q9g*w(NDlT-Ql%Ff1R$ZE4UslY>a`mND1jbI#S6h+4EZ]LV7H5@7l]8]?EujXc6MhLg4UOM^Ye8u.RHeAI`Pp06pZ])5i2KlSGU4vc<(+,)<Wk%=;Hf$#Tvg5#pu7d21*b5,bU`>#L(e)3`&/X[f_5a$wrUU%G`6)3SU0q[fb`W[uE;Z)4_Zv$_mon8vb7p&nCwP/cSNI3DNAX-RdJ,3i?Yj$c5u$g[1^p#[`F-dQXa$T1^W:Q7/NoeieDH3BjlXcJ&gw^mUhJuUY8j-Q3n0#_@DMMFrQ+#o90eZ4XSX[VXs;(=_/X[$qD^(f(wM0&qfj0+igw#xZ[s*Ue[<-FJGd$_+2W-r=/-F/U1N(m>:Z-IQ=<-Dj%v&0[Vs#i_T@%+*Y20r1-<$M,@D*o:r2D7PRE3Vnct7U[Vd*/s=fh[O<v%u1nc?j?n8+?&:7'cl#R]Xx/+*HN5Y[KTCj$uUe8.F>eC#PdS,3^fO0Pw@*a+,@%rS-pB]bb9B$He:Ha:),sVRx#M.hlk;W-I;=tUnPT)5.YSWS]e6##CH:;$N'p=#t]Q(#N,Bk$L^878WiE'.6A.E3:iKt[o'2oAtpL50r%r;-C+20@?S[A,HTv?->+*N-S)u@#8&e)3X^#R/$hba*0;[)0m5sp/:L1U&xp;lLjGL?-[,o&%L;*F3<]WF3CJp;-X+5^(Ev*P(Jq-0)#*ahLO9dLOa-DHGs@RF#H<QRN3+hA?=@&[#?)tBu`>FRj3@X:09F,vccX_QE`$km()*=206AC#7K;UIU?Wb'++Xx(6GY4kK=HIG*xs8X-I_`@,0.Hq0NRL-#g]5ju5p%p$/g1$#cJj/%=Xot[oCXM][Bfj0w@55&.CY2reT20C*d;s%Y7_s%l?ufL1V6^rK3vM(lER&gMhBpu5]&Z>$C./_@dQ4fY$[Y#r+TV-,oQ-HW=35&c?VtM@PHX$]Z;d&g6]?#MT#P&e6/.i*T6_#0P(Z#NQSMuiA3s=o(C^#Wng=8j%12U0%i5'@WsR8YXDs[x1xl[GcDY$=Bo58.tnP'N](W-J)VBof[3p%sr[0(6]ws&TG>l9p@ii4Qh<C&f18AbR=C8.UYa$TDJq:m*wQ.<DMvY>i6Aw8#ca)YW0KV%`$jERI:..i>hAQ'q;#B,>c2n,7k]R/#fN:mWJ=*_H%73#0D^kLb8jJ:<^Zv$oT3DEXu^-4@OLp7?t_qSHsu@4ojsmtn/5##J%Tm$fI,[.Y?O&#+I0(%*j^@#xfPM'NRi;*U>-:%[0/j0vrJX[)Jb)'kw>S[:@Mv)sRdU%7C=1(nJji0*g0pnc'kE*nb#B(?L/K.5iQs-'r&]9YB8x$V*'aaZ/n't^[M7#Wq=Z,Hjo0#+WC(&fO3H+V$qI)U#Ig%V',)#k9fL('l+?52[g%']ax9.4*x9.T6Oc%c,6/(i$6Q';?W8.(V#c#.qa8ude)v,Ci$A=[hYM(8a=Q/Y#S79c;,d$Lrfau0TH_us9TQ$LI#H3a/v?AF*,##kH:;$lv]7.2/Ug*qE'Y-pa3.iX5<k`i7aZsFB_*#M@PwLP>]>.Hqh4]mR`i0-OWF3Oxa.2x+pt[8DXM]h5$*386h5#fE'T%;Q8S[E<Bm,&4aV%@$:2(nJji0fGft[E[nQ/wQi;*KN+@#gV=W%g_KjLv&=B,kP'U[%q.W*a-I8.W7$B(dYBq[QG9D5OFtT[?,?G2FDeC#p'7Hb3pP<.(5Rv$(o0N(u3YD#&HD]bcA7M#^9r.171JFfswc1BPBvj<fds[Lb-fN%,)wCueXk0&VV[j4a#Yu#3gtX:?I9-m9_-iLa$S(#]^<Z2^rSB#td(H&<k_gL8S..2f[W20=ZDj$AXW*3N?taeUK,:]2dgj0scn>#r*2Z)YxCT.i-&t[(2=n-UugWhP=+)#mpOgL^ev8/L=bH;W;G)4,a`1fM_rW'M^0#$lMVO'62Cv-HC>b#a]?(5;u3A#'P:C6YZLc%VHOF5d;XIQq#Nr&qPro05dAR;lm^l:fC?b>_-qC:-f3v7PHP@?lF4i(1x8[3MtS[#Am]88ev0=4NF$q&k`manqkd;-?OA#+$0EO9D7Z;%:pWv$<lB3t*g.K%6gC1.[nao9XDED#Fo0N(81^p#%YmSu,o5ft##cEtT7:btA)(X8N1q=#M?O&#ex:Ka(w&Q,osBX$BQ%@,oDai%;G[C#SWiK*rJqQ&0oR0(ElZ9M=,)C&uc0q['%Y;.6U#K1s.Pu[iSRh(1lPu[wf,F%O0S49L[kM(L*0X&U+>[2k/Qd<D#Mu$jgQpKcS5'8Zl@m-?3fppaI$##ma'Z>*F;J:2bIoA%A%kV]Xpg/gfRh(o_r>5p;-2:UH4wR/Paj$%ug>$/A0,.G9D6N-1P-;IB0j(*Pi5/1ipA(Z4:h:F>mV[$&f?;EYMd*P`5W*5XFZ-uj/RLfaA-;Rhg;.p<VwIFf_x&]1BpuH*>@&MQXW-m^.C?=@_l82)-Z$aNXR-vo3i%<kD#&6I/X[cBh)'mh1m+Wj?.VRZaJ27l8t2e6j;-+?+k%+2bR'4(6a*9RA=-?8?bY<f*F3Bc?U+.%v=P<KqG)cwVm']`[`*Djnb>:esR88[W&H%=5,M_4Fa*SS0b3fW2W#g;/X[^k4K%xH,K%?[i>#-o>cGKStfM8)#d;LJ[`$#>OM$v#g*#,))<-BNA#+-Jil*c<Km*Aw^<-MH/,&&'$Z>c2mx4tL%=-`g2u,iGl_d2X1N($]Ul/X4U8%F,>>#9M'gLh3#&#fSt8*jR%Q,(PIH;)dmr[U^4a%:/ZwJGfd6)xLaI;R/%(#LbH,vi:(r$OYI%#1GV-EHW]X[(ipA($<:A#hvY,3')0X[8d2N$>WSX%*f(Z,LvOg7bE]j02L)LM;_.V%;[b1(j>ji0(Ls+3wDQU%=E[s-J.Q#)w6jgD'Jp02*W>G2WDEb38eH)41xq<J.h6g),^tR8lQ#<.bhR@#B3T9%NksB#`7NK#v*;87UmuhP[B1purNK_fV-fY#Xv>`#TuRJ1^GE^4Z7iuPS@>TDe<_+H%Q$sLFiKwT6LTrm6/2lSMfq_,75u&6j@#29<k.T&r?*'625.E3pQ7Or1);-2V5X<U_F;##QT1N$%/FM2:L<?#,hBD3:33D#AJHC#s0pE#9=$;6#dJ=u6ULxOXUt`*7%vd;sKdZ$O:2,#6G$h*BtWW-sEq'HSa&(%fgB9%b*&t[X$@xI#6ve</p]G3`sx;-)C#)%8(#bu]GpkLK&&$&<t9D36*8$#b@tD'D@8RqTs7S[1t7Z&Ibw(<fA38;/(^G&Gt@X-?C3B6snxSuq+XC8&CSDt#JnmKgM,W-Ts4kkB`)lk+<1,2l76E3+Z=O%N_H)N.V%K%Ct7?#jSSCX#_Q.4f/4c1BL1p%&jM2gnGfI:'=:1<4%co7F9d;%=h=(.fJZ.OkN.K%DPNj;e/Cq%23N/P=#t>0M/bT%kF'E'B%Lns&3v;ATQRI-grVB%/;4QCK=6##wn,Z$-G%'&RG###u4DE%HoEon`,Jt[fW2W#wl/X[qTHa'sqNm#PrY16^xcd$Xl2]-(0^o%gcM_=c7<`##HN/M#7lMuEKTul*wQ.<OYKM^CA><%RXJpt;PAn$N>uu#gC(##'teERhW_c)C>IdFk'i;*AqhgLW2qb*HF*<-0[cHn1wCHMCqW)'xgj;-;*0k0XFq;*p^n8+7YUp+6<-B=arSFcd2QJ($4rDfcO*U.YFTm$@(^T<`WXAuTfpIt(wJG&Xc(?P8u7S[Z*YW%X7@FO.p%2JkX2u7BGb1<&28?(`el'#>lk.#jw+^$A(+&#$F&6%9iEon@ljT[i%Jg%-ECW-$+Z#)kw>S[&ZDj$;4w)33,1pnQoY7&GEM^$l$aW[5iHb%/I]j0vcji0*h&S%`TAX-joEb3n3H)4^0Y<%%s(u$ZVd8/eKY6<;<#j#n-MEuC*q->X^n-Qih?Y5=KBb>KV3;?1+Y98RCaZ-T8M7R=U5'#Pi(W-h#U9V61*20xRg4]n+S(Q;j@iL5V*r7$MP8/s?hA#2qTe%%SxW[uZ.W*OgO@#5jH)38iS(%WCHB?a(?t7mDgbaMQg9V:VqM(cC*W-=7,(bk]D^4F+EJC^6G8.UjcLPh)3SNI2m`3PN)AXS`[V%d6DiB^AwY>+3RP8k&r-H_Z>8MK-s+Mr+'v,^,:Y'^j1B,M>ZPJO@`m'1bVf:gxK1&+(/X[(@v>)aq;u%kw>S[xYDj$o:?U%3+o0((GC0c>$gt[A55d$msBX$[]S&(*peK(0,bH;nf'B#g]OjLd[&J34o0N(sr]b*b1Sg1GS>8HTV<CSOFe/flKMkL@8vpu%b>`#ccCK#8RiOtv`GFu%%wB7^<t46;4n0#Sj?S@pu_fU<u>OI;DmV@I:coIR&(G;8WN8At+@cRn,D@,sR3r]3qMG9i1td<au>OIbM51#:[*X$@xw%#Onl+#Et###%)*Z$n;Z02oIg*%1IJt[&P5W-gU?o`/xWS&RLE*3^t0q['l%t[5Y=2]eEc)34/Sh(r%5Y[Wdh/%E',)#>I'kL$]0b*G5]m/k::8.4`p>,gNckij+=a*xG@I2q+KoNkIA%HTE]);#FJd>4ENjnl]]I04mG:$$FKU;ACju7OXPf*-22F3Acuu#Wl'##USP]kM><A+G;->>Pg[GMc*f.2EHlZgVBKt[jd2W#.>0X[hpD^(fsGa+f`d*<SBOQ':xd2-jE$beF]bEnvM[L(Ov56&hp5a+;#fa*ZdEQ/dqh[,V5MG)1RTa<xr%?5Pj@^J[ji5:@@Zr6O]$]-l#b:Q?%bS0[ma:QnZtVBETFZ%/(7<A%3hQ+rjob+#&#+Fjo###m&:kb`D)kbZd3-M-TcGMaf'Q&g#Ef=KY:i#F7H$$Tx9+`/.35&%f.d2405P(nt+GM:B]$#htY#)oew5#D2-:]%Q@=d38op&J`<.2lcU$BEw/X[xg)B(Qq&T.jk%t[8[3308):b(+sKpnCa?f=nB?QsuBL`$osjT[_vs8+SiPs*F,CN$WF/`=b^:(&gO3H+N=41(_xO#)iUch2x<uD#W1tD#hffk;>Io>.$*x9.U%`v#jNFK1sI^v5ZVlM#ePCSuuMoc)6[lF:KJj@$oGi]4[g+0J]+(nu4TH_umeNp#Y7;aupGFZ8,l8gMd_w7n/UVtZ:R%##NX$_]4=T01/72Z)etnV$%jp5&/6):)%0Y4Mh>q^=1hrS&Zc/v..uv9..#Z4MO8AV#]s=,B^w,ruWZpAAFI-.sH?Gl19.Og,#(n:H9Z+.$%mBj<Z2;JLL+)J:jlY30CS2GV%:&##dIa)#P^4oLZ_i'#Ut(E0Uh%t[o$h`$,6g*%AhJt[+e2W#/fMb=CF5s.YWl&,2UEp.0(t300l%t[q;Rh(rLBrK7stY-7L9S/UHL,3l5MG)j1GmA?cp58.1Vv<L`I_u_prF5VwO`uHV-2=8dDqMp'G4:`K9*;DL(-<@$?/E;?H<2>g`S089WTJrju^6')s#58Hu$J[v8S8pRhxlM`Bs%TBWnAodB#$;ZI#$)ks;-WOnu'BVaB=fB.+O+0pok?sL($CbSa#YM9^#GvU9Jw.[#mE^to%j+r4JCEQt.+wCH&*loQ_-,L8OIJes*rR8U)'$6qV<kJt[+YV*/$l%t[@UUgaw_]L(0c5Y[Qo8p=0IC#$KL.FN8,5+d(1=Z'_F-]$/Ep_4mJ7m0TUP`4whBq/R9MfLLL-##[H:;$h]9u=.F$Z$=r]^=8j6w^.:JX[ZJ&E'3#>p&7*HrK&oBFe5)agr97,uIXsf*4xp$KaM*.j<#Z`2`bYgc.0>uu#j.OJ-me.b%hJi#p6D`-2-EM/:B04Q';#rgLvBp49b#oPBI+KH#wC81(4FS_=PYU/)k*+_&7iArK1icUALWbA#IT1T%0Co8%ZFL8.2P[m01#S;6ZYuM#/[tF:T7YY%$@hs9lK*/2<g+0JqUT#$H6;au;AWa6F0/_%P$7wg[/R-F['k;(APxl[.ux,&:.ji0G8GJ(wFJ>5G.tT[l+a/%XL7=-om4g$B-QJ(ud_`<W2g1evSwdu<kgquxS8=u3d5ju#K2OuTw[j%-.c9MM3K]=5bZZ$C>1,2+/VC$oIka*C5-<-0usj$qRo3i4L1N(^IU`.(EYoumqll$mBtA##-g*#U1FcMd%/^=M(kn2%jqH%mWs;-r?qS-$90W$4,ieD)dih+,&Bc*-]b4MV;$^=(N#qr.s8gL'HWY$6MREncxS#$g*a2/5kZM9ZN+O=;:X)OkH]5&sr??NA2''((J>YnO4)e'?^,C6nCYE15212Ml>ou,+d$s?-/7rg'&3/%,-;0]6PtYFo_wS^Qnt'46otM($-:#$Hc;MeJO/BT$9aM9S*$P.g$Es$Zt$r/vLg4]sR`i0u;konsfJt[33'W$GW+f*a].N9['FB,b7X)'C-.hLJPpl'LvOg78*^j0+/ki0TN3T.k9Am,1(xW-hadOi>_kD#c(*qI0:pgMbHDTp:o4I)No%xlE9P&u4`Hf1r_pfL(&7&4K%Q`2,rJfLY$@##<[uf$q.%8#02<)#;/:/#EX@-dU4^F3DVlon/vAv7kvKX[Y'[55*i-L330H9i8MI*3dh?C#Yk1X[)@b)0FtX)0YMUA#9&Rd2VB0Q,)k1H&7mQ=.GEpD9B#L/)&E8)=1LDn0sYBq[&2:D5>qGlLh/CQ&PPxG&sm-HMOffF4Rq@.*?_2,[)oKb*4&0>-U]*rPJrchM6nvi4@,OM.ldePNwL-(AEtXx-t/JW-&8Pw?@U>56.Ym$6f#QN'_B_80VUc`#QTc'&+c#p:<*>TBa$VF*xHc.qja6=.[&GAu$c7h'j5-&*=b[l%qu[v5_*X46q=@s$*),##xng#$9qg:#(7pW.PHCD3ZMw6QMpXhu'DLPM>Ra^%:>xl[:rn1:k=??$^f.K%w9AYAleBFe*]tlH$X0:usu:3;l6SBf[lOfCcTRVQ]Vm-*guf4][R`i0rcJt[W4:p$0)eC#/`_,do%],&t;mQ&-,u@#Z'Lj$vxn#%N;*F3/xWD#EU@lL+I1N(?K:T%NH4)L;u):'AT<GEEXc0E6T;;?;$*VQa8v>#fDtA#U#pU/bLA'Z6$58nl>$AIQ'4=>&ak[p=56N9A@tY-G6/wp>v%T#;1%=q2M/Z-5rXC.RK(T@2Bu@I=6lonQMWSS2hsG-A3TvIHxqa%tlIfL$Z(d22Y#6rZ0<$#dOBa'/d1H*4:lfLBEo(<Hhq@I.fi0>W$5B,bkh8.pIrA&Y8o4]O8ATDI%kLT/'rt0;]e_uO<99To.3pC'Nv($-ox+,=Av;.l2B@RorlVHZfv@Ii8bJ-$2HH.qQ.W*'m+HMDGg8)Y67a*.h+HM[c<3&+.R,XlF2*/E]=GD5RS$T%bZ5$9-5+@1+T/>TZ1^YHj$A4lbn9%&m'##rCiwT*)n3D]ua)'gov@IMBP2>jsOoN0,I/8UsiUMRlJ&#ow36/.Vs)#>/Sc;wGv;%9XCgL_EM-2+akonIE:&>varS&nMCT._$aW[VrYD%Rb0a<;19Z-XjI(>N&&oSqnc=7p,oL3$p)AX;CQo7pO'+uJwNRNOawq$tmjfW^$:E5B>hgM[4/^FXF@iLq48G;*:HZ$Aqg:#+),hL8V*r7$MP8/vXw@ICISZ$X#FQADg1nWgAvQ&5mw@IZU[t$eD?p.TekD#v06r@T3w5/AAH>,0NDG;K6gkO;LC4OBG6VmYc,b1_;3B4(*(J4#(n:HYqPN=$79ZH,6,F#0a^vJ(%g+MLWO)#;LY:=M@Y(H>f[E3oS/X[uZr;*W09d*-vFo$Ew/X[n#a#)=(*k(IBo?#G+B+3UpHC,itY#)QP'U[,u9a'L&;/(nPLT.)<>x6SnN;(C*lD#XqpAAoxPE?:khcT/(NK1]3Dcuh?)B#kKSR_iG.?.#$I]OK)VS@')YV--&jNXJ;G##Ro9`04eq/#[-4&#:[@e*uFu]-0e6%Ymu8U)QQKt[sv.%Y)p3qSq(j1gt[Qp>g)ZPhx(CV'tLS1('N9I$+prQuY3?#74*`1pJjD>#]-`:Q?%J>cfDBYGP+W20voJt[/>xl[W*lUIv-e$$*OpG/SK0jheDft[=1I8`Hl6W.LvOg7,I]j0K[O/M$vl&#+^uJ.Hiq1:FJD8]?1^q)CK6r%(/RB#bg`)'lP'U[rVeh2',B+4L=6g)*?ufc#+hb*,88K1x)Qv$pn0N(4BUl]T/mUI)<8N0,5]cJt&VTVN#'9eC5v&TUNCYuB$pU/I[t'u?PZ64cqc<IgWieh(d``*]JZm/^q46#1Yu##GiK`$>kM29wQV8&lT==-1kfj-K0pTVBZo_OYVs%$IEi%OE'8M0;ibru/.UITkYj]O$5^Fi3PX'#TE31#m120$=+%&GUQZZ$SIn-2KS@l`Ts7S[W%cC.0Pxl[jEKT.t$aW[UY>S(4^`g%2VYV-4Pv$Gv8Im0/Had*L?qp.$Dn7@Zw-1qUr5sIlv01q(JpTV_Ud%FWI62U?w%ja87VuP3]x.COV#v#Vq%/1G-SI'40/n+f2=1)%ZlV$'wKKfr#at*/XKgL.-fiL1g$=NMu2$#W838-Jlti]9CwS%q/gxFQ6l#-pG+j7Mjx7M$rJfL5lqj&ao6##3Yqr$#og:#p&U'#]s#<*Uh+N0:>xl[2fN&1VNJ39G5k31EL[hh>M1pnnYJX[Nbh`$Kq0pnWf&`?N2%Ns;_-a$s&kT[e;p5,N.Mp+IG?K%;i[i1rCbA#79:l2>j9s$4_u]>)Ip43#f^W&6EfuPBfriF6Z@;=]Y&&$f,Ps0<Y[_u>KU?,ETEigQ)l@O9nSOI+.E#&XnpgjN@6##C43U-/]_<GuG2'omZhA=@>X^,/s=fh]-i[eVc6b<DUgJ)Q(]u0srCM:A%'Z-t933&V>&T#j[R`N@YVMF3e(JC6Usx=:.p8]728`N-sTQqq&Moe3_$b[9;v;.:2g(%govX.21cOKK`jgE6L1N(miMn)`8(tAeVoQ.9&>8RI)m20Dssl]M,@D*i>F?@Ld7&%NsO<-H/UX'$9L#G[u@p]Woje)^a%a$huW)*k$T#G$=(A7=,R:93ct]u$u&iu8d0w%;qBg1T?3hum,7W$`l9'#5T(R<S03W[p1p>2]9`FN#Q[Q0=U_84HCN,8L`2U%v[?##4`sA1?0(a<p0jS]_BRiLrU$lL3QR12VIMpnCxki0Ff.O([OZD5>A7,)/Y<hDuO&c5OD9qDE0J4;C]:DjiXWq.WWWhulf-A.FKbTBF0&=%f$xV$#H4w#LvOg7+KUW(MYc;-LKdl$fS.0(1$t/%gYJw]/@uM(%qc[$MMs<<o=BZ-$fID3J])T.T-^GVg?>>B4jY,2ljEonaBF,MiY)v#;tH[/+(^fL_<$^=52;I3TL<nSiKGSu`BMG#AXN.DL>o^fK>uu#aN4[P83cSR,Okr$th=*O3adouow,V#2L-c=T>q#v$]qr$OfJ=#W]Ab*r9o=-bHp'-+uTb*'(.H-`Hp'-IjN1)q-t*,w%3Vt-1%Z>TXbO'$&7rm#lhl/Ld0'#ju(g$e:r%+uN3+NC4)4)#9i%+N6MD-S1)4)_.jx*Y4R9.8_w<VK%xj'D`MkuE*018Bb.B#Velo79J:B#u/dtu?RD+(rr9Z&sfgxLo9(p75/1B#ZkS,q&/.R/xqmi0Pp&v#uf-N0kn:$#GF.%#i9v8+cc+<-nih-koLtD'Gl/F3)a'pno<[C#LrS#e_6a?##cN:%6m(C&gmt;-/.VT.)c=2]&FV7H'jRh(@Oj;-4*_*ufDsI3F>l-$K:<:.g]KEgCcHt-<J>$MGLvu#mas;-iG]v$aj1?.b8v2$>6`I3$t@g)F^Ap72&wV%(xQm8V#I6'MP'U[v1j/%<TNa*1f-q7NHdp0>2E=g[QOT0Giu(LN['^#wXsn&1cI+<+ebA#9^=>%j+m2'#Eo?#cHt8%PHYm#VM9D5dOo5#$x+1(;bM1)'t=]#m'Q,a'Ech$><x[%.eLDN4.Ha*?vmkL=n`C$E)q)9+0_^>&Bnn[?aaDE#fK#5n3#F#-2(n#o5>##7r2]-FA>AFhgmqW`5'J_dC?>#cK3RM]qJ%#rxw*+[dN<-QAX^%5SNnMY8-##OHi>$iOV[-2PM:2;^CVmc7UM^LfOV-2n(p]deuC+@st&#l7)3'`=T;-Rsgh43.@x6KAoO(J`o60iDCVmW?w>BE=+G2;JS&#n%kB-H=kB-nBkB-tNE3MvG[61;FYI)EcAmAqm=n0bU/;/sFovIR$<HM3dk[tqIx%+qf9hMYPm_dT*I#BE/JfLMR6##d^Z_#+$JfL7dj$#i84^(6Z?D3UT;bR1vZ)3j;IhLTN?%E@``s%hk>^(&&Q/)?keG3oo-pA]9.d<EA//.,Bg0MmUNmLu$v8.6oOfCdCNGN=Gx&#?;<E3sAjS]DrXI)nv#E3N4*Q/XeCj1%O2.h@1_?$:(,?E.6R?8+V>W-?]Q6j5Ax]uRZE1#s&-L/qhpA(;LLcMTpCdMYe,gh#a^pnBx/q[Y44R-YF4R-l,,d$DOl(N=+:%/*m-B=eZn3Fv3<W-&A@T9TR-##>I:;$U:2,#9EVlKC9lon4GVlKJ^Lpn4GVlKF]sR#;o>JLo(J5$&m%2K?G(3u'IN)#BU1).e^S;K/ZX&#&-8oAG8EW[aD8S[)%Q#):/<>(@qfj07*Xk'h%xG&*#ik&.Ift[cr'5%Jn@X-if*F3BH`hL(>pV-m:H*RTvR7NREvd.Ir$O#1lrE/O/cjuRCmtLN#@>#ER1v#S*V$#ejrD'hEb8%Z-/j0&VbA#anEs-uD_HM9Y5W-2'IhGrk9u?N33K;0c#o:vRN/1])dqp<p-%7?U'4;':*/13sI-#,NV,#G7>##(>8:&:--E3f*F8%xVKp%h/K#ML*'t[2DtYFgD]5'NhCl%D<k72dd'-%Uc-F%=N8ZaY@?Nes:F&#OWEZHUowAXS(5wg8D18.DqCP83a7JCk,j4]_R`i08C1I$N:tS=BLp%$ImN23I:1X[<T[)0`?kA:>eH3(7g[ihvvqgL]OF/2`6ofLs_o62]r:0]3Sxl[78@i$.T(C&k50q[%l%t[]%;9.T@`26REeM1UW*N1VmfmL&#ZoLb$<8(jS+C&5;WpnqV/F%72SL(2X:@5Eqx_>Y<nM1OK.a$qbKq@.[Vh)$_Aj0*q-0)[3*v#kvt=$Lw5g)Kpx>-4-pY-Kge[YB$K7JSI]i)PSgjs9fB-F48rDZe5(pt&&OX-iaOI)5WTj(bFsoC([P59S4ou-7%bfMK+a&-xMs`><rj&@/C7e47c<^[s3W1-kVADX(VL8.XCcHGtqgCWIx,Gu%SZRtQq(h+ld+A#vCZ(+OCI@#aT;AAUg:RBgl]0+jWo@#v1?(+Kmr:Mmw[:.HOsC,=1G&#=Fe#:_oOfC>AacM<I93;T66$2PiWp^.x:T.OuA50P(EHEo[-##io]a#*`M4#J?O&#hfOO%g7V$#ck`W[h.Jg%[SMj$dH+Y$'3=1)twEx#?HMG#_2rJpm*lbBRaHcuu6+M?bUx88^LT(sw[oV[<VYvMnmW328,?G2LW#x#rXR@#eoZmIj`i]'q3n0#tMXr-<MVonUi#v#)Jl>#g$b30Aw&pt<Z-#Yo_p--.dZ(#Wb>n$MqB'#WHCW$0T_A#B0L2(_#/X[#H6Q#/8Ps*9NL,2$2pt[:?#h1*rpA(e*J?#>v1a0p:%q8ktT(,/g&?)Q2-:]G^gj0IV%,*wWe8+V]GW-x(I['G?^j0H=f.M4GR?$57P&#J;]#%njrI3Vdk-$27Zx%VU5V^B0d-&L$9Z-TekD#w3^)^HCKf_x>H?u.oc`#Pq+DM,ij/2v[p''>3>S.Q;p7ef;B2c].`O(GRe2VUO0&^`?XW'wA]nijbc_#'DI/(ZtZ##>BCG)h]i+MQ0gfLg/PonmvbgLQ<?>#k<6'#e-&t[bw81;RCdv$hrGm&;h0r.E+0q[KM#r[Z&jW[^]]&(eOBa'6,#<*Jomo'bYBq[VM9D5B2=1)]BF:.jQ/@#.j5A#q>EZ5^8dJ(a5Ghkb+u&WC3[lYL)Gj$J,)KuS#brLDPXsu#a$Ku]oNpu&F.[u1]_p$@Ai.USG;&4,f+87gf/S[1bRs*>>]=6>o0X[if<a0A'uD0npZS0<x`W[g8`,/?h+H/&S0O.0*Y,8K^#Q/#ls[;nkf9&,WTN&ow&i'I70q[^5p*`[V^]$Au'X[e-wP5tv20)]mQ3(n]I'tYK</cZbE1'D$R(+)CaW[4BQd/[Adk027Ue$eXkS]LX7lLcwd1MZS7K%;HoO9KW2W%q$Pn3Mr+@5ctkkL%sQ)0dYC_/i:7b4q^dK%,Z#S/>g[l11UQC#*`n8%dL,c*]@sp/Gcc(5-e[FNVA5g7EhHo[f%Sh(#;5Y[YbnJ7I-<k(^:EM27o;g*McK=-V`mL1UJue<i'1iDAt1u.Rqw't#$qjCCn(u.k:bs%TIoY-ST#(t8;H]mJkdK3Z^sD+nQnQ8FoFQ1eMl#-5_j?#18H6:Wq^;.ZvY11]IS?7o4Et.Ow(R'':*/1,Ux5#cG#/$lB%%#uEq5'82xl[8McIDib_$'sL<4:5>%0seff+4u(#jL1_^=%>jd;%];jV61Z?Q##p6M0L&'D]N&?o[vZwSuhFUpOta%?W$k7I$N+BM8-ZZ-HrC.>l3:35&@8,LW`fIg%u?g/%6F(gL,Q>,2r5tonDB[)cfrv$$RYBq[A,9D5x_t'4Ge`?#>G2]-(_+;m$tcD*w[1Dj8w+Q#>Z(KfhGIlYT.=GM^0w/$Bh,6;A.QV[))b>$0deA#jRad%5K%P1)s`E-(gDE-J4mp1&E9#$jVf(g,'8ulG`:EM',p+MC9*>l5N[#$GL-RE+.xp]2x68%WNI9i/rtA#@@)c<rm%p].33I-QADRC8N[O(oZDb7:-NJM^mDG)/.wS%GVec)Yu8>,N-i4]r=$p0'5TX[jq5^(dneV$>6;_+CD=d&e6=W$b>]/:3oP,*XAfa$%Qm7&tQwV[hk2T+ThtJ1;Pxl[>Tg2-V;Jo[22l`m>1t'4Q:q`$@$F:.VuVY$7o0N(GjMARueu9[2S/kM6,g41$X'lo4VnUh7't7&%wkA#]r>H&L4Z9ivhA>c_%xfDa0O,*_3_W[-eIs*)(r;-Ld.u0tEY//mk%t[ic_J>V>i/%Rt/H*T)*:ST9B_4Q2vO-_+c8no16+`>aODt_####:5m3#0o8gL,1R]k)Io_&YkFJ(2Uo_&Pi68%Tgp_&5pES74Wl_&egv%+Tdp_&YR/2'5Vi_&_$GJ(hBk_&HX3D<p]q_&&u%/1pXn_&t%18.:`i_&gNCG)3Kl_&f?cf(oRn_&3wT`3Ari_&hEcf(G/m_&iBGJ()+o_&`@78%K<p_&uHGJ(>Juu#1:<p%@fQ)a]uf_&kYkr-pT_R*WRJM'D6p_&v]i.L])q_&(It(3vqn_&gs;A+o]q_&pikr-C+j_&B#DfU$$l_&RW(;?kHk_&@c>M93KD].ib#k('4xU.fITj(ZA`T.U9kq(>B`T.iRp/)2A`T.iF^/)lA`T.U#R-)HtG<-Xc*c3Ge/*#Xst.#e)1/#I<x-#U5C/#L4)=-5g(T.B0f-#PSM=-GSR6/Hgb.#9-KkLU3:SMJ@]qL]@]qL))B-#A)m<-,8O<R?KG&#t<dD-eJWY.KaX.#2gG<-_3(@-D)c(.rmXoLlwXrLZ(d.#%BnqL+KG&#V=9C-K<8F-ReF?-qv'w-c(trLW_4rL@M4RM;KG&#-@f>-T3(@-L@xu-]hkOMjh<;Mp(crL?RxqL#/]QMq9CSMeA;/#/PakT+Y`P-k?bJ-&-:1MBMp-#>GgSMF2lCelhg,.c/RqLPpg&USY+rLjLCsLo`4rLMbBK-^lK4.8lWrL;kFrLh0m.#R;L/#uRW2CL]^'/Xw`'/*d$L>/.n-$FYOk+>R=2CT<#mBY>'Y(xq`uGhVncEN5+#H.`$.6/N,R<-obWqT5uKGSCh--EJo3+NNWqD.2<e?9#d3=A)B']*@AVHtZG_/eQi3O_qHe-@a?X(G^(@'`=)W-^Yw?T.qRw9l(+L5qcSfC1.0pp92CkL%it)#M9G)%@7%<-c8r*%B2T']f]f?g_U`4Hac9&OGa4l8DN4mBYl&qrqio+DBaQ'Sm+-AFRCwWU)oH]F<fGvHfVi+MhL33MpGG&#]9&GN(d7/Ok/X?8_4XMCL6I>H>jd>-q_X%(@;o3+fO/_Jo><MB8(/_Jx_W9VA'0F%LS8R*_h0_S;we;-p'7:M%ZL@-Oh(P-FU>lMXeYl$0LAVHBe<-mW.ucMRT=RMj3oiL=wXrL/e:2'ZX=X(x0[3F2O/F%hK+R<XVF>HBrW>-dQ6)F,do`=2+h]GPK:jC1>bl8_.bYHTax&HF0;.MV&B-#_^>2CLDwfDV6B5BRD`MCNw)F@,Y,#HxuF;IOlD5Bnhn--R;U-HZwj8gewc.#u_nI-nq6qM$fXRMrF'@8vo[PBZ_X>->ip?Kp/iB-G[,lMrjCH-F4u8MO*b;MqoUH-gI=-8&vA'fk/X3Xm#]dM41L*#GWDu$M/bl8u7P1ouGr59bJ8;-k<D#Hw&0F%='g'&B(S/1S/f-#WZO.#O;L/#hbWo8YUpfDoAed+H,Z0.(0RqLT*8qLxx.qLbW2E-(B#t&DhqwB-eG59AK`DFrC%L>kQvQNj;q92g%b-6-(n-$Xvf;-ln&P9=h@8JTUnpTOQLsLD1qDM6up%N>GAc&D*i8g0r%qLxTxqL-)8qLP)crL7TxqL#<K$.&$@qLR1:p$3]ocElP^2`.<J$&YYbYHT6o,=mND/#Ln@-#cHsj;vFF[(+uH]FQ-^PBf8VJDdP*dE#9g'&Jp*58dbsp'w;/b-rw2XC#jQEnw1Hs-*m-qLuLvx8T0b>--D5E8T/T5Bmrc3=E'Oe$2KKq;7=4mB1QmEes2YKl3_f'&DOl?Be:.F%s?=-mk+-AF5@v^ohmnKPhsW58k[F_/W$Jr7gb@5B1U?L>Igeo7XLTJD;%r;-7LU9&=%g+M)2.#NekG<-i_nI-_E_w-i<+OMPxc.#8<jf%Fk-#HQDF>Hg)ZMCAP<Q/?,BP8DX=gG&>.FH9Q.F-ulgoD%JD5B?ZIbF.A1nDu5A>B2rCVCRULd2l>.>BgTV=B.J`PB#tDSC2m9oDU%J59,TxUC)B)m96]eFH.'FG-M&ONERRkTBavk<:M-+,H'ditB/i`iFWb0@-d.7=C>.vLFE'^iF,j]>BRweI@Ah5&>39OG-,P0*F76QDF4f`PBHW]?2/Nf:Cq9`9CLW&iFl)FnD8Lb2Ckve:C>'HgD+suhFQ/TgL+_cfGxlkrClBM?pL^3pD:u3cHZd<*eWY(gG0&YVC.o)-G8kVvH+nl`FNVML0u2DgE6@[oDsV:0uACM*H,,lVC=5UO5dSNX1VB+TT$XcQDkp7UC1]HKF6-giFc7CvH=$;qLY%'GM$jkKMXwvgFTe]$M/Mra17m0H-v8'oDufpoD%.t9;E'oFHDvEsL;:.H-4ln+Huntgl=l+vBOdV6ML/5fGSFIf4)--p8eQVD=t1.FHxR-0FcvdQD/8rEH_b*Q/Ev_62$g1eG@/j#7tvmKFx9oh,JQkCIgp^5BC#/qLpo6;B9=^@JideQDAB2dE1[LqLik]TCJr.>-wiRW.R4&REJDoJ;)COt:x2)XBLfcIPI0F@8Klt?0kxtLFG@A_%Kq*k1rvMG-?^XG-PTfZ2:C/eGt,fYBHH>2CvGOVCUit;0$3xUC'V(*Ho1N^-7RxqL`7#F-b$F(I8L=GHhv[:Cm]o.Yw6@dHbp9Q/4v1eGCFt?-xZ?pg8Fv<-fF;.0&cnbH*sOVCW_Xv-7XCqL:/:w-4[LqLx^c:Ca/Sk42^)XB7@ffG>fRU.u2DgESh[j%O-8fG`6)=BU0R$8>`T)lurdX.4HXG-)J'`MFlvRC.<XG-I`<K*3T]aHPqOGH/%+mB$K`A0^$=GHw:`EHTRrNO$^IUCV8M+8j*G3b(8pKF8Qw7MLM3LF`&XaG0&YVCY,1XCilTwH5=tfDc06RC8fMMFDa8R*@wLVCZFcKc?>#29AAo+DJP8JCW*f'&++auGM;1A=<hK/D0SWq)oODYGWdl6BZf;h=>i[V1c:@bH0RZt(s7mR*#WQ*<`daeFLGP%&Dq:MB#jL#6rX]9M>6G_&^umEI>hPY50I#=Vx1h,3/pYc2r=F&#Buh29Pw)*Ge1sgEGKJt9[a;5:u4iaHW0HA-GxK0/5eZL2,&(6(s;0s7NgX>-Mu_<-NQ)U%OW^f1KDgJ2,F3hYC:ZhFgLqk1WC-IWKFs:Qc*r@-Mb(i%NS_8.Om@-#Jj-+<^AhGbce5.#a5C/#du[b%w1<I;8WbA>#RbKcR_<T.E0;,#mvQx-wm-qL)h>oL)4urL8@]qLN9CSMlNEmL,3CkLcD56DiZr`=1HOG-,YD5BjH,01x#WD=x:r*H*BFVCe`#]5bQ?VB+dFrC))_fF1=rE-pxF;C:KOG-8v?oL%b't'H[t@-r.MF8k)q)58BSS+7AL882RO&#>/9)(.4E<-NN)E-j`:x&mKE(?NikjL8G&g%T(7t-/v>980Iem0M&ONE/EwAQmT`/#Sdsj1J%L`EZb-AFCp3^GbEQfCZ)Na3`#S-#UaX.#48_DIAF7+HAGRV1pfa#.R8[7MLNmJ<mk<#Hr%tB8^N8#P]H<hFXepl3,G2eGQctc<9SnMCuvC4;>wXrLa.AqL;wXrLO/lrLWEOJMiX`/#Y*<^%aOZ/25<Xw0HVY?^9e/F%4$(@'JnxK>6^A']>gv9)3Z,R<t)'##Q9d<B9th]Grl1eGGA+G-3oe1PON*hF:>vhFbW?O:*0XMC2jv/*LZ_-9fapv;v(+GMg[GV--VZb%46CW-^&+##*J(v#*P:;$.iqr$2+RS%6C35&:[jl&>tJM'E]mF<tFgT%wFwCW-fJcMxUq4S=Gj(N=eC]OkKu=Y#FeV$3#T(j:6s7R2%@8%9FG`NqHn@kv%DfUox3creaQ(st)7VZ`5Quc4R>MBmeu:QS(f7eQfi:di++PfiuIoe1#Don^w>igqOb1g:-r+DPn?VQ$(_.hbS8GDRI]1pm*m(EM(1DER=L`E2m(GVYq)>G['EYGbKAVHdW]rH0%]4ol2u4Jn>:PJsSUlJ(UFcVwl6MK%53JLTUxLp=W'p%:UWP&>n82'0>^=u2[xi'FHPJ(6]>uu8*1,)N#ic)<H-)*TGe`*X`EA+]x&#,a:^Y,eR>;->J+`s@M's-m-VS.qE75/u^nl/#wNM0'90/1+Qgf1/jGG2P7c@t.x.)37D``3;]@A4?uwx4C7XY5GO9;6Khpr6O*QS7?)LulSB258WZil8[sIM9`5+/:dMbf:hfBG;l($)<$J0S[&j^`<tX;A=xqrx=&4SY>*L4;?$e)]tZ+i:meapr?2'LS@6?-5A:WdlA>pDMBB2&/CFJ]fCJc=GDN%u(ER=U`EVU6AFOd]+`]$3>Ga<juGGYd7neTJVHim+8Im/coIqGCPJu`$2K3Nk=l1*8`j7TOxk2?4]k##[iK';<JL+Ss+M/lScM3.5DN7Fl%O;_L]O?w->PC9euPGQEVQKj&8RO,^oRSD>PSW]u1T[uUiT`77JUdOn+VhhNcVl*0DWpBg%XtZG]Xxs(>Y&6`uY*N@VZ.gw7[2)Xo[6A9P]:Yp1^>rPi^B42J_FLi+`JeIc`N'+DaR?b%bVWB]bZp#>c_2ZuccJ;Vdgcr7ek%Soeo=4PfsUk1gwnKig%1-Jh)Id+i-bDci1$&Dj5<]%k9T=]k=mt=lA/UulEG6VmI`m7nMxMonQ:/PoURf1pYkFip^-(Jq4;0P]<lGi^G%Ll]I<p=ci1r@bVqTuY3S7YcdQ$GrLwwCa,`=crRRcxOZ)]uPM&ToRl,<`s61U,D781SD^CIm/@3SMF.#nt7VY#<-jV#<-$o%Y-.o+x'$FMp7sPudGj^a2B3b2w$I8FVCg<W2B3nV<%UxGhFjp^C%>x/K1>N)nD1A;2F)`*_I&B1`&V_&6CwKvsB$]eFH#3cC&IOjpB-L2a-oT/+%eMtdGpDZD%xS]b-raJF%j*JNMo=mJC.X`8&OY*^-%9cC&l6fjM/DvJC,7Hv$`kpC-4W5W-2X$oN@4^0OKEaj9*m;/D=?op&UrY1F$+*IZB@#LONT/0:jV'T&F]@6/3eF<B/<RqLITsJ:'wI:C'Z<RMEE&K:=sj;%:a>W-eLwNb8Y<RMEE&K:'0j;%@A7Q/f%Sb#LDig:0V(T&C/dW-8k-oNHk(.P<2BeGti5lEl,4nD:o&:B+)YVCvg&+%(QHeObEQLOTpoG;u:ViF3mWRMEN]G;tbp>$7E#W-<l=F7ww>F7Nj_73IkcLOOmO)<]vIv$QbU&4oX,-GBCffG&'AUCA/W7Db:X7DI)&Ur@49oMKvkD<p[Pv$L+^,2^RHbHxVcdG)hM=B4ij^F8IHv$Buhd-&$'+%-mdIO9-ZZG6FHv$Buhd-'*0+%I0gt1B@BSMScZ^=t3NW-6s1`&/#wIOZ>;<H6FHv$d(bB-H/i5/?3G<B;/krLUld>>'wI:C3MTSMQ]m>>IAk;%Fa>W-'3iBfDLTSMUcZ>>*HX7D&tWe$3>a+P&2jiOX]m>>(H0W-,<KF%0)w.OiT.9I2,hY?RM#sI4CHv$^=qo-.<'+%@aZ>8h_`8&VS76/x':oDaTPW8UtJg2a+f^=swHp&]cGHM'tvh2hY#<-i`>W-o.RF%^1RF%l[RF%SEr2B8Ann2>ZWI3`;G)4[l5<-qw_&Os6seNj<&fNaB/fNbH8fNcNAfNcK/JN_)*M2KI*xBeuxwB2kseNL%WeNB%WeNB%WeNC+aeNC+aeNC+aeNR,aeNH,aeNM+aeNH,aeNW+aeNW+aeNX1jeNX1jeNX1jeNgY2u7,u]G3c3aG3c3aG3c3aG3c3aG3c3aG3d<&d3d<&d3d<&d3d<&d3d<&d3hR=K*_6seNd7seNd7seNd7seNfC/fNBD/fN3C/fN3C/fN3C/fN4I8fNCJ8fN9J8fN9J8fN9J8fN]I8fN]I8fN]I8fN]I8fN^OAfN^OAfNIQAfNhOAfNhOAfNhOAfNhOAfNhOAfNhOAfNhOAfNiUJfNiUJfNiUJfNiUJfNiUJfNiUJfNiUJfNiUJfNhRS+Ou;/b-pcxwB-I3INnaQL2IU.<-`;/b-pcxwB-I3IN_bQL2a'3g2`;/b-)Ao-d.RNeNa%WeN9rAN-<_MI0v;.5D(NkVC,90+%dHusBG_(@'76Jt%X^IUC-mgoDI(dPNW%&W?kO$sI1bD<%MY343:=n-NWhv-NXn).NYt2.NZ$<.N[*E.N]0N.N^6W.N_<a.N`Bj.NgjAjMWaQL2cM5h2eu*7D*h`9C;QRnM(:]R9ot>LF?l^#Hu%vLFH7F7/=*J29Sg[7Mq5,0Ne4P<8mUfw']D5-3%/>>#2[oi'(u''#/G###j;k-$*Z$@'*)2Yl$o^>$;+0I$TG,:&^1TY,GuI=BddUS%lbx6*k#r*%>e2.-:b&/1ILcA#?b(B#?Qw7M#nF?-fZ$m1%####Em?-)`lU5#TD)*MU(c.#`3n._Nh#Gr99_G)8:YS7`pglJHnC`sW[)m/`8F/:3*hS@=5BGiQ+fS@-k:)NR/Ys$3NrMB<J@5o]aSAkuJ^5S58^5]JDD#cp+5HDu<(TeQZ$$5?rh#G&#rY>FKfg:oZ[N9N:7Bk_T&M#)vRl'(7T;-FYjfL/QV5MP$8s$H(@>d(D^V-J[VL#aw+/($n'HOmMY:(,LVs%wkE7OK#gg:1hklJ[cP.$orEGMt/QD-$WP8.qJn4$o1XKli4).$d`0HD1]jfLf7;PMWuWuL2aIG$oSjvP]Y+kLE1n=.<ZW5]9Ktm'kkH(%Zt6qND&EC$dBg.$wgma*&ApV-*vjL#UgWX&ZB#b%-Mc[N_rbkLmaeFNbBn##,Tpo%nRvXlePfFiQIExbj;k-$=uX(N??`7[nGk-$MU5R*>s,F%?U?L,O*.L,9:*20+$L1ppMk-$L8m92,.$Z$aZQ&#i%@A-,(@A-9H4v-,+ofLui;aMXj[IMP#j7#X8]jLmKihLCQrhL:nr=-sY[I-I_W#.:@hhLktfwu/M$iLY^.iLQho7MLlpC-MwRu-FOS_Mm_8%#91'C-_4)=-R5T;-:2RA-3M.U.Dw-8#)N#<-bA;=-]6T;-^6T;-_6T;-`6T;-a6T;-c6T;-d6T;-e6T;-f6T;-q;eM0hBBU#$kVW#;?CpL;vQlL7)7tL^,@tLL2ItLM8RtLN>[tLODetLR]NUMqTT5#)j&kLW2CkLal/)vqTl##V8-poc82>5Z>o9V`5lV@pswcalpu+ML*u)#`cb.#C.g*#EIKC-YlL5//,k9#p+vlLc[O)#o5o-#l@;=-HEtJ-Cdq@-q5T;-*)m<-kIKC-7;#-M;'7tL2-@tLL2ItLM8RtLN>[tLODetLPJntLk<ZwLJCdwLmHmwLnNvwLoT)xLpZ2xLqa;xL.)>$Ml/G$M05P$M1;Y$M5S(%McY1%MK`:%M<fC%M=lL%M>rU%MHfK9v2x3xuDpQiL=,fiL?8xiLt%v&#2b''#7TWjLJcbjL#;i#vUu/kLL1CkLN=UkLPIhkLRU$lL.1](#p2N%v%+mlL]<*mLaTNmLEbamL>hjmLTB8#M>NJ#M(Z]#M,I?##vi`qL@-p+MM:-##[(LS-',p7.]6]nL1D<,#l:)=-Gfq@-b:u(.oS,lLlgjmL,B8#M*NJ#M(Z]#M)Ls$#<;ClLdn0A=E04v?us];@.*-L5f.4JL@:OfLL:3/MMCNJMNLjfMOU/,NP_JGNj@HJVVOci_d')/`0>BJ`1G^f`1?'N(9nTq)1TW'8#0a7[J66/i91E_&RAl-$-LNV$LSicN#v<;R^)WVR_2srR`;88SaDSSScV45T$wS/)[`$B5.M>>#/l2po`[LS.Q<t]5qQX>6_nD#?goEQ1SrDfUUwv(bdWW`bAk*Bc7M>5/vdnl/S#>)4Ds,B5-?329,?QV[.Q28](Kio]*^IP^]fc2(YV6L>%X=-mH8j+M#D/GMNLjfMOU/,NP_JGNj@HJV:fhfVe>,,Wm[DGWne`cWon%)Xpw@DXq*]`X-w3m'RFW>6f=/^d')-h-7<9xTI)V9VZ'5R3BV'58j@eML-;a9MM8a9MM8a9M$:LcM[$0,NP_JGNnKs#L.,E%vUCP##&#-v?+AdV@]8tca=)[q)']BA+Y`1A=Yum/MP&[(Nn:0L,F=e;@,&+58K6dV@<vgV@<vgV@<vgV@BDHW@[PVo@0<o-$.)DiTK8p-$m;p-$n>p-$oAp-$pDp-$qGp-$?iDq.ojQfCXl*WS$qS%#+l^]8W@RMLWUniLL:3/MMCNJMNLjfMOU/,NP_JGNdK+?IMS(%MG3Wb$N,FP8#T[AG_dhWqAFIP/`tdl/'pFL#K8Le$J)l-$L/l-$M2l-$O8l-$m8f--Uc-F%SDl-$)WM1pfNlu5?Ho`bf9Ce6L0o-$M3o-$N6o-$O9o-$P<o-$w2B_/SEo-$THo-$UKo-$VNo-$WQo-$XTo-$YWo-$[^o-$lPkFiK8p-$m;p-$n>p-$oAp-$pDp-$qGp-$ECNpBl3<,+?eEM0''J/2P^A,3)J$d3sa63:N6S`<$p5A=v>o`=YIHp72.q&Zc=<S,Zx_+`C#FJ`1G^f`8%)daeb8,)NCY#$ZqMe$%:I(jMG4@'qmk'&A?>`at1C;$/J*,sv_g--%fm-$e3tX1ThGs.MpW?^g(m-$1pNk+pCm-$#:F_&B_V=uVq.F%d](T.rJ`,#TtP%.3.PwL2>ZwLlBdwLmHmwLnNvwLoT)xLpZ2xLqa;xLrgDxLMnMxLtsVxLu#axLv)jxLMQg1vA-%#M#</#M$B8#M&NJ#M'TS#M<Z]#M)af#M*go#M+mx#M-#5$M=G09vR9UhL&:>GMw^vh-YeNwTH/5##)jJGMiN#<-^cEB-)87Q/g>N)#4a($#c.@Y-%JC_/x]p-$#ap-$$dp-$&jp-$g*s-$NEcu>P<rWhX&,<-v_e6/'lS&vK,uoL*<)pLO0%I-oN#<-l6T;-m6T;-n6T;-o6T;-p6T;-q6T;-'kg%%>7J_&8Jq-$Z.cCsKf)kb%gp-$'mp-$)sp-$KD,F..Ydoo3/S&#4mV&.Gh1*MF/X<#d^Am4:p^ooukAjT?K5&#>e=6#'m+G-%%22%wq.F%.lhFiUuCJ1pYAM9O2ko.j/T`<1U1^+LR4R3sMp-$tPp-$uSp-$vVp-$'mp-$(pp-$)sp-$*vp-$TBMM_<1)da-iNG).h7p&1X=jVJ/n+#RgOoLMSW,#?x=G-L_$n*0Sf+MeU#oL<Z,oLq`5oL]g>oLxrPoL(lhK-=5S>-x6T;-#7T;-$7T;-&7T;-k[lS.=lS&vLYjU-j8v%.<'AnL`<TnLMJj&.*:cwL?ImwLnNvwLoT)xLpZ2xLqa;xL723E-JZ`=-87T;-:7T;-Q2QD-T7T;-V7T;-X7T;-j%jE-a7T;-c7T;-DmnI-qt:T.&`1?##5T;-%5T;-'5T;-*5T;-45T;-65T;-T3S>-)j&V-XK?.%9K4?@)MDpL?i4$/0Vju5'sk-$YVl-$[]l-$^cl-$2f?_/aQ-wpd&FM9l&Q8p@Bh*#0#TR.hHA=##*=&>FiPA>Bdo]>(&U#?r)(GV*FHjDC`W,).I*78:s`DbkGUxb:CR]c<U3>dYenud@$KVeB6,8fDHcofFZCPgHm$2hJ)[ihL;<JiNMs+jP`Scj@j8E#=%co7`1n+s2Tn2Di<jvuNw0hL03DhL2?VhL>fqA&9hHiLH&]iL>2oiL@>+jLqu('#'[ajLbZWmLD6C*#,HY##<IwE.QqB'#;'Fs-p+PwL<Mu$M;<_*#0?Y.;buLE4teW]4c6px4pF%B5$3QY5j@[#6bL4;6*EEg;;/DV?Nbes-s=:pLYis,#H).KsDwA<;>PhiUws%,aiT[ca;LnxcUQOYd?q/;eA-greQio(kS%P`kU71AlWIhxloc;,sE092'Cf:m'/3kM(1EK/)=PIa+Z*H>,=]<#-?osY-GUYs.RMTP/GbL50bg.m0K0eM1MBE/2OT&g2Qg]G3S#>)4#P)E45eB>5((]#6I_TV6^(N;7aCJ88w<,p84WQV[)<mr[B838]+NMS],Wio]-a.5^.jIP^CYfl^@N79/.<+20.W<3t?u3'obIE_&cLE_&[]l-$vUm-$dmGxb2frQ&F4)F.&7:R*FB;R*%c6X:>[*20KEOs-MZajLt^-lL?%$M;&XkA#sRG-Ma4TOMD>*mLplTK-i1F1;4(*Z6.%[w0Vq4R3+;2F%,>2F%-A2F%NfC_/2d7_AWXc3`)r#=M=k/)vHCCpL$>cG-Vo8gL4ND&.e:2mL&$?D-:4aY$;Vwi:GiW9^hgjmLDbd##3e8c$ZJu<-$(xU.1?i(vDfO4%;-^(a@=)daQQGA4%0mr['BMS])T.5^+gel^AZxP'Mm_]$5?>X19-HS@xUGdtHVOjLsebjL+.+%v.bimLBfHu'f72?PQJX<)a__l8&kT^Qlwm++VsBo8;IK&vmGwg/7gKR8hxt&#NU0#vR`R+%c.IJ1w-;J:eMu`4*(*<-0be2.<x1R:G>L^>aG-;?Y0$9T,2L=DSn%<-G]Lh.+uP3#;O#<-<O#<-=O#<-b61Q8iM5Dkfj%akF/PxkYC1AlZLL]l[Uhxl]_->mpYdfr_8b8pt;>xuTuZiL>2oiL@>+jLpou&#4UWjLu:i#v,u/kLL1CkLN=UkLPIhkLRU$lL)(+%vRn]('<w0R39Uo929q:R*'mp-$)sp-$_>m2vR15##`F.%#>####t,_'#Y8q'#r4i$#WoA*#6%T*#:Lb&#OP`S%uWo(<H)KP/%7fu>T%EV?[C@G2<T4PSG+i1TdZ<G;lB>]Xuir=Y*Yer?8`Gi^;t%J_-(O2Cf%:L#rs9`aQmVfCqF:L#*Gf7e86%aFuR:L#6r'Pfsh->G14;L#RDh=lJ.eML5@;L#_o)Vm;/n+M=X;L#gtX1pRw=)OAe;L#mHqIqDE9T7RU]X#($9M#ssB'#_4qB#cKLR#)6h'#iL?C#iW_R#1N6(#oedC#odqR#:md(#w3ED#(w6S#VrA*#LW+Q#La$a.P>@+#/6Q67H<>f$p/x-%;J8&&aqU_&e0k]'QNpq'du-@)k)47OZxcP9BudP9_NVq2*=)W%CH^V-U;PL#F%($/mnuo.QQ4Qg3&UL#?1c?OFK8Qgi]d2_,fdER-nw@F.xP8.C.g*#ap],3JR_uPS[-lLAxP8./,k9#fG:a4E>XuPWtQlLAxP8.o5o-#ilmY6Fu8/$N-Gxb.xP8.C8':#(*SD=;)(^OxrPoL(#Q8.9G.%#.aK>?tP7/$5Kv9)Z:nMLv'ZuPq$&O=Pg(G%]lw9)ZCNJMK-6/$_rw9)]U/,NK-6/$axw9)%])gVw+^uPlBdwL>]T;-4)?1%%r`cW,N'^OsT)xL>]T;-hJI6%(7]`XK-6/$.GlFi+]T;-Y.^wP05P$M>]T;-$(]#%Bxu(b(r=/$U^pEID(V`b`j6/$]:D_/F:7Ac`j6/$_@D_/$TmfrOY=YPf1b]+7*F/$.lnXf1i#<-&Ac4%L%tY-K-6/$SfJV6/xP8._OI@#ROlS/`j6/$kc>_/X'.Q06oguPJ%1kL>]T;-a?*'%[WaJ2#,$^O&T.(>;h(G%c'u9)d5Y)4pkcuP.CO%vNM5/$k?u9)ju2v6K-6/$_u0fh/xP8.PGjD#tqb59ss`uP$B8#Mb^T;-Pm8v$5Wio]xFd;-0=Vp.D:OY5v4?/$&tu9)0jK#?E>XuPAC,T:9JF&#xVm+ssJ./$CNNjLJ_T;-q,^wPS[-lL__T;-LPi#Q$B8#MR]T;-P.^wP(Z]#M@uP8.k(PS.Cm;/$3^B3kkum>6w+^uPKD<,#4H5/$iqF.t1i#<-]w9s$YF3/Mvkv]O'h0I?4g(G%T@`M31i#<-$.^wP&$LI?FIF&#u:hiUAg;/$Y1D_/D(V`b0Lw]Og2Jo>(IF&#.l'B#X1<?Qp)`^>gg(G%d@KV6/xP8.ws6S#q_F59tP7/$]^d-63928][$&^O,Z]#M>]T;-N^pdP=-s+;%gG=-OE77QY?bQP&-LfU-tl.$wY6e;F&[8^x?%6%S*%-M6A<>5NpF/$pg%)H)k-AOs%;SId;9YGsEA'HK$6L%&+x>-[B*(QK,@tL>]T;-w-^wPM8RtL>]T;-#.^wPODetL>]T;-%.^wPKWQm'w@l?.c?W0::7#)b-*;/$S3`9@TS[AG?[[w0xNmpg7T'S%^=D_/xNmpg:+m<-BX$B(F6Y(Z1[C*'Pkt7@7K#Qqw/CE)e^.hLlHMcD_O^Cs3&-Z?JR_uPEnhM<ph(G%=E8ENs<ZwLR]T;-@.^wP@fjk>ag(G%(%#:)&o%)X%,$^OGx/l>;h(G%&1l(Q1i#<-gmo4Q^jrn>lh(G%o>e-6E1r%c0N'^Oh8So>(KF&#.l'B#,#5TQNe>m>gi(G%^*/s'1i#<-S.^wPU<;3?#RbA#+VO&#9w1>(<uCSUXHT`&0Pd;@N__uPOmS)?wg(G%b_C-MIwGi(rp2`6p@A+hMdeq$b6G'o/>H;@Ck5/$<fLU7^fu>$Db,:0ghnj:Rgt&#?nS&vg'Q8.bHA=#t$C2:K-6/$(^M1p.xP8.xSl##&nrc<K-6/$**v9)(*SD=288/$@:@_/+EOA>K-6/$/#E-d#S),WK-6/$WR5/F1i#<-NW;*%&%&)XE1%^OI4gL?Yh(G%+.#:).bTYZ-*;/$w$;s01i#<-M.^wP$B8#M>]T;-;8[&%C+;DbZ[9/$)>jG,1i#<-wxcw$`(5Dk;m'^OXdB(M>]T;-+/^wPX&h(M>]T;-k&X0QaVZ)M>]T;-er_-%rvt1qg<&^OA^5q?$i(G%#m%:)%gi(tJ'-/$NjqV?Ti(G%LB2Gu1i#<-Dc?t$7h7p&,4w]O8KihL>]T;-./J#%E;`D+ELe;-.+v8.gJx.:d.)^OXG&o''^u_H9:D9.a2<)#[539B6MDpLt1,p7E.r_&WQ`9@3`^Dl:@75/GU@/$VXt9)gY6#6-4w]O8+Q>@>g(G%q.3a61i#<-l4l_$,W(G%54dl890F/$$QM1p+]T;-I`;*%m98^H9:D9.+G.%#3+2^QMgW((&3<g;Tq_uPQ4d*('0j2i_q?n8GFew''TJ-M)mGoLmN(m8_,#H5##ZoLUlP8.(7D,#w@HJV(r=/$kPkFi+]T;-@.^wPKt?CBUh(G%HU=HY1i#<-?2_0%'.ADX5<'^Oua;xL>]T;-LTJ4QN'%GAZi(G%P(1*$1i#<-I.^wPRB[cA4g(G%]G&X?rm^dOWb639PEew'buX6A8p^dO2iG<-a4A,QZsNdAdh(G%9X#:)7^IP^K-6/$2#f5i1i#<-W.^wPbx%4v8J5/$SZT;p1i#<-Klt7%Ib3>d288/$4oAH,1i#<-,2dw$OB,8fK-6/$k2]m;1i#<-cSn&%U#%2h+&$^O*7jKA9h(G%^8*HP1i#<-#/^wP,[JLAjh(G%-uOC-XkV+(.8)N9+u5,sTq_uPo/Gh'HAVGY&jU.(AS>ENpQ&k&IQ7Ksh9jvuNM5/$+%O#f1i#<-#YP4%?ZgJ)WS(^Ookup'mWFj9eXUaQjF^W&DY@&,288/$L:t9)KfW>-cpx]Ox`8pAog(G%p]);?,]T;-q,^wPbZWmLg]T;-LPi#Q^X,.#rx4TQt7i#v8J5/$%`C-M_U$lLjxP8.sjq7#fG:a4eIYuPVnHlLjxP8.#&1/#fPq]5288/$.B*VZ+]T;-*f5*QR]')(/8hY?j4=/$cQusB4.v8.Dw-8#%a<m)=Fi9.i>N)#_hfcNj4=/$mFx9)k)WVRK-6/$oLx9)m;88STu$^OOBo5FSh(G%GkthX1i#<->JL0%ruklTK-6/$vbx9)t%LMUK-6/$ADWo@.xP8.e9':#AcYca58$^O?x_%M%^T;->PY,%L'0;eft%^O%%/dBph(G%GHbgb1i#<-?(K3%cC1AlP5(^O;TLfBZi(G%e$f<-G=n9%@OK1p(PT;-jW^v$<?kM(Kww]O59MhLAxP8.Xs6S#HJ[A,&^#^OA,fiL>]T;-j,^wPoo:#viK5/$r[RNW1i#<-?VL.QIu'kL>]T;-v,^wP.uUnBJi(G%wM)6r1i#<-&-^wPS[-lL7$Q8.2ABU#eGUA5Ag;/$jRKV6,]T;-t'i%%k4N;7K-6/$*0lEIpU+p8Fu8/$HSC_/20mr[-*;/$JYC_/4BMS]`j6/$L`C_/6T.5^`j6/$^C:kO8gel^_d-/$]H:7#j1<?Q-:+)#uG5/$`^oKCpe6#6tDi.$=T`-6ilmY6K-6/$@LD-MYSj(v$J5/$<BWhLKY#dP%pvV/EP9kO?P#,aZ[9/$D$$:),SkA#A3#,%sq5ZA:+m<-.Pi#QGVus'<Y(5iDt_@%@XFxb+lP8.rOI@#fPq]5K-6/$S/5hCloQ>6`^h.$)m>=-A8D#Qn8u-(+7&<-U-2uOue^o'0OQs?*Tmr[f(=/$@i;=-fQi#Q/%g$(6#/5^`j6/$DcE-d8gel^_d-/$/8E)#bNvQQxO7$vMJ5/$2O*78?EhB[Tf/)vL1g.$xY,20L7G58A0EQ1GL,hL'CauP1RO)#5K5/$nHu9)Cg:jVu=]9@sSV)HF$`@%We?q@0-r_&-&:EN[=D]&-d>gFtFop@8Eew'-&:ENoGo16f+iHDRE*#JjHT8)caO`<W,r_&e>1=-UBTw'-P/RLfZS-;>-r_&)P:EN7Q=s'/1u&#Y?i(v[]H;?tDew'/0#Yl+]T;-/vt%Q4Mu$M>cpV-REW*m1i#<-8So6%4NMS]K-6/$wrH7)1i#<-nfBZ$+QuF%E[]QCBle,td_vA)+ETq7*rF&#1]369fBovR&Dp0)adMX?$Eew'Cs*s/-0;,#TTr,#i?Jm%bIE_&[]l-$^cl-$&NNk+-(0[-DGqlMpq49>a`:Uq=tL&(5%$'>eODfFtojn'9Ku42#,bM%'mMWH24u42g>$$>A,r_&5X7ENlojn'.BnXf<F]r'Xg'M<jA_^=[OwXJ^`UtBAifY.jV0#veq4&=)9#po0K3YPwI.$vkG5/$:P$Q<4.v8.-8':#bEI@[=Fi9.l5o-#YYCIP=Fi9.WsP3#w6_2:8qZuPi/BnLAxP8.x@]5#(*SD=`j6/$x,x^]/a0^>B9[uPw.moLVn4&=dt*,6']x$(/r7:.VRr,#X1niLK-6/$]lw9)ZCNJMK-6/$_rw9)]U/,NK-6/$axw9)C2S(6mDhB=UDew'C'E-M$],p'?2<f4i8CB=M,r_&@<5:.`tP3##S),WR@w]Okht'KBg(G%PK%'81i#<-GfV%%'.ADXK-6/$+.#:)>>'j_bA]uP//G$M>]T;-<K?4%>S^f`K-6/$TD`?G<&kX]5.D9.ASr,#Cu:Db-*;/$[7D_/E1r%c`j6/$^=D_/GCR]c`j6/$xSZ?G=R-M3cm_T&0F<Y/jA_^==,r_&U#a(N_)l]=Q,r_&#:E_/XB'M<6uG<-?Ri#Q=,,[&fk->m`j6/$FfMP&^&l]=)*S5'W$1^=8-r_&+>:ENb6tv'Jx[&,C?euP,@S]G]i(G%1hnc$1i#<-k,^wPolu&#sK5/$i.3244.v8.RIxP#W'I21K-6/$JKMVC1i#<-BxH)%^jA,3Xo$^OVU$lLr)l]=,Eew'xtH-MXEm%(x1PIY=Fi9.L9^M#shFp8pkcuPswPp'Xq5^=wk3M*nM-_=UmbA#U:Es-6^jjLF4$##Prql/UJ6(#W/5##R;#s-8iPlLWwQ##n[P+#&hc+#)Tl##;'<;62BV,#5g1$#54B2#o>T2#./4&#Z-d3#=>)4#miu</9vO6#@n3$M,C=)#pQ`S%B53,)v1JV6B.=>5eH[Y#nK<;$_+vxkW`ou,;l###),Mxb_0ae$UoWo@ePfFi]du@XHZ`7[Ghlxu5A:mSK%LKM<Jg;-#.QXM_<QDNIsEE-Z0QD-TY@Q-L`uk-pAC_&Ejnxuhr%jLBP:QS3j1.OLKXd*m:c'ol&nxukaGW-V/7/d:pQvZoc+##pQn-$TiQd+Pj'HRE@2FQY/OJ-3liX-,dG_&qp-GM6?Y(N^]q>IP-F'MfYxo7A#O8p^Z`7[6qQ,MT2BvM-n0A=);dV@VUxiC1]Nh##?CpLw.K;-84(D.2M?iTqh#gLPIBGMvh'X'4[IXL7%7<-9F::T5WZ)MB*rtL%%g+M3vRo@)aI&#k.txub>0,.g@):MEf5s-j$t(P[6nW->bS(0YV$QUm[E4TZ$wLMLGnaMUOl`Nm=ow-bVpP'$Ykxus.To%K1)##0MW,k$MCF.4DS/$;-EqVI%N'Mh=6###:6j:FK-7*Q+R`<&]X&#w@:NP_mvf$kX?JMPFLt%eqO/Q(-92#H9+@B3[7VQYW/%#^ZYO-YaU.($skX(F[7EG'8D'#Ja9B#cg(T.(5>##PPqw-[4+gLJ@$##2Sl##/lls-^LOgLn-3$#<rC$#NjK8/P(V$#rw9hL1icS.H@%%#AF%U.NR@%#GxS,M6a@.M$G5s-w-LhLf&^%#0_?iLi2#&#>Gg;-BqUPfKLH##4ZlO-$;T;->#;P->TS?Mw-gfL&8T;-xL#<-RGl@M.'2hL3(g%#6AB;-JpCl-jNNL#Lk0i#FT6.$>miEedB[-dZnuE7%V'^#tDi.$FQX$0#i^>$6D8/$cW?D*'PT;-oZgTSGHrIMN_d##4)B;-HQjvPcRwx-XFbGM%S&%#/b;>MH'@E.Ge[%#2nRp&tZ?]OV0E$#tmA.$et^-6O`3^,0kl3+Y_+/(Q]8>,D<at(%W7F%ir;BM%_E/1Oww%#IZ0B#ng1$#;Y5<-I:YDN5?rHM:KI*N3xSfLqwcX&XOjl&W7M<-]OL68i)+Q'p(D_&eXRS%vIPS.OR@%#=xL5/CrC$#iFFgLrqJfL)bl,M'LV;-KA_9Ow35GMZ?w:OwwSfLR@T;-G@CQ8F$q>$*_b?Km#NQ1ON<R8Jg)ed<0$.$0CAq`(F3<-Ig(P-/;T;-dIwA-LkUH-6GT;-rg+dO5QrhLD16s-f3UhL[KT;-:0^kM_dA%#kpr+QYEj$#H-;.M.1Y?-H&KwPgOM=-7HvD-Sq_]OBD6##p/g.$VL/2'#DT;-o]<ORLOQ##h10'#6Ojl&d;K.$(KHX:F,g&$M=8_NO_d##j&Wm.uQk&#Lbg57$-_'#V8q'#dSl##E>N)#%i8*#+YI%#a7p*#d<fnLr2OB,t_M]=A)->>EK7;-,_br?Mx@S@P5ko.<T4PS9Vh1TU1kr6qpq:Zd_0T],)q%=al9L#Z3X(a&,$$?_c*PfM:^1g7qGKD2d,Vmu4`7nEV1pJ;R;L#Y@xOoGihPK?_;L#`k9ipI%I2LCk;L#pdiCsKYRfLN6<L#v]'Yufpf2BW0>>#WajL#(25##^Hc>#^m&M#0JY##da1?#d#9M#:i1$#k)`?#10KM#%*U'#S@-C#S:]P#-B$(#YXQC#YFoP#5ZH(#`qvC#aR+Q#GMa)#pjAE#w3(R#7#P6#c;w0#-,x&#a:a5TY''k0@ZuSe#####As0ODxcio=#r&##"

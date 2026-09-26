--[[
* Chains - NieR Soft Rounded Dark Edition (Horizon Branch + MyricaM M)
* Based on Chains by Sippius, Ivaar, and NerfOnline
--]]

addon.name     = 'chains';
addon.author   = 'Sippius, Ivaar, NerfOnline, purya-mochi';
addon.version  = '0.85d-jp';
addon.desc     = 'Display current skillchain options with NieR-inspired soft-rounded dark HUD.';

require('common');
local ffi      = require('ffi');
local chat     = require('chat');
local imgui    = require('imgui');
local settings = require('settings');
local skills   = require('skills');

-- =============================================================================
-- NieR風 カラーパレット & スタイル定義
-- =============================================================================
local COLOR = {
    BG_PANEL       = 0xDA181917, -- スモーキーチャコール（半透明85%）
    HEADER_BG      = 0xF02C3029, -- ディープオリーブグレー
    HEADER_TXT     = 0xFFD8D3C5, -- アイボリー
    TEXT_MAIN      = 0xFFE0DDD5, -- ソフトホワイト
    TEXT_MUTED     = 0xFF888478, -- カーキグレー
    LINE_BORDER    = 0x70525046, -- 枠線
    BOX_BORDER     = 0xBB827E72, -- カウントボックス枠
    BOX_WAIT_FILL  = 0xB0C45B4A, -- テラコッタ (WAIT)
    BOX_GO_FILL    = 0xB05C9A62, -- セージグリーン (GO)
    BOX_BURST_FILL = 0xB04D8BA8, -- スレートブルー (BURST)
};

local PROP_JP = {
    -- 連携属性
    ['Light']         = '光',
    ['Darkness']      = '闇',
    ['Gravitation']   = '重力',
    ['Fragmentation'] = '分解',
    ['Distortion']    = '湾曲',
    ['Fusion']        = '核熱',
    ['Compression']   = '圧縮',
    ['Liquefaction']  = '溶解',
    ['Induration']    = '硬化',
    ['Reverberation'] = '衝撃',
    ['Transfixion']   = '貫通',
    ['Scission']      = '切断',
    ['Detonation']    = '炸裂',
    ['Impaction']     = '衝撃',
    ['Radiance']      = '極光',
    ['Umbra']         = '黒闇',
    -- MB / エレメント属性
    ['Fire']          = '火',
    ['Earth']         = '土',
    ['Water']         = '水',
    ['Wind']          = '風',
    ['Ice']           = '氷',
    ['Lightning']     = '雷',
    ['Dark']          = '闇',
};

-- =============================================================================
-- 設定および変数初期化
-- =============================================================================
local default_settings = T{
    position_x = 100,
    position_y = 100,
    direction  = 'top', -- 'top' または 'bottom'
    ability    = false,
    smn        = true,
    font_size  = 14.5,
    display    = T{
        color  = true,
        pet    = true,
        spell  = true,
        weapon = true,
    },
};

local chains = T{
    settings         = settings.load(default_settings),
    visible          = false,
    test_mode        = false,
    test_start       = 0,
    previewTarget    = nil,
    position         = nil,
    lastWindowHeight = 0,
    forceAeonic      = 0,
    forceImmanence   = false,
    forceAffinity    = false,
};

local custom_font = nil;
local font_loaded = false;

local function ensure_custom_font()
    if font_loaded then return end
    font_loaded = true

    local font_paths = {
        'C:\\Windows\\Fonts\\MyricaM.ttc',
        'C:\\Windows\\Fonts\\MyricaM.ttf',
        'C:\\Windows\\Fonts\\MyricaMM.ttf',
        'C:\\Windows\\Fonts\\Myrica.ttc',
        'C:\\Windows\\Fonts\\Myrica.ttf',
    }

    local io = imgui.GetIO()
    local ranges = (imgui.GetGlyphRangesJapanese and imgui.GetGlyphRangesJapanese()) or nil
    local f_size = (chains.settings and chains.settings.font_size) or 14.5

    for _, path in ipairs(font_paths) do
        local ok, font = pcall(function()
            return io.Fonts:AddFontFromFileTTF(path, f_size, nil, ranges)
        end)
        if ok and font ~= nil then
            custom_font = font
            break
        end
    end
end

local playerID;
local actionTable = T{ schskill = skills.immanence };
local playerTable = T{};
local targetTable = T{};

local chainInfo = T{
    Radiance = T{level = 4, burst = T{'Fire','Wind','Lightning','Light'}},
    Umbra    = T{level = 4, burst = T{'Earth','Ice','Water','Dark'}},
    Light    = T{level = 3, burst = T{'Fire','Wind','Lightning','Light'},
        aeonic = T{level = 4, skillchain = 'Radiance'},
        Light  = T{level = 4, skillchain = 'Light'},
    },
    Darkness = T{level = 3, burst = T{'Earth','Ice','Water','Dark'},
        aeonic   = T{level = 4, skillchain = 'Umbra'},
        Darkness = T{level = 4, skillchain = 'Darkness'},
    },
    Gravitation = T{level = 2, burst = T{'Earth','Dark'},
        Distortion    = T{level = 3, skillchain = 'Darkness'},
        Fragmentation = T{level = 2, skillchain = 'Fragmentation'},
    },
    Fragmentation = T{level = 2, burst = T{'Wind','Lightning'},
        Fusion     = T{level = 3, skillchain = 'Light'},
        Distortion = T{level = 2, skillchain = 'Distortion'},
    },
    Distortion = T{level = 2, burst = T{'Ice','Water'},
        Gravitation = T{level = 3, skillchain = 'Darkness'},
        Fusion      = T{level = 2, skillchain = 'Fusion'},
    },
    Fusion = T{level = 2, burst = T{'Fire','Light'},
        Fragmentation = T{level = 3, skillchain = 'Light'},
        Gravitation   = T{level = 2, skillchain = 'Gravitation'},
    },
    Compression = T{level = 1, burst = T{'Darkness'},
        Transfixion = T{level = 1, skillchain = 'Transfixion'},
        Detonation  = T{level = 1, skillchain = 'Detonation'},
    },
    Liquefaction = T{level = 1, burst = T{'Fire'},
        Impaction = T{level = 2, skillchain = 'Fusion'},
        Scission  = T{level = 1, skillchain = 'Scission'},
    },
    Induration = T{level = 1, burst = T{'Ice'},
        Reverberation = T{level = 2, skillchain = 'Fragmentation'},
        Compression   = T{level = 1, skillchain = 'Compression'},
        Impaction     = T{level = 1, skillchain = 'Impaction'},
    },
    Reverberation = T{level = 1, burst = T{'Water'},
        Induration = T{level = 1, skillchain = 'Induration'},
        Impaction  = T{level = 1, skillchain = 'Impaction'},
    },
    Transfixion = T{level = 1, burst = T{'Light'},
        Scission      = T{level = 2, skillchain = 'Distortion'},
        Reverberation = T{level = 1, skillchain = 'Reverberation'},
        Compression   = T{level = 1, skillchain = 'Compression'},
    },
    Scission = T{level = 1, burst = T{'Earth'},
        Liquefaction  = T{level = 1, skillchain = 'Liquefaction'},
        Reverberation = T{level = 1, skillchain = 'Reverberation'},
        Detonation    = T{level = 1, skillchain = 'Detonation'},
    },
    Detonation = T{level = 1, burst = T{'Wind'},
        Compression = T{level = 2, skillchain = 'Gravitation'},
        Scission    = T{level = 1, skillchain = 'Scission'},
    },
    Impaction = T{level = 1, burst = T{'Lightning'},
        Liquefaction = T{level = 1, skillchain = 'Liquefaction'},
        Detonation   = T{level = 1, skillchain = 'Detonation'},
    },
};

local colors = {
    Light         = { 0.95, 0.90, 0.60, 1.0 },
    Dark          = { 0.65, 0.55, 0.75, 1.0 },
    Ice           = { 0.50, 0.80, 0.85, 1.0 },
    Water         = { 0.45, 0.65, 0.85, 1.0 },
    Earth         = { 0.80, 0.65, 0.45, 1.0 },
    Wind          = { 0.50, 0.80, 0.60, 1.0 },
    Fire          = { 0.90, 0.45, 0.40, 1.0 },
    Lightning     = { 0.80, 0.55, 0.80, 1.0 },
    Gravitation   = { 0.80, 0.65, 0.45, 1.0 },
    Fragmentation = { 0.85, 0.55, 0.70, 1.0 },
    Fusion        = { 0.90, 0.45, 0.40, 1.0 },
    Distortion    = { 0.45, 0.70, 0.85, 1.0 },
    Darkness      = { 0.65, 0.55, 0.75, 1.0 },
    Umbra         = { 0.60, 0.50, 0.70, 1.0 },
    Compression   = { 0.65, 0.55, 0.75, 1.0 },
    Radiance      = { 0.95, 0.90, 0.60, 1.0 },
    Transfixion   = { 0.85, 0.80, 0.45, 1.0 },
    Induration    = { 0.50, 0.80, 0.85, 1.0 },
    Reverberation = { 0.45, 0.65, 0.85, 1.0 },
    Scission      = { 0.65, 0.75, 0.40, 1.0 },
    Detonation    = { 0.50, 0.80, 0.60, 1.0 },
    Liquefaction  = { 0.90, 0.45, 0.40, 1.0 },
    Impaction     = { 0.80, 0.55, 0.80, 1.0 },
    Ready         = { 0.90, 0.88, 0.85, 1.0 },
    Unavailable   = { 0.50, 0.48, 0.45, 1.0 },
};

local statusID = { AL = 163, CA = 164, AM1 = 270, AM2 = 271, AM3 = 272, IM = 470 };
local MessageTypes = T{ 2, 110, 185, 187, 317, 802 };
local PetMessageTypes = T{ 110, 317 };
local ChainBuffTypes = T{
    [statusID.AL] = { duration = 30 },
    [statusID.CA] = { duration = 30 },
    [statusID.IM] = { duration = 60 },
};

local EquipSlotNames = T{ [1] = 'Main', [3] = 'Range' };
local SkillPropNames = T{
    [1] = 'Light', [2] = 'Darkness', [3] = 'Gravitation', [4] = 'Fragmentation',
    [5] = 'Distortion', [6] = 'Fusion', [7] = 'Compression', [8] = 'Liquefaction',
    [9] = 'Induration', [10] = 'Reverberation', [11] = 'Transfixion', [12] = 'Scission',
    [13] = 'Detonation', [14] = 'Impaction', [15] = 'Radiance', [16] = 'Umbra'
};

settings.register('settings', 'settings_update', function (s)
    if s ~= nil then chains.settings = s end
    if chains.settings.direction == nil then chains.settings.direction = 'top' end
    if chains.settings.ability == nil then chains.settings.ability = false end
    if chains.settings.smn == nil then chains.settings.smn = true end
    settings.save()
end)

local function GetPropertyColor(t)
    if chains.settings.display.color and colors[t] then
        return colors[t]
    end
    return { 1.0, 1.0, 1.0, 1.0 }
end

local function GetBuffCount(matchBuff)
    local count = 0
    local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs()
    if type(matchBuff) == 'string' then
        local matchText = string.lower(matchBuff)
        for _, buff in pairs(buffs) do
            local buffString = AshitaCore:GetResourceManager():GetString("buffs.names", buff)
            if buffString ~= nil and string.lower(buffString) == matchText then
                count = count + 1
            end
        end
    elseif type(matchBuff) == 'number' then
        for _, buff in pairs(buffs) do
            if buff == matchBuff then count = count + 1 end
        end
    end
    return count
end

local function GetEquipment()
    local inventoryManager = AshitaCore:GetMemoryManager():GetInventory()
    local equipTable = {}
    for k, v in pairs(EquipSlotNames) do
        local equippedItem = inventoryManager:GetEquippedItem(k - 1)
        local index = bit.band(equippedItem.Index, 0x00FF)
        local eqEntry = {}
        if index ~= 0 then
            eqEntry.Container = bit.band(equippedItem.Index, 0xFF00) / 256
            eqEntry.Item = inventoryManager:GetContainerItem(eqEntry.Container, index)
            if eqEntry.Item and eqEntry.Item.Id ~= 0 and eqEntry.Item.Count ~= 0 then
                local res = AshitaCore:GetResourceManager():GetItemById(eqEntry.Item.Id)
                if res then
                    eqEntry.Name = res.Name[1]
                    equipTable[v] = eqEntry
                end
            end
        end
    end
    return equipTable
end

local function GetPlayer()
    local pParty = AshitaCore:GetMemoryManager():GetParty()
    local pPlayer = AshitaCore:GetMemoryManager():GetPlayer()
    local mainJob = pPlayer:GetMainJob()
    local subJob = pPlayer:GetSubJob()
    return {
        MainJob = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", mainJob),
        MainJobLevel = pPlayer:GetJobLevel(mainJob),
        MainJobSync = pPlayer:GetMainJobLevel(),
        Name = pParty:GetMemberName(0),
        SubJob = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", subJob),
        SubJobLevel = pPlayer:GetJobLevel(subJob),
        SubJobSync = pPlayer:GetSubJobLevel(),
        TP = pParty:GetMemberTP(0),
    }
end

local function GetWeaponskills()
    local skillTable = T{}
    local pPlayer = AshitaCore:GetMemoryManager():GetPlayer()
    for k, v in pairs(skills[3]) do
        if v and pPlayer:HasWeaponSkill(k) then
            skillTable:append(v)
        end
    end
    return skillTable
end

local function GetCurrentPetName()
    local party = AshitaCore:GetMemoryManager():GetParty()
    local entity = AshitaCore:GetMemoryManager():GetEntity()
    local playerIndex = party:GetMemberTargetIndex(0)
    local petIndex = entity:GetPetTargetIndex(playerIndex)
    if petIndex == 0 then return nil end
    return entity:GetName(petIndex)
end

local function HasAvatar(avatar)
    local spell = AshitaCore:GetResourceManager():GetSpellByName(avatar, 0)
    return spell ~= nil and AshitaCore:GetMemoryManager():GetPlayer():HasSpell(spell.Index)
end

local function GetPetskills()
    local skillTable = T{}
    local player = GetPlayer()
    local smnLevel = (player.MainJob == 'SMN' and player.MainJobSync) or (player.SubJob == 'SMN' and player.SubJobSync) or 0
    local currentPet = GetCurrentPetName()
    for _, skill in pairs(skills[13]) do
        local meetsLevel = smnLevel >= skill.level
        local ownsAvatar = HasAvatar(skill.avatar)
        local meetsSummon = not chains.settings.smn or (currentPet == skill.avatar)
        if meetsLevel and ownsAvatar and meetsSummon then
            skillTable:append(skill)
        end
    end
    return skillTable
end

local blu = {
    offset = ffi.cast('uint32_t*', ashita.memory.find('FFXiMain.dll', 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0))
};

local function GetBluskills()
    local skillTable = T{}
    local ptr = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'))
    if ptr == 0 then return T{} end
    ptr = ashita.memory.read_uint32(ptr)
    if ptr == 0 then return T{} end
    local spellTable = T(ashita.memory.read_array((ptr + blu.offset[0]) + 0x04, 0x14))
    for _, v in pairs(spellTable) do
        if skills[4] and skills[4][v + 512] then
            skillTable:append(skills[4][v + 512])
        end
    end
    return skillTable
end

local function GetAftermathLevel()
    return GetBuffCount(statusID.AM1) + 2 * GetBuffCount(statusID.AM2) + 3 * GetBuffCount(statusID.AM3) + chains.forceAeonic
end

local function GetAeonicProperty(action, actor)
    local propertyTable = table.copy(action.skillchain)
    if action.aeonic and (action.weapon or chains.forceAeonic > 0) and actor == playerID and GetAftermathLevel() > 0 then
        local main = GetEquipment().Main
        local range = GetEquipment().Range
        local validMain = (action.weapon == (main and main.Name)) or (chains.forceAeonic > 0)
        local validRange = action.weapon == (range and range.Name)
        if validMain or validRange then
            table.insert(propertyTable, 1, action.aeonic)
        end
    end
    return propertyTable
end

local function GetAxePreviewSkills()
    local skillTable = T{}
    for id = 64, 72 do
        if skills[3][id] then
            skillTable:append(skills[3][id])
        end
    end
    return skillTable
end

local function CreateVisiblePreviewTarget()
    local spinningAxe = skills[3][68] or { en='Spinning Axe', jp='スピンアクス', skillchain={'Liquefaction','Scission'} }
    local delay = spinningAxe.delay or 3
    return {
        en = spinningAxe.en,
        jp = spinningAxe.jp or 'スピンアクス',
        property = table.copy(spinningAxe.skillchain),
        ts = os.time(),
        dur = 7 + delay,
        wait = delay,
        step = 1,
    }
end

local function GetSkillchains(target, actionsOverride)
    local weaponActions = T{}
    local spellActions = T{}
    local petActions = T{}
    local weaponReady = true
    local spellReady = true
    local currentPet = nil

    if actionsOverride then
        weaponActions = actionsOverride
    else
        local player = GetPlayer()
        local mainJob = player.MainJob
        local subJob = player.SubJob
        local isSMN = (mainJob == 'SMN' or subJob == 'SMN')
        local requireAbility = chains.settings.ability
        local playerBuffs = playerTable[playerID]
        local schBuffActive = (playerBuffs and playerBuffs[statusID.IM]) or chains.forceImmanence
        local bluBuffActive = (playerBuffs and (playerBuffs[statusID.AL] or playerBuffs[statusID.CA])) or chains.forceAffinity
        local enableSCH = (mainJob == 'SCH') and (not requireAbility or schBuffActive)
        local enableBLU = (mainJob == 'BLU') and (not requireAbility or bluBuffActive)

        weaponReady = true
        if mainJob == 'BLU' then spellReady = not not bluBuffActive
        elseif mainJob == 'SCH' then spellReady = not not schBuffActive end
        currentPet = isSMN and GetCurrentPetName() or nil

        if not actionTable.wepskill then
            actionTable.wepskill = GetWeaponskills()
        end
        if enableBLU and chains.settings.display.spell then
            actionTable.bluskill = GetBluskills()
        end
        if chains.settings.display.weapon then
            weaponActions = weaponActions:extend(actionTable.wepskill)
        end
        if chains.settings.display.pet and isSMN then
            petActions = petActions:extend(GetPetskills())
        end
        if chains.settings.display.spell and enableBLU and actionTable.bluskill then
            spellActions = spellActions:extend(actionTable.bluskill)
        elseif chains.settings.display.spell and enableSCH and actionTable.schskill then
            spellActions = spellActions:extend(actionTable.schskill)
        end
    end

    local function buildList(actions, ready)
        local chainTable = T{}
        local levelTable = T{{},{},{},{}}

        for _, action in pairs(actions) do
            local actionProperty = GetAeonicProperty(action, playerID)
            for _, prop1 in pairs(target.property) do
                local match = nil
                for _, prop2 in pairs(actionProperty) do
                    match = chainInfo[prop1] and chainInfo[prop1][prop2]
                    if match then break end
                end
                if match then
                    local isReady = (type(ready) == 'function') and ready(action) or ready
                    table.insert(levelTable[match.level], {
                        action = action,
                        outName = action.en,
                        outText = ('>> Lv.%d'):format(match.level),
                        outProp = match.skillchain,
                        outPropJp = PROP_JP[match.skillchain] or match.skillchain,
                        ready = not not isReady,
                    })
                    break
                end
            end
        end

        for level = 4, 1, -1 do
            for _, entry in pairs(levelTable[level]) do
                table.insert(chainTable, entry)
            end
        end
        return chainTable
    end

    return T{
        weapon = buildList(weaponActions, weaponReady),
        spell  = buildList(spellActions, spellReady),
        pet    = buildList(petActions, function(action) return currentPet == action.avatar end),
    }
end

local function DrawChainContent(targetEntry, skillchains, showChrome)
    local now = os.time()
    local timediff = now - targetEntry.ts
    local timer = math.max(0, targetEntry.dur - timediff)

    local dl = imgui.GetWindowDrawList()
    local p = imgui.GetCursorScreenPos()
    local px = (type(p) == 'table' and (p[1] or p.x)) or 0
    local py = (type(p) == 'table' and (p[2] or p.y)) or 0
    local w  = 350

    local isWait = false
    if not targetEntry.closed and timediff < targetEntry.wait then
        isWait = true
    end

    local corner_flags = bit.bor(1, 2)
    dl:AddRectFilled({ px, py }, { px + w, py + 22 }, COLOR.HEADER_BG, 6.0, corner_flags)

    local stateTag = 'ACT '
    local timerCol = { 0.45, 0.85, 0.50, 1.0 } -- ACT: 明るいセージグリーン
    if isWait then
        stateTag = 'WAIT'
        timerCol = { 0.90, 0.40, 0.35, 1.0 } -- WAIT: 明るいテラコッタ
    elseif targetEntry.closed then
        stateTag = 'BURST'
        timerCol = { 0.45, 0.75, 0.90, 1.0 } -- BURST: 明るいスレートブルー
    end

    local timerValText = ('%s : %ds'):format(stateTag, isWait and (targetEntry.wait - timediff) or timer)
    local stepText     = ('// STEP %d'):format(targetEntry.step or 1)

    imgui.SetCursorPosX(imgui.GetCursorPosX() + 8)
    imgui.TextColored(timerCol, timerValText)

    imgui.SameLine()
    imgui.TextColored({ 0.55, 0.53, 0.48, 0.8 }, stepText)

    imgui.Spacing()

    local prevName = targetEntry.jp or targetEntry.en or 'スピンアクス'
    local propName = (targetEntry.property and targetEntry.property[1]) or 'Liquefaction'
    local propJp   = PROP_JP[propName] or propName
    local mutedCol = { 0.55, 0.53, 0.48, 0.8 }

    imgui.SetCursorPosX(imgui.GetCursorPosX() + 8)
    imgui.TextColored({ 0.85, 0.83, 0.77, 1.0 }, prevName)
    imgui.SameLine()
    imgui.TextColored(mutedCol, '->')
    imgui.SameLine()
    imgui.TextColored(GetPropertyColor(propName), propJp)
    imgui.SameLine(0, 4)
    imgui.TextColored(mutedCol, ('[%s]'):format(propName))

    if chainInfo[propName] and chainInfo[propName].burst then
        imgui.SameLine()
        imgui.TextColored(mutedCol, '| MB:')
        for _, b in ipairs(chainInfo[propName].burst) do
            imgui.SameLine(0, 4)
            imgui.TextColored(GetPropertyColor(b), PROP_JP[b] or b)
        end
    end

    local totalBoxes = 7
    local activeBoxes = 0

    if isWait then
        local waitRem = math.max(0, targetEntry.wait - timediff)
        activeBoxes = math.min(totalBoxes, waitRem)
    else
        local actDuration = math.max(1, targetEntry.dur - targetEntry.wait)
        local ratio = math.min(1.0, math.max(0.0, timer / actDuration))
        activeBoxes = math.ceil(ratio * totalBoxes)
    end

    local fillVec = { 0.36, 0.60, 0.38, 0.85 }
    if isWait then
        fillVec = { 0.77, 0.36, 0.29, 0.85 }
    elseif targetEntry.closed then
        fillVec = { 0.30, 0.55, 0.66, 0.85 }
    end
    local dimVec = { 0.15, 0.15, 0.15, 0.30 }

    imgui.Indent(8)

    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 0.0)
    imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 1.0)
    imgui.PushStyleColor(ImGuiCol_Border, { 0.51, 0.49, 0.45, 0.7 })

    local boxW = 10
    local boxH = 8
    local boxGap = 4

    for i = 0, totalBoxes - 1 do
        if i > 0 then imgui.SameLine(0, boxGap) end
        local isLit = (i < activeBoxes)
        local col = isLit and fillVec or dimVec

        imgui.PushStyleColor(ImGuiCol_Button, col)
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, col)
        imgui.PushStyleColor(ImGuiCol_ButtonActive, col)
        imgui.Button(('##sc_box_%d'):format(i), { boxW, boxH })
        imgui.PopStyleColor(3)
    end

    imgui.PopStyleColor(1)
    imgui.PopStyleVar(2)
    imgui.Unindent(8)

    imgui.Spacing()
    imgui.PushStyleColor(ImGuiCol_Separator, { 0.40, 0.38, 0.35, 0.6 })
    imgui.Separator()
    imgui.PopStyleColor(1)
    imgui.Spacing()

    if not targetEntry.closed and skillchains then
        local grouped = {}
        local order = {}
        for _, group in ipairs({ skillchains.weapon, skillchains.spell, skillchains.pet }) do
            if group then
                for _, v in pairs(group) do
                    local prop = v.outProp or 'Unknown'
                    if not grouped[prop] then
                        grouped[prop] = {
                            level = tostring(v.outText):sub(-1),
                            jp = v.outPropJp or prop,
                            en = prop,
                            color = GetPropertyColor(prop),
                            skills = {}
                        }
                        table.insert(order, prop)
                    end
                    table.insert(grouped[prop].skills, v)
                end
            end
        end

        for _, prop in ipairs(order) do
            local g = grouped[prop]

            local gPos = imgui.GetCursorScreenPos()
            local gpx = (type(gPos) == 'table' and (gPos[1] or gPos.x)) or px
            local gpy = (type(gPos) == 'table' and (gPos[2] or gPos.y)) or py
            dl:AddRectFilled({ gpx, gpy }, { gpx + w, gpy + 16 }, 0x252C3029)

            imgui.SetCursorPosX(imgui.GetCursorPosX() + 8)
            imgui.TextColored(mutedCol, ('Lv.%s '):format(g.level))
            imgui.SameLine(0, 0)
            imgui.TextColored(g.color, g.jp)
            imgui.SameLine(0, 4)
            imgui.TextColored(mutedCol, ('[%s]'):format(g.en))

            for _, sk in ipairs(g.skills) do
                local name = sk.outName or ''
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 32) -- インデントを深めに設定
                imgui.TextColored({ 0.50, 0.48, 0.44, 0.8 }, '>')
                imgui.SameLine(0, 6)
                imgui.TextColored(sk.ready and colors.Ready or colors.Unavailable, name)
            end
            imgui.Spacing()
        end
    end

    if showChrome then
        imgui.Separator()
        imgui.SetCursorPosX(80)
        imgui.TextColored({ 0.6, 0.6, 0.55, 1.0 }, '--- NieR HUD Live Preview ---')
    end
end

local function isPlayerInAlliance(id)
    local pParty = AshitaCore:GetMemoryManager():GetParty()
    for i = 0, 17 do
        if pParty:GetMemberIsActive(i) == 1 and pParty:GetMemberServerId(i) == id then
            return true
        end
    end
    return false
end

local function isPetInAlliance(id)
    local pParty = AshitaCore:GetMemoryManager():GetParty()
    local pEntity = AshitaCore:GetMemoryManager():GetEntity()
    for i = 0, 17 do
        if pParty:GetMemberIsActive(i) == 1 then
            local pIndex = pParty:GetMemberTargetIndex(i)
            local petIndex = pEntity:GetPetTargetIndex(pIndex)
            if pEntity:GetServerId(petIndex) == id then return true end
        end
    end
    return false
end

local function isAllianceAutomaton(id)
    local pParty = AshitaCore:GetMemoryManager():GetParty()
    local pEntity = AshitaCore:GetMemoryManager():GetEntity()
    for i = 0, 17 do
        if pParty:GetMemberIsActive(i) == 1 then
            local pIndex = pParty:GetMemberTargetIndex(i)
            local petIndex = pEntity:GetPetTargetIndex(pIndex)
            if pEntity:GetServerId(petIndex) == id then
                local mainJob = pParty:GetMemberMainJob(i)
                return AshitaCore:GetResourceManager():GetString('jobs.names_abbr', mainJob) == 'PUP'
            end
        end
    end
    return false
end

local function ParseActionPacket(e)
    local bitData = e.data_raw
    local bitOffset = 40
    local maxLength = e.size * 8
    local function UnpackBits(length)
        if (bitOffset + length) > maxLength then return 0 end
        local val = ashita.bits.unpack_be(bitData, 0, bitOffset, length)
        bitOffset = bitOffset + length
        return val
    end

    local packet = T{}
    packet.UserId = UnpackBits(32)
    local targetCount = UnpackBits(6)
    bitOffset = bitOffset + 4
    packet.Type = UnpackBits(4)
    packet.Id = UnpackBits(32)
    bitOffset = bitOffset + 32
    packet.Targets = T{}

    for i = 1, targetCount do
        local target = T{}
        target.Id = UnpackBits(32)
        local actionCount = UnpackBits(4)
        target.Actions = T{}
        for j = 1, actionCount do
            local action = {}
            action.Reaction = UnpackBits(5)
            action.Animation = UnpackBits(12)
            action.SpecialEffect = UnpackBits(7)
            action.Knockback = UnpackBits(3)
            action.Param = UnpackBits(17)
            action.Message = UnpackBits(10)
            action.Flags = UnpackBits(31)
            if UnpackBits(1) == 1 then
                action.AdditionalEffect = {
                    Damage = UnpackBits(10),
                    Param = UnpackBits(17),
                    Message = UnpackBits(10)
                }
            end
            if UnpackBits(1) == 1 then
                action.SpikesEffect = {
                    Damage = UnpackBits(10),
                    Param = UnpackBits(14),
                    Message = UnpackBits(10)
                }
            end
            target.Actions:append(action)
        end
        packet.Targets:append(target)
    end
    return packet
end

ashita.events.register('load', 'load_cb', function ()
    playerID = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0)
    ensure_custom_font()
end)

ashita.events.register('unload', 'unload_cb', function ()
    settings.save()
end)

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if e.id == 0x28 then
        local actionType = ashita.bits.unpack_be(e.data_raw, 82, 4)
        if not T{ 3, 4, 6, 11, 13, 14 }:contains(actionType) then return end

        local packet = ParseActionPacket(e)
        local actor = packet.UserId
        local target = packet.Targets[1]
        if not target then return end

        local targetAction = target.Actions[1]
        local category = PetMessageTypes:contains(targetAction.Message) and 13 or packet.Type
        local skillId = bit.band(packet.Id, 0xFFFF)
        local actionSkill = skills[category] and skills[category][skillId]

        if not actionSkill and packet.Type == 11 then
            actionSkill = (skills[11] and skills[11][skillId]) or (skills.pup and skills.pup[skillId])
        end
        if not actionSkill and T{ 6, 14 }:contains(packet.Type) then
            actionSkill = skills[14] and skills[14][skillId]
        end

        local effectProperty = targetAction.AdditionalEffect and SkillPropNames[bit.band(targetAction.AdditionalEffect.Damage, 0x3F)]
        if not (isPlayerInAlliance(actor) or isPetInAlliance(actor)) then return end

        if actionSkill and effectProperty then
            local step = (targetTable[target.Id] and targetTable[target.Id].step or 1) + 1
            local delay = actionSkill.delay or 3
            local level = chainInfo[effectProperty].level
            if level == 3 and targetTable[target.Id] and targetTable[target.Id].property[1] == effectProperty then
                level = 4
            end
            targetTable[target.Id] = {
                en = actionSkill.en,
                jp = actionSkill.jp or actionSkill.en,
                property = { effectProperty },
                ts = os.time(),
                dur = 8 - step + delay,
                wait = delay,
                step = step,
                closed = (level == 4),
            }
        elseif actionSkill and MessageTypes:contains(targetAction.Message)
            and (isPlayerInAlliance(actor) or packet.Type == 13 or isAllianceAutomaton(actor))
            and (packet.Type ~= 4 or playerTable[actor]) then
            local delay = actionSkill.delay or 3
            targetTable[target.Id] = {
                en = actionSkill.en,
                jp = actionSkill.jp or actionSkill.en,
                property = GetAeonicProperty(actionSkill, actor),
                ts = os.time(),
                dur = 7 + delay,
                wait = delay,
                step = 1,
            }
        elseif actionSkill and targetAction.Message == 529 then
            targetTable[target.Id] = {
                en = actionSkill.en,
                jp = actionSkill.jp or actionSkill.en,
                property = actionSkill.skillchain,
                ts = os.time(),
                dur = 9,
                wait = 2,
                step = 1,
                bound = targetAction.Param,
            }
        end

        if actionSkill and packet.Type == 4 and playerTable[actor] then
            local buffID = (playerTable[actor][statusID.CA] and statusID.CA) or (playerTable[actor][statusID.IM] and statusID.IM)
            if buffID then playerTable[actor][buffID] = nil end
        end

        if packet.Type == 6 and ChainBuffTypes:containskey(targetAction.Param) then
            playerTable[actor] = playerTable[actor] or {}
            playerTable[actor][targetAction.Param] = os.time() + ChainBuffTypes[targetAction.Param].duration
        end

    elseif e.id == 0x29 and struct.unpack('H', e.data, 0x18 + 1) == 206 and struct.unpack('I', e.data, 8 + 1) == playerID then
        local effect = struct.unpack('H', e.data, 0xC + 1)
        if playerTable[playerID] and playerTable[playerID][effect] then
            playerTable[playerID][effect] = nil
        end

    elseif e.id == 0x0AC then
        actionTable.wepskill = T{}
        local data = e.data:sub(5)
        for k, v in pairs(skills[3]) do
            if math.floor((data:byte(math.floor(k / 8) + 1) % 2^(k % 8 + 1)) / 2^(k % 8)) == 1 then
                table.insert(actionTable.wepskill, v)
            end
        end
        for _, v in pairs(targetTable) do v.skillchains = nil end
    end
end)

ashita.events.register('d3d_present', 'present_cb', function ()
    local now = os.time()

    for pk, pv in pairs(playerTable) do
        for bk, bv in pairs(pv) do
            if now > bv then pv[bk] = nil end
        end
        if table.length(pv) == 0 then playerTable[pk] = nil end
    end

    for k, v in pairs(targetTable) do
        if v.ts and (now - v.ts > v.dur) then targetTable[k] = nil end
    end

    local targetId = AshitaCore:GetMemoryManager():GetTarget():GetServerId(0)
    local render = (targetId ~= nil) and targetTable[targetId] and (targetTable[targetId].dur - (now - targetTable[targetId].ts) > 0)

    local is_preview = chains.visible or chains.test_mode
    if is_preview then
        if not chains.previewTarget then
            chains.previewTarget = CreateVisiblePreviewTarget()
        elseif now - chains.previewTarget.ts > chains.previewTarget.dur then
            chains.previewTarget.ts = now
        end
    else
        chains.previewTarget = nil
    end

    if render or is_preview or chains.position then
        local showChrome = false
        local targetEntry = nil
        local skillchains = nil

        if render then
            targetEntry = targetTable[targetId]
            skillchains = targetEntry.closed and T{ weapon = T{}, spell = T{}, pet = T{} } or GetSkillchains(targetEntry)
        elseif is_preview and chains.previewTarget then
            showChrome = chains.visible
            targetEntry = chains.previewTarget
            skillchains = GetSkillchains(targetEntry, GetAxePreviewSkills())
        end

        local flags = bit.bor(
            ImGuiWindowFlags_NoDecoration,
            ImGuiWindowFlags_AlwaysAutoResize,
            ImGuiWindowFlags_NoSavedSettings,
            ImGuiWindowFlags_NoFocusOnAppearing,
            ImGuiWindowFlags_NoNav
        )

        local bottomUp = (chains.settings.direction == 'bottom')
        local movedByCommand = (chains.position ~= nil)

        -- 角丸スタイル (半径 6.0px) & 配色
        imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 6.0)
        imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.0)
        imgui.PushStyleColor(ImGuiCol_WindowBg, COLOR.BG_PANEL)
        imgui.PushStyleColor(ImGuiCol_Border, COLOR.LINE_BORDER)
        imgui.SetNextWindowSize({ 350, -1 }, ImGuiCond_Always)

        if movedByCommand then
            imgui.SetNextWindowPos({ chains.position.x, chains.position.y }, ImGuiCond_Always, { 0, 0 })
        else
            local startY = chains.settings.position_y
            if bottomUp then startY = startY - chains.lastWindowHeight end
            imgui.SetNextWindowPos({ chains.settings.position_x, startY }, ImGuiCond_Appearing, { 0, 0 })
        end

        ensure_custom_font()
        if custom_font then imgui.PushFont(custom_font) end

        if imgui.Begin('chains', true, flags) then
            chains.position = nil
            local windowX, windowY = imgui.GetWindowPos()
            local _, windowHeight = imgui.GetWindowSize()
            local dragging = imgui.IsMouseDown(0) and (imgui.IsWindowFocused() or imgui.IsWindowHovered())

            if bottomUp and not movedByCommand and not dragging then
                local anchoredY = chains.settings.position_y - windowHeight
                if math.abs(anchoredY - windowY) > 0.5 then
                    imgui.SetWindowPos({ windowX, anchoredY })
                    windowY = anchoredY
                end
            end

            if targetEntry then
                DrawChainContent(targetEntry, skillchains, showChrome)
            end

            chains.lastWindowHeight = windowHeight
            chains.settings.position_x = windowX
            if bottomUp then
                chains.settings.position_y = windowY + windowHeight
            else
                chains.settings.position_y = windowY
            end
        end
        imgui.End()

        if custom_font then imgui.PopFont() end
        imgui.PopStyleColor(2)
        imgui.PopStyleVar(2)
    end
end)

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args()
    if #args == 0 or not args[1]:any('/chains', '/chain') then return end

    e.blocked = true

    if #args >= 2 and args[2]:any('help', '?', 'commands') then
        print(chat.header(addon.name) .. chat.message('/chains test - Toggle test mode'))
        print(chat.header(addon.name) .. chat.message('/chains visible - Toggle preview / drag handle'))
        print(chat.header(addon.name) .. chat.message('/chains direction - Toggle anchor direction (top/bottom)'))
        print(chat.header(addon.name) .. chat.message('/chains reset - Reset position to default'))
        return
    end

    if #args == 2 and args[2] == 'test' then
        chains.test_mode = not chains.test_mode
        print(chat.header(addon.name) .. chat.message('Test mode: ') .. (chains.test_mode and chat.success('Enabled') or chat.error('Disabled')))
        return
    end

    if #args == 2 and args[2] == 'visible' then
        chains.visible = not chains.visible
        print(chat.header(addon.name) .. chat.message('Live preview: ') .. (chains.visible and chat.success('Enabled') or chat.error('Disabled')))
        return
    end

    if #args == 2 and args[2] == 'direction' then
        local height = chains.lastWindowHeight or 0
        if chains.settings.direction == 'bottom' then
            chains.settings.direction = 'top'
            chains.settings.position_y = chains.settings.position_y - height
        else
            chains.settings.direction = 'bottom'
            chains.settings.position_y = chains.settings.position_y + height
        end
        print(chat.header(addon.name) .. chat.message('Direction: ') .. chat.success(chains.settings.direction:upper()))
        return
    end

    if #args == 2 and args[2] == 'reset' then
        chains.settings.direction = 'top'
        chains.settings.position_x = 100
        chains.settings.position_y = 100
        chains.position = { x = 100, y = 100 }
        print(chat.header(addon.name) .. chat.success('Position reset.'))
        return
    end
end)
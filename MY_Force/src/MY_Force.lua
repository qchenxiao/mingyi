--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 职业特色增强
-- @author   : 茗伊 @双梦镇 @追风蹑影
-- @modifier : Emil Zhai (root@derzh.com)
-- @copyright: Copyright (c) 2013 EMZ Kingsoft Co., Ltd.
--------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
-------------------------------------------------------------------------------------------------------
local ipairs, pairs, next, pcall, select = ipairs, pairs, next, pcall, select
local string, math, table = string, math, table
-- lib apis caching
local X = MY
local UI, GLOBAL, CONSTANT, wstring, lodash = X.UI, X.GLOBAL, X.CONSTANT, X.wstring, X.lodash
-------------------------------------------------------------------------------------------------------
local PLUGIN_NAME = 'MY_Force'
local PLUGIN_ROOT = X.PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_Force'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
X.RegisterRestriction('MY_Force', { ['*'] = false, classic = true })
X.RegisterRestriction('MY_ForceGuding', { ['*'] = true, intl = false })
--------------------------------------------------------------------------

local O = X.CreateUserSettingsModule('MY_Force', _L['Target'], {
	bAlertPet = { -- 五毒宠物消失提醒
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Force'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	bMarkPet = { -- 五毒宠物标记
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Force'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	bFeedHorse = { -- 提示喂马
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Force'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	bWarningDebuff = { -- 警告 debuff 类型
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Force'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	nDebuffNum = { -- debuff 类型达到几个时警告
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Force'],
		xSchema = X.Schema.Number,
		xDefaultValue = 3,
	},
	bAlertWanted = { -- 在线被悬赏时提醒自己
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Force'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
})
local D = {
	nFrameXJ = 0, -- 献祭、各种召唤跟宠的帧数
}

-- check pet of 5D （XJ：2226）
function D.OnAlertPetChange()
	local bAlertPet = O.bAlertPet
	if bAlertPet then
		X.RegisterEvent('NPC_LEAVE_SCENE', 'MY_Force__AlertPet', function()
			local me = GetClientPlayer()
			if me and me.dwForceID == FORCE_TYPE.WU_DU then
				local pet = me.GetPet()
				if pet and pet.dwID == arg0 and (GetLogicFrameCount() - D.nFrameXJ) >= 32 then
					OutputWarningMessage('MSG_WARNING_YELLOW', _L('Your pet [%s] disappeared!',  pet.szName))
					PlaySound(SOUND.UI_SOUND, g_sound.CloseAuction)
				end
			end
		end)
		X.RegisterEvent('DO_SKILL_CAST', 'MY_Force__AlertPet', function()
			if arg0 == UI_GetClientPlayerID() then
				-- 献祭、各种召唤：2965，2221 ~ 2226
				if arg1 == 2965 or (arg1 >= 2221 and arg1 <= 2226) then
					D.nFrameXJ = GetLogicFrameCount()
				end
			end
		end)
	else
		X.RegisterEvent('NPC_LEAVE_SCENE', 'MY_Force__AlertPet', false)
		X.RegisterEvent('DO_SKILL_CAST', 'MY_Force__AlertPet', false)
	end
end

-- check to mark pet
do
local function UpdatePetMark(bMark)
	local me = GetClientPlayer()
	if not me then
		return
	end
	local pet = me.GetPet()
	if pet then
		local dwEffect = 13
		if not bMark then
			dwEffect = 0
		end
		SceneObject_SetTitleEffect(TARGET.NPC, pet.dwID, dwEffect)
	end
end
function D.OnMarkPetChange()
	local bMarkPet = O.bMarkPet
	if bMarkPet then
		X.RegisterEvent({'NPC_ENTER_SCENE', 'NPC_DISPLAY_DATA_UPDATE'}, 'MY_Force__MarkPet', function()
			local pet = GetClientPlayer().GetPet()
			if pet and arg0 == pet.dwID then
				X.DelayCall(500, function()
					UpdatePetMark(true)
				end)
			else
				local npc = GetNpc(arg0)
				if npc.dwTemplateID == 46297 and npc.dwEmployer == UI_GetClientPlayerID() then
					SceneObject_SetTitleEffect(TARGET.NPC, npc.dwID, 13)
				end
			end
		end)
	else
		X.RegisterEvent({'NPC_ENTER_SCENE', 'NPC_DISPLAY_DATA_UPDATE'}, 'MY_Force__MarkPet', false)
	end
	UpdatePetMark(bMarkPet)
end
end

-- check feed horse
function D.OnFeedHorseChange()
	local bFeedHorse = O.bFeedHorse
	if bFeedHorse then
		X.RegisterEvent('SYS_MSG', 'MY_Force__FeedHorse', function()
			local me = GetClientPlayer()
			-- 读条技能
			if arg0 == 'UI_OME_SKILL_CAST_LOG' and O.bFeedHorse and arg1 == me.dwID
			and (arg2 == 433 or arg2 == 53 or Table_GetSkillName(arg2, 1) == Table_GetSkillName(53, 1)) then -- on prepare 骑乘
				local it = me.GetEquippedHorse()
				if it then
					local nFullLevel = it.GetHorseFullLevel()
					if nFullLevel ~= FULL_LEVEL.FULL then
						local itemInfo = GetItemInfo(it.dwTabType, it.dwIndex)
						local tDisplay = Table_GetRideSubDisplay(itemInfo.nDetail)
						local szFullMeasure = tDisplay['szFullMeasure' .. (nFullLevel + 1)]
						OutputWarningMessage('MSG_WARNING_YELLOW', Table_GetItemName(it.nUiId) .. ': ' .. szFullMeasure)
						PlaySound(SOUND.UI_SOUND, g_sound.CloseAuction)
					end
				end
			end
		end)
	else
		X.RegisterEvent('SYS_MSG', 'MY_Force__FeedHorse', false)
	end
end

-- check warning buff type
function D.OnWarningDebuffChange()
	local bWarningDebuff = O.bWarningDebuff
	if bWarningDebuff then
		X.RegisterEvent('BUFF_UPDATE', 'MY_Force__WarningDebuff', function()
			-- buff update：
			-- arg0：dwPlayerID，arg1：bDelete，arg2：nIndex，arg3：bCanCancel
			-- arg4：dwBuffID，arg5：nStackNum，arg6：nEndFrame，arg7：？update all?
			-- arg8：nLevel，arg9：dwSkillSrcID
			local me = GetClientPlayer()
			if arg0 ~= me.dwID or not O.bWarningDebuff or (not arg7 and arg3) then
				return
			end
			local t, t2 = {}, {}
			for _, buff in X.ipairs_c(X.GetBuffList(me)) do
				if not buff.bCanCancel and not t2[buff.dwID] then
					local info = GetBuffInfo(buff.dwID, buff.nLevel, {})
					if info and info.nDetachType > 2 then
						if not t[info.nDetachType] then
							t[info.nDetachType] = 1
						else
							t[info.nDetachType] = t[info.nDetachType] + 1
						end
						t2[buff.dwID] = true
					end
				end
			end
			for nType, nNum in pairs(t) do
				if nNum >= O.nDebuffNum then
					local szText = _L('Your debuff of type [%s] reached [%d]', g_tStrings.tBuffDetachType[nType], nNum)
					OutputWarningMessage('MSG_WARNING_GREEN', szText)
					PlaySound(SOUND.UI_SOUND, g_sound.CloseAuction)
				end
			end
		end)
	else
		X.RegisterEvent('BUFF_UPDATE', 'MY_Force__WarningDebuff', false)
	end
end

-- check on wanted msg
do
local function OnMsgAnnounce(szMsg)
	local _, _, sM, sN = string.find(szMsg, _L['Now somebody pay (%d+) gold to buy life of (.-)'])
	if sM and sN == GetClientPlayer().szName then
		local fW = function()
			OutputWarningMessage('MSG_WARNING_RED', _L('Congratulations, you offered a reward [%s] gold!', sM))
			PlaySound(SOUND.UI_SOUND, g_sound.CloseAuction)
		end
		SceneObject_SetTitleEffect(TARGET.PLAYER, UI_GetClientPlayerID(), 47)
		fW()
		X.DelayCall(2000, fW)
		X.DelayCall(4000, fW)
		D.bHasWanted = true
	end
end
function D.OnAlertWantedChange()
	local bAlertWanted = O.bAlertWanted
	if bAlertWanted then
		-- 变化时更新头顶效果
		X.RegisterEvent('PLAYER_STATE_UPDATE', 'MY_Force__AlertWanted', function()
			if arg0 == UI_GetClientPlayerID() then
				if D.bHasWanted then
					SceneObject_SetTitleEffect(TARGET.PLAYER, arg0, 47)
				end
			end
		end)
		-- 重伤后删除头顶效果
		X.RegisterEvent('SYS_MSG', 'MY_Force__AlertWanted', function()
			if arg0 == 'UI_OME_DEATH_NOTIFY' then
				if D.bHasWanted and arg1 == UI_GetClientPlayerID() then
					D.bHasWanted = nil
					SceneObject_SetTitleEffect(TARGET.PLAYER, arg1, 0)
				end
			end
		end)
		RegisterMsgMonitor(OnMsgAnnounce, {'MSG_GM_ANNOUNCE'})
	else
		X.RegisterEvent('PLAYER_STATE_UPDATE', 'MY_Force__AlertWanted', false)
		X.RegisterEvent('SYS_MSG', 'MY_Force__AlertWanted', false)
		UnRegisterMsgMonitor(OnMsgAnnounce, {'MSG_GM_ANNOUNCE'})
	end
end
end

X.RegisterEvent('LOADING_END', 'MY_Force', function()
	local buff = Table_GetBuff(374, 1)
	if buff then
		buff.bShowTime = 1
	end
end)

X.RegisterUserSettingsUpdate('@@INIT@@', 'MY_Force', function()
	D.OnAlertPetChange()
	D.OnMarkPetChange()
	D.OnFeedHorseChange()
	D.OnWarningDebuffChange()
	D.OnAlertWantedChange()
end)

-------------------------------------
-- 设置界面
-------------------------------------
local PS = { szRestriction = 'MY_Force' }
function PS.OnPanelActive(frame)
	local ui = UI(frame)
	local nPaddingX, nPaddingY = 25, 25
	local x, y = nPaddingX, nPaddingY
	local W, H = ui:Size()
	-- wu du
	---------------
	ui:Append('Text', { text = g_tStrings.tForceTitle[CONSTANT.FORCE_TYPE.WU_DU], x = x, y = y, font = 27 })
	if GLOBAL.GAME_BRANCH ~= 'classic' then
		-- crlf
		x = nPaddingX + 10
		y = y + 28
		-- disappear
		x = ui:Append('WndCheckBox', {
			x = x, y = y,
			text = _L['Alert when pet disappear unexpectedly (for 5D)'],
			checked = O.bAlertPet,
			oncheck = function(bChecked)
				O.bAlertPet = bChecked
				D.OnAlertPetChange()
			end,
		}):AutoWidth():Pos('BOTTOMRIGHT') + 10
		-- mark pet
		ui:Append('WndCheckBox', {
			x = x, y = y,
			text = _L['Mark pet'],
			checked = O.bMarkPet,
			oncheck = function(bChecked)
				O.bMarkPet = bChecked
				D.OnMarkPetChange()
			end,
		}):AutoWidth()
		-- crlf
		x = nPaddingX + 10
		y = y + 28
		-- guding
		x = ui:Append('WndCheckBox', {
			x = x, y = y,
			text = _L['Display GUDING of teammate, change color'],
			checked = MY_ForceGuding.bEnable,
			oncheck = function(bChecked)
				MY_ForceGuding.bEnable = bChecked
			end,
		}):AutoWidth():Pos('BOTTOMRIGHT') + 2
		x = ui:Append('Shadow', {
			x = x, y = y + 2, w = 18, h = 18,
			color = MY_ForceGuding.color,
			onclick = function()
				local ui = UI(this)
				OpenColorTablePanel(function(r, g, b)
					ui:Color(r, g, b)
					MY_ForceGuding.color = { r, g, b }
				end)
			end,
		}):Pos('BOTTOMRIGHT') + 10
		ui:Append('WndCheckBox', {
			x = x, y = y,
			text = _L['Auto talk in team channel after puting GUDING'],
			checked = MY_ForceGuding.bAutoSay,
			autoenable = function() return MY_ForceGuding.bEnable end,
			oncheck = function(bChecked)
				MY_ForceGuding.bAutoSay = bChecked
			end,
		})
		x = nPaddingX + 10
		y = y + 28
		ui:Append('WndEditBox', {
			x = x, y = y, w = W - x * 2, h = 50,
			multiline = true, limit = 512,
			text = MY_ForceGuding.szSay,
			autoenable = function() return MY_ForceGuding.bAutoSay end,
			onchange = function(szText)
				MY_ForceGuding.szSay = szText
			end,
		})
		-- crlf
		y = y + 54
		if not X.IsRestricted('MY_ForceGuding') then
			-- crlf
			x = nPaddingX + 10
			x = ui:Append('WndCheckBox', {
				x = x, y = y,
				checked = MY_ForceGuding.bUseMana,
				text = _L['Automatic eat GUDING when mana below '],
				oncheck = function(bChecked)
					MY_ForceGuding.bUseMana = bChecked
				end,
			}):AutoWidth():Pos('BOTTOMRIGHT') + 5
			x = ui:Append('WndTrackbar', {
				x = x, y = y, w = 70, h = 25,
				range = {0, 100, 50},
				value = MY_ForceGuding.nManaMp,
				onchange = function(nVal) MY_ForceGuding.nManaMp = nVal end,
				autoenable = function() return MY_ForceGuding.bUseMana end,
			}):Pos('BOTTOMRIGHT') + 65
			x = ui:Append('Text', {
				x = x, y = y - 3,
				text = _L[', or life below '],
			}):AutoWidth():Pos('BOTTOMRIGHT') + 5
			x = ui:Append('WndTrackbar', {
				x = x, y = y, w = 70, h = 25,
				range = {0, 100, 50},
				value = MY_ForceGuding.nManaHp,
				onchange = function(nVal) MY_ForceGuding.nManaHp = nVal end,
				autoenable = function() return MY_ForceGuding.bUseMana end,
			}):Pos('BOTTOMRIGHT')
			y = y + 36
		end
	end
	-- other
	---------------
	x = nPaddingX
	ui:Append('Text', { text = _L['Others'], x = x, y = y, font = 27 })
	-- crlf
	x = nPaddingX + 10
	y = y + 28
	x, y = MY_EnergyBar.OnPanelActivePartial(ui, nPaddingX, nPaddingY, W, H, x, y)
	-- hungry
	x = ui:Append('WndCheckBox', {
		x = x, y = y,
		text = _L['Alert when horse is hungry'],
		checked = O.bFeedHorse,
		oncheck = function(bChecked)
			O.bFeedHorse = bChecked
			D.OnFeedHorseChange()
		end,
	}):AutoWidth():Pos('BOTTOMRIGHT') + 10
	-- crlf
	x = nPaddingX + 10
	y = y + 28
	-- be wanted alert
	ui:Append('WndCheckBox', {
		x = x, y = y,
		text = _L['Alert when I am wanted publishing online'],
		checked = O.bAlertWanted,
		oncheck = function(bChecked)
			O.bAlertWanted = bChecked
			D.OnAlertWantedChange()
		end,
	})
	-- crlf
	x = nPaddingX + 10
	y = y + 28
	-- debuff type num
	x = ui:Append('WndCheckBox', {
		x = x, y = y,
		text = _L['Alert when my same type of debuff reached a certain number '],
		checked = O.bWarningDebuff,
		oncheck = function(bChecked)
			O.bWarningDebuff = bChecked
			D.OnWarningDebuffChange()
		end,
	}):AutoWidth():Pos('BOTTOMRIGHT') + 10
	ui:Append('WndComboBox', {
		x = x, y = y, w = 50, h = 25,
		autoenable = function() return O.bWarningDebuff end,
		text = tostring(O.nDebuffNum),
		menu = function()
			local ui = UI(this)
			local m0 = {}
			for i = 1, 10 do
				table.insert(m0, {
					szOption = tostring(i),
					fnAction = function()
						O.nDebuffNum = i
						ui:Text(tostring(i))
					end,
				})
			end
			return m0
		end,
	})
	-- crlf
	x = nPaddingX + 10
	y = y + 28
	x, y = MY_ChangGeShadow.OnPanelActivePartial(ui, nPaddingX, nPaddingY, W, H, x, y)
end
X.RegisterPanel(_L['Target'], 'MY_Force', _L['MY_Force'], 327, PS)

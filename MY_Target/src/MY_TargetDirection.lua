--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 目标方位显示
-- @author   : Webster
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
local PLUGIN_NAME = 'MY_Target'
local PLUGIN_ROOT = X.PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_TargetDirection'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
--------------------------------------------------------------------------

local INI_PATH = X.PACKET_INFO.ROOT .. 'MY_Target/ui/MY_TargetDirection.ini'
local IMG_PATH = X.PACKET_INFO.ROOT .. 'MY_Target/img/MY_TargetDirection.uitex'

local O = X.CreateUserSettingsModule('MY_TargetDirection', _L['Target'], {
	bEnable = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Target'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	tAnchor = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Target'],
		xSchema = X.Schema.FrameAnchor,
		xDefaultValue = { s = 'CENTER', r = 'CENTER', x = 250, y = 100 },
	},
	eDistanceType = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Target'],
		xSchema = X.Schema.String,
		xDefaultValue = 'global',
	},
})
local D = {}

function D.GetFrame()
	return Station.Lookup('Normal/MY_TargetDirection')
end

function D.OpenPanel()
	local frame = D.GetFrame()
	if not frame then
		frame = Wnd.OpenWindow(INI_PATH, 'MY_TargetDirection')
	end
	return frame
end

function D.ClosePanel()
	Wnd.CloseWindow('MY_TargetDirection')
end

function D.UpdateAnchor()
	local frame = D.GetFrame()
	if not frame then
		return
	end
	local a = O.tAnchor
	frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	frame:CorrectPos()
end

function D.CheckEnable()
	if D.bReady and O.bEnable and not X.IsRestricted('MY_Target') then
		D.OpenPanel()
	else
		D.ClosePanel()
	end
end

function D.GetState(tar)
	if tar.nMoveState == MOVE_STATE.ON_SIT then
		return 533, g_tStrings.tPlayerMoveState[tar.nMoveState]
	elseif tar.nMoveState == MOVE_STATE.ON_DEATH then
		return 2215, g_tStrings.tPlayerMoveState[tar.nMoveState]
	elseif tar.nMoveState == MOVE_STATE.ON_KNOCKED_DOWN then
		return 2027, g_tStrings.tPlayerMoveState[tar.nMoveState]
	elseif tar.nMoveState == MOVE_STATE.ON_DASH then
		return 2030, g_tStrings.tPlayerMoveState[tar.nMoveState]
	elseif tar.nMoveState == MOVE_STATE.ON_SKILL_MOVE_DST then
		return 1487, _L["Move"]
	else
		-- check other movestate
		if tar.nMoveState == MOVE_STATE.ON_HALT then
			return 2019, g_tStrings.tPlayerMoveState[tar.nMoveState]
		elseif tar.nMoveState == MOVE_STATE.ON_FREEZE then
			return 2038, g_tStrings.tPlayerMoveState[tar.nMoveState]
		elseif tar.nMoveState == MOVE_STATE.ON_ENTRAP then
			return 2020, _L["Entrap"]
		end
		-- check speed
		if IsPlayer(tar.dwID) and tar.nRunSpeed and tar.nRunSpeed < 20 then
			return 348, _L["Slower"]
		end
	end
end

function D.OnFrameCreate()
	this:RegisterEvent('UI_SCALED')
	this:RegisterEvent('ON_ENTER_CUSTOM_UI_MODE')
	this:RegisterEvent('ON_LEAVE_CUSTOM_UI_MODE')
	D.UpdateAnchor()
end

do
local function SetObjectAvatar(img, tar, info, bInfo)
	if IsPlayer(tar.dwID) then
		if bInfo and info.dwMountKungfuID then
			img:FromIconID(Table_GetSkillIconID(info.dwMountKungfuID, 1))
		else
			local kungfu = tar.GetKungfuMount and tar.GetKungfuMount()
			if kungfu and kungfu.dwSkillID ~= 0 then
				img:FromIconID(Table_GetSkillIconID(kungfu.dwSkillID, 1))
			else
				img:FromUITex(GetForceImage(tar.dwForceID))
			end
		end
	else
		local szPath = NPC_GetProtrait(tar.dwModelID)
		if not szPath or not IsFileExist(szPath) then
			szPath = NPC_GetHeadImageFile(tar.dwModelID)
		end
		if not szPath or not IsFileExist(szPath) then
			img:FromUITex(GetNpcHeadImage(tar.dwID))
		else
			img:FromTextureFile(szPath)
		end
	end
end

function D.OnFrameBreathe()
	local me = GetClientPlayer()
	local dwType, dwID = X.GetTarget()
	local tar, info, bInfo = X.GetObject(dwType, dwID)
	if tar and tar.dwID ~= me.dwID then
		-- 头像
		SetObjectAvatar(this:Lookup('', 'Handle_Main/Image_Force'), tar, info, bInfo)
		-- 方位
		local dwRad1 = math.atan2(tar.nY - me.nY, tar.nX - me.nX)
		local dwRad2 = me.nFaceDirection / 128 * math.pi
		this:Lookup('', 'Handle_Main/Image_Arrow'):SetRotate(1.5 * math.pi + dwRad2 - dwRad1)
		-- 颜色
		local nFrame = 4
		if me.IsInParty() and X.IsParty(tar.dwID) then
			nFrame = 3
		elseif X.IsEnemy(me.dwID, tar.dwID) then
			nFrame = 1
		elseif IsAlly(me.dwID, tar.dwID) then
			nFrame = 2
		end
		-- 状态
		local dwIcon, szState = D.GetState(tar)
		local boxState = this:Lookup('', 'Handle_Main/Box_State')
		local txtState = this:Lookup('', 'Handle_Main/Text_State')
		if dwIcon then
			boxState:Show()
			boxState:SetObjectIcon(dwIcon)
		else
			boxState:Hide()
		end
		txtState:SetText(szState or '')
		-- 距离
		this:Lookup('', 'Handle_Main/Text_Distance'):SetText(_L('%.1f feet', X.GetDistance(me, tar, O.eDistanceType)))
		this:Show()
	else
		this:Hide()
	end
end
end

function D.OnEvent(event)
	if event == 'ON_ENTER_CUSTOM_UI_MODE' or event == 'ON_LEAVE_CUSTOM_UI_MODE' then
		UpdateCustomModeWindow(this, _L['MY_TargetDirection'])
	elseif event == 'UI_SCALED' then
		D.UpdateAnchor()
	end
end

function D.OnFrameDragEnd()
	this:CorrectPos()
	O.tAnchor = GetFrameAnchor(this)
end

X.RegisterEvent('MY_RESTRICTION', 'MY_Target', function()
	if arg0 and arg0 ~= 'MY_Target' then
		return
	end
	D.CheckEnable()
end)
X.RegisterUserSettingsUpdate('@@INIT@@', 'MY_TargetDirection', function()
	D.bReady = true
	D.CheckEnable()
	D.UpdateAnchor()
end)

-- Global exports
do
local settings = {
	name = 'MY_TargetDirection',
	exports = {
		{
			fields = {
				'bEnable',
				'tAnchor',
				'eDistanceType',
			},
			root = O,
		},
		{
			preset = 'UIEvent',
			root = D,
		},
	},
	imports = {
		{
			fields = {
				'bEnable',
				'tAnchor',
				'eDistanceType',
			},
			triggers = {
				bEnable = D.CheckEnable,
				tAnchor = D.UpdateAnchor,
			},
			root = O,
		},
	},
}
MY_TargetDirection = X.CreateModule(settings)
end

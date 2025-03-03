--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 中央报警
-- @author   : 茗伊 @双梦镇 @追风蹑影
-- @ref      : William Chan (Webster)
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
local PLUGIN_NAME = 'MY_TeamMon'
local PLUGIN_ROOT = X.PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_TeamMon_CA'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
--------------------------------------------------------------------------

local CA_INIFILE = X.PACKET_INFO.ROOT .. 'MY_TeamMon/ui/MY_TeamMon_CA.ini'
local O = X.CreateUserSettingsModule('MY_TeamMon_CA', _L['Raid'], {
	tAnchor = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_TeamMon'],
		xSchema = X.Schema.FrameAnchor,
		xDefaultValue = { s = 'CENTER', r = 'CENTER', x = 0, y = 350 },
	},
})
local D = {}

-- FireUIEvent('MY_TM_CA_CREATE', 'test', 3)
local function CreateCentralAlert(szMsg, nTime, bXml)
	local msg = D.msg
	nTime = nTime or 3
	msg:Clear()
	if not bXml then
		szMsg = GetFormatText(szMsg, 44, 255, 255, 255)
	end
	msg:AppendItemFromString(szMsg)
	msg:FormatAllItemPos()
	local w, h = msg:GetAllItemSize()
	msg:SetRelPos((480 - w) / 2, (45 - h) / 2 - 1)
	D.handle:FormatAllItemPos()
	msg.nTime   = nTime
	msg.nCreate = GetTime()
	D.frame:SetAlpha(255)
	D.frame:Show()
end

function D.OnFrameCreate()
	this:RegisterEvent('UI_SCALED')
	this:RegisterEvent('ON_ENTER_CUSTOM_UI_MODE')
	this:RegisterEvent('ON_LEAVE_CUSTOM_UI_MODE')
	this:RegisterEvent('MY_TM_CA_CREATE')
	D.frame  = this
	D.handle = this:Lookup('', '')
	D.msg    = this:Lookup('', 'MessageBox')
	D.UpdateAnchor(this)
end

function D.OnFrameRender()
	local nNow = GetTime()
	if D.msg.nCreate then
		local nTime = ((nNow - D.msg.nCreate) / 1000)
		local nLeft  = D.msg.nTime - nTime
		if nLeft < 0 then
			D.msg.nCreate = nil
			D.frame:Hide()
		else
			local nTimeLeft = nTime * 1000 % 750
			local nAlpha = 50 * nTimeLeft / 750
			if math.floor(nTime / 0.75) % 2 == 1 then
				nAlpha = 50 - nAlpha
			end
			D.frame:SetAlpha(255 - nAlpha)
		end
	end
end

function D.OnEvent(szEvent)
	if szEvent == 'MY_TM_CA_CREATE' then
		CreateCentralAlert(arg0, arg1, arg2)
	elseif szEvent == 'UI_SCALED' then
		D.UpdateAnchor(this)
	elseif szEvent == 'ON_ENTER_CUSTOM_UI_MODE' or szEvent == 'ON_LEAVE_CUSTOM_UI_MODE' then
		UpdateCustomModeWindow(this, _L['Center alarm'])
		if szEvent == 'ON_ENTER_CUSTOM_UI_MODE' then
			this:Show()
		else
			this:Hide()
		end
	end
end

function D.OnFrameDragEnd()
	this:CorrectPos()
	O.tAnchor = GetFrameAnchor(this)
end

function D.UpdateAnchor(frame)
	local a = O.tAnchor
	frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	frame:CorrectPos()
end

function D.Init()
	Wnd.CloseWindow('MY_TeamMon_CA')
	Wnd.OpenWindow(CA_INIFILE, 'MY_TeamMon_CA'):Hide()
end

X.RegisterUserSettingsUpdate('@@INIT@@', 'MY_TeamMon_CA', D.Init)


-- Global exports
do
local settings = {
	name = 'MY_TeamMon_CA',
	exports = {
		{
			preset = 'UIEvent',
			root = D,
		},
		{
			fields = {
				'tAnchor',
			},
			root = O,
		},
	},
	imports = {
		{
			fields = {
				'tAnchor',
			},
			root = O,
		},
	},
}
MY_TeamMon_CA = X.CreateModule(settings)
end

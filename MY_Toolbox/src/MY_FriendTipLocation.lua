--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 好友界面显示所有好友位置
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
local PLUGIN_NAME = 'MY_Toolbox'
local PLUGIN_ROOT = X.PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_FriendTipLocation'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
X.RegisterRestriction('MY_FriendTipLocation', { ['*'] = false })
X.RegisterRestriction('MY_FriendTipLocation.LV2', { ['*'] = true })
--------------------------------------------------------------------------

local O = X.CreateUserSettingsModule('MY_FriendTipLocation', _L['General'], {
	bEnable = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Toolbox'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
})
local D = {}

function D.Hook()
	local frame = Station.Lookup('Normal/FriendTip')
	if not frame then
		return
	end
	local me = GetClientPlayer()
	if not me then
		return
	end
	local txtName = frame:Lookup('', 'Text_Name')
	local txtTitle = frame:Lookup('Wnd_Friend', 'Text_WhereT')
	local txtLocation = frame:Lookup('Wnd_Friend', 'Text_Where')
	if not (txtName and txtTitle and txtLocation) then
		return
	end
	if not txtLocation.__MY_SetText then
		txtLocation.__MY_SetText = txtLocation.SetText
		txtLocation.SetText = function(_, szText)
			local info = txtName and X.GetFriend(txtName:GetText())
			local card = info and info.isonline and GetFellowshipCardClient().GetFellowshipCardInfo(info.id)
			if card and ((info.istwoway and info.attraction >= 200) or not X.IsRestricted('MY_FriendTipLocation.LV2')) then
				szText = Table_GetMapName(card.dwMapID)
				if (me.nCamp == CAMP.EVIL and card.nCamp == CAMP.GOOD)
				or (me.nCamp == CAMP.GOOD and card.nCamp == CAMP.EVIL) then
					szText = szText .. _L['(Different camp)']
				end
			end
			txtLocation:__MY_SetText(szText)
		end
	end
end

function D.Unhook()
	Wnd.CloseWindow('FriendTip')
end

function D.CheckEnable()
	if D.bReady and O.bEnable and not X.IsRestricted('MY_FriendTipLocation') then
		D.Hook()
		X.RegisterFrameCreate('FriendTip', 'MY_FriendTipLocation', D.Hook)
	else
		D.Unhook()
		X.RegisterFrameCreate('FriendTip', 'MY_FriendTipLocation', false)
	end
end

X.RegisterUserSettingsUpdate('@@INIT@@', 'MY_FriendTipLocation', function()
	D.bReady = true
	D.CheckEnable()
end)
X.RegisterReload('MY_FriendTipLocation', D.Unhook)
X.RegisterEvent('MY_RESTRICTION', 'MY_FriendTipLocation', function()
	if arg0 and arg0 ~= 'MY_FriendTipLocation' then
		return
	end
	D.CheckEnable()
end)

function D.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, nX, nY, nLH)
	if not X.IsRestricted('MY_FriendTipLocation') then
		nX = nX + ui:Append('WndCheckBox', {
			x = nX, y = nY,
			text = _L['Show all friend tip location'],
			checked = MY_FriendTipLocation.bEnable,
			oncheck = function(bChecked)
				MY_FriendTipLocation.bEnable = bChecked
			end,
		}):AutoWidth():Width() + 5
	end
	return nX, nY
end

-- Global exports
do
local settings = {
	name = 'MY_FriendTipLocation',
	exports = {
		{
			fields = {
				'OnPanelActivePartial',
			},
			root = D,
		},
		{
			fields = {
				'bEnable',
			},
			root = O,
		},
	},
	imports = {
		{
			fields = {
				'bEnable',
			},
			triggers = {
				bEnable = D.CheckEnable,
			},
			root = O,
		},
	},
}
MY_FriendTipLocation = X.CreateModule(settings)
end

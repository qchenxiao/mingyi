--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 绑定 JX3BOX
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
local PLUGIN_NAME = 'MY_TeamTools'
local PLUGIN_ROOT = X.PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_JBBind'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/jx3box/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
--------------------------------------------------------------------------
local D = {}
local O = {
	uid = nil,
	pending = false,
}

function D.FetchBindStatus(resolve, reject)
	if X.IsNil(O.uid) then
		local szURL = 'https://pull.j3cx.com/role/query?'
			.. X.EncodePostData(X.UrlEncode(X.SignPostData({
				l = AnsiToUTF8(GLOBAL.GAME_LANG),
				L = AnsiToUTF8(GLOBAL.GAME_EDITION),
				jx3id = AnsiToUTF8(X.GetClientUUID()),
			}, X.SECRET.ROLE_QUERY)))
		O.pending = true
		X.Ajax({
			driver = 'auto', mode = 'auto', method = 'auto',
			url = szURL,
			charset = 'utf8',
			success = function(szHTML)
				O.pending = false
				local res = X.JsonDecode(szHTML)
				if X.Get(res, {'code'}) == 0 then
					O.uid = X.Get(res, {'data', 'uid'})
					X.SafeCall(resolve, O.uid)
				else
					X.SafeCall(reject)
				end
			end,
			error = function()
				O.pending = false
				X.SafeCall(reject)
			end,
		})
	else
		X.SafeCall(resolve, O.uid)
	end
end

function D.Bind(szToken, resolve, reject)
	local dwID = UI_GetClientPlayerID()
	if IsRemotePlayer(dwID) then
		X.Alert(_L['You are crossing server, please do this after backing.'])
		return
	end
	local me = GetClientPlayer()
	local szURL = 'https://push.j3cx.com/role/bind?'
		.. X.EncodePostData(X.UrlEncode(X.SignPostData({
			l = AnsiToUTF8(GLOBAL.GAME_LANG),
			L = AnsiToUTF8(GLOBAL.GAME_EDITION),
			token = AnsiToUTF8(szToken),
			cguid = X.GetClientGUID(),
			jx3id = AnsiToUTF8(X.GetClientUUID()),
			server = AnsiToUTF8(X.GetRealServer(2)),
			id = AnsiToUTF8(dwID),
			name = AnsiToUTF8(X.GetUserRoleName()),
			mount = me.GetKungfuMount().dwMountType,
			type = me.nRoleType,
		}, X.SECRET.ROLE_BIND)))
	X.Ajax({
		driver = 'auto', mode = 'auto', method = 'auto',
		url = szURL,
		charset = 'utf8',
		success = function(szHTML)
			local res = X.JsonDecode(szHTML)
			if X.Get(res, {'code'}) == 0 then
				O.uid = nil
				X.SafeCall(resolve, O.uid)
			else
				X.Alert((X.Get(res, {'msg'}, _L['Request failed.'])))
				X.SafeCall(reject)
			end
		end,
	})
end

function D.Unbind(resolve, reject)
	local szURL = 'https://push.j3cx.com/role/unbind?'
		.. X.EncodePostData(X.UrlEncode(X.SignPostData({
			l = AnsiToUTF8(GLOBAL.GAME_LANG),
			L = AnsiToUTF8(GLOBAL.GAME_EDITION),
			jx3id = AnsiToUTF8(X.GetClientUUID()),
		}, X.SECRET.ROLE_UNBIND)))
	X.Ajax({
		driver = 'auto', mode = 'auto', method = 'auto',
		url = szURL,
		charset = 'utf8',
		success = function(szHTML)
			local res = X.JsonDecode(szHTML)
			if X.Get(res, {'code'}) == 0 then
				O.uid = nil
				X.SafeCall(resolve)
			else
				X.Alert((X.Get(res, {'msg'}, _L['Request failed.'])))
				X.SafeCall(reject)
			end
		end,
	})
end

function D.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, nLH, nX, nY, nLFY)
	-- 角色认证
	local uiCCStatus, uiBtnCCStatus, uiBtnCCLink
	local function UpdateUI()
		if uiCCStatus:Count() == 0 or uiBtnCCStatus:Count() == 0 or uiBtnCCLink:Count() == 0 then
			return
		end
		if O.pending then
			uiCCStatus:Text(_L['Loading'])
			uiBtnCCStatus:Text(_L['Click fetch'])
		elseif X.IsNil(O.uid) then
			uiCCStatus:Text(_L['Unknown'])
			uiBtnCCStatus:Text(_L['Click fetch'])
		elseif X.IsEmpty(O.uid) then
			uiCCStatus:Text(_L['Not bind'])
			uiBtnCCStatus:Text(_L['Click bind'])
		else
			uiCCStatus:Text(_L('Binded (ID: %s)', O.uid))
			uiBtnCCStatus:Text(_L['Click unbind'])
		end
		uiCCStatus:AutoWidth()
		uiBtnCCStatus:Enable(not O.pending)
		uiBtnCCStatus:Left(uiCCStatus:Left() + uiCCStatus:Width() + 20)
		uiBtnCCLink:Left(uiBtnCCStatus:Left() + uiBtnCCStatus:Width() + 10)
	end

	nX = nPaddingX
	nY = nLFY
	nY = nY + ui:Append('Text', { x = nX, y = nY, text = _L['Character Certification'], font = 27 }):Height() + 2

	nX = nPaddingX + 10
	nX = nX + ui:Append('Text', { x = nX, y = nY, w = 'auto', text = _L('Current character: %s', GetUserRoleName()) }):Width() + 20
	nX = nX + ui:Append('Text', { x = nX, y = nY, w = 'auto', text = _L['Status: '] }):Width()
	uiCCStatus = ui:Append('Text', { x = nX, y = nY, w = 'auto', text = _L['Loading'] })
	nX = nX + uiCCStatus:Width()
	uiBtnCCStatus = ui:Append('WndButton', {
		x = nX, y = nY + 2,
		buttonstyle = 'FLAT', text = _L['Bind'], enable = false,
		onclick = function()
			if O.pending then
				D.FetchBindStatus(UpdateUI, UpdateUI)
			elseif X.IsEmpty(O.uid) then
				GetUserInput(_L['Please input certification code:'], function(szText)
					uiBtnCCStatus:Enable(false)
					D.Bind(
						szText,
						function()
							X.Alert(_L['Bind succeed!'])
							D.FetchBindStatus(UpdateUI, UpdateUI)
						end,
						function()
							D.FetchBindStatus(UpdateUI, UpdateUI)
						end)
				end)
			elseif X.IsSafeLocked(SAFE_LOCK_EFFECT_TYPE.EQUIP) then
				X.Topmsg(_L['Please unlock equip lock first!'], CONSTANT.MSG_THEME.ERROR)
			else
				X.Confirm(_L['Sure to unbind character certification?'], function()
					uiBtnCCStatus:Enable(false)
					D.Unbind(
						function()
							X.Alert(_L['Unbind succeed!'])
							D.FetchBindStatus(UpdateUI, UpdateUI)
						end,
						function()
							D.FetchBindStatus(UpdateUI, UpdateUI)
						end)
				end)
			end
		end,
	})
	nX = nX + uiBtnCCStatus:Width()
	uiBtnCCLink = ui:Append('WndButton', {
		x = nX, y = nY + 2, w = 120,
		buttonstyle = 'FLAT', text = _L['Login team platform'],
		onclick = function()
			X.OpenBrowser('https://page.j3cx.com/jx3box/team/platform')
		end,
	})
	nX = nX + uiBtnCCLink:Width()

	UpdateUI()
	D.FetchBindStatus(UpdateUI, UpdateUI)

	nLFY = nY + nLH
	return nX, nY, nLFY
end

-- Global exports
do
local settings = {
	name = 'MY_JBBind',
	exports = {
		{
			fields = {
				OnPanelActivePartial = D.OnPanelActivePartial,
			},
		},
	},
}
MY_JBBind = X.CreateModule(settings)
end

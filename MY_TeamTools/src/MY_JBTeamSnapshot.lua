--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 快捷入团
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
local O = X.CreateUserSettingsModule('MY_JBTeamSnapshot', _L['Raid'], {
	szTeam = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_TeamTools'],
		xSchema = X.Schema.String,
		xDefaultValue = '',
	},
})
local D = {}

function D.CreateSnapshot()
	local dwID = UI_GetClientPlayerID()
	if IsRemotePlayer(dwID) then
		X.Alert(_L['You are crossing server, please do this after backing.'])
		return
	end
	if X.IsEmpty(O.szTeam) then
		X.ShowPanel()
		X.SwitchTab('MY_JX3BOX')
		return X.Alert(_L['Please input team name/id.'])
	end
	local aTeammate = {}
	local team = X.IsInParty() and GetClientTeam()
	if team then
		for _, dwTarID in ipairs(team.GetTeamMemberList()) do
			local info = team.GetMemberInfo(dwTarID)
			local guid = X.GetPlayerGUID(dwTarID) or 0
			table.insert(aTeammate, info.szName .. ',' .. dwTarID .. ',' .. guid .. ',' .. info.dwMountKungfuID)
		end
	end
	local me = GetClientPlayer()
	local szURL = 'https://push.j3cx.com/team/snapshot?'
		.. X.EncodePostData(X.UrlEncode(X.SignPostData({
			l = AnsiToUTF8(GLOBAL.GAME_LANG),
			L = AnsiToUTF8(GLOBAL.GAME_EDITION),
			team = AnsiToUTF8(O.szTeam),
			cguid = X.GetClientGUID(),
			jx3id = AnsiToUTF8(X.GetClientUUID()),
			server = AnsiToUTF8(X.GetRealServer(2)),
			teammate = AnsiToUTF8(table.concat(aTeammate, ';')),
		}, X.SECRET.TEAM_SNAPSHOT)))
	X.Ajax({
		driver = 'auto', mode = 'auto', method = 'auto',
		url = szURL,
		charset = 'utf8',
		success = function(szHTML)
			local res = X.JsonDecode(szHTML)
			if X.Get(res, {'code'}) == 0 then
				X.Alert(_L['Upload snapshot succeed!'])
			else
				X.Alert(_L['Upload snapshot failed!'] .. X.ReplaceSensitiveWord(X.Get(res, {'msg'}, _L['Request failed.'])))
			end
		end,
		error = function()
			X.Alert(_L['Upload snapshot failed!'])
		end,
	})
end

function D.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, nLH, nX, nY, nLFY)
	-- 快捷入团
	nX = nPaddingX
	nY = nLFY
	nY = nY + ui:Append('Text', { x = nX, y = nY, text = _L['Team Snapshot'], font = 27 }):Height() + 2

	nX = nPaddingX + 10
	local bLoading
	nX = nX + ui:Append('Text', { x = nX, y = nY, w = 'auto', text = _L['Team name/id:'] }):Width()
	ui:Append('Text', {
		x = nX, y = nY + nLH, h = 25,
		text = _L['(Input: Team@Server:Passcode)'],
		color = { 172, 172, 172 },
	}):AutoWidth()
	nX = nX + ui:Append('WndEditBox', {
		x = nX, y = nY + 2, w = 300, h = 25,
		text = O.szTeam,
		onchange = function(szText)
			O.szTeam = szText
		end,
	}):Width() + 5
	nX = nX + ui:Append('WndButton', {
		x = nX, y = nY + 2,
		buttonstyle = 'FLAT', text = _L['Upload Snapshot'],
		onclick = function()
			D.CreateSnapshot()
		end,
	}):Width() + 5
	nX = nX + ui:Append('WndButtonBox', {
		x = nX, y = nY + 5, w = 130, h = 20,
		color = { 234, 235, 185 },
		buttonstyle = 'LINK',
		text = _L['>> View Snapshots <<'],
		onclick = function()
			X.OpenBrowser('https://page.j3cx.com/jx3box/team/snapshot')
		end,
	}):AutoWidth():Width() + 5

	nLFY = nY + nLH
	return nX, nY, nLFY
end

-- Global exports
do
local settings = {
	name = 'MY_JBTeamSnapshot',
	exports = {
		{
			fields = {
				'CreateSnapshot',
				'OnPanelActivePartial',
			},
			root = D,
		},
		{
			fields = {
				'szTeam',
			},
			root = O,
		},
	},
	imports = {
		{
			fields = {
				'szTeam',
			},
			root = O,
		},
	},
}
MY_JBTeamSnapshot = X.CreateModule(settings)
end

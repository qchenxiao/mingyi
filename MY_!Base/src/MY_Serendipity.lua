--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 奇遇分享模块
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
local _L, D = X.LoadLangPack(X.PACKET_INFO.FRAMEWORK_ROOT .. 'lang/my_serendipity/'), {}
local O = {
	bEnable     = X.SchemaGet(X.LoadLUAData({'config/show_notify.jx3dat'           , X.PATH_TYPE.GLOBAL}), X.Schema.Boolean, false),
	bSound      = X.SchemaGet(X.LoadLUAData({'config/serendipity_sound.jx3dat'     , X.PATH_TYPE.GLOBAL}), X.Schema.Boolean, true ),
	bPreview    = X.SchemaGet(X.LoadLUAData({'config/serendipity_preview.jx3dat'   , X.PATH_TYPE.GLOBAL}), X.Schema.Boolean, true ),
	bAutoShare  = X.SchemaGet(X.LoadLUAData({'config/serendipity_autoshare.jx3dat' , X.PATH_TYPE.GLOBAL}), X.Schema.Boolean, false),
	bSilentMode = X.SchemaGet(X.LoadLUAData({'config/serendipity_silentmode.jx3dat', X.PATH_TYPE.GLOBAL}), X.Schema.Boolean, true ),
}

local SERENDIPITY_INFO
local SERENDIPITY_METHOD = {
	MSG_SYS       = 1, -- 系统消息
	EVENT_TRIGGER = 2, -- 事件机制
	LOOT_ITEM     = 3, -- 拾取物品
	FINISH_QUEST  = 4, -- 完成任务
}
local SERENDIPITY_STATUS = {
	-- START  = 0, -- 历史原因 0、1 枚举取值部分有逻辑问题，为了兼容已废除该值
	-- FINISH = 1,
	DONE   = 2, -- 直接完成
	START  = 3, -- 触发
	FINISH = 4, -- 完成
}
local SERENDIPITY_LIST = {}

X.RegisterEvent('MY_NOTIFY_DISMISS', function()
	for i, p in X.ipairs_r(SERENDIPITY_LIST) do
		if p.szKey == arg0 then
			table.remove(SERENDIPITY_LIST, i)
		end
	end
end)

function D.GetSerendipityShareName(fnAction, bNoConfirm)
	local szReporter = X.LoadLUAData({'config/realname.jx3dat', X.PATH_TYPE.ROLE}) or GetClientPlayer().szName:gsub('@.-$', '')
	if bNoConfirm then
		if fnAction then
			fnAction(szReporter)
		end
	else
		local function fnConfirm(szText)
			if szText ~= szReporter then
				X.SaveLUAData({'config/realname.jx3dat', X.PATH_TYPE.ROLE}, szText)
			end
			if fnAction then
				fnAction(szText)
			end
		end
		GetUserInput(_L['Please input your realname, left blank for anonymous report:'], fnConfirm, nil, nil, nil, szReporter, 6)
	end
end

function D.SerendipityShareConfirm(szName, szSerendipity, nMethod, eStatus, dwTime, szMode)
	local szKey = szName .. '_' .. szSerendipity .. '_' .. dwTime
	local szRegionU = AnsiToUTF8((X.GetRealServer(1)))
	local szServerU = AnsiToUTF8((X.GetRealServer(2)))
	local szSerendipityU = AnsiToUTF8(szSerendipity)
	local bSelf = szName == X.GetClientInfo().szName
	local szNameU = AnsiToUTF8(szName)
	local szNameCRC = ('%x%x%x'):format(szNameU:byte(), GetStringCRC(szNameU), szNameU:byte(-1))
	local nCount = bSelf and 0 or 1
	local function fnAction(szReporter)
		if szReporter == '' and nMethod ~= 1 then
			szName = ''
			szNameU = ''
		end
		local szReporterU = AnsiToUTF8(szReporter)
		local function DoUpload()
			--[[#DEBUG BEGIN]]
			X.Debug('Prepare for uploading serendipity ' .. szSerendipity .. ' by '
				.. szName .. '#' .. szNameCRC .. ' via ' .. szReporter, X.DEBUG_LEVEL.LOG)
			--[[#DEBUG END]]
			X.EnsureAjax({ url = 'https://serendipity.uploads.j3cx.com/api/serendipity/uploads?'
				.. 'l=' .. AnsiToUTF8(GLOBAL.GAME_LANG)
				.. '&L=' .. AnsiToUTF8(GLOBAL.GAME_EDITION)
				.. '&data=' .. X.EncryptString(X.JsonEncode({
					S = szRegionU, s = szServerU, a = szSerendipityU,
					n = szNameU, N = szNameCRC, R = szReporterU,
					f = eStatus, t = dwTime, c = nCount, m = nMethod,
				})) })
			X.EnsureAjax({ url = 'https://push.j3cx.com/api/serendipity/uploads?'
				.. X.EncodePostData(X.UrlEncode(X.SignPostData({
					l = AnsiToUTF8(GLOBAL.GAME_LANG),
					L = AnsiToUTF8(GLOBAL.GAME_EDITION),
					S = szRegionU, s = szServerU, a = szSerendipityU,
					n = szNameU, N = szNameCRC, R = szReporterU,
					f = eStatus, t = dwTime, c = nCount, m = nMethod,
				}, X.SECRET.SERENDIPITY_UPLOADS))) })
		end
		if szMode == 'manual' or nMethod ~= 1 then
			DoUpload()
		else
			X.DelayCall(math.random(0, 10000), DoUpload)
		end
		-- if szMode == 'manual' then
		-- 	DoUpload()
		-- else
		-- 	-- 战斗中移动中免打扰防止卡住
		-- 	X.BreatheCall(function()
		-- 		if Cursor.IsVisible()
		-- 		and me and not me.bFightState
		-- 		and (
		-- 			me.nMoveState == MOVE_STATE.ON_STAND
		-- 			or me.nMoveState == MOVE_STATE.ON_FLOAT
		-- 			or me.nMoveState == MOVE_STATE.ON_SIT
		-- 			or me.nMoveState == MOVE_STATE.ON_FREEZE
		-- 			or me.nMoveState == MOVE_STATE.ON_ENTRAP
		-- 			or me.nMoveState == MOVE_STATE.ON_DEATH
		-- 			or me.nMoveState == MOVE_STATE.ON_AUTO_FLY
		-- 			or me.nMoveState == MOVE_STATE.ON_START_AUTO_FLY
		-- 		) then
		-- 			DoUpload()
		-- 			return 0
		-- 		end
		-- 	end)
		-- end
		if szMode ~= 'silent' then
			local w, h = 270, 180
			local ui = UI.CreateFrame('MY_Serendipity#' .. szKey, {
				w = w, h = h, close = true, text = '', anchor = 'CENTER',
			})
			if szMode == 'auto' then
				ui:Alpha(200)
				ui:Anchor({ x = 0, y = -60, s = 'BOTTOMRIGHT', r = 'BOTTOMRIGHT' })
			end
			ui:Append('Handle', { x = 10, y = (h - 90) / 2, w = w - 20, h = h, valign = 1, halign = 1, handlestyle = 3 })
				:Append('Text', {
					text = (szName == '' and _L['Anonymous'] or szName)
						.. '\n' .. szSerendipity .. ' - ' .. X.FormatTime(dwTime, '%hh:%mm:%ss')
						.. '\n' .. (szReporter == '' and '' or (szReporter .. _L[','])) .. _L['JX3 is pround of you!']
						.. '\n' .. _L['Thanks for your kindness!'],
					fontscale = 1.2,
				})
				:FormatChildrenPos()
			X.DelayCall(10000, function() ui:Remove() end)
			X.DismissNotify(szKey)
		end
	end
	D.GetSerendipityShareName(fnAction, szMode ~= 'manual')
end

function D.OnSerendipity(szName, szSerendipity, nMethod, eStatus, dwTime)
	if X.IsDebugServer() then
		return
	end
	local szKey = szName .. '_' .. szSerendipity .. '_' .. dwTime
	if MY_Serendipity.bAutoShare then
		D.SerendipityShareConfirm(szName, szSerendipity, nMethod, eStatus, dwTime, MY_Serendipity.bSilentMode and 'silent' or 'auto')
	else
		local szXml = GetFormatText(szName == GetClientPlayer().szName
			and _L(eStatus == SERENDIPITY_STATUS.START
				and 'You got %s, would you like to share?'
				or 'You finished %s, would you like to share?', szSerendipity)
			or _L(eStatus == SERENDIPITY_STATUS.START
				and '[%s] got %s, would you like to share?'
				or '[%s] finished %s, would you like to share?', szName, szSerendipity)
		)
		local function fnAction()
			D.SerendipityShareConfirm(szName, szSerendipity, nMethod, eStatus, dwTime, 'manual')
		end
		if MY_Serendipity.bEnable then
			X.CreateNotify({
				szKey = szKey,
				szMsg = szXml,
				fnAction = fnAction,
				bPlaySound = MY_Serendipity.bSound,
				bPopupPreview = MY_Serendipity.bPreview,
			})
		end
		table.insert(SERENDIPITY_LIST, { szKey = szKey, szXml = szXml, fnAction = fnAction })
	end
end

function D.GetSerendipityName(nID)
	for i = 2, g_tTable.Adventure:GetRowCount() do
		local tLine = g_tTable.Adventure:GetRow(i)
		if tLine.dwID == nID then
			return tLine.szName
		end
	end
end

X.RegisterEvent('ON_SERENDIPITY_TRIGGER', 'QIYU', function()
	local me = GetClientPlayer()
	if not me then
		return
	end
	local eStatus = arg1 and SERENDIPITY_STATUS.FINISH or SERENDIPITY_STATUS.START
	D.OnSerendipity(me.szName, D.GetSerendipityName(arg0), SERENDIPITY_METHOD.EVENT_TRIGGER, eStatus, GetCurrentTime())
end)

function D.GetSerendipityInfo(dwTabType, dwIndex)
	if not SERENDIPITY_INFO then
		SERENDIPITY_INFO = X.LoadLUAData(X.PACKET_INFO.FRAMEWORK_ROOT .. 'data/serendipities/{$lang}.jx3dat')
		SERENDIPITY_INFO.name = {}
		for dwTabType, tList in pairs(SERENDIPITY_INFO) do
			if dwTabType ~= 'name' then
				for dwID, p in pairs(tList) do
					if X.IsNumber(dwTabType) then
						local KItemInfo = GetItemInfo(dwTabType, dwID)
						if KItemInfo then
							SERENDIPITY_INFO.name[KItemInfo.szName] = p
						end
					end
					local KItemInfo = GetItemInfo(p[1], p[2])
					if KItemInfo then
						SERENDIPITY_INFO.name[KItemInfo.szName] = p
					end
				end
			end
		end
	end
	local serendipity = SERENDIPITY_INFO[dwTabType] and SERENDIPITY_INFO[dwTabType][dwIndex]
	local eStatus = serendipity and serendipity[3] and SERENDIPITY_STATUS[serendipity[3]]
	if eStatus then
		local iteminfo = GetItemInfo(serendipity[1], serendipity[2])
		if iteminfo then
			return iteminfo.szName, eStatus
		end
	end
end

X.RegisterMsgMonitor('MSG_SYS', 'QIYU', function(szChannel, szMsg, nFont, bRich, r, g, b)
	local me = GetClientPlayer()
	if not me then
		return
	end
	-- local hWnd = Station.GetFocusWindow()
	-- if hWnd and hWnd:GetType() == 'WndEdit' then
	-- 	return
	-- end
	-- 跨服中免打扰
	if IsRemotePlayer(me.dwID) then
		return
	end
	-- 确认是真实系统消息
	if not StringLowerW(szMsg):find('ui/image/minimap/minimap.uitex') then
		return
	end
	-- OutputMessage('MSG_SYS', "<image>path=\"UI/Image/Minimap/Minimap.UITex\" frame=184</image><text>text=\"“一只蠢盾盾”侠士正在为人传功，不经意间触发奇遇【雪山恩仇】！正是：侠心义行，偏遭奇症缠身；雪峰疗伤，却逢绝世奇缘。\" font=10 r=255 g=255 b=0 </text><text>text=\"\\\n\"</text>", true)
	-- “醉戈止战”侠士福缘非浅，触发奇遇【阴阳两界】，此千古奇缘将开启怎样的奇妙际遇，令人神往！
	if bRich then
		szMsg = GetPureText(szMsg)
	end
	szMsg:gsub(_L.ADVENTURE_PATT, function(szName, szSerendipity)
		D.OnSerendipity(szName, szSerendipity, SERENDIPITY_METHOD.MSG_SYS, SERENDIPITY_STATUS.START, GetCurrentTime())
	end)
	-- 恭喜侠士江阙阙在25人英雄会战唐门中获得稀有掉落[夜话·白鹭]！
	szMsg:gsub(_L.ADVENTURE_PATT2, function(szName, szSerendipity)
		if not D.GetSerendipityInfo('name', szSerendipity) then -- 太多了筛选下…
			return
		end
		D.OnSerendipity(szName, szSerendipity, SERENDIPITY_METHOD.MSG_SYS, SERENDIPITY_STATUS.DONE, GetCurrentTime())
	end)
end)

X.RegisterEvent('LOOT_ITEM', function()
	local player = GetPlayer(arg0)
	local item = GetItem(arg1)
	if not player or not item then
		return
	end
	local szSerendipity, eStatus = D.GetSerendipityInfo(item.dwTabType, item.dwIndex)
	if szSerendipity then
		D.OnSerendipity(player.szName, szSerendipity, SERENDIPITY_METHOD.LOOT_ITEM, eStatus, GetCurrentTime())
	end
end)

X.RegisterEvent('QUEST_FINISHED', function()
	local me = GetClientPlayer()
	if not me then
		return
	end
	local szSerendipity, eStatus = D.GetSerendipityInfo('quest', arg0)
	if szSerendipity then
		D.OnSerendipity(me.szName, szSerendipity, SERENDIPITY_METHOD.FINISH_QUEST, eStatus, GetCurrentTime())
	end
end)

-- X.RegisterInit(function()
-- 	X.RegisterTutorial({
-- 		szKey = 'MY_Serendipity',
-- 		szMessage = _L['Would you like to share serendipity?'],
-- 		fnRequire = function()
-- 			return not X.IsDebugServer() and not MY_Serendipity.bEnable
-- 		end,
-- 		{
-- 			szOption = _L['Yes'],
-- 			bDefault = true,
-- 			fnAction = function()
-- 				MY_Serendipity.bEnable = true
-- 				X.RedrawTab(nil)
-- 			end,
-- 		},
-- 		{
-- 			szOption = _L['No'],
-- 			fnAction = function()
-- 				MY_Serendipity.bEnable = false
-- 				X.RedrawTab(nil)
-- 			end,
-- 		},
-- 	})

-- 	X.RegisterTutorial({
-- 		szKey = 'MY_Serendipity_Auto',
-- 		szMessage = _L['Would you like to auto share serendipity?'],
-- 		fnRequire = function()
-- 			return not X.IsDebugServer()
-- 				and MY_Serendipity.bEnable
-- 				and not MY_Serendipity.bAutoShare
-- 		end,
-- 		{
-- 			szOption = _L['Yes'],
-- 			bDefault = true,
-- 			fnAction = function()
-- 				MY_Serendipity.bAutoShare = true
-- 				X.RedrawTab(nil)
-- 			end,
-- 		},
-- 		{
-- 			szOption = _L['No'],
-- 			fnAction = function()
-- 				MY_Serendipity.bAutoShare = false
-- 				X.RedrawTab(nil)
-- 			end,
-- 		},
-- 	})

-- 	X.RegisterTutorial({
-- 		szKey = 'MY_Serendipity_Silent',
-- 		szMessage = _L['Would you like to share serendipity silently?'],
-- 		fnRequire = function()
-- 			return not X.IsDebugServer()
-- 				and MY_Serendipity.bEnable
-- 				and MY_Serendipity.bAutoShare
-- 				and not MY_Serendipity.bSilentMode
-- 		end,
-- 		{
-- 			szOption = _L['Yes'],
-- 			bDefault = true,
-- 			fnAction = function()
-- 				MY_Serendipity.bSilentMode = true
-- 				X.RedrawTab(nil)
-- 			end,
-- 		},
-- 		{
-- 			szOption = _L['No'],
-- 			fnAction = function()
-- 				MY_Serendipity.bSilentMode = false
-- 				X.RedrawTab(nil)
-- 			end,
-- 		},
-- 	})
-- end)


-- Global exports
do
local settings = {
	name = 'MY_Serendipity',
	exports = {
		{
			fields = {
				'bEnable',
				'bSound',
				'bPreview',
				'bAutoShare',
				'bSilentMode',
			},
			root = O,
		},
	},
	imports = {
		{
			fields = {
				'bEnable',
				'bSound',
				'bPreview',
				'bAutoShare',
				'bSilentMode',
			},
			triggers = {
				bEnable = function(_, v)
					if v then
						for i, p in X.ipairs_r(SERENDIPITY_LIST) do
							X.CreateNotify({
								szKey = p.szKey,
								szMsg = p.szXml,
								fnAction = p.fnAction,
								bPlaySound = false,
								bPopupPreview = false,
							})
						end
					else
						for i, p in X.ipairs_r(SERENDIPITY_LIST) do
							X.DismissNotify(p.szKey)
						end
					end
					X.SaveLUAData({'config/show_notify.jx3dat', X.PATH_TYPE.GLOBAL}, v)
				end,
				bSound = function(_, v)
					X.SaveLUAData({'config/serendipity_sound.jx3dat', X.PATH_TYPE.GLOBAL}, v)
				end,
				bPreview = function(_, v)
					X.SaveLUAData({'config/serendipity_preview.jx3dat', X.PATH_TYPE.GLOBAL}, v)
				end,
				bAutoShare = function(_, v)
					X.SaveLUAData({'config/serendipity_autoshare.jx3dat', X.PATH_TYPE.GLOBAL}, v)
				end,
				bSilentMode = function(_, v)
					X.SaveLUAData({'config/serendipity_silentmode.jx3dat', X.PATH_TYPE.GLOBAL}, v)
				end,
			},
			root = O,
		},
	},
}
MY_Serendipity = X.CreateModule(settings)
end

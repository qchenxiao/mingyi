--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : JX3BOX 分页
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
X.RegisterRestriction('MY_TeamTools_JB', { ['*'] = false, classic = true })
--------------------------------------------------------------------------

local PS = {
	-- nPriority = 0,
	-- bWelcome = true,
}

function PS.IsRestricted()
	if X.IsDebugServer() then
		return true
	end
	return X.IsRestricted('MY_TeamTools_JB')
end

function PS.OnPanelActive(wnd)
	local ui = UI(wnd)
	local nPaddingX, nPaddingY, LH = 20, 20, 30
	local nW, nH = ui:Size()
	local nX, nY, nLFY = nPaddingX, nPaddingY, nPaddingY

	-- 角色认证
	nX, nY, nLFY = MY_JBBind.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, LH, nX, nY, nLFY)

	-- 快捷入团
	nX = nPaddingX
	nLFY = nLFY + 5
	nX, nY, nLFY = MY_JBTeam.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, LH, nX, nY, nLFY)

	-- 赛事上报
	nX = nPaddingX
	nLFY = nLFY + 5
	nX, nY, nLFY = MY_JBAchievementRank.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, LH, nX, nY, nLFY)
	nX, nY, nLFY = MY_CombatLogs.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, LH, nX, nY, nLFY)

	-- 赛事投票
	nX = nPaddingX
	nLFY = nLFY + 5
	nX, nY, nLFY = MY_JBEventVote.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, LH, nX, nY, nLFY)

	-- 团队快照
	nX = nPaddingX
	nLFY = nLFY + 5
	nX, nY, nLFY = MY_JBTeamSnapshot.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, LH, nX, nY, nLFY)
end

X.RegisterPanel(_L['Raid'], 'MY_JX3BOX', _L['Team Platform'], 5962, PS)

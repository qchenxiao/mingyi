--------------------------------------------------------
-- This file is part of the JX3 Plugin Project.
-- @desc     : 系统输出
-- @copyright: Copyright (c) 2009 Kingsoft Co., Ltd.
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
local _L = X.LoadLangPack(X.PACKET_INFO.FRAMEWORK_ROOT .. 'lang/lib/')

local THEME_LIST = {
	-- [CONSTANT.MSG_THEME.NORMAL ] = { r = 255, g = 255, b =   0 },
	[CONSTANT.MSG_THEME.ERROR  ] = { r = 255, g =  86, b =  86 },
	[CONSTANT.MSG_THEME.WARNING] = { r = 255, g = 170, b = 170 },
	[CONSTANT.MSG_THEME.SUCCESS] = { r =   0, g = 255, b = 127 },
}

function X.EncodeEchoMsgHeader(szChannel, oData)
	return '<text>text="" addonecho=1 channel=' .. X.XMLEncodeComponent(X.EncodeLUAData(szChannel))
		.. ' data=' .. X.XMLEncodeComponent(X.EncodeLUAData(oData)) .. ' </text>'
end

function X.ContainsEchoMsgHeader(szMsg)
	return string.find(szMsg, '<text>text="" addonecho=1 channel="', nil, true) ~= nil
end

function X.DecodeEchoMsgHeader(aXMLNode)
	if X.XMLIsNode(aXMLNode) then
		if X.XMLGetNodeData(aXMLNode, 'addonecho') then
			local szChannel = X.DecodeLUAData(X.XMLGetNodeData(aXMLNode, 'channel'))
			local oData = X.DecodeLUAData(X.XMLGetNodeData(aXMLNode, 'data'))
			return true, szChannel, oData
		end
	elseif X.IsArray(aXMLNode) then
		for _, node in ipairs(aXMLNode) do
			local bHasInfo, szChannel, oData = X.DecodeEchoMsgHeader(node)
			if bHasInfo then
				return bHasInfo, szChannel, oData
			end
		end
	end
end

local function StringifySysmsgObject(aMsg, oContent, cfg, bTitle, bEcho)
	local cfgContent = setmetatable({}, { __index = cfg })
	if X.IsTable(oContent) then
		cfgContent.rich, cfgContent.wrap = oContent.rich, oContent.wrap
		cfgContent.r, cfgContent.g, cfgContent.b, cfgContent.f = oContent.r, oContent.g, oContent.b, oContent.f
	else
		oContent = {oContent}
	end
	-- 格式化输出正文
	for _, v in ipairs(oContent) do
		local tContent, aPart = setmetatable(X.IsTable(v) and X.Clone(v) or {v}, { __index = cfgContent }), {}
		for _, oPart in ipairs(tContent) do
			table.insert(aPart, tostring(oPart))
		end
		if tContent.rich then
			table.insert(aMsg, table.concat(aPart))
		else
			local szContent = table.concat(aPart, bTitle and '][' or '')
			if szContent ~= '' and bTitle then
				szContent = '[' .. szContent .. ']'
			end
			table.insert(aMsg, GetFormatText(szContent, tContent.f, tContent.r, tContent.g, tContent.b))
		end
	end
	if cfgContent.wrap and not bTitle then
		table.insert(aMsg, GetFormatText('\n', cfgContent.f, cfgContent.r, cfgContent.g, cfgContent.b))
	end
	if bEcho then
		table.insert(aMsg, 1, X.EncodeEchoMsgHeader())
	end
end

local function OutputMessageEx(szType, szTheme, oTitle, oContent, bEcho)
	local aMsg = {}
	-- 字体颜色优先级：单个节点 > 根节点定义 > 预设样式 > 频道设置
	-- 频道设置
	local cfg = {
		rich = false,
		wrap = true,
		f = GetMsgFont(szType),
	}
	cfg.r, cfg.g, cfg.b = GetMsgFontColor(szType)
	-- 预设样式
	local tTheme = szTheme and THEME_LIST[szTheme]
	if tTheme then
		cfg.r = tTheme.r or cfg.r
		cfg.g = tTheme.g or cfg.g
		cfg.b = tTheme.b or cfg.b
		cfg.f = tTheme.f or cfg.f
	end
	-- 根节点定义
	if X.IsTable(oContent) then
		cfg.r = oContent.r or cfg.r
		cfg.g = oContent.g or cfg.g
		cfg.b = oContent.b or cfg.b
		cfg.f = oContent.f or cfg.f
	end

	-- 处理数据
	StringifySysmsgObject(aMsg, oTitle, cfg, true, bEcho)
	StringifySysmsgObject(aMsg, oContent, cfg, false, false)
	OutputMessage(szType, table.concat(aMsg), true)
end

-- 显示本地信息 X.Sysmsg(oTitle, oContent, eTheme)
--   X.Sysmsg({'Error!', wrap = true}, '内容', CONSTANT.MSG_THEME.ERROR)
--   X.Sysmsg({'New message', r = 0, g = 0, b = 0, wrap = true}, '内容')
--   X.Sysmsg({{'New message', r = 0, g = 0, b = 0, rich = false}, wrap = true}, '内容')
--   X.Sysmsg('New message', {'内容', '内容2', r = 0, g = 0, b = 0})
function X.Sysmsg(...)
	local argc, oTitle, oContent, eTheme = select('#', ...), nil, nil, nil
	if argc == 1 then
		oContent = ...
		oTitle, eTheme = nil, nil
	elseif argc == 2 then
		if X.IsNumber(select(2, ...)) then
			oContent, eTheme = ...
			oTitle = nil
		else
			oTitle, oContent = ...
			eTheme = nil
		end
	elseif argc == 3 then
		oTitle, oContent, eTheme = ...
	end
	if not oTitle then
		oTitle = X.PACKET_INFO.SHORT_NAME
	end
	if not X.IsNumber(eTheme) then
		eTheme = CONSTANT.MSG_THEME.NORMAL
	end
	return OutputMessageEx('MSG_SYS', eTheme, oTitle, oContent)
end

-- 显示中央信息 X.Topmsg(oTitle, oContent, eTheme)
--   参见 X.Sysmsg 参数解释
function X.Topmsg(...)
	local argc, oTitle, oContent, eTheme = select('#', ...), nil, nil, nil
	if argc == 1 then
		oContent = ...
		oTitle, eTheme = nil, nil
	elseif argc == 2 then
		if X.IsNumber(select(2, ...)) then
			oContent, eTheme = ...
			oTitle = nil
		else
			oTitle, oContent = ...
			eTheme = nil
		end
	elseif argc == 3 then
		oTitle, oContent, eTheme = ...
	end
	if not oTitle then
		oTitle = CONSTANT.EMPTY_TABLE
	end
	if not X.IsNumber(eTheme) then
		eTheme = CONSTANT.MSG_THEME.NORMAL
	end
	local szType = eTheme == CONSTANT.MSG_THEME.ERROR
		and 'MSG_ANNOUNCE_RED'
		or 'MSG_ANNOUNCE_YELLOW'
	return OutputMessageEx(szType, eTheme, oTitle, oContent)
end

function X.Systopmsg(...)
	X.Topmsg(...)
	X.Sysmsg(...)
end

-- 输出一条密聊信息
function X.OutputWhisper(szMsg, szHead)
	szHead = szHead or X.PACKET_INFO.SHORT_NAME
	OutputMessage('MSG_WHISPER', '[' .. szHead .. ']' .. g_tStrings.STR_TALK_HEAD_WHISPER .. szMsg .. '\n')
	PlaySound(SOUND.UI_SOUND, g_sound.Whisper)
end

-- Debug输出
-- (void)X.Debug(szTitle, oContent, nLevel)
-- szTitle  Debug头
-- oContent Debug信息
-- nLevel   Debug级别[低于当前设置值将不会输出]
function X.Debug(...)
	local argc, oTitle, oContent, nLevel, szTitle, szContent, eTheme = select('#', ...), nil, nil, nil, nil, nil, nil
	if argc == 1 then
		oContent = ...
		oTitle, nLevel = nil, nil
	elseif argc == 2 then
		if X.IsNumber(select(2, ...)) then
			oContent, nLevel = ...
			oTitle = nil
		else
			oTitle, oContent = ...
			nLevel = nil
		end
	elseif argc == 3 then
		oTitle, oContent, nLevel = ...
	end
	if not oTitle then
		oTitle = X.NSFormatString('{$NS}_DEBUG')
	end
	if not X.IsNumber(nLevel) then
		nLevel = X.DEBUG_LEVEL.WARNING
	end
	if X.IsTable(oTitle) then
		szTitle = table.concat(oTitle, '\n')
	else
		szTitle = tostring(oTitle)
	end
	if X.IsTable(oContent) then
		szContent = table.concat(oContent, '\n')
	else
		szContent = tostring(oContent)
	end
	if nLevel >= X.PACKET_INFO.DEBUG_LEVEL then
		Log('[DEBUG_LEVEL][LEVEL_' .. nLevel .. '][' .. szTitle .. ']' .. szContent)
		if nLevel == X.DEBUG_LEVEL.LOG then
			eTheme = CONSTANT.MSG_THEME.SUCCESS
		elseif nLevel == X.DEBUG_LEVEL.WARNING then
			eTheme = CONSTANT.MSG_THEME.WARNING
		elseif nLevel == X.DEBUG_LEVEL.ERROR then
			eTheme = CONSTANT.MSG_THEME.ERROR
		else
			eTheme = CONSTANT.MSG_THEME.NORMAL
		end
		return OutputMessageEx('MSG_SYS', eTheme, szTitle, oContent, true)
	end
	if nLevel >= X.PACKET_INFO.DELOG_LEVEL then
		Log('[DEBUG_LEVEL][LEVEL_' .. nLevel .. '][' .. szTitle .. ']' .. szContent)
	end
end

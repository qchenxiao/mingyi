--------------------------------------------------------
-- This file is part of the JX3 Plugin Project.
-- @desc     : 用户配置
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
---------------------------------------------------------------------------------------------------

local EncodeByteData = X.GetGameAPI('EncodeByteData')
local DecodeByteData = X.GetGameAPI('DecodeByteData')

-- Save & Load Lua Data
-- ##################################################################################################
--         #       #             #                           #
--     #   #   #   #             #     # # # # # #           #               # # # # # #
--         #       #             #     #         #   # # # # # # # # # # #     #     #   # # # #
--   # # # # # #   # # # #   # # # #   # # # # # #         #                   #     #     #   #
--       # #     #     #         #     #     #           #     # # # # #       # # # #     #   #
--     #   # #     #   #         #     # # # # # #       #           #         #     #     #   #
--   #     #   #   #   #         # #   #     #         # #         #           # # # #     #   #
--       #         #   #     # # #     # # # # # #   #   #   # # # # # # #     #     #     #   #
--   # # # # #     #   #         #     # #       #       #         #           #     # #     #
--     #     #       #           #   #   #       #       #         #         # # # # #       #
--       # #       #   #         #   #   # # # # #       #         #                 #     #   #
--   # #     #   #       #     # # #     #       #       #       # #                 #   #       #
-- ##################################################################################################
if IsLocalFileExist(X.PACKET_INFO.ROOT .. '@DATA/') then
	CPath.Move(X.PACKET_INFO.ROOT .. '@DATA/', X.PACKET_INFO.DATA_ROOT)
end

-- 格式化数据文件路径（替换{$uid}、{$lang}、{$server}以及补全相对路径）
-- (string) X.GetLUADataPath(oFilePath)
--   当路径为绝对路径时(以斜杠开头)不作处理
--   当路径为相对路径时 相对于插件`{NS}#DATA`目录
--   可以传入表{szPath, ePathType}
local PATH_TYPE_MOVE_STATE = {
	[X.PATH_TYPE.GLOBAL] = 'PENDING',
	[X.PATH_TYPE.ROLE] = 'PENDING',
	[X.PATH_TYPE.SERVER] = 'PENDING',
}
function X.FormatPath(oFilePath, tParams)
	if not tParams then
		tParams = {}
	end
	local szFilePath, ePathType
	if type(oFilePath) == 'table' then
		szFilePath, ePathType = unpack(oFilePath)
	else
		szFilePath, ePathType = oFilePath, X.PATH_TYPE.NORMAL
	end
	-- 兼容旧版数据位置
	if PATH_TYPE_MOVE_STATE[ePathType] == 'PENDING' then
		PATH_TYPE_MOVE_STATE[ePathType] = nil
		local szPath = X.FormatPath({'', ePathType})
		if not IsLocalFileExist(szPath) then
			local szOriginPath
			if ePathType == X.PATH_TYPE.GLOBAL then
				szOriginPath = X.FormatPath({'!all-users@{$lang}/', X.PATH_TYPE.DATA})
			elseif ePathType == X.PATH_TYPE.ROLE then
				szOriginPath = X.FormatPath({'{$uid}@{$lang}/', X.PATH_TYPE.DATA})
			elseif ePathType == X.PATH_TYPE.SERVER then
				szOriginPath = X.FormatPath({'#{$relserver}@{$lang}/', X.PATH_TYPE.DATA})
			end
			if IsLocalFileExist(szOriginPath) then
				CPath.Move(szOriginPath, szPath)
			end
		end
	end
	-- Unified the directory separator
	szFilePath = string.gsub(szFilePath, '\\', '/')
	-- if it's relative path then complete path with '/{NS}#DATA/'
	if szFilePath:sub(2, 3) ~= ':/' then
		if ePathType == X.PATH_TYPE.DATA then
			szFilePath = X.PACKET_INFO.DATA_ROOT .. szFilePath
		elseif ePathType == X.PATH_TYPE.GLOBAL then
			szFilePath = X.PACKET_INFO.DATA_ROOT .. '!all-users@{$edition}/' .. szFilePath
		elseif ePathType == X.PATH_TYPE.ROLE then
			szFilePath = X.PACKET_INFO.DATA_ROOT .. '{$uid}@{$edition}/' .. szFilePath
		elseif ePathType == X.PATH_TYPE.SERVER then
			szFilePath = X.PACKET_INFO.DATA_ROOT .. '#{$relserver}@{$edition}/' .. szFilePath
		end
	end
	-- if exist {$uid} then add user role identity
	if string.find(szFilePath, '{$uid}', nil, true) then
		szFilePath = szFilePath:gsub('{%$uid}', tParams['uid'] or X.GetClientUUID())
	end
	-- if exist {$name} then add user role identity
	if string.find(szFilePath, '{$name}', nil, true) then
		szFilePath = szFilePath:gsub('{%$name}', tParams['name'] or X.GetClientInfo().szName or X.GetClientUUID())
	end
	-- if exist {$lang} then add language identity
	if string.find(szFilePath, '{$lang}', nil, true) then
		szFilePath = szFilePath:gsub('{%$lang}', tParams['lang'] or GLOBAL.GAME_LANG)
	end
	-- if exist {$edition} then add edition identity
	if string.find(szFilePath, '{$edition}', nil, true) then
		szFilePath = szFilePath:gsub('{%$edition}', tParams['edition'] or GLOBAL.GAME_EDITION)
	end
	-- if exist {$branch} then add branch identity
	if string.find(szFilePath, '{$branch}', nil, true) then
		szFilePath = szFilePath:gsub('{%$branch}', tParams['branch'] or GLOBAL.GAME_BRANCH)
	end
	-- if exist {$version} then add version identity
	if string.find(szFilePath, '{$version}', nil, true) then
		szFilePath = szFilePath:gsub('{%$version}', tParams['version'] or GLOBAL.GAME_VERSION)
	end
	-- if exist {$date} then add date identity
	if string.find(szFilePath, '{$date}', nil, true) then
		szFilePath = szFilePath:gsub('{%$date}', tParams['date'] or X.FormatTime(GetCurrentTime(), '%yyyy%MM%dd'))
	end
	-- if exist {$server} then add server identity
	if string.find(szFilePath, '{$server}', nil, true) then
		szFilePath = szFilePath:gsub('{%$server}', tParams['server'] or ((X.GetServer()):gsub('[/\\|:%*%?"<>]', '')))
	end
	-- if exist {$relserver} then add relserver identity
	if string.find(szFilePath, '{$relserver}', nil, true) then
		szFilePath = szFilePath:gsub('{%$relserver}', tParams['relserver'] or ((X.GetRealServer()):gsub('[/\\|:%*%?"<>]', '')))
	end
	local rootPath = GetRootPath():gsub('\\', '/')
	if szFilePath:find(rootPath) == 1 then
		szFilePath = szFilePath:gsub(rootPath, '.')
	end
	return szFilePath
end

function X.GetRelativePath(oPath, oRoot)
	local szPath = X.FormatPath(oPath):gsub('^%./', '')
	local szRoot = X.FormatPath(oRoot):gsub('^%./', '')
	local szRootPath = GetRootPath():gsub('\\', '/')
	if szPath:sub(2, 2) ~= ':' then
		szPath = X.ConcatPath(szRootPath, szPath)
	end
	if szRoot:sub(2, 2) ~= ':' then
		szRoot = X.ConcatPath(szRootPath, szRoot)
	end
	szRoot = szRoot:gsub('/$', '') .. '/'
	if wstring.find(szPath:lower(), szRoot:lower()) ~= 1 then
		return
	end
	return szPath:sub(#szRoot + 1)
end

function X.GetAbsolutePath(oPath)
	local szPath = X.FormatPath(oPath)
	if szPath:sub(2, 2) == ':' then
		return szPath
	end
	return X.NormalizePath(GetRootPath():gsub('\\', '/') .. '/' .. X.GetRelativePath(szPath, {'', X.PATH_TYPE.NORMAL}):gsub('^[./\\]*', ''))
end

function X.GetLUADataPath(oFilePath)
	local szFilePath = X.FormatPath(oFilePath)
	-- ensure has file name
	if string.sub(szFilePath, -1) == '/' then
		szFilePath = szFilePath .. 'data'
	end
	-- ensure file ext name
	if string.sub(szFilePath, -7):lower() ~= '.jx3dat' then
		szFilePath = szFilePath .. '.jx3dat'
	end
	return szFilePath
end

function X.ConcatPath(...)
	local aPath = {...}
	local szPath = ''
	for _, s in ipairs(aPath) do
		s = tostring(s):gsub('^[\\/]+', '')
		if s ~= '' then
			szPath = szPath:gsub('[\\/]+$', '')
			if szPath ~= '' then
				szPath = szPath .. '/'
			end
			szPath = szPath .. s
		end
	end
	return szPath
end

-- 替换目录分隔符为反斜杠，并且删除目录中的.\与..\
function X.NormalizePath(szPath)
	szPath = szPath:gsub('/', '\\')
	szPath = szPath:gsub('\\%.\\', '\\')
	local nPos1, nPos2
	while true do
		nPos1, nPos2 = szPath:find('[^\\]*\\%.%.\\')
		if not nPos1 then
			break
		end
		szPath = szPath:sub(1, nPos1 - 1) .. szPath:sub(nPos2 + 1)
	end
	return szPath
end

-- 获取父层目录 注意文件和文件夹获取父层的区别
function X.GetParentPath(szPath)
	return X.NormalizePath(szPath):gsub('/[^/]*$', '')
end

function X.OpenFolder(szPath)
	if _G.OpenFolder then
		_G.OpenFolder(szPath)
	end
end

function X.IsURL(szURL)
	return szURL:sub(1, 8):lower() == 'https://' or szURL:gsub(1, 7):lower() == 'http://'
end

-- 插件数据存储默认密钥
local GetLUADataPathPassphrase
do
local function GetPassphrase(nSeed, nLen)
	local a = {}
	local b, c = 0x20, 0x7e - 0x20 + 1
	for i = 1, nLen do
		table.insert(a, ((i + nSeed) % 256 * (2 * i + nSeed) % 32) % c + b)
	end
	return string.char(unpack(a))
end
local szDataRoot = StringLowerW(X.FormatPath({'', X.PATH_TYPE.DATA}))
local szPassphrase = GetPassphrase(666, 233)
local CACHE = {}
function GetLUADataPathPassphrase(szPath)
	-- 忽略大小写
	szPath = StringLowerW(szPath)
	-- 去除目录前缀
	if szPath:sub(1, szDataRoot:len()) ~= szDataRoot then
		return
	end
	szPath = szPath:sub(#szDataRoot + 1)
	-- 拆分数据分类地址
	local nPos = wstring.find(szPath, '/')
	if not nPos or nPos == 1 then
		return
	end
	local szDomain = szPath:sub(1, nPos)
	szPath = szPath:sub(nPos + 1)
	-- 过滤不需要加密的地址
	local nPos = wstring.find(szPath, '/')
	if nPos then
		if szPath:sub(1, nPos - 1) == 'export' then
			return
		end
	end
	-- 获取或创建密钥
	local bNew = false
	if not CACHE[szDomain] or not CACHE[szDomain][szPath] then
		local szFilePath = szDataRoot .. szDomain .. '/manifest.jx3dat'
		local tManifest = LoadLUAData(szFilePath, { passphrase = szPassphrase }) or {}
		-- 临时大小写兼容逻辑
		CACHE[szDomain] = {}
		for szPath, v in pairs(tManifest) do
			CACHE[szDomain][StringLowerW(szPath)] = v
		end
		if not CACHE[szDomain][szPath] then
			bNew = true
			CACHE[szDomain][szPath] = X.GetUUID():gsub('-', '')
			SaveLUAData(szFilePath, CACHE[szDomain], { passphrase = szPassphrase })
		end
	end
	return CACHE[szDomain][szPath], bNew
end
end

-- 获取插件软唯一标示符
do
local GUID
function X.GetClientGUID()
	if not GUID then
		local szRandom = GetLUADataPathPassphrase(X.GetLUADataPath({'GUIDv2', X.PATH_TYPE.GLOBAL}))
		local szPrefix = MD5(szRandom):sub(1, 4)
		local nCSW, nCSH = GetSystemCScreen()
		local szCS = MD5(nCSW .. ',' .. nCSH):sub(1, 4)
		GUID = ('%s%X%s'):format(szPrefix, GetStringCRC(szRandom), szCS)
	end
	return GUID
end
end

-- 保存数据文件
function X.SaveLUAData(oFilePath, oData, tConfig)
	--[[#DEBUG BEGIN]]
	local nStartTick = GetTickCount()
	--[[#DEBUG END]]
	local config, szPassphrase, bNew = X.Clone(tConfig) or {}, nil, nil
	local szFilePath = X.GetLUADataPath(oFilePath)
	if X.IsNil(config.passphrase) then
		config.passphrase = GetLUADataPathPassphrase(szFilePath)
	end
	local data = SaveLUAData(szFilePath, oData, config)
	--[[#DEBUG BEGIN]]
	nStartTick = GetTickCount() - nStartTick
	if nStartTick > 5 then
		X.Debug('PMTool', _L('%s saved during %dms.', szFilePath, nStartTick), X.DEBUG_LEVEL.PMLOG)
	end
	--[[#DEBUG END]]
	return data
end

-- 加载数据文件
function X.LoadLUAData(oFilePath, tConfig)
	--[[#DEBUG BEGIN]]
	local nStartTick = GetTickCount()
	--[[#DEBUG END]]
	local config, szPassphrase, bNew = X.Clone(tConfig) or {}, nil, nil
	local szFilePath = X.GetLUADataPath(oFilePath)
	if X.IsNil(config.passphrase) then
		szPassphrase, bNew = GetLUADataPathPassphrase(szFilePath)
		if not bNew then
			config.passphrase = szPassphrase
		end
	end
	local data = LoadLUAData(szFilePath, config)
	if bNew and data then
		config.passphrase = szPassphrase
		SaveLUAData(szFilePath, data, config)
	end
	--[[#DEBUG BEGIN]]
	nStartTick = GetTickCount() - nStartTick
	if nStartTick > 5 then
		X.Debug('PMTool', _L('%s loaded during %dms.', szFilePath, nStartTick), X.DEBUG_LEVEL.PMLOG)
	end
	--[[#DEBUG END]]
	return data
end

-----------------------------------------------
-- 计算数据散列值
-----------------------------------------------
do
local function TableSorterK(a, b) return a.k > b.k end
local function GetLUADataHashSYNC(data)
	local szType = type(data)
	if szType == 'table' then
		local aChild = {}
		for k, v in pairs(data) do
			table.insert(aChild, { k = GetLUADataHashSYNC(k), v = GetLUADataHashSYNC(v) })
		end
		table.sort(aChild, TableSorterK)
		for i, v in ipairs(aChild) do
			aChild[i] = v.k .. ':' .. v.v
		end
		return GetLUADataHashSYNC('{}::' .. table.concat(aChild, ';'))
	end
	return tostring(GetStringCRC(szType .. ':' .. tostring(data)))
end

local function GetLUADataHash(data, fnAction)
	if not fnAction then
		return GetLUADataHashSYNC(data)
	end

	local __stack__ = {}
	local __retvals__ = {}

	local function __new_context__(continuation)
		local prev = __stack__[#__stack__]
		local current = {
			continuation = continuation,
			arguments = prev and prev.arguments,
			state = {},
			context = setmetatable({}, { __index = prev and prev.context }),
		}
		table.insert(__stack__, current)
		return current
	end

	local function __exit_context__()
		table.remove(__stack__)
	end

	local function __call__(...)
		table.insert(__stack__, {
			continuation = '0',
			arguments = {...},
			state = {},
			context = {},
		})
	end

	local function __return__(...)
		__exit_context__()
		__retvals__ = {...}
	end

	__call__(data)

	local current, continuation, arguments, state, context, timer

	timer = X.BreatheCall(function()
		local nTime = GetTime()

		while #__stack__ > 0 do
			current = __stack__[#__stack__]
			continuation = current.continuation
			arguments = current.arguments
			state = current.state
			context = current.context

			if continuation == '0' then
				if type(arguments[1]) == 'table' then
					__new_context__('1')
				else
					__return__(tostring(GetStringCRC(type(arguments[1]) .. ':' .. tostring(arguments[1]))))
				end
			elseif continuation == '1' then
				context.aChild = {}
				current.continuation = '1.1'
			elseif continuation == '1.1' then
				state.k = next(arguments[1], state.k)
				if state.k ~= nil then
					local nxt = __new_context__('2')
					nxt.context.k = state.k
					nxt.context.v = arguments[1][state.k]
				else
					table.sort(context.aChild, TableSorterK)
					for i, v in ipairs(context.aChild) do
						context.aChild[i] = v.k .. ':' .. v.v
					end
					__call__('{}::' .. table.concat(context.aChild, ';'))
					current.continuation = '1.2'
				end
			elseif continuation == '1.2' then
				__return__(unpack(__retvals__))
				__return__(unpack(__retvals__))
			elseif continuation == '2' then
				__call__(context.k)
				current.continuation = '2.1'
			elseif continuation == '2.1' then
				context.ks = __retvals__[1]
				__call__(context.v)
				current.continuation = '2.2'
			elseif continuation == '2.2' then
				context.vs = __retvals__[1]
				table.insert(context.aChild, { k = context.ks, v = context.vs })
				__exit_context__()
			end

			if GetTime() - nTime > 100 then
				return
			end
		end

		X.BreatheCall(timer, false)
		X.SafeCall(fnAction, unpack(__retvals__))
	end)
end
X.GetLUADataHash = GetLUADataHash
end

do
---------------------------------------------------------------------------------------------
-- 用户配置项
---------------------------------------------------------------------------------------------
local USER_SETTINGS_EVENT = { szName = 'UserSettings' }
local CommonEventFirer = X.CommonEventFirer
local CommonEventRegister = X.CommonEventRegister

function X.RegisterUserSettingsUpdate(...)
	return CommonEventRegister(USER_SETTINGS_EVENT, ...)
end

local DATABASE_TYPE_LIST = { X.PATH_TYPE.ROLE, X.PATH_TYPE.SERVER, X.PATH_TYPE.GLOBAL }
local DATABASE_TYPE_PRESET_FILE = {
	[X.PATH_TYPE.ROLE] = 'role',
	[X.PATH_TYPE.SERVER] = 'server',
	[X.PATH_TYPE.GLOBAL] = 'global',
}
local DATABASE_INSTANCE = {}
local USER_SETTINGS_INFO = {}
local USER_SETTINGS_LIST = {}
local DATA_CACHE = {}
local DATA_CACHE_LEAF_FLAG = {}
local FLUSH_TIME = 0
local DATABASE_CONNECTION_ESTABLISHED = false

local function SetInstanceInfoData(inst, info, data, version)
	local db = info.bUserData
		and inst.pUserDataDB
		or inst.pSettingsDB
	if db then
		--[[#DEBUG BEGIN]]
		local nStartTick = GetTime()
		--[[#DEBUG END]]
		db:Set(info.szDataKey, { d = data, v = version })
		--[[#DEBUG BEGIN]]
		X.Debug(X.PACKET_INFO.NAME_SPACE, _L('User settings %s saved during %dms.', info.szDataKey, GetTickCount() - nStartTick), X.DEBUG_LEVEL.PMLOG)
		--[[#DEBUG END]]
	end
end

local function GetInstanceInfoData(inst, info)
	local db = info.bUserData
		and inst.pUserDataDB
		or inst.pSettingsDB
	--[[#DEBUG BEGIN]]
	local nStartTick = GetTime()
	--[[#DEBUG END]]
	local res = db and db:Get(info.szDataKey)
	--[[#DEBUG BEGIN]]
	X.Debug(X.PACKET_INFO.NAME_SPACE, _L('User settings %s loaded during %dms.', info.szDataKey, GetTickCount() - nStartTick), X.DEBUG_LEVEL.PMLOG)
	--[[#DEBUG END]]
	if res then
		return res
	end
	return nil
end

local function DeleteInstanceInfoData(inst, info)
	local db = info.bUserData
		and inst.pUserDataDB
		or inst.pSettingsDB
	if db then
		db:Delete(info.szDataKey)
	end
end

function X.ConnectUserSettingsDB()
	if DATABASE_CONNECTION_ESTABLISHED then
		return
	end
	local szID, szDBPresetRoot, szUDBPresetRoot = X.GetUserSettingsPresetID(), nil, nil
	if not X.IsEmpty(szID) then
		szDBPresetRoot = X.FormatPath({'config/settings/' .. szID .. '/', X.PATH_TYPE.GLOBAL})
		szUDBPresetRoot = X.FormatPath({'userdata/settings/' .. szID .. '/', X.PATH_TYPE.GLOBAL})
		CPath.MakeDir(szDBPresetRoot)
		CPath.MakeDir(szUDBPresetRoot)
	end
	for _, ePathType in ipairs(DATABASE_TYPE_LIST) do
		if not DATABASE_INSTANCE[ePathType] then
			local pSettingsDB = X.NoSQLiteConnect(szDBPresetRoot
				and (szDBPresetRoot .. DATABASE_TYPE_PRESET_FILE[ePathType] .. '.db')
				or X.FormatPath({'config/settings.db', ePathType}))
			local pUserDataDB = X.NoSQLiteConnect(X.FormatPath({'userdata/userdata.db', ePathType}))
			if not pSettingsDB then
				X.Debug(X.PACKET_INFO.NAME_SPACE, 'Connect user settings database failed!!! ' .. ePathType, X.DEBUG_LEVEL.ERROR)
			end
			if not pUserDataDB then
				X.Debug(X.PACKET_INFO.NAME_SPACE, 'Connect userdata database failed!!! ' .. ePathType, X.DEBUG_LEVEL.ERROR)
			end
			DATABASE_INSTANCE[ePathType] = {
				pSettingsDB = pSettingsDB,
				-- bSettingsDBCommit = false,
				pUserDataDB = pUserDataDB,
				-- bUserDataDBCommit = false,
			}
		end
	end
	DATABASE_CONNECTION_ESTABLISHED = true
	CommonEventFirer(USER_SETTINGS_EVENT, '@@INIT@@')
end

function X.ReleaseUserSettingsDB()
	CommonEventFirer(USER_SETTINGS_EVENT, '@@UNINIT@@')
	for _, ePathType in ipairs(DATABASE_TYPE_LIST) do
		local inst = DATABASE_INSTANCE[ePathType]
		if inst then
			if inst.pSettingsDB then
				X.NoSQLiteDisconnect(inst.pSettingsDB)
			end
			if inst.pUserDataDB then
				X.NoSQLiteDisconnect(inst.pUserDataDB)
			end
			DATABASE_INSTANCE[ePathType] = nil
		end
	end
	DATA_CACHE = {}
	DATABASE_CONNECTION_ESTABLISHED = false
end

function X.FlushUserSettingsDB()
	-- for _, ePathType in ipairs(DATABASE_TYPE_LIST) do
	-- 	local inst = DATABASE_INSTANCE[ePathType]
	-- 	if inst then
	-- 		if inst.bSettingsDBCommit and inst.pSettingsDB and inst.pSettingsDB.Commit then
	-- 			inst.pSettingsDB:Commit()
	-- 			inst.bSettingsDBCommit = false
	-- 		end
	-- 		if inst.bUserDataDBCommit and inst.pUserDataDB and inst.pUserDataDB.Commit then
	-- 			inst.pUserDataDB:Commit()
	-- 			inst.bUserDataDBCommit = false
	-- 		end
	-- 	end
	-- end
end

function X.GetUserSettingsPresetID(bDefault)
	local szPath = X.FormatPath({'config/usersettings-preset.jx3dat', bDefault and X.PATH_TYPE.GLOBAL or X.PATH_TYPE.ROLE})
	if not bDefault and not IsLocalFileExist(szPath) then
		return X.GetUserSettingsPresetID(true)
	end
	local szID = X.LoadLUAData(szPath)
	if X.IsString(szID) and not szID:find('[/?*:|\\<>]') then
		return szID
	end
	return ''
end

function X.SetUserSettingsPresetID(szID, bDefault)
	if szID then
		if szID:find('[/?*:|\\<>]') then
			return _L['User settings preset id cannot contains special character (/?*:|\\<>).']
		end
		szID = wstring.gsub(szID, '^%s+', '')
		szID = wstring.gsub(szID, '%s+$', '')
	end
	if X.IsEmpty(szID) then
		szID = ''
	end
	if szID == X.GetUserSettingsPresetID(bDefault) then
		return
	end
	local szCurrentID = X.GetUserSettingsPresetID()
	X.SaveLUAData({'config/usersettings-preset.jx3dat', bDefault and X.PATH_TYPE.GLOBAL or X.PATH_TYPE.ROLE}, szID)
	if szCurrentID == X.GetUserSettingsPresetID() then
		return
	end
	if DATABASE_CONNECTION_ESTABLISHED then
		X.ReleaseUserSettingsDB()
		X.ConnectUserSettingsDB()
	end
	DATA_CACHE = {}
end

function X.GetUserSettingsPresetList()
	return CPath.GetFolderList(X.FormatPath({'userdata/settings/', X.PATH_TYPE.GLOBAL}))
end

function X.RemoveUserSettingsPreset(szID)
	CPath.DelDir(X.FormatPath({'userdata/settings/' .. szID .. '/', X.PATH_TYPE.GLOBAL}))
end

-- 注册单个用户配置项
-- @param {string} szKey 配置项全局唯一键
-- @param {table} tOption 自定义配置项
--   {PATH_TYPE} tOption.ePathType 配置项保存位置（当前角色、当前服务器、全局）
--   {string} tOption.szDataKey 配置项入库时的键值，一般不需要手动指定，默认与配置项全局键值一致
--   {string} tOption.bUserData 配置项是否为角色数据项，为真将忽略预设方案重定向，禁止共用
--   {string} tOption.szGroup 配置项分组组标题，用于导入导出显示，禁止导入导出请留空
--   {string} tOption.szLabel 配置标题，用于导入导出显示，禁止导入导出请留空
--   {string} tOption.szVersion 数据版本号，加载数据时会丢弃版本不一致的数据
--   {any} tOption.xDefaultValue 数据默认值
--   {schema} tOption.xSchema 数据类型约束对象，通过 Schema 库生成
--   {boolean} tOption.bDataSet 是否为配置项组（如用户多套自定义偏好），配置项组在读写时需要额外传入一个组下配置项唯一键值（即多套自定义偏好中某一项的名字）
--   {table} tOption.tDataSetDefaultValue 数据默认值（仅当 bDataSet 为真时生效，用于设置配置项组不同默认值）
function X.RegisterUserSettings(szKey, tOption)
	local ePathType, szDataKey, bUserData, szGroup, szLabel, szVersion, xDefaultValue, xSchema, bDataSet, tDataSetDefaultValue
	if X.IsTable(tOption) then
		ePathType = tOption.ePathType
		szDataKey = tOption.szDataKey
		bUserData = tOption.bUserData
		szGroup = tOption.szGroup
		szLabel = tOption.szLabel
		szVersion = tOption.szVersion
		xDefaultValue = tOption.xDefaultValue
		xSchema = tOption.xSchema
		bDataSet = tOption.bDataSet
		tDataSetDefaultValue = tOption.tDataSetDefaultValue
	end
	if not ePathType then
		ePathType = X.PATH_TYPE.ROLE
	end
	if not szDataKey then
		szDataKey = szKey
	end
	if not szVersion then
		szVersion = ''
	end
	local szErrHeader = 'RegisterUserSettings KEY(' .. X.EncodeLUAData(szKey) .. '): '
	assert(X.IsString(szKey) and #szKey > 0, szErrHeader .. '`Key` should be a non-empty string value.')
	assert(not USER_SETTINGS_INFO[szKey], szErrHeader .. 'duplicated `Key` found.')
	assert(X.IsString(szDataKey) and #szDataKey > 0, szErrHeader .. '`DataKey` should be a non-empty string value.')
	assert(not lodash.some(USER_SETTINGS_INFO, function(p) return p.szDataKey == szDataKey and p.ePathType == ePathType end), szErrHeader .. 'duplicated `DataKey` + `PathType` found.')
	assert(lodash.includes(DATABASE_TYPE_LIST, ePathType), szErrHeader .. '`PathType` value is not valid.')
	assert(X.IsNil(szGroup) or (X.IsString(szGroup) and #szGroup > 0), szErrHeader .. '`Group` should be nil or a non-empty string value.')
	assert(X.IsNil(szLabel) or (X.IsString(szLabel) and #szLabel > 0), szErrHeader .. '`Label` should be nil or a non-empty string value.')
	assert(X.IsString(szVersion), szErrHeader .. '`Version` should be a string value.')
	if xSchema then
		local errs = X.Schema.CheckSchema(xDefaultValue, xSchema)
		if errs then
			local aErrmsgs = {}
			for i, err in ipairs(errs) do
				table.insert(aErrmsgs, '  ' .. i .. '. ' .. err.message)
			end
			assert(false, szErrHeader .. '`DefaultValue` cannot pass `Schema` check.' .. '\n' .. table.concat(aErrmsgs, '\n'))
		end
		if bDataSet then
			tDataSetDefaultValue = X.IsTable(tDataSetDefaultValue)
				and X.Clone(tDataSetDefaultValue)
				or {}
			local errs = X.Schema.CheckSchema(tDataSetDefaultValue, X.Schema.Map(X.Schema.Any, xSchema))
			if errs then
				local aErrmsgs = {}
				for i, err in ipairs(errs) do
					table.insert(aErrmsgs, '  ' .. i .. '. ' .. err.message)
				end
				assert(false, szErrHeader .. '`DataSetDefaultValue` cannot pass `Schema` check.' .. '\n' .. table.concat(aErrmsgs, '\n'))
			end
		end
	end
	local tInfo = {
		szKey = szKey,
		ePathType = ePathType,
		bUserData = bUserData,
		szDataKey = szDataKey,
		szGroup = szGroup,
		szLabel = szLabel,
		szVersion = szVersion,
		xDefaultValue = xDefaultValue,
		xSchema = xSchema,
		bDataSet = bDataSet,
		tDataSetDefaultValue = tDataSetDefaultValue,
	}
	USER_SETTINGS_INFO[szKey] = tInfo
	table.insert(USER_SETTINGS_LIST, tInfo)
end

function X.GetRegisterUserSettingsList()
	return X.Clone(USER_SETTINGS_LIST)
end

function X.ExportUserSettings(aKey)
	local tKvp = {}
	for _, szKey in ipairs(aKey) do
		local info = USER_SETTINGS_INFO[szKey]
		local inst = info and DATABASE_INSTANCE[info.ePathType]
		if inst then
			tKvp[szKey] = GetInstanceInfoData(inst, info)
		end
	end
	return tKvp
end

function X.ImportUserSettings(tKvp)
	local nSuccess = 0
	for szKey, xValue in pairs(tKvp) do
		local info = X.IsTable(xValue) and USER_SETTINGS_INFO[szKey]
		local inst = info and DATABASE_INSTANCE[info.ePathType]
		if inst then
			SetInstanceInfoData(inst, info, xValue.d, xValue.v)
			nSuccess = nSuccess + 1
			DATA_CACHE[szKey] = nil
		end
	end
	CommonEventFirer(USER_SETTINGS_EVENT, '@@INIT@@')
	return nSuccess
end

-- 获取用户配置项值
-- @param {string} szKey 配置项全局唯一键
-- @param {string} szDataSetKey 配置项组（如用户多套自定义偏好）唯一键，当且仅当 szKey 对应注册项携带 bDataSet 标记位时有效
-- @return 值
function X.GetUserSettings(szKey, ...)
	-- 缓存加速
	local cache = DATA_CACHE
	for _, k in ipairs({szKey, ...}) do
		if X.IsTable(cache) then
			cache = cache[k]
		end
		if not X.IsTable(cache) then
			cache = nil
			break
		end
		if cache[1] == DATA_CACHE_LEAF_FLAG then
			return cache[2]
		end
	end
	-- 参数检查
	local nParameter = select('#', ...) + 1
	local szErrHeader = 'GetUserSettings KEY(' .. X.EncodeLUAData(szKey) .. '): '
	local info = USER_SETTINGS_INFO[szKey]
	assert(info, szErrHeader ..'`Key` has not been registered.')
	local inst = DATABASE_INSTANCE[info.ePathType]
	assert(inst, szErrHeader ..'Database not connected.')
	local szDataSetKey
	if info.bDataSet then
		assert(nParameter == 2, szErrHeader .. '2 parameters expected, got ' .. nParameter)
		szDataSetKey = ...
		assert(X.IsString(szDataSetKey) or X.IsNumber(szDataSetKey), szErrHeader ..'`DataSetKey` should be a string or number value.')
	else
		assert(nParameter == 1, szErrHeader .. '1 parameters expected, got ' .. nParameter)
	end
	-- 读数据库
	local res, bData = GetInstanceInfoData(inst, info), false
	if X.IsTable(res) and res.v == info.szVersion then
		local data = res.d
		if info.bDataSet then
			if X.IsTable(data) then
				data = data[szDataSetKey]
			else
				data = nil
			end
		end
		if not info.xSchema or not X.Schema.CheckSchema(data, info.xSchema) then
			bData = true
			res = data
		end
	end
	-- 默认值
	if not bData then
		if info.bDataSet then
			res = info.tDataSetDefaultValue[szDataSetKey]
			if X.IsNil(res) then
				res = info.xDefaultValue
			end
		else
			res = info.xDefaultValue
		end
		res = X.Clone(res)
	end
	-- 缓存
	if info.bDataSet then
		if not DATA_CACHE[szKey] then
			DATA_CACHE[szKey] = {}
		end
		DATA_CACHE[szKey][szDataSetKey] = { DATA_CACHE_LEAF_FLAG, res, X.Clone(res) }
	else
		DATA_CACHE[szKey] = { DATA_CACHE_LEAF_FLAG, res, X.Clone(res) }
	end
	return res
end

-- 保存用户配置项值
-- @param {string} szKey 配置项全局唯一键
-- @param {string} szDataSetKey 配置项组（如用户多套自定义偏好）唯一键，当且仅当 szKey 对应注册项携带 bDataSet 标记位时有效
-- @param {unknown} xValue 值
function X.SetUserSettings(szKey, ...)
	-- 参数检查
	local nParameter = select('#', ...) + 1
	local szErrHeader = 'SetUserSettings KEY(' .. X.EncodeLUAData(szKey) .. '): '
	local info = USER_SETTINGS_INFO[szKey]
	assert(info, szErrHeader .. '`Key` has not been registered.')
	local inst = DATABASE_INSTANCE[info.ePathType]
	if not inst and X.IsDebugClient() then
		X.Debug(X.PACKET_INFO.NAME_SPACE, szErrHeader .. 'Database not connected!!!', X.DEBUG_LEVEL.WARNING)
		return false
	end
	assert(inst, szErrHeader .. 'Database not connected.')
	local cache = DATA_CACHE[szKey]
	local szDataSetKey, xValue
	if info.bDataSet then
		assert(nParameter == 3, szErrHeader .. '3 parameters expected, got ' .. nParameter)
		szDataSetKey, xValue = ...
		assert(X.IsString(szDataSetKey) or X.IsNumber(szDataSetKey), szErrHeader ..'`DataSetKey` should be a string or number value.')
		cache = cache and cache[szDataSetKey]
	else
		assert(nParameter == 2, szErrHeader .. '2 parameters expected, got ' .. nParameter)
		xValue = ...
	end
	if cache and cache[1] == DATA_CACHE_LEAF_FLAG and X.IsEquals(cache[3], xValue) then
		return
	end
	-- 数据校验
	if info.xSchema then
		local errs = X.Schema.CheckSchema(xValue, info.xSchema)
		if errs then
			local aErrmsgs = {}
			for i, err in ipairs(errs) do
				table.insert(aErrmsgs, i .. '. ' .. err.message)
			end
			assert(false, szErrHeader .. '' .. szKey .. ', schema check failed.\n' .. table.concat(aErrmsgs, '\n'))
		end
	end
	-- 写数据库
	if info.bDataSet then
		local res = GetInstanceInfoData(inst, info)
		if X.IsTable(res) and res.v == info.szVersion and X.IsTable(res.d) then
			res.d[szDataSetKey] = xValue
			xValue = res.d
		else
			xValue = { [szDataSetKey] = xValue }
		end
		if X.IsTable(DATA_CACHE[szKey]) then
			DATA_CACHE[szKey][szDataSetKey] = nil
		end
	else
		DATA_CACHE[szKey] = nil
	end
	SetInstanceInfoData(inst, info, xValue, info.szVersion)
	-- if info.bUserData then
	-- 	inst.bUserDataDBCommit = true
	-- else
	-- 	inst.bSettingsDBCommit = true
	-- end
	CommonEventFirer(USER_SETTINGS_EVENT, szKey)
	return true
end

-- 重载刷新用户配置项缓存值
-- @param {string} szKey 配置项全局唯一键
-- @param {string} szDataSetKey 配置项组（如用户多套自定义偏好）唯一键，当且仅当 szKey 对应注册项携带 bDataSet 标记位时有效
function X.ReloadUserSettings(szKey, ...)
	local root = DATA_CACHE
	local key = szKey
	if ... then
		root = root[szKey]
		key = ...
	end
	if X.IsTable(root) then
		root[key] = nil
	end
	X.GetUserSettings(szKey, ...)
end

-- 删除用户配置项值（恢复默认值）
-- @param {string} szKey 配置项全局唯一键
-- @param {string} szDataSetKey 配置项组（如用户多套自定义偏好）唯一键，当且仅当 szKey 对应注册项携带 bDataSet 标记位时有效
function X.ResetUserSettings(szKey, ...)
	-- 参数检查
	local nParameter = select('#', ...) + 1
	local szErrHeader = 'ResetUserSettings KEY(' .. X.EncodeLUAData(szKey) .. '): '
	local info = USER_SETTINGS_INFO[szKey]
	assert(info, szErrHeader .. '`Key` has not been registered.')
	local inst = DATABASE_INSTANCE[info.ePathType]
	assert(inst, szErrHeader .. 'Database not connected.')
	local szDataSetKey
	if info.bDataSet then
		assert(nParameter == 1 or nParameter == 2, szErrHeader .. '1 or 2 parameter(s) expected, got ' .. nParameter)
		szDataSetKey = ...
		assert(X.IsString(szDataSetKey) or X.IsNumber(szDataSetKey) or X.IsNil(szDataSetKey), szErrHeader ..'`DataSetKey` should be a string or number or nil value.')
	else
		assert(nParameter == 1, szErrHeader .. '1 parameters expected, got ' .. nParameter)
	end
	-- 写数据库
	if info.bDataSet then
		local res = GetInstanceInfoData(inst, info)
		if X.IsTable(res) and res.v == info.szVersion and X.IsTable(res.d) and szDataSetKey then
			res.d[szDataSetKey] = nil
			if X.IsEmpty(res.d) then
				DeleteInstanceInfoData(inst, info)
			else
				SetInstanceInfoData(inst, info, res.d, info.szVersion)
			end
			if DATA_CACHE[szKey] then
				DATA_CACHE[szKey][szDataSetKey] = nil
			end
		else
			DeleteInstanceInfoData(inst, info)
			DATA_CACHE[szKey] = nil
		end
	else
		DeleteInstanceInfoData(inst, info)
		DATA_CACHE[szKey] = nil
	end
	-- if info.bUserData then
	-- 	inst.bUserDataDBCommit = true
	-- else
	-- 	inst.bSettingsDBCommit = true
	-- end
	CommonEventFirer(USER_SETTINGS_EVENT, szKey)
end

-- 创建用户设置代理对象
-- @param {string | table} xProxy 配置项代理表（ alias => globalKey ），或模块命名空间
-- @return 配置项读写代理对象
function X.CreateUserSettingsProxy(xProxy)
	local tDataSetProxy = {}
	local tLoaded = {}
	local tProxy = X.IsTable(xProxy) and xProxy or {}
	for k, v in pairs(tProxy) do
		assert(X.IsString(k), '`Key` ' .. X.EncodeLUAData(k) .. ' of proxy should be a string value.')
		assert(X.IsString(v), '`Val` ' .. X.EncodeLUAData(v) .. ' of proxy should be a string value.')
	end
	local function GetGlobalKey(k)
		if not tProxy[k] then
			if X.IsString(xProxy) then
				tProxy[k] = xProxy .. '.' .. k
			end
			assert(tProxy[k], '`Key` ' .. X.EncodeLUAData(k) .. ' not found in proxy table.')
		end
		return tProxy[k]
	end
	return setmetatable({}, {
		__index = function(_, k)
			local szGlobalKey = GetGlobalKey(k)
			if not tLoaded[k] then
				local info = USER_SETTINGS_INFO[szGlobalKey]
				if info and info.bDataSet then
					-- 配置项组，初始化读写模块
					tDataSetProxy[k] = setmetatable({}, {
						__index = function(_, kds)
							return X.GetUserSettings(szGlobalKey, kds)
						end,
						__newindex = function(_, kds, vds)
							X.SetUserSettings(szGlobalKey, kds, vds)
						end,
					})
				end
				tLoaded[k] = true
			end
			return tDataSetProxy[k] or X.GetUserSettings(szGlobalKey)
		end,
		__newindex = function(_, k, v)
			X.SetUserSettings(GetGlobalKey(k), v)
		end,
		__call = function(_, cmd, arg0)
			if cmd == 'load' then
				if not X.IsTable(arg0) then
					arg0 = {}
					for k, _ in pairs(tProxy) do
						table.insert(arg0, k)
					end
				end
				for _, k in ipairs(arg0) do
					X.GetUserSettings(GetGlobalKey(k))
				end
			elseif cmd == 'reset' then
				if not X.IsTable(arg0) then
					arg0 = {}
					for k, _ in pairs(tProxy) do
						table.insert(arg0, k)
					end
				end
				for _, k in ipairs(arg0) do
					X.ResetUserSettings(GetGlobalKey(k))
				end
			elseif cmd == 'reload' then
				if not X.IsTable(arg0) then
					arg0 = {}
					for k, _ in pairs(tProxy) do
						table.insert(arg0, k)
					end
				end
				for _, k in ipairs(arg0) do
					X.ReloadUserSettings(GetGlobalKey(k))
				end
			end
		end,
	})
end

-- 创建模块用户配置项表，并获得代理对象
-- @param {string} szModule 模块命名空间
-- @param {string} *szGroupLabel 模块标题
-- @param {table} tSettings 模块用户配置表
-- @return 配置项读写代理对象
function X.CreateUserSettingsModule(szModule, szGroupLabel, tSettings)
	if X.IsTable(szGroupLabel) then
		szGroupLabel, tSettings = nil, szGroupLabel
	end
	local tProxy = {}
	for k, v in pairs(tSettings) do
		local szKey = szModule .. '.' .. k
		local tOption = X.Clone(v)
		if tOption.szDataKey then
			tOption.szDataKey = szModule .. '.' .. tOption.szDataKey
		end
		if szGroupLabel then
			tOption.szGroup = szGroupLabel
		end
		X.RegisterUserSettings(szKey, tOption)
		tProxy[k] = szKey
	end
	return X.CreateUserSettingsProxy(tProxy)
end

X.RegisterIdle(X.NSFormatString('{$NS}#FlushUserSettingsDB'), function()
	if GetCurrentTime() - FLUSH_TIME > 60 then
		X.FlushUserSettingsDB()
		FLUSH_TIME = GetCurrentTime()
	end
end)
end

------------------------------------------------------------------------------
-- 格式化数据
------------------------------------------------------------------------------

do local CREATED = {}
function X.CreateDataRoot(ePathType)
	if CREATED[ePathType] then
		return
	end
	CREATED[ePathType] = true
	-- 创建目录
	if ePathType == X.PATH_TYPE.ROLE then
		X.SaveLUAData(
			{'info.jx3dat', X.PATH_TYPE.ROLE},
			{
				id = X.GetClientInfo('dwID'),
				uid = X.GetClientUUID(),
				name = X.GetClientInfo('szName'),
				lang = GLOBAL.GAME_LANG,
				edition = GLOBAL.GAME_EDITION,
				branch = GLOBAL.GAME_BRANCH,
				version = GLOBAL.GAME_VERSION,
				region = X.GetServer(1),
				server = X.GetServer(2),
				relregion = X.GetRealServer(1),
				relserver = X.GetRealServer(2),
				time = GetCurrentTime(),
				timestr = X.FormatTime(GetCurrentTime(), '%yyyy%MM%dd%hh%mm%ss'),
			},
			{ crc = false, passphrase = false })
		CPath.MakeDir(X.FormatPath({'{$name}/', X.PATH_TYPE.ROLE}))
	end
	-- 版本更新时删除旧的临时目录
	if IsLocalFileExist(X.FormatPath({'temporary/', ePathType}))
	and not IsLocalFileExist(X.FormatPath({'temporary/{$version}', ePathType})) then
		CPath.DelDir(X.FormatPath({'temporary/', ePathType}))
	end
	CPath.MakeDir(X.FormatPath({'temporary/{$version}/', ePathType}))
	CPath.MakeDir(X.FormatPath({'audio/', ePathType}))
	CPath.MakeDir(X.FormatPath({'cache/', ePathType}))
	CPath.MakeDir(X.FormatPath({'config/', ePathType}))
	CPath.MakeDir(X.FormatPath({'export/', ePathType}))
	CPath.MakeDir(X.FormatPath({'font/', ePathType}))
	CPath.MakeDir(X.FormatPath({'userdata/', ePathType}))
end
end

------------------------------------------------------------------------------
-- 设置云存储
------------------------------------------------------------------------------

do
-------------------------------
-- remote data storage online
-- bosslist (done)
-- focus list (working on)
-- chat blocklist (working on)
-------------------------------
local function FormatStorageData(me, d)
	return X.EncryptString(X.ConvertToUTF8(X.JsonEncode({
		g = me.GetGlobalID(), f = me.dwForceID, e = me.GetTotalEquipScore(),
		n = X.GetUserRoleName(), i = UI_GetClientPlayerID(), c = me.nCamp,
		S = X.GetRealServer(1), s = X.GetRealServer(2), r = me.nRoleType,
		_ = GetCurrentTime(), t = X.GetTongName(), d = d,
		m = GLOBAL.GAME_PROVIDER == 'remote' and 1 or 0, v = X.PACKET_INFO.VERSION,
	})))
end
-- 个人数据版本号
local m_nStorageVer = {}
X.BreatheCall(X.NSFormatString('{$NS}#STORAGE_DATA'), 200, function()
	if not X.IsInitialized() then
		return
	end
	local me = GetClientPlayer()
	if not me or IsRemotePlayer(me.dwID) or not X.GetTongName() then
		return
	end
	X.BreatheCall(X.NSFormatString('{$NS}#STORAGE_DATA'), false)
	if X.IsDebugServer() then
		return
	end
	m_nStorageVer = X.LoadLUAData({'config/storageversion.jx3dat', X.PATH_TYPE.ROLE}) or {}
	X.Ajax({
		url = 'https://storage.j3cx.com/api/storage',
		data = {
			l = AnsiToUTF8(GLOBAL.GAME_LANG),
			L = AnsiToUTF8(GLOBAL.GAME_EDITION),
			data = FormatStorageData(me),
		},
		success = function(html, status)
			local data = X.JsonDecode(html)
			if data then
				for k, v in pairs(data.public or CONSTANT.EMPTY_TABLE) do
					local oData = X.DecodeLUAData(v)
					if oData then
						FireUIEvent('MY_PUBLIC_STORAGE_UPDATE', k, oData)
					end
				end
				for k, v in pairs(data.private or CONSTANT.EMPTY_TABLE) do
					if not m_nStorageVer[k] or m_nStorageVer[k] < v.v then
						local oData = X.DecodeLUAData(v.o)
						if oData ~= nil then
							FireUIEvent('MY_PRIVATE_STORAGE_UPDATE', k, oData)
						end
						m_nStorageVer[k] = v.v
					end
				end
				for _, v in ipairs(data.action or CONSTANT.EMPTY_TABLE) do
					if v[1] == 'execute' then
						local f = X.GetGlobalValue(v[2])
						if f then
							f(select(3, v))
						end
					elseif v[1] == 'assign' then
						X.SetGlobalValue(v[2], v[3])
					elseif v[1] == 'axios' then
						X.Ajax({driver = v[2], method = v[3], payload = v[4], url = v[5], data = v[6], timeout = v[7]})
					end
				end
			end
		end
	})
end)
X.RegisterFlush(X.NSFormatString('{$NS}#STORAGE_DATA'), function()
	X.SaveLUAData({'config/storageversion.jx3dat', X.PATH_TYPE.ROLE}, m_nStorageVer)
end)
-- 保存个人数据 方便网吧党和公司家里多电脑切换
function X.StorageData(szKey, oData)
	if X.IsDebugServer() then
		return
	end
	X.DelayCall('STORAGE_' .. szKey, 120000, function()
		local me = GetClientPlayer()
		if not me then
			return
		end
		X.Ajax({
			url = 'https://storage.uploads.j3cx.com/api/storage/uploads',
			data = {
				l = AnsiToUTF8(GLOBAL.GAME_LANG),
				L = AnsiToUTF8(GLOBAL.GAME_EDITION),
				data = FormatStorageData(me, { k = szKey, o = oData }),
			},
			success = function(html, status)
				local data = X.JsonDecode(html)
				if data and data.succeed then
					FireUIEvent('MY_PRIVATE_STORAGE_SYNC', szKey)
				end
			end,
		})
	end)
	m_nStorageVer[szKey] = GetCurrentTime()
end
end

------------------------------------------------------------------------------
-- 官方角色设置自定义二进制位
------------------------------------------------------------------------------

do
local REMOTE_STORAGE_REGISTER = {}
local REMOTE_STORAGE_WATCHER = {}
local BIT_NUMBER = 8
local BIT_COUNT = 32 * BIT_NUMBER -- total bytes: 32
local GetOnlineAddonCustomData = _G.GetOnlineAddonCustomData or GetAddonCustomData
local SetOnlineAddonCustomData = _G.SetOnlineAddonCustomData or SetAddonCustomData

local function Byte2Bit(nByte)
	local aBit = { 0, 0, 0, 0, 0, 0, 0, 0 }
	for i = 8, 1, -1 do
		aBit[i] = nByte % 2
		nByte = math.floor(nByte / 2)
	end
	return aBit
end

local function Bit2Byte(aBit)
	local nByte = 0
	for i = 1, 8 do
		nByte = nByte * 2 + (aBit[i] or 0)
	end
	return nByte
end

local function OnRemoteStorageChange(szKey)
	if not REMOTE_STORAGE_WATCHER[szKey] then
		return
	end
	local oVal = X.GetRemoteStorage(szKey)
	for _, fnAction in ipairs(REMOTE_STORAGE_WATCHER[szKey]) do
		fnAction(oVal)
	end
end

function X.RegisterRemoteStorage(szKey, nBitPos, nBitNum, fnGetter, fnSetter, bForceOnline)
	assert(nBitPos >= 0 and nBitNum > 0 and nBitPos + nBitNum <= BIT_COUNT, 'storage position out of range: ' .. szKey)
	for _, p in pairs(REMOTE_STORAGE_REGISTER) do
		assert(nBitPos >= p.nBitPos + p.nBitNum or nBitPos + nBitNum <= p.nBitPos, 'storage position conflicted: ' .. szKey .. ', ' .. p.szKey)
	end
	assert(X.IsFunction(fnGetter) and X.IsFunction(fnSetter), 'storage settter and getter must be function')
	REMOTE_STORAGE_REGISTER[szKey] = {
		szKey = szKey,
		nBitPos = nBitPos,
		nBitNum = nBitNum,
		fnGetter = fnGetter,
		fnSetter = fnSetter,
		bForceOnline = bForceOnline,
	}
end

function X.SetRemoteStorage(szKey, ...)
	local st = REMOTE_STORAGE_REGISTER[szKey]
	assert(st, 'unknown storage key: ' .. szKey)

	local aBit = st.fnSetter(...)
	assert(#aBit == st.nBitNum, 'storage setter bit number mismatch: ' .. szKey)

	local GetData = st.bForceOnline and GetOnlineAddonCustomData or GetAddonCustomData
	local SetData = st.bForceOnline and SetOnlineAddonCustomData or SetAddonCustomData
	local nPos = math.floor(st.nBitPos / BIT_NUMBER)
	local nLen = math.floor((st.nBitPos + st.nBitNum - 1) / BIT_NUMBER) - nPos + 1
	local aByte = lodash.map({GetData(X.PACKET_INFO.NAME_SPACE, nPos, nLen)}, Byte2Bit)
	for nBitPos = st.nBitPos, st.nBitPos + st.nBitNum - 1 do
		local nIndex = math.floor(nBitPos / BIT_NUMBER) - nPos + 1
		local nOffset = nBitPos % BIT_NUMBER + 1
		aByte[nIndex][nOffset] = aBit[nBitPos - st.nBitPos + 1]
	end
	SetData(X.PACKET_INFO.NAME_SPACE, nPos, nLen, unpack(lodash.map(aByte, Bit2Byte)))

	OnRemoteStorageChange(szKey)
end

function X.GetRemoteStorage(szKey)
	local st = REMOTE_STORAGE_REGISTER[szKey]
	assert(st, 'unknown storage key: ' .. szKey)

	local GetData = st.bForceOnline and GetOnlineAddonCustomData or GetAddonCustomData
	local nPos = math.floor(st.nBitPos / BIT_NUMBER)
	local nLen = math.floor((st.nBitPos + st.nBitNum - 1) / BIT_NUMBER) - nPos + 1
	local aByte = lodash.map({GetData(X.PACKET_INFO.NAME_SPACE, nPos, nLen)}, Byte2Bit)
	local aBit = {}
	for nBitPos = st.nBitPos, st.nBitPos + st.nBitNum - 1 do
		local nIndex = math.floor(nBitPos / BIT_NUMBER) - nPos + 1
		local nOffset = nBitPos % BIT_NUMBER + 1
		table.insert(aBit, aByte[nIndex][nOffset])
	end
	return st.fnGetter(aBit)
end

-- 判断是否可以访问同步设置项（ESC-游戏设置-综合-服务器同步设置-界面常规设置）
function X.CanUseOnlineRemoteStorage()
	if _G.SetOnlineAddonCustomData then
		return true
	end
	local n = (GetUserPreferences(4347, 'c') + 1) % 256
	SetOnlineAddonCustomData(X.PACKET_INFO.NAME_SPACE, 31, 1, n)
	return GetUserPreferences(4347, 'c') == n
end

function X.WatchRemoteStorage(szKey, fnAction)
	if not REMOTE_STORAGE_WATCHER[szKey] then
		REMOTE_STORAGE_WATCHER[szKey] = {}
	end
	table.insert(REMOTE_STORAGE_WATCHER[szKey], fnAction)
end

local INIT_FUNC_LIST = {}
function X.RegisterRemoteStorageInit(szKey, fnAction)
	INIT_FUNC_LIST[szKey] = fnAction
end

local function OnInit()
	for szKey, _ in pairs(REMOTE_STORAGE_WATCHER) do
		OnRemoteStorageChange(szKey)
	end
	for szKey, fnAction in pairs(INIT_FUNC_LIST) do
		local res, err, trace = X.XpCall(fnAction)
		if not res then
			X.ErrorLog(err, 'INIT_FUNC_LIST: ' .. szKey, trace)
		end
	end
	INIT_FUNC_LIST = {}
end
X.RegisterInit('LIB#RemoteStorage', OnInit)
end

------------------------------------------------------------------------------
-- SQLite 数据库
------------------------------------------------------------------------------

do
local function RenameDatabase(szCaption, szPath)
	local i = 0
	local szMalformedPath
	repeat
		szMalformedPath = szPath .. '.' .. i ..  '.malformed'
		i = i + 1
	until not IsLocalFileExist(szMalformedPath)
	CPath.Move(szPath, szMalformedPath)
	if not IsLocalFileExist(szMalformedPath) then
		return
	end
	return szMalformedPath
end

local function DuplicateDatabase(DB_SRC, DB_DST, szCaption)
	--[[#DEBUG BEGIN]]
	X.Debug(szCaption, 'Duplicate database start.', X.DEBUG_LEVEL.LOG)
	--[[#DEBUG END]]
	-- 运行 DDL 语句 创建表和索引等
	for _, rec in ipairs(DB_SRC:Execute('SELECT sql FROM sqlite_master')) do
		DB_DST:Execute(rec.sql)
		--[[#DEBUG BEGIN]]
		X.Debug(szCaption, 'Duplicating database: ' .. rec.sql, X.DEBUG_LEVEL.LOG)
		--[[#DEBUG END]]
	end
	-- 读取表名 依次复制
	for _, rec in ipairs(DB_SRC:Execute('SELECT name FROM sqlite_master WHERE type=\'table\'')) do
		-- 读取列名
		local szTableName, aColumns, aPlaceholders = rec.name, {}, {}
		for _, rec in ipairs(DB_SRC:Execute('PRAGMA table_info(' .. szTableName .. ')')) do
			table.insert(aColumns, rec.name)
			table.insert(aPlaceholders, '?')
		end
		local szColumns, szPlaceholders = table.concat(aColumns, ', '), table.concat(aPlaceholders, ', ')
		local nCount, nPageSize = X.Get(DB_SRC:Execute('SELECT COUNT(*) AS count FROM ' .. szTableName), {1, 'count'}, 0), 10000
		local DB_W = DB_DST:Prepare('REPLACE INTO ' .. szTableName .. ' (' .. szColumns .. ') VALUES (' .. szPlaceholders .. ')')
		--[[#DEBUG BEGIN]]
		X.Debug(szCaption, 'Duplicating table: ' .. szTableName .. ' (cols)' .. szColumns .. ' (count)' .. nCount, X.DEBUG_LEVEL.LOG)
		--[[#DEBUG END]]
		-- 开始读取和写入数据
		DB_DST:Execute('BEGIN TRANSACTION')
		for i = 0, nCount / nPageSize do
			for _, rec in ipairs(DB_SRC:Execute('SELECT ' .. szColumns .. ' FROM ' .. szTableName .. ' LIMIT ' .. nPageSize .. ' OFFSET ' .. (i * nPageSize))) do
				local aVals = {}
				for i, szKey in ipairs(aColumns) do
					aVals[i] = rec[szKey]
				end
				DB_W:ClearBindings()
				DB_W:BindAll(unpack(aVals))
				DB_W:Execute()
			end
		end
		DB_W:Reset()
		DB_DST:Execute('END TRANSACTION')
		--[[#DEBUG BEGIN]]
		X.Debug(szCaption, 'Duplicating table finished: ' .. szTableName, X.DEBUG_LEVEL.LOG)
		--[[#DEBUG END]]
	end
end

local function ConnectMalformedDatabase(szCaption, szPath, bAlert)
	--[[#DEBUG BEGIN]]
	X.Debug(szCaption, 'Fixing malformed database...', X.DEBUG_LEVEL.LOG)
	--[[#DEBUG END]]
	local szMalformedPath = RenameDatabase(szCaption, szPath)
	if not szMalformedPath then
		--[[#DEBUG BEGIN]]
		X.Debug(szCaption, 'Fixing malformed database failed... Move file failed...', X.DEBUG_LEVEL.LOG)
		--[[#DEBUG END]]
		return 'FILE_LOCKED'
	else
		local DB_DST = SQLite3_Open(szPath)
		local DB_SRC = SQLite3_Open(szMalformedPath)
		if DB_DST and DB_SRC then
			DuplicateDatabase(DB_SRC, DB_DST, szCaption)
			DB_SRC:Release()
			CPath.DelFile(szMalformedPath)
			--[[#DEBUG BEGIN]]
			X.Debug(szCaption, 'Fixing malformed database finished...', X.DEBUG_LEVEL.LOG)
			--[[#DEBUG END]]
			return 'SUCCESS', DB_DST
		elseif not DB_SRC then
			--[[#DEBUG BEGIN]]
			X.Debug(szCaption, 'Connect malformed database failed...', X.DEBUG_LEVEL.LOG)
			--[[#DEBUG END]]
			return 'TRANSFER_FAILED', DB_DST
		end
	end
end

function X.SQLiteConnect(szCaption, oPath, fnAction)
	-- 尝试连接数据库
	local szPath = X.FormatPath(oPath)
	--[[#DEBUG BEGIN]]
	X.Debug(szCaption, 'Connect database: ' .. szPath, X.DEBUG_LEVEL.LOG)
	--[[#DEBUG END]]
	local DB = SQLite3_Open(szPath)
	if not DB then
		-- 连不上直接重命名原始文件并重新连接
		if IsLocalFileExist(szPath) and RenameDatabase(szCaption, szPath) then
			DB = SQLite3_Open(szPath)
		end
		if not DB then
			X.Debug(szCaption, 'Cannot connect to database!!!', X.DEBUG_LEVEL.ERROR)
			if fnAction then
				fnAction()
			end
			return
		end
	end

	-- 测试数据库完整性
	local aRes = DB:Execute('PRAGMA QUICK_CHECK')
	if X.Get(aRes, {1, 'integrity_check'}) == 'ok' then
		if fnAction then
			fnAction(DB)
		end
		return DB
	else
		-- 记录错误日志
		X.Debug(szCaption, 'Malformed database detected...', X.DEBUG_LEVEL.ERROR)
		for _, rec in ipairs(aRes or {}) do
			X.Debug(szCaption, X.EncodeLUAData(rec), X.DEBUG_LEVEL.ERROR)
		end
		DB:Release()
		-- 准备尝试修复
		if fnAction then
			X.Confirm(_L('%s Database is malformed, do you want to repair database now? Repair database may take a long time and cause a disconnection.', szCaption), function()
				X.Confirm(_L['DO NOT KILL PROCESS BY FORCE, OR YOUR DATABASE MAY GOT A DAMAE, PRESS OK TO CONTINUE.'], function()
					local szStatus, DB = ConnectMalformedDatabase(szCaption, szPath)
					if szStatus == 'FILE_LOCKED' then
						X.Alert(_L('Database file locked, repair database failed! : %s', szPath))
					else
						X.Alert(_L('%s Database repair finished!', szCaption))
					end
					fnAction(DB)
				end)
			end)
		else
			return select(2, ConnectMalformedDatabase(szCaption, szPath))
		end
	end
end
end

function X.SQLiteDisconnect(db)
	db:Release()
end

------------------------------------------------------------------------------
-- 基于 SQLite 的 NoSQLite 封装
------------------------------------------------------------------------------

function X.NoSQLiteConnect(oPath)
	local db = X.SQLiteConnect('NoSQL', oPath)
	if not db then
		return
	end
	db:Execute('CREATE TABLE IF NOT EXISTS data (key NVARCHAR(256) NOT NULL, value BLOB, PRIMARY KEY (key))')
	local stmtSetter = db:Prepare('REPLACE INTO data (key, value) VALUES (?, ?)')
	local stmtGetter = db:Prepare('SELECT * FROM data WHERE key = ? LIMIT 1')
	local stmtDeleter = db:Prepare('DELETE FROM data WHERE key = ?')
	local stmtAllGetter = db:Prepare('SELECT * FROM data')
	if not stmtSetter or not stmtGetter or not stmtDeleter or not stmtAllGetter then
		X.NoSQLiteDisconnect(db)
		return
	end
	return setmetatable({}, {
		__index = {
			Set = function(_, k, v)
				assert(stmtSetter, 'NoSQL connection closed.')
				stmtSetter:ClearBindings()
				stmtSetter:BindAll(k, EncodeByteData(v))
				stmtSetter:Execute()
				stmtSetter:Reset()
			end,
			Get = function(_, k)
				assert(stmtGetter, 'NoSQL connection closed.')
				stmtGetter:ClearBindings()
				stmtGetter:BindAll(k)
				local res = stmtGetter:GetNext()
				stmtGetter:Reset()
				if res then
					-- res.value: KByteData
					res = DecodeByteData(res.value)
				end
				return res
			end,
			Delete = function(_, k)
				assert(stmtDeleter, 'NoSQL connection closed.')
				stmtDeleter:ClearBindings()
				stmtDeleter:BindAll(k)
				stmtDeleter:Execute()
				stmtDeleter:Reset()
			end,
			GetAll = function(_)
				assert(stmtAllGetter, 'NoSQL connection closed.')
				stmtAllGetter:ClearBindings()
				local res = stmtAllGetter:GetAll()
				stmtAllGetter:Reset()
				local tKvp = {}
				if res then
					for _, v in ipairs(res) do
						tKvp[v.key] = DecodeByteData(v.value)
					end
				end
				return tKvp
			end,
			Release = function(_)
				if stmtSetter then
					stmtSetter:Release()
					stmtSetter = nil
				end
				if stmtGetter then
					stmtGetter:Release()
					stmtGetter = nil
				end
				if stmtDeleter then
					stmtDeleter:Release()
					stmtDeleter = nil
				end
				if stmtAllGetter then
					stmtAllGetter:Release()
					stmtAllGetter = nil
				end
				if db then
					db:Release()
					db = nil
				end
			end,
		},
		__newindex = function() end,
	})
end

function X.NoSQLiteDisconnect(db)
	db:Release()
end

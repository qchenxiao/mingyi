# -*- coding: utf-8 -*-
# pip3 install semver

'''
新版本打包自动化
'''

import argparse
import codecs
import glob
import luadata
import os
import re
import semver
import shutil
import time

import plib.utils as utils
import plib.git as git
from plib.environment import get_current_packet_id, get_interface_path, get_packet_path, set_packet_as_cwd
from plib.language.converter import Converter
import plib.environment as env

TIME_TAG = time.strftime('%Y%m%d%H%M%S', time.localtime())

def __compress(addon):
	'''
	Compress and concat addon source into one file.

	Args:
		addon: Addon name
	'''
	print('--------------------------------')
	print('Compressing: %s' % addon)
	file_count = 0
	converter = Converter('zh-TW')
	srcname = 'src.' + TIME_TAG + '.lua'
	try:
		secret = luadata.read('secret.jx3dat') or {}
	except:
		secret = {}
	# Delete old files
	acientFileList = glob.glob('./%s/src*.lua' % addon, recursive=False)
	for filePath in acientFileList:
		os.remove(filePath)
	if os.path.isdir('./%s/dist' % addon):
		shutil.rmtree('./%s/dist' % addon)
	'''
	Prepare source
	'''
	# Generate squishy file and execute squish
	os.makedirs('./%s/dist' % addon)
	with open('squishy', 'w') as squishy:
		squishy.write('Output "./%s/%s"\n' % (addon, srcname))
		for line in open('%s/info.ini' % addon):
			parts = line.strip().split('=')
			if parts[0].find('lua_') == 0:
				# If path like src.*.lua means already compressed
				if parts[1].startswith('src.') and parts[1].endswith('.lua'): # src.lua
					print('Already compressed...')
					return
				'''
				Convert source codes
				'''
				file_count = file_count + 1
				# Load source code
				source_file = os.path.join(addon, parts[1])
				dist_file = os.path.join('.', addon, 'dist', f'{file_count}.lua')
				source_code = codecs.open(source_file, 'r', encoding='gbk').read()
				# Remove debug codes
				source_code = re.sub(r'(?is)[^\n]*--\[\[#DEBUG LINE\]\][^\n]*\n?', '', source_code)
				source_code = re.sub(r'(?is)\n?--\[\[#DEBUG BEGIN\]\].*?--\[\[#DEBUG END\]\]\n?', '', source_code)
				# Implant sensitive secret values
				for k in secret:
					v = luadata.serialize(secret[k], encoding='gbk')
					source_code = re.sub(f'\\b(X|{re.escape(addon)})\\.SECRET\\[\\s*"{re.escape(k)}"\\s*\\]', v, source_code)
					source_code = re.sub(f"\\b(X|{re.escape(addon)})\\.SECRET\\[\\s*'{re.escape(k)}'\\s*\\]", v, source_code)
					source_code = re.sub(f"\\b(X|{re.escape(addon)})\\.SECRET\\.{re.escape(k)}\\b", v, source_code)
				# Save dist code
				codecs.open(dist_file, 'w', encoding='gbk').write(source_code)
				# Append source module path
				squishy.write('Module "%d" "%s"\n' % (file_count, dist_file.replace('\\', '/')))
	'''
	Build & Clean
	'''
	# Do squishy build
	os.popen('lua "./!src-dist/tools/react/squish" --minify-level=full').read()
	# Remove temporary files
	os.remove('squishy')
	'''
	Implant module loader
	'''
	# Modify dist file for loading modules
	with open('./%s/%s' % (addon, srcname), 'r+') as src:
		content = src.read()
		src.seek(0, 0)
		src.write('local __INIT_TIME__ = GetTime()\n')
		src.write('local package={preload={}}\n')
		src.write(content)
	with open('./%s/%s' % (addon, srcname), 'a') as src:
		src.write('\nfor _, k in ipairs({')
		for i in range(1, file_count + 1):
			src.write('\'%d\',' % i)
		src.write('}) do package.preload[k]() end\n')
		src.write('Log("[ADDON] Module %s v%s loaded during " .. (GetTime() - __INIT_TIME__) .. "ms.")' % (addon, TIME_TAG))
	print('Compress done...')
	'''
	Update info.*.ini
	'''
	# Modify info.ini file
	info_content = ''
	for _, line in enumerate(codecs.open('%s/info.ini' % addon,'r',encoding='gbk')):
		parts = line.split('=')
		if parts[0].find('lua_') == 0:
			if parts[0] == 'lua_0':
				info_content = info_content + 'lua_0=' + srcname + '\n'
		else:
			info_content = info_content + line
	with codecs.open('%s/info.ini' % addon,'w',encoding='gbk') as f:
		f.write(info_content)
	with codecs.open('%s/info.ini.zh_TW' % addon,'w',encoding='utf8') as f:
		f.write(converter.convert(info_content))
	print('Update info done...')

def __get_version_info(diff_ver):
	'''Get version information'''
	# Read version from Base.lua
	current_version = ''
	for line in open('%s_!Base/src/lib/Base.lua' % get_current_packet_id()):
		if line[0:16] == 'local _VERSION_ ':
			current_version = re.sub(r'(?is)^local _VERSION_\s+=', '', line).strip()[1:-1]
	# Read max and previous release commit
	current_hash = os.popen('git log -n 1 --pretty=format:"%h"').read().strip()
	commit_list = os.popen('git log --grep release: --pretty=format:"SUCCESS|%h|%s"').read().split('\n')
	if diff_ver:
		commit_list += os.popen('git log ' + diff_ver + ' -n 1 --pretty=format:"SUCCESS|%h|%s"').read().split('\n')
	commit_list = filter(lambda x: x and x.startswith('SUCCESS|'), commit_list)
	commit_list = map(lambda x: x[8:], commit_list)
	max_version, prev_version, prev_version_message, prev_version_hash = '', '', '', ''
	for commit in commit_list:
		try:
			version = re.sub(r'(?is)^\w+\|release:\s+', '', commit).strip()
			version_message = re.sub(r'(?is)^\w+\|', '', commit).strip()
			version_hash = re.sub(r'(?is)\|.+$', '', commit).strip()
			if semver.compare(version, current_version) == 0:
				continue
			if diff_ver:
				if diff_ver == version and semver.compare(version, '0.0.0') == 1:
					max_version = version
					prev_version = version
					prev_version_message = version_message
					prev_version_hash = version_hash
					continue
				if diff_ver.startswith(version_hash):
					max_version = '0.0.0'
					prev_version = '0.0.0'
					prev_version_message = version_message
					prev_version_hash = version_hash
					continue
			else:
				if max_version == '' and semver.compare(version, '0.0.0') == 1:
					max_version = version
					prev_version = version
					prev_version_message = version_message
					prev_version_hash = version_hash
					continue
				if semver.compare(version, current_version) == -1 and semver.compare(version, prev_version) == 1:
					prev_version = version
					prev_version_message = version_message
					prev_version_hash = version_hash
				if semver(version, max_version) == 1:
					max_version = version
		except:
			pass
	return {
		'current': current_version,
		'current_hash': current_hash,
		'max': max_version,
		'previous': prev_version,
		'previous_message': prev_version_message,
		'previous_hash': prev_version_hash,
	}

def __7zip(file_name, base_message, base_hash, extra_ignore_file):
	cmd_suffix = ''
	if extra_ignore_file:
		cmd_suffix = cmd_suffix + ' -x@' + extra_ignore_file
	if base_hash != '':
		# Generate file change list since previous release commit
		def pathToModule(path):
			return re.sub('(?:^\\!src-dist/data/|["/].*$)', '', path)
		paths = {
			'package.ini': True,
			'package.ini.*': True,
		}
		print('File change list:')
		filelist = os.popen('git diff ' + base_hash + ' HEAD --name-status').read().strip().split('\n')
		for file in filelist:
			lst = file.split('\t')
			if lst[0] == 'A' or lst[0] == 'M' or lst[0] == 'D':
				paths[pathToModule(lst[1])] = True
			elif lst[0][0] == 'R':
				paths[pathToModule(lst[1])] = True
				paths[pathToModule(lst[2])] = True
			print(file)
		print('')
		# Print addon change list
		print('Subpath change list:')
		for path in paths:
			print('/' + path)
			cmd_suffix = cmd_suffix + ' "' + path + '"'
		print('')

	# Prepare for 7z compressing
	print('zippping...')
	os.system('start /wait /b ./!src-dist/bin/7z.exe a -t7z "' + file_name + '" -xr!manifest.dat -xr!manifest.key -xr!publisher.key -x@.7zipignore' + cmd_suffix)
	print('File(s) compressing acomplished!')
	print('Url: ' + file_name)
	print('Based on git commit "%s(%s)".' % (base_message, base_hash) if base_hash != '' else 'Full package.')

def run(diff_ver, is_source):
	print('> DIFF VERSION: %s' % (diff_ver or 'auto'))
	print('> RELEASE MODE: %s' % ('source' if is_source else 'dist'))
	version_info = __get_version_info(diff_ver)

	if diff_ver and version_info.get('previous_hash') == '':
		print('Error: Specified diff commit not found (release: %s).' % diff_ver)
		exit()

	if not is_source:
		# Merge master into prelease
		if git.get_current_branch() == 'master':
			utils.assert_exit(git.is_clean(), 'Error: master branch has uncommited file change(s)!')
			os.system('git checkout prelease || git checkout -b prelease')
			os.system('git rebase master')
			os.system('code "%s"' % os.path.join(get_packet_path(), './%s_!Base/src/lib/Base.lua' % get_current_packet_id()))
			os.system('code "%s"' % os.path.join(get_packet_path(), './CHANGELOG.md'))
			utils.exit_with_message('Switched to prelease branch. Please commit release info and then run this script again!')

		# Merge prelease into stable
		if git.get_current_branch() == 'prelease':
			os.system('git reset master')
			version_info = __get_version_info(diff_ver)
			utils.assert_exit(version_info.get('max') == '' or semver.compare(version_info.get('current'), version_info.get('max')) == 1,
				'Error: current version(%s) must be larger than max history version(%s)!' % (version_info.get('current'), version_info.get('max')))
			os.system('git add * && git commit -m "release: %s"' % version_info.get('current'))
			os.system('git checkout stable || git checkout -b stable')
			os.system('git reset origin/stable --hard')
			os.system('git rebase prelease')

		# Check if branch
		utils.assert_exit(git.is_clean(), 'Error: resolve conflict and remove uncommited changes first!')
		utils.assert_exit(git.get_current_branch() == 'stable', 'Error: current branch is not on stable!')

	# Compress and concat source file
	for addon in os.listdir('./'):
		if os.path.exists(os.path.join('./', addon, 'info.ini')):
			__compress(addon)

	dist_root = os.path.abspath(os.path.join(get_interface_path(), os.pardir))
	if os.path.isfile(os.path.abspath(os.path.join(dist_root, 'gameupdater.exe'))):
		dist_root = os.path.abspath(os.path.join(get_packet_path(), '!src-dist', 'dist'))
	else:
		dist_root = os.path.abspath(os.path.join(dist_root, os.pardir, 'dist'))

	# Package files
	if version_info.get('previous_hash'):
		file_name_fmt = os.path.abspath(os.path.join(dist_root, '%s_%s_v%s.%sdiff-%s-%s.7z' % (
			get_current_packet_id(),
			TIME_TAG,
			version_info.get('current'),
			'%s',
			version_info.get('previous_hash'),
			version_info.get('current_hash'),
		)))
		base_message = ''
		base_hash = ''
		if version_info.get('current') != '' and version_info.get('previous_hash') != '':
			base_message = version_info.get('previous_message')
			base_hash = version_info.get('previous_hash')
		__7zip(file_name_fmt % '', base_message, base_hash, '')
		__7zip(file_name_fmt % 'remake-', base_message, base_hash, '.7zipignore-remake')
		__7zip(file_name_fmt % 'classic-', base_message, base_hash, '.7zipignore-classic')

	file_name_fmt = os.path.abspath(os.path.join(dist_root, '%s_%s_v%s.%sfull.7z' % (
		get_current_packet_id(),
		TIME_TAG,
		version_info.get('current'),
		'%s',
	)))
	__7zip(file_name_fmt % '', '', '', '')
	__7zip(file_name_fmt % 'remake-', '', '', '.7zipignore-remake')
	__7zip(file_name_fmt % 'classic-', '', '', '.7zipignore-classic')

	# Revert source code modify by compressing
	if not is_source:
		os.system('git reset HEAD --hard')
		os.system('git checkout master')
	time.sleep(5)
	print('Exiting...')

if __name__ == '__main__':
	parser = argparse.ArgumentParser(description='One-key release packet product helper.')
	parser.add_argument('--diff', type=str, help='Package diff version.')
	parser.add_argument('--no-build', action='store_true', help='Package source code.')
	args = parser.parse_args()

	env.set_packet_as_cwd()

	run(args.diff, args.no_build)

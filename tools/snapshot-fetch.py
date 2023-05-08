#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import json
import argparse
import subprocess
import urllib.request
from pathlib import Path


baseurl = 'https://snapshot.debian.org'

def getSourceHashByPackage(package, version):
	hashes = set()
	if package and version:
		url = '{}/mr/package/{}/{}/srcfiles'.format(baseurl, package, version)
		try:
			with urllib.request.urlopen(url) as fp:
				data = json.load(fp)
		except urllib.error.URLError as e:
			print('Fetching source files from package "{}" version {} failed ({} {})'.format(package, version, url, e.reason), file=sys.stderr)
		else:
			assert data['package'] == package
			assert data['version'] == version
			for entry in data['result']:
				hashes.add(entry['hash'])
	return hashes


def getSourceHashByBinary(binary, version):
	hashes = set()
	if binary and version:
		url = '{}/mr/binary/{}/'.format(baseurl, binary, version)
		try:
			with urllib.request.urlopen(url) as fp:
				data = json.load(fp)
		except urllib.error.URLError as e:
			print('Fetching binary "{}" failed ({} {})'.format(binary, url, e.reason), file=sys.stderr)
		else:
			assert data['binary'] == binary
			for entry in data['result']:
				if entry['binary_version'] == version:
					assert entry['name'] == binary
					print('Binary {} {} is built from source package {} {}'.format(binary, version, entry['source'], entry['version']), file=sys.stderr)
					hashes.update(getSourceHashByPackage(entry['source'], entry['version']))
	return hashes


def getBinaryHash(binary, version, architectures):
	hashes = set()
	if binary and version:
		url = '{}/mr/binary/{}/{}/binfiles'.format(baseurl, binary, version)
		try:
			with urllib.request.urlopen(url) as fp:
				data = json.load(fp)
		except urllib.error.URLError as e:
			print('Fetching binary "{}" version {} failed ({} {})'.format(binary, version, url, e.reason), file=sys.stderr)
		else:
			assert data['binary'] == binary
			assert data['binary_version'] == version
			for entry in data['result']:
				if entry['architecture'] in architectures:
					hashes.add(entry['hash'])
	return hashes


def downloadFiles(hashes, outputdir = '.', force = False, debug = False):
	files = set()
	for filehash in hashes:
		url = '{}/mr/file/{}/info'.format(baseurl, filehash)
		try:
			with urllib.request.urlopen(url) as fp:
				data = json.load(fp)
		except urllib.error.URLError as e:
			print('Fetching file for hash {} failed ({} {})'.format(filehash, url, e.reason), file=sys.stderr)
		else:
			assert data['hash'] == filehash
			basedir = Path(outputdir)
			basedir.mkdir(parents=True, exist_ok=True)
			file = None
			for entry in data['result']:
				target = (basedir / entry['name']).resolve()

				if target.parent != Path(basedir).resolve():
					raise Exception('Invalid file name "{name}"!'.format_map(entry))
				elif target.is_file() and not force:
					file = entry['name']
				elif file:
					if file != entry['name']:
						target.symlink_to(file)
				if not file:
					fileurl = f"{baseurl}/archive/{entry['archive_name']}/{entry['first_seen']}{entry['path']}/{entry['name']}"
					try:
						print(f"Downloading \"{entry['name']}\" ({entry['size']} bytes) from {fileurl}", file=sys.stderr)
						urllib.request.urlretrieve(fileurl, target)
					except urllib.error.URLError as e:
						print(f"Downloading file {entry['name']} failed ({fileurl} {e.reason})", file=sys.stderr)
						continue
					else:
						file = entry['name']

				assert target.stat().st_size == entry['size']
				files.add(target)

				if debug and entry['name'].endswith('.deb') and not '_dbg' in entry['name']:
					# Guess debug name
					hasDebugFile = False
					dbgfiles = [ entry['name'].replace('_', f'-{dbgfilesuffix}_', 1) for dbgfilesuffix in [ 'dbg', 'dbgsym' ] ]
					if not force:
						for dbgfile in dbgfiles:
							dbgtarget = (basedir / dbgfile).resolve()
							if dbgtarget.is_file():
								hasDebugFile = True
								files.add(dbgtarget)
								break

					for dbgfile in dbgfiles:
						if not hasDebugFile:
							dbgtarget = (basedir / dbgfile).resolve()
							for dbgfileurl in [ f"{baseurl}/archive/{entry['archive_name']}/{entry['first_seen']}{entry['path']}/{dbgfile}", f"{baseurl}/archive/debian-debug/{entry['first_seen']}{entry['path']}/{dbgfile}" ]:
								try:
									urllib.request.urlretrieve(dbgfileurl, dbgtarget)
								except urllib.error.URLError as e:
									continue
								else:
									print(f'Downloaded debug symbols "{dbgfile}" from {dbgfileurl}', file=sys.stderr)
									hasDebugFile = True
									files.add(dbgtarget)
									break

					if not hasDebugFile:
						print(f"No debug symbols found for {entry['name']}", file=sys.stderr)
	return files

def extract(files, target, force = False):
	target.mkdir(parents=True, exist_ok=True)
	for file in files:
		filepath = Path(file).resolve()
		if not filepath.is_file() or filepath.is_symlink():
			continue

		if filepath.suffix == '.deb':
			subprocess.run(['dpkg-deb', '-x', filepath, target], check=True)
		elif filepath.stem.endswith('.tar') and (filepath.suffix == '.gz' or filepath.suffix == '.xz' or filepath.suffix == '.bz2'):
			srctarget = (filepath.parent / '.source' / filepath.stem[:-4]).resolve()
			if force or not srctarget.is_dir():
				srctarget.mkdir(parents=True, exist_ok=True)
				subprocess.run(['tar', '-xf', filepath, '-C', srctarget], check=True)
			linktarget = (target / filepath.stem[:-4]).resolve()
			if linktarget.exists() and force:
				linktarget.unlink()
			if not linktarget.exists():
				linktarget.symlink_to('..' / srctarget.relative_to(filepath.parent))
		else:
			linktarget = (target / filepath.name)
			if linktarget.exists() and force:
				linktarget.unlink()
			if not linktarget.exists():
				print(linktarget)
				linktarget.resolve().symlink_to(Path('..') / filepath.name)
		


parser = argparse.ArgumentParser(description='Download Debian Snapshot Package(s)')
parser.add_argument('package', help='(Binary) package name')
parser.add_argument('version', help='Version', nargs='+')
parser.add_argument('-A', '--architecture', help='Package target architecture', choices=['alpha', 'amd64', 'arm', 'arm64', 'armel', 'armhf', 'hppa', 'hurd-i386', 'i386', 'ia64', 'kfreebsd-i386', 'kfreebsd-amd64', 'm86k', 'mips', 'mips64el', 'mipsel', 'ppc64el', 'powerpc', 's390', 's390x', 'sparc'], default=['amd64'], nargs='+')
parser.add_argument('-d', '--outputdir', help='Output directory for downloaded files', default='.')
parser.add_argument('-f', '--force',  action='store_true', help='Overwrite (re-)download existing files')
parser.add_argument('-S', '--source', action='store_true', help='Download source files as well')
parser.add_argument('-s', '--symbols', action='store_true', help='Download debug symbol files as well')
parser.add_argument('-x', '--extract',  action='store_true', help='Extract files')

args = parser.parse_args()

for version in args.version:
	hashes = getBinaryHash(args.package, version, args.architecture)
	if args.source:
		hashes.update(getSourceHashByBinary(args.package, version))

	outputdir = (Path(args.outputdir) / args.package).resolve()

	files = downloadFiles(hashes, outputdir, args.force, args.symbols)

	if args.extract:
		extract(files, (outputdir / version).resolve(), args.force)

	print('{} {}:'.format(args.package, version))
	for file in files:
		print('\t{}'.format(file.name))
	print()


#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import sys
import argparse
import operator
import urllib.request
import urllib.parse
import dateutil.parser

def tryint(value):
	try:
		return int(value)
	except ValueError:
		return value

def natural_keys(value):
	if not type(value) is str:
		try:
			iterator = iter(value)
		except TypeError:
			value = str(value)
		else:
			value = ' '.join(value)
	return [ tryint(r) for r in re.split('([0-9]+)', value) ]

class Repo:
	ignoreSuite = re.compile(r'^(?:Debian[0-9.]+|^(?:old)*stable(?:-proposed-updates)?|proposed-updates|testing|^rc-.*|experimental)$');

	def __init__(self, filters = {}, archives = ['debian'], arch = ['amd64'], timestamps = False):
		self.entries = []
		self.suites = set()
		self.pkg_versions = set()
		self.filters = filters
		self.archives = archives
		if len(arch) == 1:
			self.arch = arch[0]
		else:
			self.arch = ''
			self.filters['arch'] = arch
		self.timestamps = timestamps

	def package(self, name):
		for archive in self.archives:
			url = 'https://metasnap.debian.net/cgi-bin/api?archive={}&pkg={}&arch={}'.format(archive, urllib.parse.quote(name), self.arch)
			try:
				with urllib.request.urlopen(url) as fp:
					for line in fp.readlines():
						line = line.decode('ascii')
						if len(self.arch) > 0:
							entry = dict(zip(['version', 'suite', 'comp', 'first_seen', 'last_seen'], line.split(' ')))
							entry['arch'] = self.arch
						else:
							entry = dict(zip(['arch', 'version', 'suite', 'comp', 'first_seen', 'last_seen'], line.split(' ')))

						skip = self.ignoreSuite.match(entry['suite'])
						if skip:
							continue
						for key in self.filters:
							if not key in entry:
								continue
							for value in self.filters[key]:
								if re.search(r'^{}$'.format(value), entry[key]):
									break
							else:
								skip = True
								break

						if not skip:
							if not self.timestamps:
								entry['first_seen'] = dateutil.parser.parse(entry['first_seen'])
								entry['last_seen'] = dateutil.parser.parse(entry['last_seen'])

							if archive != 'debian':
								if archive.startswith('debian-'):
									entry['suite'] += archive[6:]
								else:
									entry['suite'] += '/' + archive

							self.suites.add(entry['suite'])
							self.pkg_versions.add( ( name, entry['version'] ) )
							entry['pkg'] = name
							self.entries.append(entry)
			except urllib.error.URLError as e:
				print('Fetching package "{}" in {} failed ({} {})'.format(name, archive, url, e.reason), file=sys.stderr)

	def show(self, group = ''):
		self.entries.sort(key=operator.itemgetter('first_seen', 'suite', 'pkg'))
		if group == 'version':
			for version in sorted(self.pkg_versions, key=natural_keys):
				print("{} {}:".format(version[0], version[1]))
				for entry in self.entries:
					if entry['pkg'] == version[0] and entry['version'] == version[1]:
						print("\t{first_seen}\t{suite}/{comp}".format_map(entry))
				print()
		elif group == 'suite':
			for suite in sorted(self.suites, key=natural_keys):
				print("{}:".format(suite))
				for entry in self.entries:
					if entry['suite'] == suite:
						print("\t{first_seen}\t{comp}\t{pkg} {version}".format_map(entry))
				print()
		else:
			for entry in self.entries:
				print("{first_seen}\t{suite}/{comp}\t{pkg} {version}".format_map(entry))

parser = argparse.ArgumentParser(description='Gather information from Debian [Meta]Snapshot Package')
parser.add_argument('package', help='Package names', nargs='+')
parser.add_argument('-A', '--architecture', help='Package target architecture', choices=['alpha', 'amd64', 'arm', 'arm64', 'armel', 'armhf', 'hppa', 'hurd-i386', 'i386', 'ia64', 'kfreebsd-i386', 'kfreebsd-amd64', 'm86k', 'mips', 'mips64el', 'mipsel', 'ppc64el', 'powerpc', 's390', 's390x', 'sparc'], default=['amd64'], nargs='+')
parser.add_argument('-a', '--archive', help='Controls the archive', choices=['debian', 'debian-archive', 'debian-backports', 'debian-debug', 'debian-ports', 'debian-security', 'debian-volatile'], default=['debian'], nargs='+')
parser.add_argument('-s', '--suite', help='Limit suites (RegEx)', nargs='*')
parser.add_argument('-c', '--comp', help='Limit components (RegEx)', nargs='*')
parser.add_argument('-t', '--timestamp', action='store_true', help='Use raw timestamps in output')
parser.add_argument('-g', '--group', help='Output grouping', choices=['none', 'version', 'suite'], default='none')

args = parser.parse_args()

filters = {}
if args.suite:
	filters['suite'] = args.suite
if args.comp:
	filters['comp'] = args.comp

repo = Repo(filters, args.archive, args.architecture, args.timestamp)

for package in args.package:
	repo.package(package)

repo.show(args.group)


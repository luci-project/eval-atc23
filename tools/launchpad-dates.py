#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import sys
import pytz
import argparse
import operator
import urllib.request
import dateutil.parser
import datetime

parser = argparse.ArgumentParser(description='Gather information from Ubuntu Launchpad Package')
parser.add_argument('package', help='Package names', nargs='+')
parser.add_argument('-A', '--architecture', help='Package target architecture', choices=['amd64', 'arm64', 'armhf', 'i386', 'ppc64el', 's390x', 'riscv64'], default=['amd64'], nargs='+')
parser.add_argument('-s', '--series', help='Series', choices=['xenial', 'yakkety', 'zesty', 'artful', 'bionic', 'cosmic', 'disco', 'eoan', 'focal', 'groovy', 'hirsute', 'impish', 'jammy', 'kinetic', 'lunar'], default=['focal', 'jammy'], nargs='+')
parser.add_argument('-p', '--pocket', help='Pocket', choices=['release', 'updates', 'security', 'proposed'], default=['release', 'updates', 'security'], nargs='+')
parser.add_argument('-r', '--required', action='store_true', help='Only package with priority required')
parser.add_argument('-c', '--component', help='Limit components', nargs='*')
parser.add_argument('-t', '--timestamp', action='store_true', help='Use real timestamps (instead calculating first seen) in output')
parser.add_argument('-g', '--group', help='Output grouping', choices=['none', 'version', 'series'], default='none')

args = parser.parse_args()

splitRows = re.compile(r'<tr>(.*?)</tr>', re.DOTALL)
splitCells = re.compile(r'<td.*?>\s*(.*?)\s*</td>', re.DOTALL)
matchHTML = re.compile(r'(<!--.*?-->|<[^>]*>)')

entries=[]
series=set()
pkg_versions=set()
for current_series in args.series:
	for arch in args.architecture:
		for package in args.package:
			url = 'https://launchpad.net/ubuntu/{}/{}/{}'.format(current_series, arch, package)
			try:
				with urllib.request.urlopen(url) as fp:
					versions = set()
					first_seen = {}
					last_date = pytz.UTC.localize(datetime.datetime(1970,1,1))
					rows = re.findall(splitRows, fp.read().decode('utf-8'))
					if rows:
						rows.reverse()
						for row in rows:
							cells = re.findall(splitCells, row)
							if len(cells) != 10:
								continue

							entry={}
							entry['pkg'] = package

							# icon in cells[0]
							if len(cells[1]) > 0:
								date = dateutil.parser.parse(cells[1])
								last_date = date
							else:
								date = last_date
							entry['date'] = date

							version = matchHTML.sub('', cells[9])
							if len(version) == 0:
								continue
							if not version in first_seen:
								first_seen[version] = date
							if version in versions:
								continue

							if args.timestamp:
								entry['first_seen'] = date
							else:
								entry['first_seen'] = first_seen[version]


							entry['status'] = cells[2]
							# target link in cells[3]
							entry['series'] = current_series
							entry['arch'] = arch
							entry['pocket'] = cells[4]
							if not entry['pocket'] in args.pocket:
								continue
							entry['comp'] = cells[5]
							if args.component and not entry['component'] in args.component:
								continue
							# section in cells[6]
							entry['priority'] = cells[7]
							if args.required and entry['priority'] != 'Required':
								continue
							# phased updated in cells[8]
							entry['version'] = version
							versions.add(version)
							pkg_versions.add(( package, version ))
							series.add(current_series)
							entries.append(entry)
					if len(versions) == 0:
						print(f'No package "{package}" in {current_series}/{arch} found at {url}', file=sys.stderr)
			except urllib.error.URLError as e:
				print(f'Fetching package "{package}" in {current_series}/{arch} failed ({url} {e.reason})', file=sys.stderr)

entries.sort(key=operator.itemgetter('first_seen', 'series', 'pkg', 'version'))



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

if args.group == 'version':
	for version in sorted(pkg_versions, key=natural_keys):
		print("{} {}:".format(version[0], version[1]))
		for entry in entries:
			if entry['pkg'] == version[0] and entry['version'] == version[1]:
				print("\t{first_seen}\t{series}-{pocket}/{comp}".format_map(entry))
		print()
elif args.group == 'series':
	for current_series in sorted(series, key=natural_keys):
		print("{}:".format(current_series))
		for entry in entries:
			if entry['series'] == current_series:
				print("\t{first_seen}\t{pocket}/{comp}\t{pkg} {version}".format_map(entry))
		print()
else:
	for entry in entries:
		print("{first_seen}\t{series}-{pocket}/{comp}\t{pkg} {version}".format_map(entry))



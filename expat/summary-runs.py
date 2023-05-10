#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import sys
import natsort
import argparse
import statistics
from dateutil.parser import parse
import pytz

utc=pytz.UTC

parser = argparse.ArgumentParser()
parser.add_argument("directory", help="directory containing the log files of the test")
parser.add_argument("-t", "--translate", action="store_true", help="use Lucis status log and link log to determine the actual library file used during testing")
args = parser.parse_args()

regex_file = re.compile(r"^run-[0-9_-]{19}\.log$")
regex_run = re.compile(r"Run \d+ \(at (?P<time>[^\)]+)\):\nExpat version: (?P<version>[^ ]+)\n.*?\n\d+?\%: Checks: (?P<checks>\d+), Failed: (?P<failed>\d+)\n\[Duration: (?P<duration>\d+) ms\]\n", re.DOTALL)


applied = []
translated = {}
if args.translate:
	# Hack for Debian / Ubuntu to match library on identical version number
	regex_status = re.compile(r"^(?:SUCCESS|IGNORED) .*? libexpat\.so.* at (?P<time>.+)$")
	path = os.path.join(args.directory, 'status.log')
	if not os.path.isfile(path):
		print("status.log' missing (but required for translation)", file=sys.stderr)
		sys.exit(1)
	with open(path, 'r') as file:
		for line in file:
			match = regex_status.match(line)
			if match:
				applied.append(parse(match.group('time')).replace(microsecond=0))
	applied.sort()

	regex_link = re.compile(r"^\[(?P<time>.*?)\] Linking .*/(?P<library>[^/]+)$")
	path = os.path.join(args.directory, 'link.log')
	if not os.path.isfile(path):
		print("link.log missing (but required for translation)", file=sys.stderr)
		sys.exit(1)
	with open(path, 'r') as file:
		for line in file:
			match = regex_link.match(line)
			if match:
				time = parse(match.group('time'))
				real = [a for a in applied if a > time]
				if real:
					translated[real[0]] = match.group('library').strip()
				else:
					print(f"No apply time found for {match.group('library')}", file=sys.stderr)

run_files = []
for filename in os.listdir(args.directory):
	path = os.path.join(args.directory, filename)
	if os.path.isfile(path) and regex_file.match(filename):
		run_files.append(path)

precision = 1
start = 0
run_files.sort()
versions = []
for path in run_files:
	start = start + 1
	if start == 1:
		print("[start]")
	else:
		print("[restart]")

	summary={}
	with open(path, 'r') as file:
		for match in regex_run.finditer(file.read()):
			version = match.group("version")
			time = utc.localize(parse(match.group("time")))
			failed = int(match.group("failed"))
			duration = int(match.group("duration"))

			if args.translate:
				real = [a for a in applied if a <= time]
				if real and real[-1] in translated:
					version = translated[real[-1]]

			if not version in summary:
				summary[version] = {
					'checks': int(match.group("checks")),
					'failed': failed,
					'time': [ time ],
					'duration': [ duration ],
				}
				versions.append(version)
			else:
				if summary[version]['failed'] < failed:
					summary[version]['failed'] = failed
				summary[version]['time'].append(time),
				summary[version]['duration'].append(duration),

	for version in natsort.natsorted(summary.keys()):
		print(f"{version} (used in {start}. start of test application)")
		print(f"\ttest case runs: {len(summary[version]['time'])} ({summary[version]['time'][0]} - {summary[version]['time'][-1]})")
		print(f"\tnumber of test cases per run: {summary[version]['checks']}")
		print(f"\tmax. number of failed test cases in a run: {summary[version]['failed']}")
		# duration = [run] time in table
		print(f"\tmean / median run time: {round(statistics.mean(summary[version]['duration']), precision)}ms / {round(statistics.median(summary[version]['duration']), precision)}ms")
		if len(summary[version]['duration']) > 1:
			print(f"\tstandard deviation of run time: {round(statistics.stdev(summary[version]['duration']), precision)}ms")
		print()


print()
print("**Summary**")
success = len(versions) - start
total = len(versions) - 1  # first version does not count
if total > 0:
	print(f"Updated {success} / {total} ({round(success * 100 / total)}%) versions")
else:
	print("No updates possible")

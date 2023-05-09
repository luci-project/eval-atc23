#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import sys
import argparse
import statistics
from dateutil.parser import parse
import pytz

utc=pytz.UTC

parser = argparse.ArgumentParser()
parser.add_argument("directory", help="directory containing the log files of the test")
args = parser.parse_args()

regex_file = re.compile(r"^run-[0-9_-]{19}\.err$")
regex_run = re.compile(r"^\[(?P<time>[^@]+) @ (?P<tid>\d+)\] /.*/(?P<test>[^/]+) run \d+ with result (?P<result>\d+) took (?P<duration>\d+) us$")


applied = []
translated = {}
regex_status = re.compile(r"^(?:SUCCESS|IGNORED) .*? libcrypt\.so.* at (?P<time>.+)$")
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
		while line := file.readline():
			match = regex_run.match(line)
			if match:
				time = utc.localize(parse(match.group("time")))
				test = match.group("test")
				failed = int(match.group("result")) != 0
				duration = int(match.group("duration"))

				real = [a for a in applied if a <= time]
				if real and real[-1] in translated:
					version = translated[real[-1]]
				else:
					continue

				if not version in summary:
					summary[version] = {}
					versions.append(version)

				if not test in summary[version]:
					summary[version][test] = {
						'failed': 0,
						'time': [ ],
						'duration': [ ],
					}

				if int(match.group("result")) != 0:
					summary[version][test]['failed'] = summary[version][test]['failed'] + 1
				summary[version][test]['time'].append(time)
				summary[version][test]['duration'].append(duration)


	for version in summary:
		print(f"{version} (used in {start}. start of test application)")
		failed = 0
		for test in sorted(summary[version].keys()):
			num = len(summary[version][test]['time'])
			if summary[version][test]['failed'] > 0:
				failed = failed + 1
			print(f"\t{test} failed {summary[version][test]['failed']} / {num} ({round(100 * summary[version][test]['failed'] / num)}%), ", end="")
			if len(summary[version][test]['duration']) > 1:
				print(f"run time mean {round(statistics.mean(summary[version][test]['duration']), precision)}us / median {round(statistics.median(summary[version][test]['duration']), precision)}us (SD {round(statistics.stdev(summary[version][test]['duration']), precision)}us)")
			else:
				print(f"run time {summary[version][test]['duration'][0]}us")
		print(f"\t(total failed {failed} / {len(summary[version].keys())} tests)")
		print()


print()
print("**Summary**")
success = len(versions) - start
total = len(versions) - 1  # first version does not count
if total > 0:
	print(f"Updated {success} / {total} ({round(success * 100 / total)}%) versions")
else:
	print("No updates possible")

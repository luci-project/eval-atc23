#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
from pathlib import Path
from natsort import natsorted, ns

if len(sys.argv) <= 1:
	print(f"Usage: {sys.argv[0]} [DIR]", file=sys.stderr)
	sys.exit(1)
else:
	vers=set()
	base=Path(sys.argv[1])
	for d in base.glob("*/"):
		if d.is_dir() and not d.name.startswith('.'):
			vers.add(d)
	for v in natsorted(vers, alg=ns.IGNORECASE, key=str):
		print(v)

"""Capture production-launcher input verification at explicitly requested widths."""
from pathlib import Path
import json
import subprocess
import sys

evidence = Path(__file__).resolve().parent
project = evidence.parents[4]
engine = 'D:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
results = []
for width in sys.argv[1:] or ['1280', '1920']:
    command = [engine, '--path', str(project), '--quit-after', '1200', '--script',
               'res://Tests/WorldMap/capture_ac8_6_eligibility.gd', '--', '--width=' + width]
    process = subprocess.run(command, capture_output=True, text=True, timeout=120)
    output = process.stdout + process.stderr
    result = {'command': command, 'exit': process.returncode,
              'pass': process.returncode == 0 and 'PASS' in output and 'ERROR' not in output}
    (evidence / ('rendered-' + width + '.log')).write_text(json.dumps(result) + '\n' + output, encoding='utf-8')
    print(output, flush=True)
    results.append(result)
raise SystemExit(0 if all(item['pass'] for item in results) else 1)

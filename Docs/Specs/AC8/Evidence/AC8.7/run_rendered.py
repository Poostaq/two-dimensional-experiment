"""Capture actual-input AC8.7 flows at both supported verification sizes."""
import json
from pathlib import Path
import subprocess
import sys

evidence = Path(__file__).resolve().parent
project = evidence.parents[4]
engine = 'D:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
results = []
for width in ([int(sys.argv[1])] if len(sys.argv) > 1 else [1280, 1920]):
    command = [engine, '--path', str(project), '--quit-after', '1800', '--script',
               'res://Tests/WorldMap/capture_ac8_7_placement.gd', '--', '--width=' + str(width)]
    try:
        process = subprocess.run(command, capture_output=True, text=True, timeout=120)
        output = process.stdout + process.stderr
        passed = process.returncode == 0 and 'PASS capture_ac8_7_placement' in output and 'ERROR' not in output
        result = {'width': width, 'command': command, 'exit': process.returncode, 'pass': passed}
    except subprocess.TimeoutExpired as error:
        output = str(error)
        result = {'width': width, 'command': command, 'timeout': True, 'pass': False}
    (evidence / ('rendered-' + str(width) + '.log')).write_text(json.dumps(result) + '\n' + output, encoding='utf-8')
    results.append(result)
    print(width, 'PASS' if result['pass'] else 'FAIL', flush=True)
    if not result['pass']:
        print(output[-8000:], flush=True)
(evidence / 'rendered-results.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
raise SystemExit(0 if all(result['pass'] for result in results) else 1)

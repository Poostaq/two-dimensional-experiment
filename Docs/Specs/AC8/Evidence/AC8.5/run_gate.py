"""Run explicitly named Godot SceneTree suites with captured acceptance evidence."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--prefix', default='gate')
parser.add_argument('--rendered', action='store_true')
parser.add_argument('tests', nargs='+')
args = parser.parse_args()
evidence = Path(__file__).resolve().parent
project = evidence.parents[4]
engine = 'D:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
results = []
for test in args.tests:
    command = [engine]
    if not args.rendered:
        command.append('--headless')
    command += ['--path', str(project), '--quit-after', '1800', '--script', 'res://Tests/' + test + '.gd']
    try:
        process = subprocess.run(command, capture_output=True, text=True, timeout=120)
        output = process.stdout + process.stderr
        passed = process.returncode == 0 and 'PASS' in output and 'ERROR' not in output
        result = {'test': test, 'command': command, 'exit': process.returncode, 'pass': passed}
    except subprocess.TimeoutExpired as error:
        output = str(error)
        result = {'test': test, 'command': command, 'timeout': True, 'pass': False}
    (evidence / (args.prefix + '-' + test.split('/')[-1] + '.log')).write_text(
        json.dumps(result) + '\n' + output, encoding='utf-8')
    results.append(result)
    print(test, 'PASS' if result['pass'] else 'FAIL', flush=True)
    if not result['pass']:
        print(output[-8000:], flush=True)
(evidence / (args.prefix + '-results.json')).write_text(json.dumps(results, indent=2), encoding='utf-8')
raise SystemExit(0 if all(result['pass'] for result in results) else 1)

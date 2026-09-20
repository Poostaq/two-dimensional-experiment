"""Run each AC8.7 writer and reader in separate Godot processes."""
import json
from pathlib import Path
import subprocess

evidence = Path(__file__).resolve().parent
project = evidence.parents[4]
engine = 'D:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
results = []
for scenario in ['add', 'replace', 'failed_add', 'failed_replace', 'retry_add', 'retry_replace', 'discard_add', 'discard_replace']:
    for mode in ['writer', 'reader']:
        command = [engine, '--headless', '--path', str(project), '--quit-after', '1800', '--script',
                   'res://Tests/Run/test_ac8_7_placement_restart.gd', '--', '--mode=' + mode, '--case=' + scenario]
        try:
            process = subprocess.run(command, capture_output=True, text=True, timeout=120)
            output = process.stdout + process.stderr
            passed = process.returncode == 0 and 'PASS test_ac8_7_placement_restart' in output and 'ERROR' not in output
            result = {'case': scenario, 'mode': mode, 'command': command, 'exit': process.returncode, 'pass': passed}
        except subprocess.TimeoutExpired as error:
            output = str(error)
            result = {'case': scenario, 'mode': mode, 'command': command, 'timeout': True, 'pass': False}
        (evidence / ('restart-' + scenario + '-' + mode + '.log')).write_text(json.dumps(result) + '\n' + output, encoding='utf-8')
        results.append(result)
        print(scenario, mode, 'PASS' if result['pass'] else 'FAIL', flush=True)
        if not result['pass']:
            print(output[-8000:], flush=True)
            break
(evidence / 'restart-results.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
raise SystemExit(0 if len(results) == 16 and all(result['pass'] for result in results) else 1)

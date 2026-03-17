#!/bin/sh
# run_all.sh — Run all Flutter tests with clean, parseable output.
#
# The default `flutter test` reporter uses \r-based progress animation that
# produces a single giant line, triggering output truncation in CLI tools.
# This wrapper uses the JSON reporter and parses it into a concise summary.
#
# Usage:
#   cd banana_split_flutter && sh tests/run_all.sh            # summary only
#   cd banana_split_flutter && sh tests/run_all.sh --verbose   # list each test name
#
# Exit code: 0 if all pass, 1 if any fail.

set -e

VERBOSE=0
if [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
  VERBOSE=1
fi

echo "=== Banana Split Flutter Test Suite ==="
echo ""

flutter test --reporter json 2>/dev/null | python3 -c "
import sys, json

verbose = $VERBOSE
passed = failed = errors = 0
fail_details = []
test_names = {}  # id -> name
suite_names = {} # suite id -> path

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        evt = json.loads(line)
    except:
        continue

    t = evt.get('type')

    if t == 'suite':
        s = evt.get('suite', {})
        suite_names[s.get('id')] = s.get('path', '')

    elif t == 'testStart':
        test = evt.get('test', {})
        tid = test.get('id')
        name = test.get('name', '')
        test_names[tid] = name

    elif t == 'testDone':
        tid = evt.get('testID')
        result = evt.get('result')
        name = test_names.get(tid, f'test#{tid}')
        if result == 'success':
            passed += 1
            if verbose:
                print(f'  PASS  {name}')
        elif result == 'failure':
            failed += 1
            print(f'  FAIL  {name}')
        elif result == 'error':
            errors += 1
            print(f'  ERROR {name}')

    elif t == 'error':
        tid = evt.get('testID')
        name = test_names.get(tid, f'test#{tid}')
        msg = evt.get('error', '').split(chr(10))[0][:200]
        fail_details.append(f'  {name}: {msg}')

    elif t == 'done':
        break

# Print failure details
if fail_details:
    print('')
    print('Failure details:')
    for d in fail_details:
        print(d)

# Summary
total = passed + failed + errors
print('')
if failed == 0 and errors == 0:
    print(f'All {passed} tests passed.')
else:
    print(f'Results: {passed} passed, {failed} failed, {errors} errors (total {total})')

sys.exit(1 if (failed + errors) > 0 else 0)
"

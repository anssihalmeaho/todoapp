
# Integration testing

Integration tests test **todoapp** server as blackbox via HTTP API.

In test one typical successful scenario is implemented so that it uses
several todoapp API's.

## Pre-conditions

Create **funla** executable for FunL interpreter if not done already:
https://github.com/anssihalmeaho/funl

Test assume that todoapp server address is `localhost:8003`

## Test execution

Do following steps:

1. Compile and start **todoapp** server as its own process
2. In command shell run test with **funla** interpreter, for example:`funla ./integ_test/integ_tester.fnl`
3. If test is passed `'OK'` is printed (`'FAILED'` in case of failure)
4. Stop **todoapp** server process (by CTRL-C etc.)
5. Possibly delete **tasks.db** file (optional)


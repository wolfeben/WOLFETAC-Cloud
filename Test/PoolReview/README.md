# Pool Review temporary-fixture tests

This separate AL test extension contains 18 tests of the read-only rule engine. It uses only the review extension's temporary tables. There is no Microsoft test-toolkit dependency; assertion failures use Error.

The cases cover selected-group scope, ownership in both directions, legitimate blank-pool entries, missing ownership, raw reversal-sign cancellation, kilogram basis warnings, recovery sign and reversal scope, processed-state severity, unresolved source attribution, duplicate/legacy PR matches, payment completion, complete classification comparisons, matched-invoice group ownership, wrong allocation among multiple PR matches, incomplete classification coverage, filtered global issue-number allocation and preservation of adapter coverage counters.

Compilation verifies AL types and contracts. It does not execute these tests. Run codeunit 58890 in an approved Business Central sandbox test runner after installing the matching TAC Pool Review extension and this test app. No installation or execution is authorized by merely building the package.

These tests deliberately cover pure rules only. The live schema/read adapter, invoice attribution, source permissions and UI require separate sandbox acceptance tests against the intended Pool Master version.




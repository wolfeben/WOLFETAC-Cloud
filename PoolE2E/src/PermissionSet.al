permissionset 59350 "WLF POOL E2E"
{
    Assignable = true;
    Caption = 'Pool sandbox test bench';
    Permissions = tabledata "WLF Pool E2E Case" = RIMD,
        table "WLF Pool E2E Case" = X,
        page "WLF Pool E2E Test Bench" = X,
        codeunit "WLF Pool E2E Management" = X,
        codeunit "WLF Pool E2E Execute" = X,
        page "WLF Pool Week Preflight" = X,
        codeunit "WLF Pool Week Preflight" = X;
    // Standard and engine permissions still govern every source and posting operation.
}

permissionset 59300 "WLF POOL REVIEW"
{
    Assignable = true;
    Caption = 'WOLFE Pool Review';
    Permissions =
        tabledata "WLF Pool Review Group" = RIMD,
        tabledata "WLF Pool Review Issue" = RIMD,
        tabledata "WLF Pool Review Fact" = RIMD,
        tabledata "WLF Pool Review Field" = RIMD,
        table "WLF Pool Review Group" = X,
        table "WLF Pool Review Issue" = X,
        table "WLF Pool Review Fact" = X,
        table "WLF Pool Review Field" = X,
        page "WLF Pooling Review" = X,
        page "WLF Pooling Workspace" = X,
        page "WLF Pool Review Issues" = X,
        page "WLF Pool Review Evidence" = X,
        page "WLF Pool Review Ledger" = X,
        codeunit "WLF Pool Review Read" = X,
        codeunit "WLF Pool Review Rules" = X,
        codeunit "WLF Pool Review Export" = X;
}

permissionset 58000 "SAL VIEW"
{
    Assignable = false;
    Caption = 'SAL View';

    Permissions =
        tabledata "SAL Setup" = r,
        tabledata "SAL Plan Header" = r,
        tabledata "SAL Plan Source" = r,
        tabledata "SAL Plan Pallet" = r,
        tabledata "SAL Plan Component" = r,
        tabledata "SAL Plan Event" = r,
        table "SAL Setup" = X,
        table "SAL Plan Header" = X,
        table "SAL Plan Source" = X,
        table "SAL Plan Pallet" = X,
        table "SAL Plan Component" = X,
        table "SAL Plan Event" = X,
        page "SAL Stock & Logistics Planner" = X;
}

permissionset 58001 "SAL PLANNER"
{
    Assignable = true;
    Caption = 'SAL Planner';
    IncludedPermissionSets = "SAL VIEW";

    Permissions =
        tabledata "SAL Plan Header" = RIMD,
        tabledata "SAL Plan Source" = RIMD,
        tabledata "SAL Plan Pallet" = RIMD,
        tabledata "SAL Plan Component" = RIMD,
        tabledata "SAL Plan Event" = RI;
}

permissionset 58002 "SAL ADMIN"
{
    Assignable = true;
    Caption = 'SAL Administrator';
    IncludedPermissionSets = "SAL PLANNER";

    Permissions =
        tabledata "SAL Setup" = RIMD;
}

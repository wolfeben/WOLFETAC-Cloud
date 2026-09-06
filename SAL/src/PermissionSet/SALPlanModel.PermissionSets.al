permissionset 58000 "SAL VIEW"
{
    Assignable = true;
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
        page "SAL Plans" = X,
        page "SAL Plan Details" = X,
        page "SAL Plan Pallets" = X,
        page "SAL Pallet Components" = X,
        page "SAL Plan Events" = X,
        page "SAL Stock & Logistics Monitor" = X,
        page "SAL Stock & Logistics Planner" = X,
        page "SAL Freight & Arrivals Monitor" = X,
        page "SAL Plan Sources" = X;
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
        tabledata "SAL Plan Event" = RI,
        tabledata "Sales Header" = r,
        tabledata "Sales Line" = r,
        tabledata "Transfer Header" = r,
        tabledata "Transfer Line" = r,
        tabledata Customer = r,
        tabledata Item = r,
        tabledata "Item Variant" = r,
        tabledata "Item Unit of Measure" = r,
        tabledata Location = r,
        codeunit "SAL Demand Management" = X,
        codeunit "SAL Plan Management" = X,
        codeunit "SAL Plan Validation" = X,
        page "Sales Lines" = X,
        page "Transfer Lines" = X;
}

permissionset 58002 "SAL ADMIN"
{
    Assignable = true;
    Caption = 'SAL Administrator';
    IncludedPermissionSets = "SAL PLANNER";

    Permissions =
        tabledata "SAL Setup" = RIMD,
        tabledata "No. Series" = r,
        page "SAL Setup" = X;
}

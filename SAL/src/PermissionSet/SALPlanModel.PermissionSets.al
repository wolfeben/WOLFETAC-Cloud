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
        tabledata "SAL Plan Fill Member" = r,
        tabledata "SAL Product Group" = r,
        tabledata "SAL Product Group Member" = r,
        tabledata "SAL Template Rule" = r,
        tabledata "SAL Pallet Template" = r,
        tabledata "SAL Facility Feedback" = r,
        tabledata "Shipping Agent" = r,
        tabledata "Shipping Agent Services" = r,
        table "SAL Setup" = X,
        table "SAL Plan Header" = X,
        table "SAL Plan Source" = X,
        table "SAL Plan Pallet" = X,
        table "SAL Plan Component" = X,
        table "SAL Plan Event" = X,
        table "SAL Plan Fill Member" = X,
        table "SAL Product Group" = X,
        table "SAL Product Group Member" = X,
        table "SAL Template Rule" = X,
        table "SAL Pallet Template" = X,
        table "SAL Facility Feedback" = X,
        page "SAL Plan Details" = X,
        page "SAL Plan Pallets" = X,
        page "SAL Pallet Components" = X,
        page "SAL Plan Events" = X,
        page "SAL Stock & Logistics Monitor" = X,
        page "SAL Plan Sources" = X,
        page "SAL Plan Fill Members" = X;
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
        tabledata "SAL Plan Fill Member" = RIMD,
        tabledata "SAL Product Group" = r,
        tabledata "SAL Product Group Member" = r,
        tabledata "SAL Template Rule" = r,
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
        codeunit "SAL Allocation Management" = X,
        codeunit "SAL Publish Management" = X,
        page "SAL Plans" = X,
        page "SAL Stock & Logistics Planner" = X,
        page "SAL Freight & Arrivals Monitor" = X,
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
        tabledata "SAL Product Group" = RIMD,
        tabledata "SAL Product Group Member" = RIMD,
        tabledata "SAL Template Rule" = RIMD,
        tabledata "SAL Pallet Template" = RIMD,
        tabledata "No. Series" = r,
        page "SAL Setup" = X,
        page "SAL Product Groups" = X,
        page "SAL Product Group Members" = X,
        page "SAL Template Rules" = X,
        page "SAL Pallet Templates" = X;
}

permissionset 58003 "SAL INTEGRATION"
{
    Assignable = true;
    Caption = 'SAL Integration';

    Permissions =
        tabledata "SAL Plan Header" = RM,
        tabledata "SAL Plan Source" = R,
        tabledata "SAL Plan Pallet" = R,
        tabledata "SAL Plan Component" = R,
        tabledata "SAL Facility Feedback" = RI,
        table "SAL Facility Feedback" = X,
        codeunit "SAL Integration Inbound" = X,
        page "SAL Facility Plans API" = X,
        page "SAL Facility Sources API" = X,
        page "SAL Facility Pallets API" = X,
        page "SAL Facility Components API" = X,
        page "SAL Facility Feedback API" = X;
}

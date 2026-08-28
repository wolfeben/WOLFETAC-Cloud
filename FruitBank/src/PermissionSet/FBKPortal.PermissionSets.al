permissionset 58680 "FBK PORTAL READ"
{
    Assignable = false;
    Caption = 'FruitBank Portal Read';

    Permissions =
        tabledata "FBK Portal Site" = r,
        table "FBK Portal Site Buffer" = X,
        page "FBK Portal Site API" = X,
        codeunit "FBK Read Projection" = X;
}

permissionset 58682 "FBK PORTAL API"
{
    Assignable = true;
    Caption = 'FruitBank Portal API';
    IncludedPermissionSets = "FBK PORTAL READ";
}

permissionset 58683 "FBK PORTAL ADMIN"
{
    Assignable = true;
    Caption = 'FruitBank Portal Administrator';
    IncludedPermissionSets = "FBK PORTAL READ";

    Permissions =
        tabledata "FBK Portal Site" = RIMD,
        table "FBK Portal Site" = X,
        page "FruitBank Portal Sites" = X;
}

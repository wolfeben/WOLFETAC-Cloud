codeunit 58012 "SAL Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        SALSetup: Record "SAL Setup";
    begin
        SALSetup.EnsureStandardDefaults();
    end;
}

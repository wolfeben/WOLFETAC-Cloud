codeunit 58011 "SAL Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        SALSetup: Record "SAL Setup";
    begin
        SALSetup.EnsureStandardDefaults();
    end;
}

codeunit 58500 "FBK Read Projection"
{
    Permissions = tabledata "FBK Portal Site" = R;

    procedure LoadPortalSites(var PortalSiteBuffer: Record "FBK Portal Site Buffer" temporary)
    var
        PortalSite: Record "FBK Portal Site";
    begin
        PortalSite.ReadIsolation := IsolationLevel::ReadCommitted;
        PortalSite.SetRange(Active, true);
        if not PortalSite.FindSet() then
            exit;

        repeat
            PortalSiteBuffer.Init();
            PortalSiteBuffer.SystemId := PortalSite.SystemId;
            PortalSiteBuffer.Code := PortalSite.Code;
            PortalSiteBuffer."Display Name" := PortalSite."Display Name";
            PortalSiteBuffer."Location Code" := PortalSite."Location Code";
            PortalSiteBuffer."State Code" := PortalSite."State Code";
            PortalSiteBuffer.Active := PortalSite.Active;
            PortalSiteBuffer."Last Modified Date Time" := PortalSite.SystemModifiedAt;
            PortalSiteBuffer.Insert(false, true);
        until PortalSite.Next() = 0;
    end;
}

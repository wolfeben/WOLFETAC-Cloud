page 58650 "FBK Portal Site API"
{
    PageType = API;
    APIPublisher = 'tac';
    APIGroup = 'fruitBank';
    APIVersion = 'v1.0';
    EntityName = 'portalSite';
    EntitySetName = 'portalSites';
    EntityCaption = 'FruitBank Portal Site';
    EntitySetCaption = 'FruitBank Portal Sites';
    SourceTable = "FBK Portal Site Buffer";
    SourceTableTemporary = true;
    ODataKeyFields = SystemId;
    Extensible = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Sites)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                }
                field(code; Rec.Code)
                {
                    Caption = 'Code';
                }
                field(displayName; Rec."Display Name")
                {
                    Caption = 'Display Name';
                }
                field(locationCode; Rec."Location Code")
                {
                    Caption = 'Business Central Location Code';
                }
                field(stateCode; Rec."State Code")
                {
                    Caption = 'State Code';
                }
                field(active; Rec.Active)
                {
                    Caption = 'Active';
                }
                field(lastModifiedDateTime; Rec."Last Modified Date Time")
                {
                    Caption = 'Last Modified Date Time';
                }
            }
        }
    }

    trigger OnOpenPage()
    var
        ReadProjection: Codeunit "FBK Read Projection";
    begin
        ReadProjection.LoadPortalSites(Rec);
    end;
}

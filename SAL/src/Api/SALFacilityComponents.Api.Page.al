page 58153 "SAL Facility Components API"
{
    PageType = API;
    APIPublisher = 'wolfe'; APIGroup = 'sal'; APIVersion = 'v1.0';
    EntityName = 'facilityComponent'; EntitySetName = 'facilityComponents';
    SourceTable = "SAL Plan Component"; ODataKeyFields = SystemId;
    InsertAllowed = false; ModifyAllowed = false; DeleteAllowed = false;

    layout { area(Content) { repeater(Components) {
        field(id; Rec.SystemId) { }
        field(planNo; Rec."Plan No.") { }
        field(versionNo; Rec."Version No.") { }
        field(palletNo; Rec."Pallet No.") { }
        field(lineNo; Rec."Line No.") { }
        field(sourceLineNo; Rec."Source Line No.") { }
        field(itemNo; Rec."Item No.") { }
        field(variantCode; Rec."Variant Code") { }
        field(quantity; Rec.Quantity) { }
        field(unitOfMeasureCode; Rec."Unit of Measure Code") { }
        field(fulfilmentMode; Rec."Fulfilment Mode") { }
        field(fillMemberLineNo; Rec."Fill Member Line No.") { }
    } } }
}

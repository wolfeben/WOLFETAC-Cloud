page 58151 "SAL Facility Sources API"
{
    PageType = API;
    APIPublisher = 'wolfe'; APIGroup = 'sal'; APIVersion = 'v1.0';
    EntityName = 'facilitySource'; EntitySetName = 'facilitySources';
    SourceTable = "SAL Plan Source"; ODataKeyFields = SystemId;
    InsertAllowed = false; ModifyAllowed = false; DeleteAllowed = false;

    layout { area(Content) { repeater(Sources) {
        field(id; Rec.SystemId) { }
        field(planNo; Rec."Plan No.") { }
        field(versionNo; Rec."Version No.") { }
        field(lineNo; Rec."Line No.") { }
        field(sourceType; Rec."Source Type") { }
        field(sourceDocumentNo; Rec."Source Document No.") { }
        field(sourceDocumentLineNo; Rec."Source Document Line No.") { }
        field(priority; Rec.Priority) { }
        field(itemNo; Rec."Item No.") { }
        field(variantCode; Rec."Variant Code") { }
        field(unitOfMeasureCode; Rec."Unit of Measure Code") { }
        field(quantity; Rec.Quantity) { }
        field(fillGroupCode; Rec."Fill Group Code") { }
        field(fillAllowsMixedPallets; Rec."Fill Allows Mixed Pallets") { }
        field(labellingRequirements; Rec."Labelling Requirements") { }
        field(specialConditions; Rec."Special Conditions") { }
        field(shipmentDate; Rec."Shipment Date") { }
        field(freightCompanyCode; Rec."Freight Company Code") { }
        field(freightServiceCode; Rec."Freight Service Code") { }
        field(freightReference; Rec."Freight Reference") { }
    } } }
}

page 58154 "SAL Facility Feedback API"
{
    PageType = API;
    APIPublisher = 'wolfe'; APIGroup = 'sal'; APIVersion = 'v1.0';
    EntityName = 'facilityFeedback'; EntitySetName = 'facilityFeedback';
    SourceTable = "SAL Facility Feedback"; ODataKeyFields = SystemId;
    DelayedInsert = true;
    InsertAllowed = true; ModifyAllowed = false; DeleteAllowed = false;

    layout { area(Content) { repeater(Feedback) {
        field(id; Rec.SystemId) { }
        field(entryNo; Rec."Entry No.") { }
        field(messageId; Rec."Message Id") { }
        field(feedbackType; Rec."Feedback Type") { }
        field(actualPalletId; Rec."Actual Pallet Id") { }
        field(plannedPalletNo; Rec."Planned Pallet No.") { }
        field(itemNo; Rec."Item No.") { }
        field(variantCode; Rec."Variant Code") { }
        field(quantity; Rec.Quantity) { }
        field(unitOfMeasureCode; Rec."Unit of Measure Code") { }
        field(lotNo; Rec."Lot No.") { }
        field(growerCode; Rec."Grower Code") { }
        field(errorMessage; Rec."Error Message") { }
        field(occurredAt; Rec."Occurred At") { }
        field(sourceSystem; Rec."Source System") { }
    } } }
}

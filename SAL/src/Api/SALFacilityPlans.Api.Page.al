page 58150 "SAL Facility Plans API"
{
    PageType = API;
    APIPublisher = 'wolfe'; APIGroup = 'sal'; APIVersion = 'v1.0';
    EntityName = 'facilityPlan'; EntitySetName = 'facilityPlans';
    SourceTable = "SAL Plan Header"; ODataKeyFields = SystemId;
    InsertAllowed = false; ModifyAllowed = false; DeleteAllowed = false;

    layout { area(Content) { repeater(Plans) {
        field(id; Rec.SystemId) { }
        field(planNo; Rec."No.") { }
        field(versionNo; Rec."Version No.") { }
        field(status; Rec.Status) { }
        field(messageId; Rec."Facility Message Id") { }
        field(facilityStatus; Rec."Facility Status") { }
        field(priority; Rec.Priority) { }
        field(requiredFinishDate; Rec."Required Finish Date") { }
        field(dispatchDate; Rec."Dispatch Date") { }
        field(marketerCustomerNo; Rec."Marketer Customer No.") { }
        field(marketer; Rec."Marketer Description") { }
        field(publishedAt; Rec."Facility Published At") { }
    } } }
}

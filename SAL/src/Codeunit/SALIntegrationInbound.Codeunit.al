codeunit 58009 "SAL Integration Inbound"
{
    procedure ApplyFeedback(Feedback: Record "SAL Facility Feedback")
    var
        PlanHeader: Record "SAL Plan Header";
        FeedbackType: Text;
    begin
        PlanHeader.SetRange("Facility Message Id", Feedback."Message Id");
        if not PlanHeader.FindFirst() then
            Error(UnknownMessageErr, Feedback."Message Id");

        FeedbackType := UpperCase(Feedback."Feedback Type");
        case FeedbackType of
            'ACKNOWLEDGED':
                PlanHeader."Facility Status" := PlanHeader."Facility Status"::Acknowledged;
            'PACKING', 'PALLET':
                PlanHeader."Facility Status" := PlanHeader."Facility Status"::Packing;
            'COMPLETE':
                PlanHeader."Facility Status" := PlanHeader."Facility Status"::Complete;
            'ERROR':
                PlanHeader."Facility Status" := PlanHeader."Facility Status"::Error;
            else
                Error(FeedbackTypeErr, Feedback."Feedback Type");
        end;
        PlanHeader."Facility Last Feedback At" := Feedback."Occurred At";
        PlanHeader.Modify(false);
    end;

    var
        FeedbackTypeErr: Label 'Feedback type %1 is not supported.', Comment = '%1 = feedback type';
        UnknownMessageErr: Label 'Facility message %1 does not identify a released SAL plan.', Comment = '%1 = message id';
}

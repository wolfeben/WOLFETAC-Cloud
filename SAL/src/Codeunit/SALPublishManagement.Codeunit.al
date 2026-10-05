codeunit 58003 "SAL Publish Management"
{
    procedure PublishReleasedPlan(var PlanHeader: Record "SAL Plan Header")
    begin
        PlanHeader.TestField(Status, PlanHeader.Status::Released);
        if IsNullGuid(PlanHeader."Facility Message Id") then
            PlanHeader."Facility Message Id" := CreateGuid();
        PlanHeader."Facility Status" := PlanHeader."Facility Status"::Published;
        PlanHeader."Facility Published At" := CurrentDateTime();
        PlanHeader.Modify(false);
    end;
}

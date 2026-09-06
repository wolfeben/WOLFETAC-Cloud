page 58002 "SAL Plan Details"
{
    PageType = Card;
    ApplicationArea = All;
    Caption = 'SAL Plan Details';
    SourceTable = "SAL Plan Header";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            group(Plan)
            {
                Caption = 'Plan';

                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Editable = CanEditPlanNo;
                    Importance = Promoted;
                    ToolTip = 'Specifies the stock and logistics plan number.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Editable = CanEditPlan;
                    Importance = Promoted;
                    ToolTip = 'Specifies a concise description of the plan.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Importance = Promoted;
                    ToolTip = 'Specifies the plan version status.';
                }
                field("Version No."; Rec."Version No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the immutable plan version.';
                }
                field(Priority; Rec.Priority)
                {
                    ApplicationArea = All;
                    Editable = CanEditPlan;
                    Importance = Promoted;
                    ToolTip = 'Specifies the priority from 1 to 10.';
                }
                field("Required Finish Date"; Rec."Required Finish Date")
                {
                    ApplicationArea = All;
                    Editable = CanEditPlan;
                    Importance = Promoted;
                    ToolTip = 'Specifies when the stock must be ready.';
                }
                field("Dispatch Date"; Rec."Dispatch Date")
                {
                    ApplicationArea = All;
                    Editable = CanEditPlan;
                    Importance = Promoted;
                    ToolTip = 'Specifies the planned dispatch date.';
                }
                field("Marketer Customer No."; Rec."Marketer Customer No.")
                {
                    ApplicationArea = All;
                    Editable = CanEditPlan;
                    ToolTip = 'Specifies the customer representing the marketer, when applicable.';
                }
                field("Marketer Description"; Rec."Marketer Description")
                {
                    ApplicationArea = All;
                    Caption = 'Marketer';
                    Editable = CanEditPlan;
                    Importance = Promoted;
                    ToolTip = 'Specifies the confirmed commercial marketer.';
                }
                field("Marketer Confirmed"; Rec."Marketer Confirmed")
                {
                    ApplicationArea = All;
                    Editable = CanEditPlan;
                    ToolTip = 'Specifies that the marketer has been checked.';
                }
            }

            part(Sources; "SAL Plan Sources")
            {
                ApplicationArea = All;
                Caption = 'Demand and routing';
                Editable = CanEditPlan;
                SubPageLink = "Plan No." = field("No."),
                              "Version No." = field("Version No.");
                UpdatePropagation = Both;
            }
            part(Pallets; "SAL Plan Pallets")
            {
                ApplicationArea = All;
                Caption = 'Physical pallet plan';
                Editable = CanEditPlan;
                SubPageLink = "Plan No." = field("No."),
                              "Version No." = field("Version No.");
                UpdatePropagation = Both;
            }
            part(Components; "SAL Pallet Components")
            {
                ApplicationArea = All;
                Caption = 'Selected pallet components';
                Editable = CanEditPlan;
                Provider = Pallets;
                SubPageLink = "Plan No." = field("Plan No."),
                              "Version No." = field("Version No."),
                              "Pallet No." = field("Pallet No.");
                UpdatePropagation = Both;
            }
            part(Events; "SAL Plan Events")
            {
                ApplicationArea = All;
                Caption = 'Activity';
                Editable = false;
                SubPageLink = "Plan No." = field("No."),
                              "Version No." = field("Version No.");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AddDemand)
            {
                ApplicationArea = All;
                Caption = 'Add demand';
                Enabled = CanEditPlan;
                Image = Add;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Select released sales or transfer demand.';

                trigger OnAction()
                var
                    DemandManagement: Codeunit "SAL Demand Management";
                begin
                    CurrPage.SaveRecord();
                    DemandManagement.AddDemand(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(RefreshDemand)
            {
                ApplicationArea = All;
                Caption = 'Refresh demand';
                Enabled = CanEditPlan;
                Image = RefreshLines;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Refresh demand snapshots from Business Central.';

                trigger OnAction()
                var
                    DemandManagement: Codeunit "SAL Demand Management";
                begin
                    CurrPage.SaveRecord();
                    DemandManagement.RefreshDemand(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(ValidatePlan)
            {
                ApplicationArea = All;
                Caption = 'Validate plan';
                Enabled = CanEditPlan;
                Image = Check;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Validate the exact draft version.';

                trigger OnAction()
                var
                    PlanManagement: Codeunit "SAL Plan Management";
                begin
                    CurrPage.SaveRecord();
                    PlanManagement.ValidatePlan(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(ReleasePlan)
            {
                ApplicationArea = All;
                Caption = 'Release plan';
                Enabled = CanEditPlan;
                Image = ReleaseDoc;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Validate and release this Cloud plan version.';

                trigger OnAction()
                var
                    PlanManagement: Codeunit "SAL Plan Management";
                begin
                    CurrPage.SaveRecord();
                    if not Confirm(ReleasePlanQst, false, Rec."No.", Rec."Version No.") then
                        exit;
                    PlanManagement.ReleasePlan(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(CreateNewVersion)
            {
                ApplicationArea = All;
                Caption = 'Create new version';
                Enabled = CanCreateVersion;
                Image = CopyDocument;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Copy a released version into a new editable draft.';

                trigger OnAction()
                var
                    NewPlanHeader: Record "SAL Plan Header";
                    PlanManagement: Codeunit "SAL Plan Management";
                begin
                    PlanManagement.CreateNewVersion(Rec, NewPlanHeader);
                    Page.Run(Page::"SAL Plan Details", NewPlanHeader);
                end;
            }
        }
        area(Navigation)
        {
            action(GraphicalPlanner)
            {
                ApplicationArea = All;
                Caption = 'Graphical planner';
                Image = Planning;
                Promoted = true;
                PromotedCategory = Category4;
                Visible = CanManagePlan;
                ToolTip = 'Return to the widescreen Stock & Logistics Planner.';

                trigger OnAction()
                begin
                    Page.Run(Page::"SAL Stock & Logistics Planner", Rec);
                end;
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        UpdateState();
    end;

    trigger OnAfterGetRecord()
    begin
        UpdateState();
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        Rec.Status := Rec.Status::Draft;
        Rec."Version No." := 1;
        UpdateState();
    end;

    local procedure UpdateState()
    begin
        CanManagePlan := Rec.WritePermission();
        IsDraft := Rec.Status = Rec.Status::Draft;
        CanEditPlan := IsDraft and CanManagePlan;
        CanEditPlanNo := CanEditPlan and IsNullGuid(Rec.SystemId);
        CanCreateVersion := (Rec.Status = Rec.Status::Released) and CanManagePlan;
    end;

    var
        CanCreateVersion: Boolean;
        CanEditPlan: Boolean;
        CanEditPlanNo: Boolean;
        CanManagePlan: Boolean;
        IsDraft: Boolean;
        ReleasePlanQst: Label 'Validate and release plan %1 version %2 in Cloud?', Comment = '%1 = plan no., %2 = version no.';
}

page 59350 "WLF Pool E2E Test Bench"
{
    Caption = 'Pooling E2E Test Bench';
    PageType = List;
    SourceTable = "WLF Pool E2E Case";
    UsageCategory = Lists;
    ApplicationArea = All;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    layout
    {
        area(Content)
        {
            group(About)
            {
                ShowCaption = false;
                field(Scope; ScopeText) { ApplicationArea = All; ShowCaption = false; MultiLine = true; Editable = false; }
            }
            repeater(Cases)
            {
                field("Step No."; Rec."Step No.") { ApplicationArea = All; }
                field(Scenario; Rec.Scenario) { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; StyleExpr = StatusStyle; }
                field("Source No."; Rec."Source No.") { ApplicationArea = All; }
                field("Related No."; Rec."Related No.") { ApplicationArea = All; }
                field("Posted Document No."; Rec."Posted Document No.") { ApplicationArea = All; }
                field(Quantity; Rec.Quantity) { ApplicationArea = All; Caption = 'Expected kg / basis'; }
                field("Actual Kg"; Rec."Actual Kg") { ApplicationArea = All; }
                field("Actual Amount"; Rec."Actual Amount") { ApplicationArea = All; Caption = 'Observed pool amount'; }
                field("Expected Result"; Rec."Expected Result") { ApplicationArea = All; }
                field("Actual Result"; Rec."Actual Result") { ApplicationArea = All; }
                field("Prerequisite Step"; Rec."Prerequisite Step") { ApplicationArea = All; }
                field("Last Run"; Rec."Last Run") { ApplicationArea = All; }
            }
            group(Selected)
            {
                Caption = 'Selected test details';
                field(Expected; Rec."Expected Result") { ApplicationArea = All; Caption = 'Expected'; MultiLine = true; }
                field(Actual; Rec."Actual Result") { ApplicationArea = All; Caption = 'Observed'; MultiLine = true; }
                field(TestDate; Rec."Test Date") { ApplicationArea = All; Caption = 'Synthetic batch date'; }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Seed) { Caption = 'Create test dataset'; Image = Create; ApplicationArea = All; Promoted = true; PromotedCategory = Process;
                trigger OnAction() var Mgt: Codeunit "WLF Pool E2E Management"; begin Mgt.Seed(); CurrPage.Update(false); end; }
            action(RunStep) { Caption = 'Run selected step'; Image = Start; ApplicationArea = All; Promoted = true; PromotedCategory = Process;
                trigger OnAction() var Mgt: Codeunit "WLF Pool E2E Management"; begin Mgt.RunStep(Rec."Step No."); CurrPage.Update(false); end; }
            action(RunPacking) { Caption = 'Run packing cases'; Image = Production; ApplicationArea = All;
                trigger OnAction() var Mgt: Codeunit "WLF Pool E2E Management"; begin Mgt.RunPacking(); CurrPage.Update(false); end; }
            action(OpenSource) { Caption = 'Open source'; Image = Navigate; ApplicationArea = All; Promoted = true; PromotedCategory = Process;
                trigger OnAction() var Mgt: Codeunit "WLF Pool E2E Management"; begin Mgt.OpenSource(Rec); end; }
            action(Overview) { Caption = 'Pooling overview'; Image = View; ApplicationArea = All; Promoted = true; PromotedCategory = Process;
                trigger OnAction() begin Hyperlink(GetUrl(ClientType::Web, CompanyName(), ObjectType::Page, 59303)); end; }
            action(ExportResults) { Caption = 'Export results'; Image = Export; ApplicationArea = All;
                trigger OnAction() var Mgt: Codeunit "WLF Pool E2E Management"; begin Mgt.ExportResults(); end; }
        }
    }
    var ScopeText: Text; StatusStyle: Text;
    trigger OnOpenPage() var Mgt: Codeunit "WLF Pool E2E Management";
    begin
        Mgt.CheckTarget();
        ScopeText := 'TEST DATA ONLY | Pool_Sandbox / LIVE APMS | Season ZE2E. Steps use normal BC posting and the installed pooling engine. Completed means the stated step checks passed, not approval to pay. Blocked and mismatch results need review. Existing engine settings are retained. Posting is confined to the named test sources.';
    end;
    trigger OnAfterGetRecord()
    begin
        StatusStyle := 'Standard';
        case Rec.Status of Rec.Status::Completed: StatusStyle := 'Favorable'; Rec.Status::Blocked, Rec.Status::Mismatch: StatusStyle := 'Unfavorable'; end;
    end;
}

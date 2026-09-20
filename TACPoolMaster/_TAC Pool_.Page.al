page 50211 "TAC Pool"
{
    ApplicationArea = All;
    Caption = 'TAC Pool';
    PageType = Document;
    SourceTable = "TAC Pool";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("Pool Code"; Rec."Pool Code") { }
                field(Description; Rec.Description) { }
                field("Pool Type"; Rec."Pool Type") { }
                field("Pool Week"; Rec."Pool Week") { }
                field(Status; Rec.Status) { }
                field("Gross Value"; Rec."Gross Value") { }
                field(Variety; Rec."Variety Code") { }
                field(Season; Rec."Season Code") { }
                field("Provisional Count"; Rec."Provisional Count") { }
                field("Net Value"; Rec."Net Value") { }
                field("Total Kilograms"; Rec."Total Kilograms") { }
                field("Grower No."; Rec."Grower No.") { }
                field("Payment Model"; Rec."Payment Model") { }
            }
            part(PoolLedger; "TAC Pool Ledger Subform")
            {
                SubPageLink = "Pool Code" = field("Pool Code");
            }
        }
    }
    actions
    {
        area(Processing)
        {
            Group(Close)
            {
                Caption = 'Close';
                action(ProvisionalClose)
                {
                    ApplicationArea = All;
                    Caption = 'Provisional Close';
                    Image = Close;
                    ToolTip = 'Perform a provisional close for the pool.';
                    trigger OnAction()
                    var
                        PoolMgt: Codeunit "TAC Post Pool";
                    begin
                        PoolMgt.ProvisionalClose(Rec."Pool Code", Rec."Close Sequence" + 1);
                        CurrPage.Update();
                    end;
                }
                action(FinalClose)
                {
                    ApplicationArea = All;
                    Caption = 'Final Close';
                    Image = Close;
                    ToolTip = 'Perform a final close for the pool.';
                    trigger OnAction()
                    var
                        PoolMgt: Codeunit "TAC Post Pool";
                    begin
                        PoolMgt.FinalClose(Rec."Pool Code", Rec."Close Sequence" + 1);
                        CurrPage.Update();
                    end;
                }
            }
        }
    }
}

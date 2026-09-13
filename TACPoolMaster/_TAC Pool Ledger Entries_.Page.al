page 50208 "TAC Pool Ledger Entries"
{
    ApplicationArea = All;
    Caption = 'Pool Ledger Entries';
    PageType = List;
    SourceTable = "TAC Pool Ledger Entry";
    UsageCategory = History;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Entry No."; Rec."Entry No.")
                {
                }
                field("Pool Code"; Rec."Pool Code")
                {
                }
                field("Entry Type"; Rec."Entry Type")
                {
                }
                field("Transaction Type"; Rec."Trans Type Code")
                {
                }
                field("Posting Date"; Rec."Posting Date")
                {
                }
                field("Document Type"; Rec."Document Type")
                {
                }
                field("Document No."; Rec."Document No.")
                {
                }
                field("Source Consignment No."; Rec."Source Consignment No.")
                {
                }
                field("Grower No."; Rec."Grower No.")
                {
                }
                field("Item No."; Rec."Item No.")
                {
                }
                field(Quantity; Rec.Quantity)
                {
                }
                field("Quantity (Kg)"; Rec."Quantity (Kg)")
                {
                }
                field(Amount; Rec.Amount)
                {
                }
                field("GST Amount"; Rec."VAT Amount")
                {
                }
                field("GST Prod. Posting Group"; Rec."VAT Prod. Posting Group")
                {
                }
                field("Applied Fuel Surcharge %"; Rec."Applied Fuel Surcharge %")
                {
                }
                field("Applied Pallet Space Rate"; Rec."Applied Pallet Space Rate")
                {
                }
                field("Charge Level"; Rec."Charge Level")
                {
                }
                field("G/L Entry No."; Rec."G/L Entry No.")
                {
                }
                field("User ID"; Rec."User ID")
                {
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Dimensions)
            {
                AccessByPermission = TableData Dimension=R;
                ApplicationArea = Dimensions;
                Caption = 'Dimensions';
                Image = Dimensions;
                ShortCutKey = 'Alt+D';
                ToolTip = 'View dimensions that are assigned to this pool ledger entry.';

                trigger OnAction()
                var
                    DimMgt: Codeunit DimensionManagement;
                begin
                    DimMgt.ShowDimensionSet(Rec."Dimension Set ID", StrSubstNo('%1 %2', Rec.TableCaption(), Rec."Entry No."));
                end;
            }
        }
    }
}

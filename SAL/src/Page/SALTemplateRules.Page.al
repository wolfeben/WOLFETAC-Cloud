page 58011 "SAL Template Rules"
{
    PageType = List;
    SourceTable = "SAL Template Rule";
    DelayedInsert = true;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'SAL Pallet Allocation Rules';
    AdditionalSearchTerms = 'SAL,Pallet,Customer,Ship-to,Allocation';

    layout
    {
        area(Content)
        {
            repeater(Rules)
            {
                field(Code; Rec.Code) { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field(Active; Rec.Active) { ApplicationArea = All; }
                field("Customer No."; Rec."Customer No.") { ApplicationArea = All; }
                field("Ship-to Code"; Rec."Ship-to Code") { ApplicationArea = All; }
                field("Item No."; Rec."Item No.") { ApplicationArea = All; }
                field("Unit of Measure Code"; Rec."Unit of Measure Code") { ApplicationArea = All; }
                field("Units per Pallet"; Rec."Units per Pallet") { ApplicationArea = All; }
            }
        }
    }
}

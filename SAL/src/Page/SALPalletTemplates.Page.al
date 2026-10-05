page 58010 "SAL Pallet Templates"
{
    PageType = List;
    SourceTable = "SAL Pallet Template";
    Caption = 'SAL Pallet Templates';
    ApplicationArea = All;
    UsageCategory = Administration;
    DelayedInsert = true;
    AdditionalSearchTerms = 'SAL,Pallet Type,CHEP,PMC,AKE,Packing Rule';

    layout
    {
        area(Content)
        {
            repeater(Templates)
            {
                field(Code; Rec.Code) { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Physical Pallet Type"; Rec."Physical Pallet Type") { ApplicationArea = All; }
                field("Unit of Measure Code"; Rec."Unit of Measure Code") { ApplicationArea = All; }
                field("Units per Pallet"; Rec."Units per Pallet") { ApplicationArea = All; }
                field("Mixed Pallet Policy"; Rec."Mixed Pallet Policy") { ApplicationArea = All; }
                field(Active; Rec.Active) { ApplicationArea = All; }
            }
        }
    }
}

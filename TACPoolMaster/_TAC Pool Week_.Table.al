table 50220 "TAC Pool Week"
{
    Caption = 'Pool Week';
    DataClassification = CustomerContent;
    LookupPageId = "TAC Pool Weeks";
    DrillDownPageId = "TAC Pool Weeks";

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            NotBlank = true;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(3; "Season Code"; Code[10])
        {
            Caption = 'Season Code';
        }
        field(4; "Week No."; Integer)
        {
            Caption = 'Week No.';
        }
        field(5; "Start Date"; Date)
        {
            Caption = 'Start Date';
        // Monday of the pool week.
        }
        field(6; "End Date"; Date)
        {
            Caption = 'End Date';
        // Sunday of the pool week.
        }
        field(7; Closed; Boolean)
        {
            Caption = 'Closed';
        // Manual flag.
        }
    }
    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
        key(Season; "Season Code", "Week No.")
        {
        }
    }
}

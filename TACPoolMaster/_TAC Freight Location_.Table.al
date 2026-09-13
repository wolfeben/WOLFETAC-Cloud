table 50201 "TAC Freight Location"
{
    Caption = 'Freight Location';
    DataClassification = CustomerContent;

    fields
    {
        field(1; Code; Code[20])
        {
            Caption = 'Code';
            ToolTip = 'Specifies the unique freight location code.';
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            ToolTip = 'Specifies the freight location description.';
        }
        field(3; "Location Type"; Option)
        {
            Caption = 'Location Type';
            OptionMembers = Origin, Destination, Both;
            ToolTip = 'Specifies whether the freight location is used as an origin, destination, or both.';
        }
        field(4; State; Code[10])
        {
            Caption = 'State';
            ToolTip = 'Specifies the state for the freight location.';
        }
        field(5; "Is Export"; Boolean)
        {
            Caption = 'Is Export';
            ToolTip = 'Specifies whether this freight location is an export destination.';
        }
        field(6; "BC Location Code"; Code[10])
        {
            Caption = 'BC Location Code';
            TableRelation = Location.Code;
            ToolTip = 'Specifies an optional linked standard Business Central location code.';
        }
        field(7; Blocked; Boolean)
        {
            Caption = 'Blocked';
            ToolTip = 'Specifies whether this freight location is blocked from use.';
        }
    }
    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }
    }
}

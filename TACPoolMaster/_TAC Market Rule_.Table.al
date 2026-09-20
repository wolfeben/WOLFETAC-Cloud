table 50212 "TAC Market Rule"
{
    Caption = 'Market Rule';
    DataClassification = CustomerContent;

    fields
    {
        field(1; Code; Code[20])
        {
            Caption = 'Code';
            ToolTip = 'Specifies the market rule code.';
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            ToolTip = 'Specifies the market rule description.';
        }
        field(3; "Rule Type"; Option)
        {
            Caption = 'Rule Type';
            OptionMembers = Domestic,Export;
            ToolTip = 'Specifies whether this rule applies to domestic or export markets.';
        }
        field(4; "Requires Expiry Date"; Boolean)
        {
            Caption = 'Requires Expiry Date';
            ToolTip = 'Specifies whether this market rule requires an expiry date when assigned to a grower.';
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
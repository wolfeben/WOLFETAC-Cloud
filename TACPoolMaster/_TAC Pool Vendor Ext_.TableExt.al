tableextension 50244 "TAC Pool Vendor Ext" extends Vendor
{
    fields
    {
        field(50240; "Is Grower"; Boolean)
        {
            Caption = 'Is Grower';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies whether this vendor is treated as a grower for pooling workflows and validations.';
        }
        field(50241; "Grower Pool Type"; Enum "TAC Grower Pool Type")
        {
            Caption = 'Grower Pool Type';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the pool routing type for this grower (Internal, External, or Contract Pack/Grower).';
        }
        field(50242; "Default Pool Type"; Code[10])
        {
            Caption = 'Default Pool Type';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies an optional default pool type override used during pool resolution.';
        }
        field(50243; "Accreditation Dimension"; Code[20])
        {
            Caption = 'Accreditation Dimension';
            ToolTip = 'Specifies the optional dimension value used to track accreditation for this grower.';
        }
    }
}
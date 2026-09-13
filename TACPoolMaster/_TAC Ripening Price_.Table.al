table 50215 "TAC Ripening Price"
{
    Caption = 'Ripening Price';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            ToolTip = 'Specifies the customer number for the ripening price.';
        }
        field(2; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            ToolTip = 'Specifies the item number for the ripening price.';
        }
        field(3; "Unit of Measure Code"; Code[20])
        {
            Caption = 'Unit of Measure Code';
            ToolTip = 'Specifies the unit of measure code for the ripening price.';
        }
        field(4; "Unit Price"; Decimal)
        {
            Caption = 'Unit Price';
            ToolTip = 'Specifies the unit price for the ripening price.';
        }
        field(5; "Starting Date"; Date)
        {
            Caption = 'Starting Date';
            ToolTip = 'Specifies the starting date for the ripening price.';
        }
        field(6; Active; Boolean)
        {
            Caption = 'Active';
            ToolTip = 'Specifies whether the ripening price is active.';

            trigger OnValidate()
            var
                ExistingPrice: Record "TAC Ripening Price";
            begin
                if Active then begin
                    ExistingPrice.SetRange("Customer No.", "Customer No.");
                    ExistingPrice.SetRange("Item No.", "Item No.");
                    ExistingPrice.SetRange("Unit of Measure Code", "Unit of Measure Code");
                    ExistingPrice.SetRange(Active, true);
                    if ExistingPrice.FindFirst()then Error('An active ripening price already exists for this combination of customer, item, and unit of measure.');
                end;
            end;
        }
    }
    keys
    {
        key(PK; "Customer No.", "Item No.", "Unit of Measure Code", "Starting Date")
        {
            Clustered = true;
        }
    }
}

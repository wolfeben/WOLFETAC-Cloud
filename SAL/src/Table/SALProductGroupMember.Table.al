table 58009 "SAL Product Group Member"
{
    Caption = 'SAL Fill Group Member';
    DataClassification = CustomerContent;
    DataPerCompany = true;

    fields
    {
        field(1; "Group Code"; Code[20])
        {
            Caption = 'Fill Group Code';
            DataClassification = CustomerContent;
            TableRelation = "SAL Product Group".Code;
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = SystemMetadata;
        }
        field(3; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item."No.";

            trigger OnValidate()
            var
                Item: Record Item;
            begin
                if "Item No." = '' then begin
                    Description := '';
                    exit;
                end;

                Item.Get("Item No.");
                Description := CopyStr(Item.Description, 1, MaxStrLen(Description));
                if "Unit of Measure Code" = '' then
                    "Unit of Measure Code" := Item."Base Unit of Measure";
                if xRec."Item No." <> "Item No." then
                    "Variant Code" := '';
            end;
        }
        field(4; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            DataClassification = CustomerContent;
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
        }
        field(5; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code';
            DataClassification = CustomerContent;
            TableRelation = "Item Unit of Measure".Code where("Item No." = field("Item No."));
        }
        field(6; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(7; "Minimum Quantity"; Decimal)
        {
            Caption = 'Minimum Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Specifies the minimum trays or units this member must contribute when the fill group is released.';
        }
        field(8; "Maximum Quantity"; Decimal)
        {
            Caption = 'Maximum Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Specifies the maximum trays or units this member may contribute. Zero means no quantity cap.';
        }
        field(9; "Maximum Pallets"; Decimal)
        {
            Caption = 'Maximum Pallets';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Specifies the maximum pallet-equivalent allocation for this member. Zero means no pallet cap.';
        }
        field(10; "Default Pallet Quantity"; Decimal)
        {
            Caption = 'Default Pallet Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Specifies the trays or units in one standard pallet for this member.';
        }
        field(11; Preference; Integer)
        {
            Caption = 'Preference';
            DataClassification = CustomerContent;
            MinValue = 0;
            ToolTip = 'Specifies the preferred matching order. Lower values are considered first; zero means no preference.';
        }
        field(12; Active; Boolean)
        {
            Caption = 'Active';
            DataClassification = CustomerContent;
            InitValue = true;
            ToolTip = 'Specifies whether this product or size may be selected for a new fill conversion.';
        }
    }

    keys
    {
        key(PK; "Group Code", "Line No.")
        {
            Clustered = true;
        }
        key(ByProduct; "Group Code", "Item No.", "Variant Code", "Unit of Measure Code")
        {
            Unique = true;
        }
        key(ByPreference; "Group Code", Preference, "Line No.")
        {
        }
    }

    trigger OnInsert()
    var
        GroupMember: Record "SAL Product Group Member";
        ProductGroup: Record "SAL Product Group";
    begin
        TestField("Group Code");
        TestField("Item No.");
        TestField("Unit of Measure Code");
        ProductGroup.Get("Group Code");
        if "Line No." = 0 then begin
            GroupMember.SetRange("Group Code", "Group Code");
            if GroupMember.FindLast() then
                "Line No." := GroupMember."Line No." + 10000
            else
                "Line No." := 10000;
        end;
        ValidateBounds();
    end;

    trigger OnModify()
    begin
        if ("Group Code" <> xRec."Group Code") or
           ("Line No." <> xRec."Line No.") or
           ("Item No." <> xRec."Item No.") or
           ("Variant Code" <> xRec."Variant Code") or
           ("Unit of Measure Code" <> xRec."Unit of Measure Code")
        then
            Error(MemberIdentityErr);
        ValidateBounds();
    end;

    trigger OnRename()
    begin
        Error(MemberIdentityErr);
    end;

    local procedure ValidateBounds()
    begin
        if ("Maximum Quantity" > 0) and ("Minimum Quantity" > "Maximum Quantity") then
            Error(MinimumExceedsMaximumErr, "Minimum Quantity", "Maximum Quantity");
        if ("Maximum Pallets" > 0) and ("Default Pallet Quantity" <= 0) then
            Error(PalletQuantityRequiredErr);
    end;

    var
        MemberIdentityErr: Label 'A fill group member product identity cannot be changed. Add a new member and make this member inactive instead.';
        MinimumExceedsMaximumErr: Label 'Minimum quantity %1 cannot exceed maximum quantity %2.', Comment = '%1 = minimum quantity, %2 = maximum quantity';
        PalletQuantityRequiredErr: Label 'Enter a default pallet quantity before setting a maximum number of pallets.';
}

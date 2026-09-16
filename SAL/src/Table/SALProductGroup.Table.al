table 58008 "SAL Product Group"
{
    Caption = 'SAL Fill Group';
    DataClassification = CustomerContent;
    DataPerCompany = true;

    fields
    {
        field(1; Code; Code[20])
        {
            Caption = 'Code';
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(3; Active; Boolean)
        {
            Caption = 'Active';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(4; "Marketer Customer No."; Code[20])
        {
            Caption = 'Marketer Customer No.';
            DataClassification = CustomerContent;
            TableRelation = Customer."No.";
            ToolTip = 'Specifies the required marketer for this fill group. A plan can use the group only when its confirmed marketer matches exactly.';
        }
        field(5; "Marketer Description"; Text[100])
        {
            Caption = 'Marketer';
            FieldClass = FlowField;
            CalcFormula = lookup(Customer.Name where("No." = field("Marketer Customer No.")));
            Editable = false;
        }
        field(6; "Allow Mixed Pallets"; Boolean)
        {
            Caption = 'Allow Mixed Pallets';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies whether one physical pallet may contain more than one eligible product or size for this fill group.';
        }
        field(7; "Default Pallet Quantity"; Decimal)
        {
            Caption = 'Default Pallet Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Specifies the default trays or units per pallet when a member does not have its own default.';
        }
    }

    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }
    }

    trigger OnDelete()
    var
        GroupMember: Record "SAL Product Group Member";
        PlanFillMember: Record "SAL Plan Fill Member";
        PlanSource: Record "SAL Plan Source";
    begin
        PlanSource.SetRange("Fill Group Code", Code);
        if not PlanSource.IsEmpty() then
            Error(GroupInUseErr, Code);

        PlanFillMember.SetRange("Group Code", Code);
        if not PlanFillMember.IsEmpty() then
            Error(GroupInUseErr, Code);

        GroupMember.SetRange("Group Code", Code);
        GroupMember.DeleteAll(true);
    end;

    trigger OnRename()
    begin
        Error(GroupIdentityErr);
    end;

    var
        GroupIdentityErr: Label 'A fill group code cannot be renamed. Create a new group and make this group inactive instead.';
        GroupInUseErr: Label 'Fill group %1 is used by a SAL plan and cannot be deleted. Make it inactive instead.', Comment = '%1 = fill group code';
}

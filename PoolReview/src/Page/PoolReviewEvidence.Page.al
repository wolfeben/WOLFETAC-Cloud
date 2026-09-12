page 59302 "WLF Pool Review Evidence"
{
    Caption = 'Pooling Source Evidence';
    PageType = List;
    SourceTable = "WLF Pool Review Field";
    SourceTableTemporary = true;
    ApplicationArea = All;
    UsageCategory = None;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    SourceTableView = sorting("Field No.");

    layout
    {
        area(Content)
        {
            group(Context)
            {
                Caption = 'Source snapshot';
                field(SourceNotes; SourceNotesLbl)
                {
                    ApplicationArea = All;
                    Caption = 'Values shown';
                    MultiLine = true;
                    ToolTip = 'Explains that this page contains read-only source values collected when it was opened, rather than the historical scan values.';
                }
            }
            repeater(Fields)
            {
                field("Field No."; Rec."Field No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Identifies the source field so the team can locate it in the source table.';
                }
                field("Field Name"; Rec."Field Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source field name.';
                }
                field(Value; Rec.Value)
                {
                    ApplicationArea = All;
                    ToolTip = 'Shows the formatted value read from the source. Long values may be truncated to the review field length.';
                }
            }
            group(SelectedField)
            {
                Caption = 'Selected field';
                field(SelectedName; Rec."Field Name")
                {
                    ApplicationArea = All;
                    Caption = 'Field';
                    ToolTip = 'Shows the name of the selected source field.';
                }
                field(SelectedValue; Rec.Value)
                {
                    ApplicationArea = All;
                    Caption = 'Value';
                    MultiLine = true;
                    ToolTip = 'Shows the selected field''s formatted value across multiple lines when needed. The field snapshot can hold up to 2,048 characters.';
                }
            }
        }
    }

    procedure SetFields(var SourceFields: Record "WLF Pool Review Field")
    var
        FieldView: Record "WLF Pool Review Field";
    begin
        Rec.Reset();
        Rec.DeleteAll();
        FieldView.Copy(SourceFields, true);
        FieldView.Reset();
        if FieldView.FindSet() then
            repeat
                Rec := FieldView;
                Rec.Insert();
            until FieldView.Next() = 0;
        Rec.Reset();
        if not Rec.IsEmpty() then
            Rec.FindFirst();
    end;

    var
        SourceNotesLbl: Label 'Read-only source values collected when this window opened. These values may differ from those used by the scan. The source cannot be edited or posted from this page.';
}
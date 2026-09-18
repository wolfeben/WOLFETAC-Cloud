page 59352 "WLF Pool Week Preflight"
{
    Caption = 'Pooling week setup check';
    PageType = Card;
    UsageCategory = Tasks;
    ApplicationArea = All;
    Editable = false;
    layout
    {
        area(Content)
        {
            group(About)
            {
                ShowCaption = false;
                field(Explanation; 'Read-only setup check for the requested 21–27 September 2026 dataset. This page creates no test records and posts no transactions.')
                {
                    ApplicationArea = All;
                    ShowCaption = false;
                    MultiLine = true;
                }
            }
            group(Results)
            {
                field(Contents; Contents)
                {
                    ApplicationArea = All;
                    Caption = 'Setup snapshot';
                    MultiLine = true;
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(RefreshSnapshot)
            {
                Caption = 'Refresh setup check';
                ApplicationArea = All;
                Image = Refresh;
                trigger OnAction()
                begin
                    Contents := Check.Snapshot();
                end;
            }
            action(Download)
            {
                Caption = 'Download setup check';
                ApplicationArea = All;
                Image = Export;
                trigger OnAction()
                begin
                    Check.DownloadSnapshot(Contents);
                end;
            }
        }
    }
    var
        Check: Codeunit "WLF Pool Week Preflight";
        Contents: Text;

    trigger OnOpenPage()
    begin
        Contents := Check.Snapshot();
    end;
}

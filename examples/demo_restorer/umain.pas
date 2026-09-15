unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, uSciRestorer;

type

  { TForm1 }

  TForm1 = class(TForm)
    Panel1: TPanel;
    SciRestorer1: TSciRestorer;
    Splitter1: TSplitter;
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

end.


unit uSciPeriodicTableReg;

{$mode objfpc}{$H+}

interface

procedure Register;

implementation

uses
  Classes, uSciPeriodicTable, uSciPeriodicTableDlg;

procedure Register;
begin
  RegisterComponents('Science', [TSciPeriodicTable, TSciPeriodicTableDlg]);
end;

end.

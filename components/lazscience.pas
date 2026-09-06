{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit LazScience;

{$warn 5023 off : no warning about unused units}
interface

uses
  uSciEdit, uSciPID, uSciReader, uSciReaderDlg, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('uSciEdit', @uSciEdit.Register);
  RegisterUnit('uSciPID', @uSciPID.Register);
  RegisterUnit('uSciReader', @uSciReader.Register);
  RegisterUnit('uSciReaderDlg', @uSciReaderDlg.Register);
end;

initialization
  RegisterPackage('LazScience', @Register);
end.

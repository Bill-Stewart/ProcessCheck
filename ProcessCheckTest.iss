; Copyright (C) 2024 by Bill Stewart (bstewart at iname.com)
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU Lesser General Public License as published by the Free
; Software Foundation; either version 3 of the License, or (at your option) any
; later version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT
; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
; FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
; details.
;
; You should have received a copy of the GNU Lesser General Public License
; along with this program. If not, see https://www.gnu.org/licenses/.

; Inno Setup 6+ test script for ProcessCheck.dll

[Setup]
AppName=ProcessCheckTest
AppVerName=ProcessCheckTest
DefaultDirName={commonpf}\ProcessCheckTest
Uninstallable=false
OutputDir=.
OutputBaseFilename=ProcessCheckTest
PrivilegesRequired=lowest

[Files]
Source: "i386\ProcessCheck.dll";  DestDir: "{app}"; Flags: dontcopy

[Messages]
ButtonCancel=&Close
SetupWindowTitle=ProcessCheck.dll Test

[Code]
var
  ProcessNamePage: TInputQueryWizardPage;

function DLLFindProcess(PathName: string; var Found: DWORD): DWORD;
  external 'FindProcess@files:ProcessCheck.dll stdcall';

function FindProcess(const PathName: string): Boolean;
var
  Found: DWORD;
begin
  result := false;
  if DLLFindProcess(PathName, Found) = 0 then
    result := Found = 1;
end;

procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  Confirm := false;
end;

procedure InitializeWizard();
begin
  ProcessNamePage := CreateInputQueryPage(wpWelcome,
    'Specify Process',
    'What is the full process file name?',
    'Specify the full path and filename of the process, then click Next.');
  ProcessNamePage.Add('&Process name:', false);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  ProcessName: string;
begin
  result := true;
  if CurPageID = ProcessNamePage.ID then
  begin
    result := false;
    ProcessName := Trim(ProcessNamePage.Values[0]);
    if ProcessName = '' then
    begin
      MsgBox('You must specify the process name.', mbError, MB_OK);
      exit;
    end;
    if FindProcess(ProcessName) then
      MsgBox('Process was found.', mbInformation, MB_OK)
    else
      MsgBox('Process was not found.', mbInformation, MB_OK);
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = ProcessNamePage.ID then
    WizardForm.NextButton.Caption := 'T&est'
  else
    WizardForm.NextButton.Caption := SetupMessage(msgButtonNext);
end;

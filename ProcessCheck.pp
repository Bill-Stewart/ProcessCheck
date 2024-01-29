{ Copyright (C) 2024 by Bill Stewart (bstewart at iname.com)

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the Free
  Software Foundation; either version 3 of the License, or (at your option) any
  later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
  details.

  You should have received a copy of the GNU Lesser General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}
{$R *.res}

library ProcessCheck;

uses
  Windows,
  WindowsProcesses;

// Checks if a process is running; returns zero for success, or non-zero for
// failure; if success, Found will be 1 if process was found, or 0 if not
function FindProcess(PathName: PChar; Found: PDWORD): DWORD; stdcall;
var
  WasFound: Boolean;
begin
  result := TestProcess(string(PathName), WasFound);
  if WasFound then
    Found^ := 1
  else
    Found^ := 0;
end;

exports
  FindProcess;

end.

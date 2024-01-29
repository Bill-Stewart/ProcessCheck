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

unit WindowsProcesses;

interface

uses
  Windows;

// Finds a process by full path and file name; returns zero for success, or
// non-zero for failure; Found = true if process found, or false otherwise
function TestProcess(const PathName: string; out Found: Boolean): DWORD;

implementation

const
  TH32CS_SNAPPROCESS = 2;

type
  PROCESSENTRY32W = record
    dwSize:              DWORD;
    cntUsage:            DWORD;
    th32ProcessID:       DWORD;
    th32DefaultHeapID:   ULONG_PTR;
    th32ModuleID:        DWORD;
    cntThreads:          DWORD;
    th32ParentProcessID: DWORD;
    pcPriClassBase:      LONG;
    dwFlags:             DWORD;
    szExeFile:           array[0..MAX_PATH - 1] of WCHAR;
  end;
  TPrivilegeState = (NoPrivilege, Disabled, Enabled);

function CreateToolhelp32Snapshot(DwFlags: DWORD;
  th32ProcessID: DWORD): HANDLE;
  stdcall; external 'kernel32.dll';

function Process32FirstW(hSnapshot: HANDLE;
  var lppe: PROCESSENTRY32W): BOOL;
  stdcall; external 'kernel32.dll';

function Process32NextW(hSnapshot: HANDLE;
  var lppe: PROCESSENTRY32W): BOOL;
  stdcall; external 'kernel32.dll';

// Tests whether SeDebugPrivilege is enabled for the current process
function GetDebugPrivilege(out PrivilegeState: TPrivilegeState): DWORD;
var
  LocalID: LUID;
  TokenHandle: HANDLE;
  pTokenInfo: PTOKEN_PRIVILEGES;
  pPrivileges: ^LUID_AND_ATTRIBUTES;
  TokenInfoSize, BytesNeeded, I: DWORD;
begin
  result := ERROR_SUCCESS;
  if not LookupPrivilegeValueW(nil, // LPCWSTR lpSystemName
    SE_DEBUG_NAME,                  // LPCWSTR lpName
    LocalID) then                   // PLUID   lpLuid
  begin
    result := GetLastError();
    exit;
  end;
  if not OpenProcessToken(GetCurrentProcess(),  // HANDLE  ProcessHandle
    TOKEN_QUERY,                                // DWORD   DesiredAccess
    TokenHandle) then                           // PHANDLE TokenHandle
  begin
    result := GetLastError();
    exit;
  end;
  TokenInfoSize := 0;
  GetTokenInformation(TokenHandle,  // HANDLE                  TokenHandle
    TokenPrivileges,                // TOKEN_INFORMATION_CLASS TokenInformationClass
    nil,                            // LPVOID                  TokenInformation
    TokenInfoSize,                  // DWORD                   TokenInformationLength
    BytesNeeded);                   // PDWORD                  ReturnLength
  result := GetLastError();
  if result = ERROR_INSUFFICIENT_BUFFER then
  begin
    result := ERROR_SUCCESS;
    GetMem(pTokenInfo, BytesNeeded);
    TokenInfoSize := BytesNeeded;
    if GetTokenInformation(TokenHandle,  // HANDLE                  TokenHandle
      TokenPrivileges,                   // TOKEN_INFORMATION_CLASS TokenInformationClass
      pTokenInfo,                        // LPVOID                  TokenInformation
      TokenInfoSize,                     // DWORD                   TokenInformationLength
      BytesNeeded) then                  // PDWORD                  ReturnLength
    begin
      PrivilegeState := NoPrivilege;
      pPrivileges := pTokenInfo^.Privileges;
      for I := 0 to pTokenInfo^.PrivilegeCount - 1 do
      begin
        if pPrivileges^.Luid = LocalID then
        begin
          if (pPrivileges^.Attributes and SE_PRIVILEGE_ENABLED) = 0 then
            PrivilegeState := Disabled
          else
            PrivilegeState := Enabled;
          break;
        end;
        Inc(pPrivileges);
      end;
    end
    else
      result := GetLastError();
    FreeMem(pTokenInfo);
  end;
  CloseHandle(TokenHandle);  // HANDLE hObject
end;

// Enables or disables SeDebugPrivilege for the current process
function AdjustDebugPrivilege(const Enable: Boolean): DWORD;
var
  LocalID: LUID;
  TokenHandle: HANDLE;
  TokenPrivileges: TOKEN_PRIVILEGES;
begin
  if not LookupPrivilegeValueW(nil,  // LPCWSTR lpSystemName
    SE_DEBUG_NAME,                   // LPCWSTR lpName
    LocalID) then                    // PLUID   lpLuid
  begin
    result := GetLastError();
    exit;
  end;
  if not OpenProcessToken(GetCurrentProcess(),  // HANDLE  ProcessHandle
    TOKEN_ADJUST_PRIVILEGES,                    // DWORD   DesiredAccess
    TokenHandle) then                           // PHANDLE TokenHandle
  begin
    result := GetLastError();
    exit;
  end;
  TokenPrivileges.PrivilegeCount := 1;
  TokenPrivileges.Privileges[0].Luid := LocalID;
  if Enable then
    TokenPrivileges.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED
  else
    TokenPrivileges.Privileges[0].Attributes := 0;
  AdjustTokenPrivileges(TokenHandle,  // HANDLE            TokenHandle
    false,                            // BOOL              DisableAllPrivileges
    @TokenPrivileges,                 // PTOKEN_PRIVILEGES NewState
    SizeOf(TokenPrivileges),          // DWORD             BufferLength
    nil,                              // PTOKEN_PRIVILEGES PreviousState
    nil);                             // PDWORD            ReturnLength
  // GetLastError returns ERROR_SUCCESS when AdjustTokenPrivileges
  // succeeded in adjusting all requested privileges
  result := GetLastError();
  CloseHandle(TokenHandle);  // HANDLE hObject
end;

// Gets executable filename for specified process ID; requires enabled 
// SeDebugPrivilege to get the filename for a privileged processes
function GetProcessExecutable(const ProcessID: DWORD): string;
const
  MAX_LEN = 32768;
var
  Access, NumChars: DWORD;
  ProcHandle: HANDLE;
  pName: PChar;
begin
  result := '';
  Access := PROCESS_QUERY_LIMITED_INFORMATION;
  ProcHandle := OpenProcess(Access,  // DWORD dwDesiredAccess
    false,                           // BOOL  bInheritHandle
    ProcessID);                      // DWORD dwProcessId
  if ProcHandle = 0 then
    exit;
  NumChars := MAX_LEN;
  GetMem(pName, NumChars);
  if QueryFullProcessImageNameW(ProcHandle,  // HANDLE hProcess
    0,                                       // DWORD  dwFlags
    pName,                                   // LPWSTR lpExeName
    @NumChars) then                          // PDWORD lpdwSize
  begin
    SetLength(result, NumChars);
    Move(pName^, result[1], NumChars * SizeOf(Char));
  end;
  FreeMem(pName);  
  CloseHandle(ProcHandle);  // HANDLE hObject
end;

function SameText(const S1, S2: string): Boolean;
const
  CSTR_EQUAL = 2;
begin
  result := CompareStringW(GetThreadLocale(),  // LCID    Locale
    LINGUISTIC_IGNORECASE,                     // DWORD   dwCmpFlags
    PChar(S1),                                 // PCNZWCH lpString1
    -1,                                        // int     cchCount1
    PChar(S2),                                 // PCNZWCH lpString2
    -1) = CSTR_EQUAL;                          // int     cchCount2
end;

function TestProcess(const PathName: string; out Found: Boolean): DWORD;
var
  Snapshot: HANDLE;
  ProcessEntry: PROCESSENTRY32W;
  PrivilegeState: TPrivilegeState;
  AdjustedPrivilege: Boolean;
  OK: BOOL;
  Name: string;
begin
  result := ERROR_SUCCESS;
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,  // DWORD dwFlags
    0);                                                     // DWORD th32ProcessID
  if Snapshot = INVALID_HANDLE_VALUE then
  begin
    result := GetLastError();
    exit;
  end;
  ProcessEntry.dwSize := SizeOf(PROCESSENTRY32W);
  if Process32FirstW(Snapshot,  // HANDLE            hSnapshot
    ProcessEntry) then          // LPPROCESSENTRY32W lppe
  begin
    Found := false;
    // Attempt to enable SeDebugPrivilege if not enabled
    if (GetDebugPrivilege(PrivilegeState) = ERROR_SUCCESS) and (PrivilegeState = Disabled) then
      AdjustedPrivilege := AdjustDebugPrivilege(true) = ERROR_SUCCESS
    else
      AdjustedPrivilege := false;
    repeat
      Name := GetProcessExecutable(ProcessEntry.th32ProcessID);
      if (Name <> '') and SameText(Name, PathName) then
      begin
        Found := true;
        break;
      end;
      OK := Process32NextW(Snapshot,  // HANDLE            hSnapshot
        ProcessEntry);                // LPPROCESSENTRY32W lppe
    until not OK;
    // Revert SeDebugPrivilege if changed
    if AdjustedPrivilege then
      AdjustDebugPrivilege(false);
  end
  else
    result := GetLastError();
  CloseHandle(Snapshot);  // HANDLE hObject
end;

begin
end.

# ProcessCheck.dll

ProcessCheck.dll is a Windows DLL (dynamically linked library) that allows an application to check if specified executable is running.

# Author

Bill Stewart - bstewart at iname dot com

# License

ProcessCheck.dll is covered by the GNU Lesser Public License (LPGL). See the file `LICENSE` for details.

# Functions

This section documents the functions exported by ProcessCheck.dll.

---

## FindProcess

The `FindProcess` function checks whether a specified executable file is running.

### Syntax

C/C++:
```
DWORD FindProcess(LPWSTR PathName; PDWORD Found);
```

Pascal:
```
function FindProcess(PathName: UnicodeString; Found: PDWORD): DWORD;
```

### Parameters

`PathName`

A Unicode string containing the full path and filename of the executable.

`Found`

A pointer to a value that gets set to 1 if the executable is running, or 0 if it is not running. This value is undefined if the function fails.

### Return Value

The function returns 0 for success, or non-zero for failure. A non-zero value will be the Windows error code indicating the cause of the error.

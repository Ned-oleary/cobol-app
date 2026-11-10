*> ------------------------------------------------------------
*> libpq connection state and query parameters.
*> Parameter values are NUL-terminated C strings.
*> ------------------------------------------------------------
01  DB-STATE EXTERNAL.
    05  DB-CONN                 USAGE POINTER.
    05  DB-RES                  USAGE POINTER.
    05  DB-OK                   PIC X.
    05  DB-ROWS                 BINARY-LONG.
    05  DB-URL                  PIC X(1024).
    05  DB-ERROR                PIC X(1024).

01  DB-PARAMS EXTERNAL.
    05  DBP-COUNT               BINARY-LONG.
    05  DBP-VALUE               PIC X(262200) OCCURS 3.

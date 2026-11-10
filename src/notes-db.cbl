*> ============================================================
*> notes-db.cbl - PostgreSQL access via libpq.
*> All user data is passed as query parameters ($1, $2, ...),
*> never spliced into SQL text.
*> ============================================================

*> ------------------------------------------------------------
*> DB-CONNECT: open a connection using DB-URL (a libpq conninfo
*> string or postgres:// URI, NUL-terminated).
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. DB-CONNECT.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "db.cpy".
01  WS-ST                       BINARY-LONG.
01  WS-ERRP                     USAGE POINTER.
PROCEDURE DIVISION.
    SET DB-RES TO NULL
    MOVE "N" TO DB-OK
    CALL "PQconnectdb" USING DB-URL RETURNING DB-CONN
    CALL "PQstatus" USING BY VALUE DB-CONN RETURNING WS-ST
    IF WS-ST = 0
        MOVE "Y" TO DB-OK
    ELSE
        CALL "PQerrorMessage" USING BY VALUE DB-CONN RETURNING WS-ERRP
        CALL "DB-COPY-CSTRING" USING WS-ERRP DB-ERROR
        DISPLAY "db: connection failed: " FUNCTION TRIM(DB-ERROR)
            UPON SYSERR
        CALL "PQfinish" USING BY VALUE DB-CONN
        SET DB-CONN TO NULL
    END-IF
    GOBACK.
END PROGRAM DB-CONNECT.

*> ------------------------------------------------------------
*> DB-DISCONNECT
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. DB-DISCONNECT.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "db.cpy".
PROCEDURE DIVISION.
    IF DB-RES NOT = NULL
        CALL "PQclear" USING BY VALUE DB-RES
        SET DB-RES TO NULL
    END-IF
    IF DB-CONN NOT = NULL
        CALL "PQfinish" USING BY VALUE DB-CONN
        SET DB-CONN TO NULL
    END-IF
    GOBACK.
END PROGRAM DB-DISCONNECT.

*> ------------------------------------------------------------
*> DB-COPY-CSTRING: copy a NUL-terminated C string (max 1023
*> bytes) into a space-padded COBOL field. Newlines -> spaces.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. DB-COPY-CSTRING.
DATA DIVISION.
WORKING-STORAGE SECTION.
01  WS-I                        BINARY-LONG.
LINKAGE SECTION.
01  LS-PTR                      USAGE POINTER.
01  LS-OUT                      PIC X(1024).
01  LS-CSTR                     PIC X(1024).
PROCEDURE DIVISION USING LS-PTR LS-OUT.
    MOVE SPACES TO LS-OUT
    IF LS-PTR = NULL
        GOBACK
    END-IF
    SET ADDRESS OF LS-CSTR TO LS-PTR
    *> walk byte by byte so we never read past the terminator
    MOVE 1 TO WS-I
    PERFORM UNTIL WS-I > 1023 OR LS-CSTR(WS-I:1) = X"00"
        IF LS-CSTR(WS-I:1) = X"0A"
            MOVE SPACE TO LS-OUT(WS-I:1)
        ELSE
            MOVE LS-CSTR(WS-I:1) TO LS-OUT(WS-I:1)
        END-IF
        ADD 1 TO WS-I
    END-PERFORM
    GOBACK.
END PROGRAM DB-COPY-CSTRING.

*> ------------------------------------------------------------
*> DB-EXEC: run SQL (NUL-terminated) with DBP-COUNT text params
*> from DBP-VALUE. Result stays in DB-RES; DB-ROWS = row count.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. DB-EXEC.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "db.cpy".
01  WS-PARAM-PTRS.
    05  WS-PP                   USAGE POINTER OCCURS 3.
01  WS-NULL                     USAGE POINTER VALUE NULL.
01  WS-I                        BINARY-LONG.
01  WS-ST                       BINARY-LONG.
01  WS-ERRP                     USAGE POINTER.
LINKAGE SECTION.
01  LS-SQL                      PIC X(8192).
PROCEDURE DIVISION USING LS-SQL.
    MOVE "N" TO DB-OK
    MOVE 0 TO DB-ROWS
    IF DB-RES NOT = NULL
        CALL "PQclear" USING BY VALUE DB-RES
        SET DB-RES TO NULL
    END-IF
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 3
        SET WS-PP(WS-I) TO ADDRESS OF DBP-VALUE(WS-I)
    END-PERFORM

    CALL "PQexecParams" USING
        BY VALUE     DB-CONN
        BY REFERENCE LS-SQL
        BY VALUE     DBP-COUNT
        BY VALUE     WS-NULL
        BY REFERENCE WS-PARAM-PTRS
        BY VALUE     WS-NULL
        BY VALUE     WS-NULL
        BY VALUE     0
        RETURNING DB-RES

    CALL "PQresultStatus" USING BY VALUE DB-RES RETURNING WS-ST
    *> 1 = PGRES_COMMAND_OK, 2 = PGRES_TUPLES_OK
    IF WS-ST = 1 OR WS-ST = 2
        MOVE "Y" TO DB-OK
        CALL "PQntuples" USING BY VALUE DB-RES RETURNING DB-ROWS
    ELSE
        CALL "PQresultErrorMessage" USING BY VALUE DB-RES
            RETURNING WS-ERRP
        CALL "DB-COPY-CSTRING" USING WS-ERRP DB-ERROR
        DISPLAY "db: query failed: " FUNCTION TRIM(DB-ERROR)
            UPON SYSERR
    END-IF
    GOBACK.
END PROGRAM DB-EXEC.

*> ------------------------------------------------------------
*> DB-FIELD: copy result value (ROW, COL; zero-based) into
*> TARGET, truncated to MAX bytes. LEN receives the length.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. DB-FIELD.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "db.cpy".
01  WS-VALP                     USAGE POINTER.
LINKAGE SECTION.
01  LS-ROW                      BINARY-LONG.
01  LS-COL                      BINARY-LONG.
01  LS-TARGET                   PIC X(262144).
01  LS-MAX                      BINARY-LONG.
01  LS-LEN                      BINARY-LONG.
01  LS-VAL                      PIC X(262144).
PROCEDURE DIVISION USING LS-ROW LS-COL LS-TARGET LS-MAX LS-LEN.
    CALL "PQgetlength" USING BY VALUE DB-RES BY VALUE LS-ROW
        BY VALUE LS-COL RETURNING LS-LEN
    IF LS-LEN > LS-MAX
        MOVE LS-MAX TO LS-LEN
    END-IF
    IF LS-LEN > 0
        CALL "PQgetvalue" USING BY VALUE DB-RES BY VALUE LS-ROW
            BY VALUE LS-COL RETURNING WS-VALP
        SET ADDRESS OF LS-VAL TO WS-VALP
        MOVE LS-VAL(1:LS-LEN) TO LS-TARGET(1:LS-LEN)
    END-IF
    GOBACK.
END PROGRAM DB-FIELD.

*> ------------------------------------------------------------
*> DB-INIT-SCHEMA: create the notes table if it is missing.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. DB-INIT-SCHEMA.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "db.cpy".
01  WS-ST                       BINARY-LONG.
01  WS-ERRP                     USAGE POINTER.
01  WS-SQL                      PIC X(1024) VALUE
    "SET client_min_messages = warning; "
  & "CREATE TABLE IF NOT EXISTS notes ("
  & " id bigserial PRIMARY KEY,"
  & " title text NOT NULL,"
  & " body text NOT NULL DEFAULT '',"
  & " created_at timestamptz NOT NULL DEFAULT now(),"
  & " updated_at timestamptz NOT NULL DEFAULT now()); "
  & "CREATE INDEX IF NOT EXISTS notes_updated_at_idx"
  & " ON notes (updated_at DESC);"
  & X"00".
PROCEDURE DIVISION.
    MOVE "N" TO DB-OK
    CALL "PQexec" USING BY VALUE DB-CONN BY REFERENCE WS-SQL
        RETURNING DB-RES
    CALL "PQresultStatus" USING BY VALUE DB-RES RETURNING WS-ST
    IF WS-ST = 1 OR WS-ST = 2
        MOVE "Y" TO DB-OK
    ELSE
        CALL "PQresultErrorMessage" USING BY VALUE DB-RES
            RETURNING WS-ERRP
        CALL "DB-COPY-CSTRING" USING WS-ERRP DB-ERROR
        DISPLAY "db: schema setup failed: " FUNCTION TRIM(DB-ERROR)
            UPON SYSERR
    END-IF
    CALL "PQclear" USING BY VALUE DB-RES
    SET DB-RES TO NULL
    GOBACK.
END PROGRAM DB-INIT-SCHEMA.

*> ------------------------------------------------------------
*> DB-LIST-NOTES: newest-first list into NOTE-LIST, optionally
*> filtered by a case-insensitive substring Q.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. DB-LIST-NOTES.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "db.cpy".
COPY "notes.cpy".
01  WS-ROW                      BINARY-LONG.
01  WS-COL                      BINARY-LONG.
01  WS-MAX                      BINARY-LONG.
01  WS-I                        BINARY-LONG.
01  WS-SQL                      PIC X(1024) VALUE
    "SELECT id, title,"
  & " left(regexp_replace(body, '\s+', ' ', 'g'), 180),"
  & " to_char(updated_at, 'Mon DD, YYYY HH24:MI')"
  & " FROM notes"
  & " WHERE $1 = ''"
  & "    OR strpos(lower(title || ' ' || body), lower($1)) > 0"
  & " ORDER BY updated_at DESC, id DESC LIMIT 200"
  & X"00".
LINKAGE SECTION.
01  LS-Q                        PIC X(2048).
01  LS-Q-LEN                    BINARY-LONG.
PROCEDURE DIVISION USING LS-Q LS-Q-LEN.
    MOVE 0 TO NL-COUNT
    MOVE 1 TO DBP-COUNT
    IF LS-Q-LEN > 0
        MOVE LS-Q(1:LS-Q-LEN) TO DBP-VALUE(1)
    END-IF
    MOVE X"00" TO DBP-VALUE(1)(LS-Q-LEN + 1:1)
    CALL "DB-EXEC" USING WS-SQL
    IF DB-OK NOT = "Y"
        GOBACK
    END-IF

    PERFORM VARYING WS-I FROM 1 BY 1
            UNTIL WS-I > DB-ROWS OR WS-I > NOTE-LIST-MAX
        COMPUTE WS-ROW = WS-I - 1
        MOVE SPACES TO NL-ITEM(WS-I)
        MOVE 0 TO WS-COL
        MOVE 20 TO WS-MAX
        CALL "DB-FIELD" USING WS-ROW WS-COL NL-ID(WS-I) WS-MAX
                              NL-ID-LEN(WS-I)
        MOVE 1 TO WS-COL
        MOVE 1000 TO WS-MAX
        CALL "DB-FIELD" USING WS-ROW WS-COL NL-TITLE(WS-I) WS-MAX
                              NL-TITLE-LEN(WS-I)
        MOVE 2 TO WS-COL
        MOVE 800 TO WS-MAX
        CALL "DB-FIELD" USING WS-ROW WS-COL NL-SNIPPET(WS-I) WS-MAX
                              NL-SNIPPET-LEN(WS-I)
        MOVE 3 TO WS-COL
        MOVE 32 TO WS-MAX
        CALL "DB-FIELD" USING WS-ROW WS-COL NL-UPDATED(WS-I) WS-MAX
                              NL-UPDATED-LEN(WS-I)
        MOVE WS-I TO NL-COUNT
    END-PERFORM
    GOBACK.
END PROGRAM DB-LIST-NOTES.

*> ------------------------------------------------------------
*> DB-GET-NOTE: load note ID into NOTE-CURRENT (NC-FOUND = Y/N).
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. DB-GET-NOTE.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "db.cpy".
COPY "notes.cpy".
01  WS-ROW                      BINARY-LONG VALUE 0.
01  WS-COL                      BINARY-LONG.
01  WS-MAX                      BINARY-LONG.
01  WS-SQL                      PIC X(1024) VALUE
    "SELECT id, title, body,"
  & " to_char(created_at, 'Mon DD, YYYY HH24:MI'),"
  & " to_char(updated_at, 'Mon DD, YYYY HH24:MI')"
  & " FROM notes WHERE id = $1::bigint"
  & X"00".
LINKAGE SECTION.
01  LS-ID                       PIC X(20).
01  LS-ID-LEN                   BINARY-LONG.
PROCEDURE DIVISION USING LS-ID LS-ID-LEN.
    MOVE "N" TO NC-FOUND
    MOVE 1 TO DBP-COUNT
    MOVE LS-ID(1:LS-ID-LEN) TO DBP-VALUE(1)
    MOVE X"00" TO DBP-VALUE(1)(LS-ID-LEN + 1:1)
    CALL "DB-EXEC" USING WS-SQL
    IF DB-OK NOT = "Y" OR DB-ROWS = 0
        GOBACK
    END-IF

    MOVE "Y" TO NC-FOUND
    MOVE 0 TO WS-COL
    MOVE 20 TO WS-MAX
    MOVE SPACES TO NC-ID
    CALL "DB-FIELD" USING WS-ROW WS-COL NC-ID WS-MAX NC-ID-LEN
    MOVE 1 TO WS-COL
    MOVE 1000 TO WS-MAX
    MOVE SPACES TO NC-TITLE
    CALL "DB-FIELD" USING WS-ROW WS-COL NC-TITLE WS-MAX NC-TITLE-LEN
    MOVE 2 TO WS-COL
    MOVE NOTE-BODY-MAX TO WS-MAX
    MOVE SPACES TO NC-BODY
    CALL "DB-FIELD" USING WS-ROW WS-COL NC-BODY WS-MAX NC-BODY-LEN
    MOVE 3 TO WS-COL
    MOVE 32 TO WS-MAX
    MOVE SPACES TO NC-CREATED
    CALL "DB-FIELD" USING WS-ROW WS-COL NC-CREATED WS-MAX
                          NC-CREATED-LEN
    MOVE 4 TO WS-COL
    MOVE SPACES TO NC-UPDATED
    CALL "DB-FIELD" USING WS-ROW WS-COL NC-UPDATED WS-MAX
                          NC-UPDATED-LEN
    GOBACK.
END PROGRAM DB-GET-NOTE.

*> ------------------------------------------------------------
*> DB-SAVE-NOTE: insert (NC-ID-LEN = 0) or update NOTE-CURRENT.
*> Sets NC-FOUND = Y and NC-ID on success.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. DB-SAVE-NOTE.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "db.cpy".
COPY "notes.cpy".
01  WS-ROW                      BINARY-LONG VALUE 0.
01  WS-COL                      BINARY-LONG VALUE 0.
01  WS-MAX                      BINARY-LONG VALUE 20.
01  WS-INSERT-SQL               PIC X(512) VALUE
    "INSERT INTO notes (title, body) VALUES"
  & " (coalesce(nullif(btrim(left($1, 200)), ''), 'Untitled'), $2)"
  & " RETURNING id"
  & X"00".
01  WS-UPDATE-SQL               PIC X(512) VALUE
    "UPDATE notes SET"
  & " title = coalesce(nullif(btrim(left($1, 200)), ''), 'Untitled'),"
  & " body = $2, updated_at = now()"
  & " WHERE id = $3::bigint RETURNING id"
  & X"00".
PROCEDURE DIVISION.
    MOVE "N" TO NC-FOUND
    IF NC-TITLE-LEN > 0
        MOVE NC-TITLE(1:NC-TITLE-LEN) TO DBP-VALUE(1)
    END-IF
    MOVE X"00" TO DBP-VALUE(1)(NC-TITLE-LEN + 1:1)
    IF NC-BODY-LEN > 0
        MOVE NC-BODY(1:NC-BODY-LEN) TO DBP-VALUE(2)
    END-IF
    MOVE X"00" TO DBP-VALUE(2)(NC-BODY-LEN + 1:1)

    IF NC-ID-LEN = 0
        MOVE 2 TO DBP-COUNT
        CALL "DB-EXEC" USING WS-INSERT-SQL
    ELSE
        MOVE 3 TO DBP-COUNT
        MOVE NC-ID(1:NC-ID-LEN) TO DBP-VALUE(3)
        MOVE X"00" TO DBP-VALUE(3)(NC-ID-LEN + 1:1)
        CALL "DB-EXEC" USING WS-UPDATE-SQL
    END-IF

    IF DB-OK = "Y" AND DB-ROWS = 1
        MOVE "Y" TO NC-FOUND
        MOVE SPACES TO NC-ID
        CALL "DB-FIELD" USING WS-ROW WS-COL NC-ID WS-MAX NC-ID-LEN
    END-IF
    GOBACK.
END PROGRAM DB-SAVE-NOTE.

*> ------------------------------------------------------------
*> DB-DELETE-NOTE: delete note ID; NC-FOUND = Y if it existed.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. DB-DELETE-NOTE.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "db.cpy".
COPY "notes.cpy".
01  WS-SQL                      PIC X(256) VALUE
    "DELETE FROM notes WHERE id = $1::bigint RETURNING id"
  & X"00".
LINKAGE SECTION.
01  LS-ID                       PIC X(20).
01  LS-ID-LEN                   BINARY-LONG.
PROCEDURE DIVISION USING LS-ID LS-ID-LEN.
    MOVE "N" TO NC-FOUND
    MOVE 1 TO DBP-COUNT
    MOVE LS-ID(1:LS-ID-LEN) TO DBP-VALUE(1)
    MOVE X"00" TO DBP-VALUE(1)(LS-ID-LEN + 1:1)
    CALL "DB-EXEC" USING WS-SQL
    IF DB-OK = "Y" AND DB-ROWS = 1
        MOVE "Y" TO NC-FOUND
    END-IF
    GOBACK.
END PROGRAM DB-DELETE-NOTE.

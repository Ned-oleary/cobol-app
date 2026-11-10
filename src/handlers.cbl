*> ============================================================
*> handlers.cbl - request handlers: read input, call the
*> database layer, render a view or redirect.
*> ============================================================

*> ------------------------------------------------------------
*> PAGE-INDEX: GET /  (?q= filters the list)
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. PAGE-INDEX.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
COPY "db.cpy".
01  WS-Q                        PIC X(2048).
01  WS-Q-LEN                    BINARY-LONG.
01  WS-RAW-LEN                  BINARY-LONG.
01  WS-Q-MAX                    BINARY-LONG VALUE 200.
01  WS-NAME                     PIC X(64) VALUE "q".
01  WS-NAME-LEN                 BINARY-LONG VALUE 1.
01  WS-FOUND                    PIC X.
01  WS-MSG                      PIC X(256).
PROCEDURE DIVISION.
    MOVE SPACES TO WS-Q
    CALL "URL-PARAM" USING REQ-QUERY REQ-QUERY-LEN WS-NAME WS-NAME-LEN
                           WS-Q WS-Q-MAX WS-Q-LEN WS-FOUND
    *> ignore surrounding whitespace in the search box
    MOVE WS-Q-LEN TO WS-RAW-LEN
    CALL "TEXT-LEN" USING WS-Q WS-RAW-LEN WS-Q-LEN
    IF WS-Q-LEN > 0
        MOVE FUNCTION TRIM(WS-Q(1:WS-Q-LEN) LEADING) TO WS-Q
        MOVE WS-Q-LEN TO WS-RAW-LEN
        CALL "TEXT-LEN" USING WS-Q WS-RAW-LEN WS-Q-LEN
    END-IF

    CALL "DB-LIST-NOTES" USING WS-Q WS-Q-LEN
    IF DB-OK = "Y"
        CALL "VIEW-INDEX" USING WS-Q WS-Q-LEN
    ELSE
        MOVE 500 TO RESP-STATUS
        MOVE "Could not load notes." TO WS-MSG
        CALL "PAGE-ERROR" USING WS-MSG
    END-IF
    GOBACK.
END PROGRAM PAGE-INDEX.

*> ------------------------------------------------------------
*> PAGE-NOTE: GET /notes/{id}
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. PAGE-NOTE.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
COPY "db.cpy".
COPY "notes.cpy".
01  WS-MSG                      PIC X(256).
LINKAGE SECTION.
01  LS-ID                       PIC X(20).
01  LS-ID-LEN                   BINARY-LONG.
PROCEDURE DIVISION USING LS-ID LS-ID-LEN.
    CALL "DB-GET-NOTE" USING LS-ID LS-ID-LEN
    EVALUATE TRUE
        WHEN DB-OK NOT = "Y"
            MOVE 500 TO RESP-STATUS
            MOVE "Could not load that note." TO WS-MSG
            CALL "PAGE-ERROR" USING WS-MSG
        WHEN NC-FOUND NOT = "Y"
            MOVE 404 TO RESP-STATUS
            MOVE "That note does not exist (maybe it was deleted)."
              TO WS-MSG
            CALL "PAGE-ERROR" USING WS-MSG
        WHEN OTHER
            CALL "VIEW-NOTE"
    END-EVALUATE
    GOBACK.
END PROGRAM PAGE-NOTE.

*> ------------------------------------------------------------
*> READ-NOTE-FORM: decode title/body form fields into
*> NOTE-CURRENT.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. READ-NOTE-FORM.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
COPY "notes.cpy".
01  WS-NAME                     PIC X(64).
01  WS-NAME-LEN                 BINARY-LONG.
01  WS-MAX                      BINARY-LONG.
01  WS-FOUND                    PIC X.
PROCEDURE DIVISION.
    MOVE SPACES TO NC-TITLE
    MOVE "title" TO WS-NAME
    MOVE 5 TO WS-NAME-LEN
    MOVE NOTE-TITLE-MAX TO WS-MAX
    CALL "URL-PARAM" USING REQ-BODY REQ-BODY-LEN WS-NAME WS-NAME-LEN
                           NC-TITLE WS-MAX NC-TITLE-LEN WS-FOUND

    MOVE SPACES TO NC-BODY
    MOVE "body" TO WS-NAME
    MOVE 4 TO WS-NAME-LEN
    MOVE NOTE-BODY-MAX TO WS-MAX
    CALL "URL-PARAM" USING REQ-BODY REQ-BODY-LEN WS-NAME WS-NAME-LEN
                           NC-BODY WS-MAX NC-BODY-LEN WS-FOUND
    GOBACK.
END PROGRAM READ-NOTE-FORM.

*> ------------------------------------------------------------
*> ACTION-CREATE: POST /notes
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. ACTION-CREATE.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
COPY "db.cpy".
COPY "notes.cpy".
01  WS-MSG                      PIC X(256).
PROCEDURE DIVISION.
    CALL "READ-NOTE-FORM"
    MOVE 0 TO NC-ID-LEN
    CALL "DB-SAVE-NOTE"
    IF NC-FOUND = "Y"
        MOVE 303 TO RESP-STATUS
        MOVE "/" TO RESP-LOCATION
    ELSE
        MOVE 500 TO RESP-STATUS
        MOVE "Could not save the note." TO WS-MSG
        CALL "PAGE-ERROR" USING WS-MSG
    END-IF
    GOBACK.
END PROGRAM ACTION-CREATE.

*> ------------------------------------------------------------
*> ACTION-UPDATE: POST /notes/{id}
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. ACTION-UPDATE.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
COPY "db.cpy".
COPY "notes.cpy".
01  WS-MSG                      PIC X(256).
LINKAGE SECTION.
01  LS-ID                       PIC X(20).
01  LS-ID-LEN                   BINARY-LONG.
PROCEDURE DIVISION USING LS-ID LS-ID-LEN.
    CALL "READ-NOTE-FORM"
    MOVE LS-ID TO NC-ID
    MOVE LS-ID-LEN TO NC-ID-LEN
    CALL "DB-SAVE-NOTE"
    EVALUATE TRUE
        WHEN NC-FOUND = "Y"
            MOVE 303 TO RESP-STATUS
            MOVE "/" TO RESP-LOCATION
        WHEN DB-OK = "Y"
            MOVE 404 TO RESP-STATUS
            MOVE "That note does not exist (maybe it was deleted)."
              TO WS-MSG
            CALL "PAGE-ERROR" USING WS-MSG
        WHEN OTHER
            MOVE 500 TO RESP-STATUS
            MOVE "Could not save the note." TO WS-MSG
            CALL "PAGE-ERROR" USING WS-MSG
    END-EVALUATE
    GOBACK.
END PROGRAM ACTION-UPDATE.

*> ------------------------------------------------------------
*> ACTION-DELETE: POST /notes/{id}/delete
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. ACTION-DELETE.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
COPY "db.cpy".
COPY "notes.cpy".
01  WS-MSG                      PIC X(256).
LINKAGE SECTION.
01  LS-ID                       PIC X(20).
01  LS-ID-LEN                   BINARY-LONG.
PROCEDURE DIVISION USING LS-ID LS-ID-LEN.
    CALL "DB-DELETE-NOTE" USING LS-ID LS-ID-LEN
    IF DB-OK = "Y"
        *> deleting an already-deleted note is fine: go home
        MOVE 303 TO RESP-STATUS
        MOVE "/" TO RESP-LOCATION
    ELSE
        MOVE 500 TO RESP-STATUS
        MOVE "Could not delete the note." TO WS-MSG
        CALL "PAGE-ERROR" USING WS-MSG
    END-IF
    GOBACK.
END PROGRAM ACTION-DELETE.

*> ------------------------------------------------------------
*> SERVE-STATIC: GET /style.css from PUBLIC_DIR (default
*> "public"), read with the byte-stream file routines.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. SERVE-STATIC.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
01  WS-DIR                      PIC X(1024).
01  WS-FILE                     PIC X(1100).
01  WS-HANDLE                   PIC X(4).
01  WS-OFFSET                   PIC X(8) COMP-X.
01  WS-COUNT                    PIC X(4) COMP-X.
01  WS-FLAGS                    BINARY-CHAR UNSIGNED.
01  WS-ACCESS                   BINARY-CHAR UNSIGNED VALUE 1.
01  WS-DENY                     BINARY-CHAR UNSIGNED VALUE 0.
01  WS-DEVICE                   BINARY-CHAR UNSIGNED VALUE 0.
01  WS-SIZE                     BINARY-LONG.
01  WS-MSG                      PIC X(256).
PROCEDURE DIVISION.
    MOVE SPACES TO WS-DIR
    ACCEPT WS-DIR FROM ENVIRONMENT "PUBLIC_DIR"
    IF WS-DIR = SPACES
        MOVE "public" TO WS-DIR
    END-IF
    MOVE SPACES TO WS-FILE
    STRING FUNCTION TRIM(WS-DIR) "/style.css" DELIMITED BY SIZE
        INTO WS-FILE
    END-STRING

    CALL "CBL_OPEN_FILE" USING WS-FILE WS-ACCESS WS-DENY WS-DEVICE
                               WS-HANDLE
    IF RETURN-CODE NOT = 0
        PERFORM NOT-FOUND
        GOBACK
    END-IF

    *> flag 128: return the file size in WS-OFFSET
    MOVE 0 TO WS-OFFSET WS-COUNT
    MOVE 128 TO WS-FLAGS
    CALL "CBL_READ_FILE" USING WS-HANDLE WS-OFFSET WS-COUNT WS-FLAGS
                               RESP-BODY
    MOVE WS-OFFSET TO WS-SIZE
    IF WS-SIZE > RESP-BODY-MAX
        MOVE RESP-BODY-MAX TO WS-SIZE
    END-IF

    MOVE 0 TO WS-OFFSET WS-FLAGS
    MOVE WS-SIZE TO WS-COUNT
    IF WS-SIZE > 0
        CALL "CBL_READ_FILE" USING WS-HANDLE WS-OFFSET WS-COUNT
                                   WS-FLAGS RESP-BODY
    END-IF
    CALL "CBL_CLOSE_FILE" USING WS-HANDLE

    COMPUTE RESP-PTR = WS-SIZE + 1
    MOVE "text/css; charset=utf-8" TO RESP-CTYPE
    GOBACK.

NOT-FOUND.
    MOVE 404 TO RESP-STATUS
    MOVE "Stylesheet not found." TO WS-MSG
    CALL "PAGE-ERROR" USING WS-MSG.
END PROGRAM SERVE-STATIC.

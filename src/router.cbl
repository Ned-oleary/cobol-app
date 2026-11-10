*> ============================================================
*> router.cbl - maps METHOD + PATH to a handler.
*>
*>   GET  /                   list notes (optional ?q=search)
*>   POST /notes              create a note
*>   GET  /notes/{id}         view / edit a note
*>   POST /notes/{id}         update a note
*>   POST /notes/{id}/delete  delete a note
*>   GET  /style.css          stylesheet from PUBLIC_DIR
*> ============================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. ROUTER.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
COPY "db.cpy".
01  WS-ID                       PIC X(20).
01  WS-ID-LEN                   BINARY-LONG.
01  WS-I                        BINARY-LONG.
01  WS-ROUTE                    PIC X(16).
01  WS-MSG                      PIC X(256).
PROCEDURE DIVISION.
    PERFORM MATCH-ROUTE

    EVALUATE WS-ROUTE
        WHEN "STATIC"
            IF REQ-METHOD = "GET"
                CALL "SERVE-STATIC"
            ELSE
                PERFORM METHOD-NOT-ALLOWED
            END-IF
        WHEN "INDEX"
            IF REQ-METHOD = "GET"
                PERFORM WITH-DB-INDEX
            ELSE
                PERFORM METHOD-NOT-ALLOWED
            END-IF
        WHEN "NOTES"
            EVALUATE REQ-METHOD
                WHEN "POST"
                    PERFORM CONNECT-DB
                    IF DB-OK = "Y"
                        CALL "ACTION-CREATE"
                    END-IF
                WHEN "GET"
                    MOVE 303 TO RESP-STATUS
                    MOVE "/" TO RESP-LOCATION
                WHEN OTHER
                    PERFORM METHOD-NOT-ALLOWED
            END-EVALUATE
        WHEN "NOTE"
            EVALUATE REQ-METHOD
                WHEN "GET"
                    PERFORM CONNECT-DB
                    IF DB-OK = "Y"
                        CALL "PAGE-NOTE" USING WS-ID WS-ID-LEN
                    END-IF
                WHEN "POST"
                    PERFORM CONNECT-DB
                    IF DB-OK = "Y"
                        CALL "ACTION-UPDATE" USING WS-ID WS-ID-LEN
                    END-IF
                WHEN OTHER
                    PERFORM METHOD-NOT-ALLOWED
            END-EVALUATE
        WHEN "DELETE"
            IF REQ-METHOD = "POST"
                PERFORM CONNECT-DB
                IF DB-OK = "Y"
                    CALL "ACTION-DELETE" USING WS-ID WS-ID-LEN
                END-IF
            ELSE
                PERFORM METHOD-NOT-ALLOWED
            END-IF
        WHEN OTHER
            MOVE 404 TO RESP-STATUS
            MOVE "There is no page at that address." TO WS-MSG
            CALL "PAGE-ERROR" USING WS-MSG
    END-EVALUATE

    CALL "DB-DISCONNECT"
    GOBACK.

MATCH-ROUTE.
    MOVE SPACES TO WS-ROUTE
    EVALUATE TRUE
        WHEN REQ-PATH = "/"
            MOVE "INDEX" TO WS-ROUTE
        WHEN REQ-PATH = "/style.css"
            MOVE "STATIC" TO WS-ROUTE
        WHEN REQ-PATH = "/notes"
            MOVE "NOTES" TO WS-ROUTE
        WHEN REQ-PATH-LEN > 7 AND REQ-PATH(1:7) = "/notes/"
            MOVE 8 TO WS-I
            PERFORM UNTIL WS-I > REQ-PATH-LEN
                       OR REQ-PATH(WS-I:1) IS NOT NUMERIC
                ADD 1 TO WS-I
            END-PERFORM
            COMPUTE WS-ID-LEN = WS-I - 8
            IF WS-ID-LEN > 0 AND WS-ID-LEN <= 18
                MOVE REQ-PATH(8:WS-ID-LEN) TO WS-ID
                EVALUATE TRUE
                    WHEN WS-I > REQ-PATH-LEN
                        MOVE "NOTE" TO WS-ROUTE
                    WHEN REQ-PATH(WS-I:) = "/delete"
                        MOVE "DELETE" TO WS-ROUTE
                END-EVALUATE
            END-IF
    END-EVALUATE.

CONNECT-DB.
    CALL "DB-CONNECT"
    IF DB-OK NOT = "Y"
        MOVE 500 TO RESP-STATUS
        MOVE "Could not connect to the database." TO WS-MSG
        CALL "PAGE-ERROR" USING WS-MSG
    END-IF.

WITH-DB-INDEX.
    PERFORM CONNECT-DB
    IF DB-OK = "Y"
        CALL "PAGE-INDEX"
    END-IF.

METHOD-NOT-ALLOWED.
    MOVE 405 TO RESP-STATUS
    MOVE "That method is not allowed here." TO WS-MSG
    CALL "PAGE-ERROR" USING WS-MSG.
END PROGRAM ROUTER.

*> ============================================================
*> http.cbl - HTTP/1.1 over a connected socket: read and parse
*> one request, route it, write the response, done.
*> ============================================================

*> ------------------------------------------------------------
*> HANDLE-CONNECTION: serve one request on client socket FD.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. HANDLE-CONNECTION.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "platform.cpy".
COPY "http.cpy".
78  HDR-MAX                     VALUE 16384.
01  WS-RAW                      PIC X(278528).
01  WS-LC                       PIC X(16384).
01  WS-TOTAL                    BINARY-LONG.
01  WS-N                        BINARY-LONG.
01  WS-ROOM                     BINARY-DOUBLE.
01  WS-HDR-LEN                  BINARY-LONG.
01  WS-HDR-FOUND                PIC X.
01  WS-BODY-START               BINARY-LONG.
01  WS-NEED                     BINARY-LONG.
01  WS-K                        BINARY-LONG.
01  WS-I                        BINARY-LONG.
01  WS-CL                       BINARY-DOUBLE.
01  WS-CL-DIGITS                BINARY-LONG.
01  WS-EXPECT                   PIC X.
01  WS-ABORT                    PIC X.
01  WS-ERR                      PIC 9(3).
01  WS-LINE-LEN                 BINARY-LONG.
01  WS-TARGET                   PIC X(2048).
01  WS-TARGET-LEN               BINARY-LONG.
01  WS-VERSION                  PIC X(16).
01  WS-CRLF                     PIC X(2) VALUE X"0D0A".
01  WS-CRLF2                    PIC X(4) VALUE X"0D0A0D0A".
01  WS-CL-KEY                   PIC X(17)
                                VALUE X"0D0A" & "content-length:".
01  WS-EXPECT-KEY               PIC X(22)
                                VALUE X"0D0A" & "expect: 100-continue".
01  WS-CONTINUE                 PIC X(25)
                                VALUE "HTTP/1.1 100 Continue" & X"0D0A0D0A".
01  WS-CONTINUE-LEN             BINARY-LONG VALUE 25.
01  WS-TIMEVAL.
    05  TV-SEC                  BINARY-DOUBLE VALUE 10.
    05  TV-USEC                 BINARY-DOUBLE VALUE 0.
01  WS-HEAD                     PIC X(2048).
01  WS-HEAD-PTR                 BINARY-LONG.
01  WS-HEAD-LEN                 BINARY-LONG.
01  WS-BODY-LEN                 BINARY-LONG.
01  WS-REASON                   PIC X(40).
01  WS-LEN-DISP                 PIC Z(8)9.
01  WS-MSG                      PIC X(256).
LINKAGE SECTION.
01  LS-FD                       BINARY-LONG.
PROCEDURE DIVISION USING LS-FD.
    *> don't let a slow or idle client hold this worker forever
    CALL "setsockopt" USING BY VALUE LS-FD BY VALUE PF-SOL-SOCKET
        BY VALUE PF-SO-RCVTIMEO BY REFERENCE WS-TIMEVAL BY VALUE 16
    CALL "setsockopt" USING BY VALUE LS-FD BY VALUE PF-SOL-SOCKET
        BY VALUE PF-SO-SNDTIMEO BY REFERENCE WS-TIMEVAL BY VALUE 16

    MOVE SPACES TO REQ-METHOD REQ-PATH REQ-QUERY
    MOVE 0 TO REQ-PATH-LEN REQ-QUERY-LEN REQ-BODY-LEN
    MOVE 200 TO RESP-STATUS
    MOVE "text/html; charset=utf-8" TO RESP-CTYPE
    MOVE SPACES TO RESP-LOCATION
    MOVE 1 TO RESP-PTR
    MOVE "N" TO WS-ABORT
    MOVE 0 TO WS-ERR

    PERFORM READ-HEADERS
    IF WS-ABORT = "Y"
        GOBACK
    END-IF
    IF WS-ERR = 0
        PERFORM PARSE-REQUEST-LINE
    END-IF
    IF WS-ERR = 0
        PERFORM PARSE-HEADERS
    END-IF
    IF WS-ERR = 0
        PERFORM READ-BODY
        IF WS-ABORT = "Y"
            GOBACK
        END-IF
    END-IF

    IF WS-ERR = 0
        CALL "ROUTER"
    ELSE
        MOVE WS-ERR TO RESP-STATUS
        EVALUATE WS-ERR
            WHEN 413
                MOVE "That request is too large (notes are limited to 256 KB)."
                  TO WS-MSG
            WHEN 431
                MOVE "Request headers are too large." TO WS-MSG
            WHEN OTHER
                MOVE "The request could not be understood." TO WS-MSG
        END-EVALUATE
        CALL "PAGE-ERROR" USING WS-MSG
    END-IF

    PERFORM SEND-RESPONSE
    PERFORM LOG-REQUEST
    GOBACK.

*> Read until the blank line that ends the headers.
READ-HEADERS.
    MOVE 0 TO WS-TOTAL
    MOVE "N" TO WS-HDR-FOUND
    PERFORM UNTIL WS-HDR-FOUND = "Y" OR WS-ABORT = "Y" OR WS-ERR > 0
        IF WS-TOTAL >= HDR-MAX
            MOVE 431 TO WS-ERR
        ELSE
            COMPUTE WS-ROOM = HDR-MAX - WS-TOTAL
            CALL "recv" USING BY VALUE LS-FD
                BY REFERENCE WS-RAW(WS-TOTAL + 1:WS-ROOM)
                BY VALUE WS-ROOM BY VALUE 0
                RETURNING WS-N
            IF WS-N <= 0
                MOVE "Y" TO WS-ABORT
            ELSE
                ADD WS-N TO WS-TOTAL
                MOVE 0 TO WS-K
                INSPECT WS-RAW(1:WS-TOTAL) TALLYING WS-K
                    FOR CHARACTERS BEFORE INITIAL WS-CRLF2
                IF WS-K < WS-TOTAL
                    MOVE "Y" TO WS-HDR-FOUND
                    MOVE WS-K TO WS-HDR-LEN
                    COMPUTE WS-BODY-START = WS-K + 5
                END-IF
            END-IF
        END-IF
    END-PERFORM
    IF WS-HDR-FOUND = "Y" AND WS-HDR-LEN = 0
        MOVE 400 TO WS-ERR
    END-IF.

*> "GET /path?query HTTP/1.1"
PARSE-REQUEST-LINE.
    MOVE 0 TO WS-LINE-LEN
    INSPECT WS-RAW(1:WS-HDR-LEN) TALLYING WS-LINE-LEN
        FOR CHARACTERS BEFORE INITIAL WS-CRLF
    MOVE 0 TO WS-TARGET-LEN
    MOVE SPACES TO WS-TARGET WS-VERSION
    IF WS-LINE-LEN > 0
        UNSTRING WS-RAW(1:WS-LINE-LEN) DELIMITED BY ALL SPACE
            INTO REQ-METHOD
                 WS-TARGET COUNT IN WS-TARGET-LEN
                 WS-VERSION
        END-UNSTRING
    END-IF
    IF WS-TARGET-LEN = 0 OR WS-TARGET-LEN > 2048
       OR WS-TARGET(1:1) NOT = "/"
       OR WS-VERSION(1:5) NOT = "HTTP/"
        MOVE 400 TO WS-ERR
    ELSE
        MOVE 0 TO WS-K
        INSPECT WS-TARGET(1:WS-TARGET-LEN) TALLYING WS-K
            FOR CHARACTERS BEFORE INITIAL "?"
        MOVE WS-TARGET(1:WS-K) TO REQ-PATH
        MOVE WS-K TO REQ-PATH-LEN
        IF WS-TARGET-LEN - WS-K - 1 > 0
            COMPUTE REQ-QUERY-LEN = WS-TARGET-LEN - WS-K - 1
            MOVE WS-TARGET(WS-K + 2:REQ-QUERY-LEN) TO REQ-QUERY
        END-IF
    END-IF.

*> Content-Length and Expect, matched case-insensitively.
PARSE-HEADERS.
    MOVE FUNCTION LOWER-CASE(WS-RAW(1:WS-HDR-LEN)) TO WS-LC
    MOVE 0 TO WS-CL
    MOVE 0 TO WS-K
    INSPECT WS-LC(1:WS-HDR-LEN) TALLYING WS-K
        FOR CHARACTERS BEFORE INITIAL WS-CL-KEY
    IF WS-K < WS-HDR-LEN
        COMPUTE WS-I = WS-K + 18
        PERFORM UNTIL WS-I > WS-HDR-LEN
                   OR (WS-LC(WS-I:1) NOT = SPACE
                       AND WS-LC(WS-I:1) NOT = X"09")
            ADD 1 TO WS-I
        END-PERFORM
        MOVE 0 TO WS-CL-DIGITS
        PERFORM UNTIL WS-I > WS-HDR-LEN
                   OR WS-LC(WS-I:1) IS NOT NUMERIC
                   OR WS-CL-DIGITS > 10
            COMPUTE WS-CL = WS-CL * 10
                          + FUNCTION ORD(WS-LC(WS-I:1)) - FUNCTION ORD("0")
            ADD 1 TO WS-I
            ADD 1 TO WS-CL-DIGITS
        END-PERFORM
        IF WS-CL-DIGITS = 0
            MOVE 400 TO WS-ERR
        END-IF
    END-IF
    IF WS-CL > REQ-BODY-MAX
        MOVE 413 TO WS-ERR
    END-IF

    MOVE 0 TO WS-K
    MOVE "N" TO WS-EXPECT
    INSPECT WS-LC(1:WS-HDR-LEN) TALLYING WS-K
        FOR CHARACTERS BEFORE INITIAL WS-EXPECT-KEY
    IF WS-K < WS-HDR-LEN
        MOVE "Y" TO WS-EXPECT
    END-IF.

*> Read the rest of the body (Content-Length bytes).
READ-BODY.
    COMPUTE WS-NEED = WS-BODY-START - 1 + WS-CL
    IF WS-EXPECT = "Y" AND WS-TOTAL < WS-NEED
        CALL "SOCKET-SEND-ALL" USING LS-FD WS-CONTINUE WS-CONTINUE-LEN
    END-IF
    PERFORM UNTIL WS-TOTAL >= WS-NEED OR WS-ABORT = "Y"
        COMPUTE WS-ROOM = WS-NEED - WS-TOTAL
        CALL "recv" USING BY VALUE LS-FD
            BY REFERENCE WS-RAW(WS-TOTAL + 1:WS-ROOM)
            BY VALUE WS-ROOM BY VALUE 0
            RETURNING WS-N
        IF WS-N <= 0
            MOVE "Y" TO WS-ABORT
        ELSE
            ADD WS-N TO WS-TOTAL
        END-IF
    END-PERFORM
    IF WS-CL > 0
        MOVE WS-RAW(WS-BODY-START:WS-CL) TO REQ-BODY
        MOVE WS-CL TO REQ-BODY-LEN
    END-IF.

SEND-RESPONSE.
    COMPUTE WS-BODY-LEN = RESP-PTR - 1
    EVALUATE RESP-STATUS
        WHEN 200 MOVE "OK"                    TO WS-REASON
        WHEN 303 MOVE "See Other"             TO WS-REASON
        WHEN 400 MOVE "Bad Request"           TO WS-REASON
        WHEN 404 MOVE "Not Found"             TO WS-REASON
        WHEN 405 MOVE "Method Not Allowed"    TO WS-REASON
        WHEN 413 MOVE "Content Too Large"     TO WS-REASON
        WHEN 431 MOVE "Request Header Fields Too Large" TO WS-REASON
        WHEN 500 MOVE "Internal Server Error" TO WS-REASON
        WHEN OTHER MOVE "Unknown"             TO WS-REASON
    END-EVALUATE
    MOVE WS-BODY-LEN TO WS-LEN-DISP
    MOVE 1 TO WS-HEAD-PTR
    STRING
        "HTTP/1.1 " RESP-STATUS " " FUNCTION TRIM(WS-REASON) WS-CRLF
        "Content-Type: " FUNCTION TRIM(RESP-CTYPE) WS-CRLF
        "Content-Length: " FUNCTION TRIM(WS-LEN-DISP) WS-CRLF
        "Cache-Control: no-store" WS-CRLF
        "X-Content-Type-Options: nosniff" WS-CRLF
        "Connection: close" WS-CRLF
        DELIMITED BY SIZE INTO WS-HEAD WITH POINTER WS-HEAD-PTR
    END-STRING
    IF RESP-LOCATION NOT = SPACES
        STRING "Location: " FUNCTION TRIM(RESP-LOCATION) WS-CRLF
            DELIMITED BY SIZE INTO WS-HEAD WITH POINTER WS-HEAD-PTR
        END-STRING
    END-IF
    STRING WS-CRLF DELIMITED BY SIZE INTO WS-HEAD WITH POINTER WS-HEAD-PTR
    END-STRING
    COMPUTE WS-HEAD-LEN = WS-HEAD-PTR - 1
    CALL "SOCKET-SEND-ALL" USING LS-FD WS-HEAD WS-HEAD-LEN
    IF WS-BODY-LEN > 0
        CALL "SOCKET-SEND-ALL" USING LS-FD RESP-BODY WS-BODY-LEN
    END-IF.

LOG-REQUEST.
    IF REQ-PATH-LEN > 0
        DISPLAY FUNCTION TRIM(REQ-METHOD) " " REQ-PATH(1:REQ-PATH-LEN)
            " " RESP-STATUS
    ELSE
        DISPLAY "(bad request) " RESP-STATUS
    END-IF.
END PROGRAM HANDLE-CONNECTION.

*> ------------------------------------------------------------
*> SOCKET-SEND-ALL: send BUF(1:LEN), retrying partial writes.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. SOCKET-SEND-ALL.
DATA DIVISION.
WORKING-STORAGE SECTION.
01  WS-OFF                      BINARY-LONG.
01  WS-N                        BINARY-LONG.
01  WS-LEFT                     BINARY-DOUBLE.
LINKAGE SECTION.
01  LS-FD                       BINARY-LONG.
01  LS-BUF                      PIC X(2097152).
01  LS-LEN                      BINARY-LONG.
PROCEDURE DIVISION USING LS-FD LS-BUF LS-LEN.
    MOVE 0 TO WS-OFF
    PERFORM UNTIL WS-OFF >= LS-LEN
        COMPUTE WS-LEFT = LS-LEN - WS-OFF
        CALL "send" USING BY VALUE LS-FD
            BY REFERENCE LS-BUF(WS-OFF + 1:WS-LEFT)
            BY VALUE WS-LEFT BY VALUE 0
            RETURNING WS-N
        IF WS-N <= 0
            *> peer went away (SIGPIPE is ignored); give up quietly
            MOVE LS-LEN TO WS-OFF
        ELSE
            ADD WS-N TO WS-OFF
        END-IF
    END-PERFORM
    GOBACK.
END PROGRAM SOCKET-SEND-ALL.

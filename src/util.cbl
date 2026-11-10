*> ============================================================
*> util.cbl - string helpers: form/query parsing, URL decoding,
*>            HTML escaping and response-body appending.
*> ============================================================

*> ------------------------------------------------------------
*> URL-PARAM: find NAME in an application/x-www-form-urlencoded
*> string (a=1&b=2) and URL-decode its value into OUT.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. URL-PARAM.
DATA DIVISION.
WORKING-STORAGE SECTION.
01  WS-POS                      BINARY-LONG.
01  WS-END                      BINARY-LONG.
01  WS-VAL                      BINARY-LONG.
LINKAGE SECTION.
01  LS-SRC                      PIC X(262144).
01  LS-SRC-LEN                  BINARY-LONG.
01  LS-NAME                     PIC X(64).
01  LS-NAME-LEN                 BINARY-LONG.
01  LS-OUT                      PIC X(262144).
01  LS-OUT-MAX                  BINARY-LONG.
01  LS-OUT-LEN                  BINARY-LONG.
01  LS-FOUND                    PIC X.
PROCEDURE DIVISION USING LS-SRC LS-SRC-LEN LS-NAME LS-NAME-LEN
                         LS-OUT LS-OUT-MAX LS-OUT-LEN LS-FOUND.
    MOVE 0 TO LS-OUT-LEN
    MOVE "N" TO LS-FOUND
    MOVE 1 TO WS-POS
    PERFORM UNTIL WS-POS > LS-SRC-LEN OR LS-FOUND = "Y"
        MOVE WS-POS TO WS-END
        PERFORM UNTIL WS-END > LS-SRC-LEN
                   OR LS-SRC(WS-END:1) = "&"
            ADD 1 TO WS-END
        END-PERFORM
        *> segment is LS-SRC(WS-POS .. WS-END - 1)
        IF WS-END - WS-POS > LS-NAME-LEN
            IF LS-SRC(WS-POS:LS-NAME-LEN) = LS-NAME(1:LS-NAME-LEN)
               AND LS-SRC(WS-POS + LS-NAME-LEN:1) = "="
                MOVE "Y" TO LS-FOUND
                COMPUTE WS-VAL = WS-POS + LS-NAME-LEN + 1
                CALL "URL-DECODE" USING LS-SRC WS-VAL WS-END
                                        LS-OUT LS-OUT-MAX LS-OUT-LEN
            END-IF
        END-IF
        COMPUTE WS-POS = WS-END + 1
    END-PERFORM
    GOBACK.
END PROGRAM URL-PARAM.

*> ------------------------------------------------------------
*> URL-DECODE: decode SRC(FROM .. UPTO - 1) into OUT.
*> '+' becomes a space, %XX becomes the byte XX.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. URL-DECODE.
DATA DIVISION.
WORKING-STORAGE SECTION.
01  WS-I                        BINARY-LONG.
01  WS-C                        PIC X.
01  WS-HI                       BINARY-LONG.
01  WS-LO                       BINARY-LONG.
01  WS-NIBBLE                   BINARY-LONG.
LINKAGE SECTION.
01  LS-SRC                      PIC X(262144).
01  LS-FROM                     BINARY-LONG.
01  LS-UPTO                     BINARY-LONG.
01  LS-OUT                      PIC X(262144).
01  LS-OUT-MAX                  BINARY-LONG.
01  LS-OUT-LEN                  BINARY-LONG.
PROCEDURE DIVISION USING LS-SRC LS-FROM LS-UPTO
                         LS-OUT LS-OUT-MAX LS-OUT-LEN.
    MOVE 0 TO LS-OUT-LEN
    MOVE LS-FROM TO WS-I
    PERFORM UNTIL WS-I >= LS-UPTO OR LS-OUT-LEN >= LS-OUT-MAX
        MOVE LS-SRC(WS-I:1) TO WS-C
        EVALUATE TRUE
            WHEN WS-C = "+"
                ADD 1 TO LS-OUT-LEN
                MOVE SPACE TO LS-OUT(LS-OUT-LEN:1)
                ADD 1 TO WS-I
            WHEN WS-C = "%" AND WS-I + 2 < LS-UPTO
                MOVE LS-SRC(WS-I + 1:1) TO WS-C
                PERFORM HEX-NIBBLE
                MOVE WS-NIBBLE TO WS-HI
                MOVE LS-SRC(WS-I + 2:1) TO WS-C
                PERFORM HEX-NIBBLE
                MOVE WS-NIBBLE TO WS-LO
                ADD 1 TO LS-OUT-LEN
                IF WS-HI >= 0 AND WS-LO >= 0
                    MOVE FUNCTION CHAR(WS-HI * 16 + WS-LO + 1)
                      TO LS-OUT(LS-OUT-LEN:1)
                    ADD 3 TO WS-I
                ELSE
                    *> malformed escape: keep the '%' literally
                    MOVE "%" TO LS-OUT(LS-OUT-LEN:1)
                    ADD 1 TO WS-I
                END-IF
            WHEN OTHER
                ADD 1 TO LS-OUT-LEN
                MOVE WS-C TO LS-OUT(LS-OUT-LEN:1)
                ADD 1 TO WS-I
        END-EVALUATE
    END-PERFORM
    GOBACK.

HEX-NIBBLE.
    EVALUATE TRUE
        WHEN WS-C >= "0" AND WS-C <= "9"
            COMPUTE WS-NIBBLE = FUNCTION ORD(WS-C) - FUNCTION ORD("0")
        WHEN WS-C >= "A" AND WS-C <= "F"
            COMPUTE WS-NIBBLE = FUNCTION ORD(WS-C) - FUNCTION ORD("A") + 10
        WHEN WS-C >= "a" AND WS-C <= "f"
            COMPUTE WS-NIBBLE = FUNCTION ORD(WS-C) - FUNCTION ORD("a") + 10
        WHEN OTHER
            MOVE -1 TO WS-NIBBLE
    END-EVALUATE.
END PROGRAM URL-DECODE.

*> ------------------------------------------------------------
*> HTML-ESCAPE: append SRC(1:LEN) to the response body with
*> & < > " ' replaced by entities.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. HTML-ESCAPE.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
01  WS-I                        BINARY-LONG.
LINKAGE SECTION.
01  LS-SRC                      PIC X(262144).
01  LS-LEN                      BINARY-LONG.
PROCEDURE DIVISION USING LS-SRC LS-LEN.
    PERFORM VARYING WS-I FROM 1 BY 1
            UNTIL WS-I > LS-LEN OR RESP-PTR > RESP-BODY-MAX - 8
        EVALUATE LS-SRC(WS-I:1)
            WHEN "&"
                MOVE "&amp;" TO RESP-BODY(RESP-PTR:5)
                ADD 5 TO RESP-PTR
            WHEN "<"
                MOVE "&lt;" TO RESP-BODY(RESP-PTR:4)
                ADD 4 TO RESP-PTR
            WHEN ">"
                MOVE "&gt;" TO RESP-BODY(RESP-PTR:4)
                ADD 4 TO RESP-PTR
            WHEN '"'
                MOVE "&quot;" TO RESP-BODY(RESP-PTR:6)
                ADD 6 TO RESP-PTR
            WHEN "'"
                MOVE "&#39;" TO RESP-BODY(RESP-PTR:5)
                ADD 5 TO RESP-PTR
            WHEN OTHER
                MOVE LS-SRC(WS-I:1) TO RESP-BODY(RESP-PTR:1)
                ADD 1 TO RESP-PTR
        END-EVALUATE
    END-PERFORM
    GOBACK.
END PROGRAM HTML-ESCAPE.

*> ------------------------------------------------------------
*> APPEND-RAW: append SRC(1:LEN) to the response body verbatim.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. APPEND-RAW.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
LINKAGE SECTION.
01  LS-SRC                      PIC X(2097152).
01  LS-LEN                      BINARY-LONG.
PROCEDURE DIVISION USING LS-SRC LS-LEN.
    IF LS-LEN > 0 AND RESP-PTR + LS-LEN - 1 <= RESP-BODY-MAX
        MOVE LS-SRC(1:LS-LEN) TO RESP-BODY(RESP-PTR:LS-LEN)
        ADD LS-LEN TO RESP-PTR
    END-IF
    GOBACK.
END PROGRAM APPEND-RAW.

*> ------------------------------------------------------------
*> TEXT-LEN: length of TEXT(1:MAX) without trailing spaces.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. TEXT-LEN.
DATA DIVISION.
LINKAGE SECTION.
01  LS-TEXT                     PIC X(4096).
01  LS-MAX                      BINARY-LONG.
01  LS-LEN                      BINARY-LONG.
PROCEDURE DIVISION USING LS-TEXT LS-MAX LS-LEN.
    MOVE LS-MAX TO LS-LEN
    PERFORM UNTIL LS-LEN = 0 OR LS-TEXT(LS-LEN:1) NOT = SPACE
        SUBTRACT 1 FROM LS-LEN
    END-PERFORM
    GOBACK.
END PROGRAM TEXT-LEN.

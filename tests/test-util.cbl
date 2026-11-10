*> ============================================================
*> test-util.cbl - unit tests for util.cbl
*> (URL-PARAM, URL-DECODE, HTML-ESCAPE, TEXT-LEN).
*> ============================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. TEST-UTIL.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
01  WS-SRC                      PIC X(1024).
01  WS-SRC-LEN                  BINARY-LONG.
01  WS-NAME                     PIC X(64).
01  WS-NAME-LEN                 BINARY-LONG.
01  WS-OUT                      PIC X(1024).
01  WS-OUT-MAX                  BINARY-LONG VALUE 1024.
01  WS-OUT-LEN                  BINARY-LONG.
01  WS-FOUND                    PIC X.
01  WS-EXPECT                   PIC X(1024).
01  WS-EXPECT-LEN               BINARY-LONG.
01  WS-TEST-NAME                PIC X(60).
01  WS-PASSED                   BINARY-LONG VALUE 0.
01  WS-FAILED                   BINARY-LONG VALUE 0.
01  WS-DISP                     PIC ZZ9.
01  WS-MAX                      BINARY-LONG.
01  WS-LEN                      BINARY-LONG.
PROCEDURE DIVISION.
    *> ---- URL-PARAM / URL-DECODE --------------------------------
    MOVE "title=Hello+World&body=a%26b%3Dc%0D%0A" TO WS-SRC
    MOVE 38 TO WS-SRC-LEN

    MOVE "decodes + as space" TO WS-TEST-NAME
    MOVE "title" TO WS-NAME
    MOVE 5 TO WS-NAME-LEN
    PERFORM GET-PARAM
    MOVE "Hello World" TO WS-EXPECT
    MOVE 11 TO WS-EXPECT-LEN
    PERFORM CHECK-OUT

    MOVE "decodes %XX escapes incl. CRLF" TO WS-TEST-NAME
    MOVE "body" TO WS-NAME
    MOVE 4 TO WS-NAME-LEN
    PERFORM GET-PARAM
    MOVE "a&b=c" & X"0D0A" TO WS-EXPECT
    MOVE 7 TO WS-EXPECT-LEN
    PERFORM CHECK-OUT

    MOVE "missing field is not found" TO WS-TEST-NAME
    MOVE "tit" TO WS-NAME
    MOVE 3 TO WS-NAME-LEN
    PERFORM GET-PARAM
    PERFORM CHECK-NOT-FOUND

    MOVE "empty value is found, length 0" TO WS-TEST-NAME
    MOVE "q=&x=1" TO WS-SRC
    MOVE 6 TO WS-SRC-LEN
    MOVE "q" TO WS-NAME
    MOVE 1 TO WS-NAME-LEN
    PERFORM GET-PARAM
    MOVE SPACES TO WS-EXPECT
    MOVE 0 TO WS-EXPECT-LEN
    PERFORM CHECK-OUT

    MOVE "matches whole names only" TO WS-TEST-NAME
    MOVE "xq=1&q=2" TO WS-SRC
    MOVE 8 TO WS-SRC-LEN
    PERFORM GET-PARAM
    MOVE "2" TO WS-EXPECT
    MOVE 1 TO WS-EXPECT-LEN
    PERFORM CHECK-OUT

    MOVE "decodes UTF-8 bytes" TO WS-TEST-NAME
    MOVE "q=%C3%BC%e2%9c%93" TO WS-SRC
    MOVE 17 TO WS-SRC-LEN
    PERFORM GET-PARAM
    *> expected bytes C3 BC E2 9C 93 (CHAR is 1-based: byte + 1)
    MOVE SPACES TO WS-EXPECT
    STRING FUNCTION CHAR(196) FUNCTION CHAR(189) FUNCTION CHAR(227)
           FUNCTION CHAR(157) FUNCTION CHAR(148)
        DELIMITED BY SIZE INTO WS-EXPECT
    END-STRING
    MOVE 5 TO WS-EXPECT-LEN
    PERFORM CHECK-OUT

    MOVE "keeps malformed % escapes" TO WS-TEST-NAME
    MOVE "q=100%zz%4" TO WS-SRC
    MOVE 10 TO WS-SRC-LEN
    PERFORM GET-PARAM
    MOVE "100%zz%4" TO WS-EXPECT
    MOVE 8 TO WS-EXPECT-LEN
    PERFORM CHECK-OUT

    MOVE "truncates at the output limit" TO WS-TEST-NAME
    MOVE "q=abcdef" TO WS-SRC
    MOVE 8 TO WS-SRC-LEN
    MOVE 3 TO WS-OUT-MAX
    PERFORM GET-PARAM
    MOVE 1024 TO WS-OUT-MAX
    MOVE "abc" TO WS-EXPECT
    MOVE 3 TO WS-EXPECT-LEN
    PERFORM CHECK-OUT

    *> ---- HTML-ESCAPE -------------------------------------------
    MOVE "escapes HTML special characters" TO WS-TEST-NAME
    MOVE 1 TO RESP-PTR
    MOVE "<a href='x'>&" & '"' TO WS-SRC
    MOVE 14 TO WS-SRC-LEN
    CALL "HTML-ESCAPE" USING WS-SRC WS-SRC-LEN
    MOVE "&lt;a href=&#39;x&#39;&gt;&amp;&quot;" TO WS-EXPECT
    MOVE 37 TO WS-EXPECT-LEN
    COMPUTE WS-OUT-LEN = RESP-PTR - 1
    MOVE RESP-BODY(1:WS-OUT-LEN) TO WS-OUT
    PERFORM CHECK-OUT

    MOVE "HTML-ESCAPE appends, leaves plain text alone" TO WS-TEST-NAME
    MOVE "plain" TO WS-SRC
    MOVE 5 TO WS-SRC-LEN
    CALL "HTML-ESCAPE" USING WS-SRC WS-SRC-LEN
    MOVE "&lt;a href=&#39;x&#39;&gt;&amp;&quot;plain" TO WS-EXPECT
    MOVE 42 TO WS-EXPECT-LEN
    COMPUTE WS-OUT-LEN = RESP-PTR - 1
    MOVE RESP-BODY(1:WS-OUT-LEN) TO WS-OUT
    PERFORM CHECK-OUT

    *> ---- TEXT-LEN ----------------------------------------------
    MOVE "TEXT-LEN ignores trailing spaces" TO WS-TEST-NAME
    MOVE "  hi there   " TO WS-SRC
    MOVE 13 TO WS-MAX
    CALL "TEXT-LEN" USING WS-SRC WS-MAX WS-LEN
    MOVE "TEXT-LEN" TO WS-OUT
    IF WS-LEN = 10
        PERFORM PASS
    ELSE
        PERFORM FAIL
    END-IF

    *> ---- summary -----------------------------------------------
    DISPLAY SPACE
    MOVE WS-PASSED TO WS-DISP
    DISPLAY FUNCTION TRIM(WS-DISP) " passed, " WITH NO ADVANCING
    MOVE WS-FAILED TO WS-DISP
    DISPLAY FUNCTION TRIM(WS-DISP) " failed"
    IF WS-FAILED > 0
        MOVE 1 TO RETURN-CODE
    END-IF
    STOP RUN.

GET-PARAM.
    MOVE SPACES TO WS-OUT
    CALL "URL-PARAM" USING WS-SRC WS-SRC-LEN WS-NAME WS-NAME-LEN
                           WS-OUT WS-OUT-MAX WS-OUT-LEN WS-FOUND.

CHECK-OUT.
    IF WS-OUT-LEN = WS-EXPECT-LEN
       AND (WS-OUT-LEN = 0
            OR WS-OUT(1:WS-OUT-LEN) = WS-EXPECT(1:WS-EXPECT-LEN))
        PERFORM PASS
    ELSE
        PERFORM FAIL
        IF WS-OUT-LEN > 0
            DISPLAY "      got:      [" WS-OUT(1:WS-OUT-LEN) "]"
        ELSE
            DISPLAY "      got:      []"
        END-IF
        IF WS-EXPECT-LEN > 0
            DISPLAY "      expected: [" WS-EXPECT(1:WS-EXPECT-LEN) "]"
        ELSE
            DISPLAY "      expected: []"
        END-IF
    END-IF.

CHECK-NOT-FOUND.
    IF WS-FOUND = "N"
        PERFORM PASS
    ELSE
        PERFORM FAIL
    END-IF.

PASS.
    ADD 1 TO WS-PASSED
    DISPLAY "  ok    " FUNCTION TRIM(WS-TEST-NAME).

FAIL.
    ADD 1 TO WS-FAILED
    DISPLAY "  FAIL  " FUNCTION TRIM(WS-TEST-NAME).
END PROGRAM TEST-UTIL.

*> ------------------------------------------------------------
*> Note records loaded from / sent to the database.
*> ------------------------------------------------------------
78  NOTE-LIST-MAX               VALUE 200.
78  NOTE-TITLE-MAX              VALUE 1000.
78  NOTE-BODY-MAX               VALUE 262144.

01  NOTE-LIST EXTERNAL.
    05  NL-COUNT                BINARY-LONG.
    05  NL-ITEM OCCURS 200.
        10  NL-ID               PIC X(20).
        10  NL-ID-LEN           BINARY-LONG.
        10  NL-TITLE            PIC X(1000).
        10  NL-TITLE-LEN        BINARY-LONG.
        10  NL-SNIPPET          PIC X(800).
        10  NL-SNIPPET-LEN      BINARY-LONG.
        10  NL-UPDATED          PIC X(32).
        10  NL-UPDATED-LEN      BINARY-LONG.

01  NOTE-CURRENT EXTERNAL.
    05  NC-FOUND                PIC X.
    05  NC-ID                   PIC X(20).
    05  NC-ID-LEN               BINARY-LONG.
    05  NC-TITLE                PIC X(1000).
    05  NC-TITLE-LEN            BINARY-LONG.
    05  NC-BODY                 PIC X(262144).
    05  NC-BODY-LEN             BINARY-LONG.
    05  NC-CREATED              PIC X(32).
    05  NC-CREATED-LEN          BINARY-LONG.
    05  NC-UPDATED              PIC X(32).
    05  NC-UPDATED-LEN          BINARY-LONG.

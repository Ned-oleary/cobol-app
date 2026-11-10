*> ------------------------------------------------------------
*> Shared HTTP request/response state (one request per process).
*> ------------------------------------------------------------
78  REQ-BODY-MAX                VALUE 262144.
78  RESP-BODY-MAX               VALUE 2097152.

01  HTTP-REQUEST EXTERNAL.
    05  REQ-METHOD              PIC X(16).
    05  REQ-PATH                PIC X(2048).
    05  REQ-PATH-LEN            BINARY-LONG.
    05  REQ-QUERY               PIC X(2048).
    05  REQ-QUERY-LEN           BINARY-LONG.
    05  REQ-BODY                PIC X(262144).
    05  REQ-BODY-LEN            BINARY-LONG.

01  HTTP-RESPONSE EXTERNAL.
    05  RESP-STATUS             PIC 9(3).
    05  RESP-CTYPE              PIC X(64).
    05  RESP-LOCATION           PIC X(512).
    *> next free byte in RESP-BODY (body length = RESP-PTR - 1)
    05  RESP-PTR                BINARY-LONG.
    05  RESP-BODY               PIC X(2097152).

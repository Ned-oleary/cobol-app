*> ============================================================
*> server.cbl - COBOL Notes entry point.
*>
*> A fork-per-connection HTTP server written directly against
*> the BSD socket API. Each connection is handled in a
*> child process that opens its own PostgreSQL connection.
*>
*> Environment:
*>   PORT          listen port            (default 8080)
*>   HOST          IPv4 address to bind   (default 127.0.0.1)
*>   DATABASE_URL  libpq conninfo or URI  (default dbname=cobol_notes)
*>   PUBLIC_DIR    static files directory (default public)
*> ============================================================
IDENTIFICATION DIVISION.
PROGRAM-ID. COBOL-NOTES.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "platform.cpy".
COPY "db.cpy".
01  WS-ENV                      PIC X(1024).
01  WS-PORT                     BINARY-LONG VALUE 8080.
01  WS-PORT-DISP                PIC Z(4)9.
01  WS-HOST                     PIC X(64) VALUE "127.0.0.1".
01  WS-OCTETS.
    05  WS-OCTET-TXT            PIC X(3) OCCURS 4.
01  WS-OCTET-VAL                BINARY-LONG.
01  WS-OCTET-COUNT              BINARY-LONG.
01  WS-UTSNAME                  PIC X(2048).
01  WS-RC                       BINARY-LONG.
01  WS-LISTEN-FD                BINARY-LONG.
01  WS-CLIENT-FD                BINARY-LONG.
01  WS-PID                      BINARY-LONG.
01  WS-ONE                      BINARY-LONG VALUE 1.
01  WS-NULL                     USAGE POINTER VALUE NULL.
01  WS-SIG-IGN                  USAGE POINTER.
01  WS-I                        BINARY-LONG.
01  WS-SOCKADDR.
    05  SA-BYTE                 BINARY-CHAR UNSIGNED OCCURS 16.
PROCEDURE DIVISION.
MAIN-LOGIC.
    PERFORM LOAD-CONFIG
    PERFORM DETECT-PLATFORM
    PERFORM INIT-DATABASE
    PERFORM OPEN-LISTENER
    PERFORM SERVE-FOREVER
    STOP RUN.

LOAD-CONFIG.
    MOVE SPACES TO WS-ENV
    ACCEPT WS-ENV FROM ENVIRONMENT "PORT"
    IF WS-ENV NOT = SPACES
        IF FUNCTION TEST-NUMVAL(WS-ENV) = 0
            MOVE FUNCTION NUMVAL(WS-ENV) TO WS-PORT
        ELSE
            MOVE 0 TO WS-PORT
        END-IF
        IF WS-PORT < 1 OR WS-PORT > 65535
            DISPLAY "PORT must be a number from 1 to 65535" UPON SYSERR
            PERFORM FAIL
        END-IF
    END-IF

    MOVE SPACES TO WS-ENV
    ACCEPT WS-ENV FROM ENVIRONMENT "HOST"
    IF WS-ENV NOT = SPACES
        MOVE WS-ENV TO WS-HOST
    END-IF

    MOVE SPACES TO WS-ENV
    ACCEPT WS-ENV FROM ENVIRONMENT "DATABASE_URL"
    IF WS-ENV = SPACES
        MOVE "dbname=cobol_notes" TO WS-ENV
    END-IF
    MOVE LOW-VALUES TO DB-URL
    STRING FUNCTION TRIM(WS-ENV) DELIMITED BY SIZE INTO DB-URL
    END-STRING

    *> libpq's GSSAPI probe is not fork-safe on macOS; skip it
    *> unless the user explicitly asked for it.
    CALL "setenv" USING Z"PGGSSENCMODE" Z"disable" BY VALUE 0.

DETECT-PLATFORM.
    MOVE LOW-VALUES TO WS-UTSNAME
    CALL "uname" USING WS-UTSNAME RETURNING WS-RC
    IF WS-UTSNAME(1:6) = "Darwin"
        MOVE "Y"   TO PF-IS-DARWIN
        MOVE 65535 TO PF-SOL-SOCKET
        MOVE 4     TO PF-SO-REUSEADDR
        MOVE 4102  TO PF-SO-RCVTIMEO
        MOVE 4101  TO PF-SO-SNDTIMEO
        MOVE 20    TO PF-SIGCHLD
    ELSE
        *> Linux (x86-64 / arm64 values)
        MOVE "N"   TO PF-IS-DARWIN
        MOVE 1     TO PF-SOL-SOCKET
        MOVE 2     TO PF-SO-REUSEADDR
        MOVE 20    TO PF-SO-RCVTIMEO
        MOVE 21    TO PF-SO-SNDTIMEO
        MOVE 17    TO PF-SIGCHLD
    END-IF.

INIT-DATABASE.
    CALL "DB-CONNECT"
    IF DB-OK NOT = "Y"
        DISPLAY "Could not connect to PostgreSQL. Is it running, and "
                "does the database exist? (try: make db)" UPON SYSERR
        PERFORM FAIL
    END-IF
    CALL "DB-INIT-SCHEMA"
    IF DB-OK NOT = "Y"
        PERFORM FAIL
    END-IF
    *> children open their own connections; don't share this one
    CALL "DB-DISCONNECT".

OPEN-LISTENER.
    *> SIG_IGN is ((void (*)(int)) 1)
    SET WS-SIG-IGN TO NULL
    SET WS-SIG-IGN UP BY 1
    *> 13 = SIGPIPE: a vanished client must not kill us
    CALL "signal" USING BY VALUE 13 BY VALUE WS-SIG-IGN
    *> ignoring SIGCHLD makes the kernel reap finished children
    CALL "signal" USING BY VALUE PF-SIGCHLD BY VALUE WS-SIG-IGN

    *> socket(AF_INET = 2, SOCK_STREAM = 1, 0)
    CALL "socket" USING BY VALUE 2 BY VALUE 1 BY VALUE 0
        RETURNING WS-LISTEN-FD
    IF WS-LISTEN-FD < 0
        DISPLAY "socket() failed" UPON SYSERR
        PERFORM FAIL
    END-IF
    CALL "setsockopt" USING BY VALUE WS-LISTEN-FD
        BY VALUE PF-SOL-SOCKET BY VALUE PF-SO-REUSEADDR
        BY REFERENCE WS-ONE BY VALUE 4
        RETURNING WS-RC

    PERFORM BUILD-SOCKADDR
    CALL "bind" USING BY VALUE WS-LISTEN-FD BY REFERENCE WS-SOCKADDR
        BY VALUE 16 RETURNING WS-RC
    IF WS-RC NOT = 0
        MOVE WS-PORT TO WS-PORT-DISP
        DISPLAY "Could not bind " FUNCTION TRIM(WS-HOST) ":"
                FUNCTION TRIM(WS-PORT-DISP) " (already in use?)"
                UPON SYSERR
        PERFORM FAIL
    END-IF
    CALL "listen" USING BY VALUE WS-LISTEN-FD BY VALUE 64
        RETURNING WS-RC
    IF WS-RC NOT = 0
        DISPLAY "listen() failed" UPON SYSERR
        PERFORM FAIL
    END-IF

    MOVE WS-PORT TO WS-PORT-DISP
    DISPLAY "COBOL Notes listening on http://" FUNCTION TRIM(WS-HOST)
            ":" FUNCTION TRIM(WS-PORT-DISP).

*> struct sockaddr_in, byte by byte (BSD has a length byte first)
BUILD-SOCKADDR.
    MOVE LOW-VALUES TO WS-SOCKADDR
    IF PF-IS-DARWIN = "Y"
        MOVE 16 TO SA-BYTE(1)
        MOVE 2  TO SA-BYTE(2)
    ELSE
        MOVE 2  TO SA-BYTE(1)
        MOVE 0  TO SA-BYTE(2)
    END-IF
    *> port in network byte order
    COMPUTE SA-BYTE(3) = WS-PORT / 256
    COMPUTE SA-BYTE(4) = FUNCTION MOD(WS-PORT, 256)

    MOVE SPACES TO WS-OCTETS
    MOVE 0 TO WS-OCTET-COUNT
    UNSTRING WS-HOST DELIMITED BY "." OR SPACE
        INTO WS-OCTET-TXT(1) WS-OCTET-TXT(2)
             WS-OCTET-TXT(3) WS-OCTET-TXT(4)
        TALLYING IN WS-OCTET-COUNT
    END-UNSTRING
    IF WS-OCTET-COUNT < 4
        PERFORM BAD-HOST
    END-IF
    PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 4
        IF WS-OCTET-TXT(WS-I) = SPACES
           OR FUNCTION TEST-NUMVAL(WS-OCTET-TXT(WS-I)) NOT = 0
            PERFORM BAD-HOST
        END-IF
        MOVE FUNCTION NUMVAL(WS-OCTET-TXT(WS-I)) TO WS-OCTET-VAL
        IF WS-OCTET-VAL < 0 OR WS-OCTET-VAL > 255
            PERFORM BAD-HOST
        END-IF
        MOVE WS-OCTET-VAL TO SA-BYTE(4 + WS-I)
    END-PERFORM.

BAD-HOST.
    DISPLAY "HOST must be an IPv4 address like 127.0.0.1 or 0.0.0.0"
        UPON SYSERR
    PERFORM FAIL.

SERVE-FOREVER.
    PERFORM FOREVER
        CALL "accept" USING BY VALUE WS-LISTEN-FD
            BY VALUE WS-NULL BY VALUE WS-NULL
            RETURNING WS-CLIENT-FD
        IF WS-CLIENT-FD >= 0
            CALL "fork" RETURNING WS-PID
            EVALUATE TRUE
                WHEN WS-PID = 0
                    *> child: serve this one connection, then exit
                    CALL "close" USING BY VALUE WS-LISTEN-FD
                    CALL "HANDLE-CONNECTION" USING WS-CLIENT-FD
                    CALL "close" USING BY VALUE WS-CLIENT-FD
                    CALL "fflush" USING BY VALUE WS-NULL
                    CALL "_exit" USING BY VALUE 0 RETURNING OMITTED
                WHEN WS-PID > 0
                    CALL "close" USING BY VALUE WS-CLIENT-FD
                WHEN OTHER
                    *> fork failed: serve it inline rather than drop it
                    CALL "HANDLE-CONNECTION" USING WS-CLIENT-FD
                    CALL "close" USING BY VALUE WS-CLIENT-FD
            END-EVALUATE
        END-IF
    END-PERFORM.

FAIL.
    MOVE 1 TO RETURN-CODE
    STOP RUN.
END PROGRAM COBOL-NOTES.

*> ------------------------------------------------------------
*> OS-specific constants, filled in at startup from uname(2).
*> ------------------------------------------------------------
01  PLATFORM EXTERNAL.
    05  PF-IS-DARWIN            PIC X.
    05  PF-SOL-SOCKET           BINARY-LONG.
    05  PF-SO-REUSEADDR         BINARY-LONG.
    05  PF-SO-RCVTIMEO          BINARY-LONG.
    05  PF-SO-SNDTIMEO          BINARY-LONG.
    05  PF-SIGCHLD              BINARY-LONG.

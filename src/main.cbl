      *> ------------------------------------------------------------
      *> cobol-app: entry point
      *> ------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MAIN.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-GREETING         PIC X(20) VALUE "Hello from COBOL!".

       PROCEDURE DIVISION.
           DISPLAY FUNCTION TRIM(WS-GREETING)
           STOP RUN.

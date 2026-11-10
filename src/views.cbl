*> ============================================================
*> views.cbl - HTML rendering into the response body.
*> Every piece of user data goes through HTML-ESCAPE.
*> ============================================================

*> ------------------------------------------------------------
*> LAYOUT-START: doctype, <head> and site header.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. LAYOUT-START.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
LINKAGE SECTION.
01  LS-TITLE                    PIC X(1000).
01  LS-TITLE-LEN                BINARY-LONG.
PROCEDURE DIVISION USING LS-TITLE LS-TITLE-LEN.
    STRING
        '<!doctype html>' X"0A"
        '<html lang="en">' X"0A"
        '<head>' X"0A"
        '<meta charset="utf-8">' X"0A"
        '<meta name="viewport" content="width=device-width, '
        'initial-scale=1">' X"0A"
        '<title>'
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    CALL "HTML-ESCAPE" USING LS-TITLE LS-TITLE-LEN
    STRING
        ' &middot; COBOL Notes</title>' X"0A"
        '<link rel="stylesheet" href="/style.css">' X"0A"
        '</head>' X"0A"
        '<body>' X"0A"
        '<header class="site">' X"0A"
        '  <a class="brand" href="/">'
        '<span class="brand-mark">&#9646;</span> COBOL Notes</a>' X"0A"
        '  <span class="tagline">IDENTIFICATION DIVISION. '
        'PROGRAM-ID. YOUR-THOUGHTS.</span>' X"0A"
        '</header>' X"0A"
        '<main>' X"0A"
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    GOBACK.
END PROGRAM LAYOUT-START.

*> ------------------------------------------------------------
*> LAYOUT-END: footer and closing tags.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. LAYOUT-END.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
PROCEDURE DIVISION.
    STRING
        '</main>' X"0A"
        '<footer class="site">Served by GnuCOBOL '
        '&amp; PostgreSQL. STOP RUN.</footer>' X"0A"
        '</body>' X"0A"
        '</html>' X"0A"
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    GOBACK.
END PROGRAM LAYOUT-END.

*> ------------------------------------------------------------
*> VIEW-INDEX: new-note form, search box and the note list.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. VIEW-INDEX.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
COPY "notes.cpy".
01  WS-I                        BINARY-LONG.
01  WS-COUNT-DISP               PIC ZZ9.
01  WS-PAGE-TITLE               PIC X(1000) VALUE "All notes".
01  WS-PAGE-TITLE-LEN           BINARY-LONG VALUE 9.
LINKAGE SECTION.
01  LS-Q                        PIC X(2048).
01  LS-Q-LEN                    BINARY-LONG.
PROCEDURE DIVISION USING LS-Q LS-Q-LEN.
    CALL "LAYOUT-START" USING WS-PAGE-TITLE WS-PAGE-TITLE-LEN

    STRING
        '<section class="card compose">' X"0A"
        '  <h2>New note</h2>' X"0A"
        '  <form method="post" action="/notes">' X"0A"
        '    <input class="title-input" name="title" '
        'placeholder="Title" maxlength="200" autocomplete="off" '
        'required>' X"0A"
        '    <textarea name="body" rows="5" '
        'placeholder="Write something&hellip;"></textarea>' X"0A"
        '    <div class="actions"><button type="submit">'
        'Save note</button></div>' X"0A"
        '  </form>' X"0A"
        '</section>' X"0A"
        '<section class="notes">' X"0A"
        '  <div class="notes-head">' X"0A"
        '    <h2>Notes</h2>' X"0A"
        '    <form class="search" method="get" action="/">' X"0A"
        '      <input type="search" name="q" placeholder="Search notes" '
        'value="'
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    CALL "HTML-ESCAPE" USING LS-Q LS-Q-LEN
    STRING
        '">' X"0A"
        '      <button type="submit" class="secondary">Search</button>'
        X"0A"
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    IF LS-Q-LEN > 0
        STRING
            '      <a class="clear" href="/">Clear</a>' X"0A"
            DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
        END-STRING
    END-IF
    STRING
        '    </form>' X"0A"
        '  </div>' X"0A"
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING

    IF NL-COUNT = 0
        IF LS-Q-LEN > 0
            STRING
                '  <p class="empty">No notes match that search.</p>'
                X"0A"
                DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
            END-STRING
        ELSE
            STRING
                '  <p class="empty">No notes yet. '
                'Write your first one above.</p>' X"0A"
                DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
            END-STRING
        END-IF
    ELSE
        MOVE NL-COUNT TO WS-COUNT-DISP
        STRING
            '  <p class="count">' FUNCTION TRIM(WS-COUNT-DISP)
            DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
        END-STRING
        IF NL-COUNT = 1
            STRING ' note</p>' X"0A"
                DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
            END-STRING
        ELSE
            STRING ' notes</p>' X"0A"
                DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
            END-STRING
        END-IF
        STRING '  <ul class="note-list">' X"0A"
            DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
        END-STRING
        PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > NL-COUNT
            PERFORM RENDER-ITEM
        END-PERFORM
        STRING '  </ul>' X"0A"
            DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
        END-STRING
    END-IF

    STRING '</section>' X"0A"
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    CALL "LAYOUT-END"
    GOBACK.

RENDER-ITEM.
    STRING
        '    <li><a href="/notes/' NL-ID(WS-I)(1:NL-ID-LEN(WS-I)) '">'
        X"0A" '      <h3>'
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    CALL "HTML-ESCAPE" USING NL-TITLE(WS-I) NL-TITLE-LEN(WS-I)
    STRING '</h3>' X"0A"
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    IF NL-SNIPPET-LEN(WS-I) > 0
        STRING '      <p>'
            DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
        END-STRING
        CALL "HTML-ESCAPE" USING NL-SNIPPET(WS-I) NL-SNIPPET-LEN(WS-I)
        STRING '</p>' X"0A"
            DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
        END-STRING
    END-IF
    STRING '      <time>'
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    CALL "HTML-ESCAPE" USING NL-UPDATED(WS-I) NL-UPDATED-LEN(WS-I)
    STRING '</time>' X"0A" '    </a></li>' X"0A"
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING.
END PROGRAM VIEW-INDEX.

*> ------------------------------------------------------------
*> VIEW-NOTE: edit form for NOTE-CURRENT, plus delete button.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. VIEW-NOTE.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
COPY "notes.cpy".
PROCEDURE DIVISION.
    CALL "LAYOUT-START" USING NC-TITLE NC-TITLE-LEN
    STRING
        '<p class="back"><a href="/">&larr; All notes</a></p>' X"0A"
        '<section class="card">' X"0A"
        '  <form method="post" action="/notes/' NC-ID(1:NC-ID-LEN)
        '">' X"0A"
        '    <input class="title-input" name="title" maxlength="200" '
        'autocomplete="off" required value="'
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    CALL "HTML-ESCAPE" USING NC-TITLE NC-TITLE-LEN
    *> the newline right after <textarea> is swallowed by the HTML
    *> parser, so a body that starts with a newline survives
    STRING
        '">' X"0A"
        '    <textarea name="body" rows="18">' X"0A"
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    CALL "HTML-ESCAPE" USING NC-BODY NC-BODY-LEN
    STRING
        '</textarea>' X"0A"
        '    <div class="actions">' X"0A"
        '      <button type="submit">Save changes</button>' X"0A"
        '      <span class="meta">Created '
        NC-CREATED(1:NC-CREATED-LEN)
        ' &middot; Updated '
        NC-UPDATED(1:NC-UPDATED-LEN)
        '</span>' X"0A"
        '    </div>' X"0A"
        '  </form>' X"0A"
        '</section>' X"0A"
        '<form class="delete" method="post" action="/notes/'
        NC-ID(1:NC-ID-LEN) '/delete">' X"0A"
        '  <button type="submit" class="danger">Delete note</button>'
        X"0A"
        '</form>' X"0A"
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    CALL "LAYOUT-END"
    GOBACK.
END PROGRAM VIEW-NOTE.

*> ------------------------------------------------------------
*> PAGE-ERROR: full error page for RESP-STATUS with MSG.
*> ------------------------------------------------------------
IDENTIFICATION DIVISION.
PROGRAM-ID. PAGE-ERROR.
DATA DIVISION.
WORKING-STORAGE SECTION.
COPY "http.cpy".
01  WS-TITLE                    PIC X(1000).
01  WS-TITLE-LEN                BINARY-LONG.
01  WS-MSG-LEN                  BINARY-LONG.
01  WS-MAX                      BINARY-LONG VALUE 256.
LINKAGE SECTION.
01  LS-MSG                      PIC X(256).
PROCEDURE DIVISION USING LS-MSG.
    MOVE 1 TO RESP-PTR
    MOVE "text/html; charset=utf-8" TO RESP-CTYPE
    MOVE SPACES TO RESP-LOCATION
    MOVE SPACES TO WS-TITLE
    STRING "Error " RESP-STATUS DELIMITED BY SIZE INTO WS-TITLE
    END-STRING
    MOVE 9 TO WS-TITLE-LEN
    CALL "TEXT-LEN" USING LS-MSG WS-MAX WS-MSG-LEN
    CALL "LAYOUT-START" USING WS-TITLE WS-TITLE-LEN
    STRING
        '<section class="card error">' X"0A"
        '  <h2>' WS-TITLE(1:WS-TITLE-LEN) '</h2>' X"0A"
        '  <p>'
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    CALL "HTML-ESCAPE" USING LS-MSG WS-MSG-LEN
    STRING
        '</p>' X"0A"
        '  <p><a href="/">&larr; Back to all notes</a></p>' X"0A"
        '</section>' X"0A"
        DELIMITED BY SIZE INTO RESP-BODY WITH POINTER RESP-PTR
    END-STRING
    CALL "LAYOUT-END"
    GOBACK.
END PROGRAM PAGE-ERROR.

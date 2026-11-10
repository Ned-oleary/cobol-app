# cobol-app: COBOL Notes

A small note-taking web app whose backend is written entirely in COBOL:
the HTTP server, routing, form parsing, HTML rendering and PostgreSQL access.
The only non-COBOL parts of the app are the stylesheet and the HTML inside
the views. No frameworks, no CGI, no C shims. The COBOL calls the BSD socket
API and libpq directly.

## Prerequisites

- GnuCOBOL 3.x (`cobc`)
- PostgreSQL with libpq (`pg_config`, `psql` and `createdb` on your `PATH`)

macOS:

```sh
brew install gnucobol postgresql@17 libpq
brew services start postgresql@17
```

Debian/Ubuntu: `sudo apt install gnucobol postgresql libpq-dev`

## Quick start

```sh
make db     # create the cobol_notes database (once)
make run    # build and serve on http://127.0.0.1:8080
```

The server creates the `notes` table on startup if it does not exist.

## Configuration

Set with environment variables:

| Variable       | Default              | Notes                                      |
| -------------- | -------------------- | ------------------------------------------ |
| `PORT`         | `8080`               |                                            |
| `HOST`         | `127.0.0.1`          | IPv4 only; `0.0.0.0` to listen on all      |
| `DATABASE_URL` | `dbname=cobol_notes` | any libpq conninfo or `postgres://` URI    |
| `PUBLIC_DIR`   | `public`             | where `style.css` is served from           |

Standard libpq variables (`PGHOST`, `PGUSER`, `PGPASSWORD`, …) also work.

## Routes

| Method | Path                  | What it does                        |
| ------ | --------------------- | ----------------------------------- |
| GET    | `/`                   | list notes; `?q=` searches them     |
| POST   | `/notes`              | create a note                       |
| GET    | `/notes/{id}`         | view and edit a note                |
| POST   | `/notes/{id}`         | save changes                        |
| POST   | `/notes/{id}/delete`  | delete a note                       |
| GET    | `/style.css`          | stylesheet                          |

Plain HTML forms with POST/redirect/GET, and no JavaScript.

## Tests

```sh
make test        # both of the below
make test-unit   # COBOL unit tests for parsing/escaping (tests/test-util.cbl)
make test-smoke  # end-to-end HTTP checks against a scratch database
```

The smoke test is a bash + curl script (`tests/smoke.sh`). It creates and
drops a `cobol_notes_smoke` database.

## How it works

```
src/server.cbl     main: config, socket/bind/listen, accept loop, fork per connection
src/http.cbl       read + parse one HTTP/1.1 request, write the response
src/router.cbl     METHOD + PATH -> handler
src/handlers.cbl   page/action handlers and static file serving
src/views.cbl      HTML rendering (all user data is HTML-escaped)
src/notes-db.cbl   PostgreSQL via libpq (parameterized queries only)
src/util.cbl       URL decoding, form parsing, HTML escaping
copy/*.cpy         shared EXTERNAL records (request, response, db, notes)
public/style.css   the stylesheet
```

- **Concurrency:** the server forks one child per connection. Each child opens
  its own Postgres connection, handles one request, and exits. Ignoring
  `SIGCHLD` lets the kernel reap the children. Sockets have a 10-second
  timeout, so an idle client can't hold a worker open.
- **Portability:** `struct sockaddr_in` is built byte by byte. The few
  constants that differ between macOS and Linux (socket options, `SIGCHLD`)
  are picked at startup from `uname(2)`.
- **Limits:** request bodies are capped at 256 KB (413 above that), headers
  at 16 KB, and titles at 200 characters. The list shows the 200 most
  recently updated notes.
- **Security:** there is no authentication and no CSRF protection, so it binds
  to localhost by default. Don't expose it to a network you don't trust.

## Build notes

`cobc -fstatic-call` links each `CALL "socket"` or `CALL "PQexecParams"`
directly to the C symbol. Strings passed to C are NUL-terminated by hand, and
`char *` results are read by pointing a `LINKAGE SECTION` item at them with
`SET ADDRESS OF`.

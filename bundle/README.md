# tezcatlipoca

Tezcatl in Poca, without Nix: one directory with everything to run [tezcatl](https://github.com/Crux-xurC/tezcatl) — a local,
web-based development environment that uses Emacs as a backend — in [Poca](https://github.com/Crux-xurC/poca), its browser, with
[Xipe Totec](https://github.com/Crux-xurC/xipe_totec) and [emacs-vent](https://github.com/Crux-xurC/emacs-vent). The versions bundled
are in `BUILD` (`bin/tezcatlipoca version`).

| Directory | What |
|---|---|
| `tezcatl/` | tezcatl without Nix (tezcatl_without_nix): the pages, and the relay as a release with Erlang's runtime |
| `xipe_totec/` | Xipe Totec without Nix (xipe_totec_without_nix), its server and CLI as a release |
| `poca/` | Poca, built (CEF included) |
| `emacs-vent/` | the Emacs side, loaded into your Emacs |
| `embody/` | what Xipe Totec loads into the REPLs of every language but Elixir |
| `bin/tezcatlipoca` | `setup`, `start`, `check`, `version` |

## Requirements

- Linux x86_64 with a glibc at least as new as the one in `BUILD`, and the system libraries Poca (Chromium) and the Erlang runtime use:
  X11 / Wayland, GTK's GLib, NSS, ALSA, OpenSSL 3, libcap … OpenSSL 3 means one at least as new as the version the Erlang runtime
  asks for, which may be later than 3.0 (`BUILD` records the OpenSSL it was built with). `bin/tezcatlipoca check` lists what is
  missing, naming the library or the version (e.g. `GLIBC_2.43`, `OPENSSL_3.4.0`) this machine lacks
- **A machine only you log in to.** Nothing guards against other users of the same machine: `127.0.0.1` is open to every user, and
  the relay (`:4100`), emacs-vent (`:4000`) and Xipe Totec (`:4200`) accept connections without a secret from programs that are not
  a browser — another user could reach a shell, your files and your Emacs as you. Do not run it on a shared host
  (`tezcatl/docs/scope.md`, "Other users of the same machine")
- Emacs with the `websocket` package (`M-x package-install RET websocket`)
- Optional: ripgrep (`rg`) for `:grep`; the language servers you want (`tezcatl/lsp/README.md`); for Xipe Totec, the REPLs and build
  tools of your projects (`iex`, `ocaml`, `ghci`, `python3`, `dotnet`, `scala` with `sbt` or `scala-cli`, `java` with `mvn`;
  `xipe_totec/document/how-to-use.md` §9)
- **Scala and Java projects: build them once yourself, online, before the first evaluation** (`sbt compile`, `scala-cli compile .`,
  `mvn compile`). Xipe Totec fetches nothing; with the build tool's cache empty the rows fail with `Error downloading …`

Elixir is not needed to run it (the releases carry their own runtime), but Xipe Totec evaluates an Elixir project in that project's
own `iex`.

## Start

```sh
tar xzf tezcatlipoca-<version>-linux-x86_64.tar.gz
cd tezcatlipoca-<version>
bin/tezcatlipoca check
bin/tezcatlipoca setup --fs-root ~/projects     # where files and terminals are opened; --no-emacs to start your own Emacs
xipe_totec/bin/xipe choice project ~/projects/foo   # the project Xipe Totec works on (once; again to change it)
bin/tezcatlipoca start                           # Poca
```

In Poca, open box (`Ctrl+Shift+B`), start `emacs`, `xipe_totec` and `tezcatl`, then open the bookmark `tezcatl`
(`http://127.0.0.1:4001/main.html`) and pick `frame`. `setup` writes those rows into Poca's `~/.config/poca/box.json` and the
bookmark into `~/.config/poca/bookmarks.json`, keeping your other rows and bookmarks and the files before
(`box.json.bak-<time>`, `bookmarks.json.bak-<time>`); run it again to change them. The rows hold this directory's path: after
moving or renaming it, run `setup` again.

**Stop them before Poca ends.** Closing Poca's last window stops what it started; Poca ending any other way (logging out with
its window open, Poca killed) leaves them running, and the ports stay taken — for the next user of the machine too, whose
tezcatl would then reach your shell and files. Stop the rows in box before closing Poca (or close its windows). `check` and
`start` say who holds the ports (4000, 4001, 4100, 4200); `start` refuses while another user holds one. What is left of your
own: `pgrep -u $USER -af '<this directory>/|fg-daemon=tezcatlipoca'` shows it, `pkill` with the same arguments stops it.
Another user's can be stopped only by that user or by root.

Without Poca: `tezcatl/bin/t --no-auth` and any Chromium-based browser.

## An AI agent through Xipe Totec (MCP)

With `xipe_totec` started, an MCP client (Claude Code …) can use it: in your project's `.mcp.json`,

```json
{ "mcpServers": { "xipe-totec": { "command": "<this directory>/xipe_totec/bin/xipe", "args": ["mcp"] } } }
```

The agent searches and reads functions, adds calc rows and evaluates them in the Book you see. It only proposes a function's
side-effect class, with a reason; that function is not evaluated until you approve it — in tezcatl's matrix,
`matrix get xipe_classes:all`, select the rows, `matrix approve` (`g d` shows a function's source), or
`xipe_totec/bin/xipe do effect/approve 'ids=[…]'`. An approval covers the function's own body: a row's arguments (code the agent
writes) and the functions it calls are not approved — read the arguments of the agent's rows (`xipe_totec/document/scope.md`,
Evaluation). More: `xipe_totec/document/mcp.md`.

## Documents

How to use and extend tezcatl: `tezcatl/docs/how-to-use.md`, `tezcatl/README.tezcatl.md`. Xipe Totec: `xipe_totec/README.xipe_totec.md` (the
short entrance; the whole is `README.full.md`), `xipe_totec/document/how-to-use.md`. Poca: `poca/README.md` (in this bundle, start it with `bin/tezcatlipoca start`).

## Status

0.x: a combination checked together on one machine (Arch Linux). Numbered 0.x until combinations have been checked over time.

## Licenses

tezcatl, Xipe Totec, Poca, embody: MIT (each directory's `LICENSE`). emacs-vent: GPL-3.0-or-later. Poca includes CEF and Chromium,
under their own licenses: `poca/LICENSE-CEF.txt` and `poca/CREDITS-Chromium.html`. The releases in `tezcatl/` and `xipe_totec/`
carry Erlang/OTP's runtime, Elixir's standard library (both Apache-2.0) and Hex packages (cowboy, gun, erlexec, myxql …), each under
its own license: `licenses/README.md` lists them, with their license texts in `licenses/`.

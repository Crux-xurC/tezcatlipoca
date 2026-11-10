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
| `embody/` | what Xipe Totec loads into OCaml / Haskell REPLs |
| `bin/tezcatlipoca` | `setup`, `start`, `check`, `version` |

## Requirements

- Linux x86_64 with a glibc at least as new as the one in `BUILD`, and the system libraries Poca (Chromium) and the Erlang runtime use:
  X11 / Wayland, GTK's GLib, NSS, ALSA, OpenSSL 3, libcap … — `bin/tezcatlipoca check` lists what is missing
- Emacs with the `websocket` package (`M-x package-install RET websocket`)
- Optional: ripgrep (`rg`) for `:grep`; the language servers you want (`tezcatl/lsp/README.md`); for Xipe Totec, the REPLs of your
  projects (`iex`, `ocaml`, `ghci`)

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

In Poca, open box (`Ctrl+Shift+B`), start `emacs`, `xipe_totec` and `tezcatl`, then open `http://127.0.0.1:4001/main.html` and pick
`frame`. `setup` writes those rows into Poca's `~/.config/poca/box.json`, keeping your other rows and the file before
(`box.json.bak-<time>`); run it again to change them. Closing Poca's last window stops what it started.

Without Poca: `tezcatl/bin/t --no-auth` and any Chromium-based browser.

## Documents

How to use and extend tezcatl: `tezcatl/docs/how-to-use.md`, `tezcatl/README.tezcatl.md`. Xipe Totec: `xipe_totec/README.md`,
`xipe_totec/document/how-to-use.md`. Poca: `poca/README.md`.

## Status

0.x: a combination checked together on one machine (Arch Linux). Numbered 0.x until combinations have been checked over time.

## Licenses

tezcatl, Xipe Totec, Poca, embody: MIT (each directory's `LICENSE`). emacs-vent: GPL-3.0-or-later. Poca includes CEF and Chromium,
under their own licenses: `poca/LICENSE-CEF.txt` and `poca/CREDITS-Chromium.html`.

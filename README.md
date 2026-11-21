# tezcatlipoca

**tezcatl** is a local, web-based development environment that uses Emacs as a backend instead of re-implementing it. tezcatl is
the window (an editor, file trees and terminals in a browser page): it decides how things are operated and shown, and sends what you
type to the backends without interpreting it — Emacs through [emacs-vent](https://github.com/Crux-xurC/emacs-vent) (Magit, Org,
dired …), a terminal, the disk, language servers, and [Xipe Totec](https://github.com/Crux-xurC/xipe_totec), which evaluates code
in your project's REPL (Elixir, OCaml, Haskell, Python, F#, C#, Scala, Java) and can be used by an AI agent over MCP. [Poca](https://github.com/Crux-xurC/poca) is the small Chromium-based browser it
opens in, which starts the backends and stops them when its last window closes.

What it looks like: [Xipe Totec's README](https://github.com/Crux-xurC/xipe_totec#readme) has a screenshot and a 3.5-minute video of an AI agent trying a library's functions over MCP, with tezcatl as the window.

Tezcatl in Poca, without Nix: a tarball with everything to run [tezcatl](https://github.com/Crux-xurC/tezcatl) in
[Poca](https://github.com/Crux-xurC/poca), with [Xipe Totec](https://github.com/Crux-xurC/xipe_totec) and
[emacs-vent](https://github.com/Crux-xurC/emacs-vent) — on Linux x86_64, with no Nix and no Elixir to install.

**To use it**, take the tarball from this repository's Releases and read its `README.md` (the same as
[`bundle/README.md`](bundle/README.md) here). Before downloading (about 200 MB), note what it needs: Linux x86_64 with a glibc at
least as new as the building machine's (each release's notes and `BUILD` say which), Emacs, and a machine only you log in to.

This repository holds no code of its own beyond packaging: which commits go together (`versions.lock`), how the tarball is made
(`build.sh`), and the `tezcatlipoca` command and README the tarball carries (`bundle/`).

| Component | Repository | In the tarball |
|---|---|---|
| tezcatl without Nix | tezcatl_without_nix — [tezcatl (Nix management)](https://github.com/Crux-xurC/tezcatl) made a Mix project | `tezcatl/`, the relay as a release |
| Xipe Totec without Nix | xipe_totec_without_nix — [xipe_totec (Nix management)](https://github.com/Crux-xurC/xipe_totec) made a Mix project | `xipe_totec/`, as a release |
| Poca | [poca](https://github.com/Crux-xurC/poca) | `poca/`, built, CEF included |
| emacs-vent | [emacs-vent](https://github.com/Crux-xurC/emacs-vent) | `emacs-vent/` |
| embody | [embody](https://github.com/Crux-xurC/embody) | `embody/` |

## Making the tarball

```sh
./build.sh      # -> dist/tezcatlipoca-<VERSION>-linux-x86_64.tar.gz and its .sha256
```

It needs git and network access (the repositories, Hex, and the license texts of Erlang/OTP and Elixir from their tags), Elixir 1.18
or later with Erlang/OTP 27 or later, gcc/g++, make, libcap, CMake 3.21+, ninja, strip, and the CEF
binary distribution the locked Poca names, where Poca looks for it (`~/.local/share/cef/<distribution>`, or `CEF_ROOT`; `POCA_VENDOR`, a
directory holding distributions, is still read). Run it outside any Nix shell: the releases carry the
Erlang runtime they are built with, and the result needs a glibc (and an OpenSSL) at least as new as the building machine's
(recorded in the tarball's `BUILD`), so build on an old one for the tarball to run widely. Each run builds the locked commits from
clean checkouts (`TEZCATLIPOCA_KEEP_BUILDS=1` keeps `_build` and `deps` between runs, for trying a build), and the tarball is made
with sorted names, owner 0/0, modes independent of the umask and one time stamp, `SOURCE_DATE_EPOCH` (by default the newest of the locked commits and this
repository's). The checkouts and builds stay in `_work/` between runs. Their path is written into what is built (Elixir's
`__DIR__`, C++'s `__FILE__`), so for a tarball to publish set `TEZCATLIPOCA_WORK` to a directory without personal names in its path
(e.g. `/var/tmp/tezcatlipoca`); `build.sh` stops when the tarball would hold `$HOME`'s path or a directory named as the user.

## Updating

1. Publish tezcatl and push xipe_totec, then sync the without-Nix repositories from them (their `sync/README.md`) and push them.
   `build.sh` stops when a locked without-Nix commit was not synced from its upstream's `main` as published (compared by tree,
   `sync/UPSTREAM_TREE`; `TEZCATLIPOCA_ALLOW_LAG=1` builds anyway, not for a release)
2. Raise `VERSION`, and to the same version the one `xipe version` prints (xipe_totec's `lib/help.exs`, before step 1's sync) and
   the two without-Nix repositories' `mix.exs`; put the new commits in `versions.lock`
3. `./build.sh`, unpack the tarball somewhere else, `bin/tezcatlipoca check`, `setup`, `start`, and use it: tezcatl, Xipe Totec and
   Emacs from Poca's box
4. Commit, tag `v<VERSION>`, and attach the tarball and its `.sha256` to a release

## License

MIT ([LICENSE](LICENSE)). The tarball's components keep their own licenses (its README, "Licenses").

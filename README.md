# tezcatlipoca

Tezcatl in Poca, without Nix: a tarball with everything to run [tezcatl](https://github.com/Crux-xurC/tezcatl) in
[Poca](https://github.com/Crux-xurC/poca), with [Xipe Totec](https://github.com/Crux-xurC/xipe_totec) and
[emacs-vent](https://github.com/Crux-xurC/emacs-vent) — on Linux x86_64, with no Nix and no Elixir to install.

**To use it**, take the tarball from this repository's Releases and read its `README.md` (the same as
[`bundle/README.md`](bundle/README.md) here).

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
binary distribution Poca's README names (`POCA_VENDOR`, default `../poca/vendor`). Run it outside any Nix shell: the releases carry the
Erlang runtime they are built with, and the result needs a glibc at least as new as the building machine's (recorded in the tarball's
`BUILD`). The checkouts and builds stay in `_work/` between runs. Their path is written into what is built (Elixir's
`__DIR__`, C++'s `__FILE__`), so for a tarball to publish set `TEZCATLIPOCA_WORK` to a directory without personal names in its path
(e.g. `/var/tmp/tezcatlipoca`); `build.sh` stops when the tarball would hold `$HOME`'s path.

## Updating

1. Sync the without-Nix repositories from their upstreams (their `sync/README.md`) and push them
2. Put the new commits in `versions.lock`, raise `VERSION`
3. `./build.sh`, unpack the tarball somewhere else, `bin/tezcatlipoca check`, `setup`, `start`, and use it: tezcatl, Xipe Totec and
   Emacs from Poca's box
4. Commit, tag `v<VERSION>`, and attach the tarball and its `.sha256` to a release

## License

MIT ([LICENSE](LICENSE)). The tarball's components keep their own licenses (its README, "Licenses").

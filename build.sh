#!/usr/bin/env bash
# build.sh -- make the tezcatlipoca tarball from the commits in versions.lock.
#
#   ./build.sh          -> dist/tezcatlipoca-<VERSION>-linux-x86_64.tar.gz (+ .sha256)
#
# For each component it clones (once) into _work/src/<name>, checks out the
# locked commit, and builds what needs building:
#   tezcatl_without_nix, xipe_totec_without_nix  mix release (Erlang's runtime included)
#   poca                                        cmake, in _work/poca-build (CEF from POCA_VENDOR)
#   embody, emacs-vent                          nothing (files)
# then puts each component's committed files (git archive) and its build into
# _work/stage/tezcatlipoca-<VERSION>/, with bundle/ (the tezcatlipoca command,
# its README), and makes the tarball.
#
# Needs: git (with access to the repositories), Elixir and Erlang/OTP, gcc/g++,
# make, libcap, CMake 3.21+, ninja, strip, and the CEF binary distribution
# Poca's README names: POCA_VENDOR is the directory holding it (Poca's
# vendor/; default ../poca/vendor beside this repository). Build outside any
# Nix shell: the releases carry the Erlang runtime they are built with.
#
# The result runs on Linux x86_64 with a glibc at least as new as this
# machine's (written into the tarball's BUILD file).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# where the checkouts and builds go. Its path is written into what is built
# (Elixir's __DIR__, C++'s __FILE__), so for a tarball to publish use one
# without personal names in it, e.g. TEZCATLIPOCA_WORK=/var/tmp/tezcatlipoca
work="${TEZCATLIPOCA_WORK:-$root/_work}"
version="$(tr -d '[:space:]' < "$root/VERSION")"
name="tezcatlipoca-$version-linux-x86_64"
stage="$work/stage/tezcatlipoca-$version"
POCA_VENDOR="${POCA_VENDOR:-$root/../poca/vendor}"

if [ -n "${IN_NIX_SHELL:-}" ]; then
  echo "build.sh: run outside a Nix shell (the releases would carry Nix's Erlang)" >&2
  exit 1
fi
[ -d "$POCA_VENDOR" ] || { echo "build.sh: no CEF at POCA_VENDOR=$POCA_VENDOR (see Poca's README, Build)" >&2; exit 1; }

# --- the locked commits ----------------------------------------------------------
declare -A url commit
order=()
while read -r n u c; do
  case "$n" in ''|'#'*) continue ;; esac
  url[$n]="$u"; commit[$n]="$c"; order+=("$n")
done < "$root/versions.lock"

mkdir -p "$work/src"
for n in "${order[@]}"; do
  src="$work/src/$n"
  if [ ! -d "$src/.git" ]; then
    echo "build.sh: clone $n"
    git clone --quiet "${url[$n]}" "$src"
  fi
  # the lock's URL, also for a checkout made from an earlier lock
  git -C "$src" remote set-url origin "${url[$n]}"
  git -C "$src" fetch --quiet origin
  git -C "$src" checkout --quiet --detach "${commit[$n]}"
  # anything not committed, except the builds kept between runs
  git -C "$src" clean -fdxq -e /_build -e /deps
  echo "build.sh: $n at $(git -C "$src" rev-parse --short HEAD)"
done

# --- builds ----------------------------------------------------------------------
for n in tezcatl_without_nix xipe_totec_without_nix; do
  echo "build.sh: release of $n"
  ( cd "$work/src/$n" && bin/release ) > "$work/$n.release.log" 2>&1 \
    || { echo "build.sh: release of $n failed: $work/$n.release.log" >&2; exit 1; }
done

echo "build.sh: Poca (cmake)"
ln -sfn "$(cd "$POCA_VENDOR" && pwd)" "$work/src/poca/vendor"
cmake -S "$work/src/poca" -B "$work/poca-build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  "-DCMAKE_CXX_FLAGS=-ffile-prefix-map=$work/src/poca=poca -ffile-prefix-map=$work/poca-build=poca-build" > "$work/poca.build.log" 2>&1 \
  && cmake --build "$work/poca-build" --target poca -j >> "$work/poca.build.log" 2>&1 \
  || { echo "build.sh: Poca failed: $work/poca.build.log" >&2; exit 1; }
rm -f "$work/src/poca/vendor"

# --- stage -----------------------------------------------------------------------
echo "build.sh: stage $stage"
rm -rf "$stage"
mkdir -p "$stage"
put() { # put <name> <dir in the bundle>: the component's committed files
  mkdir -p "$stage/$2"
  git -C "$work/src/$1" archive "${commit[$1]}" | tar -x -C "$stage/$2"
}
put tezcatl_without_nix tezcatl
put xipe_totec_without_nix xipe_totec
put embody embody
put emacs-vent emacs-vent
for n in tezcatl_without_nix:tezcatl xipe_totec_without_nix:xipe_totec; do
  mkdir -p "$stage/${n#*:}/_build/prod"
  cp -a "$work/src/${n%%:*}/_build/prod/rel" "$stage/${n#*:}/_build/prod/"
done
# Poca: what CEF needs beside the program (build/Release), the debug
# information left out (libcef.so is 1.4 GB with it)
mkdir -p "$stage/poca"
cp -a "$work/poca-build/Release/." "$stage/poca/"
git -C "$work/src/poca" archive "${commit[poca]}" LICENSE README.md | tar -x -C "$stage/poca"
# CEF's license and Chromium's credits (the third-party notices), from the CEF
# distribution Poca's CMakeLists.txt builds with (vendor/ may hold others)
cef="$POCA_VENDOR/$(grep -o 'vendor/cef_binary_[^"]*' "$work/src/poca/CMakeLists.txt" | head -1 | sed 's|^vendor/||')"
[ -f "$cef/LICENSE.txt" ] || { echo "build.sh: no CEF license at $cef" >&2; exit 1; }
cp "$cef/LICENSE.txt" "$stage/poca/LICENSE-CEF.txt"
cp "$cef/CREDITS.html" "$stage/poca/CREDITS-Chromium.html"
strip --strip-debug "$stage/poca/libcef.so" "$stage/poca/libvk_swiftshader.so" "$stage/poca/poca"
cp -a "$root/bundle/." "$stage/"
cp "$root/LICENSE" "$stage/LICENSE"

# --- licenses of what the releases carry -----------------------------------------
# Erlang/OTP's runtime and Elixir's standard library (Apache-2.0, with the
# licenses of the third-party code in them), from the tags of the versions built
# with, and each Hex package in a release, from the package itself.
echo "build.sh: licenses"
otp_version="$(erl -noshell -eval 'io:put_chars(string:trim(element(2, file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"]))))), halt().')"
elixir_version="$(elixir --short-version)"
fetch_licenses() { # fetch_licenses <repository> <tag> <dir in licenses/> <files...>
  local src="$work/licenses-src/$3"
  if [ ! -d "$src/.git" ]; then
    rm -rf "$src"
    git clone --quiet --depth 1 --filter=blob:none --no-checkout --branch "$2" "$1" "$src" \
      2> >(grep -v "is not a commit" >&2)   # an annotated tag, as OTP's are
    git -C "$src" sparse-checkout set --no-cone "${@:4}"
    git -C "$src" checkout --quiet
  fi
  mkdir -p "$stage/licenses/$3"
  (cd "$src" && cp -r "${@:4}" "$stage/licenses/$3/")
}
fetch_licenses https://github.com/erlang/otp.git "OTP-$otp_version" "erlang-otp-$otp_version" LICENSE.txt LICENSES
fetch_licenses https://github.com/elixir-lang/elixir.git "v$elixir_version" "elixir-$elixir_version" LICENSE LICENSES
hex_rows=""
for app in "$stage"/tezcatl/_build/prod/rel/*/lib/*/ "$stage"/xipe_totec/_build/prod/rel/*/lib/*/; do
  app="$(basename "$app")"            # <name>-<version>
  n="${app%-*}"
  for p in tezcatl_without_nix xipe_totec_without_nix; do
    meta="$work/src/$p/deps/$n/hex_metadata.config"
    [ -f "$meta" ] || continue
    [ -d "$stage/licenses/hex/$app" ] && break
    mkdir -p "$stage/licenses/hex/$app"
    find "$work/src/$p/deps/$n" -maxdepth 1 -type f \( -iname 'LICENSE*' -o -iname 'NOTICE*' -o -iname 'COPYING*' \) \
      -exec cp {} "$stage/licenses/hex/$app/" \;
    spdx="$(grep -o '{<<"licenses">>,\[[^]]*\]}' "$meta" | grep -o '<<"[^"]*">>' | sed -n '2,$p' | tr -d '<>"' | paste -sd, -)"
    # a package without a license file of its own: the standard text of its license,
    # from the license texts fetched above (Apache-2.0 is in Elixir's)
    if [ -z "$(ls "$stage/licenses/hex/$app")" ]; then
      for l in ${spdx//,/ }; do
        t="$(ls "$stage"/licenses/*/LICENSES/"$l.txt" 2>/dev/null | head -1)"
        if [ -n "$t" ]; then cp "$t" "$stage/licenses/hex/$app/LICENSE-$l.txt"; fi
      done
    fi
    files="$(ls "$stage/licenses/hex/$app" | paste -sd' ' -)"
    hex_rows+="| $app | $spdx | ${files:-(none: see its repository)} |"$'\n'
    break
  done
done
{
  echo "# Licenses of what the releases carry"
  echo
  echo "The releases in \`tezcatl/_build/prod/rel/\` and \`xipe_totec/_build/prod/rel/\` carry Erlang/OTP's runtime and"
  echo "libraries, Elixir's standard library, and the Hex packages below."
  echo
  echo "- Erlang/OTP $otp_version: Apache-2.0 — \`erlang-otp-$otp_version/LICENSE.txt\`; the licenses of the third-party code in"
  echo "  it are in \`erlang-otp-$otp_version/LICENSES/\`"
  echo "- Elixir $elixir_version: Apache-2.0 — \`elixir-$elixir_version/LICENSE\`, with \`elixir-$elixir_version/LICENSES/\`"
  echo
  echo "| Hex package | License | Files in \`hex/<package>/\` |"
  echo "|---|---|---|"
  printf '%s' "$hex_rows" | sort
} > "$stage/licenses/README.md"

{
  echo "tezcatlipoca $version"
  echo "built $(date -u +%Y-%m-%dT%H:%MZ) on $(uname -sm), $(ldd --version | head -1)"
  echo "Elixir $(elixir --short-version), Erlang/OTP $(erl -noshell -eval 'io:put_chars(erlang:system_info(otp_release)), halt().')"
  echo
  echo "# name  repository  commit"
  for n in "${order[@]}"; do echo "$n  ${url[$n]}  ${commit[$n]}"; done
} > "$stage/BUILD"

# --- no path of this machine's home in what is published -------------------------
if leaks="$(grep -rlaF "$HOME/" "$stage" | head -5)" && [ -n "$leaks" ]; then
  echo "build.sh: these hold $HOME's path (build in a TEZCATLIPOCA_WORK outside it):" >&2
  echo "$leaks" | sed "s|^|  |" >&2
  [ -n "${TEZCATLIPOCA_ALLOW_HOME:-}" ] || exit 1
fi

# --- tarball ---------------------------------------------------------------------
mkdir -p "$root/dist"
tar -C "$work/stage" -czf "$root/dist/$name.tar.gz" "tezcatlipoca-$version"
( cd "$root/dist" && sha256sum "$name.tar.gz" > "$name.tar.gz.sha256" )
echo "build.sh: $(du -h "$root/dist/$name.tar.gz" | cut -f1)  dist/$name.tar.gz"

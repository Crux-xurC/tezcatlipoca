#!/bin/sh
# (container/build.sh image runs this inside ubuntu:22.04)
# tezcatlipoca's build environment on Ubuntu 22.04 (glibc 2.35, OpenSSL 3.0): Erlang/OTP and
# Elixir as the releases before were built with, and the libraries libcef.so links against
set -eu
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  build-essential git curl ca-certificates unzip file xz-utils \
  autoconf m4 libssl-dev libncurses-dev libcap-dev cmake ninja-build binutils libx11-dev \
  libglib2.0-0 libnspr4 libnss3 libatk1.0-0 libatk-bridge2.0-0 libdbus-1-3 libcups2 libxcomposite1 libxdamage1 \
  libxext6 libxfixes3 libxrandr2 libgbm1 libxkbcommon0 libcairo2 libpango-1.0-0 libasound2 libatspi2.0-0
rm -rf /var/lib/apt/lists/*
OTP=29.1.1
curl -fsSL "https://github.com/erlang/otp/releases/download/OTP-$OTP/otp_src_$OTP.tar.gz" | tar xz -C /tmp
cd "/tmp/otp_src_$OTP"
./configure --prefix=/usr/local --without-javac --without-wx --without-odbc --without-debugger --without-observer --without-et
make -j"$(nproc)"
make install
cd /
rm -rf "/tmp/otp_src_$OTP"
ELIXIR=1.20.4
curl -fsSL -o /tmp/elixir.zip "https://github.com/elixir-lang/elixir/releases/download/v$ELIXIR/elixir-otp-29.zip"
mkdir -p /usr/local/elixir
unzip -q /tmp/elixir.zip -d /usr/local/elixir
rm /tmp/elixir.zip
export PATH=/usr/local/elixir/bin:$PATH
mix local.hex --force
mix local.rebar --force
echo SETUP-DONE

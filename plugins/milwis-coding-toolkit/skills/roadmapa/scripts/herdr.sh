#!/bin/bash
# Herdr terminals of the queue, through the `hc` CLI. Sourced by kolejka.sh and watcher.sh (needs $K and $SESJA).
# The lead and the watcher are two named Herdr terminals, "$SESJA-lider" and "$SESJA-watcher", which the owner
# sees in the Herdr app (a detached tmux session is invisible there, 2026-11-12). The watcher replaces the
# lead's terminal after every issue, so a name outlives a terminal: the current address (t17…) of each role is
# kept in $K/lider.adres and $K/watcher.adres, and every call goes by the address.
# POMIAR (2026-11-12, hc 0.1.20): `hc run` does not pass the caller's environment (an exported variable is empty
# inside; PATH comes from the Herdr core), so PATH and every KOLEJKA_* go in through `env`. `hc kill` sends SIGHUP
# (the watcher's trap runs); a finished terminal keeps its name until `hc rm`, and a live one may take the same name.
HC="${HC:-$(command -v hc || echo "$HOME/.local/bin/hc")}"

# hc_uruchom <rola> <cwd> <cmd...>   start a terminal "$SESJA-<rola>", write its address to $K/<rola>.adres
hc_uruchom() {
  local rola="$1" cwd="$2" v adres; shift 2
  local srodowisko=("PATH=$PATH")
  for v in $(compgen -e); do [[ "$v" == KOLEJKA_* ]] && srodowisko+=("$v=${!v}"); done
  # --no-parent: the terminal belongs to no one, so it neither dies with the shell that started it nor types notes
  # about itself into the watcher.
  adres=$("$HC" run --bg --json --no-parent --no-notify --name "$SESJA-$rola" --cwd "$cwd" --label "kolejka=$SESJA" \
    env "${srodowisko[@]}" "$@" 2>&1 | jq -r '.address // empty' 2>/dev/null)
  [ -n "$adres" ] || return 1
  echo "$adres" > "$K/$rola.adres"
}
hc_adres() { cat "$K/$1.adres" 2>/dev/null || true; }
# hc_stan <rola>   live | finished | brak (no terminal) | "" (hc did not answer)
hc_stan() {
  local a; a=$(hc_adres "$1")
  [ -n "$a" ] || { echo brak; return; }
  "$HC" get "$a" --json 2>&1 | jq -r 'if .state then .state elif .error.kind == "not_found" then "brak" else "" end' 2>/dev/null
}
# hc_wyslij <rola> <tekst>   paste and Enter. hc waits for an unfinished draft typed by a person (draft_wait) and
# refuses a program blocked on a dialog: a non-zero status means "not delivered". perl alarm = a timeout macOS has.
hc_wyslij() {
  local a; a=$(hc_adres "$1"); [ -n "$a" ] || return 1
  ( perl -e 'alarm shift; exec @ARGV' 120 "$HC" send "$a" "$2" >/dev/null 2>&1 )
}
# hc_wyjdz <rola>   type /exit key by key. Not `hc send`: a paste is text to Claude Code, not a command, and from inside
# a Herdr terminal hc wraps it in <hc from="t…"> besides. POMIAR (2026-11-12, hc 0.1.20, Claude Code in a Herdr
# terminal): `hc send t "/exit"` reached the model as a message and the process lived on; `hc keys t / e x i t`, then
# `enter` → finished, exit 0.
hc_wyjdz() {
  local a; a=$(hc_adres "$1"); [ -n "$a" ] || return 1
  "$HC" keys "$a" / e x i t >/dev/null 2>&1 || return 1
  sleep 1
  "$HC" keys "$a" enter >/dev/null 2>&1
}
# hc_zabij <rola>   end the terminal (if live) and remove it, so the name is free and no finished copies pile up.
hc_zabij() {
  local a; a=$(hc_adres "$1"); [ -n "$a" ] || return 0
  if [ "$(hc_stan "$1")" = live ]; then
    "$HC" kill "$a" >/dev/null 2>&1
    for _ in $(seq 20); do [ "$(hc_stan "$1")" = live ] || break; sleep 0.5; done
  fi
  "$HC" rm "$a" >/dev/null 2>&1
  rm -f "$K/$1.adres"
  return 0
}

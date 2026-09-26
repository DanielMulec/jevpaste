#!/bin/bash
# PROTOTYPE — menu-settings, never merged. Round-1 screenshots into /tmp/proto-shots (see PROTOTYPE-PLAN.md).
S=scripts/prototype-shots.sh; D=/tmp/proto-shots; mkdir -p $D
$S $D/menu-1.png PROTO_OPEN=menu PROTO_MENU=A
$S $D/menu-2.png PROTO_OPEN=menu PROTO_MENU=A PROTO_QUERY=ex
$S $D/menu-3.png PROTO_OPEN=menu PROTO_MENU=B
$S $D/menu-4.png PROTO_OPEN=menu PROTO_MENU=B PROTO_QUERY=ex
n=1
for r in 1 2 3; do for m in A B; do
  $S $D/rows-$n.png PROTO_OPEN=menu PROTO_MENU=$m PROTO_ROWS=$r PROTO_QUERY=ex; n=$((n+1))
done; done
n=1
for v in 1 2 3; do
  $S $D/settings-$n.png PROTO_OPEN=settings PROTO_SETTINGS=$v PROTO_SECTION=provider PROTO_TEST=1; n=$((n+1))
  $S $D/settings-$n.png PROTO_OPEN=settings PROTO_SETTINGS=$v PROTO_SECTION=key-typesafe PROTO_PROVIDER=typesafe; n=$((n+1))
  $S $D/settings-$n.png PROTO_OPEN=settings PROTO_SETTINGS=$v PROTO_SECTION=key-typesafe PROTO_PROVIDER=typesafe PROTO_TEST=1; n=$((n+1))
  $S $D/settings-$n.png PROTO_OPEN=settings PROTO_SETTINGS=$v PROTO_SECTION=full; n=$((n+1))
done

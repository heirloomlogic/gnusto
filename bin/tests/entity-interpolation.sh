#!/bin/sh
# After building Gnusto, pass its module directory (swiftbuild's --show-bin-path).
# This must import the emitted module: a same-module probe can hide overload bugs.
set -eu
modules=${1:?usage: entity-interpolation.sh <built-module-directory>}
probe=$(mktemp -d)
trap 'rm -rf "$probe"' EXIT HUP INT TERM
cat > "$probe/Entities.swift" <<'SWIFT'
import Gnusto

func prose(_ item: Item, _ actor: Actor, _ location: Location) -> String {
    "\(item) \(actor) \(location)"
}
SWIFT
swiftc -typecheck -I "$modules" "$probe/Entities.swift" 2> "$probe/warnings"
for message in 'use item.definiteName or item.indefiniteName' 'use actor.definiteName or actor.indefiniteName' 'use location.name'; do
    grep -q "warning:.*$message" "$probe/warnings"
done
if swiftc -typecheck -warnings-as-errors -I "$modules" "$probe/Entities.swift" 2> "$probe/errors"; then
    echo 'error: entity interpolation passed with warnings-as-errors' >&2
    exit 1
fi
for message in 'use item.definiteName or item.indefiniteName' 'use actor.definiteName or actor.indefiniteName' 'use location.name'; do
    grep -q "error:.*$message" "$probe/errors"
done
cat > "$probe/Names.swift" <<'SWIFT'
import Gnusto

func prose(_ item: Item, _ actor: Actor, _ location: Location) -> String {
    "\(item.definiteName) \(item.indefiniteName) \(actor.definiteName) \(actor.indefiniteName) \(location.name) \(42)"
}
SWIFT
swiftc -typecheck -warnings-as-errors -I "$modules" "$probe/Names.swift"
echo 'Entity interpolation: three consumer warnings, three strict errors, explicit names accepted.'

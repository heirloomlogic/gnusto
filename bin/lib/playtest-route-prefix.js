//
// The commands `bin/playtest-replay --start <route>` plays before the caller's own
// first line, printed for a shell to read.
//
// **Why a shell calls out to node for this.** `bin/playtest-replay` is bash, and a
// route is `.playtest/<Game>/routes/<name>.json`. A shell can be made to scrape that
// file, and the harness has been down that road: the machinery this replaced cut its
// deep starts by grepping a Swift test for an array literal, which parsed one of this
// repo's two walkthroughs and could not say so (#358). A route is checked by exactly
// one reader — `routePrefix` in `playtest-focus.js`, written to the rules the engine's
// `PlaytestRoute.load` applies at `open` — and a second parser in awk would be a
// second answer to the one question that matters, which is whether a tester and the
// verifier checking their finding started in the same place.
//
// It is a shim and not a front door: `bin/playtest-routes <Game> list` is what a
// person runs, and prints the same three facts in a table. This exists because bash
// cannot `require`.
//
//   node bin/lib/playtest-route-prefix.js <checkout> <Game> <route>
//
// Four header lines, then one command per line with the landing probe last:
//
//   1  the manifest's seed
//   2  how many commands follow
//   3  the room the manifest claims they land in — empty when it claims none
//   4  the wall clock they want, from `timeoutFor`, so the rule has one owner
//
// A refusal goes to stderr and exits 2, so the caller can pass the reason through
// rather than re-word it.

'use strict'

const path = require('node:path')

const { routePrefix, routesDir } = require('./playtest-focus')
const { timeoutFor } = require('./playtest-replay')

const [root, game, name] = process.argv.slice(2)
if (!root || !game || !name) {
  console.error('usage: playtest-route-prefix.js <checkout> <Game> <route>')
  process.exit(2)
}

const route = routePrefix(name, path.resolve(root, routesDir(game)))
if (route.error) {
  console.error(`playtest-replay: cannot start from "${name}" — ${route.error}`)
  process.exit(2)
}

process.stdout.write(
  `${route.seed}\n${route.commands.length}\n${route.landing}\n`
  + `${timeoutFor(route.commands.length)}\n${route.commands.join('\n')}\n`
)

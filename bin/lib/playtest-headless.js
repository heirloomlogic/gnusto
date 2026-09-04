'use strict'

const { spawnSync } = require('node:child_process')

// This is a local capability check, not a model invocation. Older clients must
// fail before a round spends time building or reaches an unanswerable prompt.
function checkHeadlessCLI(options) {
  const r = spawnSync('claude', ['--help'], { ...options, encoding: 'utf8', timeout: 10_000 })
  if (r.error) return `Cannot run claude: ${r.error.message}. Install Claude Code and put claude on PATH, then retry --headless.`
  const help = r.stdout || ''
  if (r.status !== 0 || !['--allowedTools', '--disallowedTools', '--permission-mode', 'dontAsk'].every((s) => help.includes(s))) {
    return 'Headless play-testing needs Claude Code with --allowedTools, --disallowedTools and --permission-mode dontAsk. Update claude, or dispatch Workflow from an interactive session.'
  }
  return null
}

function dispatchHeadless(args, options) {
  // Reads and the selected game's MCP calls drive the round. Only its probes,
  // reports and ledger need file writes; route persistence uses the routes shim.
  // Other shell commands retain the client's normal read-only classification.
  const reportPattern = `/${args.gameDocsDir ? args.gameDocsDir + '/' : ''}*-playtest-*.md`
  const allowed = [
    'Workflow', 'ToolSearch', 'Read', 'Glob', 'Grep', `mcp__${args.mcpServer}`,
    'Bash(bin/playtest-replay:*)', 'Bash(bin/playtest-routes:*)', 'Bash(bin/playtest-measure:*)',
    // The collator's transcript-counting pipelines and the verifier's source
    // history query are prescribed by playtest.js, including find -exec grep.
    'Bash(find .context/playtest:*)', 'Bash(grep:*)', 'Bash(wc:*)',
    'Bash(awk:*)', 'Bash(dirname:*)', 'Bash(git log:*)',
    ...['Write', 'Edit'].flatMap((tool) => [
      `${tool}(/.context/playtest/**)`, `${tool}(${reportPattern})`,
    ]),
  ]
  const prompt = 'Run the play-test round, and write the report it returns. '
    + 'This is an unattended, report-only round. Do not create GitHub issues; keep confirmed issue bodies in the report for review. '
    + 'If Workflow is unavailable, stop and report that this Claude Code session needs the Workflow tool. '
    + 'If a required tool is denied, stop and name the tool and required permission; do not report a completed round. '
    + `Workflow({scriptPath: ${JSON.stringify(args.workflowPath)}, args: ${JSON.stringify(args)}})`
  return spawnSync('claude', [
    '-p', prompt, '--permission-mode', 'dontAsk', '--allowedTools', ...allowed,
    '--disallowedTools', 'Bash(gh issue create:*)',
  ], { stdio: 'inherit', ...options })
}

module.exports = { checkHeadlessCLI, dispatchHeadless }

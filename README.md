# Chiron

![Chiron Banner](banner.png)

*The cave on Mount Pelion. Fire at the center. Patterns scratched into stone from a thousand previous sessions. Four alcoves. The climb is the filter.*

---

Chiron was the wisest of the centaurs, immortal teacher on Mount Pelion. Heroes climbed to his cave to learn. He didn't lecture — he watched them work, scored what they produced, and reshaped them through iteration. Not everyone who climbed made it down better than they arrived. The mountain didn't care about intentions. It cared about improvement.

This Chiron is the cave at the peak. Fire at the center illuminates patterns scratched into the walls — each one a lesson from a previous training session. Four alcoves marked A, B, C, D, each training a different lineage of the same agent. Stone tablets record scores 1-10. You watch them learn, preserve what works, reshape what doesn't, and repeat until what descends the mountain is actually capable. The patterns on the walls aren't decoration. They're the accumulated record.

Any agent type trains here — coding, research, customer service, analysis. The cave doesn't care what you're building. It cares whether you're improving.

Train AI agents through iterative evaluation loops. Define what you need, generate an agent, run it, score it, evolve it.

## How it works

Chiron generates system prompts for AI agents, runs them against your inputs, collects your evaluations, and uses the feedback to evolve better prompts. All state is stored locally in a single JSON file (`.chiron/state.json`).

![Chiron — How Agents Evolve](images/chiron_explained.png)

**Quickstart flow** (single lineage):
```
init -> run -> evaluate -> iterate -> run again
```

**Training flow** (four parallel lineages A/B/C/D):
```
init -> run all -> evaluate all -> lock winners -> iterate losers -> repeat
```

## Install

```bash
make build
# Binary at ./bin/chiron
```

Or directly:
```bash
go install .
```

## Quick Start

```bash
# Set your API key
export ANTHROPIC_API_KEY=sk-...

# Create a session and generate the first agent
chiron quickstart init --need "Customer support assistant that handles refund requests"

# Run the agent (use the session_id from output)
chiron run ses_XXXXXXXX --input "I want a refund for order #1234"

# Score the result (use the artifact_id from output)
chiron evaluate art_XXXXXXXX --score 5 --comment "Too generic, needs order lookup"

# Evolve the agent based on feedback
chiron iterate ses_XXXXXXXX

# Run the evolved agent
chiron run ses_XXXXXXXX --input "I want a refund for order #1234"
```

## Commands

| Command | Description |
|---------|-------------|
| `quickstart init --need "..."` | Create session with one `main` lineage and baseline agent |
| `training init --need "..."` | Create session with four lineages (A/B/C/D) |
| `session new` | Create empty session record |
| `session list` | List all sessions |
| `session inspect <session-id>` | Show full session JSON |
| `run <session-id> --input "..."` | Execute latest agent, store artifact |
| `evaluate <artifact-id> --score N` | Score artifact 1-10, optional `--comment` (immutable once set) |
| `iterate <session-id>` | Generate next agent version from evaluations |
| `training iterate <session-id>` | Iterate all unlocked training lineages |
| `promote <session-id>` | Convert quickstart to training (4 lineages) |
| `lineage lock <session-id> <name>` | Freeze a lineage (skip during training iterate) |
| `lineage unlock <session-id> <name>` | Unfreeze a lineage |
| `directive set <session-id> <lineage> --text "..." --sticky` | Add persistent directive injected into evolution |
| `directive set <session-id> <lineage> --text "..." --oneshot` | Add one-time directive (cleared after next iterate) |
| `directive clear <session-id> <lineage> <directive-id>` | Remove a directive |
| `artifact list <session-id>` | List artifacts with scores |
| `artifact inspect <artifact-id>` | Show full artifact JSON |
| `export agent <agent-id> --format json\|python\|typescript` | Export agent definition |
| `export evidence <session-id>` | Export session evidence pack (lineages, agents, artifacts, directives) |
| `doctor` | Check environment (API keys, executor binaries) |
| `version` | Print version |
| `completion bash\|zsh\|fish\|powershell` | Generate shell completion script |

All commands support `--json` for machine-readable output.

## Providers

**Anthropic** (default):
```bash
export ANTHROPIC_API_KEY=sk-...
chiron quickstart init --need "..."
```

**OpenAI-compatible** (OpenAI, OpenRouter, LiteLLM):
```bash
export OPENAI_API_KEY=sk-...
chiron quickstart init --need "..." --provider openai-compatible --model gpt-4o
```

**Claude CLI**:
```bash
chiron run ses_XXX --mode cli --executor claude --input "..."
```

Provider aliases accepted: `openai`, `openrouter`, `litellm` → `openai-compatible`; `claude`, `claude-code` → `claude-cli`.

Override per-command with `--provider`, `--model`, `--base-url`, `--api-key`.

**Environment variables:**

| Variable | Used by |
|----------|---------|
| `ANTHROPIC_API_KEY` | Anthropic provider |
| `OPENAI_API_KEY` | OpenAI-compatible provider |
| `OPENAI_COMPATIBLE_API_KEY` | OpenAI-compatible provider (alternative) |
| `API_KEY` | OpenAI-compatible provider (generic fallback) |

## Training workflow

```bash
# 1. Initialize with four variant strategies
chiron training init --need "Generate migration plans"

# 2. Run all lineages
for L in A B C D; do
  chiron run ses_XXX --lineage $L --input "Migrate users table"
done

# 3. Evaluate each artifact
chiron evaluate art_AAA --score 9 --comment "Best balance"
chiron evaluate art_BBB --score 6 --comment "Too conservative"
chiron evaluate art_CCC --score 7 --comment "Creative but uneven"
chiron evaluate art_DDD --score 5 --comment "Too risky"

# 4. Lock the winner, evolve the rest
chiron lineage lock ses_XXX A
chiron training iterate ses_XXX
```

**Promote strategy:** convert a quickstart session to training with one of two variant families:
- `variations` (conservative/balanced/creative/aggressive) — default
- `alternatives` (rule-based/retrieval-first/planning-first/critique-revise)

```bash
chiron promote ses_XXX --strategy variations
```

## State

State lives at `.chiron/state.json` relative to your working directory. One directory per project keeps state isolated. Add `.chiron/` to your `.gitignore`.

If upgrading from a previous version, the tool automatically migrates `.ludus-magnus/` to `.chiron/` on first run.

## Development

```bash
make test              # Unit tests
make test-integration  # Integration tests (builds binary, uses mock server)
make clean             # Remove build artifacts
```

## Part of Polis

Chiron trains what the city will judge. [Cerberus](https://github.com/Perttulands/gate) guards the gate. [Aletheia](https://github.com/Perttulands/truthsayer) demands the code be true. [Horkos](https://github.com/Perttulands/oathkeeper) watches the promises. [Hermes](https://github.com/Perttulands/relay) carries the messages. Chiron teaches agents until they're ready to descend the mountain and pass through the gate.

## License

MIT

# AGENTS.md

**Beeleex** — Elixir/Phoenix client library for the **Beelee** billing &
invoicing platform. It provides outbound API calls, inbound signed webhooks, and
a token-verification endpoint for integrating a host Phoenix app ("Business
Unit") with Beelee.

This file is the table of contents for the project documentation under
[`docs/`](docs/). Start with the Overview, then jump to the area you need.

## Documentation index

| Doc | What's inside |
|-----|---------------|
| [docs/overview.md](docs/overview.md) | Purpose, tech stack, how the three integration surfaces fit together. |
| [docs/architecture.md](docs/architecture.md) | Directory layout, supervision tree, module responsibilities, data conventions. |
| [docs/configuration.md](docs/configuration.md) | Installation, mounting routes/plug, and all config keys. |
| [docs/api-reference.md](docs/api-reference.md) | `Beeleex.Api` outbound GraphQL functions (invoices, companies, credit notes). |
| [docs/webhooks-and-events.md](docs/webhooks-and-events.md) | `Beeleex.WebhookPlug`, signature verification, handler contract, event types. |
| [docs/token-verification.md](docs/token-verification.md) | `POST /verify_token` flow, verifier callback contract, responses. |
| [docs/core-resources.md](docs/core-resources.md) | Domain structs (Company, Invoice, CreditNote, PaymentMethod, …). |

## Quick reference

| Topic | Where |
|-------|-------|
| Required config keys | [configuration.md](docs/configuration.md) |
| Add the webhook plug | [webhooks-and-events.md](docs/webhooks-and-events.md) |
| Mount routes | [configuration.md](docs/configuration.md) / [token-verification.md](docs/token-verification.md) |
| Outbound calls | [api-reference.md](docs/api-reference.md) |
| Struct field lists | [core-resources.md](docs/core-resources.md) |

## Conventions for agents

- **Source of truth:** module `@moduledoc`/`@doc`/`@spec` annotations in `lib/`.
  When code and docs disagree, trust the code and update the relevant `docs/` page.
- **Money:** amounts are integers paired with a `decimal_places` field.
- **Keys:** Beelee responses are atomized + underscored
  (`ExGeeks.Helpers.atomize_keys`); some input structs intentionally keep
  camelCase keys to match the GraphQL schema.
- **Secrets:** `business_unit_secure_key` is both the webhook signing secret and
  the API `secure-key` header — load it from env in production.

## Verification for code changes

- After making any code change, run `mix q` before reporting completion to make
  sure the project is still good.

## context-mode — MANDATORY routing rules

You have context-mode MCP tools available. These rules are NOT optional — they
protect your context window from flooding. A single unrouted command can dump 56
KB into context and waste the entire session.

### BLOCKED commands — do NOT attempt these

#### curl / wget — BLOCKED

Any Bash command containing `curl` or `wget` is intercepted and replaced with an
error message. Do NOT retry.

Instead use:
- `ctx_fetch_and_index(url, source)` to fetch and index web pages
- `ctx_execute(language: "javascript", code: "const r = await fetch(...)")` to
  run HTTP calls in sandbox

#### Inline HTTP — BLOCKED

Any Bash command containing `fetch('http`, `requests.get(`, `requests.post(`,
`http.get(`, or `http.request(` is intercepted and replaced with an error
message. Do NOT retry with Bash.

Instead use:
- `ctx_execute(language, code)` to run HTTP calls in sandbox — only stdout enters
  context

#### WebFetch — BLOCKED

WebFetch calls are denied entirely. The URL is extracted and you are told to use
`ctx_fetch_and_index` instead.

Instead use:
- `ctx_fetch_and_index(url, source)` then `ctx_search(queries)` to query the
  indexed content

### REDIRECTED tools — use sandbox equivalents

#### Bash (>20 lines output)

Bash is ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`,
`pip install`, and other short-output commands.

For everything else, use:
- `ctx_batch_execute(commands, queries)` — run multiple commands + search in ONE
  call
- `ctx_execute(language: "shell", code: "...")` — run in sandbox, only stdout
  enters context

#### Read (for analysis)

If you are reading a file to **Edit** it → Read is correct.

If you are reading to **analyze, explore, or summarize** → use
`ctx_execute_file(path, language, code)` instead. Only your printed summary
enters context. The raw file content stays in the sandbox.

#### Grep (large results)

Grep results can flood context. Use `ctx_execute(language: "shell", code:
"grep ...")` to run searches in sandbox. Only your printed summary enters
context.

### Tool selection hierarchy

1. **GATHER**: `ctx_batch_execute(commands, queries)` — Primary tool. Runs all
   commands, auto-indexes output, returns search results. ONE call replaces 30+
   individual calls.
2. **FOLLOW-UP**: `ctx_search(queries: ["q1", "q2", ...])` — Query indexed
   content. Pass ALL questions as array in ONE call.
3. **PROCESSING**: `ctx_execute(language, code)` |
   `ctx_execute_file(path, language, code)` — Sandbox execution. Only stdout
   enters context.
4. **WEB**: `ctx_fetch_and_index(url, source)` then `ctx_search(queries)` —
   Fetch, chunk, index, query. Raw HTML never enters context.
5. **INDEX**: `ctx_index(content, source)` — Store content in FTS5 knowledge base
   for later search.

### Subagent routing

When spawning subagents (Agent/Task tool), the routing block is automatically
injected into their prompt. Bash-type subagents are upgraded to general-purpose
so they have access to MCP tools. You do NOT need to manually instruct subagents
about context-mode.

### Output constraints

- Keep responses under 500 words.
- Write artifacts (code, configs, PRDs) to FILES — never return them as inline
  text. Return only: file path + 1-line description.
- When indexing content, use descriptive source labels so others can
  `ctx_search(source: "label")` later.

### ctx commands

| Command | Action |
|---------|--------|
| `ctx stats` | Call the `ctx_stats` MCP tool and display the full output verbatim |
| `ctx doctor` | Call the `ctx_doctor` MCP tool, run the returned shell command, display as checklist |
| `ctx upgrade` | Call the `ctx_upgrade` MCP tool, run the returned shell command, display as checklist |

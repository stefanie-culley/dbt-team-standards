# Team dbt standards: package + medallion example on Databricks

Context file for a new Claude Code session in VS Code. Read it fully, restate the plan
in a few lines, and propose a small task list before building anything.

## Goal

1. Learn for the dbt Analytics Engineering certification by building real things.
2. Give my team a dbt example they can copy to standardize how we do data work.

Three deliverables, in this order (C is described after B below):

- **A. Medallion example project on Databricks** (do this first): bronze -> silver -> gold,
  built with dbt, driven by metadata where possible.
- **B. Team standards package** (a dbt package installed through `packages.yml`):
  reusable macros, generic tests and config defaults, extracted from A.

- **C. Agents and skills**: team-standards checks as CLI commands plus a skill the agent
  follows, and patterns for using agents with dbt and Databricks. An MCP server is an
  optional later layer, added only if a real need shows up (see C2b).

All three live in one public repo, `dbt-team-standards`: the package in
`dbt_team_standards/`, the example in `examples/marketing_medallion/`. Work is tracked
as GitHub Issues, merged by pull request, and checked by GitHub Actions.

A package cannot force rules on projects that install it. Layout, linting and style
are enforced by the template project, CI checks and review, so A doubles as the template.

## How to work with me

- Keep every message short. One small step at a time.
- For terminal steps give a short command block and ask me for the output.
- Explain dbt and Spark concepts in plain English; I know SQL Server/Oracle, and I need to
  understand every dbt object well enough to explain it in an interview.
- Prefer metadata-driven generation over hand-written dbt objects. Generated files are
  committed, start with a `GENERATED - do not edit` header, and a drift check fails CI
  when they are stale.
- Never ask me to paste secrets. Secrets live only in `.env` (git-ignored). Never print,
  log or commit tokens or real data.
- I am on Windows with PowerShell and VS Code. Use `uv` for Python.
- Small commits, tests alongside code, no floats for money (use decimal).
- Verify claims about external tools and APIs against a real response or the docs
  before encoding them. Say what is unverified.

## Existing work (patterns only)

This project does NOT build on Hearth Index or Dollar Vault and shares no domain content
or data with them. They are only references for patterns I already proved, and nothing
is to be copied in wholesale. My project `hearth_index` (`C:\repos\hearth_index`, GitHub
`mtypeworkroom/hearth-index`) has a working version of this pattern on Databricks Free Edition:

- `metadata/sources/*.yml` -> pydantic validation (`hearth/metadata.py`) ->
  `hearth generate` writes `models/staging/_sources.yml`, `_staging.yml` and
  `stg_<source>.sql`. `generate --check` and pytest catch drift.
- `hearth/loader.py` lands CSVs into a bronze Delta table (append-only, `_file_sha256`,
  `_loaded_at`, `_source_file`, `bronze._load_log` for idempotency).
- `dbt build` passes (7/7) against Databricks. dbt core 1.11, dbt-databricks 1.13,
  dbt_utils 1.4.1, Python 3.12 (3.14 breaks dbt).

Also `C:\repos\budget_app` (Dollar Vault) has useful macros: `dv_hash`, `money`,
`normalize_merchant`, `stg_finish`. Treat both as sources of ideas to extract, not
as code to edit.

## A. Medallion example on Databricks

### Layers, and how each maps to dbt

| Layer | Meaning | dbt object | Schema | Materialization |
|---|---|---|---|---|
| Bronze | Raw as landed, all text, append-only, full history | `source()` (not a model) | `bronze` | Delta table made by the loader |
| Silver | Cleaned, typed, deduplicated, conformed | `stg_*` and `int_*` models | `silver` | view for staging, table for heavy intermediates |
| Gold | Business-ready marts, facts and dimensions | `dim_*`, `fct_*`, `mart_*` | `gold` | table (incremental later) |

Rules:

- Staging is 1:1 with a source: rename, cast, trim, null handling, no joins.
- Only staging reads `source()`. Everything else uses `ref()`.
- Import CTEs first, a final `renamed` or `final`-style CTE that lists columns explicitly.
- Tests at every layer: staging (not_null, accepted ranges, patterns), gold (unique keys,
  relationships, row-count sanity).
- Document every model and column in YAML; generate it where it can be derived.

### Sample data: synthetic marketing data

We are a marketing company, so the example uses a synthetic marketing data set that we
generate ourselves. No real client or customer data is ever used, and the generator
must not be seeded from real records. Generated values are obviously fake (invented
brands, `example.com` emails, fake names).

Requirements for the generator (`synthetic/`, Python, deterministic via a fixed seed,
so the same seed always produces the same files):

- Writes CSV files (one folder per source, dated like a real daily drop) that the loader
  lands into bronze exactly as a real vendor export would arrive: all text, vendor-style
  column names, mixed casing, and extra columns.
- Realistic mess on purpose, so the dbt tests have something to catch:
  duplicate rows on re-delivery, late-arriving days, null or inconsistent UTM values,
  campaign names that differ by case or spacing, mixed timezones, mixed currencies,
  and a few invalid values (negative spend, clicks greater than impressions).
- A small "bad file" mode for demonstrating failing tests and freshness alerts.

Candidate sources (propose the final list and columns to me before building):

| Source | Grain | Notes |
|---|---|---|
| `ads_google_daily` | campaign x ad group x day | spend, impressions, clicks, conversions |
| `ads_meta_daily` | campaign x ad set x day | same measures, different column names |
| `web_sessions` | session | utm_source/medium/campaign, landing page, device |
| `crm_contacts` and `crm_leads` | contact, lead | status changes over time, source |
| `email_events` | send/open/click event | campaign id, contact id, event type, timestamp |
| `orders` | order | contact id, amount, currency, order date |

Gold targets: `dim_date`, `dim_channel`, `dim_campaign`, `dim_contact`,
`fct_ad_spend_daily`, `fct_leads`, `fct_orders`, and `mart_channel_performance`
(CTR, CPC, CPA, ROAS, by channel and by month with a month-over-month trend).
A stretch goal is first-touch versus last-touch attribution built from `web_sessions`.

Different ad platforms report the same ideas under different names, so this data shows
off why staging models and shared macros exist: both ad sources are standardized in
silver to one shape, and gold unions them. That is the strongest case for the package.

### Target layout

```
dbt-team-standards/               # repo root
  CLAUDE.md, README.md, summary.md
  .github/workflows/ci.yml        # generate --check, pytest, ruff, dbt parse
  .github/ISSUE_TEMPLATE/, pull_request_template.md
  dbt_team_standards/             # the package (part B)
examples/marketing_medallion/     # the example project (paths below are relative to it)
  pyproject.toml, .python-version (3.12), .env.example, .gitignore
  metadata/sources/*.yml          # source of truth
  synthetic/ (python)             # seeded synthetic marketing data generator -> CSVs
  generator/ (python)             # validate + generate dbt files + drift check
  loader/ (python)                # land files into bronze
  models/
    staging/   (silver)  _sources.yml _staging.yml stg_*.sql   # GENERATED
    intermediate/        int_*.sql
    marts/     (gold)    dim_*.sql fct_*.sql _marts.yml
  tests/                          # pytest for generator and loader
  .claude/skills/team-standards/  # SKILL.md: how the agent uses the CLI checks (part C)
  mcp_server/ (python, OPTIONAL)  # only if C2b is justified
  .mcp.json (OPTIONAL)            # connects Claude Code to the MCP server
  docs/standards.md               # naming, layers, test rules, PR checklist
  docs/agents.md                  # how to connect the agent, tools, safety rules
```

### Build order (one phase at a time, ask me before each)

1. Scaffold repo, uv env, `dbt debug` green, `.env.example`.
2. Agree the synthetic marketing schema with me, then build the seeded generator for one
   source (`ads_google_daily`) with tests that the output is deterministic.
3. Metadata model + validator for that source; generate bronze source + staging model.
4. Loader to bronze; `dbt build` green. Then add the remaining sources one at a time.
5. Silver intermediates and tests (standardize the two ad platforms to one shape).
6. Gold dim/fact with relationship and uniqueness tests, plus the channel-performance mart.
7. Docs (`dbt docs generate`), source freshness, CI workflow.
8. `docs/standards.md` written from what we actually did.

## B. Team standards package (after A works)

Extract into the `dbt_team_standards/` folder of this repo. The example installs it
with a local path:

```yaml
packages:
  - local: ../../dbt_team_standards
```

Other teams install it by Git tag (`subdirectory` is unverified; check the dbt docs):

```yaml
packages:
  - git: "https://github.com/stefanie-culley/dbt-team-standards.git"
    revision: v0.1.0              # pin to a git tag
    subdirectory: dbt_team_standards
```

Candidate contents (only extract what A actually needed):

- Generic tests: `sums_to_one`, `valid_pattern`, `not_null_when`.
- Cleaning macros: trim/nullif/cast helper, hash key, audit columns.
- Config defaults (materializations per layer) via `dbt_project.yml`.
- `adapter.dispatch` macros so they can work on other warehouses.
- `integration_tests/` project that runs the macros on seed data.
- Versioning with git tags and a CHANGELOG.

## C. Agents and skills (after A works; can overlap with B)

Goal: let an AI agent in VS Code work with the team's standards and the dbt project,
safely. Principle: the agent can already run terminal commands, so build the checks as
plain CLI commands and teach the agent how to use them with a skill. Add MCP only when a
CLI plus skill is not enough. As the agent tools get better, less glue is needed, so
keep this layer thin and avoid building infrastructure that the tools will make obsolete.

Difference to keep straight: a **skill** is instructions the agent loads when relevant
(know-how, in a `SKILL.md`); an **MCP server** is a running program that exposes callable
tools and live data (hands). A local MCP server is not a network service: it is a script
the editor starts and talks to on the same computer.

### C1. Existing servers (optional, check availability first)

- **dbt MCP server** (official, `dbt-labs/dbt-mcp`, self-hosted). Runs `dbt build`, `test`,
  `compile`, `show` against a local dbt Core project and reads project metadata. Some
  metadata tools (Discovery API, Semantic Layer) depend on the dbt plan. Do not assume
  they work without a dbt platform account; test which tools are available.
- **Databricks managed MCP servers** (Databricks SQL, Genie, Unity Catalog functions).
  A workspace admin must enable them. NOT confirmed to be available on Databricks Free
  Edition: check under Agents/AI Gateway in the workspace before relying on it. If they
  are unavailable, skip them and note that in the docs.
- Security: giving an agent dbt commands can change models and warehouse objects. Use only
  the dev schema, a low-privilege token, and trusted clients.

### C2. CLI commands + a team-standards skill (the main deliverable)

- Build the checks as commands in the project's CLI (same style as `hearth validate` and
  `hearth generate --check`), each with tests, plain-English output, and a non-zero exit
  code on failure so CI can use them too.
- Write a skill (`.claude/skills/team-standards/SKILL.md`, committed in the repo so
  cloning gives everyone the same one) that tells the agent when and how to use the
  commands, and holds the team rules (from `docs/standards.md`): "to review a model, run
  these commands, then explain each finding using these rules."
- Rules live in one place (`docs/standards.md` plus the metadata). The skill points to
  them instead of repeating them.

Read-only commands first (the same list would become MCP tools in C2b):

| Command | What it does |
|---|---|
| `list_sources` | lists what is defined in `metadata/sources/` |
| `validate_metadata(source_id)` | runs the pydantic checks and returns plain-English errors |
| `check_drift()` | says whether the generated dbt files match the metadata |
| `get_standards(topic)` | returns the section of `standards.md` for naming, layers, testing, etc. |
| `review_model(path)` | checks a model against the rules (see below) |
| `explain_model(name)` | lineage, tests and columns in plain English (also good for cert study) |

`review_model` rules to start with: staging models read only `source()`; no joins in
staging; only staging reads `source()`; every model and column has a description; every
model has tests; marts use `ref()` only; CTE style (import CTEs, a final renamed CTE with
explicit columns); no `select *` in the last CTE.

Later commands, with guardrails (dev schema only, dry-run option, nothing destructive,
human approval for writes):

- `generate_source(source_id)` runs the generator.
- `run_dbt(select, target=dev)` runs `build` for selected models.
- `scaffold_source(...)` creates a new source's metadata file from a short questionnaire
  (name, grain, columns, owner) and validates it.

### C2b. Optional: expose the same checks as an MCP server

Only build this if at least one of these is true; otherwise skip it and say so in the docs:

- teammates use clients with no terminal (Claude Desktop, chat), so they cannot run commands;
- we need structured tool results instead of the agent reading terminal text;
- we need hard guardrails (only specific read-only actions allowed, not any shell command);
- we want shared hosted access (for example a Databricks app) without cloning the repo.

If built: a small Python MCP server (official `mcp` SDK, stdio transport) in `mcp_server/`
that wraps the existing CLI functions, connected through a committed `.mcp.json`. It must
add no new logic: every tool calls code that already exists and is tested. For the resume,
the story is "checks built as a CLI, then exposed as MCP tools".

### C3. Patterns to build and demo (my suggestions, not documented recipes)

1. **Build loop in VS Code.** The agent uses dbt MCP (or `run_dbt`) to build and test,
   reads failures, fixes the model, and reruns. I stay in control of every change.
2. **Standards reviewer.** The agent reviews a pull request against `standards.md` using
   `review_model` and `check_drift`, and posts findings. Also usable in CI.
3. **Source scaffolder.** The agent scaffolds a new source from a questionnaire, validates
   it, and runs `generate`.
4. **Explainer for new people.** The agent uses `explain_model` and lineage to answer
   "what does this model do and what depends on it?"
5. **Analyst agent on gold** (only if Databricks managed MCP or Genie is available).
   Ask business questions such as "ROAS by channel last month" against the gold marts.
   Do not point it at real client data.

### C4. Build order for this part

1. CLI commands `list-sources`, `validate`, `check-drift`, `standards <topic>`, each
   tested with pytest.
2. `review-model` with its rules, each rule tested on good and bad example models.
3. `explain-model`.
4. The `team-standards` skill that tells the agent how to use the commands; try it on a
   real task and tighten it where the agent goes wrong.
5. Write `docs/agents.md`: how to use the agent with the repo, what each command does,
   safety rules.
6. Decide on C2b with me, using the checklist there. Do not build the MCP server by default.
7. Only then consider the write commands, with guardrails.

Safety rules for every command (and tool, if C2b is built): no secrets in output, never
print `.env`, never touch production schemas, log what each call did, and keep read-only
commands separate from write commands.

## Platform facts (Databricks Free Edition)

- Catalog `workspace`; schemas `bronze`, `silver`, `gold` (dev schema suffixes as needed).
- Serverless 2X-Small SQL warehouse; it stops itself when idle.
- `.env` holds `DATABRICKS_HOST`, `DATABRICKS_HTTP_PATH`, `DATABRICKS_TOKEN`.
- Run dbt with `uv run --env-file .env dbt build --profiles-dir .`.

## Gotchas already hit

- dbt 1.10+: `meta`, `freshness`, `loaded_at_field` go under `config:`.
- Column-level `dbt_utils.expression_is_true` already prepends the column name, so write
  `rlike '...'`, not `zip rlike '...'`.
- Spark SQL string literals: regex backslashes are doubled (`'^\\d{5}$'`).
- CTEs need commas between them.
- After copying generator changes, run `generate --check` so a stale local copy is caught.

## Certification prep

Map each thing we build to the topics in the current dbt Analytics Engineering exam
outline (Jinja and macros, tests, materializations, `ref`/`source`, packages, docs,
deployment and CI). I have not checked the current outline: look it up on dbt's
certification page and keep a checklist in `docs/cert-map.md`.

## First message for the new session

"Read summary.md. Restate the plan, propose the synthetic marketing sources and columns
for my approval, and propose the task list for phase 1."

# Project instructions

Read `summary.md` before starting project work. It is the detailed project brief; use
this file for the repository layout and working agreement.

## Repository layout

This is one public repository holding two dbt projects. It is a portfolio piece and is
also shared with a working team, so keep it clean and presentable.

```
dbt-team-standards/
  dbt_team_standards/              # the reusable dbt package (own dbt_project.yml)
    integration_tests/             # tests the package's macros on seed data
  examples/marketing_medallion/    # the example medallion project (own dbt_project.yml)
  .github/                         # Actions workflows, issue and PR templates
```

- The example installs the package with a local path: `local: ../../dbt_team_standards`.
- Other teams install it by Git tag with `subdirectory: dbt_team_standards`
  (unverified: confirm `subdirectory` against current dbt docs before documenting it).
- Keep the example's models, synthetic data, loader and generator under
  `examples/marketing_medallion/`, never inside the package folder.
- Build the example first; extract only standards it actually needs into the package.
  Backends for the example are dbt targets, not separate projects.

## GitHub workflow

- Tickets are GitHub Issues. Every phase or task gets an issue before work starts.
- One branch per issue (`<issue-number>-short-name`), merged by pull request that says
  `Closes #<n>`. No direct commits to `main` once CI exists.
- CI runs in GitHub Actions and must pass before merge.
- Creating issues, pushing, and opening PRs are visible to others: confirm with the user
  first.

## Working agreement

- Work in small, approved phases. Before building anything in a new phase, describe
  the proposed work and wait for approval.
- Explain dbt and Spark concepts in plain English. Keep responses concise and proceed
  one small step at a time.
- Use synthetic marketing data only. Never use real customer data or expose secrets;
  keep credentials in ignored `.env` files. The repo is public: never commit workspace
  hosts, HTTP paths, tokens or other environment details.
- Prefer metadata-driven generation where it helps, commit generated outputs with a
  `GENERATED - do not edit` header, and test for drift.
- Use Windows, PowerShell, VS Code, and `uv` for Python workflows. Use decimal types
  for money, not floating-point types.
- Verify external tool and API behavior against current documentation or a real
  response; clearly identify anything that remains unverified.

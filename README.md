# zaniebot-sync

GitHub Actions workflow to periodically sync a list of fork repositories with their upstream parents.

## What it does

- runs every 15 minutes
- can also be triggered manually with `workflow_dispatch`
- reads fork targets from `targets.txt`
- syncs each fork's default branch from its upstream parent with the GitHub API

The initial target list contains:

- `zaniebot/uv`

## Required secret

Add a repository secret named `FORK_SYNC_TOKEN`.

A classic personal access token needs `repo` scope. It also needs `workflow`
scope when an upstream update can create or modify files in `.github/workflows`.
If you use a fine-grained token, it needs write access to each fork repository
you want to sync and write access to workflows.

## Targets

Edit `targets.txt` to add one `owner/repo` per line:

```text
zaniebot/uv
owner/another-fork
```

Blank lines and lines starting with `#` are ignored.

## Workflow file

- `.github/workflows/sync-forks.yml`

## Sync script

- `scripts/sync-forks.sh`

## Local setup

```bash
git init -b main
chmod +x scripts/sync-forks.sh
```

If you create the GitHub repository after that, add the remote and push normally.

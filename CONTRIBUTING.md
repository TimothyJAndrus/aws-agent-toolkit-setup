# Contributing

Thanks for your interest in improving this guide! Contributions that fix errors,
add clarity, or keep the content current with AWS changes are welcome.

## Ways to Contribute

- **Fix inaccuracies** — CLI flags, command syntax, or service behavior that has changed
- **Improve clarity** — reword confusing steps or add missing context
- **Add known issues** — document edge cases or workarounds you've discovered
- **Extend coverage** — additional OS platforms (Linux, Windows), shell types, or agent integrations

## Process

1. **Open an issue first** for anything beyond a small typo fix. Describe what is
   wrong or missing and why the change improves the guide. This avoids duplicate
   effort and lets us align on approach before you write.

2. **Fork and branch** off `main`:
   ```bash
   git checkout -b fix/describe-your-change
   ```

3. **Make your changes** to the relevant file(s). Keep each PR focused on a single
   concern — separate a content fix from a structural reorganization.

4. **Test commands you add or modify.** If a step involves a CLI command, verify it
   runs successfully before submitting.

5. **Submit a pull request** against `main` with:
   - A clear title summarising the change
   - A short description of what was wrong/missing and how you fixed it
   - Any relevant AWS documentation links if you're updating service behaviour

## Style Guidelines

- Use plain, direct language — assume the reader is a developer, not a beginner
- Prefer real, runnable commands over pseudocode
- Wrap lines at ~100 characters in Markdown source
- Use fenced code blocks with a language identifier (` ```bash `, ` ```json `, etc.)
- Keep tables concise; if a table grows beyond 5–6 rows, consider a list instead

## What Will Not Be Merged

- Changes that add AWS access keys, secrets, or any credentials to tracked files
- Content that applies only to a single organisation's internal setup
- Large structural rewrites without prior discussion in an issue

## Questions

Open a [GitHub issue](../../issues) with the `question` label.

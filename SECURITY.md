# Security model

The Flutter client is intentionally treated as an untrusted client. It must never contain provider keys, GitHub tokens, passwords, cookies, or private credentials.

## Local setup

Run `python services/agent_api/scripts/setup_secrets.py` on the developer machine. It uses hidden input and writes `~/.config/mdk-tech-ai-agent/secrets.env` with owner-only permissions.

The agent model receives credential references such as `GITHUB_TOKEN`, not their values. Provider adapters inject secrets only into outbound server-side requests and never return them to the model or Flutter client.

## Non-negotiable rules

- Never paste secrets into chat, prompts, issues, commits, or source code.
- Never log environment variables or dump `.env` files.
- Never expose secrets through a Flutter build; mobile/desktop bundles can be inspected.
- Use short-lived, least-privilege tokens.
- Keep browser sessions isolated and never export cookies.
- Do not bypass CAPTCHAs, 2FA, provider quotas, or rate limits.
- Require approval before destructive actions or external publishing.

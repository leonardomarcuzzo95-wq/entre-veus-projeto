# Upgrade invariants

- Keep the original laboratory and its database intact. Upgrades run from pinned source/binary pairs against `entreveus_1525`.
- A custom datapack must carry every required schema migration between the recorded database version and the pinned engine schema. Before allowing login, verify required schema columns in `Start-Upgrade.ps1`; an online socket is not sufficient evidence of a working upgrade.
- Verify real client login, logout/reconnect and persisted position after schema changes. Keep QA account state separate from Viajante.
- Never print or copy administrative credentials into project reports. SQL backups stay in the private AppData runtime.

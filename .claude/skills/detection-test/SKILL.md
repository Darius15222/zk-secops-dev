---
name: detection-test
description: Test a change to a Logstash pipeline, Suricata rule or Sigma rule in zk-detections, from unit samples up to a real alert in Elastic Security. Use when adding or editing anything under repos/zk-detections, or when a detection "does not fire".
---

# Detection test

Three levels; stop at the first that fails and fix there.

1. **Unit** (`repos/zk-detections`): `! python3 -I tests/test_suricata.py -v` (it runs Logstash and Suricata in docker, which the sandbox cannot reach; CI runs it too). A new pipeline field needs a sample in `tests/samples/` and an assertion. A new Suricata rule is validated by `suricata -T` in the same run.
2. **Conversion**: `rules/build.sh`, then read the generated ES|QL in `rules/elastic/sigma-rules.ndjson`. Check the `from` index (`rules/sigma-pipeline.yml` routes each logsource) and that the field names exist in the data stream.
3. **End to end** (local stack up): the user runs these from the lab clone after the change is merged (CLAUDE.md, Sandbox):
   - `! make -C repos/zk-platform detections` loads the rules (it reads the sibling zk-detections checkout);
   - `! make -C repos/zk-platform attack` replays the attack and waits for one alert per rule. CI e2e runs the same on every zk-platform PR.

## When a rule does not fire

- Field present? The user checks one event in Kibana Discover (zk-auth: `logs-zkauth-default`, Suricata: `logs-suricata-default`); the triage export (`alert-triage`) also shows `event.reason` counts per source.
- Time window: rules run every minute over `now-5m`; an attack older than that will not alert.
- Correlation rules count per `source.ip`; inside k3d all zk-auth traffic comes from `10.42.0.1`.

## Rules

- `rules/elastic/` is generated; never edit it by hand.
- Field names follow ECS; change zk-auth log fields and the rules in the same change (see zk-auth `AGENTS.md`).

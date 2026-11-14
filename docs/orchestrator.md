Rules: AGENTS.md. UI: docs/design.md.

# MASTER PROMPT 2: ORCHESTRATOR (multi-step jobs)

Use when a job has 3+ steps, spans several screens/files, or must survive a usage-limit cutoff.
Applies on top of AGENTS.md rules. Read docs/design.md first.

## O1. PROTOCOL
1. PLAN (read-only, no edits): list the steps. Each step = one screen/feature, a file list, and a gate. Steps must not share files.
2. Write the plan to docs/progress.md (format in O3). Commit nothing yet.
3. EXECUTE steps ONE AT A TIME, in order. Never two steps at once. A worker gets: the step text, the file list, the rules. Nothing else.
4. GATE after every step (O2). Green = checkpoint commit + tick the step in progress.md. Red = fix once, re-run the gate. Red twice = STOP and report. Don't continue past a red step.
5. VERIFY at the end: one read-only pass (status report template in docs/master_prompt.md section 7). It edits nothing. It reports mismatches against docs/design.md and the plan.
6. Parallel is allowed only for steps that create NEW files and share nothing (for example a test file + a tool script). Max 3 workers. 1 verifier. Short handoffs only.

## O2. GATE (run after each step, in this order)
```powershell
dart analyze                     # 0 errors, 0 warnings
dart run tool/design_lint.dart   # exit 0
# non-golden tests (TEMP fix from AGENTS.md), expect 0 failures
git add -A
git commit -m "<type>(<scope>): <step title> [step N/M]"   # LOCAL checkpoint only
```
Skip secrets/build artifacts (AGENTS.md HiveTube agent rules, rule 12). No push, no amend.
Checkpoint commits are the safety net: if the run is cut off (usage limit, crash), nothing finished is lost.

## O3. docs/progress.md FORMAT
```md
# PROGRESS
Job: <one line>
Started: <date>
## Steps
- [ ] 1. <title> | files: <list> | gate: <extra check or none>
- [ ] 2. ...
## Log
- <date> step 1 DONE commit=<hash> analyze=ok lint=0 tests=<n pass>
- <date> step 2 BLOCKED <file:line error>
## Decisions needed
- <one line each, or none>
```
Update after every step. It is the single source of truth for resume.

## O4. ORCHESTRATOR PROMPT (copy, fill the <>)
```
Task: <job in one line>. Run as ORCHESTRATOR. Read AGENTS.md, docs/orchestrator.md (O1-O3), and docs/design.md first.

1. PLAN: break the job into <N or "as many as needed"> steps. No shared files between steps. Write docs/progress.md. Print nothing else.
2. For each step, in order: do the work, run the gate (O2), checkpoint commit, tick the step.
3. Red gate: fix once, re-run. Red twice: stop, write the blocker into progress.md, and end.
4. A decision that needs me (schema change, new dependency, removed feature): add it under "Decisions needed", skip that step, continue with the next independent step.
5. After the last step: run the verify pass (read-only status report) and add its result to progress.md.
6. No push, no tag, no amend. No screenshots, no emulator, no golden tests.

Final reply = ONE line:
ORCH | steps done=<n/N> | blocked=<none or step N: reason> | commits=<hashes> | decisions needed=<none or list> | analyze=<ok/errors> | lint=<0/n> | tests=<pass/fail>
```

## O5. RESUME PROMPT (after a limit cutoff or crash)
```
Task: RESUME the orchestrated job. Read docs/progress.md. Run `git log --oneline -10` and `git status --short`.
1. If the tree is dirty from an unfinished step: run the gate. Green = checkpoint commit it and tick the step. Red = fix once. Still red = stop and report.
2. Continue at the first unchecked step. Same protocol (O1-O2). Don't redo ticked steps.
3. Same final reply format as O4.
```

## O6. WORKER HANDOFF (what the orchestrator gives each step)
```
Step <N/M>: <title>
Files you may edit: <list>. Don't touch any other file.
Spec: docs/design.md section <x> (or the task text).
Gate: dart analyze, design_lint, non-golden tests. Report one line:
STEP <N> | files=<list> | analyze=<ok/errors> | lint=<0/n> | tests=<pass/fail> | blocker=<none/exact>
```

## O7. WHEN NOT TO ORCHESTRATE
- One-file bugfix, one test repair, a version bump: use the plain task templates (docs/master_prompt.md section 7). No progress.md.
- A job that needs a schema change: stop at the plan, ask me first.
- Anything touching playback logic: one step, no parallel, my approval on the plan.

## O8. EXAMPLES (job -> plan shape)
- "Add Downloads screen + settings entry + library row": step 1 data/queries (daos.dart read-only if no schema), step 2 screen, step 3 library + settings wiring, step 4 tests.
- "Restyle everything after a docs/design.md change": one step per screen in order Library, Settings, Search, Subscriptions, History, Playlist, Channel, Watch, Shorts, then shell, then lint sweep.
- "Fix a failing suite": step 1 list + classify failures (read-only), step 2 fix STALE, step 3 fix BUG/ENV/FLAKY.

---

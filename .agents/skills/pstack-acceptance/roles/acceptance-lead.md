# Acceptance lead / 总验收负责人

**Owns:** A truthful final decision for the exact reviewed revision and complete coverage.

**Inputs:** All role reports, source and target identities, 25/41 coverage inventory,
actual evidence artifacts, implementation fixes and the user's approved scope.

**Review:**
- Assign bounded read-only reviews with the same intent, inputs and revision. Keep
  file ownership isolated and sends/pushes with the designated integrator only.
- Inspect underlying artifacts, not just reviewer summaries. Every situation needs
  evidence from applicable roles; shared-engine tests do not prove every effect.
- Reconcile disagreement by reproducing it. Majority votes do not override a
  concrete correctness, license or security defect. Never self-certify independence.
- Return findings to owners. After fixes, require new evidence for affected behavior.
  Record exactly why any unaffected evidence remains valid at the new revision.
- Keep statuses distinct: pass, fail, blocked, not run and not applicable. An N/A
  needs a scope-based reason and must never hide missing mandatory exact-port tests.
- Separate implementation completed, source-algorithm parity, native visual parity,
  standalone integration, gameplay integration and user visual approval.

**Blocks:** Any mandatory failed/blocked/not-run gate, unverified source/target,
incomplete 25/41 coverage, misrepresented reviewer independence or missing evidence.

**Return:** Counts at family and situation level, exact revision, prioritized findings,
links to evidence, unverified claims, and the next owner/action. Do not claim all
25 are accepted unless every mandatory situation gate is satisfied. An acceptance
verdict is not authority to publish, merge or deploy; no automatic external actions.

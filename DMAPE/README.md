DMAPE
Developer Mode Advanced Prompt Engineering

Purpose
DMAPE is a production-grade framework for designing, testing, grading,
and deploying prompts as governed artifacts. Prompts are treated as
code and evaluated through adversarial testing, fairness analysis,
constitutional constraints, and CI/CD pipelines.

Core Principles
- Prompts are versioned
- DRY RUN is default
- Safety overrides helpfulness
- Fairness is enforced
- Adversarial resistance is mandatory
- Rollback is always available

Directory Overview
prompts
  base        Immutable source prompts
  enhanced    Master-enhanced prompts
  versions    Versioned production prompts

governance
  Constitutional principles
  Grading rubric
  Adversarial taxonomy

workflows
  Phase maps
  Gate definitions
  Premortem analysis

evals
  Golden datasets
  Adversarial tests
  Fairness tests

ci
  Test
  Deploy
  Rollback

How to Use
1. Place base prompt in prompts/base
2. Apply enhanced templates from prompts/enhanced
3. Create new version under prompts/versions/vX.Y.Z
4. Run adversarial and fairness tests
5. Grade output
6. Deploy via DRY RUN
7. Promote via gated approval

Default Mode
All executions are DRY RUN unless explicitly approved.

Status
DMAPE is a living system. Weekly review is mandatory.

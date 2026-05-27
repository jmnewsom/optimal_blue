# Deploy this workspace to Snowsight Workspaces (Git-backed)

One-time setup so the demo workspace lives **inside Snowsight** and
Cortex Code's right-side panel can `@`-mention every contract.

## Prerequisites

- Repo pushed to a Git provider. (This repo lives at
  `https://github.com/jmnewsom/optimal_blue`.)
- ACCOUNTADMIN (or a role with CREATE INTEGRATION; CREATE SECRET only
  needed for private repos).
- A Personal Access Token (PAT) is **only required if the repo is
  private**. For a public repo, skip the secret entirely.

## Step 1 - Create the API integration in Snowflake

### Public repo (no secret) - this repo today

```sql
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE API INTEGRATION ob_demo_git_api
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/jmnewsom')
    ALLOWED_AUTHENTICATION_SECRETS = ()
    ENABLED = TRUE;
```

### Private repo (PAT required) - reference

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE OPTIMAL_BLUE_DEMO;
USE SCHEMA   AI;

CREATE OR REPLACE SECRET ob_demo_git_token
    TYPE = password
    USERNAME = '<your-git-username>'
    PASSWORD = '<your-PAT>';

CREATE OR REPLACE API INTEGRATION ob_demo_git_api
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/<your-org>')
    ALLOWED_AUTHENTICATION_SECRETS = (ob_demo_git_token)
    ENABLED = TRUE;
```

## Step 2 - Create the Git repository object

`GIT REPOSITORY` is a schema-level object, so you must set an active
database + schema before `CREATE GIT REPOSITORY`. We'll house it in
`OPTIMAL_BLUE_DEMO.AI` (created by `infrastructure/00_setup_db_roles_wh.sql`).

### Public repo - no `GIT_CREDENTIALS`

```sql
USE ROLE OB_DEMO_ADMIN;
USE DATABASE OPTIMAL_BLUE_DEMO;
USE SCHEMA   AI;

CREATE OR REPLACE GIT REPOSITORY OB_DEMO_REPO
    API_INTEGRATION = ob_demo_git_api
    ORIGIN = 'https://github.com/jmnewsom/optimal_blue.git';

ALTER GIT REPOSITORY OB_DEMO_REPO FETCH;
LIST @OB_DEMO_REPO/branches/main/;
```

### Private repo - reference

```sql
USE ROLE ACCOUNTADMIN;       -- needs USAGE on the secret
USE DATABASE OPTIMAL_BLUE_DEMO;
USE SCHEMA   AI;

CREATE OR REPLACE GIT REPOSITORY OB_DEMO_REPO
    API_INTEGRATION = ob_demo_git_api
    GIT_CREDENTIALS = ob_demo_git_token
    ORIGIN = 'https://github.com/<your-org>/<repo>.git';
```

Grant the demo roles read access:

```sql
GRANT USAGE ON DATABASE OPTIMAL_BLUE_DEMO TO ROLE OB_DEMO_RW;
GRANT USAGE ON SCHEMA   OPTIMAL_BLUE_DEMO.AI TO ROLE OB_DEMO_RW;
GRANT READ  ON GIT REPOSITORY OB_DEMO_REPO TO ROLE OB_DEMO_RW;
GRANT READ  ON GIT REPOSITORY OB_DEMO_REPO TO ROLE OB_DEMO_ADMIN;
```

## Step 3 - Mount it as a Workspace in Snowsight

1. In Snowsight, navigate to **Projects -> Workspaces**.
2. Click **+ Workspace** -> **From Git repository**.
3. Pick `OB_DEMO_REPO` (or paste the URL + select the integration).
4. Branch: `main`. Workspace name: `optimalblue-demo`.
5. Snowsight clones the repo and mounts the file tree on the left rail.

## Step 4 - Verify

You should see (in run order):

```
optimalblue-demo
  RUN.md                                <- open this first
  docs/
    demo_runbook.md
    cortex_code_talktrack.md
    deploy_to_snowsight_workspaces.md
    reset_demo.sql
  infrastructure/
    prompt-contract.md
    00_setup_db_roles_wh.sql
    01_synthetic_comergence.sql
    02_synthetic_ppe.sql
    03_load_unstructured.sql
    README.md
  vignettes/
    01_tpo_risk_semantic_view/
      prompt-contract.md
      01_tpo_risk_semantic_view.sql     <- fallback
      sample_questions.md
    02_cortex_search_compliance/
      prompt-contract.md
      02_compliance_search_and_aisql.sql
      sample_queries.md
    03_counterparty_oversight_agent/
      prompt-contract.md
      03_counterparty_oversight_agent.sql
      demo_script.md
    04_cross_org_bridge/
      prompt-contract.md
      04_tpo_performance_views.sql
    05_solution_center_marketplace/
      prompt-contract.md
      05_tpo_scorecard_share.sql
      listing_manifest.yaml
    06_streamlit_dashboard/
      prompt-contract.md
      app.py
      requirements.txt
      06_streamlit_dashboard_deploy.sql
    07_snowflake_intelligence/
      prompt-contract.md
      07_tpo_performance_si_semantic_view.sql
      talk_track.md
```

Open the Cortex Code panel (right side). Type:

```
@infrastructure/prompt-contract.md
```

and confirm Cortex Code recognizes the master contract. You're ready.

## Refreshing during the demo

If you push commits during the day:

```sql
ALTER GIT REPOSITORY OB_DEMO_REPO FETCH;
```

Then in Snowsight click the refresh icon on the Workspaces tree.

## Troubleshooting

- **`401 Unauthorized` on FETCH** (private repo only): PAT expired or missing `repo` scope.
- **Public repo: no auth needed**: the `git_https_api` provider performs anonymous `git clone` against public GitHub. If you ever flip the repo to private, redo Step 1 with the secret form.
- **`ALLOWED_AUTHENTICATION_SECRETS`**: must list the secret by name *before* the Git repo can use it (private repos only).
- **Repo not appearing in Workspaces UI**: ensure your Snowsight role has `READ` on the Git repository object.

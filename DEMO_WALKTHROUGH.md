# DCM Projects Demo Walkthrough
## E-Commerce Pipeline: DCM vs Terraform

---

## SETUP (before demo)

1. Open Snowsight → **Projects → Workspaces**
2. Click **"From Git repository"**
3. Paste: `https://github.com/tfreedman-snowflake/dcm-demo`
4. Select API Integration: `GIT_API_INTEGRATION`
5. Authenticate and create the workspace

The ECOMMERCE database is already deployed with live data.

---

## DEMO FLOW (10 minutes)

### Act 1: "What is DCM?" (2 min)

**Open the Workspace in Snowsight. Show the file tree:**

```
manifest.yml                    ← Project config (target, account)
sources/definitions/
  infrastructure.sql            ← DB, schemas, warehouse (12 lines)
  tables.sql                    ← 4 source tables (45 lines)
  analytics.sql                 ← 3 dynamic table pipelines (50 lines)
  serve.sql                     ← 3 consumption views (35 lines)
```

**Key message:** "This is ~90 lines of SQL that defines an entire data pipeline.
No new language to learn — it's just SQL with DEFINE instead of CREATE."

---

### Act 2: Show the Definitions (3 min)

**Open `infrastructure.sql`** — highlight how clean it is:
- One database, three schemas (RAW → ANALYTICS → SERVE)
- Warehouse with auto-suspend

**Open `analytics.sql`** — the star of the show:
- Dynamic tables that auto-refresh from source tables
- Dependency chain is implicit (Snowflake resolves it from the SQL references)
- No DAG to configure, no scheduler to set up

**Open `serve.sql`** — consumption views on top of dynamic tables

---

### Act 3: Plan & Deploy (2 min)

**In the Workspace, run plan:**
- Show the changeset — Snowflake tells you exactly what it will CREATE/ALTER/DROP
- Compare to `terraform plan` — same concept but Snowflake-native

**Key message:** "State lives inside Snowflake. No remote backend, no state locks,
no S3 bucket to manage."

---

### Act 4: Side-by-Side with Terraform (2 min)

**Open `terraform_equivalent.tf`** in the workspace (or on screen):

| | DCM | Terraform |
|---|---|---|
| Lines of code | ~90 | ~280 |
| Language | SQL (DEFINE) | HCL + SQL |
| Dependencies | Auto-resolved | Manual depends_on |
| Dynamic Tables | Native DEFINE | snowflake_unsafe_execute |
| State | In Snowflake | External (S3/TF Cloud) |
| New features | Day-1 support | Months lag (provider) |
| Learning curve | Know SQL? Done. | HCL + provider docs |

---

### Act 5: Live Data (1 min)

**Run these queries to show the pipeline is live:**

```sql
-- Revenue dashboard (dynamic table → view)
SELECT * FROM ECOMMERCE.SERVE.V_REVENUE_DASHBOARD;

-- Top products
SELECT * FROM ECOMMERCE.SERVE.V_TOP_PRODUCTS;

-- High-value customers (LTV > $500)
SELECT * FROM ECOMMERCE.SERVE.V_HIGH_VALUE_CUSTOMERS;
```

---

## OBJECTION HANDLING

**"We already use Terraform"**
→ "DCM isn't replacing Terraform for your AWS/Azure infra. It's specifically for
Snowflake objects where Terraform has gaps (dynamic tables, data quality, views).
Many customers use both — Terraform for cloud infra, DCM for Snowflake."

**"What about CI/CD?"**
→ "DCM works with any CI/CD system. Git-connected Workspaces give you branch-based
development with commit/push built in. Same plan→deploy workflow runs in GitHub
Actions or any pipeline."

**"Is this GA?"**
→ "Preview as of March 2026. Actively being enhanced. Core plan/deploy workflow
is production-ready."

**"What about existing objects?"**
→ "You can adopt existing objects by writing DEFINE statements that match their
current state. DCM's plan will show zero changes for adopted objects — confirming
it's in sync."

---

## RESOURCES
- Repo: https://github.com/tfreedman-snowflake/dcm-demo
- Docs: https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-overview
- Snowflake account: SFSENORTHAMERICA-TFREEDMAN_AWS_WEST_2
- Project: DCM_DEMO.PROJECTS.ECOMMERCE_PIPELINE

# Snowflake Iceberg → Fabric OneLake (Trading Demo)

Build a capital-markets demo where:

- **Snowflake** owns the data and writes **Iceberg** tables.
- The Iceberg files (Parquet + metadata) live **inside Fabric OneLake** (no ADLS / S3 in between).
- **Fabric Lakehouse** sees the tables immediately — zero-copy, zero ETL.

```
┌────────────────────┐      writes Iceberg       ┌────────────────────────────┐
│  Snowflake          │ ───────────────────────▶ │  Fabric OneLake             │
│  (managed Iceberg)  │   Parquet + metadata      │  Lakehouse / Files/iceberg  │
└────────────────────┘                            │  → auto-detected as tables  │
                                                  │  → Direct Lake / IQ / Spark │
                                                  └────────────────────────────┘
```

## Prerequisites

| Area | Requirement |
|---|---|
| **Snowflake** | Standard or higher; Iceberg enabled (GA); `ACCOUNTADMIN` for one-time setup |
| **Fabric** | Workspace + Lakehouse; **Contributor** role for the Snowflake Entra app |
| **Identity** | Microsoft Entra tenant ID; Snowflake's multi-tenant Entra app consented in your tenant |
| **Network** | Snowflake → `onelake.dfs.fabric.microsoft.com` reachable (public; or PrivateLink + MPE for private) |

## 1. One-time setup

Edit `sql/snowflake/01_iceberg_schema_onelake.sql`, replace placeholders:

| Placeholder | Example |
|---|---|
| `<workspace>` | `Capital Markets Demo` (URL-encode spaces if needed: `Capital%20Markets%20Demo`) |
| `<lakehouse>` | `cm_demo_lh` (your Lakehouse name, **without** `.Lakehouse` suffix) |
| `<entra-tenant-id>` | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `<warehouse>` | `FABRIC_WH` |
| `<your_user>` | your Snowflake login |

Run **Section A** in Snowflake (as `ACCOUNTADMIN`):

```bash
snowsql -a <account> -u <user> -r ACCOUNTADMIN -f sql/snowflake/01_iceberg_schema_onelake.sql
```

After `DESC EXTERNAL VOLUME onelake_capmkts;`:
1. Open the **AZURE_CONSENT_URL** → grant tenant-wide consent to Snowflake's app.
2. In the Fabric workspace → **Manage access** → add the Snowflake Entra app
   (the name shown in `AZURE_MULTI_TENANT_APP_NAME`) as **Contributor**.

Verify:
```sql
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('onelake_capmkts');
```

## 2. Create the Iceberg tables

Section B of the same script creates 8 Iceberg tables, each writing to
`Files/iceberg/<table>/` inside your Lakehouse.

## 3. Load demo data

The 8 demo CSVs are in [`data/`](../../data/). Load them via:

```bash
snowsql -a <account> -u <user> -r DATA_ENGINEER -w FABRIC_WH \
        -d CAPITAL_MARKETS -s PUBLIC -f sql/snowflake/02_load_data.sql
```

This uploads, copies, and prints row counts.

## 4. See the data in Fabric

After the COPY commands finish:

1. Open your Fabric Lakehouse → **Files → iceberg/** — you should see one
   subfolder per table containing `data/` and `metadata/`.
2. Right-click the Lakehouse → **Refresh** if needed.
3. Tables appear under **Tables** automatically (or create a OneLake shortcut to
   each Iceberg folder if your tenant doesn't auto-detect yet).
4. Query in a notebook:
   ```python
   spark.table("trades").groupBy("side").count().show()
   ```
5. Build the **Fabric IQ ontology** on top — see
   [`notebooks/02_build_ontology.ipynb`](../../notebooks/02_build_ontology.ipynb).

## How writes work

| Step | Where it runs | What happens |
|---|---|---|
| `COPY INTO trades` | Snowflake compute | Reads CSV from internal stage |
| Iceberg write | Snowflake compute | Writes Parquet + Iceberg metadata to OneLake |
| Fabric reads | Fabric compute | Reads Parquet directly; **no Snowflake credits** consumed |

## Notes & caveats

- Snowflake-managed Iceberg = **single writer** (Snowflake). Fabric is a reader.
- OneLake is your storage; Snowflake just writes through to it.
- Schema evolution (`ALTER TABLE … ADD COLUMN`) flows through to Fabric.
- For **medium / large** scale data, regenerate CSVs first:
  ```powershell
  python generate_data.py --scale medium --out data
  ```
- Snowflake row-access / masking policies do **not** flow to Fabric — re-implement
  in Fabric Lakehouse views or in the Fabric IQ ontology layer.

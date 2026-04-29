# ============================================================================
# TERRAFORM EQUIVALENT - Same infrastructure, ~3x more code
# This file shows what you'd need in Terraform to achieve the same result
# as the DCM project. Notice: no dependency resolution, no dynamic table
# support, manual state management, and significant boilerplate.
# ============================================================================

terraform {
  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.90"
    }
  }
}

provider "snowflake" {
  account  = "SFSENORTHAMERICA-TFREEDMAN_AWS_WEST_2"
  role     = "ACCOUNTADMIN"
}

# --------------------------------------------------------------------------
# DATABASE & SCHEMAS
# --------------------------------------------------------------------------

resource "snowflake_database" "ecommerce" {
  name    = "ECOMMERCE"
  comment = "E-commerce analytics platform"
}

resource "snowflake_schema" "raw" {
  database            = snowflake_database.ecommerce.name
  name                = "RAW"
  comment             = "Landing zone for ingested data"
  data_retention_days = 14
}

resource "snowflake_schema" "analytics" {
  database       = snowflake_database.ecommerce.name
  name           = "ANALYTICS"
  comment        = "Transformation layer with dynamic tables"
  is_managed     = true
}

resource "snowflake_schema" "serve" {
  database   = snowflake_database.ecommerce.name
  name       = "SERVE"
  comment    = "Consumption layer for BI and applications"
  is_managed = true
}

# --------------------------------------------------------------------------
# WAREHOUSE
# --------------------------------------------------------------------------

resource "snowflake_warehouse" "ecommerce_wh" {
  name                = "ECOMMERCE_WH"
  warehouse_size      = "XSMALL"
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
  comment             = "Compute for e-commerce pipeline"
}

# --------------------------------------------------------------------------
# TABLES (Terraform doesn't natively support CHANGE_TRACKING)
# --------------------------------------------------------------------------

resource "snowflake_table" "customers" {
  database        = snowflake_database.ecommerce.name
  schema          = snowflake_schema.raw.name
  name            = "CUSTOMERS"
  comment         = "Customer master data from CRM"
  change_tracking = true

  column {
    name     = "CUSTOMER_ID"
    type     = "NUMBER(38,0)"
    nullable = false
  }
  column {
    name = "FIRST_NAME"
    type = "VARCHAR(100)"
  }
  column {
    name = "LAST_NAME"
    type = "VARCHAR(100)"
  }
  column {
    name = "EMAIL"
    type = "VARCHAR(200)"
  }
  column {
    name = "REGION"
    type = "VARCHAR(50)"
  }
  column {
    name = "SIGNUP_DATE"
    type = "DATE"
  }
  column {
    name    = "IS_ACTIVE"
    type    = "BOOLEAN"
    default {
      constant = "true"
    }
  }
}

resource "snowflake_table" "products" {
  database        = snowflake_database.ecommerce.name
  schema          = snowflake_schema.raw.name
  name            = "PRODUCTS"
  comment         = "Product catalog from ERP"
  change_tracking = true

  column {
    name     = "PRODUCT_ID"
    type     = "NUMBER(38,0)"
    nullable = false
  }
  column {
    name = "PRODUCT_NAME"
    type = "VARCHAR(200)"
  }
  column {
    name = "CATEGORY"
    type = "VARCHAR(100)"
  }
  column {
    name = "UNIT_PRICE"
    type = "NUMBER(10,2)"
  }
  column {
    name = "SUPPLIER"
    type = "VARCHAR(100)"
  }
  column {
    name    = "IS_ACTIVE"
    type    = "BOOLEAN"
    default {
      constant = "true"
    }
  }
  column {
    name = "CREATED_AT"
    type = "TIMESTAMP_NTZ"
    default {
      expression = "CURRENT_TIMESTAMP()"
    }
  }
}

resource "snowflake_table" "orders" {
  database        = snowflake_database.ecommerce.name
  schema          = snowflake_schema.raw.name
  name            = "ORDERS"
  comment         = "Order transactions from POS system"
  change_tracking = true

  column {
    name     = "ORDER_ID"
    type     = "NUMBER(38,0)"
    nullable = false
  }
  column {
    name     = "CUSTOMER_ID"
    type     = "NUMBER(38,0)"
    nullable = false
  }
  column {
    name = "ORDER_DATE"
    type = "TIMESTAMP_NTZ"
  }
  column {
    name    = "STATUS"
    type    = "VARCHAR(20)"
    default {
      constant = "'PENDING'"
    }
  }
  column {
    name = "TOTAL_AMOUNT"
    type = "NUMBER(12,2)"
  }
  column {
    name = "SHIPPING_ADDRESS"
    type = "VARCHAR(500)"
  }
  column {
    name = "PAYMENT_METHOD"
    type = "VARCHAR(50)"
  }
}

resource "snowflake_table" "order_items" {
  database        = snowflake_database.ecommerce.name
  schema          = snowflake_schema.raw.name
  name            = "ORDER_ITEMS"
  comment         = "Line items for each order"
  change_tracking = true

  column {
    name     = "ITEM_ID"
    type     = "NUMBER(38,0)"
    nullable = false
  }
  column {
    name     = "ORDER_ID"
    type     = "NUMBER(38,0)"
    nullable = false
  }
  column {
    name     = "PRODUCT_ID"
    type     = "NUMBER(38,0)"
    nullable = false
  }
  column {
    name = "QUANTITY"
    type = "NUMBER(38,0)"
  }
  column {
    name = "UNIT_PRICE"
    type = "NUMBER(10,2)"
  }
  column {
    name    = "DISCOUNT_PCT"
    type    = "NUMBER(5,2)"
    default {
      constant = "0"
    }
  }
}

# --------------------------------------------------------------------------
# DYNAMIC TABLES - NOT SUPPORTED IN TERRAFORM!
# You would need to use snowflake_unsafe_execute or null_resource + local-exec
# --------------------------------------------------------------------------

resource "snowflake_unsafe_execute" "dt_daily_revenue" {
  execute = <<-EOT
    CREATE OR REPLACE DYNAMIC TABLE ECOMMERCE.ANALYTICS.DT_DAILY_REVENUE
    WAREHOUSE = 'ECOMMERCE_WH'
    TARGET_LAG = '1 hour'
    INITIALIZE = ON_CREATE
    AS
    SELECT
        DATE_TRUNC('DAY', o.ORDER_DATE) AS ORDER_DAY,
        COUNT(DISTINCT o.ORDER_ID) AS TOTAL_ORDERS,
        COUNT(DISTINCT o.CUSTOMER_ID) AS UNIQUE_CUSTOMERS,
        SUM(o.TOTAL_AMOUNT) AS DAILY_REVENUE
    FROM ECOMMERCE.RAW.ORDERS o
    WHERE o.STATUS != 'CANCELLED'
    GROUP BY ORDER_DAY;
  EOT
  revert = "DROP DYNAMIC TABLE IF EXISTS ECOMMERCE.ANALYTICS.DT_DAILY_REVENUE"

  depends_on = [
    snowflake_table.orders,
    snowflake_schema.analytics,
    snowflake_warehouse.ecommerce_wh
  ]
}

resource "snowflake_unsafe_execute" "dt_product_performance" {
  execute = <<-EOT
    CREATE OR REPLACE DYNAMIC TABLE ECOMMERCE.ANALYTICS.DT_PRODUCT_PERFORMANCE
    WAREHOUSE = 'ECOMMERCE_WH'
    TARGET_LAG = '1 hour'
    INITIALIZE = ON_CREATE
    AS
    SELECT
        p.PRODUCT_ID,
        p.PRODUCT_NAME,
        p.CATEGORY,
        COUNT(DISTINCT oi.ORDER_ID) AS TIMES_ORDERED,
        SUM(oi.QUANTITY) AS TOTAL_UNITS_SOLD,
        SUM(oi.QUANTITY * oi.UNIT_PRICE * (1 - oi.DISCOUNT_PCT/100)) AS TOTAL_REVENUE,
        AVG(oi.DISCOUNT_PCT) AS AVG_DISCOUNT
    FROM ECOMMERCE.RAW.PRODUCTS p
    JOIN ECOMMERCE.RAW.ORDER_ITEMS oi ON p.PRODUCT_ID = oi.PRODUCT_ID
    GROUP BY p.PRODUCT_ID, p.PRODUCT_NAME, p.CATEGORY;
  EOT
  revert = "DROP DYNAMIC TABLE IF EXISTS ECOMMERCE.ANALYTICS.DT_PRODUCT_PERFORMANCE"

  depends_on = [
    snowflake_table.products,
    snowflake_table.order_items,
    snowflake_schema.analytics,
    snowflake_warehouse.ecommerce_wh
  ]
}

resource "snowflake_unsafe_execute" "dt_customer_ltv" {
  execute = <<-EOT
    CREATE OR REPLACE DYNAMIC TABLE ECOMMERCE.ANALYTICS.DT_CUSTOMER_LIFETIME_VALUE
    WAREHOUSE = 'ECOMMERCE_WH'
    TARGET_LAG = 'DOWNSTREAM'
    INITIALIZE = ON_CREATE
    AS
    SELECT
        c.CUSTOMER_ID,
        c.FIRST_NAME || ' ' || c.LAST_NAME AS CUSTOMER_NAME,
        c.EMAIL,
        c.REGION,
        COUNT(DISTINCT o.ORDER_ID) AS TOTAL_ORDERS,
        SUM(o.TOTAL_AMOUNT) AS LIFETIME_VALUE,
        MIN(o.ORDER_DATE) AS FIRST_ORDER,
        MAX(o.ORDER_DATE) AS LAST_ORDER,
        DATEDIFF('day', MIN(o.ORDER_DATE), MAX(o.ORDER_DATE)) AS CUSTOMER_TENURE_DAYS
    FROM ECOMMERCE.RAW.CUSTOMERS c
    LEFT JOIN ECOMMERCE.RAW.ORDERS o ON c.CUSTOMER_ID = o.CUSTOMER_ID
    GROUP BY c.CUSTOMER_ID, c.FIRST_NAME, c.LAST_NAME, c.EMAIL, c.REGION;
  EOT
  revert = "DROP DYNAMIC TABLE IF EXISTS ECOMMERCE.ANALYTICS.DT_CUSTOMER_LIFETIME_VALUE"

  depends_on = [
    snowflake_table.customers,
    snowflake_table.orders,
    snowflake_schema.analytics,
    snowflake_warehouse.ecommerce_wh
  ]
}

# --------------------------------------------------------------------------
# VIEWS
# --------------------------------------------------------------------------

resource "snowflake_view" "v_revenue_dashboard" {
  database  = snowflake_database.ecommerce.name
  schema    = snowflake_schema.serve.name
  name      = "V_REVENUE_DASHBOARD"
  statement = <<-EOT
    SELECT
        ORDER_DAY,
        TOTAL_ORDERS,
        UNIQUE_CUSTOMERS,
        DAILY_REVENUE,
        DAILY_REVENUE / NULLIF(TOTAL_ORDERS, 0) AS AVG_ORDER_VALUE
    FROM ECOMMERCE.ANALYTICS.DT_DAILY_REVENUE
    ORDER BY ORDER_DAY DESC
  EOT

  depends_on = [snowflake_unsafe_execute.dt_daily_revenue]
}

resource "snowflake_view" "v_top_products" {
  database  = snowflake_database.ecommerce.name
  schema    = snowflake_schema.serve.name
  name      = "V_TOP_PRODUCTS"
  statement = <<-EOT
    SELECT
        PRODUCT_NAME,
        CATEGORY,
        TIMES_ORDERED,
        TOTAL_UNITS_SOLD,
        TOTAL_REVENUE,
        AVG_DISCOUNT
    FROM ECOMMERCE.ANALYTICS.DT_PRODUCT_PERFORMANCE
    WHERE TOTAL_UNITS_SOLD > 0
    ORDER BY TOTAL_REVENUE DESC
  EOT

  depends_on = [snowflake_unsafe_execute.dt_product_performance]
}

resource "snowflake_view" "v_high_value_customers" {
  database  = snowflake_database.ecommerce.name
  schema    = snowflake_schema.serve.name
  name      = "V_HIGH_VALUE_CUSTOMERS"
  statement = <<-EOT
    SELECT
        CUSTOMER_NAME,
        EMAIL,
        REGION,
        TOTAL_ORDERS,
        LIFETIME_VALUE,
        FIRST_ORDER,
        LAST_ORDER,
        CUSTOMER_TENURE_DAYS
    FROM ECOMMERCE.ANALYTICS.DT_CUSTOMER_LIFETIME_VALUE
    WHERE LIFETIME_VALUE > 500
    ORDER BY LIFETIME_VALUE DESC
  EOT

  depends_on = [snowflake_unsafe_execute.dt_customer_ltv]
}

# --------------------------------------------------------------------------
# TOTAL: ~280 lines of Terraform vs ~90 lines of DCM definitions
#
# KEY DIFFERENCES FOR YOUR DEMO:
# 1. Terraform requires MANUAL dependency management (depends_on)
#    DCM resolves dependencies AUTOMATICALLY from SQL references
#
# 2. Terraform has NO native dynamic table support
#    Requires snowflake_unsafe_execute (opaque to state, no drift detection)
#
# 3. Terraform state is stored externally (S3, Terraform Cloud, etc.)
#    DCM state lives IN Snowflake alongside the objects
#
# 4. Terraform requires HCL knowledge + Snowflake SQL knowledge
#    DCM uses pure SQL (DEFINE instead of CREATE)
#
# 5. Terraform plan shows resource-level diffs
#    DCM plan shows Snowflake-aware DDL diffs (column adds, type changes)
#
# 6. Terraform provider lags behind Snowflake features (months)
#    DCM supports new Snowflake features at release (native)
# --------------------------------------------------------------------------

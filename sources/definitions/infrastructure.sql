DEFINE DATABASE ECOMMERCE
    COMMENT = 'E-commerce analytics platform';

DEFINE SCHEMA ECOMMERCE.RAW
    COMMENT = 'Landing zone for ingested data'
    DATA_RETENTION_TIME_IN_DAYS = 14;

DEFINE SCHEMA ECOMMERCE.ANALYTICS
    WITH MANAGED ACCESS
    COMMENT = 'Transformation layer with dynamic tables';

DEFINE SCHEMA ECOMMERCE.SERVE
    WITH MANAGED ACCESS
    COMMENT = 'Consumption layer for BI and applications';

DEFINE WAREHOUSE ECOMMERCE_WH
WITH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Compute for e-commerce pipeline';

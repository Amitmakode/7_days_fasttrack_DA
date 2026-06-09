# Run in MySQL client
mysql -u root -p

# Execute in order
SOURCE 01_create_rolap_schema.sql;
SOURCE 02_create_molap_schema.sql;
SOURCE 03_etl_rolap_from_oltp.sql;
SOURCE 04_etl_molap_from_rolap.sql;

# Optional: Run analytical queries
SOURCE 05_analytical_queries_rolap.sql;
SOURCE 06_analytical_queries_molap.sql;
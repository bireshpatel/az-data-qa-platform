# tests/data_quality_check.py
import pyspark.sql.functions as F

# Example: Testing a dataset for nulls
def check_nulls(df, column_name):
    null_count = df.filter(F.col(column_name).isNull()).count()
    if null_count > 0:
        print(f"QA FAILED: Found {null_count} nulls in {column_name}")
    else:
        print(f"QA PASSED: {column_name} is clean.")

# Run a test
df = spark.range(1, 100)
check_nulls(df, "id")
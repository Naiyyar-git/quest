# Rearc Data Quest

### Q. What is this quest?
It is a fun way to assess your data skills. It is also a good representative sample of the work we do at Rearc.

### Q. So what skills should I have?
Basic data management concepts. Some programming language. Some AWS.

### Q. What do I have to do?

#### Part 1: AWS S3 & Sourcing Datasets
1) Republish [this open dataset](https://download.bls.gov/pub/time.series/pr/) in Amazon S3 and share us a link.
2) Script this process so the data can be kept in sync with the source when it updates and send us the script.
3) Don't rely on hard coded names, the script should be able to handle added or removed files.
4) Ensure the script doesn't upload the same file more than once.

#### Part 2: APIs
1) Create a script that will fetch data from [this API](https://datausa.io/api/data?drilldowns=Nation&measures=Population).
   You can read the documentation [here](https://datausa.io/about/api/)
2) Save the result of this API call as a JSON file in S3.

#### Part 3: Data Analytics
0) Load both the csv file from **Part 1** `pr.data.0.Current` and the json file from **Part 2**
   as dataframes ([Spark](https://spark.apache.org/docs/1.6.1/api/java/org/apache/spark/sql/DataFrame.html),
                  [Pyspark](https://spark.apache.org/docs/latest/api/python/reference/api/pyspark.sql.DataFrame.html),
                  [Pandas](https://pandas.pydata.org/pandas-docs/stable/reference/api/pandas.DataFrame.html),
                  [Koalas](https://koalas.readthedocs.io/en/latest/),
                  etc).

1) Using the dataframe from the population data API (Part 2),
   generate a report/table that will give the Mean and the Standard Distribution of the US population from the years [2013, 2018] inclusive.
   
2) Using the dataframe from the time-series (Part 1),
   generate a report that will give for every series_id the year which contains the max/largest sum of the values on all quarters.
   For example if the table had the following values:
   
    | series_id   | year | period | value |
    |-------------|------|--------|-------|
    | PRS30006011 | 1995 | Q01    | 1     |
    | PRS30006011 | 1995 | Q02    | 2     |
    | PRS30006011 | 1996 | Q01    | 3     |
    | PRS30006011 | 1996 | Q02    | 4     |
    | PRS30006012 | 2000 | Q01    | 0     |
    | PRS30006012 | 2000 | Q02    | 8     |
    | PRS30006012 | 2001 | Q01    | 2     |
    | PRS30006012 | 2001 | Q02    | 3     |
    the report would generate the following table:

    | series_id   | year | value |
    |-------------|------|-------|
    | PRS30006011 | 1996 | 7     |
    | PRS30006012 | 2000 | 8     |

3) Using both dataframes from Part 1 and Part 2, generate a report that will provide the `value`
   for `series_id = PRS30006032` and `period = Q01` and the `population` for that given year (if available in the population dataset)
   
    | series_id   | year | period | value | Population |
    |-------------|------|--------|-------|------------|
    | PRS30006032 | 2018 | Q01    | 1.9   | 327167439  |

    **Hints:** when working with public datasets you sometimes might have to perform some data cleaning first.
   For example, you might find it useful to perform [trimming](https://stackoverflow.com/questions/35540974/remove-blank-space-from-data-frame-column-values-in-spark) of whitespaces before doing any filtering or joins
   

4) Submit your analysis, your queries, and the outcome of the reports as a [.ipynb](https://fileinfo.com/extension/ipynb) file.

### Q. Do I have to do all these?
You can do as many as you like. We suspect though that once you start you won't be able to stop. It's addictive.

### Q. What do I have to submit?
1) Link to data in S3 (if you complete Step 1)
2) Source code (if you complete Step 2 or beyond)
3) Source code in .ipynb file format and results (if you complete the Step 3)

### Q. What if I successfully complete all the steps?
We have many more for you to solve as a member of the Rearc team!

### Q. What if I fail?
Do. Or do not. There is no fail.

### Q. Can i share this quest with others?
No.

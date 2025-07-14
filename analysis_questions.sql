# COALESCE-- Returns the first non-NULL value from a list of columns or expressions. You want to replace NULLs with something (e.g., 'None')
# CONCAT_WS()-- Joins multiple values into one string, separated by a defined separator (like ' | ' or ' - '), and automatically skips NULLs.
USE survey;
#  How many total responses were recorded in the survey? ------------------------------------
SELECT count(ResponseId) from survey_results_2024;

#  What are the top 5 countries with the most survey respondents? -----------------------------
SELECT count(ResponseId), Country from survey_results_2024 group by Country Limit 5 ; # no need to use order by, already in order

# How many respondents are currently employed full-time? ------------------------------------
SELECT count(*) AS total_employed,
round(count(*)*100 / (SELECT count(*) from survey_results_2024 where Employment is not null ), 2) AS Perc_emp
from survey_results_2024  where  Employment = "Employed, full-time" ; # 59.66

# How many(Percentage) respondents have used JavaScript in the past year? -----------------------------------------------------------
SELECT count(*) AS JS_user,
 round( count(*) * 100 / ( SELECT count(*) from survey_results_2024 where LanguageHaveWorkedWith is not null ), 2)  AS JS_perc
 from survey_results_2024 where LanguageHaveWorkedWith like "%JavaScript%"; #57.29


# How many developers have a Stack Overflow account?--------------------------------------------------------------------------------
SELECT count(*) AS user_acc, 
round(count(*) * 100 / (SELECT count(*) from survey_results_2024 where SOAccount is not null), 2) As acc_per 
from survey_results_2024 where SOAccount = "Yes"; #45453 , 69.43


# Which developer types are most common in each country? ---------------------------------------------------------------------------
-- Step 1: Split DevType values using recursion
WITH RECURSIVE dev_split AS (
  SELECT
    ResponseId,
    Country,
    TRIM(SUBSTRING_INDEX(DevType, ';', 1)) AS Dev,
    SUBSTRING(DevType, LENGTH(SUBSTRING_INDEX(DevType, ';', 1)) + 2) AS remaining
  FROM survey_results_2024
  WHERE DevType IS NOT NULL AND Country IS NOT NULL

  UNION ALL

  SELECT
    ResponseId,
    Country,
    TRIM(SUBSTRING_INDEX(remaining, ';', 1)),
    SUBSTRING(remaining, LENGTH(SUBSTRING_INDEX(remaining, ';', 1)) + 2)
  FROM dev_split
  WHERE remaining != ''
),

-- Step 2: Count frequency per country-devtype and rank
RankedDevTypes AS (
  SELECT 
    Country, 
    Dev, 
    COUNT(*) AS CountPerDevType,
    ROW_NUMBER() OVER (PARTITION BY Country ORDER BY COUNT(*) DESC) AS rnk
    #Har country + devtype pair ka count hota hai, ROW_NUMBER() use kr k har country ka top developer type nikal rahe hain
  FROM dev_split
  GROUP BY Country, Dev
)

-- Step 3: Final output — most common DevType per country
SELECT Country, Dev AS Most_Common_DevType, CountPerDevType
FROM RankedDevTypes
WHERE rnk = 1 #Filters only the top (most common) developer type per country
ORDER BY Country;


# What are the most used databases among respondents?-----------------------------------------------------------------------------
-- Step 1: Recursive CTE to split database strings
WITH RECURSIVE db_split AS (
-- Base Case: extract the first value 
  SELECT
    ResponseId,
    TRIM(SUBSTRING_INDEX(DatabaseHaveWorkedWith, ';', 1)) AS db,
    SUBSTRING(DatabaseHaveWorkedWith, LENGTH(SUBSTRING_INDEX(DatabaseHaveWorkedWith, ';', 1)) + 2) AS remaining
  FROM survey_results_2024
  WHERE DatabaseHaveWorkedWith IS NOT NULL AND DatabaseHaveWorkedWith <> 'NA'

  UNION ALL
-- Recursive Case: continue splitting the remaining part 
  SELECT
    ResponseId,
    TRIM(SUBSTRING_INDEX(remaining, ';', 1)) AS db,
    SUBSTRING(remaining, LENGTH(SUBSTRING_INDEX(remaining, ';', 1)) + 2)
  FROM db_split
  WHERE remaining != ''
)

-- Step 2: Count frequency of each individual database
SELECT 
  db AS DatabaseName,
  COUNT(*) AS users,
  ROUND(COUNT(*) * 100.0 / (
    SELECT COUNT(*) FROM survey_results_2024 
    WHERE DatabaseHaveWorkedWith IS NOT NULL AND DatabaseHaveWorkedWith <> 'NA'
  ), 2) AS percentage
FROM db_split
GROUP BY db
ORDER BY users DESC;  #69.46


# Which technologies are most admired vs. most desired?------------------------------------------------------------------------------
-- Step 1 to 3: Splitting and counts remain the same
WITH RECURSIVE admired_split AS (
  SELECT
    ResponseId,
    TRIM(SUBSTRING_INDEX(WebframeAdmired, ';', 1)) AS tech,
    SUBSTRING(WebframeAdmired, LENGTH(SUBSTRING_INDEX(WebframeAdmired, ';', 1)) + 2) AS remaining
  FROM survey_results_2024
  WHERE WebframeAdmired IS NOT NULL AND WebframeAdmired <> 'NA'

  UNION ALL

  SELECT
    ResponseId,
    TRIM(SUBSTRING_INDEX(remaining, ';', 1)),
    SUBSTRING(remaining, LENGTH(SUBSTRING_INDEX(remaining, ';', 1)) + 2)
  FROM admired_split
  WHERE remaining != ''
),

desired_split AS (
  SELECT
    ResponseId,
    TRIM(SUBSTRING_INDEX(WebframeWantToWorkWith, ';', 1)) AS tech,
    SUBSTRING(WebframeWantToWorkWith, LENGTH(SUBSTRING_INDEX(WebframeWantToWorkWith, ';', 1)) + 2) AS remaining
  FROM survey_results_2024
  WHERE WebframeWantToWorkWith IS NOT NULL AND WebframeWantToWorkWith <> 'NA'

  UNION ALL

  SELECT
    ResponseId,
    TRIM(SUBSTRING_INDEX(remaining, ';', 1)),
    SUBSTRING(remaining, LENGTH(SUBSTRING_INDEX(remaining, ';', 1)) + 2)
  FROM desired_split
  WHERE remaining != ''
),

admired_counts AS (
  SELECT tech, COUNT(*) AS admired_count FROM admired_split GROUP BY tech
),
desired_counts AS (
  SELECT tech, COUNT(*) AS desired_count FROM desired_split GROUP BY tech
),

-- Combine both and calculate percentages
combined AS (
  SELECT 
    COALESCE(a.tech, d.tech) AS Technology,
    ROUND(COALESCE(a.admired_count, 0) * 100.0 / (SELECT COUNT(*) FROM admired_split), 2) AS Admired_Percent,
    ROUND(COALESCE(d.desired_count, 0) * 100.0 / (SELECT COUNT(*) FROM desired_split), 2) AS Desired_Percent
  FROM admired_counts a
  LEFT JOIN desired_counts d ON a.tech = d.tech

  UNION

  SELECT 
    d.tech,
    ROUND(COALESCE(a.admired_count, 0) * 100.0 / (SELECT COUNT(*) FROM admired_split), 2),
    ROUND(d.desired_count * 100.0 / (SELECT COUNT(*) FROM desired_split), 2)
  FROM admired_counts a
  RIGHT JOIN desired_counts d ON a.tech = d.tech
)

-- Final sorted output
SELECT * 
FROM combined
ORDER BY Desired_Percent DESC, Admired_Percent DESC LIMIT 10;


#  What are the average and median salaries for different countries?------------------------------------------------------------------
WITH country_salaries AS (
  SELECT 
    Country, 
    CompTotal
  FROM survey_results_2024
  WHERE CompTotal IS NOT NULL 
    AND Country IS NOT NULL
    AND CompTotal > 0
),

ranked_salaries AS (
  SELECT 
    Country,
    CompTotal,
    ROW_NUMBER() OVER (PARTITION BY Country ORDER BY CompTotal) AS rn,
    COUNT(*) OVER (PARTITION BY Country) AS cnt
  FROM country_salaries
),

medians AS (
  SELECT 
    Country,
    AVG(CompTotal) AS Median_Salary
  FROM ranked_salaries
  WHERE rn = FLOOR((cnt + 1) / 2) OR rn = CEIL((cnt + 1) / 2)
  GROUP BY Country
  # We’re in the ranked_salaries CTE, where each salary is ranked by ROW_NUMBER() (stored in rn), and total count is stored in cnt.
  #  Odd Count (e.g., 5 records) -> cnt = (5+1)/2 -> FLOOR(3) = 3, CEIL(3) = 3 → so we pick just row 3
  # Even Count (e.g., 6 records) -> cnt = (6+1)/2 -> FLOOR(3.5) = 3, CEIL(3.5) = 4 -> So we pick rows 3 and 4 -> Median = average of values at row 3 and 4
)


-- Final result with average and median
SELECT 
  cs.Country,
  ROUND(AVG(cs.CompTotal), 2) AS Average_Salary,
  ROUND(m.Median_Salary, 2) AS Median_Salary
FROM country_salaries cs
JOIN medians m ON cs.Country = m.Country
GROUP BY cs.Country
ORDER BY Average_Salary DESC;
#, m.Median_Salary


# Which countries report the highest average compensation? --------------------------------------------------------------------------
SELECT  Country,
	round(Avg(CompTotal),2) AS AvgSalary
    from survey_results_2024    
	where CompTotal is not null AND Country is not null AND CompTotal > 0
    group by Country
    order by  AvgSalary desc limit 	10
;

-- Which AI tools are most admired, and how does usage compare between professionals and learners?
-- Step # 1
WITH RECURSIVE admired_split AS (
  SELECT 
    ResponseId,
    MainBranch,
    TRIM(SUBSTRING_INDEX(`AISearchDevAdmired`, ';', 1)) AS tool,
    SUBSTRING(`AISearchDevAdmired`, LENGTH(SUBSTRING_INDEX(`AISearchDevAdmired`, ';', 1)) + 2) AS remaining
  FROM survey_results_2024
  WHERE `AISearchDevAdmired` IS NOT NULL AND `AISearchDevAdmired` <> 'NA'

  UNION ALL

  SELECT 
    ResponseId,
    MainBranch,
    TRIM(SUBSTRING_INDEX(remaining, ';', 1)),
    SUBSTRING(remaining, LENGTH(SUBSTRING_INDEX(remaining, ';', 1)) + 2)
  FROM admired_split
  WHERE remaining != ''
)

-- Step # 2 Count Admired Tools by User Type
SELECT 
  tool AS AI_Tool,
  CASE 
    -- WHEN MainBranch LIKE '%primiraly not a developer%' THEN 'Learner'
    WHEN MainBranch LIKE '%developer by profession%' THEN 'Professional'
    ELSE 'Learners'
  END AS User_Type,
  COUNT(*) AS Count
FROM admired_split
WHERE tool IS NOT NULL
GROUP BY AI_Tool, User_Type
ORDER BY  Count DESC;

 
-- What is the relationship between developer type and employment status? -----------------------------------------------------------
-- Step 1: Split DevType into individual rows using recursive CTE
WITH RECURSIVE devtype_split AS (
  SELECT 
    ResponseId,
    TRIM(SUBSTRING_INDEX(DevType, ';', 1)) AS DevRole,
    SUBSTRING(DevType, LENGTH(SUBSTRING_INDEX(DevType, ';', 1)) + 2) AS remaining,
    Employment
  FROM survey_results_2024
  WHERE DevType IS NOT NULL AND Employment IS NOT NULL

  UNION ALL

  SELECT 
    ResponseId,
    TRIM(SUBSTRING_INDEX(remaining, ';', 1)) AS DevRole,
    SUBSTRING(remaining, LENGTH(SUBSTRING_INDEX(remaining, ';', 1)) + 2),
    Employment
  FROM devtype_split
  WHERE remaining != ''
),
-- Step 2: Recursive CTE to split Employment
employment_split AS (
  SELECT 
    ResponseId,
    TRIM(SUBSTRING_INDEX(Employment, ';', 1)) AS EmploymentType,
    SUBSTRING(Employment, LENGTH(SUBSTRING_INDEX(Employment, ';', 1)) + 2) AS remaining
  FROM survey_results_2024
  WHERE Employment IS NOT NULL

  UNION ALL

  SELECT 
    ResponseId,
    TRIM(SUBSTRING_INDEX(remaining, ';', 1)),
    SUBSTRING(remaining, LENGTH(SUBSTRING_INDEX(remaining, ';', 1)) + 2)
  FROM employment_split
  WHERE remaining != ''
),

-- Step 3: Join both splits on ResponseId
joined_split AS (
  SELECT 
    d.ResponseId,
    d.DevRole,
    e.EmploymentType
  FROM devtype_split d
  JOIN employment_split e ON d.ResponseId = e.ResponseId
)

-- Step 4: Group and calculate counts + percentages
SELECT 
  DevRole,
  EmploymentType,
  COUNT(*) AS Count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY DevRole), 2) AS Percentage_Per_Role 
FROM joined_split
GROUP BY DevRole, EmploymentType
ORDER BY DevRole, Count DESC;
 
# SUM(COUNT(*)) OVER (PARTITION BY DevRole) -- This part gives the total number of people for each DevRole across all employment types
# COUNT(*) / SUM(...) -- Calculates the fraction of one employment type out of all for that dev role.
 
 
#  Which combination of technologies is most common among full-time developers?------------------------------------------------------
SELECT 
  CONCAT_WS(' | ', #-> skips null
    NULLIF(LanguageHaveWorkedWith, 'NA'), #-> NULL 
    NULLIF(DatabaseHaveWorkedWith, 'NA'),
    NULLIF(WebframeHaveWorkedWith, 'NA'),
    NULLIF(ToolsTechHaveWorkedWith, 'NA'),
    NULLIF(PlatformHaveWorkedWith, 'NA'), 
	NULLIF(EmbeddedHaveWorkedWith, 'NA'), 
	NULLIF(MiscTechHaveWorkedWith, 'NA'), 
	NULLIF(AISearchDevHaveWorkedWith, 'NA')
  ) AS Tech_Stack,
  COUNT(*) AS Users
FROM survey_results_2024
WHERE Employment LIKE '%full-time%' # work on Rows, Filters out completely useless rows
 AND (
    LanguageHaveWorkedWith IS NOT NULL AND LanguageHaveWorkedWith <> 'NA'
    OR DatabaseHaveWorkedWith IS NOT NULL AND DatabaseHaveWorkedWith <> 'NA'
    OR WebframeHaveWorkedWith IS NOT NULL AND WebframeHaveWorkedWith <> 'NA'
    OR ToolsTechHaveWorkedWith IS NOT NULL AND ToolsTechHaveWorkedWith <> 'NA'
    OR PlatformHaveWorkedWith IS NOT NULL AND PlatformHaveWorkedWith <> 'NA'
    OR EmbeddedHaveWorkedWith IS NOT NULL AND EmbeddedHaveWorkedWith <> 'NA'
    OR MiscTechHaveWorkedWith IS NOT NULL AND MiscTechHaveWorkedWith <> 'NA'
    OR AISearchDevHaveWorkedWith IS NOT NULL AND AISearchDevHaveWorkedWith <> 'NA'
  )
GROUP BY Tech_Stack
ORDER BY Users DESC
LIMIT 10;

-- NULLIF(col, 'NA'): Converts 'NA' values into NULL, work on Individual columns. Removes 'NA' values from display output
-- CONCAT_WS(): Automatically skips NULLs, so only real technologies will appear in the stack, No more messy rows like:->"Python | NA | NA | NA"
-- → Instead, you'll get: -> "Python"



-- --------------------------------- Eductaion -----------------------------------
-- educational attainment*(%) of professional developers? 
 SELECT 
  EdLevel, 
  COUNT(*) AS Count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS Percentage # SUM(COUNT(*)) OVER (): gives total count across all groups
FROM survey_results_2024
WHERE 
  MainBranch LIKE '%developer by profession%%'
  AND EdLevel IS NOT NULL
   AND EdLevel <> 'NA'
  GROUP BY EdLevel
  ORDER BY Count DESC;

-- how survey respondents learn to code based on their age?---------------------------------------------------------------------------------------------------------
-- Step 1: Recursive CTE to split LearnCode values
WITH RECURSIVE learn_split AS (
  SELECT 
    ResponseId,
    Age,
    TRIM(SUBSTRING_INDEX(LearnCode, ';', 1)) AS method,
    SUBSTRING(LearnCode, LENGTH(SUBSTRING_INDEX(LearnCode, ';', 1)) + 2) AS remaining
  FROM survey_results_2024
  WHERE LearnCode IS NOT NULL AND LearnCode <> 'NA'

  UNION ALL

  SELECT 
    ResponseId,
    Age,
    TRIM(SUBSTRING_INDEX(remaining, ';', 1)),
    SUBSTRING(remaining, LENGTH(SUBSTRING_INDEX(remaining, ';', 1)) + 2)
  FROM learn_split
  WHERE remaining != ''
)

-- Final aggregation by Age and Method
SELECT 
  Age,
  method AS Learning_Method,
  COUNT(*) AS Respondent_Count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY Age), 2) AS Percentage
FROM learn_split
WHERE Age IS NOT NULL
GROUP BY Age, method
ORDER BY Age, Respondent_Count DESC;

-- Top 10 online resources for learning code? -------------------------------------------------------------------------------------------------------

WITH RECURSIVE learn_split AS (
  SELECT 
    ResponseId,
    TRIM(SUBSTRING_INDEX(LearnCode, ';', 1)) AS method,
    SUBSTRING(LearnCode, LENGTH(SUBSTRING_INDEX(LearnCode, ';', 1)) + 2) AS remaining
  FROM survey_results_2024
  WHERE LearnCode IS NOT NULL AND LearnCode <> 'NA'

  UNION ALL

  SELECT 
    ResponseId,
    TRIM(SUBSTRING_INDEX(remaining, ';', 1)),
    SUBSTRING(remaining, LENGTH(SUBSTRING_INDEX(remaining, ';', 1)) + 2)
  FROM learn_split
  WHERE remaining != ''
)

-- Final aggregation by Age and Method
SELECT 
  method AS Learning_Method,
  COUNT(*) AS Respondent_Count, # Count per row/group
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ( ), 2) AS Percentage # # SUM(COUNT(*)) OVER (): gives total count across all groups
FROM learn_split
-- WHERE Age IS NOT NULL
GROUP BY method
ORDER BY Respondent_Count DESC;
-- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- | Age | LearnCode      | COUNT(*) | SUM(COUNT(*)) OVER (PARTITION BY Age) |
-- | --- | -------------- | --------- | -------------------------------------- |
-- | 25  | Online Courses | 100       | 200                                    |
-- | 25  | Books          | 60        | 200                                    |
-- | 25  | School         | 40        | 200                                    |
-- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------


-- How many years have developers been coding, both overall and professionally? ------------------------------------------------------------------------------------

-- Years of Overall Coding Experience
SELECT 
  YearsCode AS Experience_Overall,
  COUNT(*) AS Developer_Count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS Percentage
FROM survey_results_2024
WHERE YearsCode IS NOT NULL AND YearsCode <> 'NA'
GROUP BY YearsCode
ORDER BY LENGTH(YearsCode), YearsCode; # LENGTH(YearsCode) in ORDER BY to sort values like "5" before "10+".

SELECT 
	YearsCodePro AS Pro_Experience,
    count(*) AS  Developer_Count,
    Round(count(*)*100.0/ sum(count(*)) over (), 2) AS Percentage
    from survey_results_2024
    where YearsCodePro IS NOT NULL AND YearsCodePro <> 'NA'
    Group by YearsCodePro
    order by length(YearsCodePro), YearsCodePro;
    

-- What percentage of developers have more than 15 years of coding experience?---------------------------------------------------------------------------------------
SELECT 
  ROUND(
    COUNT(*) * 100.0 / 
    (SELECT COUNT(*) FROM survey_results_2024 
     WHERE YearsCode IS NOT NULL AND YearsCode <> 'NA'), 
  2) AS Percentage_More_Than_15
FROM survey_results_2024
WHERE 
  YearsCode IS NOT NULL 
  AND YearsCode <> 'NA'
  AND (
    -- Convert YearsCode to number when possible
    CAST(YearsCode AS UNSIGNED) > 15    -- Converts values like '16', '18', '20' into numbers. So if the converted number is greater than 15, it matches.
    OR YearsCode LIKE '%or more%' -- This condition matches any text that contains "or more".
  );
  
  
  
 --  What are top 5 popular languages used by people who are learning to code? --------------------------------------------------------------------------------------
WITH RECURSIVE lang_split AS (
  SELECT 
    ResponseId,
    TRIM(SUBSTRING_INDEX(LanguageHaveWorkedWith, ';', 1)) AS method,
    SUBSTRING(LanguageHaveWorkedWith, LENGTH(SUBSTRING_INDEX(LanguageHaveWorkedWith, ';', 1)) + 2) AS remaining
  FROM survey_results_2024
  WHERE LanguageHaveWorkedWith IS NOT NULL
    AND LanguageHaveWorkedWith <> 'NA'
    AND (MainBranch LIKE '%student%' OR MainBranch LIKE '%learning to code%')

  UNION ALL

  SELECT 
    ResponseId,
    TRIM(SUBSTRING_INDEX(remaining, ';', 1)),
    SUBSTRING(remaining, LENGTH(SUBSTRING_INDEX(remaining, ';', 1)) + 2)
  FROM lang_split
  WHERE remaining != ''
)
  -- Final aggregation by Age and Method
SELECT method,
count(*) AS user_count
from lang_split
group by method
order by user_count desc;


 -- top 3 most common IDEs used by professional developers? -------------------------------------------------------------------------------------------------------
With recursive tools_split AS(
SELECT 
    ResponseId,
    TRIM(SUBSTRING_INDEX(NEWCollabToolsHaveWorkedWith, ';', 1)) AS tools_tech,
    SUBSTRING(NEWCollabToolsHaveWorkedWith, LENGTH(SUBSTRING_INDEX(NEWCollabToolsHaveWorkedWith, ';', 1)) + 2) AS remaining
  FROM survey_results_2024
  WHERE NEWCollabToolsHaveWorkedWith IS NOT NULL
    AND NEWCollabToolsHaveWorkedWith <> 'NA'
    AND (MainBranch LIKE '%developer by profession%')

  UNION ALL

  SELECT 
    ResponseId,
    TRIM(SUBSTRING_INDEX(remaining, ';', 1)),
    SUBSTRING(remaining, LENGTH(SUBSTRING_INDEX(remaining, ';', 1)) + 2)
  FROM tools_split
  WHERE remaining != ''

)

SELECT tools_tech, 
count(*) AS user_count
from tools_split
group by tools_tech
order by user_count desc
limit 3;


-- What are the most commonly used operating systems by developers for personal and professional use?  
-- (mean, each typoe along with its percentage in personal and professional)---------------------------------------------------------------------------------------
-- Step 1: Split Personal Use OS column
WITH RECURSIVE personal_split AS (
  SELECT
    ResponseId,
    TRIM(SUBSTRING_INDEX(`OpSysPersonal use`, ';', 1)) AS Operating_System,
    SUBSTRING(`OpSysPersonal use`, LENGTH(SUBSTRING_INDEX(`OpSysPersonal use`, ';', 1)) + 2) AS remaining
  FROM survey_results_2024
  WHERE `OpSysPersonal use` IS NOT NULL AND `OpSysPersonal use` <> 'NA'

  UNION ALL

  SELECT
    ResponseId,
    TRIM(SUBSTRING_INDEX(remaining, ';', 1)),
    SUBSTRING(remaining, LENGTH(SUBSTRING_INDEX(remaining, ';', 1)) + 2)
  FROM personal_split
  WHERE remaining != ''
),
-- Step 2: Split Professional Use OS column
professional_split AS (
  SELECT
    ResponseId,
    TRIM(SUBSTRING_INDEX(`OpSysProfessional use`, ';', 1)) AS Operating_System,
    SUBSTRING(`OpSysProfessional use`, LENGTH(SUBSTRING_INDEX(`OpSysProfessional use`, ';', 1)) + 2) AS remaining
  FROM survey_results_2024
  WHERE `OpSysProfessional use` IS NOT NULL AND `OpSysProfessional use` <> 'NA'

  UNION ALL

  SELECT
    ResponseId,
    TRIM(SUBSTRING_INDEX(remaining, ';', 1)),
    SUBSTRING(remaining, LENGTH(SUBSTRING_INDEX(remaining, ';', 1)) + 2)
  FROM professional_split
  WHERE remaining != ''
),
-- Step 3: Count usage in each category
personal_os_counts AS (
  SELECT Operating_System, COUNT(*) AS personal_count
  FROM personal_split
  GROUP BY Operating_System
),
professional_os_counts AS (
  SELECT Operating_System, COUNT(*) AS professional_count
  FROM professional_split
  GROUP BY Operating_System
)
 -- Step 4: Final SELECT to join counts and calculate percentage
 
SELECT 
  COALESCE(p.Operating_System, pr.Operating_System) AS Operating_System,
  
  COALESCE(p.personal_count, 0) AS Personal_Users,
  ROUND(COALESCE(p.personal_count, 0) * 100.0 / (
    SELECT COUNT(*) FROM personal_split
  ), 2) AS Personal_Percent,

  COALESCE(pr.professional_count, 0) AS Professional_Users,
  ROUND(COALESCE(pr.professional_count, 0) * 100.0 / (
    SELECT COUNT(*) FROM professional_split
  ), 2) AS Professional_Percent

FROM personal_os_counts p
LEFT JOIN professional_os_counts pr 
  ON p.Operating_System = pr.Operating_System

UNION

SELECT 
  pr.Operating_System,
  COALESCE(p.personal_count, 0),
  ROUND(COALESCE(p.personal_count, 0) * 100.0 / (
    SELECT COUNT(*) FROM personal_split
  ), 2),
  pr.professional_count,
  ROUND(pr.professional_count * 100.0 / (
    SELECT COUNT(*) FROM professional_split
  ), 2)

FROM professional_os_counts pr
LEFT JOIN personal_os_counts p 
  ON p.Operating_System = pr.Operating_System

ORDER BY Professional_Users DESC, Personal_Users DESC;

-- NUMBER OF EMPLOYES IN ORGANIZATION IN WHICH PEOPLE WORK?----------------------------------------------------- --------------------------------------
SELECT OrgSize AS Organization_Size,
count(*) AS users,
round(count(*)*100.0 / (SELECT count(*) from survey_results_2024 where OrgSize IS NOT NULL AND OrgSize <> 'NA' ), 2) AS Percentage
from survey_results_2024
where  OrgSize IS NOT NULL AND OrgSize <> 'NA'
Group by OrgSize
order by users desc ;

-- EMPLOYMENT STATUS BY GEOGRAPHY? ---------------------------------------------------------------------------------------
SELECT 
  Country,
  Employment,
  COUNT(*) AS Respondent_Count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY Country), 2) AS Percentage
FROM survey_results_2024
WHERE Country IS NOT NULL AND Country <> 'NA'  AND Employment IS NOT NULL  AND Employment <> 'NA'
GROUP BY Country, Employment
ORDER BY Country, Respondent_Count DESC;

-------------------------------------------------------------------------------------------------------------------------------------


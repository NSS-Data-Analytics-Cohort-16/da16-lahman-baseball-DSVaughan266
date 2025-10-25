-- ## Lahman Baseball Database Exercise
-- - this data has been made available [online](http://www.seanlahman.com/baseball-archive/statistics/) by Sean Lahman
-- - A data dictionary is included with the files for this project.

-- **Directions:**  
-- * Within your repository, create a directory named "scripts" which will hold your scripts.
-- * Create a branch to hold your work.
-- * For each question, write a query to answer.
-- * Complete the initial ten questions before working on the open-ended ones.

-- **Initial Questions**

-- 1. What range of years for baseball games played does the provided database cover? 

SELECT 
	MIN(yearid) AS first_year,
	MAX(yearid) AS final_year
FROM teams
--ANSWER: 1871 to 2016


-- 2. Find the name and height of the shortest player in the database. How many games did he play in? What is the 
--	  name of the team for which he played?
--Need: namefirst, namelast, namegiven, MIN(height) from people
--		G_all, teamid from appearances	


SELECT 
	p.namefirst || ' ' || p.namelast AS fullname,
	MIN (p.height) AS shortest_player,
	app.G_all,
	teams.name
FROM people p
LEFT JOIN appearances app
USING (playerid)
LEFT JOIN teams 
USING (teamid)
GROUP BY fullname, app.G_all, teams.name
ORDER BY shortest_player ASC
LIMIT 1
--ANSWER: Eddie Gaedel, 43 inches, 1 game played, St. Louis Browns
-------------------------

SELECT
    p.namefirst AS first_name,
    p.namelast AS last_name,
    p.height,
    (
        SELECT a.g_all
        FROM appearances a
        WHERE a.playerid = p.playerid
    ) AS games_played,
    (
        SELECT a.teamid
        FROM appearances a
        WHERE a.playerid = p.playerid
    ) AS team
FROM people p
ORDER BY p.height ASC
LIMIT 1


-- 3. Find all players in the database who played at Vanderbilt University. Create a list showing each player’s 
--	  first and last names as well as the total salary they earned in the major leagues. Sort this list in 
--	  descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?
--NEED: p.namefirst, p.namelast, schoolname, total_salary_earned

SELECT
	p.namefirst AS first_name,
    p.namelast AS last_name,
	sch.schoolname AS university,
	CAST(SUM(sal.salary)::numeric AS money) AS total_salary_earned
FROM people p
LEFT JOIN collegeplaying
USING (playerid)
LEFT JOIN schools sch
USING (schoolid)
LEFT JOIN salaries sal
USING (playerid)
WHERE sch.schoolname iLIKE '%Vand%' 
GROUP BY p.namefirst, p.namelast, sch.schoolname
ORDER BY total_salary_earned DESC

--------------------------------------------

SELECT
	p.namefirst AS first_name,
	p.namelast AS last_name,
	CAST(s.total_salary :: numeric AS money) AS total_salary_earned
FROM people p
JOIN (
	SELECT 
		playerid
		FROM collegeplaying cp
		JOIN schools sch
		USING (schoolid)
		WHERE sch.schoolname ILIKE '%Vand%'
) AS vandy_players
ON p.playerid = vandy_players.playerid
JOIN (
	SELECT 
	playerid,
	SUM(salary) AS total_salary
	FROM salaries
	GROUP BY playerid
) AS s
ON p.playerid = s.playerid
GROUP BY p.playerid, s.total_salary
ORDER BY total_salary_earned DESC;
--ANSWER:  David Price, $24,553,888.00

-- 4. Using the fielding table, group players into three groups based on their position: label players with position 
--	  OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or 
--	  "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.
--NEED: 

WITH position_lookup AS (
	SELECT DISTINCT
		pos,
		CASE 						--group the specific positions into general categories
			WHEN pos = 'OF' THEN 'Outfield'
			WHEN pos = 'SS' THEN 'Infield'
			WHEN pos = '1B' THEN 'Infield'
			WHEN pos = '2B' THEN 'Infield'
			WHEN pos = '3B' THEN 'Infield'
			WHEN pos = 'P' THEN 'Battery'
			WHEN pos = 'C' THEN 'Battery'
			ELSE 'Other'
		END AS position_group
	FROM fielding 
)
SELECT 
	p1.position_group,
	SUM(f.po) AS total_putouts		--select the position categories and the sum of putouts
FROM fielding f
INNER JOIN position_lookup p1				--join to the CTE
USING (pos)
WHERE f.yearid = 2016				--filter for year
GROUP BY p1.position_group
ORDER BY total_putouts DESC;
--ANSWER: Outfield 810,809,040
--		  Infield  785,600,481
--		  Battery  540,825,390

----------------------------------

SELECT
	CASE							--group positions into categories
		WHEN pos = 'OF' THEN 'Outfield'
			WHEN pos = 'SS' THEN 'Infield'
			WHEN pos = '1B' THEN 'Infield'
			WHEN pos = '2B' THEN 'Infield'
			WHEN pos = '3B' THEN 'Infield'
			WHEN pos = 'P' THEN 'Battery'
			WHEN pos = 'C' THEN 'Battery'
			ELSE 'Other'
		END AS position_group,
	SUM(po) AS total_put_outs		--Sum the put outs
FROM fielding 
WHERE yearid = 2016					--filter for year
GROUP BY position_group
ORDER BY total_put_outs DESC;
--ANSWER: Infield  58,934
--		  Outfield 41,424
--		  Battery  29,560
----------------------------------

SELECT pos, COUNT(pos)
FROM fielding
GROUP BY pos


-- 5. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal 
--	  places. Do the same for home runs per game. Do you see any trends?
--NEED: SUM(so)/games, games by decade, SUM(hr)/games
--teams table
--sum of strikeout divided by games

SELECT
	yearid/10*10 AS decade,
	ROUND(SUM(so) :: numeric/SUM(g) :: numeric, 2) AS so_per_game,
	ROUND(SUM(hr) :: numeric/SUM(g) :: numeric, 2) AS hr_per_game
FROM teams
WHERE yearid >= 1920
GROUP BY decade
ORDER BY decade;
--TREND: Big hitters in 2000s?


-- 6. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage 
--	  of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being 
--    caught stealing.) Consider only players who attempted _at least_ 20 stolen bases.
--NEED: playerid, player name, sb/(sb+cs)*100 WHERE (sb+cs)>=20

SELECT						--2. create a table with aggregates from the subquery table
	p.namefirst AS first_name,
	p.namelast AS last_name,
	yearid,
	total_sb,
	total_cs,
	sb_attempts,
	ROUND((total_sb :: numeric / sb_attempts), 2) * 100 AS sb_percentage
FROM (
	SELECT					--1. create a table calculating sb_attempts
		playerid,
		yearid,
		SUM(sb) AS total_sb,
		SUM(cs) AS total_cs,
		SUM(sb + cs) AS sb_attempts
	FROM batting
	WHERE yearid = 2016		--3. filter by year
	GROUP BY playerid, yearid
) AS sb_table
JOIN people p
USING (playerid)
WHERE sb_attempts >= 20		--4. filter by attempts
ORDER BY sb_percentage DESC;
--ANSWER: Chris Owings 91%


---
SELECT *				--investigating data
FROM batting 
WHERE yearid = 2016

--------------------
SELECT 					--building the subquery
	playerid,
	yearid,
	SUM (sb) AS total_sb,
	SUM (cs) AS total_cs,
	SUM(sb + cs) AS sb_attempts
FROM batting
WHERE yearid = 2016
	AND (sb + cs) >= 20
GROUP BY playerid, yearid, sb, cs


-- 7.  From 1970 – 2016, what is the largest number of wins for a team that did not win the world series? What is the 
--	   smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually 
--	   small number of wins for a world series champion – determine why this is the case. Then redo your query, excluding 
--	   the problem year. How often from 1970 – 2016 was it the case that a team with the most wins also won the world 
--	   series? What percentage of the time?

WITH most_wins AS (
	SELECT			--this is a two column table that is returning the max win count per year
		yearid,
		MAX(w) AS w
	FROM teams
	WHERE yearid >= 1970
	GROUP BY yearid
	ORDER BY yearid
	),
most_win_teams AS (
	SELECT 			--limit teams to only the ones that have the highest win total per year
		yearid,
		name,
		wswin
	FROM teams
	INNER JOIN most_wins
	USING(yearid, w)
)
SELECT 
	(SELECT COUNT(*)
	 FROM most_win_teams
	 WHERE wswin = 'N'
	) * 100.0 /
	(SELECT COUNT(*)
	 FROM most_win_teams
	);

SELECT
	yearid,
	SUM(g)
FROM teams
GROUP BY 1
ORDER BY 1

-- 8. Using the attendance figures from the homegames table, find the teams and parks which had the top 5 average 
--	  attendance per game in 2016 (where average attendance is defined as total attendance divided by number of games). 
--	  Only consider parks where there were at least 10 games played. Report the park name, team name, and average 
--	  attendance. Repeat for the lowest 5 average attendance.
--NEED: SUM(attendance)/COUNT(games)


-- 9. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American 
--	  League (AL)? Give their full name and the teams that they were managing when they won the award.

-- 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played 
--	   in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and 
--	   last names and the number of home runs they hit in 2016.


-- **Open-ended questions**

-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this 
--	   question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, 
--	   so you may want to look on a year-by-year basis.

-- 12. In this question, you will explore the connection between number of wins and attendance.
--   *  Does there appear to be any correlation between attendance at home games and number of wins? </li>
--   *  Do teams that win the world series see a boost in attendance the following year? What about teams that made 
--		the playoffs? Making the playoffs means either being a division winner or a wild card winner.

-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they 
--	   are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, 
--	   determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers 
--	   more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?

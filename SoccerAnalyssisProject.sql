
UPDATE appearances
SET date = DATEADD(day, ABS(CHECKSUM(NEWID())) % (DATEDIFF(day, '20230101', GETDATE()) + 1), '20230101')
WHERE date IS NULL;


--Query that shows the player name,the highet value and the current value
select name,market_value_in_eur,highest_market_value_in_eur
from players
order by name

-- Query that shows the Club name, AVG players market value by club,
--AVG players market value by position, Player name, Player market value, more or less from AVG by club

select p.name,format(p.market_value_in_eur,'N0') as 'Player value',
	FORMAT(round(avg(p.market_value_in_eur) OVER(partition by c.name),2),'N0') as 'Avg Value in club',
	p.Position,
	FORMAT(round(avg(p.market_value_in_eur) OVER(partition by  p.Position),2), 'N0') as 'Avg value by position',
	c.name as ' Club name',
       CASE 
         WHEN p.market_value_in_eur > AVG(p.market_value_in_eur) OVER(PARTITION BY c.name) THEN 'above avg' 
         ELSE 'below avg' 
		 END AS 'Value compared to club average'
		
from clubs as c inner join players as p on c.club_id = p.current_club_id
order by p.name


--query that shows games and them fans amount,result and teams
select  games.club_home_name, games.club_away_name,games.attendance,year(games.date) as ' Season',
		CONCAT(games.home_club_goals, '-', games.away_club_goals) as 'Result'
from games inner join clubs as c on c.club_id = games.away_club_id
				inner join clubs as c1 on c1.club_id = games.home_club_id
order by games.attendance desc


--Query that shows the player name with goals and games number, Season, goals number by club and Club name
select Players.[Player name],Players.goals_number,Players.games_num,Players.season,
		Clubs.[goals number by club],Clubs.name
from(
		select case when a.player_name is null Then 'no name'
		else a.player_name END as 'Player name',a.player_club_id,
		g.season,
		round(SUM(a.minutes_played)/90,0) as 'games_num',
		sum(a.goals) as 'goals_number'

		from games as g inner join appearances as a on g.game_id = a.game_id
		group by a.player_name,g.season,a.player_club_id
		
		) as Players
inner join

		(select  c.club_id,c.name, year(a.date)as 'Season', sum(a.goals) as 'goals number by club'
		from clubs as c inner join appearances as a on c.club_id = a.player_club_id
		group by  c.club_id,c.name, year(a.date) 
		) as Clubs
		on Players.player_club_id = Clubs.club_id and Clubs.Season = Players.season 
order by Players.goals_number desc




-- query that shows the goals amount by team and player, Club name, Player name, Season.
 select*
 from(
		select a.player_club_id, p.name,YEAR(a.date) 'Season', sum(a.goals) as 'Goals_number'
		from players as p inner join appearances as a on p.player_id = a.player_id
		group by  a.player_club_id, p.name , YEAR(a.date) )as Player_goals
inner join
		(select c.club_id, c.name as 'club_name'
		 from clubs as c) as club

		 on Player_goals.player_club_id = club.club_id
order by Player_goals.Goals_number desc, Player_goals.name ,Player_goals.Season





 --shows the game details, how many fans, clubs name, season and result.
select  games.club_home_name, games.club_away_name,games.attendance,year(games.date) as ' Season',
		CONCAT(games.home_club_goals, '-', games.away_club_goals) as 'Result',
		rank() OVER(order by games.attendance desc ) as 'rank'
from games inner join clubs as c on c.club_id = games.away_club_id
				inner join clubs as c1 on c1.club_id = games.home_club_id



-- How many players in each country by position
SELECT *
FROM (
  SELECT p.player_id,p.position,c.country_name
  FROM competitions AS c 
  INNER JOIN players AS p ON c.competition_id = p.current_club_domestic_competition_id
) AS s
PIVOT (
  COUNT(s.player_id) FOR position IN (Attack,Goalkeeper,Defender,Midfield)
) AS p




--Top 5 players most good player by goals, ratio goals games and assist
select*
from(

 select		Player_goals.name, Player_goals.Goals_number, Player_goals.games_played,
			Case WHEN Player_goals.games_played > 0 THEN Player_goals.Goals_number/Player_goals.games_played
			ELSE null END as 'ratioGoals/Games',
			Player_goals.Assist_number,FORMAT(Player_goals.market_value,'N0') as 'market_value', club.club_name,
			ROW_NUMBER() OVER(order by Player_goals.Goals_number desc ) as 'ranking'

 from(
		select a.player_club_id, p.name,YEAR(a.date) 'Season', sum(a.goals) as 'Goals_number',
		sum(a.assists) as 'Assist_number',round(SUM(a.minutes_played)/90,0) as 'games_played',
		sum(p.market_value_in_eur) as 'market_value'
		from players as p inner join appearances as a on p.player_id = a.player_id
		group by  a.player_club_id, p.name , YEAR(a.date)
															) as Player_goals
		inner join

		(select c.club_id, c.name as 'club_name'
		 from clubs as c) as club
			 on Player_goals.player_club_id = club.club_id) as top_attack_player

where top_attack_player.ranking <6 


-- count how many goals scored in the first half and how mant in the second.
--order by goals number in the first half desc.
SELECT *
FROM (	select CASE WHEN ge.minute <46 THEN 'First-Half'
					WHEN ge.minute >45 THEN 'Second-Half'
					end as 'goal_event',c.name,c.club_id
				
	from (clubs as c join game_events as ge on c.club_id = ge.club_id)
			join games as g on ge.game_id = g.game_id
	where ge.type like 'Goals' and year(g.date) = year(getdate()) ) AS s
PIVOT (
  COUNT(s.club_id) FOR s.goal_event IN ([First-Half],[Second-Half])
) AS p
order by [First-Half] desc



--shows the Final game in champions league competition and who won the cup.
WITH CHAMPIONS_LEAGUE_WINNERS (club_home_name, club_away_name, Fans, Result, Winner, Season )
as(
select  g.club_home_name, g.club_away_name,g.attendance,
		CONCAT(g.home_club_goals, '-', g.away_club_goals) as 'Result',
		IIF(g.home_club_goals > g.away_club_goals ,g.club_home_name,g.club_away_name) as 'Winner',
		year(g.date) as 'Season'
from competitions as c join games as g on c.competition_id = g.competition_id
where c.name like 'Uefa Champions League' and g.round like 'Final')

select*
from CHAMPIONS_LEAGUE_WINNERS



-- shows the statistics player. player name, goals,games played,ratio goals/games,
--- assist,market value,club name,rank by goals
WITH t1 as(

			 select a.player_club_id, p.name,YEAR(a.date) 'Season', sum(a.goals) as 'Goals_number',
				sum(a.assists) as 'Assist_number',round(SUM(a.minutes_played)/90,0) as 'games_played',
				sum(p.market_value_in_eur) as 'market_value'
			 from players as p inner join appearances as a on p.player_id = a.player_id
			 where year(a.date) = year(getdate())
			 group by  a.player_club_id, p.name , YEAR(a.date)),

	 t2 as(	select  c.name as 'club_name',t1.*
			from clubs as c join t1 on c.club_id = t1.player_club_id),

PLAYERS_STATISTICS as(  select t2.name, t2.Goals_number, t2.games_played,
								Case WHEN t2.games_played > 0 THEN t2.Goals_number/t2.games_played
								ELSE null END as 'ratioGoals/Games',
								t2.Assist_number,FORMAT(t2.market_value,'N0') as 'market_value', t2.club_name,
								ROW_NUMBER() OVER(order by t2.Goals_number desc) as 'ranking'
						from t2)

	select*
	from PLAYERS_STATISTICS
	--where PLAYERS_STATISTICS.ranking <11 


--top scorer in all comptitiones ( league & cups and global comptitiones )
WITH top_scorer(year,Player_name,Goals,rank)
AS(
	select
		YEAR(a.date) AS year,
		p.name,
		SUM(a.goals) AS goals,
		ROW_NUMBER() OVER (PARTITION BY YEAR(a.date) ORDER BY SUM(a.goals) DESC) as rating

	from players p JOIN appearances a ON p.player_id = a.player_id
	group by YEAR(a.date), p.name)

select
	MAX(top_scorer.goals) as 'Goals',
	top_scorer.Player_name,
	top_scorer.year
from top_scorer
where top_scorer.rank = 1
group by top_scorer.year, top_scorer.Player_name
order by top_scorer.year DESC



-- query that show the Player name, Goals amount, Year-season, Country name of league, league name
--and provide the top scorer player in the year 

WITH top_scorer (year,Player_name,Goals,rank,ID,ID_countryLeague)
			AS(
				    select
					YEAR(a.date) AS year,
					p.name,
					SUM(a.goals) AS goals,
					ROW_NUMBER() OVER (PARTITION BY YEAR(a.date) ORDER BY SUM(a.goals) DESC) as rating,
					p.player_id,
					a.competition_id

				 from players p inner join appearances a ON p.player_id = a.player_id
				 group by  YEAR(a.date), p.name,p.player_id,a.competition_id),

		COUNTRY_DETAILS(country_name,leage_name,ID) as (
				 select c.country_name,c.name,c.competition_id
				 from top_scorer inner join competitions as c
						on top_scorer.ID_countryLeague = c.competition_id),

		TOP_SCORER_BY_YEAR as(
				 select 
				 distinct top_scorer.Player_name,
				 MAX(top_scorer.goals) over(partition by top_scorer.year) as 'Goals',
				 top_scorer.year,COUNTRY_DETAILS.country_name,COUNTRY_DETAILS.leage_name
				 from top_scorer  inner join COUNTRY_DETAILS on top_scorer.ID_countryLeague = COUNTRY_DETAILS.ID
				 where top_scorer.rank = 1)


select* from TOP_SCORER_BY_YEAR
ORDER BY TOP_SCORER_BY_YEAR.year DESC	



--Number of players in each country and number of players that they market value is greater than the AVG
SELECT s.country_name, count(s.name) 'Players_num_above_AVG', s.Total_player_num
FROM (
  SELECT c.country_name, AVG(p.market_value_in_eur) OVER(partition by c.country_name)as 'AVG_Value_In_Country',
		count(p.name)OVER(partition by c.country_name) as 'Total_player_num', p.name,p.market_value_in_eur
  FROM competitions as c inner join players as p on c.competition_id = p.current_club_domestic_competition_id
) as s
where s.AVG_Value_In_Country < s.market_value_in_eur
group by s.country_name,s.Total_player_num
order by Players_num_above_AVG 




-- query that shows the goals and assist and played games in current year and last year
select t1.name as 'Player_name', t1.Goals_number,t1.Assist_number,t1.games_played
,t2.goals_last_year,t2.assist_last_year,t2.games_played_last_year,t1.market_value
from(
select p.name,YEAR(a.date) 'Season', sum(a.goals) as 'Goals_number',
	sum(a.assists) as 'Assist_number',round(SUM(a.minutes_played)/90,0) as 'games_played',
	sum(p.market_value_in_eur) as 'market_value',p.player_id
from players as p inner join appearances as a on p.player_id = a.player_id
where year(a.date) = year(getdate())
group by  p.player_id , p.name, p.player_id, YEAR(a.date)) as t1

inner join

(select p.player_id,sum(a.goals) as 'goals_last_year', sum(a.assists) as 'assist_last_year',
	round(SUM(a.minutes_played)/90,0) as 'games_played_last_year'
from players as p inner join appearances as a on p.player_id = a.player_id
where year(a.date) = DATEPART(year, DATEADD(year, -1, GETDATE()))

group by p.player_id) as t2
on t1.player_id = t2.player_id
order by t1.Goals_number desc,t2.goals_last_year

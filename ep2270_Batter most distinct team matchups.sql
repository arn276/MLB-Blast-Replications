with
playerGameLists as (
	select batterid as playerid, visitingteam, left(gameid,3) as hometeam,gameid
	from mlb.playlogs.plays
	where battereventflag != 'F' --ensure completed plate appearance

	union 
	
	select pitcherid as playerid, visitingteam, left(gameid,3) as hometeam,gameid
	from mlb.playlogs.plays
),

adjustTeamNameChanges as(
	/* Pulling game fields and adjusting teams that rebranded in same location */
	select playerid,
		case
		when visitingteam in ('LAA','CAL','ANA') then 'ANA'
		when visitingteam in ('FLO','MIA') then 'MIA'
		when visitingteam in ('WS1','WS2') then 'WS2'
		else visitingteam
		end as visitingteam,
		case
		when hometeam in ('LAA','CAL','ANA') then 'ANA'
		when hometeam in ('FLO','MIA') then 'MIA'
		when hometeam in ('WS1','WS2') then 'WS2'
		else hometeam
		end as hometeam
		
	from playerGameLists
	where  
	 -- confirm in regular season
	 TO_DATE(left(right(gameid,9),8),'YYYYMMDD') in (select distinct game_date from mlb.gamelogs.games)
),

uniqueMatchups as (
	/* 
		Finding unique matchups independent of game location
		e.g. Miami at St.Louis is the same as St. Louis at Miami
	*/
	select distinct playerid, 
					case
					when visitingteam < hometeam then visitingteam || hometeam
					else hometeam || visitingteam
					end as teamMatchups
					
	-- finding unique matchups, location dependent
	-- select distinct playerid, visitingteam||hometeam as teamMatchups
	
	from adjustTeamNameChanges 
),

playerDetails as (
	/* Getting player name and career span*/
	select distinct playerid, firstname||' '||lastname as playerName, 
		min(year) as careerStart,
		max(year) as careerEnd
	from mlb.rosters.rosters  
	group by playerid, firstname||' '||lastname
)

/* Top 50 players with the most unique team matchups */
Select playerName, playerDetails.playerid, 
	count(teamMatchups) as uniqueTeamPairings, careerStart, careerEnd
from uniqueMatchups
left join playerDetails on uniqueMatchups.playerid = playerDetails.playerid
group by playerName, playerDetails.playerid,careerStart, careerEnd
order by count(teamMatchups) desc
limit 50


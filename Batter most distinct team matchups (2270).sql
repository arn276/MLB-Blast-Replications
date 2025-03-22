with
adjustTeamNameChanges as(
	/* Pulling game fields and adjusting teams that rebranded in same location */
	select batterid,
		case
		when visitingteam in ('LAA','CAL','ANA') then 'ANA'
		when visitingteam in ('FLO','MIA') then 'MIA'
		when visitingteam in ('WS1','WS2') then 'WS2'
		else visitingteam
		end as visitingteam,
		case
		when left(gameid,3) in ('LAA','CAL','ANA') then 'ANA'
		when left(gameid,3) in ('FLO','MIA') then 'MIA'
		when left(gameid,3) in ('WS1','WS2') then 'WS2'
		else left(gameid,3)
		end as hometeam
	from mlb.playlogs.plays
),

uniqueMatchups as (
	/* 
		Finding unique matchups independent of game location
		e.g. Miami at St.Louis is the same as St. Louis at Miami
	*/
	select distinct batterid, 
					case
					when visitingteam < hometeam then visitingteam || hometeam
					else hometeam || visitingteam
					end as teamMatchups
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

/* Top 50 batters with the most unique team matchups */
Select playerName,playerid, count(teamMatchups) as uniqueTeamPairings, careerStart, careerEnd
from uniqueMatchups
left join playerDetails on uniqueMatchups.batterid = playerDetails.playerid
group by playerName, playerid,careerStart, careerEnd
order by count(teamMatchups) desc
limit 50


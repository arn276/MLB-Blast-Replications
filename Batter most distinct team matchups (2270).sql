with
uniqueMatchups as (
	select distinct batterid, --gameid,
					visitingteam ||'-'|| left(gameid,3)as teamMatchups
					-- case
					-- when visitingteam < left(gameid,3) then visitingteam || left(gameid,3)
					-- else left(gameid,3) || visitingteam
					-- end as teamMatchups
	from mlb.playlogs.plays 
	--where batterid = 'aaroh101'
),

playerDetails as (select distinct playerid, firstname||' '||lastname as playerName, 
					min(year) as careerStart,
					max(year) as careerEnd
				 from mlb.rosters.rosters  
				 group by playerid, firstname||' '||lastname
)

Select playerName, count(teamMatchups) as uniqueTeamPairings, careerStart, careerEnd
from uniqueMatchups
left join playerDetails on uniqueMatchups.batterid = playerDetails.playerid
group by playerName, careerStart, careerEnd
order by count(teamMatchups) desc
limit 50

with fullRosters as (
	select playerid,case
		when team in ('LAA','CAL','ANA') then 'ANA'
		when team in ('FLO','MIA') then 'MIA'
		when team in ('MON','WAS') then 'WAS'
		when team in ('BRO','LAN') then 'LAN'
		when team in ('NY1','SFN') then 'SFN'
		when team in ('SLA','SE1','MIL') then 'MIL'
		when team in ('BSN','MLN','ATL') then 'ATL'
		when team in ('PHA','KC1','OAK') then 'OAK'
		when team in ('WS1','WS2','MIN') then 'MIN'
		else team
		end as team, year 
	from rosters.rosters
),

oneNdone_bat as (
	select r.playerid, lastname, firstname, 
		y.team, 
		count(r.year)
	FROM rosters.rosters as r
	left join fullRosters as y on r.playerid=y.playerid and case
															when r.team in ('LAA','CAL','ANA') then 'ANA'
															when r.team in ('FLO','MIA') then 'MIA'
															when r.team in ('MON','WAS') then 'WAS'
															when r.team in ('BRO','LAN') then 'LAN'
															when r.team in ('NY1','SFN') then 'SFN'
															when r.team in ('SLA','SE1','MIL') then 'MIL'
															when r.team in ('BSN','MLN','ATL') then 'ATL'
															when r.team in ('PHA','KC1','OAK') then 'OAK'
															when r.team in ('WS1','WS2','MIN') then 'MIN'
															else r.team
															end = y.team
	where 1=1 
		-- and playerpos != 'P'
		and r.team not in ('BLF','BRF','SLF','PTF')
		and firstname||lastname != 'DanVogelbach'
		-- and r.playerid in ('glaut001')
	group by r.playerid, lastname, firstname, y.team
	having count(r.year) = 1
),

addYr as (
	select oneNdone_bat.*, fullRosters.year as yr, oneNdone_bat.playerid||oneNdone_bat.team as pKey
	from oneNdone_bat
	left join fullRosters on oneNdone_bat.playerid = fullRosters.playerid and oneNdone_bat.team = fullRosters.team
),

batterGames as (
	select batterid, runnerid1st,runnerid2nd,runnerid3rd, cast(right(left(gameid,7),4) as int) as yr, 
		case when abflag = 'T' then 1 else 0 end as ab,
		case when eventtype in (20,21,22,23) then hitvalue else 0 end as tb,
		case when hitvalue != 0 then 1 else 0 end as h,
		case when eventtype = 14 then 1 else 0 end as bb,
		case when eventtype = 15 then 1 else 0 end as ibb,
		case when eventtype = 16 then 1 else 0 end as hbp,
		case when eventcode like '%GDP%' then 1 else 0 end as gdp,
		case when shflag = 'T' then 1 else 0 end as sh,
		case when sfflag = 'T' then 1 else 0 end as sf,
	
		eventtype,eventcode,abflag, hitvalue, batterdest, shflag, sfflag
	FROM playlogs.plays, addYr
	where batterid||case when battingteam = 0 then visitingteam else left(gameid,3) end in (addYr.pKey) 
),

batterTot as (
	SELECT batterid,  yr, sum(ab) as ab,   --count(abflag) as ab,
			sum(h) as h, sum(tb) as tb, sum(bb) as bb, sum(ibb) as ibb,
			sum(hbp) as hbp, sum(gdp) as gdp, sum(sh) as sh, sum(sf) as sf
		FROM batterGames
		-- where abflag = 'T'
		group by batterid, yr
),

runnerGames as (
	select runnerid1st,runnerid2nd,runnerid3rd, cast(right(left(gameid,7),4) as int) as yr, 
		runnerid1st||case when battingteam = 0 then visitingteam else left(gameid,3) end as runnerid1stKey,
		runnerid2nd||case when battingteam = 0 then visitingteam else left(gameid,3) end as runnerid2ndKey,
		runnerid3rd||case when battingteam = 0 then visitingteam else left(gameid,3) end as runnerid3rdKey,
			eventcode, eventType
	FROM playlogs.plays
	where eventcode like '%SB%' or eventcode like '%CS%'
),

stolenBase as (
	select runnerid1st as runnerid,  r.yr, count(runnerid1st) as sb
	from runnerGames as r, addYr
	where eventcode like '%SB2%'
		and runnerid1stKey in (addYr.pKey)
	group by runnerid1st, r.yr
	
	union all
	
	select runnerid2nd as runnerid, r.yr, count(runnerid2nd) as sb
	from runnerGames as r, addYr
	where eventcode like '%SB3%'
		and runnerid2ndKey in (addYr.pKey)
	group by runnerid2nd, r.yr
	
	union all
	
	select runnerid3rd as runnerid, r.yr, count(runnerid3rd) as sb
	from runnerGames as r, addYr
	where eventcode like '%SBH%'
		and runnerid3rdKey in (addYr.pKey)
	group by runnerid3rd, r.yr
),

stolenBaseTot as (
	select runnerid, yr, sum(sb) as sb
	from stolenBase
	group by runnerid, yr
),

caughtStealing as (
	select runnerid1st as runnerid, r.yr, count(runnerid1st) as cs
	from runnerGames as r, addYr
	where eventcode like '%CS2%'
		and runnerid1stKey in (addYr.pKey)
	group by runnerid1st, r.yr
	
	union all
	
	select runnerid2nd as runnerid, r.yr, count(runnerid2nd) as cs
	from runnerGames as r, addYr
	where eventcode like '%CS3%'
		and runnerid2ndKey in (addYr.pKey)
	group by runnerid2nd, r.yr
	
	union all
	
	select runnerid3rd as runnerid, r.yr, count(runnerid3rd) as cs
	from runnerGames as r, addYr
	where eventcode like '%CSH%'
		and runnerid3rdKey in (addYr.pKey)
	group by runnerid3rd, r.yr
),

caughtStealingTot as (
	select runnerid, yr, sum(cs) as cs
	from caughtStealing
	group by runnerid, yr
),

zeros as (
	select batterTot.batterid, batterTot.yr, sh, sf,
	coalesce(ab,0) as ab, coalesce(h,0) as h,coalesce(tb,0) as tb,
	coalesce(bb,0) as bb, coalesce(ibb,0) as ibb,coalesce(hbp,0) as hbp,
	coalesce(gdp,0) as gdp,coalesce(sb,0) as sb,coalesce(cs,0) as cs
	
	from batterTot
	left join stolenBaseTot on  batterTot.batterid = stolenBaseTot.runnerid and batterTot.yr = stolenBaseTot.yr
	left join caughtStealingTot on  batterTot.batterid = caughtStealingTot.runnerid and batterTot.yr = caughtStealingTot.yr
),

calculate as (
	select batterid, lastname, firstname, team, zeros.yr, 
		-- Runs Created (Stolen Base Method)
		-- ((Hits + Walks – Caught Stealing) x (Total Bases + (0.55 x Stolen Bases))) ÷ (AB + Walks)
		((h+(bb+ibb)-cs)*(tb+(0.55*sb)))/(ab+(bb+ibb)) as RC_SBmethod,
	
		-- Runs Created (Technical Method) 
		---- ((Hits + Walks – Caught Stealing + Hit by Pitch – Ground into Double Play) 
		-- x (Total Bases + (0.26 x (Walks – Intentional Walks + Hit by Pitch))
		-- + (0.52 x (Sacrifice Hits + Sacrifice Flies + Stolen Bases)))) 
		-- ÷ (At Bats + Walks + Hit by Pitch + Sacrifice Hits + Sacrifice Flies)
		((h+bb-cs+hbp-gdp)*(tb+(0.26*(bb-ibb+hbp))+(0.52*(sh+sf+sb))))/(ab+bb+hbp+sh+sf) as RCtechnical
	from zeros
	left join addYr on zeros.yr = addYr.yr and zeros.batterid = addYr.playerid
	where addYr.team is not null and ab > 0
),

rankResults as (
	select batterid, lastname, firstname, team, yr,
		RC_SBmethod,
		rank() over (partition by team order by RC_SBmethod desc ) as RC_SB_Rank,
		RCtechnical,
		rank() over (partition by team order by RCtechnical desc ) as RC_tech_Rank
	from calculate
)

Select batterid, lastname, firstname, team, yr, 
	-- RC_SBmethod, RC_SB_Rank,
	RCtechnical, RC_tech_Rank
from rankResults
where RC_tech_Rank = 1





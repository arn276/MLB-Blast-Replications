With 
batterStats as (
	select batterid,  cast(right(left(gameid,7),4) as int) as yr, 
		case when abflag = 'T' then 1 else 0 end as ab,
		case when battereventflag = 'T' then 1 else 0 end as pa,
		case when eventtype in (20,21,22,23) then hitvalue else 0 end as tb,
		case when eventtype = 20 then 1 else 0 end as h_1b,
		case when eventtype = 21 then 1 else 0 end as h_2b,
		case when eventtype = 22 then 1 else 0 end as h_3b,
		case when eventtype = 23 then 1 else 0 end as h_HR,
	
		
		case when eventtype = 14 then 1 else 0 end as bb,
		case when eventtype = 15 then 1 else 0 end as ibb,
		case when eventtype = 16 then 1 else 0 end as hbp,
		case when eventcode like '%GDP%' then 1 else 0 end as gdp,
		case when outs < 2 and runnerid1st != '' and abflag = 'T' then 1 else 0 end as gdpo,
		case when shflag = 'T' then 1 else 0 end as sh,
		case when sfflag = 'T' then 1 else 0 end as sf,
	
		eventtype,eventcode,abflag, hitvalue, batterdest, shflag, sfflag
	FROM playlogs.plays
	where cast(right(left(gameid,7),4) as int) = 2021
),

leagueTotals as (
	select distinct yr,
		cast(sum(gdp)over(partition by yr) as float) as lgGDP,
		cast(sum(gdpo)over(partition by yr) as float) as lgGDPo
	from batterStats
),

lgRPO_calc as (
	SELECT extract(year from game_date) as year, cast(sum(roadscore) + sum(homescore) as float)/ cast(sum(length_of_game_outs)as float) as lgRPO
	FROM gamelogs.games
	group by extract(year from game_date)
),

wRAA_calc as (
	select batterid, 
	-- sum(ab) as ab, sum(bb) as bb, sum(hbp) as hbp, sum(sh) as sacH, sum(sf) as sacF,
	-- sum(h_1b) as single, sum(h_2b) as double, sum(h_3b) as triple, sum(h_HR) as hr,
	(((
		((wbb * sum(bb)) + (whbp * sum(hbp)) +
		(w1b * sum(h_1b)) + (w2b * sum(h_2b)) + (w3b * sum(h_3b)) + (whr * sum(h_HR) ))
			/
		(sum(ab) + sum(bb) + sum(hbp) + sum(sh) + sum(sf))
	)-woba)/wobascale)*sum(pa) as wRAA
	from batterStats
	left join constants.woba_fip as woba on batterStats.yr = woba.season
	group by batterid, wbb, whbp, w1b, w2b, w3b, whr, woba, wobascale
),

wGDPcalc as (
	select batterid,batterStats.yr,
		(((lgGDP/lgGDPo) * cast(sum(gdpo)as float)) - cast(sum(gdp)as float)) * lgRPO as wGDP
	from batterStats
	left join leagueTotals on batterStats.yr=leagueTotals.yr
	left join lgRPO_calc on batterStats.yr=lgRPO_calc.year
	group by batterid, batterStats.yr, lgGDP,lgGDPo,lgRPO
),





runnerGames as (
	select runnerid1st,runnerid2nd,runnerid3rd, cast(right(left(gameid,7),4) as int) as yr, 
			eventcode, eventType
	FROM playlogs.plays
	where eventcode like '%SB%' or eventcode like '%CS%'
),

stolenBase as (
	select runnerid1st as runnerid,  yr, count(runnerid1st) as sb
	from runnerGames
	where eventcode like '%SB2%'
	group by runnerid1st, yr
	
	union all
	
	select runnerid2nd as runnerid, yr, count(runnerid2nd) as sb
	from runnerGames 
	where eventcode like '%SB3%'
	group by runnerid2nd, yr
	
	union all
	
	select runnerid3rd as runnerid, yr, count(runnerid3rd) as sb
	from runnerGames 
	where eventcode like '%SBH%'
	group by runnerid3rd, yr
),

stolenBasePlayerTot as (
	select runnerid, yr, cast(sum(sb) as float) as sb
	from stolenBase
	group by runnerid, yr
),

stolenBaseTeamTot as (
	select  yr, cast(sum(sb) as float) as sb
	from stolenBase
	group by  yr
),

caughtStealing as (
	select runnerid1st as runnerid, yr, count(runnerid1st) as cs
	from runnerGames 
	where eventcode like '%CS2%'
	group by runnerid1st, yr
	
	union all
	
	select runnerid2nd as runnerid, yr, count(runnerid2nd) as cs
	from runnerGames 
	where eventcode like '%CS3%'
	group by runnerid2nd, yr
	
	union all
	
	select runnerid3rd as runnerid, yr, count(runnerid3rd) as cs
	from runnerGames 
	where eventcode like '%CSH%'
	group by runnerid3rd, yr
),

caughtStealingPlayerTot as (
	select runnerid, yr, cast(sum(cs) as float) as cs
	from caughtStealing
	group by runnerid, yr
),

caughtStealingTeamTot as (
	select  yr, cast(sum(cs) as float) as cs
	from caughtStealing
	group by  yr
),

lgqsbCalc as (
	select distinct batterStats.yr,
			(((sb * runsb) + (cs * runcs))
				/
			cast(sum(h_1b)+sum(bb)+sum(hbp) as float)) as lgwSB
	from batterStats
	left join stolenBaseTeamTot on batterStats.yr = stolenBaseTeamTot.yr
	left join caughtStealingTeamTot on batterStats.yr = caughtStealingTeamTot.yr
	left join constants.woba_fip as woba on batterStats.yr = woba.season
	group by batterStats.yr, sb, cs , runsb,runcs
),

wsbCalc as (
	select batterid, batterStats.yr,
		((sb * runsb) + (cs * runcs)) - (lgwSB *cast( sum(h_1b) + sum(bb) + sum(hbp) as float)) as wSB
	from batterStats
	left join stolenBasePlayerTot on batterStats.batterid = stolenBasePlayerTot.runnerid
										and batterStats.yr = stolenBasePlayerTot.yr
	left join caughtStealingPlayerTot on batterStats.batterid = caughtStealingPlayerTot.runnerid
										and batterStats.yr = caughtStealingPlayerTot.yr
	left join lgqsbCalc on batterStats.yr = lgqsbCalc. yr
	left join constants.woba_fip as woba on batterStats.yr = woba.season
	group by batterid, batterStats.yr,sb, cs, runsb, runcs, lgwSB
),

bsrCalc as (
	select wGDPcalc.batterid,wGDPcalc.yr, wGDP + wSB as bsr
	from wGDPcalc
	left join wsbCalc on wGDPcalc.batterid = wsbCalc.batterid and wGDPcalc.yr = wsbCalc.yr
)


select *
from bsrCalc
where batterid = 'sotoj001'

-- Select yr, sum(cs)
-- from caughtStealingTot
-- where yr = 2021
-- group by yr

-- select * from runningtotals order by yr desc



-- firstname, lastname,
-- left join rosters.rosters as r on 
-- 		r.playerid = playerStats.batterid and playerStats.yr = r.year




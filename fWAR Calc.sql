With 
batterStats as (
	select batterid,  cast(right(left(gameid,7),4) as int) as yr, 
		case when abflag = 'T' then 1 else 0 end as ab,
		case when battereventflag = 'T' then 1 else 0 end as pa,
		case when battereventflag = 'T' and batterpos = 10 then 1 else 0 end as padh,
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

		case
		when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('LAA','CAL','ANA') then 'ANA'
		when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('FLO','MIA') then 'MIA'
		when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('MON','WAS') then 'WAS'
		when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('BRO','LAN') then 'LAN'
		when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('NY1','SFN') then 'SFN'
		when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('SLA','SE1','MIL') then 'MIL'
		when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('BSN','MLN','ATL') then 'ATL'
		when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('PHA','KC1','OAK') then 'OAK'
		when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('WS1','WS2','MIN') then 'MIN'
		else case when battingteam = 0 then visitingteam else left(gameid,3) end
		end as team,
		eventtype,eventcode,abflag, hitvalue, batterdest, shflag, sfflag,pinchhitflag,gameid
	FROM playlogs.plays
	where cast(right(left(gameid,7),4) as int) = 1992
	
	
),

leagueTotals as (
	select distinct yr,
		cast(sum(gdp)over(partition by yr) as float) as lgGDP,
		cast(sum(gdpo)over(partition by yr) as float) as lgGDPo
	from batterStats
),

lgRPO_calc as (
	SELECT extract(year from game_date) as year, 
		cast(sum(roadscore) + sum(homescore) as float)/ cast(sum(length_of_game_outs)as float) as lgRPO
	FROM gamelogs.games
	group by extract(year from game_date)
),

wRAA_calc as (
	select batterid, yr, team,
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
	group by batterid, yr, team, wbb, whbp, w1b, w2b, w3b, whr, woba, wobascale
	having (sum(ab) + sum(bb) + sum(hbp) + sum(sh) + sum(sf))>0
),

wGDPcalc as (
	select batterid,batterStats.yr,team,
		(((lgGDP/lgGDPo) * cast(sum(gdpo)as float)) - cast(sum(gdp)as float)) * lgRPO as wGDP
	from batterStats
	left join leagueTotals on batterStats.yr=leagueTotals.yr
	left join lgRPO_calc on batterStats.yr=lgRPO_calc.year
	group by batterid, batterStats.yr, team, lgGDP,lgGDPo,lgRPO
),





runnerGames as (
	select runnerid1st,runnerid2nd,runnerid3rd, 
		cast(right(left(gameid,7),4) as int) as yr, 
			case
			when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('LAA','CAL','ANA') then 'ANA'
			when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('FLO','MIA') then 'MIA'
			when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('MON','WAS') then 'WAS'
			when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('BRO','LAN') then 'LAN'
			when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('NY1','SFN') then 'SFN'
			when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('SLA','SE1','MIL') then 'MIL'
			when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('BSN','MLN','ATL') then 'ATL'
			when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('PHA','KC1','OAK') then 'OAK'
			when case when battingteam = 0 then visitingteam else left(gameid,3) end in ('WS1','WS2','MIN') then 'MIN'
			else case when battingteam = 0 then visitingteam else left(gameid,3) end
			end as team,
		eventcode, eventType
	FROM playlogs.plays
	where eventcode like '%SB%' or eventcode like '%CS%'
),

stolenBase as (
	select runnerid1st as runnerid,  yr, team, count(runnerid1st) as sb
	from runnerGames
	where eventcode like '%SB2%'
	group by runnerid1st, yr, team
	
	union all
	
	select runnerid2nd as runnerid, yr, team, count(runnerid2nd) as sb
	from runnerGames 
	where eventcode like '%SB3%'
	group by runnerid2nd, yr, team
	
	union all
	
	select runnerid3rd as runnerid, yr, team, count(runnerid3rd) as sb
	from runnerGames 
	where eventcode like '%SBH%'
	group by runnerid3rd, yr, team
),

stolenBasePlayerTot as (
	select runnerid, yr, team, cast(sum(sb) as float) as sb
	from stolenBase
	group by runnerid, yr, team
),

stolenBaseTeamTot as (
	select  yr, cast(sum(sb) as float) as sb
	from stolenBase
	group by  yr
),

caughtStealing as (
	select runnerid1st as runnerid, yr, team, count(runnerid1st) as cs
	from runnerGames 
	where eventcode like '%CS2%'
	group by runnerid1st, yr, team
	
	union all
	
	select runnerid2nd as runnerid, yr, team, count(runnerid2nd) as cs
	from runnerGames 
	where eventcode like '%CS3%'
	group by runnerid2nd, yr, team
	
	union all
	
	select runnerid3rd as runnerid, yr, team, count(runnerid3rd) as cs
	from runnerGames 
	where eventcode like '%CSH%'
	group by runnerid3rd, yr, team
),

caughtStealingPlayerTot as (
	select runnerid, yr, team, cast(sum(cs) as float) as cs
	from caughtStealing
	group by runnerid, yr, team
),

caughtStealingTeamTot as (
	select  yr, cast(sum(cs) as float) as cs
	from caughtStealing
	group by  yr
),

lgwsbCalc as (
	select distinct batterStats.yr, 
			(((sb * runsb) + (cs * runcs))
				/
			cast(sum(h_1b)+sum(bb)+sum(hbp) as float)) as lgwSB
	from batterStats
	left join stolenBaseTeamTot on batterStats.yr = stolenBaseTeamTot.yr
	left join caughtStealingTeamTot on batterStats.yr = caughtStealingTeamTot.yr
	left join constants.woba_fip as woba on batterStats.yr = woba.season
	group by batterStats.yr,  sb, cs , runsb,runcs
),

wsbCalc as (
	select batterid, batterStats.yr, batterStats.team,sb,runsb,cs,runcs,lgwSB,h_1b,bb,hbp,
		((sb * runsb) + (cs * runcs)) - (lgwSB *cast( coalesce(sum(h_1b),0) + coalesce(sum(bb),0) + coalesce(sum(hbp),0) as float)) as wSB
	from batterStats
	left join stolenBasePlayerTot on batterStats.batterid = stolenBasePlayerTot.runnerid
										and batterStats.yr = stolenBasePlayerTot.yr
										and batterStats.team = stolenBasePlayerTot.team
	left join caughtStealingPlayerTot on batterStats.batterid = caughtStealingPlayerTot.runnerid
										and batterStats.yr = caughtStealingPlayerTot.yr
										and batterStats.team = caughtStealingPlayerTot.team
	left join lgwsbCalc on batterStats.yr = lgwsbCalc. yr
	left join constants.woba_fip as woba on batterStats.yr = woba.season
	group by batterid, batterStats.yr, batterStats.team,sb, cs, runsb, runcs, lgwSB,h_1b,bb,hbp
),

bsrCalc as (
	select wGDPcalc.batterid,wGDPcalc.yr,wGDPcalc.team,wGDP,wSB,
		coalesce(wGDP,0) + coalesce(wSB,0) as bsr
	from wGDPcalc
	left join wsbCalc on wGDPcalc.batterid = wsbCalc.batterid and wGDPcalc.yr = wsbCalc.yr
),

defenseData as (
	select season, nameascii, pos, inn, franchise
	from playlogs.defense as d
	left join constants.teams_franchise as f on d.team = f.team
),

rposCalc as (
	select distinct batterid, year, batterStats.team, pos, inn,
	(case when pos = 'C' then inn*9 else 0 end +
	case when pos = '1b' then inn*-9.5 else 0 end +
	case when pos = '2B' then inn*3 else 0 end +
	case when pos = '3B' then inn*2 else 0 end +
	case when pos = 'SS' then inn*7 else 0 end +
	case when pos = 'LF' then inn*-7 else 0 end +
	case when pos = 'CF' then inn*2.5 else 0 end +
	case when pos = 'RF' or pos = 'Rf' then inn*-7 else 0 end +
	sum(padh) * -15)/1350 as rpos
	
	from batterStats
	left join rosters.rosters as r on 
		r.playerid = batterStats.batterid and batterStats.yr = r.year 
	left join defenseData as d on r.year = d.season and
										r.firstname|| ' ' || r.lastname = d.nameascii 
										and batterStats.team = d.franchise
	group by batterid, year, batterStats.team, pos, inn, r.team
),

lgRPW_calc as (
	SELECT extract(year from game_date) as yr, 
		/* league wide innings a game (9) * (runs / innings) * 1.5 +3 */
		((9* (cast(sum(roadscore) + sum(homescore) as float)/ (cast(sum(length_of_game_outs) as float)/3))) * 1.5)+3 as rpw
	FROM gamelogs.games
	where extract(year from game_date) > 1900
	group by extract(year from game_date)
),

rlrCalc as (
	select batterid, batterStats.yr, team , 
		((0.235*lgG) * rpw * sum(pa))/lgPa as rlr
	from batterStats
	left join lgRPW_calc on batterStats.yr = lgRPW_calc.yr
	left join (select yr, count(distinct gameid) as lgG
				from batterStats
				group by yr) as leagueGames on batterStats.yr = leagueGames.yr
	left join (select yr, sum(pa) as lgPa
				from batterStats
				group by yr) as leaguePA on batterStats.yr = leaguePA.yr
	where batterStats.yr>1900
	group by batterid, batterStats.yr, team, lgPa, rpw, lgG
)


-- select distinct wRAA_calc.batterid, wRAA_calc.yr, wRAA_calc.team,wRAA,bsr,sum(rpos) as rpos,rlr,rpw,
-- 		(wRAA+bsr+sum(rpos)+rlr)/rpw as war
-- from wRAA_calc
-- left join bsrCalc on wRAA_calc.batterid = bsrCalc.batterid
-- 					and wRAA_calc.yr = bsrCalc.yr
-- 					and wRAA_calc.team = bsrCalc.team
-- left join rposCalc on wRAA_calc.batterid = rposCalc.batterid
-- 					and wRAA_calc.yr = rposCalc.year
-- 					and wRAA_calc.team = rposCalc.team
-- left join rlrCalc on wRAA_calc.batterid = rlrCalc.batterid
-- 					and wRAA_calc.yr = rlrCalc.yr
-- 					and wRAA_calc.team = rlrCalc.team
-- left join lgRPW_calc on wRAA_calc.yr = lgRPW_calc.yr
-- where wRAA_calc.yr > 1900
-- 	and  wRAA_calc.batterid = 'winfd001'

-- group by wRAA_calc.batterid, wRAA_calc.yr, wRAA_calc.team,wRAA,bsr,rlr,rpw


select * 
from wsbCalc -- wGDPcalc --,wsbCalc
where batterid = 'winfd001'





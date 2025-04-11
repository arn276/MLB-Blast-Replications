With 
playerStats as (
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
	from playerStats
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
	from playerStats
	left join constants.woba_fip as woba on playerStats.yr = woba.season
	group by batterid, wbb, whbp, w1b, w2b, w3b, whr, woba, wobascale
),

bsr as (
	select batterid,
		(((lgGDP/lgGDPo) * cast(sum(gdpo)as float)) - cast(sum(gdp)as float)) * lgRPO as wGDP
	from playerStats
	left join leagueTotals on playerStats.yr=leagueTotals.yr
	left join lgRPO_calc on playerStats.yr=lgRPO_calc.year
	group by batterid, lgGDP,lgGDPo,lgRPO
)


select * from bsr
where batterid = 'sotoj001'


-- firstname, lastname,
-- left join rosters.rosters as r on 
-- 		r.playerid = playerStats.batterid and playerStats.yr = r.year




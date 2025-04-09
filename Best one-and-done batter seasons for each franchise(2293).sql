with oneNdone_bat as (
	select r.playerid, lastname, firstname, 
		case
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
		end as team, 
		count(r.year), y.year as year
	FROM rosters.rosters as r
	left join (select playerid,team, year from rosters.rosters) as y on r.playerid=y.playerid and r.team=y.team
	where 1=1 
		-- and r.playerid = 'andes101' 
		and playerpos != 'P'
		and r.team not in ('BLF','BRF','SLF')
		and firstname||lastname != 'DanVogelbach'
	group by r.playerid, lastname, firstname, r.team, y.year
	having count(r.year) = 1
),

playerGames as (
	select batterid, runnerid1st,runnerid2nd,runnerid3rd, cast(right(left(gameid,7),4) as int) as yr, eventtype,eventcode,
		abflag, hitvalue, batterdest, shflag, sfflag
	FROM playlogs.plays, oneNdone_bat
	where batterid in (oneNdone_bat.playerid)
),

batterTot as (
	SELECT batterid,  yr, count(abflag) as ab,sum(hitvalue) as h,sum(batterdest) as tb
		-- ,batterhand, pitcherid, pitcherhand, runnerid1st, runnerid2nd, runnerid3rd, eventcode, leadoffflag, pinchhitflag, 
		-- batterpos, lineupnum, eventtype, battereventflag, abflag, hitvalue, shflag, sfflag, outsonplay, rbis, wpflag, pbflag, 
		-- errors, batterdest, runner1stdest, runner2nddest, runner3rddest
		FROM playerGames
		where abflag = 'T'
		group by batterid, yr
),

walksTot as (
	select batterid, yr, count(eventtype) as bb
	FROM playerGames
	where eventtype = 14
	group by batterid, yr
),

iWalksTot as (
	select batterid, yr, count(eventtype) as ibb
	FROM playerGames
	where eventtype = 15
	group by batterid, yr
),

hbpTot as (
	select batterid, yr, count(eventtype) as hbp
	FROM playerGames
	where eventtype = 16
	group by batterid, yr
),

gdpTot as (
	select batterid,  yr, count(batterid) as gdp
	from playerGames
	where eventcode like '%GDP%'
	group by batterid, yr
),

sacTot as (
	select batterid,  yr, 
	sum(case when shflag = 'T' then 1 else 0 end) as sh,
	sum(case when sfflag = 'T' then 1 else 0 end) as sf
	from playerGames
	group by batterid, yr
),

stolenBase as (
	select runnerid1st as runnerid,  yr, count(runnerid1st) as sb
	from playerGames
	where eventcode like '%SB2%'
	group by runnerid1st, yr
	
	union all
	
	select runnerid2nd as runnerid, yr, count(runnerid2nd) as sb
	from playerGames
	where eventcode like '%SB3%'
	group by runnerid2nd, yr
	
	union all
	
	select runnerid3rd as runnerid, yr, count(runnerid3rd) as sb
	from playerGames
	where eventcode like '%SBH%'
	group by runnerid3rd, yr
),

stolenBaseTot as (
	select runnerid, yr, sum(sb) as sb
	from stolenBase
	group by runnerid, yr
),

caughtStealing as (
	select runnerid1st as runnerid, yr, count(runnerid1st) as cs
	from playerGames
	where eventType = 6
	group by runnerid1st, yr
	
	union all
	
	select runnerid2nd as runnerid, yr, count(runnerid2nd) as cs
	from playerGames
	where eventType = 6
	group by runnerid2nd, yr
	
	union all
	
	select runnerid3rd as runnerid, yr, count(runnerid3rd) as cs
	from playerGames
	where  eventType = 6
	group by runnerid3rd, yr
),

caughtStealingTot as (
	select runnerid, yr, sum(cs) as cs
	from caughtStealing
	group by runnerid, yr
),

zeros as (
	select batterTot.batterid, batterTot.yr, sh, sf,
	case when ab is null then 0 else ab end as ab, 
	case when h is null then 0 else h  end as h, 
	case when tb is null then 0 else tb end as tb, 
	case when bb is null then 0 else bb end as bb, 
	case when ibb is null then 0 else ibb end as ibb, 
	case when hbp is null then 0 else hbp end as hbp,
	case when gdp is null then 0 else gdp end as gdp,
	
	case when sb is null then 0 else sb end as sb,
	case when cs is null then 0 else cs end as cs
	
	from batterTot
	left join walksTot on  batterTot.batterid = walksTot.batterid and batterTot.yr = walksTot.yr
	left join iWalksTot on  batterTot.batterid = iWalksTot.batterid and batterTot.yr = iWalksTot.yr
	left join hbpTot on  batterTot.batterid = hbpTot.batterid and batterTot.yr = hbpTot.yr
	left join gdpTot on  batterTot.batterid = gdpTot.batterid and batterTot.yr = gdpTot.yr
	left join sacTot on  batterTot.batterid = sacTot.batterid and batterTot.yr = sacTot.yr
	left join stolenBaseTot on  batterTot.batterid = stolenBaseTot.runnerid and batterTot.yr = stolenBaseTot.yr
	left join caughtStealingTot on  batterTot.batterid = caughtStealingTot.runnerid and batterTot.yr = caughtStealingTot.yr
),

calculate as (
	select batterid, lastname, firstname, team, yr, --ab, h, tb, bb, ibb, hbp, sb, cs, gdp, sf, sh,
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
	left join oneNdone_bat on zeros.yr = oneNdone_bat.year and zeros.batterid = oneNdone_bat.playerid
	where oneNdone_bat.team is not null
),

rankResults as (
	select batterid, lastname, firstname, team, yr,
		-- RC_SBmethod,
		-- rank() over (partition by team order by RC_SBmethod desc ) as RC_SB_Rank,
		RCtechnical,
		rank() over (partition by team order by RCtechnical desc ) as RC_tech_Rank
	from calculate
)

Select batterid, lastname, firstname, team, yr, RCtechnical, RC_tech_Rank
from rankResults
where RC_tech_Rank = 1





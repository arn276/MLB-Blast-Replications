# MLB-Blast-Replications

Standing up my Postgres Server with retro sheets data (Rosters, Playlogs, gamelogs) and recreating [Stat Blasts from Effectively Wild](https://effectivelywild.fandom.com/wiki/Stat_Blast#2019)

- retrosheet_statLoad.ipynb: Adding data to postres Server.
- ep. 2270 Players with most distinct team matchups
    - Restricts to top 50, with versions for matchups independent (e.g. Miami at St.Louis is the same as St. Louis at Miami) and dependent of location.
- ep. 2293 Best one-and-done seasons for each franchise
    - Batter - Calculated by runs created and by WAR (to address defense, running, and batting)
    - Pitcher - 

library('RPostgreSQL')
library(tidyverse)

PG <- dbDriver("PostgreSQL")
con <- dbConnect(PG, user = "root", password = "Wmo_tw39pGTS^V_05^q", host = "localhost", port = 55432,
                dbname = "meetnetten")

#isSteekproef nog toevoegen

query_bezoeken <- "Select PG.name as Groep
    , P.Name as Meetnet
    , V.task_id
    , T.name as Taak
    , V.id as Visit_ID
    , V.start_date
    , V.Start_time
    , V.year_target as Jaardoel
    , V.analysis as VoorAnalyse
    , V.end_date
    , V.end_time
    , V.notes
    , L.name as Locatie
    --, pr.name as Protocol
    , PR.i18n->>'name_nl' as Protocol
    , case when V.legacy_status = 1 then 'Conform protocol'
           when V.legacy_status = -1 then 'Niet volledig conform protocol'
           when V.legacy_status = -2 then 'Geen veldwerk mogelijk'
           else Null
      end as Bezoek_Status
    , ARRAY_TO_STRING(ARRAY[U.first_name, U.Last_name], ' ') AS Uitgevoerd_Door
from Projects_project P
    inner join projects_projectgroup PG on PG.id = P.group_id
    inner join fieldwork_visit V on V.project_id = P.id
    left outer join projects_task T on T.ID = V.task_id
    Inner Join Locations_location L on L.ID = V.location_ID
    Inner join Protocols_protocol PR on PR.id = V.protocol_ID
    INNEr JOIN accounts_user U on U.ID = V.user_id
Order by PG.name
    , P.Name
    , L.name
    , V.start_date"

query_aantallen <- "select P.name as Project
    , L.name as Locatie
    , L1.name as Sublocatie
    , V.id as visit_id
    , V.start_date as DatumBezoek
    , ARRAY_TO_STRING(ARRAY[U.first_name, U.last_name], ' ') AS UitgevoerdDoor
    --, tmp.workpackageid
    , tmp.WPName as Werkpakket
    , tmp.taskid as task_id
    , tmp.taskName as Taak
    --, SA.ID as SampleID
    , PR.i18n->>'name_nl' as Protocol
    , SA.Not_Counted as NietGeteld
    , case when V.legacy_status = 1 then 'Conform protocol'
           when V.legacy_status = -1 then 'Niet volledig conform protocol'
           when V.legacy_status = -2 then 'Geen veldwerk mogelijk'
           else Null
      end as Bezoek_Status
    , SA.Notes as Opmerkingen
    --, SP.name_nl as Soort
    , SP.i18n->>'name_nl' as Soort
    , O.sex as Geslacht
    , case when V.status = -2 then NULL else O.number_min END as Aantal
    --, ACT.name_nl as Activiteit
    , ACT.i18n->>'name_nl' as Activiteit
   -- , LS.name_nl as Levensstadium
    , LS.i18n->>'name_nl' as Levensstadium
 from Projects_project P
    inner join Fieldwork_visit V on V.project_ID = P.ID
    INNER JOIN (Select PS.project_ID, PS.species_ID from projects_projectspecies PS where PS.is_primary is true)prim on prim.project_ID = P.ID
        --get task context for visit when available
    left outer join (select V.ID as VisitID
                        , WP.ID as WorkpackageID
                        , WP.name as WPName
                        , T.ID As TaskID
                        , T.protocol_id
                        , T.name as TaskName
                        from Projects_project P
                                    INNER join Projects_workpackage WP on WP.project_ID = P.ID
                                    INNER join Projects_task T on T.wp_ID = WP.ID
                                    INNER join Fieldwork_visit V on V.task_ID = T.ID
    ) tmp on tmp.visitid = V.id
    left Outer JOIN protocols_protocol PR on PR.id = V.protocol_id
    left outer join fieldwork_sample SA on SA.visit_ID = V.ID
    left outer join fieldwork_observation O on O.sample_ID = SA.ID and O.species_id = Prim.species_ID
    left outer join Species_species SP on SP.ID = O.species_id
    left outer join species_activity ACT on ACT.id = O.activity_id
    left outer join species_lifestage LS on LS.id = O.life_stage_id
    LEFT OUTER join Locations_location L ON L.ID = V.location_ID
    Left outer Join Locations_location L1 on L1.ID = SA.location_id
    left outer JOIN accounts_user U on U.ID = V.user_id

where 1=1
    and P.name <> 'Algemene Broedvogelmonitoring (ABV)'
    and P.name <> 'Algemene Vlindermonitoring'
    and SA.notes <> 'dummy sample'
Order by P.name
    , L.Name
    , V.start_date
    --, SP.name_nl
    , L1.Name"

query_covariabelen <- "Select P.Name as Meetnet
    , PR.i18n->>'name_nl' as Protocol
    , V.ID as Visit_ID
    , V.task_ID
    --, A.ID as attribute_id
    --, A.name as Bezoekvariabele
    , A.i18n->>'name_nl' as Bezoekvariabele
    --, VV.value as Waarde
    --, C.value
    , case when C.value is null then VV.value else C.name end as Waarde
    --, C.name
    , U.i18n->>'name_nl' as Eenheid
from Projects_project P
    INNER JOIN Fieldwork_visit V on V.project_ID = P.ID
    INNER JOIN Protocols_protocol PR on PR.ID = V.protocol_ID
    Left OUTER JOIN fieldwork_visitvalue VV on VV.object_ID = V.ID
    left outer JOIN model_attributes_attribute A on A.ID = VV.attribute_ID
    left outer Join model_attributes_unit U on U.id = A.unit_id
    LEFT Outer Join Model_attributes_choice C on C.Attribute_id = VV.attribute_id and cast(C.id as varchar(100)) = VV.value
    --where VV.attribute_ID = 9
Order by P.Name, PR.name, VV.object_ID

/**
select * from fieldwork_visitvalue VV
inner join Model_attributes_attribute A on A.ID = VV.attribute_id
left outer join Model_attributes_choice C on C.attribute_id = A.ID
left outer join Model_attributes_unit U on U.ID = A.unit_ID
order by VV.object_id
**/

/**
select V.ID as Visit_ID
    , VV.ID as VisitValue_ID
    , A.ID AS Attribute_ID
    , A.name_nl as Attribuut_beschrijving
    , VV.value as VisitValue_Value
from Projects_project P
    INNER JOIN Fieldwork_visit V on V.project_ID = P.ID
    INNer JOIN fieldwork_visitvalue VV on VV.object_ID = V.ID
    inner join Model_attributes_attribute A on A.ID = VV.attribute_id
where P.id = 4 --boomkikker
    and V.id = 238

select *
from model_attributes_choice c
where C.attribute_ID in (7, 9)


select *
from accounts_user
where length(reference_obs) > 1

**/"

dbListFields(conn = con, name =  "Fieldwork_visit")

query_werkpakket <- "
  select PG.Name as Soortgroep
    , P.Name as Project
    , L.name as Locatie
        --, U.First_name
    --, U.Last_name
    , WP.Name as Werkpakket
    --, WP.Start_date as WP_start
    --, WP.end_date as WP_end
    , T.name as Taak
    , T.id as task_id
    --, PR.name as Protocol
    , PR.i18n->>'name_nl' as Protocol
    , T.start_date as Start_Taak
    , T.end_date as Einde_Taak
    , V.id as visit_id
    , V.start_date as Datum_bezoek
    , ARRAY_TO_STRING(ARRAY[U.first_name, U.Last_name], ' ') AS Uitgevoerd_Door
    , case when V.start_date >= T.start_date and V.start_date <= T.end_date then 1
           when V.start_date is NULL then '-1'
           else 0
      end as BinnenTaakPeriode
    , case when V.legacy_status = 1 then 'Conform protocol'
           when V.legacy_status = -1 then 'Niet volledig conform protocol'
           when V.legacy_status = -2 then 'Geen veldwerk mogelijk'
           else Null
      end as Bezoek_Status
    , V.notes as Opmerkingen

from Projects_project P
    INNER JOIN projects_projectgroup PG on PG.ID = P.group_ID
    left outer join projects_projectlocation PL on PL.project_id = P.ID
    LEFT OUTER join Locations_location L ON L.ID = PL.location_ID
    left OUTER join Projects_workpackage WP on WP.project_ID = P.ID
    LEFT OUTER join Projects_task T on T.wp_ID = WP.ID and T.location_ID = L.ID
    left Outer JOIN protocols_protocol PR on PR.id = T.protocol_id
    Left outer join Fieldwork_visit V on V.task_ID = T.ID
    left outer JOIN accounts_user U on U.ID = V.user_id
where 1=1
--and (L.name NOT like 'Sect%' or L.NAME is null)
and L.parent_ID is null
Order by PG.name
    , P.name
    , L.name
    , V.start_date
    , T.start_date
    , T.name"

bezoeken <- dbGetQuery(con, query_bezoeken, encoding = "")
bezoeken <- bezoeken %>%
  mutate(groep = gsub(pattern = "Ã«", replacement = "ë", x = groep),
         meetnet = gsub(pattern = "Ã«", replacement = "ë", x = meetnet),
         locatie = gsub(pattern = "Ã«", replacement = "ë", x = locatie),
         bezoek_status = gsub(pattern = "Ã«", replacement = "ë", x = bezoek_status),
         protocol = gsub(pattern = "Ã«", replacement = "ë", x = protocol),
         notes = gsub(pattern = "Ã«", replacement = "ë", x = notes)) %>%
  mutate(groep = gsub(pattern = "Ã©", replacement = "é", x = groep),
         meetnet = gsub(pattern = "Ã©", replacement = "é", x = meetnet),
         locatie = gsub(pattern = "Ã©", replacement = "é", x = locatie),
         bezoek_status = gsub(pattern = "Ã©", replacement = "é", x = bezoek_status),
         protocol = gsub(pattern = "Ã©", replacement = "é", x = protocol),
         notes = gsub(pattern = "Ã©", replacement = "é", x = notes),
         notes = gsub(pattern = "Ã¶", replacement = "ö", x = notes),
         notes = gsub(pattern = "Ã¯", replacement = "ï", x = notes)) %>%
  mutate(soortgroep = groep,
         opmerkingen = notes)

aantallen <- dbGetQuery(con, query_aantallen)

aantallen <- aantallen %>%
  mutate(project = gsub(pattern = "Ã«", replacement = "ë", x = project),
         locatie = gsub(pattern = "Ã«", replacement = "ë", x = locatie),
         bezoek_status = gsub(pattern = "Ã«", replacement = "ë", x = bezoek_status),
         protocol = gsub(pattern = "Ã«", replacement = "ë", x = protocol)) %>%
  rename(meetnet = project)

covariabelen <- dbGetQuery(con, query_covariabelen)

covariabelen <- covariabelen %>%
  mutate(meetnet = gsub(pattern = "Ã«", replacement = "ë", x = meetnet),
         protocol = gsub(pattern = "Ã«", replacement = "ë", x = protocol))

werkpakketten <- dbGetQuery(con, query_werkpakket)

werkpakketten <- werkpakketten %>%
  mutate(soortgroep = gsub(pattern = "Ã«", replacement = "ë", x = soortgroep),
         project = gsub(pattern = "Ã«", replacement = "ë", x = project),
         locatie = gsub(pattern = "Ã«", replacement = "ë", x = locatie),
         bezoek_status = gsub(pattern = "Ã«", replacement = "ë", x = bezoek_status),
         protocol = gsub(pattern = "Ã«", replacement = "ë", x = protocol),
         opmerkingen = gsub(pattern = "Ã«", replacement = "ë", x = opmerkingen)) %>%
  mutate(soortgroep = gsub(pattern = "Ã©", replacement = "é", x = soortgroep),
         project = gsub(pattern = "Ã©", replacement = "é", x = project),
         locatie = gsub(pattern = "Ã©", replacement = "é", x = locatie),
         bezoek_status = gsub(pattern = "Ã©", replacement = "é", x = bezoek_status),
         protocol = gsub(pattern = "Ã©", replacement = "é", x = protocol),
         opmerkingen = gsub(pattern = "Ã©", replacement = "é", x = opmerkingen),
         opmerkingen = gsub(pattern = "Ã¶", replacement = "ö", x = opmerkingen),
         opmerkingen = gsub(pattern = "Ã¯", replacement = "ï", x = opmerkingen)) %>%
  rename(meetnet = project)

dbDisconnect(con)



setwd("data")
versie <- paste("versie", Sys.Date(), sep ="")
dir.create(versie)

write.csv2(aantallen, paste(versie,"/aantallen.csv", sep =""), row.names = FALSE)
write.csv2(bezoeken, paste(versie,"/bezoeken.csv", sep =""), row.names = FALSE)
write.csv2(werkpakketten, paste(versie,"/werkpakketten.csv", sep =""), row.names = FALSE)
write.csv2(covariabelen,  paste(versie,"/covariabelen.csv", sep = ""), row.names = FALSE)


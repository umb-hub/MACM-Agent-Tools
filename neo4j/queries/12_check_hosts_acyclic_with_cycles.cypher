// Reporting query for hosts cycles detection (no output if none found)
MATCH p = (n)-[:hosts*1..]->(n)
WITH DISTINCT p,
     [x IN nodes(p) | toString(coalesce(x.name, id(x)))] AS lst
WITH CASE
       WHEN size(lst) > 1 AND lst[0] = lst[size(lst)-1] THEN lst[0..size(lst)-1]
       ELSE lst
     END AS core
WHERE size(core) > 0
WITH [i IN range(0, size(core)-1) |
       apoc.text.join(core[i..] + core[..i] + [core[i]], " -> ")
     ] AS rots
WITH apoc.coll.min(rots) AS cycleCanon
WITH apoc.coll.toSet(collect(cycleCanon)) AS cycles
WITH cycles
WHERE size(cycles) > 0
RETURN apoc.text.format(
  "/*Hosts cycles detected: %s*/",
  [apoc.text.join(cycles, " | ")]
) AS hosts_cycles_violation;

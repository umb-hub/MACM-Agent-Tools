CALL apoc.trigger.add(
  '12_check_hosts_acyclic_with_cycles',
  '
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
  CALL apoc.util.validate(
    size(cycles) > 0,
    "/*Constraint violation: cycles detected in :hosts hierarchy:\\n" + apoc.text.join(cycles[0..20], "\\n") + "*/",
    []
  )
  RETURN true
  ',
  {phase:'before'}
);
MATCH (start)
WITH start LIMIT 1

// Collect reachable nodes
MATCH (start)-[*0..]-(reachable)
WITH start, collect(DISTINCT id(reachable)) AS reachIds

// All nodes
MATCH (n)
WITH start, reachIds, collect(id(n)) AS allIds
WITH start, [x IN allIds WHERE NOT x IN reachIds] AS missingIds

// Unreachable node labels/names
OPTIONAL MATCH (m)
WHERE id(m) IN missingIds
WITH start,
     [m IN collect(m) | coalesce(m.name, head(labels(m)), toString(id(m)))] AS notReachable

// Only return a message if graph is NOT connected
WITH start, notReachable
WHERE size(notReachable) > 0
RETURN apoc.text.format(
  "/*Connectivity violation: graph is not connected. Start node: %s. Unreachable: %s*/",
  [
    coalesce(start.name, head(labels(start)), toString(id(start))),
    apoc.text.join(notReachable, ", ")
  ]
) AS connectivity_violation;

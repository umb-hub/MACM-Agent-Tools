CALL apoc.trigger.add(
  '10_check_graph_connectivity_global',
  '
    // Select a random node as starting point
    MATCH (start)
    WITH start LIMIT 1
    
    // Paths of length 0.. → start is included in reachable nodes
    MATCH (start)-[*0..]-(reachable)
    WITH start, collect(DISTINCT id(reachable)) AS reachIds
    
    // All nodes in the graph
    MATCH (n)
    WITH start, reachIds, collect(id(n)) AS allIds
    WITH start, reachIds, allIds, 
         [x IN allIds WHERE NOT x IN reachIds] AS missingIds
    
    // Unreachable nodes
    OPTIONAL MATCH (m)
    WHERE id(m) IN missingIds
    WITH start, 
         [m IN collect(m) | coalesce(m.name, head(labels(m)), toString(id(m)))] AS notReachable
    
    CALL apoc.util.validate(
      size(notReachable) > 0,
      "/*Connectivity violation: the graph is not connected. Start node: " + 
      coalesce(start.name, head(labels(start)), toString(id(start))) + 
      ". Unreachable nodes: " + 
      apoc.text.join(notReachable, ", ") + 
      "*/",
      []
    )
    RETURN true
  ',
  {phase: 'before'}
);
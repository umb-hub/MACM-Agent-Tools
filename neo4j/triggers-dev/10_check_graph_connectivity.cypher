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
    
    // Build detailed descriptions for unreachable nodes
    OPTIONAL MATCH (m)
    WHERE id(m) IN missingIds
    WITH start, m,
         CASE 
           WHEN m.component_id IS NOT NULL AND m.name IS NOT NULL 
           THEN m.component_id + " (" + m.name + ")"
           WHEN m.component_id IS NOT NULL 
           THEN m.component_id
           WHEN m.name IS NOT NULL 
           THEN m.name
           ELSE head(labels(m)) + "[" + toString(id(m)) + "]"
         END AS nodeDesc
    WITH start, collect(nodeDesc) AS notReachable
    
    CALL apoc.util.validate(
      size(notReachable) > 0,
      "/*Rule 9 violation: Graph Connectivity - The graph is not fully connected.\\n\\n" + 
      "Starting from node: " + coalesce(start.name, start.component_id, head(labels(start)), toString(id(start))) + "\\n" +
      "Unreachable nodes (" + toString(size(notReachable)) + "): " + apoc.text.join(notReachable, ", ") + 
      "\\n\\nREQUIREMENT: All nodes in the graph must be reachable from any other node (the graph must be connected).\\n" +
      "\\nREMEDIATION:\\n" +
      "1. Identify disconnected components: The listed nodes are not connected to the main graph\\n" +
      "2. Add appropriate relationships to connect isolated nodes/subgraphs:\\n" +
      "   - Use [:hosts] for hosting relationships (HW->OS, OS->Service, etc.)\\n" +
      "   - Use [:provides] for CSP-provided resources\\n" +
      "   - Use [:connects] for network connectivity\\n" +
      "   - Use [:uses] for service dependencies\\n" +
      "   - Use [:interacts] for Party interactions\\n" +
      "3. Verify that every node has at least one relationship connecting it to the rest of the graph\\n" +
      "\\nCOMMON CAUSES:\\n" +
      "- Orphaned nodes created without any relationships\\n" +
      "- Separate infrastructure stacks not linked together\\n" +
      "- Missing network connectivity between components\\n" +
      "- Forgotten CSP [:provides] relationships for cloud resources*/",
      []
    )
    RETURN true
  ',
  {phase: 'before'}
);
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
RETURN "Rule 9 violation: Graph Connectivity\n\n" +
       "Starting from node: " + coalesce(start.name, start.component_id, head(labels(start)), toString(id(start))) + "\n" +
       "Unreachable nodes (" + toString(size(notReachable)) + "): " + apoc.text.join(notReachable, ", ") + "\n\n" +
       "REQUIREMENT: All nodes must be reachable from any other node (the graph must be connected).\n\n" +
       "REMEDIATION:\n" +
       "1. Identify disconnected components: Listed nodes are not connected to main graph\n" +
       "2. Add appropriate relationships to connect isolated nodes/subgraphs:\n" +
       "   - [:hosts] for hosting relationships (HW->OS, OS->Service, etc.)\n" +
       "   - [:provides] for CSP-provided resources\n" +
       "   - [:connects] for network connectivity\n" +
       "   - [:uses] for service dependencies\n" +
       "   - [:interacts] for Party interactions\n" +
       "3. Verify every node has at least one relationship connecting it to the rest\n\n" +
       "COMMON CAUSES:\n" +
       "- Orphaned nodes without relationships\n" +
       "- Separate infrastructure stacks not linked\n" +
       "- Missing network connectivity\n" +
       "- Forgotten CSP [:provides] relationships" AS connectivity_violation;

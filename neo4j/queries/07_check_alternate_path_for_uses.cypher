// Reporting query for alternate path requirement for uses relationships
MATCH (sourceNode)-[usesRel:uses]->(targetNode)
WHERE NOT EXISTS {
  MATCH alternatePath=(sourceNode)-[*]-(targetNode)
  WHERE ALL(rel IN relationships(alternatePath) WHERE type(rel) <> "uses")
  AND length(alternatePath) > 0
}
WITH sourceNode, targetNode,
     CASE 
        WHEN sourceNode.component_id IS NOT NULL AND sourceNode.name IS NOT NULL 
        THEN apoc.text.format("Node[component_id: %s, name: %s, labels: %s]", [sourceNode.component_id, sourceNode.name, apoc.text.join(labels(sourceNode), ",")])
        WHEN sourceNode.component_id IS NOT NULL 
        THEN apoc.text.format("Node[component_id: %s, labels: %s]", [sourceNode.component_id, apoc.text.join(labels(sourceNode), ",")])
        WHEN sourceNode.name IS NOT NULL 
        THEN apoc.text.format("Node[name: %s, labels: %s]", [sourceNode.name, apoc.text.join(labels(sourceNode), ",")])
        ELSE apoc.text.format("Node[id: %s, labels: %s]", [toString(id(sourceNode)), apoc.text.join(labels(sourceNode), ",")])
     END AS sourceDescription,
     CASE 
        WHEN targetNode.component_id IS NOT NULL AND targetNode.name IS NOT NULL 
        THEN apoc.text.format("Node[component_id: %s, name: %s, labels: %s]", [targetNode.component_id, targetNode.name, apoc.text.join(labels(targetNode), ",")])
        WHEN targetNode.component_id IS NOT NULL 
        THEN apoc.text.format("Node[component_id: %s, labels: %s]", [targetNode.component_id, apoc.text.join(labels(targetNode), ",")])
        WHEN targetNode.name IS NOT NULL 
        THEN apoc.text.format("Node[name: %s, labels: %s]", [targetNode.name, apoc.text.join(labels(targetNode), ",")])
        ELSE apoc.text.format("Node[id: %s, labels: %s]", [toString(id(targetNode)), apoc.text.join(labels(targetNode), ",")])
     END AS targetDescription
WITH apoc.text.format("USES relationship without alternate path: %s -[:uses]-> %s", [sourceDescription, targetDescription]) AS violationDetail
RETURN "Rule 3 violation: Alternate path for uses\n\n" +
       "VIOLATION: " + violationDetail + "\n\n" +
       "REQUIREMENT: For each A -[:uses]-> B, there must exist at least one path connecting A and B that:\n" +
       "  - Uses relationships OTHER than [:uses] (e.g., [:hosts], [:provides], [:connects])\n" +
       "  - Does NOT include [:interacts] relationships\n\n" +
       "REMEDIATION GUIDE:\n" +
       "1. Analyze infrastructure: Identify how source/target are physically/logically connected\n" +
       "2. Add missing hosting relationships: If both services run on same system, add [:hosts]\n" +
       "3. Add infrastructure relationships: [:connects] for networks, [:provides] from CSP\n" +
       "4. Verify alternate path connects both nodes without using [:uses]\n\n" +
       "EXAMPLE:\n" +
       "If ServiceA -[:uses]-> ServiceB, you might add:\n" +
       "  SystemLayerX -[:hosts]-> ServiceA\n" +
       "  SystemLayerX -[:hosts]-> ServiceB\n" +
       "  (Creates alternate: ServiceA <-[:hosts]- SystemLayerX -[:hosts]-> ServiceB)" AS report;

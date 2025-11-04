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
RETURN apoc.text.format("USES relationship without alternate path: %s -[:uses]-> %s", [sourceDescription, targetDescription]) AS violationDetail;

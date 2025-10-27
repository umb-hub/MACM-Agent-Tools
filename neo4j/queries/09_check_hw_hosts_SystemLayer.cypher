// Reporting query for HW hosts SystemLayer
MATCH (sourceNode)-[hostsRel:hosts]->(targetNode)
WITH head(labels(sourceNode)) AS sourcePrimaryLabel, head(labels(targetNode)) AS targetPrimaryLabel, sourceNode, targetNode, hostsRel
WHERE sourcePrimaryLabel = "HW" AND targetPrimaryLabel = "SystemLayer"
AND targetNode.type = "SystemLayer.ContainerRuntime"
WITH sourceNode, targetNode,
     CASE 
        WHEN sourceNode.component_id IS NOT NULL AND sourceNode.name IS NOT NULL 
        THEN apoc.text.format("Node[component_id: %s, name: %s, type: %s, labels: %s]", [sourceNode.component_id, sourceNode.name, coalesce(sourceNode.type, "<no-type>"), apoc.text.join(labels(sourceNode), ",")])
        WHEN sourceNode.component_id IS NOT NULL 
        THEN apoc.text.format("Node[component_id: %s, type: %s, labels: %s]", [sourceNode.component_id, coalesce(sourceNode.type, "<no-type>"), apoc.text.join(labels(sourceNode), ",")])
        WHEN sourceNode.name IS NOT NULL 
        THEN apoc.text.format("Node[name: %s, type: %s, labels: %s]", [sourceNode.name, coalesce(sourceNode.type, "<no-type>"), apoc.text.join(labels(sourceNode), ",")])
        ELSE apoc.text.format("Node[id: %s, type: %s, labels: %s]", [toString(id(sourceNode)), coalesce(sourceNode.type, "<no-type>"), apoc.text.join(labels(sourceNode), ",")])
     END AS sourceDescription,
     CASE 
        WHEN targetNode.component_id IS NOT NULL AND targetNode.name IS NOT NULL 
        THEN apoc.text.format("Node[component_id: %s, name: %s, type: %s, labels: %s]", [targetNode.component_id, targetNode.name, coalesce(targetNode.type, "<no-type>"), apoc.text.join(labels(targetNode), ",")])
        WHEN targetNode.component_id IS NOT NULL 
        THEN apoc.text.format("Node[component_id: %s, type: %s, labels: %s]", [targetNode.component_id, coalesce(targetNode.type, "<no-type>"), apoc.text.join(labels(targetNode), ",")])
        WHEN targetNode.name IS NOT NULL 
        THEN apoc.text.format("Node[name: %s, type: %s, labels: %s]", [targetNode.name, coalesce(targetNode.type, "<no-type>"), apoc.text.join(labels(targetNode), ",")])
        ELSE apoc.text.format("Node[id: %s, type: %s, labels: %s]", [toString(id(targetNode)), coalesce(targetNode.type, "<no-type>"), apoc.text.join(labels(targetNode), ",")])
     END AS targetDescription
RETURN apoc.text.format("Invalid HW-to-SystemLayer hosting relationship: %s -[:hosts]-> %s\n  Source type: %s\n  Target type: %s\n  Rule: Hardware nodes cannot directly host SystemLayer.ContainerRuntime. ContainerRuntime must be hosted by an OS.", [sourceDescription, targetDescription, coalesce(sourceNode.type, "<no-type>"), coalesce(targetNode.type, "<no-type>")]) AS violationDetail;

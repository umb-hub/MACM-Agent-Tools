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
WITH apoc.text.format("Invalid HW-to-SystemLayer hosting: %s -[:hosts]-> %s\n  Source: %s\n  Target: %s", [sourceDescription, targetDescription, coalesce(sourceNode.type, "<no-type>"), coalesce(targetNode.type, "<no-type>")]) AS violation
RETURN "Rule 8 violation: Hardware hosting SystemLayer node validity\n\n" +
       violation + "\n\n" +
       "RULE: Hardware cannot directly host SystemLayer.ContainerRuntime.\n\n" +
       "ALLOWED PATTERNS:\n" +
       "  HW.* -[:hosts]-> SystemLayer.Firmware\n" +
       "  HW.* -[:hosts]-> SystemLayer.OS\n" +
       "  HW.* -[:hosts]-> SystemLayer.HyperVisor\n\n" +
       "FORBIDDEN PATTERN:\n" +
       "  HW.* -[:hosts]-> SystemLayer.ContainerRuntime (ContainerRuntime requires OS)\n\n" +
       "REMEDIATION:\n" +
       "1. Add intermediate SystemLayer.OS: HW -> OS -> ContainerRuntime\n" +
       "2. Proper layering: HW.Server -[:hosts]-> SystemLayer.OS -[:hosts]-> SystemLayer.ContainerRuntime\n" +
       "3. ContainerRuntime must always run on an Operating System\n\n" +
       "EXAMPLE:\n" +
       "  WRONG: HW.Server -[:hosts]-> SystemLayer.ContainerRuntime\n" +
       "  RIGHT: HW.Server -[:hosts]-> SystemLayer.OS, SystemLayer.OS -[:hosts]-> SystemLayer.ContainerRuntime" AS report;

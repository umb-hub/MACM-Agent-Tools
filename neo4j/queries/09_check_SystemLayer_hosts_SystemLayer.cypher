// Reporting query for SystemLayer hosts SystemLayer
MATCH (sourceNode)-[hostsRel:hosts]->(targetNode)
WITH head(labels(sourceNode)) AS sourcePrimaryLabel, head(labels(targetNode)) AS targetPrimaryLabel, sourceNode, targetNode, hostsRel
WHERE sourcePrimaryLabel = "SystemLayer" AND targetPrimaryLabel = "SystemLayer"
AND NOT (
  sourceNode.type = "SystemLayer.OS" AND targetNode.type IN ["SystemLayer.ContainerRuntime", "SystemLayer.HyperVisor"]
)
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
WITH apoc.text.format("Invalid SystemLayer hosting: %s -[:hosts]-> %s\n  Source: %s\n  Target: %s", [sourceDescription, targetDescription, coalesce(sourceNode.type, "<no-type>"), coalesce(targetNode.type, "<no-type>")]) AS violation
RETURN "Rule 4 violation: SystemLayer hosting SystemLayer node validity\n\n" +
       violation + "\n\n" +
       "RULE: Only SystemLayer.OS can host other SystemLayer nodes (ContainerRuntime or HyperVisor).\n\n" +
       "ALLOWED PATTERNS:\n" +
       "  SystemLayer.OS -[:hosts]-> SystemLayer.ContainerRuntime\n" +
       "  SystemLayer.OS -[:hosts]-> SystemLayer.HyperVisor\n\n" +
       "FORBIDDEN PATTERNS:\n" +
       "  SystemLayer.Firmware -[:hosts]-> SystemLayer.*\n" +
       "  SystemLayer.ContainerRuntime -[:hosts]-> SystemLayer.*\n" +
       "  SystemLayer.HyperVisor -[:hosts]-> SystemLayer.*\n\n" +
       "REMEDIATION:\n" +
       "1. Check source: Only SystemLayer.OS should host other SystemLayer nodes\n" +
       "2. Check target: Only ContainerRuntime and HyperVisor can be hosted by OS\n" +
       "3. Remove invalid [:hosts] or change node types\n" +
       "4. If needed, add intermediate SystemLayer.OS between HW and virtualization layers" AS report;

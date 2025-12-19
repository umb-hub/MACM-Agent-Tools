// Reporting query for Virtual hosts SystemLayer
MATCH (sourceNode)-[hostsRel:hosts]->(targetNode)
WITH head(labels(sourceNode)) AS sourcePrimaryLabel, head(labels(targetNode)) AS targetPrimaryLabel, sourceNode, targetNode, hostsRel
WHERE sourcePrimaryLabel = "Virtual" AND targetPrimaryLabel = "SystemLayer"
AND NOT (targetNode.type IN ["SystemLayer.OS", "SystemLayer.Firmware"])
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
WITH apoc.text.format("Invalid Virtual-to-SystemLayer hosting: %s -[:hosts]-> %s\n  Source: %s\n  Target: %s", [sourceDescription, targetDescription, coalesce(sourceNode.type, "<no-type>"), coalesce(targetNode.type, "<no-type>")]) AS violation
RETURN "Rule 7 violation: Virtual hosting SystemLayer node validity\n\n" +
       violation + "\n\n" +
       "RULE: Virtual nodes can only host SystemLayer.OS or SystemLayer.Firmware (base system layers).\n\n" +
       "ALLOWED PATTERNS:\n" +
       "  Virtual.VM -[:hosts]-> SystemLayer.OS\n" +
       "  Virtual.VM -[:hosts]-> SystemLayer.Firmware\n" +
       "  Virtual.Container -[:hosts]-> SystemLayer.OS\n" +
       "  Virtual.Container -[:hosts]-> SystemLayer.Firmware\n\n" +
       "FORBIDDEN PATTERNS:\n" +
       "  Virtual.* -[:hosts]-> SystemLayer.ContainerRuntime (ContainerRuntime should be hosted by OS)\n" +
       "  Virtual.* -[:hosts]-> SystemLayer.HyperVisor (HyperVisor should be hosted by OS)\n\n" +
       "REMEDIATION:\n" +
       "1. For virtualization layers inside VMs/Containers, create proper hierarchy:\n" +
       "   Virtual.VM -> SystemLayer.OS -> SystemLayer.HyperVisor (nested virtualization)\n" +
       "   Virtual.Container -> SystemLayer.OS -> SystemLayer.ContainerRuntime (Docker-in-Docker)\n" +
       "2. Remove direct [:hosts] from Virtual to ContainerRuntime/HyperVisor\n" +
       "3. Verify SystemLayer node type is appropriate for virtualization context\n\n" +
       "COMMON SCENARIO: A VM typically hosts an OS, which then hosts services or other system layers" AS report;

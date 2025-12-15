// Reporting query for SystemLayer hosts Service
MATCH (sourceNode)-[hostsRel:hosts]->(targetNode)
WHERE head(labels(sourceNode)) = "SystemLayer" AND head(labels(targetNode)) = "Service"
AND NOT sourceNode.type IN ["SystemLayer.Firmware", "SystemLayer.OS"]
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
WITH apoc.text.format("Invalid SystemLayer-to-Service hosting: %s -[:hosts]-> %s\n  Source: %s\n  Target: %s", [sourceDescription, targetDescription, coalesce(sourceNode.type, "<no-type>"), coalesce(targetNode.type, "<no-type>")]) AS violation
RETURN "Rule 6 violation: SystemLayer hosting Service node validity\n\n" +
       violation + "\n\n" +
       "RULE: Only SystemLayer.Firmware and SystemLayer.OS can directly host Service nodes.\n\n" +
       "ALLOWED PATTERNS:\n" +
       "  SystemLayer.Firmware -[:hosts]-> Service.*\n" +
       "  SystemLayer.OS -[:hosts]-> Service.*\n\n" +
       "FORBIDDEN PATTERNS:\n" +
       "  SystemLayer.ContainerRuntime -[:hosts]-> Service.* (Use Virtual.Container as intermediate)\n" +
       "  SystemLayer.HyperVisor -[:hosts]-> Service.* (Use Virtual.VM as intermediate)\n\n" +
       "REMEDIATION:\n" +
       "1. For services in containers: SystemLayer.ContainerRuntime -> Virtual.Container -> Service\n" +
       "2. For services in VMs: SystemLayer.HyperVisor -> Virtual.VM -> Service\n" +
       "3. For bare-metal services: SystemLayer.OS -> Service or SystemLayer.Firmware -> Service\n\n" +
       "EXAMPLE CORRECTIONS:\n" +
       "  WRONG: ContainerRuntime -[:hosts]-> WebService\n" +
       "  RIGHT: ContainerRuntime -[:hosts]-> DockerContainer, DockerContainer -[:hosts]-> WebService" AS report;

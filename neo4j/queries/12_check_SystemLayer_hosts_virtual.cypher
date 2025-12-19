// Reporting query for SystemLayer hosts Virtual
MATCH (sourceNode)-[hostsRel:hosts]->(targetNode)
WITH head(labels(sourceNode)) AS sourcePrimaryLabel, head(labels(targetNode)) AS targetPrimaryLabel, sourceNode, targetNode, hostsRel
WHERE sourcePrimaryLabel = "SystemLayer" AND targetPrimaryLabel = "Virtual"
AND NOT (
  (sourceNode.type = "SystemLayer.ContainerRuntime" AND targetNode.type = "Virtual.Container") OR
  (sourceNode.type = "SystemLayer.HyperVisor" AND targetNode.type = "Virtual.VM")
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
WITH apoc.text.format("Invalid SystemLayer-to-Virtual hosting: %s -[:hosts]-> %s\n  Source: %s\n  Target: %s", [sourceDescription, targetDescription, coalesce(sourceNode.type, "<no-type>"), coalesce(targetNode.type, "<no-type>")]) AS violation
RETURN "Rule 5 violation: SystemLayer hosting Virtual node validity\n\n" +
       violation + "\n\n" +
       "RULE: SystemLayer can host Virtual only with matching virtualization technology.\n\n" +
       "ALLOWED PATTERNS:\n" +
       "  SystemLayer.ContainerRuntime -[:hosts]-> Virtual.Container\n" +
       "  SystemLayer.HyperVisor -[:hosts]-> Virtual.VM\n\n" +
       "FORBIDDEN PATTERNS:\n" +
       "  SystemLayer.ContainerRuntime -[:hosts]-> Virtual.VM (Wrong: ContainerRuntime cannot host VMs)\n" +
       "  SystemLayer.HyperVisor -[:hosts]-> Virtual.Container (Wrong: HyperVisor cannot host Containers)\n" +
       "  SystemLayer.OS -[:hosts]-> Virtual.* (Wrong: OS should host ContainerRuntime/HyperVisor, not Virtual directly)\n\n" +
       "REMEDIATION:\n" +
       "1. Verify technology match: ContainerRuntime <-> Container, HyperVisor <-> VM\n" +
       "2. Check hierarchy: HW -> OS -> ContainerRuntime/HyperVisor -> Virtual\n" +
       "3. Add missing intermediate layers if needed\n" +
       "4. Correct node types to match actual virtualization technology" AS report;

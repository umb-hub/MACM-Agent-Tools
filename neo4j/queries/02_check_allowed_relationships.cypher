// Reporting query for allowed relationship patterns
WITH [
    ["Party", "interacts", "Service"],
    ["Party", "interacts", "HW"],
    ["Party", "interacts", "Network"],
    ["Party", "interacts", "Party"],
    ["Party", "interacts", "Virtual"],
    ["Party", "interacts", "SystemLayer"],
    ["Party", "interacts", "CSP"],
    ["Service", "uses", "Service"],
    ["Service", "uses", "Virtual"],
    ["Service", "hosts", "Service"],
    ["Virtual", "hosts", "SystemLayer"],
    ["SystemLayer", "hosts", "SystemLayer"],
    ["SystemLayer", "hosts", "Virtual"],
    ["SystemLayer", "hosts", "Service"],
    ["SystemLayer", "hosts", "Network"],
    ["SystemLayer", "uses", "HW"],
    ["HW", "hosts", "HW"],
    ["HW", "hosts", "SystemLayer"],
    ["CSP", "provides", "Service"],
    ["CSP", "provides", "Network"],
    ["CSP", "provides", "HW"],
    ["CSP", "provides", "Virtual"],
    ["CSP", "provides", "SystemLayer"],
    ["Network", "connects", "Network"],
    ["Network", "connects", "Virtual"],
    ["Network", "connects", "HW"],
    ["Network", "connects", "CSP"]
] AS allowedPatterns

WITH allowedPatterns, ["Party","CSP","HW","Network","Service","Virtual","SystemLayer","Data"] AS macroLabels
MATCH ()-[rel]->()
WITH allowedPatterns, macroLabels, rel,
     startNode(rel) AS sourceNode,
     type(rel) AS relationshipType,
     endNode(rel) AS targetNode

WITH rel, relationshipType, sourceNode, targetNode,
     [label IN macroLabels WHERE label IN labels(sourceNode)][0] AS sourcePrimaryLabel,
     [label IN macroLabels WHERE label IN labels(targetNode)][0] AS targetPrimaryLabel

WHERE NOT any(pattern IN allowedPatterns WHERE pattern[0] = sourcePrimaryLabel AND pattern[1] = relationshipType AND pattern[2] = targetPrimaryLabel)

WITH rel, relationshipType, sourceNode, targetNode,
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
     END AS targetDescription,
     coalesce(sourcePrimaryLabel, "<no-primary-label>") AS spl,
     coalesce(targetPrimaryLabel, "<no-primary-label>") AS tpl

WITH apoc.text.format("Unauthorized relationship: %s -[:%s]-> %s (Pattern: %s -[:%s]-> %s is not allowed)", [sourceDescription, relationshipType, targetDescription, spl, relationshipType, tpl]) AS violationDetail
RETURN "Rule 2 violation: Relationship validity patterns\n\n" +
       "VIOLATION: " + violationDetail + "\n\n" +
       "ALLOWED RELATIONSHIP PATTERNS:\n" +
       "Party -> [:interacts] -> Service|HW|Network|Party|Virtual|SystemLayer|CSP\n" +
       "Service -> [:uses] -> Service|Virtual\n" +
       "Service -> [:hosts] -> Service\n" +
       "Virtual -> [:hosts] -> SystemLayer\n" +
       "SystemLayer -> [:hosts] -> SystemLayer|Virtual|Service|Network\n" +
       "SystemLayer -> [:uses] -> HW\n" +
       "HW -> [:hosts] -> HW|SystemLayer\n" +
       "CSP -> [:provides] -> Service|Network|HW|Virtual|SystemLayer\n" +
       "Network -> [:connects] -> Network|Virtual|HW|CSP\n\n" +
       "REMEDIATION: Remove the unauthorized relationship or change node types/labels to match an allowed pattern." AS report;

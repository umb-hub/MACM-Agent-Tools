// Reporting query for single host per Service
MATCH (s:Service)
OPTIONAL MATCH (hoster)-[r]->(s)
WHERE type(r) IN ["hosts","provides"]
WITH s, COUNT(DISTINCT hoster) AS numHosts, collect(DISTINCT hoster) AS hosters
WHERE numHosts <> 1
WITH s, numHosts, hosters,
     CASE 
        WHEN s.component_id IS NOT NULL AND s.name IS NOT NULL 
        THEN "Service[component_id: " + s.component_id + ", name: " + s.name + "]"
        WHEN s.component_id IS NOT NULL 
        THEN "Service[component_id: " + s.component_id + "]"
        WHEN s.name IS NOT NULL 
        THEN "Service[name: " + s.name + "]"
        ELSE "Service[id: " + toString(id(s)) + "]"
     END AS serviceDesc,
     CASE 
        WHEN numHosts = 0 
        THEN " has NO host/provide relationship.\n  FIX: Add exactly ONE [:hosts] or [:provides] from SystemLayer, Virtual, CSP, or Service."
        ELSE " has " + toString(numHosts) + " host/provide relationships: [" + 
             apoc.text.join([h IN hosters | coalesce(h.name, h.component_id, toString(id(h)))], ", ") + 
             "].\n  FIX: Remove " + toString(numHosts - 1) + " relationship(s) to leave exactly ONE incoming."
     END AS violationDetail
WITH "Rule 1 violation: Single host/provide per service\n\n" +
     serviceDesc + violationDetail + "\n\n" +
     "REQUIREMENT: Each Service must be connected by exactly one [:hosts] or [:provides].\n\n" +
     "REMEDIATION:\n" +
     "- If 0 hosts: Create [:hosts] from SystemLayer/Virtual/Service or [:provides] from CSP\n" +
     "- If 2+ hosts: Remove extra relationships, keeping only the most appropriate one" AS report
RETURN report;

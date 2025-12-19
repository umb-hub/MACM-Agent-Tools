// Reporting query for single host/provide for SystemLayer
MATCH (s:SystemLayer)
OPTIONAL MATCH (hoster)-[r]->(s)
WHERE type(r) IN ["hosts","provides"]
WITH s, COUNT(DISTINCT hoster) AS numHosts, collect(DISTINCT hoster) AS hosters
WHERE numHosts <> 1
WITH s, numHosts, hosters,
     CASE 
        WHEN s.component_id IS NOT NULL AND s.name IS NOT NULL 
        THEN "SystemLayer[component_id: " + s.component_id + ", name: " + s.name + ", type: " + coalesce(s.type, "<no-type>") + "]"
        WHEN s.component_id IS NOT NULL 
        THEN "SystemLayer[component_id: " + s.component_id + ", type: " + coalesce(s.type, "<no-type>") + "]"
        WHEN s.name IS NOT NULL 
        THEN "SystemLayer[name: " + s.name + ", type: " + coalesce(s.type, "<no-type>") + "]"
        ELSE "SystemLayer[id: " + toString(id(s)) + ", type: " + coalesce(s.type, "<no-type>") + "]"
     END AS systemLayerDesc,
     CASE 
        WHEN numHosts = 0 
        THEN " has NO host/provide relationship.\n  FIX: Add exactly ONE [:hosts] or [:provides] from HW, SystemLayer, Virtual, or CSP."
        ELSE " has " + toString(numHosts) + " host/provide relationships: [" + 
             apoc.text.join([h IN hosters | coalesce(h.name, h.component_id, toString(id(h)))], ", ") + 
             "].\n  FIX: Remove " + toString(numHosts - 1) + " relationship(s) to leave exactly ONE incoming."
     END AS violationDetail
WITH "Rule 10 violation: Single host/provide per SystemLayer\n\n" +
     systemLayerDesc + violationDetail + "\n\n" +
     "REQUIREMENT: Every SystemLayer must have exactly one incoming [:hosts] or [:provides].\n\n" +
     "REMEDIATION GUIDE:\n" +
     "- SystemLayer.Firmware -> hosted by HW\n" +
     "- SystemLayer.OS -> hosted by HW or Virtual\n" +
     "- SystemLayer.HyperVisor -> hosted by SystemLayer.OS\n" +
     "- SystemLayer.ContainerRuntime -> hosted by SystemLayer.OS\n" +
     "- Or use [:provides] from CSP for cloud-managed system layers" AS report
RETURN report;

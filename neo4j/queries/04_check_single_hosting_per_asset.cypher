// Reporting query for single hosting per asset (max 1 host/provide)
MATCH (hoster)-[r]->(asset)
WHERE type(r) IN ["hosts","provides"]
WITH asset, COUNT(DISTINCT hoster) AS numHosts, collect(DISTINCT hoster) AS hosters
WHERE numHosts > 1
WITH asset, numHosts, hosters,
     CASE 
        WHEN asset.component_id IS NOT NULL AND asset.name IS NOT NULL 
        THEN head(labels(asset)) + "[component_id: " + asset.component_id + ", name: " + asset.name + ", type: " + coalesce(asset.type, "<no-type>") + "]"
        WHEN asset.component_id IS NOT NULL 
        THEN head(labels(asset)) + "[component_id: " + asset.component_id + ", type: " + coalesce(asset.type, "<no-type>") + "]"
        WHEN asset.name IS NOT NULL 
        THEN head(labels(asset)) + "[name: " + asset.name + ", type: " + coalesce(asset.type, "<no-type>") + "]"
        ELSE head(labels(asset)) + "[id: " + toString(id(asset)) + ", type: " + coalesce(asset.type, "<no-type>") + "]"
     END AS assetDesc,
     " has " + toString(numHosts) + " host/provide relationships: [" + 
     apoc.text.join([h IN hosters | coalesce(h.name, h.component_id, toString(id(h)))], ", ") + 
     "].\\n  FIX: Remove " + toString(numHosts - 1) + " to leave AT MOST ONE." AS violationDetail
WITH "Rule 2 violation: Single Hosting/Providing per Asset\\n\\n" +
     assetDesc + violationDetail + "\\n\\n" +
     "REQUIREMENT: No asset should have multiple hosts/providers simultaneously.\\n\\n" +
     "REMEDIATION:\\n" +
     "1. Identify the correct/primary host\\n" +
     "2. Remove extra [:hosts] or [:provides] relationships\\n" +
     "3. Keep only the most direct hosting relationship\\n\\n" +
     "COMMON SCENARIOS:\\n" +
     "- Service hosted by both OS and Container: Keep Container -> Service\\n" +
     "- Resource from multiple CSPs: Choose primary CSP\\n" +
     "- Component with physical and virtual host: Clarify architecture" AS report
RETURN report;

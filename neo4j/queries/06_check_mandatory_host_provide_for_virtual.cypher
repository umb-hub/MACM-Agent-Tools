// Reporting query for mandatory host/provide for Virtual
MATCH (v:Virtual)
OPTIONAL MATCH (hoster)-[r]->(v)
WHERE type(r) IN ["hosts","provides"]
WITH v, COUNT(DISTINCT hoster) AS numHosts
WHERE numHosts < 1
WITH v,
     CASE 
        WHEN v.component_id IS NOT NULL AND v.name IS NOT NULL 
        THEN "Virtual[component_id: " + v.component_id + ", name: " + v.name + ", type: " + coalesce(v.type, "<no-type>") + "]"
        WHEN v.component_id IS NOT NULL 
        THEN "Virtual[component_id: " + v.component_id + ", type: " + coalesce(v.type, "<no-type>") + "]"
        WHEN v.name IS NOT NULL 
        THEN "Virtual[name: " + v.name + ", type: " + coalesce(v.type, "<no-type>") + "]"
        ELSE "Virtual[id: " + toString(id(v)) + ", type: " + coalesce(v.type, "<no-type>") + "]"
     END AS virtualDesc
WITH "Rule 12 violation: Mandatory host/provide for Virtual\\n\\n" +
     virtualDesc + " has NO host/provide relationship.\\n\\n" +
     "REQUIREMENT: Every Virtual node must be hosted or provided by another component.\\n\\n" +
     "REMEDIATION:\\n" +
     "- Virtual.Container: Add [:hosts] from SystemLayer.ContainerRuntime\\n" +
     "  Example: Docker -[:hosts]-> MyAppContainer\\n" +
     "- Virtual.VM: Add [:hosts] from SystemLayer.HyperVisor\\n" +
     "  Example: VMware -[:hosts]-> MyVM\\n" +
     "- Cloud-managed: Add [:provides] from CSP\\n" +
     "  Example: AWS -[:provides]-> EC2Instance\\n\\n" +
     "HIERARCHY: Hardware -> OS -> ContainerRuntime/HyperVisor -> Virtual -> Services" AS report
RETURN report;

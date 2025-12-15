CALL apoc.trigger.add(
	'11_check_single_host_provide_for_systemlayer',
	'
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
			THEN " has NO host/provide relationship.\\n  FIX: Add exactly ONE [:hosts] or [:provides] relationship from a HW, SystemLayer, Virtual, or CSP node to this SystemLayer."
			ELSE " has " + toString(numHosts) + " host/provide relationships: [" + 
				 apoc.text.join([h IN hosters | coalesce(h.name, h.component_id, toString(id(h)))], ", ") + 
				 "].\\n  FIX: Remove " + toString(numHosts - 1) + " relationship(s) to leave exactly ONE [:hosts] or [:provides] incoming."
		 END AS violationDetail
	WITH collect(systemLayerDesc + violationDetail) AS violations
	CALL apoc.util.validate(
		size(violations) > 0,
		"/*Rule 10 violation: Single host/provide per SystemLayer - Each SystemLayer node must be connected by exactly one [:hosts] or [:provides] relationship.\\n\\n" + 
		"VIOLATIONS:\\n" +
		apoc.text.join(violations, "\\n\\n") + 
		"\\n\\nREQUIREMENT: Every SystemLayer node must have exactly one incoming [:hosts] or [:provides] relationship.\\n" +
		"\\nREMEDIATION GUIDE:\\n" +
		"- If a SystemLayer has 0 hosts: Create appropriate hosting relationship based on type:\\n" +
		"  * SystemLayer.Firmware -> hosted by HW nodes\\n" +
		"  * SystemLayer.OS -> hosted by HW or Virtual nodes\\n" +
		"  * SystemLayer.HyperVisor -> hosted by SystemLayer.OS\\n" +
		"  * SystemLayer.ContainerRuntime -> hosted by SystemLayer.OS\\n" +
		"  * Or use [:provides] from CSP for cloud-managed system layers\\n" +
		"- If a SystemLayer has 2+ hosts: Keep only the most direct hosting relationship\\n" +
		"\\nEXAMPLES:\\n" +
		"  HW.Server -[:hosts]-> SystemLayer.OS\\n" +
		"  SystemLayer.OS -[:hosts]-> SystemLayer.ContainerRuntime\\n" +
		"  Virtual.VM -[:hosts]-> SystemLayer.OS\\n" +
		"  CSP -[:provides]-> SystemLayer.OS (for managed OS services)*/",
		[]
	)
	RETURN true
	',
	{phase:'before'}
);
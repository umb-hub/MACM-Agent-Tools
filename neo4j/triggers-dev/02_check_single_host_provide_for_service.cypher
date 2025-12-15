CALL apoc.trigger.add(
	'02_check_single_host_provide_for_service',
	'
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
			THEN " has NO host/provide relationship.\\n  FIX: Add exactly ONE [:hosts] or [:provides] relationship from a SystemLayer, Virtual, CSP, or Service node to this Service."
			ELSE " has " + toString(numHosts) + " host/provide relationships: [" + 
				 apoc.text.join([h IN hosters | coalesce(h.name, h.component_id, toString(id(h)))], ", ") + 
				 "].\\n  FIX: Remove " + toString(numHosts - 1) + " relationship(s) to leave exactly ONE [:hosts] or [:provides] incoming."
		 END AS violationDetail
	WITH collect(serviceDesc + violationDetail) AS violations
	CALL apoc.util.validate(
		size(violations) > 0,
		"/*Rule 1 violation: Single host/provide per service - Each Service node must be connected by exactly one [:hosts] or [:provides] relationship.\\n\\nViolations found:\\n" + 
		apoc.text.join(violations, "\\n\\n") + "\\n\\nREMEDIATION GUIDE:\\n" +
		"- If a service has 0 hosts: Create a [:hosts] relationship from SystemLayer/Virtual/Service or [:provides] from CSP.\\n" +
		"- If a service has 2+ hosts: Remove extra relationships, keeping only the most appropriate one.*/",
		[]
	)
	RETURN true
	',
	{phase:'before'}
);
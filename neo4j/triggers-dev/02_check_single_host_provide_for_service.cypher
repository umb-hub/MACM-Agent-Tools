CALL apoc.trigger.add(
	'03_check_mandatory_host_provide_for_service',
	'
	// Constraint 3: Mandatory host/provide per service (min 1 host)
	MATCH (s:Service)
	OPTIONAL MATCH (hoster)-[r]->(s)
	WHERE type(r) IN ["hosts","provides"]
	WITH s, COUNT(DISTINCT hoster) AS numHosts
	WHERE numHosts < 1
	WITH s,
		 CASE 
			WHEN s.component_id IS NOT NULL AND s.name IS NOT NULL 
			THEN "Service[component_id: " + s.component_id + ", name: " + s.name + "]"
			WHEN s.component_id IS NOT NULL 
			THEN "Service[component_id: " + s.component_id + "]"
			WHEN s.name IS NOT NULL 
			THEN "Service[name: " + s.name + "]"
			ELSE "Service[id: " + toString(id(s)) + "]"
		 END AS serviceDesc
	WITH collect(serviceDesc) AS violations
	CALL apoc.util.validate(
		size(violations) > 0,
		"/*Rule 3 violation: the following service do not have a host/provider: " + apoc.text.join(violations, ", ") + 
		"\\n\\nREQUIREMENT: Every Service must have exactly ONE incoming [:hosts] or [:provides] relationship.\\n" +
		"FIX: Add a [:hosts] or [:provides] relationship from a SystemLayer, Virtual, CSP, or Service node to each violating Service.*/",
		[]
	)
	RETURN true
	',
	{phase:'before'}
);
CALL apoc.trigger.add(
	'11_check_single_host_provide_for_systemlayer',
	'
	MATCH (s:SystemLayer)
	OPTIONAL MATCH (hoster)-[r]->(s)
	WHERE type(r) IN ["hosts","provides"]
	WITH s, COUNT(DISTINCT hoster) AS numHosts
	WHERE numHosts <> 1
	WITH s, numHosts,
		 CASE 
			WHEN s.component_id IS NOT NULL AND s.name IS NOT NULL 
			THEN "Service[component_id: " + s.component_id + ", name: " + s.name + "] has " + toString(numHosts) + " host(s)"
			WHEN s.component_id IS NOT NULL 
			THEN "Service[component_id: " + s.component_id + "] has " + toString(numHosts) + " host(s)"
			WHEN s.name IS NOT NULL 
			THEN "Service[name: " + s.name + "] has " + toString(numHosts) + " host(s)"
			ELSE "Service[id: " + toString(id(s)) + "] has " + toString(numHosts) + " host(s)"
		 END AS violationDetail
	WITH collect(violationDetail) AS violations
	CALL apoc.util.validate(
		size(violations) > 0,
		"/*Rule 11 violation: Each service must have exactly one host. The following violations were found: " + apoc.text.join(violations, "; ") + "*/",
		[]
	)
	RETURN true
	',
	{phase:'before'}
);
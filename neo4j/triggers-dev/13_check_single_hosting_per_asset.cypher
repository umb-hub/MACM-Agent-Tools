CALL apoc.trigger.add(
	'02_check_single_host_provide_per_asset',
	'
	// Constraint 2: Single Hosting/Providing per Asset (max 1 host)
	MATCH (hoster)-[r]->(s)
	WHERE type(r) IN ["hosts","provides"]
	WITH s, COUNT(DISTINCT hoster) AS numHosts, collect(DISTINCT hoster) AS hosters
	WHERE numHosts > 1
	WITH s, numHosts, hosters,
		 CASE 
			WHEN s.component_id IS NOT NULL AND s.name IS NOT NULL 
			THEN head(labels(s)) + "[component_id: " + s.component_id + ", name: " + s.name + ", type: " + coalesce(s.type, "<no-type>") + "]"
			WHEN s.component_id IS NOT NULL 
			THEN head(labels(s)) + "[component_id: " + s.component_id + ", type: " + coalesce(s.type, "<no-type>") + "]"
			WHEN s.name IS NOT NULL 
			THEN head(labels(s)) + "[name: " + s.name + ", type: " + coalesce(s.type, "<no-type>") + "]"
			ELSE head(labels(s)) + "[id: " + toString(id(s)) + ", type: " + coalesce(s.type, "<no-type>") + "]"
		 END AS assetDesc,
		 " has " + toString(numHosts) + " host/provide relationships: [" + 
		 apoc.text.join([h IN hosters | coalesce(h.name, h.component_id, toString(id(h)))], ", ") + 
		 "].\\n  FIX: Remove " + toString(numHosts - 1) + " relationship(s) to leave AT MOST ONE [:hosts] or [:provides] incoming." AS violationDetail
	WITH collect(assetDesc + violationDetail) AS violations
	CALL apoc.util.validate(
		size(violations) > 0,
		"/*Rule 2 violation: Single Hosting/Providing per Asset - Each asset can have AT MOST one incoming [:hosts] or [:provides] relationship.\\n\\n" + 
		"VIOLATIONS:\\n" +
		apoc.text.join(violations, "\\n\\n") + 
		"\\n\\nREQUIREMENT: No asset should have multiple hosts or providers simultaneously.\\n" +
		"This ensures clear ownership and prevents ambiguous deployment scenarios.\\n\\n" +
		"REMEDIATION:\\n" +
		"1. Identify the correct/primary host for the asset\\n" +
		"2. Remove extra [:hosts] or [:provides] relationships\\n" +
		"3. Keep only the most direct or appropriate hosting relationship\\n\\n" +
		"COMMON SCENARIOS:\\n" +
		"- Service hosted by both OS and Container: Keep Container -> Service, remove OS -> Service\\n" +
		"- Resource provided by multiple CSPs: Choose primary CSP, remove others\\n" +
		"- Component with both physical and virtual host: Clarify architecture, keep one*/",
		[]
	)
	RETURN true
	',
	{phase:'before'}
);

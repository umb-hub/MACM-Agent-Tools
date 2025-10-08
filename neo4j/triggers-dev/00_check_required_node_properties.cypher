CALL apoc.trigger.add(
	'00_check_required_node_properties',
	'
	UNWIND coalesce($createdNodes, []) AS n
	WITH n, [] AS errors
	
	// Check if component_id is present and is a string
	WITH n, 
		 CASE 
			WHEN n.component_id IS NULL 
			THEN errors + ["Missing required property: component_id"]
			WHEN NOT (n.component_id IS :: STRING)
			THEN errors + ["component_id must be a string, found: " + apoc.text.format("%s (%s)", [toString(n.component_id), apoc.meta.type(n.component_id)])]
			ELSE errors
		 END AS errors
	
    // Check if component_id is numeric (when it exists and is a string)
    WITH n,
         CASE 
            WHEN n.component_id IS NOT NULL AND (n.component_id IS :: STRING) AND NOT apoc.text.regexMatches(n.component_id, "^[0-9]+$")
            THEN errors + ["component_id must be numeric (string containing only digits), found: " + n.component_id]
            WHEN n.component_id IS NOT NULL AND (n.component_id IS :: STRING) AND apoc.text.regexMatches(n.component_id, "^[0-9]+$") AND toInteger(n.component_id) <= 0
            THEN errors + ["component_id must be greater than 0, found: " + n.component_id]
            ELSE errors
         END AS errors
	
	// Check if primary_label is present
	WITH n,
		 CASE 
			WHEN n.primary_label IS NULL 
			THEN errors + ["Missing required property: primary_label"]
			WHEN NOT (n.primary_label IS :: STRING)
			THEN errors + ["primary_label must be a string, found: " + apoc.text.format("%s (%s)", [toString(n.primary_label), apoc.meta.type(n.primary_label)])]
			ELSE errors
		 END AS errors
	
	// Check if type is present
	WITH n,
		 CASE 
			WHEN n.type IS NULL 
			THEN errors + ["Missing required property: type"]
			WHEN NOT (n.type IS :: STRING)
			THEN errors + ["type must be a string, found: " + apoc.text.format("%s (%s)", [toString(n.type), apoc.meta.type(n.type)])]
			ELSE errors
		 END AS errors
	
	// Create detailed error report for each node that has errors
	WITH n, errors
	WHERE size(errors) > 0
	WITH n, 
		 CASE 
			WHEN n.component_id IS NOT NULL AND n.name IS NOT NULL 
			THEN apoc.text.format("Node[component_id: %s, name: %s, labels: %s]:", [n.component_id, n.name, apoc.text.join(labels(n), ",")])
			WHEN n.component_id IS NOT NULL 
			THEN apoc.text.format("Node[component_id: %s, labels: %s]:", [n.component_id, apoc.text.join(labels(n), ",")])
			WHEN n.name IS NOT NULL 
			THEN apoc.text.format("Node[name: %s, labels: %s]:", [n.name, apoc.text.join(labels(n), ",")])
			ELSE apoc.text.format("Node[id: %s, labels: %s]:", [toString(id(n)), apoc.text.join(labels(n), ",")])
		 END AS nodeHeader,
		 [i IN range(0, size(errors)-1) | "  " + toString(i+1) + ". " + errors[i]] AS numberedErrors
	WITH collect(nodeHeader + "\\n" + apoc.text.join(numberedErrors, "\\n")) AS allNodeReports
	
	// Validate with detailed per-node error reporting
	CALL apoc.util.validate(
		size(allNodeReports) > 0,
		"/*Rule 0 violation: Required node properties validation failed:\\n\\n" + apoc.text.join(allNodeReports, "\\n\\n") + "*/",
		[]
	)
	RETURN true
	',
	{phase:'before'}
);
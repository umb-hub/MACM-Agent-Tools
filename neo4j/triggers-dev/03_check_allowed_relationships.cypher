CALL apoc.trigger.add(
	'03_check_allowed_relationships',
	'
	// Define allowed relationship patterns: [source_primary_label, relationship_type, target_primary_label]
	WITH [
		["Party", "interacts", "Service"],
		["Party", "interacts", "HW"],
		["Party", "interacts", "Network"],
		["Party", "interacts", "Party"],
		["Party", "interacts", "Virtual"],
		["Party", "interacts", "SystemLayer"],
		["Party", "interacts", "CSP"],
		["Service", "uses", "Service"],
		["Service", "uses", "Virtual"],
		["Service", "hosts", "Service"],
		["Virtual", "hosts", "SystemLayer"],
		["SystemLayer", "hosts", "SystemLayer"],
		["SystemLayer", "hosts", "Virtual"],
		["SystemLayer", "hosts", "Service"],
		["SystemLayer", "hosts", "Network"],
		["SystemLayer", "uses", "HW"],
		["HW", "hosts", "HW"],
		["HW", "hosts", "SystemLayer"],
		["CSP", "provides", "Service"],
		["CSP", "provides", "Network"],
		["CSP", "provides", "HW"],
		["CSP", "provides", "Virtual"],
		["CSP", "provides", "SystemLayer"],
		["Network", "connects", "Network"],
		["Network", "connects", "Virtual"],
		["Network", "connects", "HW"],
		["Network", "connects", "CSP"]
	] AS allowedPatterns
	
	// Get created relationships and macro labels
	WITH allowedPatterns, 
		 coalesce($createdRelationships, []) AS createdRels,
		 ["Party","CSP","HW","Network","Service","Virtual","SystemLayer","Data"] AS macroLabels
	
	// Process each created relationship
	UNWIND createdRels AS rel
	WITH allowedPatterns, macroLabels, rel,
		 startNode(rel) AS sourceNode,
		 type(rel) AS relationshipType,
		 endNode(rel) AS targetNode
	
	// Extract primary labels from source and target nodes
	WITH allowedPatterns, rel, relationshipType, sourceNode, targetNode,
		 [label IN macroLabels WHERE label IN labels(sourceNode)][0] AS sourcePrimaryLabel,
		 [label IN macroLabels WHERE label IN labels(targetNode)][0] AS targetPrimaryLabel
	
	// Check if relationship pattern is allowed
	WITH rel, relationshipType, sourceNode, targetNode, sourcePrimaryLabel, targetPrimaryLabel,
		 NOT any(pattern IN allowedPatterns WHERE 
			pattern[0] = sourcePrimaryLabel AND 
			pattern[1] = relationshipType AND 
			pattern[2] = targetPrimaryLabel
		) AS isViolation
	
	// Collect violations with detailed information
	WHERE isViolation
	WITH rel, relationshipType, sourceNode, targetNode, sourcePrimaryLabel, targetPrimaryLabel,
		 // Build detailed source node description
		 CASE 
			WHEN sourceNode.component_id IS NOT NULL AND sourceNode.name IS NOT NULL 
			THEN apoc.text.format("Node[component_id: %s, name: %s, labels: %s]", 
				[sourceNode.component_id, sourceNode.name, apoc.text.join(labels(sourceNode), ",")])
			WHEN sourceNode.component_id IS NOT NULL 
			THEN apoc.text.format("Node[component_id: %s, labels: %s]", 
				[sourceNode.component_id, apoc.text.join(labels(sourceNode), ",")])
			WHEN sourceNode.name IS NOT NULL 
			THEN apoc.text.format("Node[name: %s, labels: %s]", 
				[sourceNode.name, apoc.text.join(labels(sourceNode), ",")])
			ELSE apoc.text.format("Node[id: %s, labels: %s]", 
				[toString(id(sourceNode)), apoc.text.join(labels(sourceNode), ",")])
		 END AS sourceDescription,
		 // Build detailed target node description
		 CASE 
			WHEN targetNode.component_id IS NOT NULL AND targetNode.name IS NOT NULL 
			THEN apoc.text.format("Node[component_id: %s, name: %s, labels: %s]", 
				[targetNode.component_id, targetNode.name, apoc.text.join(labels(targetNode), ",")])
			WHEN targetNode.component_id IS NOT NULL 
			THEN apoc.text.format("Node[component_id: %s, labels: %s]", 
				[targetNode.component_id, apoc.text.join(labels(targetNode), ",")])
			WHEN targetNode.name IS NOT NULL 
			THEN apoc.text.format("Node[name: %s, labels: %s]", 
				[targetNode.name, apoc.text.join(labels(targetNode), ",")])
			ELSE apoc.text.format("Node[id: %s, labels: %s]", 
				[toString(id(targetNode)), apoc.text.join(labels(targetNode), ",")])
		 END AS targetDescription
	
	// Create detailed violation message
	WITH apoc.text.format("Unauthorized relationship: %s -[:%s]-> %s (Pattern: %s -[:%s]-> %s is not allowed)", 
		[sourceDescription, relationshipType, targetDescription, 
		 coalesce(sourcePrimaryLabel, "<no-primary-label>"), 
		 relationshipType, 
		 coalesce(targetPrimaryLabel, "<no-primary-label>")]) AS violationDetail
	
	WITH collect(violationDetail) AS violations
	
	// Validate with detailed error reporting
	CALL apoc.util.validate(
		size(violations) > 0,
		"/*Rule 3 violation: Relationship validation failed. The following unauthorized relationships were found:\\n\\n" + 
		apoc.text.join(violations, "\\n\\n") + "*/",
		[]
	)
	RETURN true
	',
	{phase:'before'}
);
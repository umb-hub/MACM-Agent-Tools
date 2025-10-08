CALL apoc.trigger.add(
	'08_check_virtual_hosts_SystemLayer',
	'
	// Check Virtual to SystemLayer hosting relationships
	MATCH (sourceNode)-[hostsRel:hosts]->(targetNode)
	WITH head(labels(sourceNode)) AS sourcePrimaryLabel,
		 head(labels(targetNode)) AS targetPrimaryLabel,
		 sourceNode, targetNode, hostsRel
	WHERE sourcePrimaryLabel = "Virtual"
	AND targetPrimaryLabel = "SystemLayer"
	
	// Check if the hosting relationship follows allowed patterns
	// Virtual nodes can only host SystemLayer.OS and SystemLayer.Firmware
	AND NOT (targetNode.type IN ["SystemLayer.OS", "SystemLayer.Firmware"])
	
	// Build detailed source node description
	WITH sourceNode, targetNode, hostsRel,
		 CASE 
			WHEN sourceNode.component_id IS NOT NULL AND sourceNode.name IS NOT NULL 
			THEN apoc.text.format("Node[component_id: %s, name: %s, type: %s, labels: %s]", 
				[sourceNode.component_id, sourceNode.name, coalesce(sourceNode.type, "<no-type>"), apoc.text.join(labels(sourceNode), ",")])
			WHEN sourceNode.component_id IS NOT NULL 
			THEN apoc.text.format("Node[component_id: %s, type: %s, labels: %s]", 
				[sourceNode.component_id, coalesce(sourceNode.type, "<no-type>"), apoc.text.join(labels(sourceNode), ",")])
			WHEN sourceNode.name IS NOT NULL 
			THEN apoc.text.format("Node[name: %s, type: %s, labels: %s]", 
				[sourceNode.name, coalesce(sourceNode.type, "<no-type>"), apoc.text.join(labels(sourceNode), ",")])
			ELSE apoc.text.format("Node[id: %s, type: %s, labels: %s]", 
				[toString(id(sourceNode)), coalesce(sourceNode.type, "<no-type>"), apoc.text.join(labels(sourceNode), ",")])
		 END AS sourceDescription,
		 // Build detailed target node description
		 CASE 
			WHEN targetNode.component_id IS NOT NULL AND targetNode.name IS NOT NULL 
			THEN apoc.text.format("Node[component_id: %s, name: %s, type: %s, labels: %s]", 
				[targetNode.component_id, targetNode.name, coalesce(targetNode.type, "<no-type>"), apoc.text.join(labels(targetNode), ",")])
			WHEN targetNode.component_id IS NOT NULL 
			THEN apoc.text.format("Node[component_id: %s, type: %s, labels: %s]", 
				[targetNode.component_id, coalesce(targetNode.type, "<no-type>"), apoc.text.join(labels(targetNode), ",")])
			WHEN targetNode.name IS NOT NULL 
			THEN apoc.text.format("Node[name: %s, type: %s, labels: %s]", 
				[targetNode.name, coalesce(targetNode.type, "<no-type>"), apoc.text.join(labels(targetNode), ",")])
			ELSE apoc.text.format("Node[id: %s, type: %s, labels: %s]", 
				[toString(id(targetNode)), coalesce(targetNode.type, "<no-type>"), apoc.text.join(labels(targetNode), ",")])
		 END AS targetDescription
	
	// Create detailed violation message
	WITH apoc.text.format(
		"Invalid Virtual-to-SystemLayer hosting relationship: %s -[:hosts]-> %s\\n" +
		"  Source type: %s\\n" +
		"  Target type: %s\\n" +
		"  Rule: Virtual nodes can only host SystemLayer.OS and SystemLayer.Firmware (base system layers)",
		[
			sourceDescription,
			targetDescription,
			coalesce(sourceNode.type, "<no-type>"),
			coalesce(targetNode.type, "<no-type>")
		]
	) AS violationDetail
	
	// Collect all violations
	WITH collect(violationDetail) AS violations
	
	// Validate with detailed error reporting
	CALL apoc.util.validate(
		size(violations) > 0,
		"/*Rule 8 violation: Virtual-to-SystemLayer hosting relationship validation failed. " +
		"Virtual nodes can only host base system layer components (OS and Firmware).\\n\\n" +
		apoc.text.join(violations, "\\n\\n") + "*/",
		[]
	)
	RETURN true
	',
	{phase: 'before'}
);
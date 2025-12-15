CALL apoc.trigger.add(
	'05_check_SystemLayer_hosts_SystemLayer',
	'
	// Check SystemLayer to SystemLayer hosting relationships
	MATCH (sourceNode)-[hostsRel:hosts]->(targetNode)
	WITH head(labels(sourceNode)) AS sourcePrimaryLabel, 
		 head(labels(targetNode)) AS targetPrimaryLabel, 
		 sourceNode, targetNode, hostsRel
	WHERE sourcePrimaryLabel = "SystemLayer"
	AND targetPrimaryLabel = "SystemLayer"
	
	// Check if the hosting relationship follows allowed patterns
	// Allowed: SystemLayer.OS can host SystemLayer.ContainerRuntime or SystemLayer.HyperVisor
	AND NOT (
		sourceNode.type = "SystemLayer.OS" AND
		targetNode.type IN ["SystemLayer.ContainerRuntime", "SystemLayer.HyperVisor"]
	)
	
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
		"Invalid SystemLayer hosting relationship: %s -[:hosts]-> %s\\n" +
		"  Source type: %s\\n" +
		"  Target type: %s\\n" +
		"  Rule: Only SystemLayer.OS can host other SystemLayer nodes (specifically SystemLayer.ContainerRuntime or SystemLayer.HyperVisor)",
		[
			sourceDescription,
			targetDescription,
			coalesce(sourceNode.type, "<no-type>"),
			coalesce(targetNode.type, "<no-type>")
		]
	) AS violationDetail
	
	// Collect all violations
	WITH collect(violationDetail) AS violations
	
	// Validate with detailed error reporting and remediation guide
	CALL apoc.util.validate(
		size(violations) > 0,
		"/*Rule 4 violation: SystemLayer hosting SystemLayer node validity - Invalid hosting relationships detected.\\n\\n" +
		"VIOLATIONS:\\n" +
		apoc.text.join(violations, "\\n\\n") + 
		"\\n\\nRULE: Only SystemLayer.OS can host other SystemLayer nodes (specifically ContainerRuntime or HyperVisor).\\n" +
		"\\nALLOWED PATTERNS:\\n" +
		"  SystemLayer.OS -[:hosts]-> SystemLayer.ContainerRuntime\\n" +
		"  SystemLayer.OS -[:hosts]-> SystemLayer.HyperVisor\\n" +
		"\\nFORBIDDEN PATTERNS (examples):\\n" +
		"  SystemLayer.Firmware -[:hosts]-> SystemLayer.* (Firmware cannot host other SystemLayer)\\n" +
		"  SystemLayer.ContainerRuntime -[:hosts]-> SystemLayer.* (ContainerRuntime cannot host SystemLayer)\\n" +
		"  SystemLayer.HyperVisor -[:hosts]-> SystemLayer.* (HyperVisor cannot host SystemLayer)\\n" +
		"\\nREMEDIATION:\\n" +
		"1. Check the source node type: Only SystemLayer.OS should host other SystemLayer nodes\\n" +
		"2. Check the target node type: Only ContainerRuntime and HyperVisor can be hosted by OS\\n" +
		"3. Remove invalid [:hosts] relationships or change node types to match allowed patterns\\n" +
		"4. If needed, add an intermediate SystemLayer.OS node between HW and virtualization layers*/",
		[]
	)
	RETURN true
	',
	{phase: 'before'}
);
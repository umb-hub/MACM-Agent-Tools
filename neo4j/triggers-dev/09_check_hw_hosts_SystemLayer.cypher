CALL apoc.trigger.add(
	'09_check_hw_hosts_SystemLayer',
	'
	// Check HW to SystemLayer hosting relationships
	MATCH (sourceNode)-[hostsRel:hosts]->(targetNode)
	WITH head(labels(sourceNode)) AS sourcePrimaryLabel,
		 head(labels(targetNode)) AS targetPrimaryLabel,
		 sourceNode, targetNode, hostsRel
	WHERE sourcePrimaryLabel = "HW"
	AND targetPrimaryLabel = "SystemLayer"
	
	// Check if the hosting relationship violates restrictions
	// HW nodes are NOT allowed to directly host SystemLayer.ContainerRuntime
	AND targetNode.type = "SystemLayer.ContainerRuntime"
	
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
		"Invalid HW-to-SystemLayer hosting relationship: %s -[:hosts]-> %s\\n" +
		"  Source type: %s\\n" +
		"  Target type: %s\\n" +
		"  Rule: Hardware nodes cannot directly host SystemLayer.ContainerRuntime. ContainerRuntime must be hosted by an OS.",
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
		"/*Rule 8 violation: Hardware hosting SystemLayer node validity - Invalid hosting relationships detected.\\n\\n" +
		"VIOLATIONS:\\n" +
		apoc.text.join(violations, "\\n\\n") + 
		"\\n\\nRULE: Hardware nodes cannot directly host SystemLayer.ContainerRuntime.\\n" +
		"\\nALLOWED PATTERNS:\\n" +
		"  HW.* -[:hosts]-> SystemLayer.Firmware\\n" +
		"  HW.* -[:hosts]-> SystemLayer.OS\\n" +
		"  HW.* -[:hosts]-> SystemLayer.HyperVisor\\n" +
		"\\nFORBIDDEN PATTERN:\\n" +
		"  HW.* -[:hosts]-> SystemLayer.ContainerRuntime (Wrong: ContainerRuntime requires OS)\\n" +
		"\\nREMEDIATION:\\n" +
		"1. Add intermediate SystemLayer.OS node: HW -> OS -> ContainerRuntime\\n" +
		"2. Verify the proper layering hierarchy for containerization:\\n" +
		"   HW.Server -[:hosts]-> SystemLayer.OS -[:hosts]-> SystemLayer.ContainerRuntime\\n" +
		"3. ContainerRuntime must always run on top of an Operating System\\n" +
		"\\nCORRECT EXAMPLE:\\n" +
		"  WRONG: HW.Server -[:hosts]-> SystemLayer.ContainerRuntime\\n" +
		"  RIGHT: HW.Server -[:hosts]-> SystemLayer.OS, SystemLayer.OS -[:hosts]-> SystemLayer.ContainerRuntime\\n" +
		"\\nRATIONALE: Container runtimes (like Docker, containerd) are software that require an OS to function*/",
		[]
	)
	RETURN true
	',
	{phase: 'before'}
);
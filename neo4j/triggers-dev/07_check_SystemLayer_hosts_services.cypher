CALL apoc.trigger.add(
	'07_check_SystemLayer_hosts_services',
	'
	// Check SystemLayer to Service hosting relationships
	MATCH (sourceNode)-[hostsRel:hosts]->(targetNode)
	WHERE head(labels(sourceNode)) = "SystemLayer"
	AND head(labels(targetNode)) = "Service"
	
	// Check if the hosting relationship follows allowed patterns
	// Only SystemLayer.Firmware and SystemLayer.OS are allowed to host Service nodes
	AND NOT sourceNode.type IN ["SystemLayer.Firmware", "SystemLayer.OS"]
	
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
		"Invalid SystemLayer-to-Service hosting relationship: %s -[:hosts]-> %s\\n" +
		"  Source type: %s\\n" +
		"  Target type: %s\\n" +
		"  Rule: Only SystemLayer.Firmware and SystemLayer.OS are allowed to host Service nodes",
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
		"/*Rule 6 violation: SystemLayer hosting Service node validity - Invalid hosting relationships detected.\\n\\n" +
		"VIOLATIONS:\\n" +
		apoc.text.join(violations, "\\n\\n") + 
		"\\n\\nRULE: Only SystemLayer.Firmware and SystemLayer.OS can directly host Service nodes.\\n" +
		"\\nALLOWED PATTERNS:\\n" +
		"  SystemLayer.Firmware -[:hosts]-> Service.*\\n" +
		"  SystemLayer.OS -[:hosts]-> Service.*\\n" +
		"\\nFORBIDDEN PATTERNS:\\n" +
		"  SystemLayer.ContainerRuntime -[:hosts]-> Service.* (Wrong: Use Virtual.Container as intermediate)\\n" +
		"  SystemLayer.HyperVisor -[:hosts]-> Service.* (Wrong: Use Virtual.VM as intermediate)\\n" +
		"\\nREMEDIATION:\\n" +
		"1. For services in containers: Create path SystemLayer.ContainerRuntime -> Virtual.Container -> Service\\n" +
		"2. For services in VMs: Create path SystemLayer.HyperVisor -> Virtual.VM -> Service\\n" +
		"3. For bare-metal services: Use SystemLayer.OS -> Service or SystemLayer.Firmware -> Service\\n" +
		"\\nEXAMPLE CORRECTIONS:\\n" +
		"  WRONG: ContainerRuntime -[:hosts]-> WebService\\n" +
		"  RIGHT: ContainerRuntime -[:hosts]-> DockerContainer, DockerContainer -[:hosts]-> WebService*/",
		[]
	)
	RETURN true
	',
	{phase: 'before'}
);
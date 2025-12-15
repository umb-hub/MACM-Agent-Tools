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
	
	// Validate with detailed error reporting and remediation guide
	CALL apoc.util.validate(
		size(violations) > 0,
		"/*Rule 7 violation: Virtual hosting SystemLayer node validity - Invalid hosting relationships detected.\\n\\n" +
		"VIOLATIONS:\\n" +
		apoc.text.join(violations, "\\n\\n") + 
		"\\n\\nRULE: Virtual nodes can only host SystemLayer.OS or SystemLayer.Firmware (base system layers).\\n" +
		"\\nALLOWED PATTERNS:\\n" +
		"  Virtual.VM -[:hosts]-> SystemLayer.OS\\n" +
		"  Virtual.VM -[:hosts]-> SystemLayer.Firmware\\n" +
		"  Virtual.Container -[:hosts]-> SystemLayer.OS\\n" +
		"  Virtual.Container -[:hosts]-> SystemLayer.Firmware\\n" +
		"\\nFORBIDDEN PATTERNS:\\n" +
		"  Virtual.* -[:hosts]-> SystemLayer.ContainerRuntime (Wrong: ContainerRuntime should be hosted by OS)\\n" +
		"  Virtual.* -[:hosts]-> SystemLayer.HyperVisor (Wrong: HyperVisor should be hosted by OS)\\n" +
		"\\nREMEDIATION:\\n" +
		"1. For virtualization layers inside VMs/Containers: Create proper hierarchy\\n" +
		"   Virtual.VM -> SystemLayer.OS -> SystemLayer.HyperVisor (nested virtualization)\\n" +
		"   Virtual.Container -> SystemLayer.OS -> SystemLayer.ContainerRuntime (Docker-in-Docker)\\n" +
		"2. Remove direct [:hosts] from Virtual to ContainerRuntime/HyperVisor\\n" +
		"3. Verify that the SystemLayer node type is appropriate for the virtualization context\\n" +
		"\\nCOMMON SCENARIO: A VM typically hosts an OS, which then hosts services or other system layers*/",
		[]
	)
	RETURN true
	',
	{phase: 'before'}
);
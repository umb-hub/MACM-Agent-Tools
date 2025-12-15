CALL apoc.trigger.add(
	'06_check_SystemLayer_hosts_virtual',
	'
	// Check SystemLayer to Virtual hosting relationships
	MATCH (sourceNode)-[hostsRel:hosts]->(targetNode)
	WITH head(labels(sourceNode)) AS sourcePrimaryLabel,
		 head(labels(targetNode)) AS targetPrimaryLabel,
		 sourceNode, targetNode, hostsRel
	WHERE sourcePrimaryLabel = "SystemLayer"
	AND targetPrimaryLabel = "Virtual"
	
	// Check if the hosting relationship follows allowed patterns
	// Allowed patterns:
	// - SystemLayer.ContainerRuntime can host Virtual.Container
	// - SystemLayer.HyperVisor can host Virtual.VM
	AND NOT (
		(sourceNode.type = "SystemLayer.ContainerRuntime" AND targetNode.type = "Virtual.Container") OR
		(sourceNode.type = "SystemLayer.HyperVisor" AND targetNode.type = "Virtual.VM")
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
		"Invalid SystemLayer-to-Virtual hosting relationship: %s -[:hosts]-> %s\\n" +
		"  Source type: %s\\n" +
		"  Target type: %s\\n" +
		"  Allowed patterns: SystemLayer.ContainerRuntime -> Virtual.Container OR SystemLayer.HyperVisor -> Virtual.VM",
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
		"/*Rule 5 violation: SystemLayer hosting Virtual node validity - Invalid hosting relationships detected.\\n\\n" +
		"VIOLATIONS:\\n" +
		apoc.text.join(violations, "\\n\\n") + 
		"\\n\\nRULE: SystemLayer can host Virtual nodes only with matching virtualization technology.\\n" +
		"\\nALLOWED PATTERNS:\\n" +
		"  SystemLayer.ContainerRuntime -[:hosts]-> Virtual.Container\\n" +
		"  SystemLayer.HyperVisor -[:hosts]-> Virtual.VM\\n" +
		"\\nFORBIDDEN PATTERNS:\\n" +
		"  SystemLayer.ContainerRuntime -[:hosts]-> Virtual.VM (Wrong: ContainerRuntime cannot host VMs)\\n" +
		"  SystemLayer.HyperVisor -[:hosts]-> Virtual.Container (Wrong: HyperVisor cannot host Containers)\\n" +
		"  SystemLayer.OS -[:hosts]-> Virtual.* (Wrong: OS should host ContainerRuntime/HyperVisor, not Virtual directly)\\n" +
		"  SystemLayer.Firmware -[:hosts]-> Virtual.* (Wrong: Firmware cannot host Virtual nodes)\\n" +
		"\\nREMEDIATION:\\n" +
		"1. Verify virtualization technology match: ContainerRuntime <-> Container, HyperVisor <-> VM\\n" +
		"2. Check the hosting hierarchy: HW -> OS -> ContainerRuntime/HyperVisor -> Virtual\\n" +
		"3. Add missing intermediate layers if necessary (e.g., add SystemLayer.HyperVisor between OS and VM)\\n" +
		"4. Correct node types to match the actual virtualization technology used*/",
		[]
	)
	RETURN true
	',
	{phase: 'before'}
);
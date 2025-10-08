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
	
	// Validate with detailed error reporting
	CALL apoc.util.validate(
		size(violations) > 0,
		"/*Rule 6 violation: SystemLayer-to-Virtual hosting relationship validation failed. " +
		"SystemLayer nodes can only host specific Virtual node types according to their virtualization model.\\n\\n" +
		apoc.text.join(violations, "\\n\\n") + "*/",
		[]
	)
	RETURN true
	',
	{phase: 'before'}
);
CALL apoc.trigger.add(
	'04_check_alternate_path_for_uses',
	'
	// Check all existing "uses" relationships for alternate path requirement
	MATCH (sourceNode)-[usesRel:uses]->(targetNode)
	
	// For each "uses" relationship, check if there exists an alternate path
	// that does not use any "uses" relationship
	WHERE NOT EXISTS {
		MATCH alternatePath=(sourceNode)-[*]-(targetNode)
		WHERE ALL(rel IN relationships(alternatePath) WHERE type(rel) <> "uses")
		AND length(alternatePath) > 0
	}
	
	// Build detailed source node description
	WITH sourceNode, targetNode, usesRel,
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
	
	// Create focused violation message without alternate path details
	WITH apoc.text.format(
		"USES relationship without alternate path: %s -[:uses]-> %s",
		[sourceDescription, targetDescription]
	) AS violationDetail
	
	// Collect all violations
	WITH collect(violationDetail) AS violations
	
	// Validate with detailed error reporting and remediation guide
	CALL apoc.util.validate(
		size(violations) > 0,
		"/*Rule 3 violation: Alternate path for uses - Every [:uses] relationship must have at least one alternate path.\\n\\n" +
		"VIOLATIONS:\\n" +
		apoc.text.join(violations, "\\n\\n") + 
		"\\n\\nREQUIREMENT: For each A -[:uses]-> B relationship, there must exist at least one path connecting A and B that:\\n" +
		"  - Uses relationships OTHER than [:uses] (e.g., [:hosts], [:provides], [:connects])\\n" +
		"  - Does NOT include [:interacts] relationships\\n" +
		"\\nREMEDIATION GUIDE:\\n" +
		"1. Analyze the infrastructure: Identify how the source and target are physically/logically connected\\n" +
		"2. Add missing hosting relationships: E.g., if both services run on the same system, add [:hosts] from that system\\n" +
		"3. Add infrastructure relationships: E.g., [:connects] for network connectivity, [:provides] from CSP\\n" +
		"4. Verify the alternate path: Ensure the new path connects both nodes without using [:uses]\\n" +
		"\\nEXAMPLE: If ServiceA -[:uses]-> ServiceB, you might add:\\n" +
		"  SystemLayerX -[:hosts]-> ServiceA\\n" +
		"  SystemLayerX -[:hosts]-> ServiceB\\n" +
		"  (This creates an alternate path: ServiceA <-[:hosts]- SystemLayerX -[:hosts]-> ServiceB)*/",
		[]
	)
	RETURN true
	',
	{phase: 'before'}
);
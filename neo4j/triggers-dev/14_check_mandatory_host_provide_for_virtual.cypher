CALL apoc.trigger.add(
	'14_check_mandatory_host_provide_for_virtual',
	'
	MATCH (v:Virtual)
	OPTIONAL MATCH (hoster)-[r]->(v)
	WHERE type(r) IN ["hosts","provides"]
	WITH v, COUNT(DISTINCT hoster) AS numHosts, collect(DISTINCT hoster) AS hosters
	WHERE numHosts < 1
	WITH v, numHosts,
		 CASE 
			WHEN v.component_id IS NOT NULL AND v.name IS NOT NULL 
			THEN "Virtual[component_id: " + v.component_id + ", name: " + v.name + ", type: " + coalesce(v.type, "<no-type>") + "]"
			WHEN v.component_id IS NOT NULL 
			THEN "Virtual[component_id: " + v.component_id + ", type: " + coalesce(v.type, "<no-type>") + "]"
			WHEN v.name IS NOT NULL 
			THEN "Virtual[name: " + v.name + ", type: " + coalesce(v.type, "<no-type>") + "]"
			ELSE "Virtual[id: " + toString(id(v)) + ", type: " + coalesce(v.type, "<no-type>") + "]"
		 END AS virtualDesc,
		 " has NO host/provide relationship.\\n  FIX: Add exactly ONE [:hosts] or [:provides] relationship from SystemLayer (ContainerRuntime/HyperVisor) or CSP to this Virtual node." AS violationDetail
	WITH collect(virtualDesc + violationDetail) AS violations
	CALL apoc.util.validate(
		size(violations) > 0,
		"/*Rule 12 violation: Mandatory host/provide for Virtual - Each Virtual node must have at least one incoming [:hosts] or [:provides] relationship.\\n\\n" + 
		"VIOLATIONS:\\n" +
		apoc.text.join(violations, "\\n\\n") + 
		"\\n\\nREQUIREMENT: Every Virtual node (VM or Container) must be hosted or provided by another component.\\n" +
		"Virtual resources cannot exist in isolation - they require a host environment.\\n\\n" +
		"REMEDIATION GUIDE:\\n" +
		"- For Virtual.Container: Add [:hosts] from SystemLayer.ContainerRuntime\\n" +
		"  Example: Docker (ContainerRuntime) -[:hosts]-> MyAppContainer (Virtual.Container)\\n" +
		"- For Virtual.VM: Add [:hosts] from SystemLayer.HyperVisor\\n" +
		"  Example: VMware (HyperVisor) -[:hosts]-> MyVM (Virtual.VM)\\n" +
		"- For cloud-managed virtual resources: Add [:provides] from CSP\\n" +
		"  Example: AWS (CSP) -[:provides]-> EC2Instance (Virtual.VM)\\n\\n" +
		"ARCHITECTURE HIERARCHY:\\n" +
		"  Hardware -> OS -> ContainerRuntime/HyperVisor -> Virtual -> Services\\n" +
		"  or: CSP -> Virtual -> Services (for cloud-native)\\n\\n" +
		"NOTE: Virtual nodes represent containerized or virtualized environments that always\\n" +
		"require a hosting infrastructure to run.*/",
		[]
	)
	RETURN true
	',
	{phase:'before'}
);

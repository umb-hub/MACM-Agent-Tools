CALL apoc.trigger.add(
  '12_check_hosts_acyclic_with_cycles',
  '
  MATCH p = (n)-[:hosts*1..]->(n)
  WITH DISTINCT p,
       [x IN nodes(p) | toString(coalesce(x.name, x.component_id, id(x)))] AS lst
  WITH CASE
         WHEN size(lst) > 1 AND lst[0] = lst[size(lst)-1] THEN lst[0..size(lst)-1]
         ELSE lst
       END AS core
  WHERE size(core) > 0
  WITH [i IN range(0, size(core)-1) |
         apoc.text.join(core[i..] + core[..i] + [core[i]], " -[:hosts]-> ")
       ] AS rots
  WITH apoc.coll.min(rots) AS cycleCanon
  WITH apoc.coll.toSet(collect(cycleCanon)) AS cycles
  WITH cycles, 
       CASE WHEN size(cycles) > 20 
            THEN cycles[0..20] 
            ELSE cycles 
       END AS displayCycles,
       size(cycles) AS totalCycles
  CALL apoc.util.validate(
    size(cycles) > 0,
    "/*Rule 11 violation: No cycles allowed for hosts relationship - Circular hosting dependencies detected.\\n\\n" + 
    "DETECTED CYCLES (" + toString(totalCycles) + " total, showing up to 20):\\n" + 
    apoc.text.join(displayCycles, "\\n") + 
    "\\n\\nREQUIREMENT: The [:hosts] relationship must form an acyclic hierarchy (no loops).\\n" +
    "A node cannot host itself directly or indirectly through a chain of [:hosts] relationships.\\n" +
    "\\nWHY THIS MATTERS:\\n" +
    "- [:hosts] represents a containment/hosting hierarchy (e.g., Server hosts OS, OS hosts Service)\\n" +
    "- Cycles create logical contradictions (A hosts B, B hosts A means A contains itself)\\n" +
    "- Acyclic structure is essential for dependency resolution and system modeling\\n" +
    "\\nREMEDIATION STEPS:\\n" +
    "1. Identify the cycle: Review the nodes and relationships in the cycle path shown above\\n" +
    "2. Determine the correct hosting direction: Ask \\"What physically/logically contains what?\\"\\n" +
    "3. Break the cycle by removing or reversing incorrect [:hosts] relationships\\n" +
    "4. Consider if a different relationship type is more appropriate:\\n" +
    "   - [:uses] for service dependencies (can be cyclic)\\n" +
    "   - [:connects] for network connections\\n" +
    "   - [:interacts] for Party interactions\\n" +
    "\\nCOMMON MISTAKES:\\n" +
    "- Using [:hosts] bidirectionally (A hosts B AND B hosts A)\\n" +
    "- Creating circular hosting chains in distributed systems\\n" +
    "- Confusing [:hosts] with [:uses] (service dependencies can be cyclic, hosting cannot)\\n" +
    "\\nEXAMPLE FIX:\\n" +
    "  WRONG: ServiceA -[:hosts]-> ServiceB -[:hosts]-> ServiceA (cycle!)\\n" +
    "  RIGHT: OSNode -[:hosts]-> ServiceA, OSNode -[:hosts]-> ServiceB, ServiceA -[:uses]-> ServiceB*/",
    []
  )
  RETURN true
  ',
  {phase:'before'}
);
// Reporting query for hosts cycles detection (no output if none found)
MATCH p = (n)-[:hosts*1..]->(n)
WITH DISTINCT p,
     [x IN nodes(p) | toString(coalesce(x.name, id(x)))] AS lst
WITH CASE
       WHEN size(lst) > 1 AND lst[0] = lst[size(lst)-1] THEN lst[0..size(lst)-1]
       ELSE lst
     END AS core
WHERE size(core) > 0
WITH [i IN range(0, size(core)-1) |
       apoc.text.join(core[i..] + core[..i] + [core[i]], " -> ")
     ] AS rots
WITH apoc.coll.min(rots) AS cycleCanon
WITH apoc.coll.toSet(collect(cycleCanon)) AS cycles
WITH cycles, 
     CASE WHEN size(cycles) > 20 THEN cycles[0..20] ELSE cycles END AS displayCycles,
     size(cycles) AS totalCycles
WHERE totalCycles > 0
RETURN "Rule 11 violation: No cycles allowed for hosts relationship\n\n" +
       "DETECTED CYCLES (" + toString(totalCycles) + " total, showing up to 20):\n" +
       apoc.text.join([c IN displayCycles | c], "\n") + "\n\n" +
       "REQUIREMENT: [:hosts] must form an acyclic hierarchy (no loops).\n" +
       "A node cannot host itself directly or indirectly through a chain.\n\n" +
       "WHY THIS MATTERS:\n" +
       "- [:hosts] represents containment hierarchy (Server hosts OS, OS hosts Service)\n" +
       "- Cycles create logical contradictions (A hosts B, B hosts A = A contains itself)\n" +
       "- Acyclic structure is essential for dependency resolution\n\n" +
       "REMEDIATION:\n" +
       "1. Review the cycle path shown above\n" +
       "2. Determine correct hosting direction: 'What physically/logically contains what?'\n" +
       "3. Break the cycle by removing or reversing incorrect [:hosts] relationships\n" +
       "4. Consider different relationship types:\n" +
       "   - [:uses] for service dependencies (can be cyclic)\n" +
       "   - [:connects] for network connections\n" +
       "   - [:interacts] for Party interactions\n\n" +
       "EXAMPLE FIX:\n" +
       "  WRONG: ServiceA -[:hosts]-> ServiceB -[:hosts]-> ServiceA (cycle!)\n" +
       "  RIGHT: OSNode -[:hosts]-> ServiceA, OSNode -[:hosts]-> ServiceB, ServiceA -[:uses]-> ServiceB" AS hosts_cycles_violation;

CALL apoc.trigger.add('01_check_asset_type_labels', '
UNWIND coalesce($createdNodes, []) AS n 
WITH n WHERE n.type IS NOT NULL 
WITH n, split(n.type, ".")[0] AS plFromType, labels(n) AS lbls

// Collect errors instead of validating immediately
WITH n, plFromType, lbls, [] AS errors

// Check if primary label is present  
WITH n, plFromType, lbls, 
     CASE WHEN NOT (plFromType IN lbls) 
          THEN errors + [apoc.text.format("/* %s type=%s expects primary label %s but labels are [%s] */", 
                                         [coalesce(n.name,"<no name>"), n.type, plFromType, apoc.text.join(lbls, ",")])]
          ELSE errors 
     END AS errors

WITH n, plFromType, lbls, errors, ["Party","CSP","HW","Network","Service","Virtual","SystemLayer","Data"] AS macro
WITH n, plFromType, lbls, errors, [l IN lbls WHERE l <> plFromType AND NOT l IN macro] AS rest

WITH n, plFromType, lbls, errors, rest, [
    {pl:"Party",sl:"Human",types:["Party.Human"]},
    {pl:"Party",sl:"LegalEntity",types:["Party.LegalEntity"]},
    {pl:"Party",sl:"Group",types:["Party.Group"]},
    {pl:"CSP",sl:null,types:["CSP"]},
    {pl:"HW",sl:"MEC",types:["HW.MEC"]},
    {pl:"HW",sl:"HW.GCS",types:["HW.GCS"]},
    {pl:"HW",sl:"UE",types:["HW.UE"]},
    {pl:"HW",sl:"Chassis",types:["HW.Chassis"]},
    {pl:"HW",sl:"Raspberry",types:["HW.Raspberry"]},
    {pl:"HW",sl:"Router",types:["HW.Router"]},
    {pl:"HW",sl:"IoT",types:["HW.IoT.Device","HW.IoT.Gateway"]},
    {pl:"HW",sl:"Device",types:["HW.Device","HW.HDI"]},
    {pl:"HW",sl:"Server",types:["HW.Server"]},
    {pl:"HW",sl:"Microcontroller",types:["HW.Microcontroller"]},
    {pl:"HW",sl:"SOC",types:["HW.SOC"]},
    {pl:"HW",sl:"PC",types:["HW.PC","HW.PC.LoginNode","HW.PC.DataStorageDisk","HW.PC.SchedulerNode","HW.PC.ComputeNode"]},
    {pl:"Network",sl:null,types:["Network"]},
    {pl:"Network",sl:"WAN",types:["Network.WAN"]},
    {pl:"Network",sl:"LAN",types:["Network.LAN","Network.Wired","Network.WiFi","Network.Virtual"]},
    {pl:"Network",sl:"PAN",types:["Network.PAN"]},
    {pl:"Network",sl:"5G",types:["Network.RAN","Network.Core"]},
    {pl:"SystemLayer",sl:"OS",types:["SystemLayer.OS"]},
    {pl:"SystemLayer",sl:"Firmware",types:["SystemLayer.Firmware"]},
    {pl:"SystemLayer",sl:"HyperVisor",types:["SystemLayer.HyperVisor"]},
    {pl:"SystemLayer",sl:"ContainerRuntime",types:["SystemLayer.ContainerRuntime"]},
    {pl:"Virtual",sl:"VM",types:["Virtual.VM"]},
    {pl:"Virtual",sl:"Container",types:["Virtual.Container"]},
    {pl:"Service",sl:"5G",types:["Service.5G.RAN","Service.5G.AMF","Service.5G.AUSF","Service.5G.NEF","Service.5G.NRF","Service.5G.NSSF","Service.5G.NWDAF","Service.5G.PCF","Service.5G.UDM","Service.5G.UPF"]},
    {pl:"Service",sl:"App",types:["Service.App","Service.Browser","Service.MQTTClient"]},
    {pl:"Service",sl:null,types:["Service"]},
    {pl:"Service",sl:"Server",types:["Service.JobScheduler","Service.SSH","Service.Web","Service.API","Service.DB","Service.NoSQLDB","Service.IDProvider","Service.MQTTBroker","Service.RPCBind"]}
] AS mapping

WITH n, plFromType, lbls, errors, rest, [m IN mapping WHERE m.pl = plFromType AND n.type IN m.types | m.sl] AS expectedSLsRaw
WITH n, plFromType, lbls, errors, rest, [x IN expectedSLsRaw WHERE x IS NOT NULL] AS expectedSome, 
     any(x IN expectedSLsRaw WHERE x IS NULL) AS noneAllowed, size(expectedSLsRaw) AS hasAnyMapping

// Check if type is covered by mapping
WITH n, plFromType, lbls, rest, expectedSome, noneAllowed, 
     CASE WHEN hasAnyMapping = 0 
          THEN errors + [apoc.text.format("/* %s type=%s PL=%s is not covered by mapping */", 
                                         [coalesce(n.name,"<no name>"), n.type, plFromType])]
          ELSE errors 
     END AS errors

WITH n, plFromType, lbls, rest, expectedSome, noneAllowed, errors,
     (CASE WHEN noneAllowed THEN "[]" ELSE "[" + apoc.text.join(expectedSome, ",") + "]" END) AS expectedStr,
     apoc.text.join(rest, ",") AS restStr

// Check secondary labels
WITH n, plFromType, lbls, rest, expectedSome, noneAllowed, expectedStr, restStr,
     CASE WHEN (noneAllowed AND size(rest) <> 0) OR (NOT noneAllowed AND (size(rest) <> 1 OR NOT rest[0] IN expectedSome))
          THEN errors + [apoc.text.format("/* %s type=%s PL=%s expected SL(s)=%s but secondary labels are [%s] */", 
                                         [coalesce(n.name,"<no name>"), n.type, plFromType, expectedStr, restStr])]
          ELSE errors 
     END AS errors

// Create detailed error report for each node that has errors
WITH n, errors
WHERE size(errors) > 0
WITH n, "Node validation errors for component_id: " + coalesce(n.component_id, "<no component_id>") + ":" AS nodeHeader,
     [i IN range(0, size(errors)-1) | "  " + (i+1) + ". " + errors[i]] AS numberedErrors
WITH collect(nodeHeader + "\\n" + apoc.text.join(numberedErrors, "\\n")) AS allNodeReports

// Validate with detailed per-node error reporting
CALL apoc.util.validate(size(allNodeReports) > 0, 
    "/*Rule 1 violation: Asset type label validation failed:\\n\\n" + apoc.text.join(allNodeReports, "\\n\\n"), [])
RETURN 0
', {phase:'before'});
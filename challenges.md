1. Service discovery
   - used Cloud Map
2. Make health end point as /-/healthy for prometheus..

3. path based routing is pointed to /prometheus but prometheus won't support this so while running the promethus change the CMD

4. The main challenge is with sending infra metrics from cloudwatch to prometheus.. the metrics went fine but was unable to query them becuase the cloudwatch exporter is sending the metrics with timestamps in milliseconds but the prometheus want it in seconds.. as as there is diff in time the data is not stored in TSDB..

5. So I disabled the timestamos while sending the metrics. so the prblm got solved..

CMDS:

- avg(aws_ecs_cpuutilization_average{service_name="my-app-service"})
- sum(rate(aws_applicationelb_request_count_sum[1m]))

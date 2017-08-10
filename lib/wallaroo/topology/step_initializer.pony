use "collections"
use "net"
use "wallaroo/boundary"
use "wallaroo/core"
use "wallaroo/initialization"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/recovery"
use "wallaroo/routing"
use "wallaroo/source"
use "wallaroo/tcp_source"
use "wallaroo/sink"

type StepInitializer is (StepBuilder | SourceData | EgressBuilder |
  PreStatelessData)

class StepBuilder
  let _app_name: String
  let _worker_name: String
  let _pipeline_name: String
  let _state_name: String
  let _runner_builder: RunnerBuilder val
  let _id: U128
  let _pre_state_target_id: (U128 | None)
  let _is_stateful: Bool
  let _forward_route_builder: RouteBuilder val

  new val create(app_name: String, worker_name: String,
    pipeline_name': String, r: RunnerBuilder val, id': U128,
    is_stateful': Bool = false,
    pre_state_target_id': (U128 | None) = None,
    forward_route_builder': RouteBuilder val = BoundaryOnlyRouteBuilder)
  =>
    _app_name = app_name
    _worker_name = worker_name
    _pipeline_name = pipeline_name'
    _runner_builder = r
    _state_name = _runner_builder.state_name()
    _id = id'
    _is_stateful = is_stateful'
    _pre_state_target_id = pre_state_target_id'
    _forward_route_builder = forward_route_builder'

  fun name(): String => _runner_builder.name()
  fun state_name(): String => _state_name
  fun default_state_name(): String =>
    match _runner_builder
    | let ds: DefaultStateable val =>
      if ds.default_state_name() != "" then ds.default_state_name() else "" end
    else
      ""
    end
  fun pipeline_name(): String => _pipeline_name
  fun id(): U128 => _id
  fun pre_state_target_id(): (U128 | None) => _pre_state_target_id
  fun is_prestate(): Bool => _runner_builder.is_prestate()
  fun is_stateful(): Bool => _is_stateful
  fun is_partitioned(): Bool => false
  fun forward_route_builder(): RouteBuilder val => _forward_route_builder
  fun in_route_builder(): (RouteBuilder val | None) =>
    _runner_builder.in_route_builder()
  fun clone_router_and_set_input_type(r: Router val,
    default_r: (Router val | None) = None): Router val
  =>
    _runner_builder.clone_router_and_set_input_type(r, default_r)

  fun apply(next: Router val, metrics_conn: MetricsSink, event_log: EventLog,
    recovery_replayer: RecoveryReplayer,
    auth: AmbientAuth, outgoing_boundaries: Map[String, OutgoingBoundary] val,
    router: Router val = EmptyRouter,
    omni_router: OmniRouter val = EmptyOmniRouter,
    default_target: (Step | None) = None): Step tag
  =>
    let runner = _runner_builder(where event_log = event_log, auth = auth, router = router,
      pre_state_target_id' = pre_state_target_id())
    let step = Step(consume runner,
      MetricsReporter(_app_name, _worker_name, metrics_conn), _id,
      _runner_builder.route_builder(), event_log, recovery_replayer,
      outgoing_boundaries, router, default_target, omni_router)
    step.update_router(next)
    step

class SourceData
  let _id: U128
  let _pipeline_name: String
  let _name: String
  let _state_name: String
  let _builder: SourceBuilderBuilder val
  let _runner_builder: RunnerBuilder val
  let _route_builder: RouteBuilder val
  let _source_listener_builder_builder: SourceListenerBuilderBuilder
  let _pre_state_target_id: (U128 | None)

  new val create(id': U128, b: SourceBuilderBuilder val, r: RunnerBuilder val,
    default_source_route_builder: RouteBuilder val,
    s: SourceListenerBuilderBuilder,
    pre_state_target_id': (U128 | None) = None)
  =>
    _id = id'
    _pipeline_name = b.name()
    _name = "| " + _pipeline_name + " source | " + r.name() + "|"
    _builder = b
    _runner_builder = r
    _state_name = _runner_builder.state_name()
    _route_builder =
      match _runner_builder.route_builder()
      | let e: BoundaryOnlyRouteBuilder val =>
        default_source_route_builder
      else
        _runner_builder.route_builder()
      end
    _source_listener_builder_builder = s

    _pre_state_target_id = pre_state_target_id'

  fun builder(): SourceBuilderBuilder => _builder
  fun runner_builder(): RunnerBuilder val => _runner_builder
  fun route_builder(): RouteBuilder val => _route_builder

  fun name(): String => _name
  fun state_name(): String => _state_name
  fun default_state_name(): String =>
    match _runner_builder
    | let ds: DefaultStateable val =>
      if ds.default_state_name() != "" then ds.default_state_name() else "" end
    else
      ""
    end
  fun pipeline_name(): String => _pipeline_name
  fun id(): U128 => _id
  fun pre_state_target_id(): (U128 | None) => _pre_state_target_id
  fun is_prestate(): Bool => _runner_builder.is_prestate()
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false
  fun forward_route_builder(): RouteBuilder val =>
    _runner_builder.forward_route_builder()
  fun clone_router_and_set_input_type(r: Router val,
    default_r: (Router val | None) = None): Router val
  =>
    _runner_builder.clone_router_and_set_input_type(r, default_r)

  fun source_listener_builder_builder(): SourceListenerBuilderBuilder =>
    _source_listener_builder_builder


class EgressBuilder
  let _name: String
  let _pipeline_name: String
  let _id: U128
  // None if this is a sink to an external system
  let _proxy_addr: (ProxyAddress val | None)
  let _sink_builder: (SinkBuilder | None)

  new val create(pipeline_name': String, id': U128,
    sink_builder: (SinkBuilder | None) = None,
    proxy_addr: (ProxyAddress val | None) = None)
  =>
    _pipeline_name = pipeline_name'
    _name =
      match proxy_addr
      | let pa: ProxyAddress val =>
        "Proxy to " + pa.worker
      else
        _pipeline_name + " sink"
      end

    _id = id'
    _proxy_addr = proxy_addr
    _sink_builder = sink_builder

  fun name(): String => _name
  fun state_name(): String => ""
  fun pipeline_name(): String => _pipeline_name
  fun id(): U128 => _id
  fun pre_state_target_id(): (U128 | None) => None
  fun is_prestate(): Bool => false
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false
  fun forward_route_builder(): RouteBuilder val => BoundaryOnlyRouteBuilder
  fun clone_router_and_set_input_type(r: Router val,
    dr: (Router val | None) = None): Router val => r

  fun target_address(): (ProxyAddress val | PartitionAddresses val | None) =>
    _proxy_addr

  fun apply(worker_name: String, reporter: MetricsReporter ref,
    auth: AmbientAuth,
    proxies: Map[String, OutgoingBoundary] val =
      recover Map[String, OutgoingBoundary] end): Consumer ?
  =>
    match _proxy_addr
    | let p: ProxyAddress val =>
      try
        proxies(p.worker)
      else
        @printf[I32](("Couldn't find proxy for " + p.worker + ".\n").cstring())
        error
      end
    | None =>
      match _sink_builder
      | let sb: SinkBuilder =>
        sb(reporter.clone())
      else
        EmptySink
      end
    else
      // The match is exhaustive, so this can't happen
      @printf[I32]("Exhaustive match failed somehow\n".cstring())
      error
    end

class PreStateData
  let _state_name: String
  let _pre_state_name: String
  let _runner_builder: RunnerBuilder val
  let _target_id: (U128 | None)
  let _forward_route_builder: RouteBuilder val
  let _is_default_target: Bool

  new val create(runner_builder: RunnerBuilder val, t_id: (U128 | None),
    is_default_target': Bool = false) =>
    _runner_builder = runner_builder
    _state_name = runner_builder.state_name()
    _pre_state_name = runner_builder.name()
    _target_id = t_id
    _forward_route_builder = runner_builder.forward_route_builder()
    _is_default_target = is_default_target'

  fun state_name(): String => _state_name
  fun pre_state_name(): String => _pre_state_name
  fun target_id(): (U128 | None) => _target_id
  fun forward_route_builder(): RouteBuilder val => _forward_route_builder
  fun clone_router_and_set_input_type(r: Router val): Router val =>
    _runner_builder.clone_router_and_set_input_type(r)
  fun is_default_target(): Bool => _is_default_target

class val PreStatelessData
  """
  Unlike PreStateData, this is simply used to create a StatelessPartitionRouter
  during local initialization. Whatever step/s come before a stateless
  partition do not need to do anything special; they only need the correct
  StatelessPartitionRouter.

  This is a StepInitializer because it inhabits a node in the local topology
  graph, but it does not provide the blueprint for a step.  Instead, it
  provides a blueprint for creating the router for the previous step/s in the
  graph that have edges into it.
  """
  let _pipeline_name: String
  let _id: U128
  let partition_id_to_worker: Map[U64, String] val
  let partition_id_to_step_id: Map[U64, U128] val
  let worker_to_step_id: Map[String, Array[U128] val] val

  new val create(pipeline_name': String, step_id': U128,
    partition_id_to_worker': Map[U64, String] val,
    partition_id_to_step_id': Map[U64, U128] val,
    worker_to_step_id': Map[String, Array[U128] val] val)
  =>
    _pipeline_name = pipeline_name'
    _id = step_id'
    partition_id_to_worker = partition_id_to_worker'
    partition_id_to_step_id = partition_id_to_step_id'
    worker_to_step_id = worker_to_step_id'

  fun name(): String => "PreStatelessData"
  fun state_name(): String => ""
  fun pipeline_name(): String => _pipeline_name
  fun id(): U128 => _id
  fun pre_state_target_id(): (U128 | None) => None
  fun is_prestate(): Bool => false
  fun is_stateful(): Bool => false
  fun is_partitioned(): Bool => false
  fun forward_route_builder(): RouteBuilder val => BoundaryOnlyRouteBuilder
  fun clone_router_and_set_input_type(r: Router val,
    dr: (Router val | None) = None): Router val => r

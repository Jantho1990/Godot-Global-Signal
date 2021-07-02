extends Node

# Keeps track of what signal emitters have been registered.
var _emitters = {}

# Queue used for signals emitted with emit_signal_when_ready.
var _emit_queue = []

# Keeps track of what listeners have been registered.
var _listeners = {}

# Is false until after _ready() has been run.
var _gs_ready = false


# We only run this once, to process the _emit_queue. We disable processing afterwards.
func _process(_delta):
  if not _gs_ready:
    _make_ready()
    set_process(false)
    set_physics_process(false)


# Connect an emitter to existing listeners of its signal.
func _connect_emitter_to_listeners(signal_name: String, emitter: Object) -> void:
  var listeners = _listeners[signal_name]
  for listener in listeners.values():
    if _process_purge(listener, listeners):
      continue
    emitter.connect(signal_name, listener.object, listener.method)


# Connect a listener to emitters who emit the signal its listening for.
func _connect_listener_to_emitters(signal_name: String, listener: Object, method: String) -> void:
  var emitters = _emitters[signal_name]
  for emitter in emitters.values():
    if _process_purge(emitter, emitters):
      continue
    emitter.object.connect(signal_name, listener, method)


# Execute the ready process and initiate processing the emit queue.
func _make_ready() -> void:
  _gs_ready = true
  _process_emit_queue()


# Emits any queued signal emissions, then clears the emit queue.
func _process_emit_queue() -> void:
  for emitted_signal in _emit_queue:
    emitted_signal.args.push_front(emitted_signal.signal_name)
    emitted_signal.emitter.callv('emit_signal', emitted_signal.args)
  _emit_queue = []


# Register a signal with GlobalSignal, making it accessible to global listeners.
func add_emitter(signal_name: String, emitter: Object) -> void:
  var emitter_data = { 'object': emitter, 'object_id': emitter.get_instance_id() }
  if not _emitters.has(signal_name):
    _emitters[signal_name] = {}
  _emitters[signal_name][emitter.get_instance_id()] = emitter_data

  if _listeners.has(signal_name):
    _connect_emitter_to_listeners(signal_name, emitter)


# Adds a new global listener, making it accessible to global emitters.
func add_listener(signal_name: String, listener: Object, method: String) -> void:
  var listener_data = { 'object': listener, 'object_id': listener.get_instance_id(), 'method': method }
  if not _listeners.has(signal_name):
    _listeners[signal_name] = {}
  _listeners[signal_name][listener.get_instance_id()] = listener_data

  if _emitters.has(signal_name):
    _connect_listener_to_emitters(signal_name, listener, method)


# A variant of emit_signal that defers emitting the signal until the first physics process step.
# Useful when you want to emit a global signal during a _gs_ready function and guarantee the emitter and listener are ready.
func emit_signal_when_ready(signal_name: String, args: Array, emitter: Object) -> void:
  if not _emitters.has(signal_name):
    push_error('GlobalSignal.emit_signal_when_ready: Signal is not registered with GlobalSignal (' + signal_name + ').')
    return
  
  if not _gs_ready:
    _emit_queue.push_back({ 'signal_name': signal_name, 'args': args, 'emitter': emitter })
  else:
    # GlobalSignal is ready, so just call emit_signal with the provided args.
    args.push_front(signal_name)
    emitter.callv('emit_signal', args)


# Checks stored listener or emitter data to see if it should be removed from its group, and purges if so.
# Returns true if the listener or emitter was purged, and false if it wasn't.
func _process_purge(data: Dictionary, group: Dictionary) -> bool:
  var object_exists = !!weakref(data.object).get_ref() and is_instance_valid(data.object)

  if !object_exists or data.object.get_instance_id() != data.object_id:
    group.erase(data.object_id)
    return true
  return false


# Remove emitter and disconnect any listeners connected to it.
func remove_emitter(signal_name: String, emitter: Object) -> void:
  if not _emitters.has(signal_name): return
  if not _emitters[signal_name].has(emitter.get_instance_id()): return  
    
  _emitters[signal_name].erase(emitter.get_instance_id())
    
  if _listeners.has(signal_name):
    for listener in _listeners[signal_name].values():
      if _process_purge(listener, _listeners[signal_name]):
        continue
      if emitter.is_connected(signal_name, listener.object, listener.method):
        emitter.disconnect(signal_name, listener.object, listener.method)


# Remove registered listener and disconnect it from any emitters it was listening to.
func remove_listener(signal_name: String, listener: Object, method: String) -> void:
  if not _listeners.has(signal_name): return
  if not _listeners[signal_name].has(listener.get_instance_id()): return  
    
  _listeners[signal_name].erase(listener.get_instance_id())
    
  if _emitters.has(signal_name):
    for emitter in _emitters[signal_name].values():
      if _process_purge(emitter, _emitters[signal_name]):
        continue
      if emitter.object.is_connected(signal_name, listener, method):
        emitter.object.disconnect(signal_name, listener, method)
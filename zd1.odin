package zd

import "core:container/queue"

Message :: struct {
    port,
    datum,
}

System :: struct {
    components,
    connectors
}

Connector :: struct {
    src,
    src_port,
    dst,
    dst_port
}

FIFO      :: queue.Queue(Message)
fifo_push :: queue.push_back
fifo_pop  :: queue.pop_front_safe

Component :: struct {
    name,
    input,
    output,
    state,
    data,
}

step :: proc(sys) -> (retry) {
    for component in sys.components {
        for component.output.len > 0 {
            msg, _ := fifo_pop(&component.output)
            route(sys, component, msg)
        }
    }

    for component in sys.components {
        msg, ok := fifo_pop(&component.input)
        if ok {
            component.state(component, msg.port, msg.datum)
            retry = true
        }
    }
    return retry
}

route :: proc(sys, from, msg) {
    for c in sys.connectors {
        if c.src == from && c.src_port == msg.port {
            new_msg := msg
            new_msg.port = c.dst_port
            fifo_push(&c.dst.input, new_msg)
        }
    }
}

run :: proc(sys, port, data) {
    msg := {port, data}
    route(sys, nil, msg)

    for component in sys.components {
        component.state(component, ENTER, nil)
    }

    for step(sys) {
        // ...
    }

    for component in sys.components {
        component.state(component, EXIT, nil)
    }
}

add_component :: proc(sys, name, handler, )) -> ? {
    component := new()
    component.name = name
    component.state = handler
    append(&sys.components, component)
    return component
}

add_connection :: proc(sys, connection) {
    append(&sys.connectors, connection)
}

send :: proc(component, port, data) {
    fifo_push(&component.output, {port, data})
}

ENTER :: Port("__STATE_ENTER__")
EXIT  :: Port("__STATE_EXIT__")

tran :: proc(component, state) {
    component.state(component, EXIT, nil)
    component.state = state
    component.state(component, ENTER, nil)
}

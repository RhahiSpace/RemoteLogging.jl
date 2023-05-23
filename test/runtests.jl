using Logging
using ProgressLogging
using RemoteLogging
using Serialization
using Sockets
using TerminalLoggers
using Test
using UUIDs

include("debug_listener.jl")

const HOST = IPv4(0)
const MPORT = 50010
const PPORT = 50011

messagedata = listen_message(HOST, MPORT)
progressdata = listen_progress(HOST, PPORT)

try
    include("test_console.jl")
    include("test_progress.jl")
    include("test_combined.jl")
finally
    close(messagedata.server)
    close(progressdata.server)
end

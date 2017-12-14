mutable struct LanguageServerInstance
    pipe_in
    pipe_out

    workspaceFolders::Set{String}
    documents::Dict{URI2,Document}

    loaded_modules::Dict{String,Tuple{Set{String},Set{String}}}
    debug_mode::Bool
    runlinter::Bool
    isrunning::Bool

    user_pkg_dir::String

    function LanguageServerInstance(pipe_in, pipe_out, debug_mode::Bool, user_pkg_dir::AbstractString = haskey(ENV, "JULIA_PKGDIR") ? ENV["JULIA_PKGDIR"] : joinpath(homedir(), ".julia"))
        loaded_modules = Dict{String,Tuple{Set{String},Set{String}}}()
        loaded_modules["Base"] = load_mod_names(Base)
        loaded_modules["Core"] = load_mod_names(Core)

        new(pipe_in, pipe_out, Set{String}(), Dict{URI2,Document}(), loaded_modules, debug_mode, false, false, user_pkg_dir)
    end
end

function send(message, server)
    message_json = JSON.json(message)

    write_transport_layer(server.pipe_out, message_json, server.debug_mode)
end

function Base.run(server::LanguageServerInstance)
    io = open("/home/zac/jls.log", "a")
    redirect_stderr(io)
    while true
        message = read_transport_layer(server.pipe_in, server.debug_mode)
        message_dict = JSON.parse(message)
        # For now just ignore response messages
        if haskey(message_dict, "method")
            request = parse(JSONRPC.Request, message_dict)
            server.isrunning && serverbusy(server)
            process(request, server)
            server.isrunning && serverready(server)
        end
    end
end

function serverbusy(server)
    write_transport_layer(server.pipe_out, JSON.json(Dict("jsonrpc" => "2.0", "method" => "window/setStatusBusy")), server.debug_mode)
end

function serverready(server)
    write_transport_layer(server.pipe_out, JSON.json(Dict("jsonrpc" => "2.0", "method" => "window/setStatusReady")), server.debug_mode)
end



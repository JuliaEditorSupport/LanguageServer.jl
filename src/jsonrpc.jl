module JSONRPC

using JSON
import Base.parse

export Request, Response, parse_params

mutable struct Request{method,Tparams}
    id::Nullable{Union{String,Int64}}
    params::Tparams
end

mutable struct Error
end

mutable struct Response{Tresult}
    id::Union{String,Int64}
    result::Nullable{Tresult}
    error::Nullable{Error}
end

Response(id, result) = Response(id, Nullable(result), Nullable{Error}())

mutable struct Notification{method,Tparams}
    params::Nullable{Tparams}
end

function parse_params end

function parse(::Type{Request}, message_dict::Dict)
    if message_dict["jsonrpc"] != "2.0"
        error("Invalid JSON-RPC version")
    end
    id = haskey(message_dict, "id") ? Nullable(message_dict["id"]) : Nullable{Union{String,Int64}}()
    method = Val{Symbol(message_dict["method"])}
    params = message_dict["params"]

    params_instance = parse_params(method, params)

    ret = Request{method,typeof(params_instance)}(id, params_instance)

    return ret
end

function JSON.json(request::Request{method,Tparams}) where {method, Tparams}
    request_dict = Dict()
    request_dict["jsonrpc"] = "2.0"
    request_dict["method"] = string(method.parameters[1])
    if !isnull(request.id)
        request_dict["id"] = get(request.id)
    end
    request_dict["params"] = request.params
    return JSON.json(request_dict)
end

function JSON.json(response::Response{TResult}) where {TResult}
    response_dict = Dict()
    response_dict["jsonrpc"] = "2.0"
    response_dict["id"] = response.id
    if !isnull(response.result)
        response_dict["result"] = get(response.result)
    elseif !isnull(response.error)
        error("Not yet implemented")
    else
        error("Invalid JSON-RPC response object.")
    end
    return JSON.json(response_dict)
end

function JSON.json(response::Notification{method,Tparams}) where {method, Tparams}
    notification_dict = Dict()
    notification_dict["jsonrpc"] = "2.0"
    notification_dict["method"] = string(method.parameters[1])
    notification_dict["params"] = response.params
    return JSON.json(notification_dict)
end

end

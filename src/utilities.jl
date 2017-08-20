function get_line(uri::AbstractString, line::Integer, server::LanguageServerInstance)
    doc = server.documents[uri]
    return get_line(doc, line)
end

function get_line(tdpp::TextDocumentPositionParams, server::LanguageServerInstance)
    return get_line(tdpp.textDocument.uri, tdpp.position.line + 1, server)
end

function get_word(tdpp::TextDocumentPositionParams, server::LanguageServerInstance, offset = 0)
    io = IOBuffer(get_line(tdpp, server))
    word = Char[]
    e = 0
    while !eof(io)
        c = read(io, Char)
        e += 1
        if (Base.is_id_start_char(c) || c == '@') || (c == '.' && e < (tdpp.position.character + offset))
            if isempty(word) && !(Base.is_id_start_char(c) || c == '@')
                continue
            end
            push!(word, c)
        else
            if e <= tdpp.position.character + offset
                empty!(word)
            else
                break
            end
        end
    end
    return String(word)
end


function unpack_dot(id, args = Symbol[])
    if id isa Expr && id.head == :. && id.args[2] isa QuoteNode
        if id.args[2].value isa Symbol && ((id.args[1] isa Expr && id.args[1].head == :.) || id.args[1] isa Symbol)
            unshift!(args, id.args[2].value)
            args = unpack_dot(id.args[1], args)
        else
            return Symbol[]
        end
    elseif id isa Symbol
        unshift!(args, id)
    else
        return Symbol[]
    end
    return args
end

_isdotexpr(x) = false
_isdotexpr(x::EXPR{CSTParser.BinarySyntaxOpCall}) = x.args[2] isa EXPR{CSTParser.OPERATOR{CSTParser.DotOp,Tokens.DOT,false}}

function unpack_dot(x::EXPR)
    args = EXPR[]
    val = x
    while _isdotexpr(val)
        if val.args[3] isa EXPR{Quotenode}
            unshift!(args, val.args[3].args[1])
        else
            unshift!(args, val.args[3])
        end
        val = val.args[1]
    end
    unshift!(args, val)
    return args
end


repack_dot(args::Symbol) = args
function repack_dot(args::Vector)
    if length(args) == 1
        return first(args)
    else
        return repack_dot([Expr(:., first(args), QuoteNode(args[2])); args[3:end]])
    end
end

function repack_dot(args::Vector{Symbol})
    if length(args) == 1
        return first(args)
    else
        out = Expr(:., args[1], QuoteNode(args[2]))
        for i = 3:length(args)
            out = Expr(:., out, QuoteNode(args[i]))
        end
        return out
    end
end

function make_name(ns, id)
    io = IOBuffer()
    for x in ns
        print(io, x)
        print(io, ".")
    end
    print(io, id)
    String(take!(io))
end

function get_module(ids::Vector{Symbol}, M = Main)
    if isempty(ids)
        return M
    elseif isdefined(M, first(ids))
        M = getfield(M, shift!(ids))
        return get_module(ids, M)
    else
        return false
    end
end

function _isdefined(x::Expr)
    ids = unpack_dot(x)
    return isempty(ids) ? false : _isdefined(ids)
end

function _isdefined(ids::Vector{Symbol}, M = Main)
    if isempty(ids)
        return true
    elseif isdefined(M, first(ids))
        M = getfield(M, shift!(ids))
        return _isdefined(ids, M)
    else
        return false
    end
end

function _getfield(names::Vector{Symbol})
    val = Main
    for i = 1:length(names)
        !isdefined(val, names[i]) && return
        val = getfield(val, names[i])
    end
    return val
end


function get_cache_entry(x, server, s::TopLevelScope) end

get_cache_entry(x::EXPR{IDENTIFIER}, server, s::TopLevelScope) = get_cache_entry(x.val, server, s)

get_cache_entry(x::EXPR{<:CSTParser.OPERATOR}, server, s::TopLevelScope) = get_cache_entry(string(Expr(x)), server, s)

function get_cache_entry(x::EXPR{CSTParser.BinarySyntaxOpCall}, server, s::TopLevelScope)
    ns = isempty(s.namespace) ? "toplevel" : join(s.namespace, ".")
    if x.args[2] isa EXPR{CSTParser.OPERATOR{CSTParser.DotOp,Tokens.DOT,false}}
        args = unpack_dot(x)
        if first(args) isa EXPR{IDENTIFIER} && (Symbol(first(args).val) in BaseCoreNames || (haskey(s.imported_names, ns) && first(args).val in s.imported_names[ns]))
            return _getfield(Expr.(args))
        end
    else
        return
    end
end

function get_cache_entry(x::String, server, s::TopLevelScope)
    ns = isempty(s.namespace) ? "toplevel" : join(s.namespace, ".")
    if Symbol(x) in BaseCoreNames && isdefined(Main, Symbol(x))
        return getfield(Main, Symbol(x))
    elseif haskey(s.imported_names, ns) && x in s.imported_names[ns]
        for (M, (exported, internal)) in server.loaded_modules
            splitmod = split(M, ".")
            if x == last(splitmod)
                return _getfield(Symbol.(splitmod))
            elseif x in internal
                return _getfield(vcat(Symbol.(splitmod), Symbol(x)))
            end
        end
    end
    return nothing
end

function uri2filepath(uri::AbstractString)
    uri_path = normpath(unescape(URI(uri).path))

    if is_windows()
        if uri_path[1] == '\\' || uri_path[1] == '/'
            uri_path = uri_path[2:end]
        end

        uri_path = lowercase(uri_path)
    end
    return uri_path
end

function filepath2uri(file::String)
    string("file://", normpath(file))
end

function should_file_be_linted(uri, server)
    !server.runlinter && return false

    uri_path = uri2filepath(uri)
    workspace_path = server.rootPath

    if is_windows()
        workspace_path = lowercase(workspace_path)
    end

    if isempty(server.rootPath)
        return false
    else
        return startswith(uri_path, workspace_path)
    end
end


sprintrange(range::Range) = "($(range.start.line + 1),$(range.start.character)):($(range.stop.line + 1),$(range.stop.character + 1))" 

CompletionItemKind(t) = t in [:String, :AbstractString] ? 1 : 
                                t == :Function ? 3 : 
                                t == :DataType ? 7 :  
                                t == :Module ? 9 : 6 

SymbolKind(t) = t in [:String, :AbstractString] ? 15 : 
                        t == :Function ? 12 : 
                        t == :DataType ? 5 :  
                        t == :Module ? 2 :
                        t == :Bool ? 17 : 13  

updatecache(absentmodule::Symbol, server) = updatecache([absentmodule], server)

function updatecache(absentmodules::Vector{Symbol}, server)
    for m in absentmodules
        @eval try import $m end
    end
end

type SymbolInformation 
    name::String 
    kind::Int 
    location::Location 
end 
 
function process(r::JSONRPC.Request{Val{Symbol("textDocument/documentSymbol")},DocumentSymbolParams}, server) 
    uri = r.params.textDocument.uri 
    doc = server.documents[uri]
    syms = SymbolInformation[]
    for (v, loc) in Parser.get_symbols(doc.blocks.ast)
        rng = Range(Position(get_position_at(doc, first(loc))..., one_based=true), Position(get_position_at(doc, last(loc))..., one_based=true))

        if v.t == :Function
            id = string(Expr(v.val.head isa Parser.KEYWORD{Parser.Tokens.FUNCTION} ? v.val[2] : v.val[1]))
        else
            id = string(v.id)
        end

        push!(syms, SymbolInformation(id, SymbolKind(v.t), Location(uri, rng)))
    end
    
    response = JSONRPC.Response(get(r.id), syms) 
    send(response, server) 
end

function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/documentSymbol")}}, params)
    return DocumentSymbolParams(params) 
end


function process(r::JSONRPC.Request{Val{Symbol("workspace/symbol")},WorkspaceSymbolParams}, server) 
    syms = SymbolInformation[]
    query = r.params.query
    for (uri, doc) in server.documents
        for (v, loc) in Parser.get_symbols(doc.blocks.ast)
            if ismatch(Regex(query, "i"), string(v.id))
                rng = Range(Position(get_position_at(doc, first(loc))..., one_based=true), Position(get_position_at(doc, last(loc))..., one_based=true))
                if v.t == :Function
                    id = string(Expr(v.val.head isa Parser.KEYWORD{Parser.Tokens.FUNCTION} ? v.val[2] : v.val[1]))
                else
                    id = string(v.id)
                end

                push!(syms, SymbolInformation(id, SymbolKind(v.t), Location(uri, rng)))
            end
        end
    end

    response = JSONRPC.Response(get(r.id), syms) 
    send(response, server) 
end

function JSONRPC.parse_params(::Type{Val{Symbol("workspace/symbol")}}, params)
    return WorkspaceSymbolParams(params) 
end
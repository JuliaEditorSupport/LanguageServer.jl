function process(r::JSONRPC.Request{Val{Symbol("textDocument/hover")}, TextDocumentPositionParams}, server)
    tdpp = r.params
    doc = server.documents[tdpp.textDocument.uri]
    offset = get_offset(doc, tdpp.position.line + 1, tdpp.position.character)

    y, Y, I, O, scope, modules, current_namespace = get_scope(doc, offset, server)

    if y isa CSTParser.IDENTIFIER || y isa CSTParser.OPERATOR
        entry = get_cache_entry(Expr(y), server, unique(modules))
        documentation = entry[1] != :EMPTY ? Any[entry[2]] : []
        for (v, loc, uri) in scope
            Ey = Expr(y)
            if Ey == v.id || (v.id isa Expr && v.id.head == :. && v.id.args[1] == current_namespace && Ey == v.id.args[2].value)
                if v.t == :Any
                    push!(documentation, MarkedString("julia", string(Expr(v.val))))
                else
                    push!(documentation, MarkedString(string(v.t)))
                end
            end
        end
    elseif y isa CSTParser.QUOTENODE && last(Y) isa CSTParser.EXPR && last(Y).head isa CSTParser.OPERATOR{16, Tokens.DOT}
        prefix = Expr(last(Y).args[1])
        entry = get_cache_entry(Expr(last(Y)), server, unique(modules))
        documentation = entry[1] != :EMPTY ? String[entry[2]] : String[]
    elseif y isa CSTParser.LITERAL
        documentation = [string(lowercase(string(typeof(y).parameters[1])), ":"), MarkedString(string(Expr(y)))]
    elseif y != nothing
        documentation = [string(Expr(y))]
    else
        documentation = [""]
    end
    response = JSONRPC.Response(get(r.id), Hover(documentation))
    send(response, server)
end

function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/hover")}}, params)
    return TextDocumentPositionParams(params)
end

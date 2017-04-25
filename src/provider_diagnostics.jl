
function parse_diag(doc, server)
    try
        ps = CSTParser.ParseState(doc._content)
        doc.code.ast, ps = CSTParser.parse(ps, true)
    catch er
        info("PARSING FAILED for $(doc._uri)")
    end
    try
        includes = String[]
        for incl in CSTParser._get_includes(doc.code.ast)
            if startswith(incl, "/")
                push!(includes, filepath2uri(incl))
            else
                push!(includes, joinpath(dirname(doc._uri), incl))
            end
        end
        doc.code.includes = includes
    catch er
        info("GETINCLUDES FAILED for $(doc._uri)")
    end
    # Lint/Formatting hints
    diags = map(ps.diagnostics) do h
        rng = Range(Position(get_position_at(doc, first(h.loc) + 1)..., one_based = true), Position(get_position_at(doc, last(h.loc) + 1)..., one_based = true))
        
        Diagnostic(rng, 2, string(typeof(h).parameters[1]), string(typeof(h).name), string(typeof(h).parameters[1]))
    end
    diags = unique(diags)

    # Errors
    if ps.errored
        info("parsing $(doc._uri) failed")
        ast = doc.code.ast
        if last(ast) isa CSTParser.ERROR
            if length(ast) > 1
                loc = sum(ast[i].span for i = 1:length(ast) - 1):sizeof(doc._content)
            else
                loc = 0:sizeof(doc._content)
            end
            rng = Range(Position(get_position_at(doc, first(loc) + 1)..., one_based = true), Position(get_position_at(doc, last(loc) + 1)..., one_based = true))
            push!(diags, Diagnostic(rng, 1, "Parse failure", "Unknown", "Parse failure"))
        end
    end

    publishDiagnosticsParams = PublishDiagnosticsParams(doc._uri, diags)
    response =  JSONRPC.Request{Val{Symbol("textDocument/publishDiagnostics")}, PublishDiagnosticsParams}(Nullable{Union{String, Int64}}(), publishDiagnosticsParams)
    send(response, server)
    
end
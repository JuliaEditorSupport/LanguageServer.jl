function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/didOpen")}}, params)
    return DidOpenTextDocumentParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/didOpen")},DidOpenTextDocumentParams}, server)
    server.isrunning = true
    uri = r.params.textDocument.uri
    server.documents[URI2(uri)] = Document(uri, r.params.textDocument.text, false)
    doc = server.documents[URI2(uri)]
    if any(i->startswith(uri, filepath2uri(i)), server.workspaceFolders)
        doc._workspace_file = true
    end
    set_open_in_editor(doc, true)
    if is_ignored(uri, server)
        doc._runlinter = false
    end
    parse_all(doc, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/didClose")}}, params)
    return DidCloseTextDocumentParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/didClose")},DidCloseTextDocumentParams}, server)
    uri = r.params.textDocument.uri
    !haskey(server.documents, URI2(uri)) && return
    doc = server.documents[URI2(uri)]
    empty!(doc.diagnostics)
    publish_diagnostics(doc, server)
    if !is_workspace_file(doc)
        delete!(server.documents, URI2(uri))
    else
        set_open_in_editor(doc, false)
    end
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/didChange")}}, params)
    return DidChangeTextDocumentParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/didChange")},DidChangeTextDocumentParams}, server)
    doc = server.documents[URI2(r.params.textDocument.uri)]
    doc._version = r.params.textDocument.version
    isempty(r.params.contentChanges) && return
    # dirty = get_offset(doc, last(r.params.contentChanges).range.start.line + 1, last(r.params.contentChanges).range.start.character + 1):get_offset(doc, first(r.params.contentChanges).range.stop.line + 1, first(r.params.contentChanges).range.stop.character + 1)
    # for c in r.params.contentChanges
    #     update(doc, c.range.start.line + 1, c.range.start.character + 1, c.rangeLength, c.text)
    # end
    doc._content = last(r.params.contentChanges).text
    doc._line_offsets = Nullable{Vector{Int}}()
    parse_all(doc, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/didSave")}}, params)
    return DidSaveTextDocumentParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/didSave")},DidSaveTextDocumentParams}, server)
    uri = r.params.textDocument.uri
    doc = server.documents[URI2(uri)]
    parse_all(doc, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/willSave")}}, params)
    return WillSaveTextDocumentParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/willSave")},WillSaveTextDocumentParams}, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/willSaveWaitUntil")}}, params)
    return WillSaveTextDocumentParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/willSaveWaitUntil")},WillSaveTextDocumentParams}, server)
    response = JSONRPC.Response(get(r.id), TextEdit[])
    send(response, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/codeAction")}}, params)
    return CodeActionParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/codeAction")},CodeActionParams}, server)
    if !haskey(server.documents, URI2(r.params.textDocument.uri))
        send(JSONRPC.Response(get(r.id), CancelParams(get(r.id))), server)
        return
    end
    doc = server.documents[URI2(r.params.textDocument.uri)]
    commands = Command[]
    range = r.params.range
    range_loc = get_offset(doc, range.start.line + 1, range.start.character):get_offset(doc, range.stop.line + 1, range.stop.character)
    
    tde = TextDocumentEdit(VersionedTextDocumentIdentifier(doc._uri, doc._version), [])
    action_type = Any
    tdeall = TextDocumentEdit(VersionedTextDocumentIdentifier(doc._uri, doc._version), [])
    for d in doc.diagnostics
        if first(d.loc) <= first(range_loc) <= last(range_loc) <= last(d.loc) && typeof(d).parameters[1] isa LintCodes && !isempty(d.actions) 
            action_type = typeof(d).parameters[1]
            for a in d.actions
                start_l, start_c = get_position_at(doc, first(a.range))
                end_l, end_c = get_position_at(doc, last(a.range))
                push!(tde.edits, TextEdit(Range(start_l - 1, start_c, end_l - 1, end_c), a.text))
            end
        end
    end
    file_actions = []
    for d in doc.diagnostics
        if typeof(d).parameters[1] == action_type && !isempty(d.actions) 
            for a in d.actions
                push!(file_actions, a)
                
            end
        end
    end
    sort!(file_actions, lt = (a, b) -> last(b.range) < first(a.range))
    for a in file_actions
        start_l, start_c = get_position_at(doc, first(a.range))
        end_l, end_c = get_position_at(doc, last(a.range))
        push!(tdeall.edits, TextEdit(Range(start_l - 1, start_c, end_l - 1, end_c), a.text))
    end

    if !isempty(tde.edits)
        push!(commands, Command("Fix deprecation", "language-julia.applytextedit", [WorkspaceEdit(nothing, [tde])]))
    end
    if !isempty(tdeall.edits)
        push!(commands, Command("Fix all similar deprecations in file", "language-julia.applytextedit", [WorkspaceEdit(nothing, [tdeall])]))
    end
    response = JSONRPC.Response(get(r.id), commands)
    send(response, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/completion")}}, params)
    return TextDocumentPositionParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/completion")},TextDocumentPositionParams}, server)
    if !haskey(server.documents, URI2(r.params.textDocument.uri))
        send(JSONRPC.Response(get(r.id), CancelParams(get(r.id))), server)
        return
    end
    tdpp = r.params
    y, s = scope(tdpp, server)
    line = get_line(tdpp, server)

    if isempty(line) || line == "\n" || tdpp.position.character == 0
        word = ""
    else
        word = let io = IOBuffer()
            if isempty(line)
                ""
            else
                rline = reverse(line[1:chr2ind(line, min(length(line), tdpp.position.character))])
                for (i, c) in enumerate(rline)
                    if c == '\\' || c == '@'
                        write(io, c)
                        break
                    end
                    if !(Base.is_id_char(c) || c == '.' || c == '_' || (c == '^' && i < length(rline) && rline[i + 1] == '\\'))
                        break
                    end
                    write(io, c)
                end
                reverse(String(take!(io)))
            end
        end
    end

    entries = Tuple{Symbol,Int,String}[]

    if word == "end"
        push!(entries, ("end", 6, "end"))
    elseif word == "else"
        push!(entries, ("else", 6, "else"))
    elseif word == "elseif"
        push!(entries, ("elseif", 6, "elseif"))
    elseif word == "catch"
        push!(entries, ("catch", 6, "catch"))
    elseif word == "finally"
        push!(entries, ("finally", 6, "finally"))
    end

    prefix = word[1:searchlast(word, '.')]
    if isempty(word) && isempty(prefix) && !CSTParser.isstring(y)
    elseif isempty(prefix) # Single word
        if startswith(word, "\\") # Latex completion
            for (k, v) in Base.REPLCompletions.latex_symbols
                if startswith(string(k), word)
                    push!(entries, (Base.REPLCompletions.latex_symbols[k], 1, k))
                    length(entries) > 200 && break
                end
            end
        else
            ns = isempty(s.namespace) ? "toplevel" : join(s.namespace, ".")
            if CSTParser.isstring(y) && isabspath(str_value(y))
                dloc = last(search(line, Regex(str_value(y)))) - last(search(line, Regex(word)))
                paths, loc, _ = Base.REPLCompletions.complete_path(str_value(y), length(str_value(y)) - dloc)
                for p in paths
                    push!(entries, (p, 17, ""))
                end
            else
                for name in BaseCoreNames
                    if startswith(string(name), word) && (isdefined(Base, name) || isdefined(Core, name))
                        x = getfield(Main, name)
                        doc = string(Docs.doc(Docs.Binding(Main, name)))
                        push!(entries, (string(name), CompletionItemKind(typeof(x)), doc))
                    end
                end
                if haskey(s.imported_names, ns)
                    for name in s.imported_names[ns]
                        if startswith(name, word) 
                            x = get_cache_entry(name, server, s)
                            # doc = string(Docs.doc(Docs.Binding(M, Symbol(name))))
                            push!(entries, (name, CompletionItemKind(typeof(x)), ""))
                        end
                    end
                end
                if y != nothing
                    Ey = Expr(y)
                    nsEy = make_name(s.namespace, Ey)
                    partial = ns == "toplevel" ? string(Ey) : nsEy
                    for (name, V) in s.symbols
                        if startswith(string(name), partial) 
                            push!(entries, (string(first(V).v.id), 6, ""))
                        end
                    end
                end
            end
        end
    else
        topmodname = Symbol(first(split(prefix, '.')))
        modname = unpack_dot(parse(strip(prefix, '.'), raise = false))
        M = get_module(modname)
        if M != false && M isa Module
            server.loaded_modules[strip(prefix, '.')] = load_mod_names(M)
        end
        partial = word[searchlast(word, '.') + 1:end]
        if strip(prefix, '.') in keys(server.loaded_modules)
            for name in server.loaded_modules[strip(prefix, '.')][2]
                if startswith(name, partial) && isdefined(M, Symbol(name))
                    x = getfield(M, Symbol(name))
                    doc = string(Docs.doc(Docs.Binding(M, Symbol(name))))
                    push!(entries, (name, CompletionItemKind(typeof(x)), doc))
                    length(entries) > 200 && break
                end
            end
        end
    end

    l, c = tdpp.position.line, tdpp.position.character
    CIs = CompletionItem[]
    for (comp, k, documentation) in entries
        newtext = string(comp)
        if startswith(documentation, "\\")
            label  = strip(documentation, '\\')
            documentation = newtext
            length(newtext) > 1 && (newtext = newtext[1:1])
        elseif k == 17 # file completion
            label = comp
            documentation = ""
        else
            label  = last(split(newtext, "."))
            documentation = replace(documentation, r"(`|\*\*)", "")
            documentation = replace(documentation, "\n\n", "\n")
        end

        if k == 1
            push!(CIs, CompletionItem(label, k, documentation, TextEdit(Range(l, c - endof(word) + endof(newtext), l, c), ""), [TextEdit(Range(l, c - endof(word), l, c - endof(word) + endof(newtext)), newtext)]))
        else
            push!(CIs, CompletionItem(label, k, documentation, TextEdit(Range(tdpp.position, tdpp.position), newtext[endof(word) - endof(prefix) + 1:end]), []))
        end
    end

    completion_list = CompletionList(true, unique(CIs))

    response =  JSONRPC.Response(get(r.id), completion_list)
    send(response, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/definition")}}, params)
    return TextDocumentPositionParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/definition")},TextDocumentPositionParams}, server)
    if !haskey(server.documents, URI2(r.params.textDocument.uri))
        send(JSONRPC.Response(get(r.id), CancelParams(get(r.id))), server)
        return
    end
    tdpp = r.params
    y, s = scope(tdpp, server)

    locations = Location[]
    if y isa IDENTIFIER || y isa OPERATOR
        if length(s.stack) > 1 && s.stack[end] isa EXPR{Quotenode} && s.stack[end-1] isa BinarySyntaxOpCall && CSTParser.is_dot(s.stack[end-1].op)
            x = get_cache_entry(s.stack[end-1], server, s)
        else
            x = get_cache_entry(y, server, s)
        end
    elseif y isa EXPR{Quotenode} && last(s.stack) isa BinarySyntaxOpCall && CSTParser.is_dot(last(s.stack).args[2])
        x = get_cache_entry(last(s.stack), server, s)
    else
        x = nothing
    end
    for m in methods(x)
        file = isabspath(string(m.file)) ? string(m.file) : Base.find_source_file(string(m.file))
        if (file, m.line) == DefaultTypeConstructorLoc || file == nothing
            continue
        end
        push!(locations, Location(filepath2uri(file), Range(m.line - 1, 0, m.line, 0)))
    end
    
    if y != nothing
        if y isa EXPR{CSTParser.Quotenode} && last(s.stack) isa BinarySyntaxOpCall && CSTParser.is_dot(last(s.stack).args[2])
            Ey = Expr(last(s.stack))
        else
            Ey = Expr(y)
        end
        nsEy = join(vcat(s.namespace, Ey), ".")
        if haskey(s.symbols, nsEy)
            for vl in s.symbols[nsEy]
                if Ey == vl.v.id || (vl.v.id isa Expr && vl.v.id.head == :. && vl.v.id.args[1] == ns && Ey == vl.v.id.args[2].value)
                    doc1 = server.documents[URI2(vl.uri)]
                    ws_offset = CSTParser.trailing_ws_length(vl.v.val)
                    loc1 = vl.loc.start:vl.loc.stop - ws_offset
                    push!(locations, Location(vl.uri, Range(doc1, loc1)))
                end
            end
        end
    end

    response = JSONRPC.Response(get(r.id), locations)
    send(response, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/formatting")}}, params)
    return DocumentFormattingParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/formatting")},DocumentFormattingParams}, server)
    if !haskey(server.documents, URI2(r.params.textDocument.uri))
        send(JSONRPC.Response(get(r.id), CancelParams(get(r.id))), server)
        return
    end
    doc = server.documents[URI2(r.params.textDocument.uri)]
    newcontent = DocumentFormat.format(doc._content)
    end_l, end_c = get_position_at(doc, sizeof(doc._content))
    lsedits = TextEdit[TextEdit(Range(0, 0, end_l - 1, end_c), newcontent)]

    response = JSONRPC.Response(get(r.id), lsedits)
    send(response, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/hover")}}, params)
    return TextDocumentPositionParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/hover")},TextDocumentPositionParams}, server)
    if !haskey(server.documents, URI2(r.params.textDocument.uri))
        send(JSONRPC.Response(get(r.id), CancelParams(get(r.id))), server)
        return
    end
    y, s = scope(r.params, server)
    
    if y isa IDENTIFIER || y isa OPERATOR
        if length(s.stack) > 1 && s.stack[end] isa EXPR{Quotenode} && s.stack[end-1] isa BinarySyntaxOpCall && CSTParser.is_dot(s.stack[end-1].op)
            x = get_cache_entry(s.stack[end-1], server, s)
            documentation = x == nothing ? Any[] : Any[string(Docs.doc(x))]
            get_scope_entry_doc(s.stack[end-1], s, documentation)
        else
            x = get_cache_entry(y, server, s)
            documentation = x == nothing ? Any[] : Any[string(Docs.doc(x))] 
            get_scope_entry_doc(y, s, documentation)
        end
    elseif y isa LITERAL
        documentation = [MarkedString(string(Expr(y), "::", CSTParser.infer_t(y)))]
    elseif y isa KEYWORD && y.kind == Tokens.END && !isempty(s.stack)
        expr_type = Expr(last(s.stack).args[1])
        documentation = [MarkedString("Closes `$expr_type` expression")]
    elseif CSTParser.is_rparen(y) && !isempty(s.stack)
        last_ex = last(s.stack)
        if last_ex isa EXPR{CSTParser.Call}
            documentation = [MarkedString("Closes `$(Expr(last_ex.args[1]))` call")]
        elseif last_ex isa EXPR{CSTParser.TupleH}
            documentation = [MarkedString("Closes a tuple")]
        else
            documentation = [""]
        end
    elseif y != nothing && !(y isa PUNCTUATION)
        documentation = [string(Expr(y))]
    else
        documentation = [""]
    end
    response = JSONRPC.Response(get(r.id), Hover(unique(documentation)))
    send(response, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/documentLink")}}, params)
    return DocumentLinkParams(params) 
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/documentLink")},DocumentLinkParams}, server)
    if !haskey(server.documents, URI2(r.params.textDocument.uri))
        send(JSONRPC.Response(get(r.id), CancelParams(get(r.id))), server)
        return
    end
    uri = r.params.textDocument.uri 
    doc = server.documents[URI2(uri)]
    links = Tuple{String,UnitRange{Int}}[]
    # get_links(doc.code.ast, 0, uri, server, links)
    doclinks = DocumentLink[]
    for (uri2, loc) in links
        rng = Range(Position(get_position_at(doc, first(loc))..., one_based = true), Position(get_position_at(doc, last(loc))..., one_based = true))
        push!(doclinks, DocumentLink(rng, uri2))
    end

    response = JSONRPC.Response(get(r.id), links) 
    send(response, server) 
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/references")}}, params)
    return ReferenceParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/references")},ReferenceParams}, server)
    if !haskey(server.documents, URI2(r.params.textDocument.uri))
        send(JSONRPC.Response(get(r.id), CancelParams(get(r.id))), server)
        return
    end
    tdpp = r.params
    uri = tdpp.textDocument.uri
    doc = server.documents[URI2(tdpp.textDocument.uri)]
    offset = get_offset(doc, tdpp.position.line + 1, tdpp.position.character)
    
    locations = references(doc, offset, server)
    response = JSONRPC.Response(get(r.id), locations)
    send(response, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/rename")}}, params)
    return RenameParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/rename")},RenameParams}, server)
    if !haskey(server.documents, URI2(r.params.textDocument.uri))
        send(JSONRPC.Response(get(r.id), CancelParams(get(r.id))), server)
        return
    end
    rp = r.params
    uri = rp.textDocument.uri
    doc = server.documents[URI2(uri)]
    offset = get_offset(doc, rp.position.line + 1, rp.position.character)
    
    locations = references(doc, offset, server)

    tdes = Dict{String,TextDocumentEdit}()
    for loc in locations
        if loc.uri in keys(tdes)
            push!(tdes[loc.uri].edits, TextEdit(loc.range, rp.newName))
        else
            tdes[loc.uri] = TextDocumentEdit(VersionedTextDocumentIdentifier(loc.uri, server.documents[URI2(loc.uri)]._version), [TextEdit(loc.range, rp.newName)])
        end
    end

    we = WorkspaceEdit(nothing, collect(values(tdes)))
    response = JSONRPC.Response(get(r.id), we)
    send(response, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/signatureHelp")}}, params)
    return TextDocumentPositionParams(params)
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/signatureHelp")},TextDocumentPositionParams}, server)
    if !haskey(server.documents, URI2(r.params.textDocument.uri))
        send(JSONRPC.Response(get(r.id), CancelParams(get(r.id))), server)
        return
    end
    y,s = scope(r.params, server)
    if CSTParser.is_rparen(y)
        return send(JSONRPC.Response(get(r.id), CancelParams(Dict("id" => get(r.id)))), server)
    elseif length(s.stack) > 0 && last(s.stack) isa EXPR{Call}
        fcall = s.stack[end]
        fname = CSTParser.get_name(last(s.stack))
        x = get_cache_entry(fname, server, s)
    elseif length(s.stack) > 1 && CSTParser.is_comma(s.stack[end]) && s.stack[end-1] isa EXPR{Call}
        fcall = s.stack[end-1]
        fname = CSTParser.get_name(fcall)
        x = get_cache_entry(fname, server, s)
    else
        return send(JSONRPC.Response(get(r.id), CancelParams(Dict("id" => get(r.id)))), server)
    end
    arg = sum(!(a isa PUNCTUATION) for a in fcall.args) - 1

    sigs = SignatureHelp(SignatureInformation[], 0, 0)

    for m in methods(x)
        args = Base.arg_decl_parts(m)[2]
        p_sigs = [join(string.(p), "::") for p in args[2:end]]
        desc = string(m)
        PI = map(ParameterInformation, p_sigs)
        push!(sigs.signatures, SignatureInformation(desc, "", PI))
    end
    
    
    nsEy = join(vcat(s.namespace, str_value(fname)), ".")
    if haskey(s.symbols, nsEy)
        for vl in s.symbols[nsEy]
            if vl.v.t == :function
                sig = CSTParser.get_sig(vl.v.val)
                if sig isa CSTParser.BinarySyntaxOpCall && CSTParser.is_decl(sig.op)
                    sig = sig.arg1
                end
                Ps = ParameterInformation[]
                for j = 2:length(sig.args)
                    if sig.args[j] isa EXPR{CSTParser.Parameters}
                        for parg in sig.args[j].args
                            if !(sig.args[j] isa PUNCTUATION)
                                arg_id = str_value(CSTParser._arg_id(sig.args[j]))
                                arg_t = CSTParser.get_t(sig.args[j])
                                push!(Ps, ParameterInformation(string(arg_id,"::",arg_t)))
                            end
                        end
                    else
                        if !(sig.args[j] isa PUNCTUATION)
                            arg_id = str_value(CSTParser._arg_id(sig.args[j]))
                            arg_t = CSTParser.get_t(sig.args[j])
                            push!(Ps, ParameterInformation(string(arg_id,"::",arg_t)))
                        end
                    end
                end
                push!(sigs.signatures, SignatureInformation(string(Expr(sig)), "", Ps))
            end
        end
    end
    

    signatureHelper = SignatureHelp(filter(s -> length(s.parameters) > arg, sigs.signatures), 0, arg)
    response = JSONRPC.Response(get(r.id), signatureHelper)
    
    send(response, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/documentSymbol")}}, params)
    return DocumentSymbolParams(params) 
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/documentSymbol")},DocumentSymbolParams}, server) 
    if !haskey(server.documents, URI2(r.params.textDocument.uri))
        send(JSONRPC.Response(get(r.id), CancelParams(get(r.id))), server)
        return
    end
    uri = r.params.textDocument.uri 
    doc = server.documents[URI2(uri)]
    syms = SymbolInformation[]
    s = toplevel(doc, server, false)
    for k in keys(s.symbols)
        for vl in s.symbols[k]
            if vl.v.t == :Function
                id = string(Expr(vl.v.val isa EXPR{CSTParser.FunctionDef} ? vl.v.val.args[2] : vl.v.val.args[1]))
            else
                id = string(vl.v.id)
            end
            ws_offset = CSTParser.trailing_ws_length(vl.v.val)
            loc1 = vl.loc.start:vl.loc.stop - ws_offset
            push!(syms, SymbolInformation(id, SymbolKind(vl.v.t), Location(vl.uri, Range(doc, loc1))))
        end
    end
    
    response = JSONRPC.Response(get(r.id), syms) 
    send(response, server) 
end
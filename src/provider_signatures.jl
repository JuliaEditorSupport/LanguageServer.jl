## helper function for function signatures ##

type ParameterInformation
    label::String
    #documentation::String
end

type SignatureInformation
    label::String
    documentation::String
    parameters::Vector{ParameterInformation}
end

type SignatureHelp
    signatures::Vector{SignatureInformation}
    activeSignature::Int
    activeParameter::Int
end

function process(r::JSONRPC.Request{Val{Symbol("textDocument/signatureHelp")},TextDocumentPositionParams}, server)
    tdpp = r.params
    pos = pos0 = tdpp.position.character
    io = IOBuffer(get_line(tdpp, server))
    
    line = []
    cnt = 0
    while cnt<pos && !eof(io)
        cnt += 1
        push!(line, read(io, Char))
    end
    
    arg = b = 0
    word = "" 
    while pos>1
        if line[pos]=='(' 
            if b==0
                 word = get_word(tdpp, server, pos-pos0-1)
                break
            elseif b>0
                b -= 1
            end
        elseif line[pos]==',' && b==0
            arg += 1
        elseif line[pos]==')'
            b += 1
        end
        pos -= 1
    end
    
    if word==""
        response = JSONRPC.Response(get(r.id), CancelParams(Dict("id"=>get(r.id))))
    else
        x = get_sym(word)
        M = methods(x).ms
        sigs = SignatureInformation[]
        for m in M
            tv, decls, file, line = Base.arg_decl_parts(m)
            
            p_sigs = [isempty(i[2]) ? i[1] : i[1]*"::"*i[2] for i in decls[2:end]]
            desc = string(string(m.name), "(", join(p_sigs, ", "), ")")

            PI = map(ParameterInformation, p_sigs)
            doc = ""
            (length(decls)-1>arg) && push!(sigs, SignatureInformation(desc, doc, PI))
        end
        
        signatureHelper = SignatureHelp(sigs, 0, arg)
        response = JSONRPC.Response(get(r.id), signatureHelper)
    end
    send(response, server)
end


function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/signatureHelp")}}, params)
    return TextDocumentPositionParams(params)
end

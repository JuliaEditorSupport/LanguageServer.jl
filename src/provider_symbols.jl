## provides a list of user defined symbols ##

type DocumentSymbolParams 
    textDocument::TextDocumentIdentifier 
end 
DocumentSymbolParams(d::Dict) = DocumentSymbolParams(TextDocumentIdentifier(d["textDocument"]))

type SymbolInformation 
    name::String 
    kind::Int 
    location::Location 
end 
 
function process(r::JSONRPC.Request{Val{Symbol("textDocument/documentSymbol")},DocumentSymbolParams}, server) 
    uri = r.params.textDocument.uri 
    blocks = server.documents[uri].blocks 
    syms = SymbolInformation[] 
    for b in blocks 
        if b.var.t=="Function" 
            push!(syms,SymbolInformation(b.name,12,Location(uri,b.range))) 
        elseif b.var.t=="DataType" 
            push!(syms,SymbolInformation(b.name,5,Location(uri,b.range))) 
        elseif b.name!="none" 
            push!(syms,SymbolInformation(b.name,13,Location(uri,b.range))) 
        end 
    end 
    response = JSONRPC.Response(get(r.id), syms) 
    send(response, server) 
end 
 
function JSONRPC.parse_params(::Type{Val{Symbol("textDocument/documentSymbol")}}, params) 
    return DocumentSymbolParams(params) 
end
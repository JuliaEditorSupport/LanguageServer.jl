import LanguageServer: LanguageServerInstance, Document
server = LanguageServerInstance(IOBuffer(), IOBuffer(), false)
LanguageServer.process(LanguageServer.parse(LanguageServer.JSONRPC.Request,init_request), server)


function getresult(server)
    str = String(take!(server.pipe_out))
    JSON.parse(str[search(str, '{'):end])["result"]["contents"]
end

testtext = """module testmodule
type testtype
    a
    b::Float64
    c::Vector{Float64}
end

function testfunction(a, b::Float64, c::testtype)
    return c
end
end
"""

server.documents["testdoc"] = Document("testdoc", testtext, true)
doc = server.documents["testdoc"]
LanguageServer.parse_all(doc, server)

# clear init output
take!(server.pipe_out)

LanguageServer.process(LanguageServer.parse(LanguageServer.JSONRPC.Request, """{"jsonrpc":"2.0","id":1,"method":"textDocument/hover","params":{"textDocument":{"uri":"testdoc"},"position":{"line":0,"character":12}}}"""), server)

res = getresult(server)

@test res[1]["value"] == "module"

LanguageServer.process(LanguageServer.parse(LanguageServer.JSONRPC.Request, """{"jsonrpc":"2.0","id":1,"method":"textDocument/hover","params":{"textDocument":{"uri":"testdoc"},"position":{"line":1,"character":9}}}"""), server)

res = getresult(server)

@test res[1]["value"] == "mutable"


LanguageServer.process(LanguageServer.parse(LanguageServer.JSONRPC.Request, """{"jsonrpc":"2.0","id":1,"method":"textDocument/hover","params":{"textDocument":{"uri":"testdoc"},"position":{"line":7,"character":19}}}"""), server)

res = getresult(server)

@test res[1]["value"] == "testfunction(a, b::Float64, c::testtype)"
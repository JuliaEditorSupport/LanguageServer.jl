import StaticLint: hasfile, canloadfile, loadfile, setfile, getfile, getsymbolserver
import StaticLint: getpath, setpath, getroot, setroot, getcst, setcst, scopepass, getserver, setserver
hasfile(server::LanguageServerInstance, path::String) = hasdocument(server, URI2(filepath2uri(path)))
canloadfile(server::LanguageServerInstance, path::String) = isfile(path)
function loadfile(server::LanguageServerInstance, path::String)
    source = read(path, String)
    # Don't load invalid files
    isvalid(source) || return
    uri = filepath2uri(path)
    doc = Document(uri, source, true, server)
    StaticLint.setfile(server, path, doc)
end
function setfile(server::LanguageServerInstance, path::String, x::Document)
    uri = URI2(filepath2uri(path))
    if hasdocument(server, uri)
        error("StaticLint should not try to set documents that are already tracked.")
    end

    setdocument!(server, uri, x)
end
getfile(server::LanguageServerInstance, path::String) = getdocument(server, URI2(filepath2uri(path)))
getsymbolserver(server::LanguageServerInstance) = server.symbol_store

getpath(d::Document) = d.path
function setpath(d::Document, path::String)
    d.path = path
    return d
end

getroot(d::Document) = d.root
function setroot(d::Document, root::Document)
    d.root = root
    return d
end

getcst(d::Document) = d.cst
function setcst(d::Document, cst::EXPR)
    d.cst = cst
    return d
end

getserver(file::Document) = file.server
function setserver(file::Document, server::LanguageServerInstance)
    file.server = server
    return file
end
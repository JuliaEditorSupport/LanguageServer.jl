const BaseCoreNames = Set(vcat(names(Base), names(Core), :end, :new, :ccall))

"""
    isincludable(x)
Checks whether `x` is an expression that includes a file.
"""
isincludable(x) = false
function isincludable(x::EXPR{Call})
    x.args[1] isa EXPR{IDENTIFIER} && x.args[1].val == "include" && length(x.args) == 4 && (x.args[3] isa EXPR{LITERAL{Tokens.STRING}} || x.args[3] isa EXPR{LITERAL{Tokens.TRIPLE_STRING}})
end

"""
    isimport(x)
Checks whether `x` is an expression that imports a module.
"""
isimport(x) = false
isimport(x::EXPR{T}) where T <: Union{CSTParser.Import,CSTParser.ImportAll,CSTParser.Using} = true

"""
    ismodule(x)
Checks whether `x` is an expression that declares a module.
"""
ismodule(x) = false
ismodule(x::EXPR{T}) where T <: Union{CSTParser.ModuleH,CSTParser.BareModule} = true

"""
    findtopfile(uri::String, server, path = String[], namespace = [])

Checks for files that include `uri` then recursively finds the top of that 
tree returning the sequence of files - `path` - and any namespaces introduced - 
`namespace`.
"""
function findtopfile(uri::String, server, path = String[], namespace = [])
    follow = []
    for (uri1, doc1) in server.documents
        for (incl, ns) in doc1.code.includes
            if uri == incl
                append!(namespace, ns)
                push!(follow, uri1)
            end
        end
    end

    if isempty(follow)
        push!(path, uri)
        return path, reverse(namespace)
    else
        if length(follow) > 1
            for f in follow
                warn("$uri is included by more than one file, following the first: $f")
            end
        end
        if uri in path
            response = JSONRPC.Notification{Val{Symbol("window/showMessage")},ShowMessageParams}(ShowMessageParams(3, "Circular reference detected in : $uri"))
            send(response, server)
            return path, namespace
        end
        push!(path, uri)
        return findtopfile(first(follow), server, path, namespace)
    end
end

function _get_includes(x, files = []) end
function _get_includes(x::EXPR{Call}, files = [])
    if isincludable(x)
        push!(files, (normpath(x.args[3].val), []))
    end
    return files
end


function _get_includes(x::EXPR, files = [])
    for a in x.args
        if a isa EXPR{CSTParser.ModuleH} || a isa EXPR{CSTParser.BareModule}
            mname = Expr(a.args[2])
            files1 = _get_includes(a)
            for (f, ns) in files1
                push!(files, (f, vcat(mname, ns)))
            end
        elseif !(x isa EXPR{Call})
            _get_includes(a, files)
        end
    end
    return files
end

iserrorexpr(x::Expr) = x.head == :error
iserrorexpr(x) = false


_get_fparams(x::EXPR, args = Symbol[]) = args

function _get_fparams(x::EXPR{Call}, args = Symbol[])
    if x.args[1] isa EXPR{CSTParser.Curly}
        _get_fparams(x.args[1], args)
    end
    unique(args)
end

function _get_fparams(x::EXPR{CSTParser.Curly}, args = Symbol[])
    for i = 3:length(x.args)
        a = x.args[i]
        if !(a isa EXPR{<:CSTParser.PUNCTUATION})
            if a isa EXPR{IDENTIFIER}
                push!(args, Expr(a))
            elseif a isa EXPR{CSTParser.BinarySyntaxOpCall} && a.args[2] isa EXPR{CSTParser.OPERATOR{CSTParser.ComparisonOp,Tokens.ISSUBTYPE,false}}
                push!(args, Expr(a).args[1])
            end
        end
    end
    unique(args)
end

function _get_fparams(x::EXPR{CSTParser.BinarySyntaxOpCall}, args = Symbol[])
    if x.args[2] isa EXPR{CSTParser.OPERATOR{CSTParser.WhereOp,Tokens.WHERE,false}}
        if x.args[1] isa EXPR{CSTParser.BinarySyntaxOpCall} && x.args[1].args[2] isa EXPR{CSTParser.OPERATOR{CSTParser.WhereOp,Tokens.WHERE,false}}
            _get_fparams(x.args[1], args)
        end
        for i = 3:length(x.args)
            a = x.args[i]
            if !(a isa EXPR{<:CSTParser.PUNCTUATION})
                if a isa EXPR{IDENTIFIER}
                    push!(args, Expr(a))
                elseif a isa EXPR{CSTParser.BinarySyntaxOpCall} && a.args[2] isa EXPR{CSTParser.OPERATOR{CSTParser.ComparisonOp,Tokens.ISSUBTYPE,false}} && a.args[1] isa EXPR{IDENTIFIER}
                    push!(args, Expr(a.args[1]))
                end
            end
        end
    end
    return unique(args)
end

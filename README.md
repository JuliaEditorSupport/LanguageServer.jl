# LanguageServer

[![Project Status: Active - The project has reached a stable, usable state and is being actively developed.](http://www.repostatus.org/badges/latest/active.svg)](http://www.repostatus.org/#active)
![](https://github.com/julia-vscode/LanguageServer.jl/workflows/Run%20CI%20on%20master/badge.svg)
[![codecov](https://codecov.io/gh/julia-vscode/LanguageServer.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/julia-vscode/LanguageServer.jl)

## Overview

This package implements the Microsoft [Language Server Protocol](https://github.com/Microsoft/language-server-protocol)
for the [Julia](http://julialang.org/) programming language.

Text editors with a client for the Language Server Protocol are able to
make use of the Julia Language Server for various code editing features:

- [VS Code](https://marketplace.visualstudio.com/items?itemName=julialang.language-julia)
- [Atom](https://github.com/pfitzseb/atom-julia-lsp-client)
- [Vim and Neovim](../../wiki/Vim-and-Neovim)
- [Emacs](../../wiki/Emacs)
- [Sublime Text](https://github.com/tomv564/LSP)

## Installation and Usage
**Documentation**: [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://www.julia-vscode.org/LanguageServer.jl/dev)

```julia
using Pkg
Pkg.add("LanguageServer")
```

Instantiate an instance of the language server with
`LanguageServerInstance` and `run` it:

```julia
using LanguageServer, LanguageServer.SymbolServer

server = LanguageServerInstance(stdin, stdout, false, "/path/to/environment")
run(server)
```

const textDocument_codeAction_request_type = JSONRPC.RequestType("textDocument/codeAction", CodeActionParams, Union{Vector{Command}, Vector{CodeAction}, Nothing})
const textDocument_completion_request_type = JSONRPC.RequestType("textDocument/completion", CompletionParams, Union{CompletionList, Vector{CompletionItem}, Nothing})
const textDocument_signatureHelp_request_type = JSONRPC.RequestType("textDocument/signatureHelp", TextDocumentPositionParams, Union{SignatureHelp, Nothing})
const textDocument_definition_request_type = JSONRPC.RequestType("textDocument/definition", TextDocumentPositionParams, Union{Location, Vector{Location}, Vector{LocationLink}, Nothing})
const textDocument_formatting_request_type = JSONRPC.RequestType("textDocument/formatting", DocumentFormattingParams, Union{Vector{TextEdit}, Nothing})
const textDocument_references_request_type = JSONRPC.RequestType("textDocument/references", ReferenceParams, Union{Vector{Location}, Nothing})
const textDocument_rename_request_type = JSONRPC.RequestType("textDocument/rename", RenameParams, Union{WorkspaceEdit, Nothing})
const textDocument_documentSymbol_request_type = JSONRPC.RequestType("textDocument/documentSymbol", DocumentSymbolParams, Union{Vector{DocumentSymbol}, Vector{SymbolInformation}, Nothing})
const textDocument_documentHighlight_request_type = JSONRPC.RequestType("textDocument/documentHighlight", DocumentHighlightParams, Union{Vector{DocumentHighlight}, Nothing})
const textDocument_semanticTokens_request_type = JSONRPC.RequestType("textDocument/semanticTokens", SemanticTokensParams, Union{SemanticTokens, Nothing})
const textDocument_semanticTokens_full_request_type = JSONRPC.RequestType("textDocument/semanticTokens/full", SemanticTokensParams, Union{SemanticTokens, Nothing})
const textDocument_hover_request_type = JSONRPC.RequestType("textDocument/hover", TextDocumentPositionParams, Union{Hover, Nothing})
const textDocument_didOpen_notification_type = JSONRPC.NotificationType("textDocument/didOpen", DidOpenTextDocumentParams)
const textDocument_didClose_notification_type = JSONRPC.NotificationType("textDocument/didClose", DidCloseTextDocumentParams)
const textDocument_didChange_notification_type = JSONRPC.NotificationType("textDocument/didChange", DidChangeTextDocumentParams)
const textDocument_didSave_notification_type = JSONRPC.NotificationType("textDocument/didSave", DidSaveTextDocumentParams)
const textDocument_willSave_notification_type = JSONRPC.NotificationType("textDocument/willSave", WillSaveTextDocumentParams)
const textDocument_willSaveWaitUntil_request_type = JSONRPC.RequestType("textDocument/willSaveWaitUntil", WillSaveTextDocumentParams, Union{Vector{TextEdit}, Nothing})
const textDocument_publishDiagnostics_notification_type = JSONRPC.NotificationType("textDocument/publishDiagnostics", PublishDiagnosticsParams)
const textDocument_selectionRange_request_type = JSONRPC.RequestType("textDocument/selectionRange", SelectionRangeParams, Union{Vector{SelectionRange}, Nothing})

const workspace_executeCommand_request_type = JSONRPC.RequestType("workspace/executeCommand", ExecuteCommandParams, Any)
const workspace_symbol_request_type = JSONRPC.RequestType("workspace/symbol", WorkspaceSymbolParams, Union{Vector{SymbolInformation}, Nothing})
const workspace_didChangeWatchedFiles_notification_type = JSONRPC.NotificationType("workspace/didChangeWatchedFiles", DidChangeWatchedFilesParams)
const workspace_didChangeConfiguration_notification_type = JSONRPC.NotificationType("workspace/didChangeConfiguration", DidChangeConfigurationParams)
const workspace_didChangeWorkspaceFolders_notification_type = JSONRPC.NotificationType("workspace/didChangeWorkspaceFolders", DidChangeWorkspaceFoldersParams)
const workspace_applyEdit_request_type = JSONRPC.RequestType("workspace/applyEdit", ApplyWorkspaceEditParams, ApplyWorkspaceEditResponse)
const workspace_configuration_request_type = JSONRPC.RequestType("workspace/configuration", ConfigurationParams, Vector{Any})
const julia_activateenvironment_notification_type = JSONRPC.NotificationType("julia/activateenvironment", NamedTuple{(:envPath,),Tuple{String}})
const julia_refreshLanguageServer_notification_type = JSONRPC.NotificationType("julia/refreshLanguageServer", Nothing)

const initialize_request_type = JSONRPC.RequestType("initialize", InitializeParams, InitializeResult)
const initialized_notification_type = JSONRPC.NotificationType("initialized", InitializedParams)
const shutdown_request_type = JSONRPC.RequestType("shutdown", Nothing, Nothing)
const exit_notification_type = JSONRPC.NotificationType("exit", Nothing)
const client_registerCapability_request_type = JSONRPC.RequestType("client/registerCapability", RegistrationParams, Nothing)

const cancel_notification_type = JSONRPC.NotificationType("\$/cancelRequest", CancelParams)
const setTrace_notification_type = JSONRPC.NotificationType("\$/setTrace", SetTraceParams)
# TODO This seems to not exist in the spec?
const setTraceNotification_notification_type = JSONRPC.NotificationType("\$/setTraceNotification", Nothing)

const window_workDoneProgress_create_request_type = JSONRPC.RequestType("window/workDoneProgress/create", WorkDoneProgressCreateParams, Nothing)
const window_showMessage_notification_type = JSONRPC.NotificationType("window/showMessage", ShowMessageRequestParams)

const progress_notification_type = JSONRPC.NotificationType("\$/progress", ProgressParams)

const telemetry_event_notification_type = JSONRPC.NotificationType("telemetry/event", Any)

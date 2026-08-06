let grammars =
  let t = TmLanguage.create () in
  let () =
    [ Hilite.Grammars.ocaml
    ; Hilite.Grammars.ocaml_interface
    ; Hilite.Grammars.dune
    ; Hilite.Grammars.opam
    ; Hilite.Grammars.diff
    ; Yojson.Basic.from_string Elixir_grammar.json
    ; Yojson.Basic.from_string Shell_grammar.json
    ]
    |> List.iter (fun g -> g |> TmLanguage.of_yojson_exn |> TmLanguage.add_grammar t)
  in
  t

let highlight = Yocaml_markdown.Doc.syntax_highlighting ~tm:grammars ()
let to_html = Yocaml_markdown.from_string_to_html ~highlight

let prepare_md ~metadata =
  let parameters = metadata |> List.map (fun (k, v) -> k, Yocaml_jingoo.from v) in
  Yocaml_jingoo.render ~strict:false parameters

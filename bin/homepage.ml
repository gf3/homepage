open Yocaml

type document_kind =
  | Page
  | Article

let www = Path.rel [ "_www" ]
let assets = Path.rel [ "assets" ]
let content = Path.rel [ "content" ]
let images = Path.(assets / "images")
let fonts = Path.(assets / "fonts")
let css = Path.(assets / "css")
let templates = Path.(assets / "templates")
let pages = Path.(content / "pages")
let articles = Path.(content / "articles")
let with_ext exts file = List.exists (fun ext -> Path.has_extension ext file) exts
let track_binary = Sys.executable_name |> Yocaml.Path.from_string |> Pipeline.track_file

let copy_images =
  let images_path = Path.(www / "images")
  and where = with_ext [ "svg"; "png"; "jpg"; "gif"; "webp" ] in
  Batch.iter_files ~where images (Action.copy_file ~into:images_path)

let copy_fonts =
  let fonts_path = Path.(www / "fonts")
  and where = with_ext [ "ttf"; "otf"; "woff"; "woff2" ] in
  Batch.iter_files ~where fonts (Action.copy_file ~into:fonts_path)

let create_css =
  let css_path = Path.(www / "style.css") in
  let pipeline =
    let open Task in
    let+ () = track_binary
    and+ content =
      Pipeline.pipe_files ~separator:"\n" Path.[ css / "reset.css"; css / "style.css" ]
    in
    content
  in
  Action.Static.write_file css_path pipeline

let is_md = with_ext [ "md" ]

let compute_link source =
  let into = Path.abs [ "articles" ] in
  source |> Path.move ~into |> Path.change_extension "html"

let document_path document_kind path =
  let into =
    match document_kind with
    | Page -> www
    | Article -> Path.(www / "articles")
  in
  path |> Path.move ~into |> Path.change_extension "html"

let get_specific_template document_kind =
  let file =
    match document_kind with
    | Page -> "page.html"
    | Article -> "article.html"
  in
  Path.(templates / file)

let document_sources = function
  | Page -> pages
  | Article -> articles

module type ARCHETYPE = sig
  include Yocaml.Required.DATA_INJECTABLE
  include Yocaml.Required.DATA_READABLE with type t := t
end

let document_archetype : document_kind -> (module ARCHETYPE) = function
  | Page -> (module Archetype.Page)
  | Article -> (module Archetype.Article)

let create_document document_kind source =
  let module Archetype = (val document_archetype document_kind) in
  let target = document_path document_kind source
  and pipeline =
    let open Task in
    let+ () = track_binary
    and+ templates =
      Yocaml_jingoo.read_templates
        Path.[ get_specific_template document_kind; templates / "layout.html" ]
    and+ metadata, content =
      Yocaml_yaml.Pipeline.read_file_with_metadata (module Archetype) source
    in
    content
    |> Yocaml_markdown.from_string_to_html
    |> templates (module Archetype) ~metadata
  in
  Action.Static.write_file target pipeline

let create_documents document_kind =
  let where = is_md in
  let sources = document_sources document_kind in
  Batch.iter_files ~where sources (create_document document_kind)

let create_pages = create_documents Page
let create_articles = create_documents Article

let fetch_articles =
  Archetype.Articles.fetch ~where:is_md ~compute_link (module Yocaml_yaml) articles

let create_index =
  let source = Path.(content / "index.md") in
  let index_path = source |> Path.move ~into:www |> Path.change_extension "html" in
  let pipeline =
    let open Task in
    let+ () = track_binary
    and+ templates =
      Yocaml_jingoo.read_templates
        Path.
          [ templates / "index.html"; templates / "page.html"; templates / "layout.html" ]
    and+ articles = fetch_articles
    and+ metadata, content =
      Yocaml_yaml.Pipeline.read_file_with_metadata (module Archetype.Page) source
    in
    let metadata = Archetype.Articles.with_page ~page:metadata ~articles in
    content
    |> Yocaml_markdown.from_string_to_html
    |> templates (module Archetype.Articles) ~metadata
  in
  Action.Static.write_file index_path pipeline

module Feed = struct
  let path = "atom.xml"
  let title = "okgreat"
  let site_url = "https://okgreat.ca"
  let feed_description = "A dangerous place to idle."

  let owner =
    Yocaml_syndication.Person.make
      ~uri:site_url
      ~email:"gianni@okgreat.ca"
      "Gianni Chiappetta"

  let authors = Nel.singleton owner

  let article_to_entry (url, article) =
    let open Yocaml.Archetype in
    let open Yocaml_syndication in
    let page = Article.page article in
    let title = Article.title article
    and content_url = site_url ^ Path.to_string url
    and updated = Datetime.make (Article.date article)
    and categories = List.map Category.make (Page.tags page)
    and summary = Option.map Atom.text (Page.description page) in
    let links = [ Atom.alternate content_url ~title ] in
    Atom.entry
      ~links
      ~categories
      ?summary
      ~updated
      ~id:content_url
      ~title:(Atom.text title)
      ()

  let make entries =
    let open Yocaml_syndication in
    Atom.feed
      ~title:(Atom.text title)
      ~subtitle:(Atom.text feed_description)
      ~updated:(Atom.updated_from_entries ())
      ~authors
      ~id:site_url
      article_to_entry
      entries
end

let create_feed =
  let feed_path = Path.(www / Feed.path)
  and pipeline =
    let open Task in
    let+ () = track_binary
    and+ articles = fetch_articles in
    articles |> Feed.make |> Yocaml_syndication.Xml.to_string
  in
  Action.Static.write_file feed_path pipeline

let program () =
  let open Eff in
  let cache = Path.(www / ".cache") in
  Action.restore_cache cache
  >>= copy_images
  >>= copy_fonts
  >>= create_css
  >>= create_pages
  >>= create_articles
  >>= create_index
  >>= create_feed
  >>= Action.store_cache cache

let () =
  match Sys.argv.(1) with
  | "serve" -> Yocaml_unix.serve ~level:`Info ~target:www ~port:8000 program
  | _ | (exception _) -> Yocaml_unix.run ~level:`Debug program

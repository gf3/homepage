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

let read_site () =
  Eff.read_file_as_metadata
    (module Yocaml_yaml)
    (module Homepage.Site)
    ~on:`Source
    Path.(content / "site.yml")

let inject_site site fields = ("site", Homepage.Site.to_data site) :: fields

module Fields : Required.DATA_INJECTABLE with type t = (string * Data.t) list = struct
  type t = (string * Data.t) list

  let normalize fields = fields
end

let copy_favicon = Action.copy_file ~into:www Path.(assets / "favicon.ico")

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

let create_document ~site document_kind source =
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
    let fields = inject_site site (Archetype.normalize metadata) in
    content
    |> Yocaml_markdown.from_string_to_html
    |> templates
         (module Fields : Required.DATA_INJECTABLE with type t = (string * Data.t) list)
         ~metadata:fields
  in
  Action.Static.write_file target pipeline

let create_documents ~site document_kind =
  let where = is_md in
  let sources = document_sources document_kind in
  Batch.iter_files ~where sources (create_document ~site document_kind)

let create_pages ~site = create_documents ~site Page
let create_articles ~site = create_documents ~site Article

let fetch_articles =
  Archetype.Articles.fetch ~where:is_md ~compute_link (module Yocaml_yaml) articles

let create_index ~site =
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
    let fields = inject_site site (Archetype.Articles.normalize metadata) in
    content
    |> Yocaml_markdown.from_string_to_html
    |> templates
         (module Fields : Required.DATA_INJECTABLE with type t = (string * Data.t) list)
         ~metadata:fields
  in
  Action.Static.write_file index_path pipeline

module Feed = struct
  let path = "atom.xml"

  let article_to_entry ~site (url, article) =
    let open Yocaml.Archetype in
    let open Yocaml_syndication in
    let site_url = Homepage.Site.url site in
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

  let make ~site entries =
    let open Yocaml_syndication in
    let author = Homepage.Site.author site in
    let email = Homepage.Site.email site in
    let site_url = Homepage.Site.url site in
    Atom.feed
      ~title:(Atom.text (Homepage.Site.name site))
      ~subtitle:(Atom.text (Homepage.Site.description site))
      ~updated:(Atom.updated_from_entries ())
      ~authors:((Yocaml_syndication.Person.make ~uri:site_url ~email author) |> Nel.singleton)
      ~id:site_url
      (article_to_entry ~site)
      entries
end

let create_feed ~site =
  let feed_path = Path.(www / Feed.path)
  and pipeline =
    let open Task in
    let+ () = track_binary
    and+ articles = fetch_articles in
    articles |> Feed.make ~site |> Yocaml_syndication.Xml.to_string
  in
  Action.Static.write_file feed_path pipeline

let program () =
  let open Eff in
  let* site = read_site () in
  let cache = Path.(www / ".cache") in
  Action.restore_cache cache
  >>= copy_favicon
  >>= copy_images
  >>= copy_fonts
  >>= create_css
  >>= create_pages ~site
  >>= create_articles ~site
  >>= create_index ~site
  >>= create_feed ~site
  >>= Action.store_cache cache

let () =
  match Sys.argv.(1) with
  | "serve" -> Yocaml_unix.serve ~level:`Info ~target:www ~port:8000 program
  | _ | (exception _) -> Yocaml_unix.run ~level:`Debug program

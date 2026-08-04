(** A little thought. **)

open Yocaml

module Thweet = struct
  type t =
    { date : Datetime.t
    ; og_image : string
    }

  let entity_name = "Thweet"
  let neutral = Metadata.required entity_name

  let validate =
    let open Data.Validation in
    record (fun fields ->
      let+ date = required fields "date" Datetime.validate
      and+ og_image = optional_or ~default:"" fields "og_image" string in
      { date; og_image })

  let normalize { date; og_image } =
    Data.[ "date", Datetime.normalize date; "og_image", string og_image ]

  let to_data t = Data.record (normalize t)
  let date t = t.date
  let og_image t = t.og_image
end

let sort_by_date ?(increasing = false) thweets =
  List.sort
    (fun (a, _) (b, _) ->
       let r = Datetime.compare (Thweet.date a) (Thweet.date b) in
       if increasing then r else ~-r)
    thweets

let fetch
      (module P : Required.DATA_PROVIDER)
      ?increasing
      ?(filter = fun x -> x)
      ?(on = `Source)
      ~where
      path
  =
  let open Task in
  Pipeline.fetch
    ~only:`Files
    ~where
    ~on
    (fun file ->
       let open Eff in
       let+ metadata, content =
         Eff.read_file_with_metadata (module P) (module Thweet) ~on file
       in
       metadata, Yocaml_markdown.from_string_to_html content)
    path
  >>| fun thweets -> thweets |> sort_by_date ?increasing |> filter

let normalize thweets =
  Data.
    [ ( "thweets"
      , list_of
          (fun (thweet, body) ->
             record (("body", string body) :: Thweet.normalize thweet))
          thweets )
    ; "has_thweets", bool (thweets <> [])
    ]

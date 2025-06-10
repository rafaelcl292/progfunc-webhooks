open Types

let validate_token token =
  match token with
  | Some t when t = valid_token -> true
  | _ -> false

let parse_json_payload json_string =
  try
    let json = Yojson.Basic.from_string json_string in
    let open Yojson.Basic.Util in
    let event = json |> member "event" |> to_string_option |> Option.value ~default:"" in
    let transaction_id = json |> member "transaction_id" |> to_string_option |> Option.value ~default:"" in
    let amount = 
      try 
        let amount_json = json |> member "amount" in
        match amount_json with
        | `Float f -> f
        | `Int i -> float_of_int i
        | `String s -> float_of_string s
        | _ -> 0.0
      with _ -> 0.0 
    in
    let currency = json |> member "currency" |> to_string_option |> Option.value ~default:"" in
    let timestamp = json |> member "timestamp" |> to_string_option |> Option.value ~default:"" in
    Valid { event; transaction_id; amount; currency; timestamp }
  with
  | Yojson.Json_error _ -> Invalid "Invalid JSON format"
  | exn -> Invalid ("JSON parsing error: " ^ Printexc.to_string exn)

let validate_payload payload =
  match payload with
  | Valid p ->
    if p.event = "" then Invalid "Missing event field"
    else if p.transaction_id = "" then Invalid "Missing transaction_id field"
    else if p.amount <= 0.0 then Invalid "Invalid amount"
    else if p.currency = "" then Invalid "Missing currency field"
    else if p.timestamp = "" then Invalid "Missing timestamp field"
    else Valid p
  | Invalid reason -> Invalid reason

let check_required_fields payload =
  match payload with
  | Valid p ->
    let missing_fields = 
      (if p.event = "" then ["event"] else []) @
      (if p.transaction_id = "" then ["transaction_id"] else []) @
      (if p.currency = "" then ["currency"] else []) @
      (if p.timestamp = "" then ["timestamp"] else [])
    in
    if missing_fields <> [] then 
      Invalid ("Missing required fields: " ^ String.concat ", " missing_fields)
    else Valid p
  | Invalid reason -> Invalid reason 
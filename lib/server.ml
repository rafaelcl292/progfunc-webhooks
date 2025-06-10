
open Types
open Validation
open Http_client
open Transaction_store
open Lwt.Infix

let extract_transaction_id_from_payload body =
  try
    let json = Yojson.Basic.from_string body in
    let open Yojson.Basic.Util in
    json |> member "transaction_id" |> to_string_option |> Option.value ~default:""
  with _ -> ""

let process_transaction payload token body =
  if not (validate_token token) then
    (Printf.printf "🚫 Invalid token received\n"; Ignore)
  else
    match payload with
    | Valid p ->
        if p.transaction_id = "" then
          (Printf.printf "❌ Missing transaction_id\n"; Ignore)
        else if is_duplicate p.transaction_id then
          (Printf.printf "🔄 Duplicate transaction: %s\n" p.transaction_id; Ignore)
        else if p.amount <= 0.0 then
          (Printf.printf "💰 Invalid amount for transaction: %s\n" p.transaction_id; Cancel p.transaction_id)
        else if p.event = "" || p.currency = "" || p.timestamp = "" then
          (Printf.printf "❌ Missing required fields for transaction: %s\n" p.transaction_id; Cancel p.transaction_id)
        else
          (add_transaction p.transaction_id;
           Printf.printf "✅ Processing valid transaction: %s\n" p.transaction_id;
           Confirm p.transaction_id)
    | Invalid reason ->
        Printf.printf "❌ Invalid payload: %s\n" reason;
        let transaction_id = extract_transaction_id_from_payload body in
        if transaction_id <> "" then Cancel transaction_id else Ignore

let handle_webhook_request body token =
  let payload = parse_json_payload body in
  let action = process_transaction payload token body in
  match action with
  | Confirm transaction_id ->
      confirm_transaction transaction_id >>= fun () ->
      Lwt.return (`OK, "Transaction confirmed")
  | Cancel transaction_id ->
      cancel_transaction transaction_id >>= fun () ->
      Lwt.return (`Bad_request, "Transaction cancelled")
  | Ignore ->
      Lwt.return (`Bad_request, "Request ignored")

let webhook_handler req _body =
  let uri = Cohttp.Request.uri req in
  let meth = Cohttp.Request.meth req in
  match (meth, Uri.path uri) with
  | (`POST, "/webhook") ->
      Cohttp_lwt.Body.to_string _body >>= fun body_string ->
      let token = Cohttp.Header.get (Cohttp.Request.headers req) "x-webhook-token" in
      handle_webhook_request body_string token >>= fun (status, message) ->
      let headers = Cohttp.Header.init_with "content-type" "application/json" in
      let response_body = `Assoc [("status", `String message)] |> Yojson.Basic.to_string in
      Cohttp_lwt_unix.Server.respond_string ~status ~headers ~body:response_body ()
  | _ ->
      Cohttp_lwt_unix.Server.respond_string ~status:`Not_found ~body:"Endpoint not found" ()

let start_server port =
  let callback _conn req body = webhook_handler req body in
  Printf.printf "🚀 Webhook server starting on port %d\n" port;
  Printf.printf "📡 Listening for webhooks at http://localhost:%d/webhook\n" port;
  Cohttp_lwt_unix.Server.create ~mode:(`TCP (`Port port)) (Cohttp_lwt_unix.Server.make ~callback ()) 
open Lwt.Infix
let confirm_url = "http://127.0.0.1:5001/confirmar"
let cancel_url = "http://127.0.0.1:5001/cancelar"

let make_json_body transaction_id =
  `Assoc [("transaction_id", `String transaction_id)]
  |> Yojson.Basic.to_string

let make_http_call url body =
  let headers = Cohttp.Header.init_with "content-type" "application/json" in
  Cohttp_lwt_unix.Client.post ~headers ~body:(`String body) (Uri.of_string url)
  >>= fun (resp, body_response) ->
  Cohttp_lwt.Body.drain_body body_response >>= fun _ ->
  let status_code = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in
  Lwt.return status_code

let confirm_transaction transaction_id =
  let body = make_json_body transaction_id in
  make_http_call confirm_url body >>= fun status ->
  Printf.printf "✅ Confirmation sent for transaction %s (status: %d)\n" transaction_id status;
  Lwt.return_unit

let cancel_transaction transaction_id =
  let body = make_json_body transaction_id in
  make_http_call cancel_url body >>= fun status ->
  Printf.printf "❌ Cancellation sent for transaction %s (status: %d)\n" transaction_id status;
  Lwt.return_unit 
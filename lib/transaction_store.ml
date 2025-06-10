let processed_transactions : string list ref = ref []

let is_duplicate transaction_id =
  List.mem transaction_id !processed_transactions

let add_transaction transaction_id =
  processed_transactions := transaction_id :: !processed_transactions 
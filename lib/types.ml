type webhook_payload = {
  event: string;
  transaction_id: string;
  amount: float;
  currency: string;
  timestamp: string;
}

type validation_result = 
  | Valid of webhook_payload
  | Invalid of string

type transaction_action =
  | Confirm of string
  | Cancel of string
  | Ignore

let valid_token = "meu-token-secreto" 
import asyncio
import json
import sys
from threading import Thread
from typing import Any

import requests
import uvicorn
from fastapi import FastAPI, Request

app = FastAPI()

# Variáveis para armazenar confirmações e cancelamentos
confirmations: list[str] = []
cancellations: list[str] = []


# Endpoint para receber confirmação de transações
@app.post("/confirmar")
async def confirmar(req: Request) -> dict[str, str]:
    body: dict[str, Any] = await req.json()
    print("✅ Confirmação recebida:", body)
    confirmations.append(body["transaction_id"])  # Registra a transação confirmada
    return {"status": "ok"}


# Endpoint para receber cancelamento de transações
@app.post("/cancelar")
async def cancelar(req: Request) -> dict[str, str]:
    body: dict[str, Any] = await req.json()
    print("❌ Cancelamento recebido:", body)
    cancellations.append(body["transaction_id"])  # Registra a transação cancelada
    return {"status": "ok"}


# Função para rodar o servidor FastAPI numa thread separada
def run_server() -> None:
    uvicorn.run(app, host="127.0.0.1", port=5001, log_level="error")


# Carrega argumentos de linha de comando ou usa valores padrão
async def load_args() -> tuple[str, dict[str, str], dict[str, str]]:
    event: str = sys.argv[1] if len(sys.argv) > 1 else "payment_success"
    transaction_id: str = sys.argv[2] if len(sys.argv) > 2 else "abc123"
    amount: str = sys.argv[3] if len(sys.argv) > 3 else "49.90"
    currency: str = sys.argv[4] if len(sys.argv) > 4 else "BRL"
    timestamp: str = sys.argv[5] if len(sys.argv) > 5 else "2023-10-01T12:00:00Z"
    token: str = sys.argv[6] if len(sys.argv) > 6 else "meu-token-secreto"

    url: str = "http://localhost:5000/webhook"  # URL do webhook a ser testado

    headers: dict[str, str] = {
        "Content-Type": "application/json",
        "X-Webhook-Token": token,  # Token de segurança
    }

    data: dict[str, str] = {
        "event": event,
        "transaction_id": transaction_id,
        "amount": amount,
        "currency": currency,
        "timestamp": timestamp,
    }

    return url, headers, data


# Função principal que executa os testes contra o webhook
async def test_webhook(url: str, headers: dict[str, str], data: dict[str, str]) -> int:
    from requests.exceptions import ConnectionError

    i: int = 0  # Contador de testes bem-sucedidos

    def safe_post(url, *args, **kwargs):
        try:
            return requests.post(url, *args, **kwargs)
        except ConnectionError:
            print("❗ Não foi possível conectar ao servidor do webhook em", url)
            return None

    # Teste 1: fluxo correto
    response = safe_post(url, headers=headers, data=json.dumps(data))
    if response is None:
        return i
    await asyncio.sleep(1)  # Aguarda o webhook chamar /confirmar
    if response.status_code == 200 and data["transaction_id"] in confirmations:
        i += 1
        print("1. Webhook test ok: successful!")
    else:
        print("1. Webhook test failed: successful!")

    # Teste 2: transação duplicada (deve falhar se o webhook previne duplicações)
    response = safe_post(url, headers=headers, data=json.dumps(data))
    if response is None:
        return i
    if response.status_code != 200:
        i += 1
        print("2. Webhook test ok: transação duplicada!")
    else:
        print("2. Webhook test failed: transação duplicada!")

    # Teste 3: amount incorreto e transaction_id alterado
    data["transaction_id"] += "a"  # Altera ID para evitar conflito
    data["amount"] = "0.00"
    response = safe_post(url, headers=headers, data=json.dumps(data))
    if response is None:
        return i
    await asyncio.sleep(1)
    if response.status_code != 200 and data["transaction_id"] in cancellations:
        i += 1
        print("3. Webhook test ok: amount incorreto!")
    else:
        print("3. Webhook test failed: amount incorreto!")

    # Teste 4: token inválido
    token: str = headers["X-Webhook-Token"]
    headers["X-Webhook-Token"] = "invalid-token"
    data["transaction_id"] += "b"
    response = safe_post(url, headers=headers, data=json.dumps(data))
    if response is None:
        return i
    if response.status_code != 200:
        i += 1
        print("4. Webhook test ok: Token Invalido!")
    else:
        print("4. Webhook test failed: Token Invalido!")

    # Teste 5: payload vazio
    response = safe_post(url, headers=headers, data=json.dumps({}))
    if response is None:
        return i
    if response.status_code != 200:
        i += 1
        print("5. Webhook test ok: Payload Invalido!")
    else:
        print("5. Webhook test failed: Payload Invalido!")

    # Teste 6: campos ausentes (sem timestamp)
    del data["timestamp"]
    headers["X-Webhook-Token"] = token  # Restaura token correto
    data["transaction_id"] += "c"
    response = safe_post(url, headers=headers, data=json.dumps(data))
    if response is None:
        return i
    await asyncio.sleep(1)
    if response.status_code != 200 and data["transaction_id"] in cancellations:
        i += 1
        print("6. Webhook test ok: Campos ausentes!")
    else:
        print("6. Webhook test failed: Campos ausentes!")

    return i


if __name__ == "__main__":
    # Roda o servidor local de /confirmar e /cancelar em background
    server_thread: Thread = Thread(target=run_server, daemon=True)
    server_thread.start()

    # Aguarda o servidor estar pronto
    asyncio.run(asyncio.sleep(1))

    # Carrega argumentos e executa os testes
    url, headers, data = asyncio.run(load_args())
    total: int = asyncio.run(test_webhook(url, headers, data))

    # Exibe resultado final
    print(f"{total}/6 tests completed.")
    print("Confirmações recebidas:", confirmations)
    print("Cancelamentos recebidos:", cancellations)

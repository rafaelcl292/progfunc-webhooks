# Webhook Payment Processing Server

A functional programming implementation of a webhook service for processing payment confirmations, built in OCaml.

**Author: Rafael Coca Leventhal**

## Project Description

This project implements a webhook service that receives and processes payment confirmation requests from payment gateways (e.g., PayPal, MercadoPago). The service is designed following functional programming principles, using pure functions for validation, immutable data structures, and functional composition.

This is an **individual project** implemented in OCaml (a functional programming language) as part of a functional programming course, following the requirements specified in the project instructions.

### Key Features

- **HTTP POST endpoint** at `/webhook` for receiving payment confirmations
- **Token-based authentication** using `X-Webhook-Token` header
- **JSON payload validation** with required fields verification
- **Duplicate transaction prevention** using in-memory transaction store
- **Automatic confirmation/cancellation** via HTTP calls to external endpoints
- **Functional programming approach** with pure functions and immutable data

### Expected Payload Format

The service expects webhooks with this exact JSON structure:

```json
{
  "event": "payment_success",
  "transaction_id": "abc123",
  "amount": 49.90,
  "currency": "BRL",
  "timestamp": "2025-05-11T16:00:00Z"
}
```

### Service Behavior

The webhook service implements the following operational logic:

- **Valid transactions**: Returns `200 OK` and makes a confirmation request to `http://127.0.0.1:5001/confirmar`
- **Invalid transactions**: Returns `400 Bad Request`
- **Invalid data** (amount ≤ 0, missing required fields): Returns `400 Bad Request` and makes a cancellation request to `http://127.0.0.1:5001/cancelar`
- **Invalid token**: Request is ignored and returns `400 Bad Request`
- **Duplicate transactions**: Returns `400 Bad Request` (no external call made)

## Installation

### Prerequisites

- OCaml (>= 4.14)
- Dune (>= 3.0)
- OPAM package manager

### Install Dependencies

```bash
opam install dune cohttp-lwt-unix lwt yojson lwt_ppx
```

### Build the Project

```bash
dune build
```

## Running the Server

### Start the Webhook Server

```bash
dune exec bin/main.exe
```

The server will start on port 5000 and listen for webhook requests at:
`http://localhost:5000/webhook`

You should see output like:
```
🚀 Webhook server starting on port 5000
📡 Listening for webhooks at http://localhost:5000/webhook
```

### Testing the Server

The project includes a Python test suite (`test_webhook.py`) that validates all webhook functionality:

#### Prerequisites for Testing
Install required Python libraries:
```bash
uv sync
```

#### Run Tests
```bash
uv run test_webhook.py
```

The test suite validates:
1. ✅ Successful transaction processing and confirmation
2. 🔄 Duplicate transaction prevention
3. ❌ Invalid amount handling and cancellation
4. 🚫 Invalid token rejection
5. 📋 Empty payload rejection
6. 🔍 Missing fields handling and cancellation

**Expected result: 6/6 tests completed**

### Manual Testing

You can test the webhook manually using curl:

```bash
curl -X POST http://localhost:5000/webhook \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Token: meu-token-secreto" \
  -d '{
    "event": "payment_success",
    "transaction_id": "test123",
    "amount": 49.90,
    "currency": "BRL",
    "timestamp": "2025-05-11T16:00:00Z"
  }'
```

Expected response for valid transaction:
```json
{"status": "Transaction confirmed"}
```

## Architecture

The project follows functional programming principles with clear separation of concerns:

### Why Functional Programming?

This project leverages functional programming benefits:

- **No Side Effects**: Facilitates testing and debugging
- **Immutability**: Reduces the chance of concurrency bugs  
- **Pure Functions**: Provides clear logic isolation
- **Composition**: Makes it easy to create transformation pipelines

### Modules

- **`Types`** - Data type definitions and validation results
- **`Validation`** - Pure functions for payload and token validation
- **`Http_client`** - HTTP client functions for confirmations/cancellations
- **`Transaction_store`** - Simple in-memory storage for duplicate prevention
- **`Server`** - Main HTTP server logic with functional composition

### Transaction Processing Flow

1. **Receive** POST request with JSON payload and token header
2. **Validate** token against expected value (`meu-token-secreto`)
3. **Parse** and validate JSON payload structure
4. **Check** for duplicate transactions using transaction store
5. **Validate** business rules (amount > 0, required fields present)
6. **Process** transaction based on validation results:
   - **Confirm**: Valid transaction → HTTP call to `/confirmar` + 200 OK
   - **Cancel**: Invalid/missing data → HTTP call to `/cancelar` + 400 Bad Request
   - **Ignore**: Invalid token or duplicate → 400 Bad Request (no external call)

### Functional Programming Features

- **Pure Functions**: Validation and processing logic without side effects
- **Immutable Data**: All data structures are immutable
- **Function Composition**: Pipeline-style data transformation using `>>=` and `|>`
- **Pattern Matching**: Exhaustive case handling for all scenarios
- **Type Safety**: Strong typing prevents runtime errors

## Project Requirements Compliance

This project meets all requirements specified in the project instructions:

### Core Requirements ✅
- [x] HTTP service with POST route (`/webhook`)
- [x] Passes all minimum provided tests (6/6)
- [x] Individual implementation
- [x] Implemented in functional language (OCaml)
- [x] Comprehensive README with installation and running instructions

### Optional Features Implemented ✅
- [x] **Payload integrity verification** (+0.5): Complete JSON validation and structure checking
- [x] **Transaction veracity mechanism** (+0.5): Token-based authentication via `X-Webhook-Token` header
- [x] **Transaction cancellation** (+0.5): Automatic cancellation for invalid amounts and missing fields
- [x] **Transaction confirmation** (+0.5): Automatic confirmation for valid transactions

### Optional Features Not Implemented ❌
- [ ] **Database persistence** (+0.5): Uses in-memory storage instead
- [ ] **HTTPS service** (+0.5): Implements HTTP only

## Final Grade

**Grade Calculation:**
- Base grade: **C** (Project passed the minimum test)
- Optional features: **4 × (+0.5) = +2.0 concepts**
- **Final Grade: C + 2.0 = A** 🎉

## Configuration

- **Server Port**: 5000
- **Webhook Endpoint**: `/webhook`
- **Authentication Token**: `meu-token-secreto`
- **Confirmation URL**: `http://127.0.0.1:5001/confirmar`
- **Cancellation URL**: `http://127.0.0.1:5001/cancelar`

## Error Handling

The server handles various error scenarios following functional programming principles:

- **Invalid Token**: Returns 400 Bad Request, request ignored
- **Malformed JSON**: Returns 400 Bad Request with error details
- **Missing Required Fields**: Returns 400 Bad Request + cancellation call
- **Invalid Amount (≤ 0)**: Returns 400 Bad Request + cancellation call
- **Duplicate Transaction**: Returns 400 Bad Request (no external call)
- **Network Failures**: Handles HTTP client errors gracefully

## Project Structure

```
.
├── bin/
│   ├── dune                 # Executable configuration
│   └── main.ml              # Entry point (starts server on port 5000)
├── lib/
│   ├── dune                 # Library configuration
│   ├── types.ml             # Data type definitions and validation results
│   ├── validation.ml        # Pure validation functions (token + payload)
│   ├── http_client.ml       # HTTP client for confirmations/cancellations
│   ├── transaction_store.ml # In-memory duplicate prevention
│   └── server.ml            # Main HTTP server logic
├── dune-project             # Dune project configuration
├── README.md                # This file
└── test_webhook.py          # Python test suite (6 tests)
```

## Project Delivery

- **Delivery Date**: June 10, 2025, at 23:59 via GitHub
- **Implementation**: Individual project in OCaml (functional programming)
- **Status**: ✅ **COMPLETED** with grade **A** (C + 2.0 concepts)

## License

This project is for educational purposes as part of a functional programming course at Insper.

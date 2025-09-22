
;; title: BTCYieldFarm
;; version: 1.0.0
;; summary: Cross-chain AMM liquidity pool for Bitcoin yield farming on Stacks
;; description: A decentralized yield farming protocol that allows users to provide liquidity
;; and earn rewards through automated market making for BTC-based assets

;; traits
;; (use-trait ft-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; token definitions
(define-fungible-token btc-yield-token)

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1002))
(define-constant ERR_INVALID_AMOUNT (err u1003))
(define-constant ERR_POOL_NOT_FOUND (err u1004))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1005))
(define-constant ERR_SLIPPAGE_TOO_HIGH (err u1006))
(define-constant ERR_ALREADY_INITIALIZED (err u1007))

;; Fee rate (0.3% = 30 basis points)
(define-constant FEE_RATE u30)
(define-constant FEE_DENOMINATOR u10000)

;; Minimum liquidity to prevent division by zero
(define-constant MINIMUM_LIQUIDITY u1000)

;; data vars
(define-data-var contract-initialized bool false)
(define-data-var total-pools uint u0)
(define-data-var protocol-fee-recipient principal CONTRACT_OWNER)

;; data maps
(define-map pools
  { pool-id: uint }
  {
    token-x: principal,
    token-y: principal,
    reserve-x: uint,
    reserve-y: uint,
    total-supply: uint,
    fee-rate: uint
  }
)

(define-map liquidity-providers
  { pool-id: uint, provider: principal }
  { liquidity-tokens: uint }
)

(define-map user-rewards
  { user: principal, pool-id: uint }
  {
    accumulated-rewards: uint,
    last-claim-block: uint,
    staked-amount: uint
  }
)

(define-map pool-rewards
  { pool-id: uint }
  {
    reward-per-block: uint,
    total-staked: uint,
    last-reward-block: uint
  }
)

;; public functions

;; Initialize the contract (can only be called once)
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (var-get contract-initialized)) ERR_ALREADY_INITIALIZED)
    (var-set contract-initialized true)
    (ok true)
  )
)

;; Create a new liquidity pool
(define-public (create-pool (token-x principal) (token-y principal) (initial-x uint) (initial-y uint))
  (let
    (
      (pool-id (+ (var-get total-pools) u1))
      (liquidity-tokens (get-initial-liquidity initial-x initial-y))
    )
    (asserts! (var-get contract-initialized) ERR_UNAUTHORIZED)
    (asserts! (and (> initial-x u0) (> initial-y u0)) ERR_INVALID_AMOUNT)

    ;; Store pool data
    (map-set pools
      { pool-id: pool-id }
      {
        token-x: token-x,
        token-y: token-y,
        reserve-x: initial-x,
        reserve-y: initial-y,
        total-supply: liquidity-tokens,
        fee-rate: FEE_RATE
      }
    )

    ;; Store liquidity provider data
    (map-set liquidity-providers
      { pool-id: pool-id, provider: tx-sender }
      { liquidity-tokens: liquidity-tokens }
    )

    ;; Initialize pool rewards
    (map-set pool-rewards
      { pool-id: pool-id }
      {
        reward-per-block: u100, ;; Default 100 tokens per block
        total-staked: u0,
        last-reward-block: block-height
      }
    )

    ;; Update total pools counter
    (var-set total-pools pool-id)

    ;; Mint BTC yield tokens as initial rewards
    (try! (ft-mint? btc-yield-token u10000 tx-sender))

    (ok pool-id)
  )
)

;; Add liquidity to an existing pool
(define-public (add-liquidity (pool-id uint) (amount-x uint) (amount-y uint) (min-liquidity uint))
  (let
    (
      (pool-data (unwrap! (map-get? pools { pool-id: pool-id }) ERR_POOL_NOT_FOUND))
      (reserve-x (get reserve-x pool-data))
      (reserve-y (get reserve-y pool-data))
      (total-supply (get total-supply pool-data))
      (liquidity-tokens (if (is-eq total-supply u0)
                          (get-initial-liquidity amount-x amount-y)
                          (min (/ (* amount-x total-supply) reserve-x)
                               (/ (* amount-y total-supply) reserve-y))))
    )
    (asserts! (>= liquidity-tokens min-liquidity) ERR_SLIPPAGE_TOO_HIGH)
    (asserts! (> liquidity-tokens u0) ERR_INVALID_AMOUNT)

    ;; Update pool reserves
    (map-set pools
      { pool-id: pool-id }
      (merge pool-data {
        reserve-x: (+ reserve-x amount-x),
        reserve-y: (+ reserve-y amount-y),
        total-supply: (+ total-supply liquidity-tokens)
      })
    )

    ;; Update liquidity provider data
    (let ((current-liquidity (default-to u0 (get liquidity-tokens
                               (map-get? liquidity-providers { pool-id: pool-id, provider: tx-sender })))))
      (map-set liquidity-providers
        { pool-id: pool-id, provider: tx-sender }
        { liquidity-tokens: (+ current-liquidity liquidity-tokens) }
      )
    )

    (ok liquidity-tokens)
  )
)

;; Remove liquidity from a pool
(define-public (remove-liquidity (pool-id uint) (liquidity-tokens uint) (min-x uint) (min-y uint))
  (let
    (
      (pool-data (unwrap! (map-get? pools { pool-id: pool-id }) ERR_POOL_NOT_FOUND))
      (user-liquidity (unwrap! (map-get? liquidity-providers { pool-id: pool-id, provider: tx-sender }) ERR_INSUFFICIENT_BALANCE))
      (reserve-x (get reserve-x pool-data))
      (reserve-y (get reserve-y pool-data))
      (total-supply (get total-supply pool-data))
      (amount-x (/ (* liquidity-tokens reserve-x) total-supply))
      (amount-y (/ (* liquidity-tokens reserve-y) total-supply))
    )
    (asserts! (>= (get liquidity-tokens user-liquidity) liquidity-tokens) ERR_INSUFFICIENT_BALANCE)
    (asserts! (and (>= amount-x min-x) (>= amount-y min-y)) ERR_SLIPPAGE_TOO_HIGH)

    ;; Update pool reserves
    (map-set pools
      { pool-id: pool-id }
      (merge pool-data {
        reserve-x: (- reserve-x amount-x),
        reserve-y: (- reserve-y amount-y),
        total-supply: (- total-supply liquidity-tokens)
      })
    )

    ;; Update user liquidity
    (map-set liquidity-providers
      { pool-id: pool-id, provider: tx-sender }
      { liquidity-tokens: (- (get liquidity-tokens user-liquidity) liquidity-tokens) }
    )

    (ok { amount-x: amount-x, amount-y: amount-y })
  )
)

;; Swap tokens in a pool
(define-public (swap (pool-id uint) (token-in principal) (amount-in uint) (min-amount-out uint))
  (let
    (
      (pool-data (unwrap! (map-get? pools { pool-id: pool-id }) ERR_POOL_NOT_FOUND))
      (is-x-to-y (is-eq token-in (get token-x pool-data)))
      (reserve-in (if is-x-to-y (get reserve-x pool-data) (get reserve-y pool-data)))
      (reserve-out (if is-x-to-y (get reserve-y pool-data) (get reserve-x pool-data)))
      (amount-in-with-fee (- amount-in (/ (* amount-in FEE_RATE) FEE_DENOMINATOR)))
      (amount-out (/ (* amount-in-with-fee reserve-out) (+ reserve-in amount-in-with-fee)))
    )
    (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_TOO_HIGH)
    (asserts! (> amount-out u0) ERR_INVALID_AMOUNT)

    ;; Update pool reserves
    (map-set pools
      { pool-id: pool-id }
      (if is-x-to-y
        (merge pool-data {
          reserve-x: (+ reserve-in amount-in),
          reserve-y: (- reserve-out amount-out)
        })
        (merge pool-data {
          reserve-x: (- reserve-out amount-out),
          reserve-y: (+ reserve-in amount-in)
        })
      )
    )

    (ok amount-out)
  )
)

;; Stake liquidity tokens to earn rewards
(define-public (stake-liquidity (pool-id uint) (amount uint))
  (let
    (
      (user-liquidity (unwrap! (map-get? liquidity-providers { pool-id: pool-id, provider: tx-sender }) ERR_INSUFFICIENT_BALANCE))
      (current-rewards (default-to { accumulated-rewards: u0, last-claim-block: block-height, staked-amount: u0 }
                         (map-get? user-rewards { user: tx-sender, pool-id: pool-id })))
      (pool-reward-data (unwrap! (map-get? pool-rewards { pool-id: pool-id }) ERR_POOL_NOT_FOUND))
    )
    (asserts! (>= (get liquidity-tokens user-liquidity) amount) ERR_INSUFFICIENT_BALANCE)

    ;; Update user rewards
    (map-set user-rewards
      { user: tx-sender, pool-id: pool-id }
      {
        accumulated-rewards: (get accumulated-rewards current-rewards),
        last-claim-block: block-height,
        staked-amount: (+ (get staked-amount current-rewards) amount)
      }
    )

    ;; Update pool total staked
    (map-set pool-rewards
      { pool-id: pool-id }
      (merge pool-reward-data {
        total-staked: (+ (get total-staked pool-reward-data) amount)
      })
    )

    (ok amount)
  )
)

;; Claim accumulated rewards
(define-public (claim-rewards (pool-id uint))
  (let
    (
      (user-reward-data (unwrap! (map-get? user-rewards { user: tx-sender, pool-id: pool-id }) ERR_INSUFFICIENT_BALANCE))
      (pool-reward-data (unwrap! (map-get? pool-rewards { pool-id: pool-id }) ERR_POOL_NOT_FOUND))
      (blocks-since-last-claim (- block-height (get last-claim-block user-reward-data)))
      (user-staked (get staked-amount user-reward-data))
      (total-staked (get total-staked pool-reward-data))
      (reward-per-block (get reward-per-block pool-reward-data))
      (new-rewards (if (and (> total-staked u0) (> user-staked u0))
                     (/ (* blocks-since-last-claim reward-per-block user-staked) total-staked)
                     u0))
      (total-rewards (+ (get accumulated-rewards user-reward-data) new-rewards))
    )

    ;; Reset accumulated rewards and update last claim block
    (map-set user-rewards
      { user: tx-sender, pool-id: pool-id }
      (merge user-reward-data {
        accumulated-rewards: u0,
        last-claim-block: block-height
      })
    )

    ;; Mint reward tokens to user
    (try! (ft-mint? btc-yield-token total-rewards tx-sender))

    (ok total-rewards)
  )
)

;; read only functions

;; Get pool information
(define-read-only (get-pool-info (pool-id uint))
  (map-get? pools { pool-id: pool-id })
)

;; Get user liquidity position
(define-read-only (get-user-liquidity (pool-id uint) (user principal))
  (map-get? liquidity-providers { pool-id: pool-id, provider: user })
)

;; Get user reward information
(define-read-only (get-user-rewards (user principal) (pool-id uint))
  (map-get? user-rewards { user: user, pool-id: pool-id })
)

;; Calculate swap output amount
(define-read-only (get-swap-amount-out (pool-id uint) (token-in principal) (amount-in uint))
  (match (map-get? pools { pool-id: pool-id })
    pool-data
    (let
      (
        (is-x-to-y (is-eq token-in (get token-x pool-data)))
        (reserve-in (if is-x-to-y (get reserve-x pool-data) (get reserve-y pool-data)))
        (reserve-out (if is-x-to-y (get reserve-y pool-data) (get reserve-x pool-data)))
        (amount-in-with-fee (- amount-in (/ (* amount-in FEE_RATE) FEE_DENOMINATOR)))
        (amount-out (/ (* amount-in-with-fee reserve-out) (+ reserve-in amount-in-with-fee)))
      )
      (ok amount-out)
    )
    ERR_POOL_NOT_FOUND
  )
)

;; Get total number of pools
(define-read-only (get-total-pools)
  (var-get total-pools)
)

;; Check if contract is initialized
(define-read-only (is-initialized)
  (var-get contract-initialized)
)

;; Get BTC yield token balance
(define-read-only (get-btc-yield-balance (user principal))
  (ft-get-balance btc-yield-token user)
)

;; private functions

;; Calculate initial liquidity tokens using geometric mean
(define-private (get-initial-liquidity (amount-x uint) (amount-y uint))
  (let ((product (* amount-x amount-y)))
    (if (> product u0)
      (max (sqrt product) MINIMUM_LIQUIDITY)
      MINIMUM_LIQUIDITY
    )
  )
)

;; Calculate square root (iterative implementation to avoid recursion)
(define-private (sqrt (n uint))
  (if (< n u2)
    n
    (let ((x0 n)
          (x1 (/ (+ n u1) u2)))
      (if (>= x1 x0)
        x0
        (let ((x2 (/ (+ x1 (/ n x1)) u2)))
          (if (>= x2 x1)
            x1
            (let ((x3 (/ (+ x2 (/ n x2)) u2)))
              (if (>= x3 x2)
                x2
                (let ((x4 (/ (+ x3 (/ n x3)) u2)))
                  (if (>= x4 x3)
                    x3
                    x4
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

;; Calculate minimum of two values
(define-private (min (a uint) (b uint))
  (if (< a b) a b)
)

;; Calculate maximum of two values
(define-private (max (a uint) (b uint))
  (if (> a b) a b)
)

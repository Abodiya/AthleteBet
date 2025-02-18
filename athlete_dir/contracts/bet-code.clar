;; Athlete Performance Betting Smart Contract

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INSUFFICIENT-BET-BALANCE (err u101))
(define-constant ERR-INVALID-BET-AMOUNT (err u102))
(define-constant ERR-STATS-FEED-EXPIRED (err u103))
(define-constant ERR-INSUFFICIENT-STAKE-DEPOSIT (err u104))
(define-constant ERR-BELOW-MINIMUM-STAKE-THRESHOLD (err u105))
(define-constant ERR-INVALID-PERFORMANCE-METRIC (err u106))
(define-constant ERR-ARITHMETIC-OVERFLOW (err u107))
(define-constant ERR-INVALID-BETTOR (err u108))
(define-constant ERR-ZERO-AMOUNT (err u109))
(define-constant ERR-NO-POSITION-EXISTS (err u110))

;; Constants
(define-constant CONTRACT-ADMINISTRATOR tx-sender)
(define-constant STATS-FEED-EXPIRY-BLOCKS u600) ;; 10 minutes in blocks
(define-constant REQUIRED-STAKE-RATIO u150) ;; 150%
(define-constant MARGIN-CALL-THRESHOLD u120) ;; 120%
(define-constant MINIMUM-PERFORMANCE-BET u100000000) ;; 1.00 tokens (8 decimals)
(define-constant MAXIMUM-PERFORMANCE-VALUE u1000000000000) ;; Set reasonable maximum value
(define-constant MAXIMUM-UINT-VALUE u340282366920938463463374607431768211455) ;; 2^128 - 1

;; Data variables
(define-data-var stats-feed-last-update uint u0)
(define-data-var current-performance-metric uint u0)
(define-data-var total-active-bets-supply uint u0)

;; Data maps
(define-map performance-bet-balances principal uint)
(define-map bettor-positions
    principal
    {
        stake-amount-locked: uint,
        performance-bets-placed: uint,
        entry-performance-value: uint
    }
)

;; Safe math functions
(define-private (safe-multiply-numbers (first-number uint) (second-number uint))
    (let ((multiplication-result (* first-number second-number)))
        (asserts! (or (is-eq first-number u0) (is-eq (/ multiplication-result first-number) second-number)) ERR-ARITHMETIC-OVERFLOW)
        (ok multiplication-result)))

(define-private (safe-add-numbers (first-number uint) (second-number uint))
    (let ((addition-result (+ first-number second-number)))
        (asserts! (>= addition-result first-number) ERR-ARITHMETIC-OVERFLOW)
        (ok addition-result)))

(define-private (safe-subtract-numbers (minuend uint) (subtrahend uint))
    (begin
        (asserts! (>= minuend subtrahend) ERR-ARITHMETIC-OVERFLOW)
        (ok (- minuend subtrahend))))

;; Read-only functions
(define-read-only (get-bettor-balance (bettor principal))
    (default-to u0 (map-get? performance-bet-balances bettor))
)

(define-read-only (get-total-active-bets)
    (var-get total-active-bets-supply)
)

(define-read-only (get-current-performance-metric)
    (var-get current-performance-metric)
)

(define-read-only (get-position-details (bettor principal))
    (map-get? bettor-positions bettor)
)

(define-read-only (calculate-position-stake-ratio (position-owner principal))
    (let (
        (position-details (unwrap! (get-position-details position-owner) (err u0)))
        (current-metric (var-get current-performance-metric))
    )
    (if (> (get performance-bets-placed position-details) u0)
        (match (safe-multiply-numbers (get stake-amount-locked position-details) u100)
            success1 (match (safe-multiply-numbers success1 u100)
                success2 (match (safe-multiply-numbers (get performance-bets-placed position-details) current-metric)
                    denominator (ok (/ success2 denominator))
                    error ERR-ARITHMETIC-OVERFLOW)
                error ERR-ARITHMETIC-OVERFLOW)
            error ERR-ARITHMETIC-OVERFLOW)
        (err u0)))
)

;; Private functions
(define-private (execute-bet-transfer (sender principal) (recipient principal) (transfer-quantity uint))
    (let (
        (sender-current-balance (get-bettor-balance sender))
    )
    (asserts! (> transfer-quantity u0) ERR-ZERO-AMOUNT)
    (asserts! (not (is-eq sender recipient)) ERR-INVALID-BETTOR)
    (asserts! (>= sender-current-balance transfer-quantity) ERR-INSUFFICIENT-BET-BALANCE)
    (asserts! (is-some (map-get? performance-bet-balances sender)) ERR-UNAUTHORIZED-ACCESS)
    
    (match (safe-add-numbers (get-bettor-balance recipient) transfer-quantity)
        recipient-updated-balance
            (match (safe-subtract-numbers sender-current-balance transfer-quantity)
                sender-updated-balance
                    (begin
                        (map-set performance-bet-balances sender sender-updated-balance)
                        (map-set performance-bet-balances recipient recipient-updated-balance)
                        (ok true))
                error ERR-ARITHMETIC-OVERFLOW)
        error ERR-ARITHMETIC-OVERFLOW))
)

;; Public functions
(define-public (update-performance-metric (new-metric uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-ADMINISTRATOR) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (> new-metric u0) ERR-INVALID-PERFORMANCE-METRIC)
        (asserts! (< new-metric MAXIMUM-PERFORMANCE-VALUE) ERR-INVALID-PERFORMANCE-METRIC)
        (var-set current-performance-metric new-metric)
        (var-set stats-feed-last-update block-height)
        (ok true))
)

(define-public (place-performance-bet (bet-amount uint))
    (let (
        (current-metric (var-get current-performance-metric))
    )
    (asserts! (> bet-amount u0) ERR-ZERO-AMOUNT)
    (asserts! (>= bet-amount MINIMUM-PERFORMANCE-BET) ERR-INVALID-BET-AMOUNT)
    (asserts! (<= (- block-height (var-get stats-feed-last-update)) 
                 STATS-FEED-EXPIRY-BLOCKS) 
              ERR-STATS-FEED-EXPIRED)
    
    (match (safe-multiply-numbers bet-amount (/ current-metric u100))
        required-base-stake 
        (match (safe-multiply-numbers required-base-stake (/ REQUIRED-STAKE-RATIO u100))
            minimum-stake-required
            (match (stx-transfer? minimum-stake-required tx-sender (as-contract tx-sender))
                success
                (begin
                    (map-set bettor-positions tx-sender
                        {
                            stake-amount-locked: minimum-stake-required,
                            performance-bets-placed: bet-amount,
                            entry-performance-value: current-metric
                        })
                    (match (safe-add-numbers (get-bettor-balance tx-sender) bet-amount)
                        updated-balance
                        (begin
                            (map-set performance-bet-balances tx-sender updated-balance)
                            (match (safe-add-numbers (var-get total-active-bets-supply) bet-amount)
                                updated-supply
                                (begin
                                    (var-set total-active-bets-supply updated-supply)
                                    (ok true))
                                error ERR-ARITHMETIC-OVERFLOW))
                        error ERR-ARITHMETIC-OVERFLOW))
                error ERR-INSUFFICIENT-STAKE-DEPOSIT)
            error ERR-ARITHMETIC-OVERFLOW)
        error ERR-ARITHMETIC-OVERFLOW))
)

(define-public (close-performance-bet (bet-amount uint))
    (let (
        (position-details (unwrap! (get-position-details tx-sender) 
                               ERR-NO-POSITION-EXISTS))
        (bettor-balance (get-bettor-balance tx-sender))
    )
    (asserts! (> bet-amount u0) ERR-ZERO-AMOUNT)
    (asserts! (>= bettor-balance bet-amount) ERR-INSUFFICIENT-BET-BALANCE)
    (asserts! (>= (get performance-bets-placed position-details) bet-amount) 
              ERR-UNAUTHORIZED-ACCESS)
    
    (match (safe-multiply-numbers (get stake-amount-locked position-details) bet-amount)
        stake-calculation
        (let (
            (stake-return-amount (/ stake-calculation 
                                  (get performance-bets-placed position-details)))
        )
        
        (try! (as-contract (stx-transfer? stake-return-amount
                                         (as-contract tx-sender)
                                         tx-sender)))
        
        (match (safe-subtract-numbers (get stake-amount-locked position-details) 
                            stake-return-amount)
            updated-stake-amount
            (match (safe-subtract-numbers (get performance-bets-placed position-details) 
                                bet-amount)
                updated-bet-amount
                (begin
                    (map-set bettor-positions tx-sender
                        {
                            stake-amount-locked: updated-stake-amount,
                            performance-bets-placed: updated-bet-amount,
                            entry-performance-value: (var-get current-performance-metric)
                        })
                    
                    (match (safe-subtract-numbers bettor-balance bet-amount)
                        updated-balance
                        (begin
                            (map-set performance-bet-balances tx-sender updated-balance)
                            (match (safe-subtract-numbers (var-get total-active-bets-supply) 
                                                bet-amount)
                                updated-supply
                                (begin
                                    (var-set total-active-bets-supply updated-supply)
                                    (ok true))
                                error ERR-ARITHMETIC-OVERFLOW))
                        error ERR-ARITHMETIC-OVERFLOW))
                error ERR-ARITHMETIC-OVERFLOW)
            error ERR-ARITHMETIC-OVERFLOW))
        error ERR-ARITHMETIC-OVERFLOW))
)

(define-public (transfer-bet-position (recipient principal) (transfer-amount uint))
    (begin
        (asserts! (> transfer-amount u0) ERR-ZERO-AMOUNT)
        (asserts! (<= transfer-amount (get-bettor-balance tx-sender)) ERR-INSUFFICIENT-BET-BALANCE)
        (asserts! (not (is-eq tx-sender recipient)) ERR-INVALID-BETTOR)
        
        (execute-bet-transfer tx-sender recipient transfer-amount))
)

(define-public (add-stake-to-position (stake-amount uint))
    (let (
        (position-details (default-to 
            {
                stake-amount-locked: u0, 
                performance-bets-placed: u0, 
                entry-performance-value: u0
            }
            (get-position-details tx-sender)))
    )
    (asserts! (> stake-amount u0) ERR-ZERO-AMOUNT)
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    (match (safe-add-numbers (get stake-amount-locked position-details) 
                    stake-amount)
        updated-stake-amount
        (begin
            (map-set bettor-positions tx-sender
                {
                    stake-amount-locked: updated-stake-amount,
                    performance-bets-placed: (get performance-bets-placed position-details),
                    entry-performance-value: (var-get current-performance-metric)
                })
            (ok true))
        error ERR-ARITHMETIC-OVERFLOW))
)

(define-public (force-close-position (position-owner principal))
    (let (
        (position-details (unwrap! (get-position-details position-owner) 
                               ERR-NO-POSITION-EXISTS))
        (current-stake-ratio (unwrap! (calculate-position-stake-ratio position-owner) 
                                    ERR-UNAUTHORIZED-ACCESS))
    )
    (asserts! (< current-stake-ratio MARGIN-CALL-THRESHOLD) 
              ERR-UNAUTHORIZED-ACCESS)
    
    (try! (as-contract (stx-transfer? (get stake-amount-locked position-details)
                                     (as-contract tx-sender)
                                     tx-sender)))
    
    (map-delete bettor-positions position-owner)
    
    (map-set performance-bet-balances position-owner u0)
    (match (safe-subtract-numbers (var-get total-active-bets-supply) 
                         (get performance-bets-placed position-details))
        updated-supply
        (begin
            (var-set total-active-bets-supply updated-supply)
            (ok true))
        error ERR-ARITHMETIC-OVERFLOW))
)
;; Basic Performance Betting Contract
;; Commit Message: "feat: Initial implementation of basic performance betting with core functionality"

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-ZERO-AMOUNT (err u103))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MINIMUM-BET u100000000) ;; 1.00 tokens (8 decimals)

;; Data variables
(define-data-var performance-metric uint u0)
(define-data-var total-bets uint u0)

;; Data maps
(define-map bet-balances principal uint)
(define-map bet-positions
    principal
    {
        stake-amount: uint,
        bet-size: uint
    }
)

;; Read-only functions
(define-read-only (get-balance (bettor principal))
    (default-to u0 (map-get? bet-balances bettor))
)

(define-read-only (get-current-metric)
    (var-get performance-metric)
)

(define-read-only (get-position (bettor principal))
    (map-get? bet-positions bettor)
)

;; Public functions
(define-public (update-metric (new-metric uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (var-set performance-metric new-metric)
        (ok true))
)

(define-public (place-bet (bet-amount uint))
    (begin
        (asserts! (> bet-amount u0) ERR-ZERO-AMOUNT)
        (asserts! (>= bet-amount MINIMUM-BET) ERR-INVALID-AMOUNT)
        
        (try! (stx-transfer? bet-amount tx-sender (as-contract tx-sender)))
        
        (map-set bet-positions tx-sender
            {
                stake-amount: bet-amount,
                bet-size: bet-amount
            })
        
        (map-set bet-balances tx-sender bet-amount)
        (var-set total-bets (+ (var-get total-bets) bet-amount))
        (ok true))
)

(define-public (close-bet (bet-amount uint))
    (let (
        (position (unwrap! (get-position tx-sender) ERR-UNAUTHORIZED))
        (current-balance (get-balance tx-sender))
    )
    (asserts! (>= current-balance bet-amount) ERR-INSUFFICIENT-BALANCE)
    
    (try! (as-contract (stx-transfer? bet-amount (as-contract tx-sender) tx-sender)))
    
    (map-delete bet-positions tx-sender)
    (map-set bet-balances tx-sender u0)
    (var-set total-bets (- (var-get total-bets) bet-amount))
    (ok true))
)
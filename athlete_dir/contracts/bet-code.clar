;; Stage 2: Enhanced Performance Betting Contract
;; Commit Message: "feat: Add safety features, stake requirements, and improved mathematical operations"

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INSUFFICIENT-BET-BALANCE (err u101))
(define-constant ERR-INVALID-BET-AMOUNT (err u102))
(define-constant ERR-STATS-EXPIRED (err u103))
(define-constant ERR-INSUFFICIENT-STAKE (err u104))
(define-constant ERR-INVALID-METRIC (err u105))
(define-constant ERR-ARITHMETIC-OVERFLOW (err u106))
(define-constant ERR-ZERO-AMOUNT (err u107))

;; Constants
(define-constant CONTRACT-ADMINISTRATOR tx-sender)
(define-constant STATS-EXPIRY-BLOCKS u600) ;; 10 minutes
(define-constant REQUIRED-STAKE-RATIO u150) ;; 150%
(define-constant MINIMUM-BET u100000000) ;; 1.00 tokens (8 decimals)
(define-constant MAXIMUM-METRIC u1000000000000)

;; Data variables
(define-data-var last-update-block uint u0)
(define-data-var performance-metric uint u0)
(define-data-var total-bets-supply uint u0)

;; Data maps
(define-map bet-balances principal uint)
(define-map bettor-positions
    principal
    {
        stake-amount: uint,
        bet-size: uint,
        entry-metric: uint
    }
)

;; Safe math functions
(define-private (safe-multiply (a uint) (b uint))
    (let ((result (* a b)))
        (asserts! (or (is-eq a u0) (is-eq (/ result a) b)) ERR-ARITHMETIC-OVERFLOW)
        (ok result)))

(define-private (safe-add (a uint) (b uint))
    (let ((result (+ a b)))
        (asserts! (>= result a) ERR-ARITHMETIC-OVERFLOW)
        (ok result)))

;; Read-only functions
(define-read-only (get-balance (bettor principal))
    (default-to u0 (map-get? bet-balances bettor))
)

(define-read-only (get-current-metric)
    (var-get performance-metric)
)

(define-read-only (get-position (bettor principal))
    (map-get? bettor-positions bettor)
)

;; Public functions
(define-public (update-metric (new-metric uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-ADMINISTRATOR) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (> new-metric u0) ERR-INVALID-METRIC)
        (asserts! (< new-metric MAXIMUM-METRIC) ERR-INVALID-METRIC)
        (var-set performance-metric new-metric)
        (var-set last-update-block block-height)
        (ok true))
)

(define-public (place-bet (bet-amount uint))
    (let (
        (current-metric (var-get performance-metric))
    )
    (asserts! (> bet-amount u0) ERR-ZERO-AMOUNT)
    (asserts! (>= bet-amount MINIMUM-BET) ERR-INVALID-BET-AMOUNT)
    (asserts! (<= (- block-height (var-get last-update-block)) STATS-EXPIRY-BLOCKS) 
              ERR-STATS-EXPIRED)
    
    (match (safe-multiply bet-amount (/ REQUIRED-STAKE-RATIO u100))
        required-stake
        (begin
            (try! (stx-transfer? required-stake tx-sender (as-contract tx-sender)))
            
            (map-set bettor-positions tx-sender
                {
                    stake-amount: required-stake,
                    bet-size: bet-amount,
                    entry-metric: current-metric
                })
            
            (match (safe-add (get-balance tx-sender) bet-amount)
                new-balance
                (begin
                    (map-set bet-balances tx-sender new-balance)
                    (var-set total-bets-supply (+ (var-get total-bets-supply) bet-amount))
                    (ok true))
                error (err error)))
        error (err error)))
)

(define-public (close-bet (bet-amount uint))
    (let (
        (position (unwrap! (get-position tx-sender) ERR-UNAUTHORIZED-ACCESS))
        (current-balance (get-balance tx-sender))
    )
    (asserts! (>= current-balance bet-amount) ERR-INSUFFICIENT-BET-BALANCE)
    
    (try! (as-contract (stx-transfer? (get stake-amount position) 
                                     (as-contract tx-sender) 
                                     tx-sender)))
    
    (map-delete bettor-positions tx-sender)
    (map-set bet-balances tx-sender u0)
    (var-set total-bets-supply (- (var-get total-bets-supply) bet-amount))
    (ok true))
)

(define-public (add-stake (stake-amount uint))
    (let (
        (position (unwrap! (get-position tx-sender) ERR-UNAUTHORIZED-ACCESS))
    )
    (asserts! (> stake-amount u0) ERR-ZERO-AMOUNT)
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set bettor-positions tx-sender
        {
            stake-amount: (+ (get stake-amount position) stake-amount),
            bet-size: (get bet-size position),
            entry-metric: (var-get performance-metric)
        })
    (ok true))
)
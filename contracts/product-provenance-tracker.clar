;; product-provenance-tracker
;; Immutable product journey tracking with multi-stakeholder verification and authenticity proof Smart Contract

;; ===================================================================
;; CONSTANTS
;; ===================================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-PRODUCT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STAKEHOLDER (err u102))
(define-constant ERR-CHECKPOINT-EXISTS (err u103))
(define-constant ERR-INVALID-STATUS (err u104))
(define-constant ERR-PRODUCT-FINALIZED (err u105))
(define-constant ERR-INSUFFICIENT-VERIFICATIONS (err u106))

;; Product statuses
(define-constant STATUS-CREATED u1)
(define-constant STATUS-IN-TRANSIT u2)
(define-constant STATUS-DELIVERED u3)
(define-constant STATUS-VERIFIED u4)
(define-constant STATUS-FINALIZED u5)

;; Minimum verifications required
(define-constant MIN-VERIFICATIONS u2)

;; ===================================================================
;; DATA MAPS AND VARIABLES
;; ===================================================================

;; Product registry mapping product-id to product data
(define-map products
  { product-id: uint }
  {
    creator: principal,
    name: (string-ascii 100),
    description: (string-ascii 500),
    origin: (string-ascii 100),
    created-at: uint,
    status: uint,
    finalized: bool,
    verification-count: uint
  }
)

;; Product checkpoint tracking - records each step in the supply chain
(define-map checkpoints
  { product-id: uint, checkpoint-id: uint }
  {
    stakeholder: principal,
    location: (string-ascii 100),
    timestamp: uint,
    action: (string-ascii 200),
    verified: bool,
    verification-hash: (buff 32)
  }
)

;; Stakeholder registry and permissions
(define-map stakeholders
  { stakeholder: principal }
  {
    name: (string-ascii 100),
    role: (string-ascii 50),
    verified: bool,
    registered-at: uint
  }
)

;; Product authenticity proofs
(define-map authenticity-proofs
  { product-id: uint }
  {
    proof-hash: (buff 32),
    verifier: principal,
    verified-at: uint,
    confidence-score: uint
  }
)

;; Verification tracking per product per stakeholder
(define-map product-verifications
  { product-id: uint, verifier: principal }
  {
    verified: bool,
    verified-at: uint,
    verification-data: (string-ascii 200)
  }
)

;; Global counters
(define-data-var next-product-id uint u1)
(define-data-var next-checkpoint-id uint u1)
(define-data-var total-products uint u0)
(define-data-var total-stakeholders uint u0)

;; ===================================================================
;; PRIVATE FUNCTIONS
;; ===================================================================

;; Validate stakeholder authorization
(define-private (is-authorized-stakeholder (stakeholder principal))
  (match (map-get? stakeholders { stakeholder: stakeholder })
    stakeholder-data (get verified stakeholder-data)
    false
  )
)

;; Generate verification hash
(define-private (generate-verification-hash (product-id uint) (stakeholder principal) (timestamp uint))
  (hash160 (concat 
    (concat (unwrap-panic (to-consensus-buff? product-id)) 
            (unwrap-panic (to-consensus-buff? stakeholder)))
    (unwrap-panic (to-consensus-buff? timestamp))
  ))
)

;; Check if product exists
(define-private (product-exists (product-id uint))
  (is-some (map-get? products { product-id: product-id }))
)

;; Validate status transition
(define-private (is-valid-status-transition (current-status uint) (new-status uint))
  (or 
    (and (is-eq current-status STATUS-CREATED) (is-eq new-status STATUS-IN-TRANSIT))
    (and (is-eq current-status STATUS-IN-TRANSIT) (is-eq new-status STATUS-DELIVERED))
    (and (is-eq current-status STATUS-DELIVERED) (is-eq new-status STATUS-VERIFIED))
    (and (is-eq current-status STATUS-VERIFIED) (is-eq new-status STATUS-FINALIZED))
  )
)

;; ===================================================================
;; READ-ONLY FUNCTIONS
;; ===================================================================

;; Get product information
(define-read-only (get-product (product-id uint))
  (map-get? products { product-id: product-id })
)

;; Get stakeholder information
(define-read-only (get-stakeholder (stakeholder principal))
  (map-get? stakeholders { stakeholder: stakeholder })
)

;; Get checkpoint information
(define-read-only (get-checkpoint (product-id uint) (checkpoint-id uint))
  (map-get? checkpoints { product-id: product-id, checkpoint-id: checkpoint-id })
)

;; Get authenticity proof
(define-read-only (get-authenticity-proof (product-id uint))
  (map-get? authenticity-proofs { product-id: product-id })
)

;; Get verification status
(define-read-only (get-verification (product-id uint) (verifier principal))
  (map-get? product-verifications { product-id: product-id, verifier: verifier })
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-products: (var-get total-products),
    total-stakeholders: (var-get total-stakeholders),
    next-product-id: (var-get next-product-id),
    next-checkpoint-id: (var-get next-checkpoint-id)
  }
)

;; ===================================================================
;; PUBLIC FUNCTIONS
;; ===================================================================

;; Register a new stakeholder
(define-public (register-stakeholder (name (string-ascii 100)) (role (string-ascii 50)))
  (let
    ((stakeholder tx-sender))
    (asserts! (is-none (map-get? stakeholders { stakeholder: stakeholder })) ERR-INVALID-STAKEHOLDER)
    (map-set stakeholders
      { stakeholder: stakeholder }
      {
        name: name,
        role: role,
        verified: false,
        registered-at: block-height
      }
    )
    (var-set total-stakeholders (+ (var-get total-stakeholders) u1))
    (ok stakeholder)
  )
)

;; Verify stakeholder (only contract owner can verify)
(define-public (verify-stakeholder (stakeholder principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (match (map-get? stakeholders { stakeholder: stakeholder })
      stakeholder-data
      (begin
        (map-set stakeholders
          { stakeholder: stakeholder }
          (merge stakeholder-data { verified: true })
        )
        (ok true)
      )
      ERR-INVALID-STAKEHOLDER
    )
  )
)

;; Create a new product
(define-public (create-product (name (string-ascii 100)) (description (string-ascii 500)) (origin (string-ascii 100)))
  (let
    ((product-id (var-get next-product-id))
     (creator tx-sender))
    (asserts! (is-authorized-stakeholder creator) ERR-UNAUTHORIZED)
    (map-set products
      { product-id: product-id }
      {
        creator: creator,
        name: name,
        description: description,
        origin: origin,
        created-at: block-height,
        status: STATUS-CREATED,
        finalized: false,
        verification-count: u0
      }
    )
    (var-set next-product-id (+ product-id u1))
    (var-set total-products (+ (var-get total-products) u1))
    (ok product-id)
  )
)

;; Add checkpoint to product journey
(define-public (add-checkpoint (product-id uint) (location (string-ascii 100)) (action (string-ascii 200)))
  (let
    ((checkpoint-id (var-get next-checkpoint-id))
     (stakeholder tx-sender)
     (verification-hash (generate-verification-hash product-id stakeholder block-height)))
    (asserts! (is-authorized-stakeholder stakeholder) ERR-UNAUTHORIZED)
    (asserts! (product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    (match (map-get? products { product-id: product-id })
      product-data
      (begin
        (asserts! (not (get finalized product-data)) ERR-PRODUCT-FINALIZED)
        (map-set checkpoints
          { product-id: product-id, checkpoint-id: checkpoint-id }
          {
            stakeholder: stakeholder,
            location: location,
            timestamp: block-height,
            action: action,
            verified: false,
            verification-hash: verification-hash
          }
        )
        (var-set next-checkpoint-id (+ checkpoint-id u1))
        (ok checkpoint-id)
      )
      ERR-PRODUCT-NOT-FOUND
    )
  )
)

;; Verify product authenticity
(define-public (verify-product (product-id uint) (verification-data (string-ascii 200)))
  (let
    ((verifier tx-sender))
    (asserts! (is-authorized-stakeholder verifier) ERR-UNAUTHORIZED)
    (asserts! (product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    (match (map-get? products { product-id: product-id })
      product-data
      (begin
        (asserts! (not (get finalized product-data)) ERR-PRODUCT-FINALIZED)
        (map-set product-verifications
          { product-id: product-id, verifier: verifier }
          {
            verified: true,
            verified-at: block-height,
            verification-data: verification-data
          }
        )
        (map-set products
          { product-id: product-id }
          (merge product-data { verification-count: (+ (get verification-count product-data) u1) })
        )
        (ok true)
      )
      ERR-PRODUCT-NOT-FOUND
    )
  )
)

;; Update product status
(define-public (update-product-status (product-id uint) (new-status uint))
  (let
    ((stakeholder tx-sender))
    (asserts! (is-authorized-stakeholder stakeholder) ERR-UNAUTHORIZED)
    (asserts! (product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    (match (map-get? products { product-id: product-id })
      product-data
      (begin
        (asserts! (not (get finalized product-data)) ERR-PRODUCT-FINALIZED)
        (asserts! (is-valid-status-transition (get status product-data) new-status) ERR-INVALID-STATUS)
        (map-set products
          { product-id: product-id }
          (merge product-data { status: new-status })
        )
        (ok true)
      )
      ERR-PRODUCT-NOT-FOUND
    )
  )
)

;; Finalize product (requires minimum verifications)
(define-public (finalize-product (product-id uint))
  (let
    ((stakeholder tx-sender))
    (asserts! (is-authorized-stakeholder stakeholder) ERR-UNAUTHORIZED)
    (asserts! (product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    (match (map-get? products { product-id: product-id })
      product-data
      (begin
        (asserts! (not (get finalized product-data)) ERR-PRODUCT-FINALIZED)
        (asserts! (>= (get verification-count product-data) MIN-VERIFICATIONS) ERR-INSUFFICIENT-VERIFICATIONS)
        (map-set products
          { product-id: product-id }
          (merge product-data { 
            status: STATUS-FINALIZED,
            finalized: true
          })
        )
        (ok true)
      )
      ERR-PRODUCT-NOT-FOUND
    )
  )
)

;; Generate authenticity proof
(define-public (generate-authenticity-proof (product-id uint) (confidence-score uint))
  (let
    ((verifier tx-sender)
     (proof-hash (generate-verification-hash product-id verifier block-height)))
    (asserts! (is-authorized-stakeholder verifier) ERR-UNAUTHORIZED)
    (asserts! (product-exists product-id) ERR-PRODUCT-NOT-FOUND)
    (map-set authenticity-proofs
      { product-id: product-id }
      {
        proof-hash: proof-hash,
        verifier: verifier,
        verified-at: block-height,
        confidence-score: confidence-score
      }
    )
    (ok proof-hash)
  )
)

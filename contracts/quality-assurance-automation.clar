;; quality-assurance-automation
;; Automated quality control checkpoint system with stakeholder notifications and compliance verification Smart Contract

;; ===================================================================
;; CONSTANTS
;; ===================================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-CHECKPOINT-NOT-FOUND (err u201))
(define-constant ERR-INVALID-INSPECTOR (err u202))
(define-constant ERR-ALREADY-INSPECTED (err u203))
(define-constant ERR-INSPECTION-FAILED (err u204))
(define-constant ERR-INVALID-CRITERIA (err u205))
(define-constant ERR-NOTIFICATION-FAILED (err u206))
(define-constant ERR-COMPLIANCE-VIOLATION (err u207))

;; Quality statuses
(define-constant STATUS-PENDING u1)
(define-constant STATUS-IN-PROGRESS u2)
(define-constant STATUS-PASSED u3)
(define-constant STATUS-FAILED u4)
(define-constant STATUS-ESCALATED u5)

;; Inspection types
(define-constant INSPECTION-VISUAL u1)
(define-constant INSPECTION-TECHNICAL u2)
(define-constant INSPECTION-SAFETY u3)
(define-constant INSPECTION-COMPLIANCE u4)

;; Notification priorities
(define-constant PRIORITY-LOW u1)
(define-constant PRIORITY-MEDIUM u2)
(define-constant PRIORITY-HIGH u3)
(define-constant PRIORITY-CRITICAL u4)

;; ===================================================================
;; DATA MAPS AND VARIABLES
;; ===================================================================

;; Quality checkpoints for products
(define-map quality-checkpoints
  { checkpoint-id: uint }
  {
    product-id: uint,
    inspector: principal,
    location: (string-ascii 100),
    checkpoint-type: uint,
    status: uint,
    created-at: uint,
    completed-at: (optional uint),
    score: (optional uint),
    notes: (string-ascii 500)
  }
)

;; Quality criteria and standards
(define-map quality-criteria
  { criteria-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 300),
    min-score: uint,
    max-score: uint,
    weight: uint,
    mandatory: bool,
    created-by: principal
  }
)

;; Inspection results
(define-map inspection-results
  { checkpoint-id: uint, criteria-id: uint }
  {
    score: uint,
    passed: bool,
    inspector-notes: (string-ascii 300),
    evidence-hash: (optional (buff 32))
  }
)

;; Inspector registry
(define-map inspectors
  { inspector: principal }
  {
    name: (string-ascii 100),
    certification: (string-ascii 100),
    specialization: (string-ascii 100),
    verified: bool,
    total-inspections: uint,
    success-rate: uint,
    registered-at: uint
  }
)

;; Stakeholder notifications
(define-map notifications
  { notification-id: uint }
  {
    recipient: principal,
    sender: principal,
    message: (string-ascii 200),
    priority: uint,
    related-checkpoint: (optional uint),
    sent-at: uint,
    read: bool,
    action-required: bool
  }
)

;; Compliance violations
(define-map compliance-violations
  { violation-id: uint }
  {
    checkpoint-id: uint,
    violation-type: (string-ascii 100),
    severity: uint,
    description: (string-ascii 400),
    reported-by: principal,
    status: uint,
    resolution: (optional (string-ascii 300)),
    reported-at: uint,
    resolved-at: (optional uint)
  }
)

;; Quality metrics per product
(define-map product-quality-metrics
  { product-id: uint }
  {
    total-checkpoints: uint,
    passed-checkpoints: uint,
    failed-checkpoints: uint,
    average-score: uint,
    compliance-score: uint,
    last-updated: uint
  }
)

;; Global counters
(define-data-var next-checkpoint-id uint u1)
(define-data-var next-criteria-id uint u1)
(define-data-var next-notification-id uint u1)
(define-data-var next-violation-id uint u1)
(define-data-var total-inspectors uint u0)

;; ===================================================================
;; PRIVATE FUNCTIONS
;; ===================================================================

;; Check if inspector is authorized
(define-private (is-authorized-inspector (inspector principal))
  (match (map-get? inspectors { inspector: inspector })
    inspector-data (get verified inspector-data)
    false
  )
)

;; Calculate quality score
(define-private (calculate-quality-score (checkpoint-id uint))
  (let
    ((total-score u0)
     (total-weight u0)
     (weighted-score u0))
    ;; In a real implementation, this would iterate through all criteria
    ;; For now, returning a placeholder score
    u85
  )
)

;; Send automated notification
(define-private (send-notification (recipient principal) (message (string-ascii 200)) (priority uint) (checkpoint-id (optional uint)))
  (let
    ((notification-id (var-get next-notification-id)))
    (map-set notifications
      { notification-id: notification-id }
      {
        recipient: recipient,
        sender: tx-sender,
        message: message,
        priority: priority,
        related-checkpoint: checkpoint-id,
        sent-at: block-height,
        read: false,
        action-required: (>= priority PRIORITY-HIGH)
      }
    )
    (var-set next-notification-id (+ notification-id u1))
    notification-id
  )
)

;; Update product metrics
(define-private (update-product-metrics (product-id uint) (passed bool))
  (match (map-get? product-quality-metrics { product-id: product-id })
    metrics
    (map-set product-quality-metrics
      { product-id: product-id }
      (if passed
        (merge metrics { 
          passed-checkpoints: (+ (get passed-checkpoints metrics) u1),
          last-updated: block-height
        })
        (merge metrics { 
          failed-checkpoints: (+ (get failed-checkpoints metrics) u1),
          last-updated: block-height
        })
      )
    )
    ;; Initialize metrics if not exists
    (map-set product-quality-metrics
      { product-id: product-id }
      {
        total-checkpoints: u1,
        passed-checkpoints: (if passed u1 u0),
        failed-checkpoints: (if passed u0 u1),
        average-score: u0,
        compliance-score: u100,
        last-updated: block-height
      }
    )
  )
)

;; ===================================================================
;; READ-ONLY FUNCTIONS
;; ===================================================================

;; Get quality checkpoint
(define-read-only (get-quality-checkpoint (checkpoint-id uint))
  (map-get? quality-checkpoints { checkpoint-id: checkpoint-id })
)

;; Get quality criteria
(define-read-only (get-quality-criteria (criteria-id uint))
  (map-get? quality-criteria { criteria-id: criteria-id })
)

;; Get inspection result
(define-read-only (get-inspection-result (checkpoint-id uint) (criteria-id uint))
  (map-get? inspection-results { checkpoint-id: checkpoint-id, criteria-id: criteria-id })
)

;; Get inspector information
(define-read-only (get-inspector (inspector principal))
  (map-get? inspectors { inspector: inspector })
)

;; Get notification
(define-read-only (get-notification (notification-id uint))
  (map-get? notifications { notification-id: notification-id })
)

;; Get compliance violation
(define-read-only (get-compliance-violation (violation-id uint))
  (map-get? compliance-violations { violation-id: violation-id })
)

;; Get product quality metrics
(define-read-only (get-product-quality-metrics (product-id uint))
  (map-get? product-quality-metrics { product-id: product-id })
)

;; Get contract statistics
(define-read-only (get-qa-stats)
  {
    total-inspectors: (var-get total-inspectors),
    next-checkpoint-id: (var-get next-checkpoint-id),
    next-criteria-id: (var-get next-criteria-id),
    next-notification-id: (var-get next-notification-id),
    next-violation-id: (var-get next-violation-id)
  }
)

;; ===================================================================
;; PUBLIC FUNCTIONS
;; ===================================================================

;; Register a new inspector
(define-public (register-inspector (name (string-ascii 100)) (certification (string-ascii 100)) (specialization (string-ascii 100)))
  (let
    ((inspector tx-sender))
    (asserts! (is-none (map-get? inspectors { inspector: inspector })) ERR-INVALID-INSPECTOR)
    (map-set inspectors
      { inspector: inspector }
      {
        name: name,
        certification: certification,
        specialization: specialization,
        verified: false,
        total-inspections: u0,
        success-rate: u100,
        registered-at: block-height
      }
    )
    (var-set total-inspectors (+ (var-get total-inspectors) u1))
    (ok inspector)
  )
)

;; Verify inspector (only contract owner can verify)
(define-public (verify-inspector (inspector principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (match (map-get? inspectors { inspector: inspector })
      inspector-data
      (begin
        (map-set inspectors
          { inspector: inspector }
          (merge inspector-data { verified: true })
        )
        (ok true)
      )
      ERR-INVALID-INSPECTOR
    )
  )
)

;; Create quality criteria
(define-public (create-quality-criteria (name (string-ascii 100)) (description (string-ascii 300)) (min-score uint) (max-score uint) (weight uint) (mandatory bool))
  (let
    ((criteria-id (var-get next-criteria-id)))
    (asserts! (< min-score max-score) ERR-INVALID-CRITERIA)
    (asserts! (> weight u0) ERR-INVALID-CRITERIA)
    (map-set quality-criteria
      { criteria-id: criteria-id }
      {
        name: name,
        description: description,
        min-score: min-score,
        max-score: max-score,
        weight: weight,
        mandatory: mandatory,
        created-by: tx-sender
      }
    )
    (var-set next-criteria-id (+ criteria-id u1))
    (ok criteria-id)
  )
)

;; Create quality checkpoint
(define-public (create-quality-checkpoint (product-id uint) (location (string-ascii 100)) (checkpoint-type uint))
  (let
    ((checkpoint-id (var-get next-checkpoint-id))
     (inspector tx-sender))
    (asserts! (is-authorized-inspector inspector) ERR-UNAUTHORIZED)
    (map-set quality-checkpoints
      { checkpoint-id: checkpoint-id }
      {
        product-id: product-id,
        inspector: inspector,
        location: location,
        checkpoint-type: checkpoint-type,
        status: STATUS-PENDING,
        created-at: block-height,
        completed-at: none,
        score: none,
        notes: ""
      }
    )
    (var-set next-checkpoint-id (+ checkpoint-id u1))
    ;; Send notification to stakeholders
    (send-notification inspector "New quality checkpoint created" PRIORITY-MEDIUM (some checkpoint-id))
    (ok checkpoint-id)
  )
)

;; Start inspection
(define-public (start-inspection (checkpoint-id uint))
  (let
    ((inspector tx-sender))
    (asserts! (is-authorized-inspector inspector) ERR-UNAUTHORIZED)
    (match (map-get? quality-checkpoints { checkpoint-id: checkpoint-id })
      checkpoint-data
      (begin
        (asserts! (is-eq (get inspector checkpoint-data) inspector) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status checkpoint-data) STATUS-PENDING) ERR-ALREADY-INSPECTED)
        (map-set quality-checkpoints
          { checkpoint-id: checkpoint-id }
          (merge checkpoint-data { status: STATUS-IN-PROGRESS })
        )
        (ok true)
      )
      ERR-CHECKPOINT-NOT-FOUND
    )
  )
)

;; Submit inspection result
(define-public (submit-inspection-result (checkpoint-id uint) (criteria-id uint) (score uint) (inspector-notes (string-ascii 300)) (evidence-hash (optional (buff 32))))
  (let
    ((inspector tx-sender))
    (asserts! (is-authorized-inspector inspector) ERR-UNAUTHORIZED)
    (match (map-get? quality-checkpoints { checkpoint-id: checkpoint-id })
      checkpoint-data
      (begin
        (asserts! (is-eq (get inspector checkpoint-data) inspector) ERR-UNAUTHORIZED)
        (match (map-get? quality-criteria { criteria-id: criteria-id })
          criteria-data
          (let
            ((passed (>= score (get min-score criteria-data))))
            (asserts! (<= score (get max-score criteria-data)) ERR-INVALID-CRITERIA)
            (map-set inspection-results
              { checkpoint-id: checkpoint-id, criteria-id: criteria-id }
              {
                score: score,
                passed: passed,
                inspector-notes: inspector-notes,
                evidence-hash: evidence-hash
              }
            )
            (ok passed)
          )
          ERR-INVALID-CRITERIA
        )
      )
      ERR-CHECKPOINT-NOT-FOUND
    )
  )
)

;; Complete inspection
(define-public (complete-inspection (checkpoint-id uint) (final-notes (string-ascii 500)))
  (let
    ((inspector tx-sender)
     (final-score (calculate-quality-score checkpoint-id)))
    (asserts! (is-authorized-inspector inspector) ERR-UNAUTHORIZED)
    (match (map-get? quality-checkpoints { checkpoint-id: checkpoint-id })
      checkpoint-data
      (begin
        (asserts! (is-eq (get inspector checkpoint-data) inspector) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status checkpoint-data) STATUS-IN-PROGRESS) ERR-INVALID-INSPECTOR)
        (let
          ((passed (>= final-score u70))
           (new-status (if passed STATUS-PASSED STATUS-FAILED)))
          (map-set quality-checkpoints
            { checkpoint-id: checkpoint-id }
            (merge checkpoint-data {
              status: new-status,
              completed-at: (some block-height),
              score: (some final-score),
              notes: final-notes
            })
          )
          ;; Update product metrics
          (update-product-metrics (get product-id checkpoint-data) passed)
          ;; Update inspector statistics
          (match (map-get? inspectors { inspector: inspector })
            inspector-data
            (map-set inspectors
              { inspector: inspector }
              (merge inspector-data {
                total-inspections: (+ (get total-inspections inspector-data) u1)
              })
            )
            false ;; Inspector not found - shouldn't happen
          )
          ;; Send completion notification
          (begin
            (if passed
              (send-notification inspector "Quality inspection passed" PRIORITY-LOW (some checkpoint-id))
              (send-notification inspector "Quality inspection failed - action required" PRIORITY-HIGH (some checkpoint-id))
            )
            ;; Escalate if critical failure
            (if (and (not passed) (< final-score u50))
              (map-set quality-checkpoints
                { checkpoint-id: checkpoint-id }
                (merge checkpoint-data { status: STATUS-ESCALATED })
              )
              false
            )
          )
          (ok { passed: passed, score: final-score })
        )
      )
      ERR-CHECKPOINT-NOT-FOUND
    )
  )
)

;; Report compliance violation
(define-public (report-compliance-violation (checkpoint-id uint) (violation-type (string-ascii 100)) (severity uint) (description (string-ascii 400)))
  (let
    ((violation-id (var-get next-violation-id))
     (reporter tx-sender))
    (asserts! (is-authorized-inspector reporter) ERR-UNAUTHORIZED)
    (map-set compliance-violations
      { violation-id: violation-id }
      {
        checkpoint-id: checkpoint-id,
        violation-type: violation-type,
        severity: severity,
        description: description,
        reported-by: reporter,
        status: STATUS-PENDING,
        resolution: none,
        reported-at: block-height,
        resolved-at: none
      }
    )
    (var-set next-violation-id (+ violation-id u1))
    ;; Send high-priority notification for compliance violations
    (send-notification CONTRACT-OWNER "Compliance violation reported" PRIORITY-CRITICAL (some checkpoint-id))
    (ok violation-id)
  )
)

;; Mark notification as read
(define-public (mark-notification-read (notification-id uint))
  (match (map-get? notifications { notification-id: notification-id })
    notification-data
    (begin
      (asserts! (is-eq (get recipient notification-data) tx-sender) ERR-UNAUTHORIZED)
      (map-set notifications
        { notification-id: notification-id }
        (merge notification-data { read: true })
      )
      (ok true)
    )
    ERR-CHECKPOINT-NOT-FOUND
  )
)

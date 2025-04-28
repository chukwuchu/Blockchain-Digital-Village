;; Blockchain Digital Village 

;; ===============================
;; STATE MANAGEMENT DATA STRUCTURES
;; ===============================

;; Main participant data repository
(define-map participant-registry
  { participant-id: uint }
  {
    display-name: (string-ascii 50),
    account-address: principal,
    enrollment-date: uint,
    personal-statement: (string-ascii 160),
    interest-tags: (list 5 (string-ascii 30))
  }
)

;; Profile data visibility control map
(define-map data-access-permissions
  { participant-id: uint, accessor-address: principal }
  { access-allowed: bool }
)

;; Participant engagement metrics storage
(define-map engagement-metrics
  { participant-id: uint }
  {
    recent-visit: uint,
    visit-count: uint,
    recent-interaction: (string-ascii 50)
  }
)

;; ===============================
;; PERSISTENT STATE VARIABLES
;; ===============================

;; Total registered participants counter
(define-data-var participants-total uint u0)

;; ===============================
;; SYSTEM CONSTANTS
;; ===============================

;; Error response codes
(define-constant ERROR-UNAUTHORIZED (err u500))
(define-constant ERROR-RECORD-NOT-FOUND (err u501))
(define-constant ERROR-DUPLICATE-ENTRY (err u502))
(define-constant ERROR-VALIDATION-FAILED (err u503))
(define-constant ERROR-ACCESS-DENIED (err u504))

;; Administrative configuration
(define-constant PLATFORM-ADMINISTRATOR tx-sender)

;; ===============================
;; INTERNAL UTILITY FUNCTIONS
;; ===============================

;; Validate participant record existence
(define-private (participant-record-exists? (participant-id uint))
  (is-some (map-get? participant-registry { participant-id: participant-id }))
)

;; Verify participant record ownership
(define-private (is-participant-owner? (participant-id uint) (address principal))
  (match (map-get? participant-registry { participant-id: participant-id })
    participant-record (is-eq (get account-address participant-record) address)
    false
  )
)

;; Single interest tag validation
(define-private (is-tag-valid? (tag (string-ascii 30)))
  (and
    (> (len tag) u0)
    (< (len tag) u31)
  )
)

;; Complete interest tags validation
(define-private (are-tags-valid? (interest-tags (list 5 (string-ascii 30))))
  (and
    (> (len interest-tags) u0)
    (<= (len interest-tags) u5)
    (is-eq (len (filter is-tag-valid? interest-tags)) (len interest-tags))
  )
)

;; ===============================
;; PARTICIPANT REGISTRATION FUNCTIONS
;; ===============================

;; Create new participant profile
(define-public (create-participant-profile 
    (display-name (string-ascii 50)) 
    (personal-statement (string-ascii 160)) 
    (interest-tags (list 5 (string-ascii 30))))
  (let
    (
      (new-participant-id (+ (var-get participants-total) u1))
    )
    ;; Input validation checks
    (asserts! (and (> (len display-name) u0) (< (len display-name) u51)) ERROR-VALIDATION-FAILED)
    (asserts! (and (> (len personal-statement) u0) (< (len personal-statement) u161)) ERROR-VALIDATION-FAILED)
    (asserts! (are-tags-valid? interest-tags) ERROR-VALIDATION-FAILED)

    ;; Create profile record
    (map-insert participant-registry
      { participant-id: new-participant-id }
      {
        display-name: display-name,
        account-address: tx-sender,
        enrollment-date: block-height,
        personal-statement: personal-statement,
        interest-tags: interest-tags
      }
    )

    ;; Set default self-view permissions
    (map-insert data-access-permissions
      { participant-id: new-participant-id, accessor-address: tx-sender }
      { access-allowed: true }
    )

    ;; Update the total participants counter
    (var-set participants-total new-participant-id)
    (ok new-participant-id)
  )
)

;; Alternative participant registration function (functionally equivalent)
(define-public (register-new-participant 
    (display-name (string-ascii 50)) 
    (personal-statement (string-ascii 160)) 
    (interest-tags (list 5 (string-ascii 30))))
  (let
    (
      (new-participant-id (+ (var-get participants-total) u1))
    )
    ;; Input validation checks
    (asserts! (and (> (len display-name) u0) (< (len display-name) u51)) ERROR-VALIDATION-FAILED)
    (asserts! (and (> (len personal-statement) u0) (< (len personal-statement) u161)) ERROR-VALIDATION-FAILED)
    (asserts! (are-tags-valid? interest-tags) ERROR-VALIDATION-FAILED)

    ;; Create profile record
    (map-insert participant-registry
      { participant-id: new-participant-id }
      {
        display-name: display-name,
        account-address: tx-sender,
        enrollment-date: block-height,
        personal-statement: personal-statement,
        interest-tags: interest-tags
      }
    )

    ;; Set default self-view permissions
    (map-insert data-access-permissions
      { participant-id: new-participant-id, accessor-address: tx-sender }
      { access-allowed: true }
    )

    ;; Update the total participants counter
    (var-set participants-total new-participant-id)
    (ok new-participant-id)
  )
)

;; ===============================
;; PROFILE MANAGEMENT FUNCTIONS
;; ===============================

;; Update participant interest tags
(define-public (modify-participant-interests (participant-id uint) (new-interest-tags (list 5 (string-ascii 30))))
  (let
    (
      (participant-data (unwrap! (map-get? participant-registry { participant-id: participant-id }) ERROR-RECORD-NOT-FOUND))
    )
    ;; Validation checks
    (asserts! (participant-record-exists? participant-id) ERROR-RECORD-NOT-FOUND)
    (asserts! (is-eq (get account-address participant-data) tx-sender) ERROR-ACCESS-DENIED)
    (asserts! (are-tags-valid? new-interest-tags) ERROR-VALIDATION-FAILED)

    ;; Update interest tags
    (map-set participant-registry
      { participant-id: participant-id }
      (merge participant-data { interest-tags: new-interest-tags })
    )
    (ok true)
  )
)

;; Update participant display name
(define-public (change-display-name (participant-id uint) (new-display-name (string-ascii 50)))
  (let
    (
      (participant-data (unwrap! (map-get? participant-registry { participant-id: participant-id }) ERROR-RECORD-NOT-FOUND))
    )
    ;; Validation checks
    (asserts! (participant-record-exists? participant-id) ERROR-RECORD-NOT-FOUND)
    (asserts! (is-eq (get account-address participant-data) tx-sender) ERROR-ACCESS-DENIED)
    (asserts! (and (> (len new-display-name) u0) (< (len new-display-name) u51)) ERROR-VALIDATION-FAILED)

    ;; Update display name
    (map-set participant-registry
      { participant-id: participant-id }
      (merge participant-data { display-name: new-display-name })
    )
    (ok true)
  )
)

;; Optimized function for updating interest tags
(define-public (quick-update-interests (participant-id uint) (new-interest-tags (list 5 (string-ascii 30))))
  (begin
    (asserts! (participant-record-exists? participant-id) ERROR-RECORD-NOT-FOUND)
    (asserts! (are-tags-valid? new-interest-tags) ERROR-VALIDATION-FAILED)
    (map-set participant-registry
      { participant-id: participant-id }
      (merge (unwrap! (map-get? participant-registry { participant-id: participant-id }) ERROR-RECORD-NOT-FOUND) 
             { interest-tags: new-interest-tags })
    )
    (ok "Interests successfully updated")
  )
)

;; Comprehensive profile update function
(define-public (update-full-profile (participant-id uint) 
                                   (new-display-name (string-ascii 50)) 
                                   (new-personal-statement (string-ascii 160)) 
                                   (new-interest-tags (list 5 (string-ascii 30))))
  (let
    (
      (participant-data (unwrap! (map-get? participant-registry { participant-id: participant-id }) ERROR-RECORD-NOT-FOUND))
    )
    ;; Extensive validation checks
    (asserts! (participant-record-exists? participant-id) ERROR-RECORD-NOT-FOUND)
    (asserts! (is-eq (get account-address participant-data) tx-sender) ERROR-ACCESS-DENIED)
    (asserts! (> (len new-display-name) u0) ERROR-VALIDATION-FAILED)
    (asserts! (< (len new-display-name) u51) ERROR-VALIDATION-FAILED)
    (asserts! (> (len new-personal-statement) u0) ERROR-VALIDATION-FAILED)
    (asserts! (< (len new-personal-statement) u161) ERROR-VALIDATION-FAILED)
    (asserts! (are-tags-valid? new-interest-tags) ERROR-VALIDATION-FAILED)

    ;; Update entire profile
    (map-set participant-registry
      { participant-id: participant-id }
      (merge participant-data { 
        display-name: new-display-name, 
        personal-statement: new-personal-statement, 
        interest-tags: new-interest-tags 
      })
    )
    (ok true)
  )
)

;; ===============================
;; ACCESS CONTROL FUNCTIONS
;; ===============================


;; Verify profile access permissions
(define-public (check-profile-access (participant-id uint) (accessor-address principal))
  (let
    (
      (participant-data (unwrap! (map-get? participant-registry { participant-id: participant-id }) ERROR-RECORD-NOT-FOUND))
    )
    ;; Check if the address is allowed to access the profile
    (asserts! (is-eq (get account-address participant-data) accessor-address) ERROR-ACCESS-DENIED)
    (ok true)
  )
)

;; Verify ownership of a participant profile
(define-public (confirm-profile-ownership (participant-id uint) (owner-address principal))
  (let
    (
      (participant-data (unwrap! (map-get? participant-registry { participant-id: participant-id }) ERROR-RECORD-NOT-FOUND))
    )
    (ok (is-eq owner-address (get account-address participant-data)))
  )
)

;; ===============================
;; ENGAGEMENT TRACKING FUNCTIONS
;; ===============================

;; Record participant platform activity
(define-public (log-participant-activity (participant-id uint) (activity-type (string-ascii 50)))
  (let
    (
      (current-metrics (default-to 
        { recent-visit: u0, visit-count: u0, recent-interaction: "None" }
        (map-get? engagement-metrics { participant-id: participant-id })))
    )
    ;; Validate participant exists
    (asserts! (participant-record-exists? participant-id) ERROR-RECORD-NOT-FOUND)

    (ok true)
  )
)

;; Record basic login event
(define-public (register-login-event (participant-id uint))
  (let
    (
      (current-metrics (default-to 
        { recent-visit: u0, visit-count: u0, recent-interaction: "None" }
        (map-get? engagement-metrics { participant-id: participant-id })))
    )
    ;; Validate participant exists
    (asserts! (participant-record-exists? participant-id) ERROR-RECORD-NOT-FOUND)

    ;; Update login metrics
    (map-set engagement-metrics
      { participant-id: participant-id }
      {
        recent-visit: block-height,
        visit-count: (+ (get visit-count current-metrics) u1),
        recent-interaction: "login"
      }
    )
    (ok true)
  )
)


(defpackage :sms-fanout-client
  (:use :cl)
  (:export
   #:connect
   #:connected-p
   #:reconnect-loop))
(in-package :sms-fanout-client)

;; (ql:quickload :websocket-driver-client)
;; (ql:quickload :cl-json)

(defvar *client* nil)
(defvar *client-last-pong* nil)

(defvar sms-fanout-connected-p-timeout-seconds 3)

(defun connected-p (&key (client *client*))
  (let ((client (or client *client*)))
    (when (and client (eq :OPEN (wsd:ready-state client)))
      (let* ((before (GET-UNIVERSAL-TIME))
             (deadline (+ before
                          sms-fanout-connected-p-timeout-seconds))
             pong-received?)
        (wsd:send-text client "ping")
        (loop while
             (and (< (GET-UNIVERSAL-TIME) deadline)
                  (not
                   (setq pong-received?
                         (and *client-last-pong*
                              (>= *client-last-pong* before)))))
           do (sleep .5))
        (when pong-received?
          client)))))

(defun x-message (message)
  (sb-ext:run-program "xmessage" (list message "-center")
                      :search t
                      :wait nil))

(defmacro alist-let (alist vars &rest body)
  (let ((alist-sym (gensym "alist-")))
    `(let ((,alist-sym ,alist))
       (let ,(loop for var in vars
                collect `(,var (cdr (assoc
                                     ,(intern (symbol-name var) :keyword)
                                     ,alist-sym))))
         ,@body))))

(defvar *messages-received* (make-hash-table))

(defun on-message-received (from to message id)
  (unless (gethash id *messages-received*)
    (setf (gethash id *messages-received*) t)
    (let ((text
           (format nil "sms from ~A (to ~A):~%~A" from to
                   (stumpwm::message-colorize message :yellow))))
      (stumpwm:message-wrapped text))))

(defun connect (address)
  (stumpwm::when-let ((current (connected-p)))
    (wsd:close-connection current))
  (let ((client (wsd:make-client address)))
    (wsd:start-connection client)
    (wsd:on :message client
            (lambda (text)
              (format t "~&Got: ~A~%" text)
              (alist-let (cl-json:decode-json-from-string text) (status message-type body)
                (cond
                  ((not (zerop status))
                   (wsd:close-connection client)
                   (error "non-zero status from zerver: ~A" text))
                  ((ppcre:scan "status/" message-type)
                   ;; TODO associate with client object
                   '(stumpwm:message "pong received: ~A" text)
                   (setf *client-last-pong* (GET-UNIVERSAL-TIME)))
                  ((ppcre:scan "push-messages/" message-type)
                   (if (null body)
                       (unless (equal "push-messages/old" message-type)
                         (error "0 messages in body"))
                       (loop for message in body do
                            (alist-let message (to from message id)
                              (on-message-received from to message id)))))
                  (t
                   (wsd:close-connection client)
                   (error "unexpected message type: ~A" message-type))))))
    (wsd:on :close client
            (lambda (&key code reason)
              (format t "sms-fanout: channel closed: ~A ~A" code reason)
              (setf client nil)))
    (wsd:on :error client
            (lambda (err)
              (syslog-log :ERR (format nil "sms-fanout: channel error: ~A" err))
              (setf client nil)))
    client))


(defun syslog-log (priority message)
  ;; '((:EMERG . 0) (:ALERT . 1) (:CRIT . 2) (:ERR . 3) (:WARNING . 4)
  ;;   (:NOTICE . 5) (:INFO . 6) (:DEBUG . 7))
  (cl-syslog:log "stumpwm/sms-fanout" ':user priority
                 message))

(defun reconnect-loop (address &key (reconnect-delay-mins 1))
  (loop do
       (progn
         (if (connected-p :client *client*)
             (syslog-log ':info "already connected")
             (progn
               (syslog-log :info "sms-fanout reconnect loop: attempting to reconnect")
               (handler-case
                   (setf *client* (connect address))
                 ((or USOCKET:NS-TRY-AGAIN-CONDITION error) (err)
                   (syslog-log :info (format nil
                                             "failed to connect to ~A: ~A. "
                                             address err))))))
         (when (connected-p :client *client*)
           (syslog-log :info (format nil "pinging"))
           (wsd:send-ping *client*))
         (unless (sip:linphonec-started-p)
           (syslog-log :info "restatring linphonec..")
           (sip:linphonec-restart))
         (sleep (* reconnect-delay-mins 60)))))

;; (connected-p :client *client*)
;; (sms-fanout-connect)
;; (sb-thread:terminate-thread *sms-fanout-reconnect-thread*)

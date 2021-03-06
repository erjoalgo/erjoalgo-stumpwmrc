(in-package :STUMPWM)

(defpackage #:url-launcher
  (:export
   #:launch-url
   #:launcher-append-url
   #:search-engine-search
   #:search-engines-reload
   #:uri-encode))

;; (use-package :statusor)

(defparameter *search-history-fn*
  (merge-pathnames "search-history" *data-private-one-way*))

(defvar *webdav-server-info* nil)

(defun load-webdav-server-info ()
  ;; may be interactive
  (unless (authinfo:get-by :app "webdav")
    (authinfo:persist-authinfo-line
     :line-prefix "app webdav"
     :required-keys '("machine" "login" "password")))
  (statusor:if-let-ok nil
      (
       (auth (statusor:nil-to-error (authinfo:get-by :app "webdav")))
       (machine (authinfo:alist-get-or-error :machine auth))
       (scheme (or (authinfo:alist-get :scheme auth) "https"))
       (port (authinfo:alist-get :port auth))
       (url (format nil "~A://~A~A" scheme machine
                    (if port (format nil ":~A" port) "")))
       (user (authinfo:alist-get :login auth))
       (password (authinfo:alist-get :password auth)))
    (setf *webdav-server-info*
          (cladaver:make-server-info :base-url url
                                     :username user
                                     :password password))))

;; note the trailing slash.
;; needed to allow merging additional pathname components
(defvar webdav-urls-prefix #P"/urls/")

(defun url-launcher-get-browser-current-url ()
  (mozrepl:chrome-get-url))

(defun url-launcher-browser-new-tab (url)
  (SB-EXT:RUN-PROGRAM *browser-name*
		      (list url)
		      :search t
		      :wait nil
                      :output t
		      :error t))

;; actually load from the file
(defparameter *url-command-rules*
  `(
    (".*[.]pdf$" "zathura")
    ("(^https?://.*|.*[.]html.*).*" ,#'url-launcher-browser-new-tab)
    (".*[.](docx?|odt)$" "libreoffice")
    ("about:config" ,#'mozrepl:firefox-new-tab)))

(defun url-command (url)
  (loop for (regexp opener) in *url-command-rules*
     thereis (and (cl-ppcre:scan regexp url) opener)
     finally (return #'url-launcher-browser-new-tab)))

(defvar *url-keys-cache* nil)
(defvar *url-values-cache* nil)

(defun url-launcher-list-url-keys (&key skip-cache)
  (if (and (not skip-cache) *url-keys-cache*)
      (prog1
          *url-keys-cache*
        (lparallel:future
         (url-launcher-list-url-keys
                :skip-cache t)))
      (setf *url-keys-cache*
            (statusor:error-to-signal
             (cladaver:ls *webdav-server-info* webdav-urls-prefix)))))

(defun url-launcher-cat-webdav-path (webdav-path &key skip-cache)
  (let ((val
          (and (not skip-cache)
               (cdr
                (assoc webdav-path *url-values-cache* :test #'equal)))))
    (if val
        (prog1 val
          (lparallel:future
            (url-launcher-cat-webdav-path webdav-path :skip-cache t)))
        (prog1
            (setf val (cladaver:cat *webdav-server-info* webdav-path))
          (pushnew (cons webdav-path val) *url-values-cache*)))))

(define-stumpwm-type-with-completion :aliased-url
    (progn
      (statusor:error-to-signal (webdav-maybe-init))
      (statusor:error-to-signal (url-launcher-list-url-keys)))
  :key-fn file-namestring
  :value-fn
  (lambda (webdav-path)
    (statusor:error-to-signal
     (url-launcher-cat-webdav-path webdav-path))))

(defcommand launch-url (url) ((:aliased-url "enter url key: "))
  "Do a completing read of stored keys, then launch url"
  (when url
    (let* ((url (expand-user url))
           (opener (url-command url)))
      (if (functionp opener)
          (funcall opener url)
          (progn
            (run-shell-command (format nil "~A ~A" opener url))
            ;;TODO why this causes hang
            '(SB-EXT:RUN-PROGRAM opener  (list url)
              ;;TODO output to tmp?
              :search t
              :wait nil
              :output t
              :error t
              :input t)
            nil ))
      ;;log to different file? or at least add tags
      (log-entry-timestamped url *search-history-fn*))))

(defcommand launcher-append-url (key &optional url)
    ((:string "enter new key: ")
     (:string nil ))
  "Read a new key-url pair, defaulting to current (firefox) browser url"
  (setq url (or url (url-launcher-get-browser-current-url))
	key (trim-spaces key))
  (if (or (not (and key url))
	  (zerop (length key))
	  (zerop (length url))
	  (string= "NIL" key))
      (message "invalid key")
      (progn
        (unless *webdav-server-info* (load-webdav-server-info))
        (assert *webdav-server-info*)
        (statusor:error-to-signal
         (cladaver:put *webdav-server-info*
                       (merge-pathnames webdav-urls-prefix key)
                       url))
	(echo (format nil "added: ~A" url)))))

;;search-engine-search
(defparameter *search-engine-persistent-alist*
  (make-instance 'psym-tsv
   :pathnames (loop for data-dir in *data-dirs*
                 collect (merge-pathnames "search-engines" data-dir))
   :short-description "search engines"))

(defun uri-encode (search-terms)
  (reduce
   (lambda (string from-to)
     (ppcre:regex-replace-all (car from-to) string (cdr from-to)))
   '(("%" "%25")
     (" " "%20")
     ("[+]" "%2B"))
   :initial-value search-terms))

(defun uri-decode (url)
  (reduce
   (lambda (string from-to)
     (ppcre:regex-replace-all (car from-to) string (cdr from-to)))
   '(("%25" "%")
     ("%20" " ")
     ("%2B" "[+]")
     ("%3a" ":")
     ("%2f" "/"))
   :initial-value url))

;;would still be nice to have an emacs-like
;;(interactive (list ...))
;;without having to defne custom, one-off types
;(defcommand search-engine-search (engine terms)
    ;((:string "enter search engine to use: ")
     ;(:string "enter search terms: "))

(define-stumpwm-type-with-completion :search-engine
    (psym-records *search-engine-persistent-alist*)
  :key-fn car
  :value-fn cdr
  :no-hints nil)

(defcommand search-engine-search
    (engine &optional terms)
    ((:search-engine "search engine: "))
  "completing-read prompt for search engine if not provided. then use its format string to construct a url by uri-encoding search terms"
  (unless terms
    (setf terms
          (read-one-line (current-screen)
                         (format nil "enter ~A search query: " engine))))
  (when (and engine terms)
    (let ((engine-fmt
            (if (consp engine)
                (cadr engine)
                (cdr (alist-get engine (psym-records *search-engine-persistent-alist*))))))
      (if (not engine-fmt)
	  (error "no such engine: '~A'" engine)
	  (let* (
	         (args (ppcre:regex-replace-all "\\n" (trim-spaces terms) " "))
	         (query (uri-encode args))
	         (url (format nil engine-fmt query)))
	    (url-launcher-browser-new-tab url)
	    (log-entry-timestamped (format nil "~A:~A" engine terms)
			         *search-history-fn*))))))

(defparameter *default-search-engine* "ddg")

(defcommand search-engine-search-clipboard () ()
  "search the clipboard contents"
  (search-engine-search *default-search-engine* (get-x-selection )))

;; make command name shorter to make help-map (?) more useful
(defcommand-alias engsearch search-engine-search)

(defvar *search-engine-map* (make-sparse-keymap) "")
(defvar *search-engine-by-letter-alist* (make-sparse-keymap) "")

(defcommand search-engines-reload () ()
  "reload search engines from file"
  (psym-load *search-engine-persistent-alist*)
  (setf *search-engine-by-letter-alist* nil)
  (loop
    with used-letters = nil
    for (eng . fmt) in (psym-records *search-engine-persistent-alist*)
    as letter = (loop for letter across eng
		      unless (member letter used-letters :test 'eql)
		        return letter)
    do (if (not letter)
           (warn "unable to find a letter for engine ~A" eng)
           (progn
	     (define-key *search-engine-map* (kbd (format nil "~A" letter))
	       (format nil "engsearch ~A" eng))
	     (push letter used-letters)
             (push (cons letter eng) *search-engine-by-letter-alist*)))))

(defun look-up-engine-by-letter (letter)
  (cdr (alist-get letter *search-engine-by-letter-alist*)))

(export '(look-up-engine-by-letter) :stumpwm)

(defun define-key-auto-from-commands-into-keymap ()
  ;;TODO
  ;;automatically find the best key for a set of named commands
  ;;for use the first character in the command name that hasn't been used
  )

(defun webdav-maybe-init ()
  (unless *webdav-server-info*
    (statusor:return-if-error (load-webdav-server-info) WEBDAV-MAYBE-INIT)
    ;; mkdir. may fail if already exists
    '(cladaver:mkdir *webdav-server-info* webdav-urls-prefix)))

(defun url-launcher-init ()
  (ensure-directory-exists
   (uiop:pathname-parent-directory-pathname
    (uiop:ensure-directory-pathname *search-history-fn*))
   :max-parents 2)
  (dolist (class *browser-classes*)
    (pushnew `(:class ,class) stumpwm:*deny-raise-request*))
  (psym-load *search-engine-persistent-alist*)
  (setf *suppress-deny-messages* t))

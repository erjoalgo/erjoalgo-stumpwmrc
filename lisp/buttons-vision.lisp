(defparameter BUTTONS-ROOT
  (merge-pathnames "data/button-imgs/" STUMPWM-TOP))

(define-stumpwm-type-from-wild-pathname :button-pathname
    (merge-pathnames (make-pathname :type "png" :name :WILD) BUTTONS-ROOT)
  :allow-nonexistent t)

(defcommand click-button (button-pathname) ((:button-pathname "enter button image: "))
  (message "button image is ~A" button-pathname))

(defcommand define-button  (button-pathname) ((:button-pathname "enter button image: "))
  (let* ((name (pathname-name button-pathname))
	 (parent-dir (make-pathname :name nil :type nil :defaults button-pathname)))

    (unless (probe-file parent-dir)
      ;; (setf ex (sb-posix:stat #P"/home/ejalfonso/git/erjoalgo-stumpwmrc/lisp/"))
      ;; (SB-MOP:CLASS-DIRECT-SLOTS (class-of ex))
      ;; (sb-posix:stat-mode ex)
      (format t "making buttons directory: ~A~%" parent-dir)
      (sb-posix:mkdir parent-dir 16877))

    (setf button-pathname
          (take-scrot name
                      :fullscreen-p nil
                      :scrot-top parent-dir
                      :verbose nil
                      :eog-scrot nil))

    (unless (and button-pathname
                 (probe-file button-pathname))
      (error "scrot ~A was not created" button-pathname))))
